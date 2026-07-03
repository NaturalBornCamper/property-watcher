#!/bin/bash
#
# email-to-html.sh - cPanel "pipe to a program" handler.
#
# Receives one raw email on stdin, extracts the HTML body, and publishes it
# as $OUTPUT_DIR/<sender>.html, where <sender> is derived from the sender's
# domain (mail from search-alerts@centris.ca becomes centris.html).
#
# Self-contained: needs only bash, awk, and coreutils (base64, tr, sed),
# which are present on any cPanel server. No Python or Perl dependency.
#
# cPanel/Exim pipe rules this script follows:
#   - Never write to stdout: anything on stdout is bounced back to the
#     sender as a delivery error.
#   - Always exit 0: a non-zero exit status also bounces the email.
#     Failures are logged to $LOG_FILE instead, and the raw email is kept
#     in $FAILED_DIR so nothing is lost.

# stdout/stderr must never reach Exim; silence them until the log is known.
exec >/dev/null 2>&1

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load settings.
if [ -f "$SCRIPT_DIR/settings.env" ]; then
    set -a
    . "$SCRIPT_DIR/settings.env"
    set +a
fi

LOG_FILE="$SCRIPT_DIR/pipe.log"
FAILED_DIR="$SCRIPT_DIR/failed"

# Simple rotation so the log cannot grow unbounded on shared hosting.
if [ -f "$LOG_FILE" ]; then
    log_size=$(wc -c < "$LOG_FILE" 2>/dev/null)
    if [ "${log_size:-0}" -gt 1048576 ] 2>/dev/null; then
        mv -f "$LOG_FILE" "$LOG_FILE.old"
    fi
fi

if ! touch "$LOG_FILE"; then
    LOG_FILE=/dev/null
fi
exec >>"$LOG_FILE" 2>&1

log() {
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

# Spool the email to a temp file first so every failure path below can
# preserve it in FAILED_DIR instead of discarding it.
RAW_FILE="$(mktemp "${TMPDIR:-/tmp}/email-pipe.XXXXXX")"
if [ -z "$RAW_FILE" ]; then
    log "ERROR: mktemp failed, email discarded"
    exit 0
fi
PART_FILE=""
TMP_OUT=""
INDEX_TMP=""
HAVE_LOCK=""
trap 'rm -f "$RAW_FILE" "$PART_FILE" "$TMP_OUT" "$INDEX_TMP"; [ -n "$HAVE_LOCK" ] && rmdir "$LOCK_DIR" 2>/dev/null' EXIT
cat > "$RAW_FILE"

fail() {
    mkdir -p "$FAILED_DIR"
    local dest="$FAILED_DIR/$(date '+%Y%m%d-%H%M%S')-$$.eml"
    if mv -f "$RAW_FILE" "$dest"; then
        log "ERROR: $1 (raw email saved to $dest)"
    else
        log "ERROR: $1 (raw email could not be saved)"
    fi
    exit 0
}

if [ ! -f "$SCRIPT_DIR/settings.env" ]; then
    fail "settings.env not found; copy settings.env.example to settings.env and edit it"
fi

if [ -z "$OUTPUT_DIR" ]; then
    fail "OUTPUT_DIR is not set in settings.env"
fi

if ! mkdir -p "$OUTPUT_DIR"; then
    fail "cannot create OUTPUT_DIR: $OUTPUT_DIR"
fi

# --------------------------------------------------------------------------
# Embedded awk programs
# --------------------------------------------------------------------------

# Print the (lowercased) domain of the From address in the top headers.
AWK_FROM=$(cat <<'AWK'
{
    line = $0
    sub(/\r$/, "", line)
    if (line == "") exit               # end of top headers
    if (line ~ /^[ \t]/) {             # folded continuation line
        if (infrom) { sub(/^[ \t]+/, " ", line); fromv = fromv line }
        next
    }
    infrom = (tolower(line) ~ /^from:/)
    if (infrom) fromv = line
}
END {
    v = fromv
    if (v == "") exit 1
    if (match(v, /<[^>]*>/))
        v = substr(v, RSTART + 1, RLENGTH - 2)
    else
        sub(/^[Ff][Rr][Oo][Mm]:[ \t]*/, "", v)
    n = split(v, parts, "@")
    if (n < 2) exit 1
    d = tolower(parts[n])
    gsub(/[^a-z0-9.-]/, "", d)
    if (d == "") exit 1
    print d
}
AWK
)

# Walk the MIME structure and emit the first non-attachment text/html part:
# first a "META cte=... charset=..." line, then the raw (still-encoded) body.
# Emits nothing when the message has no text/html part.
AWK_MIME=$(cat <<'AWK'
BEGIN { phase = "top"; nb = 0; hcur = "" }

function reset_entity() {
    e_type = ""; e_bound = ""; e_charset = ""; e_cte = ""; e_attach = 0
}

function flush_hdr(    lc, rest, cs) {
    if (hcur == "") return
    lc = tolower(hcur)
    if (lc ~ /^content-type:/) {
        e_type = lc
        sub(/^content-type:[ \t]*/, "", e_type)
        sub(/;.*$/, "", e_type)
        gsub(/[ \t"]/, "", e_type)
        # Boundary is case-sensitive: locate it on the lowercased copy but
        # extract from the original header text.
        if (match(lc, /boundary[ \t]*=[ \t]*"/)) {
            rest = substr(hcur, RSTART + RLENGTH)
            sub(/".*$/, "", rest)
            e_bound = rest
        } else if (match(lc, /boundary[ \t]*=[ \t]*/)) {
            rest = substr(hcur, RSTART + RLENGTH)
            sub(/[;, \t].*$/, "", rest)
            e_bound = rest
        }
        if (match(lc, /charset[ \t]*=[ \t]*"?/)) {
            cs = substr(lc, RSTART + RLENGTH)
            sub(/["';, \t].*$/, "", cs)
            e_charset = cs
        }
    } else if (lc ~ /^content-transfer-encoding:/) {
        e_cte = lc
        sub(/^content-transfer-encoding:[ \t]*/, "", e_cte)
        gsub(/[ \t"]/, "", e_cte)
    } else if (lc ~ /^content-disposition:[ \t]*attachment/) {
        e_attach = 1
    }
    hcur = ""
}

function entity_done() {
    if (e_type ~ /^multipart\// && e_bound != "") {
        bstack[++nb] = e_bound
        phase = "search"
    } else if (e_type == "text/html" && !e_attach && !found) {
        printf "META cte=%s charset=%s\n", e_cte, e_charset
        found = 1
        phase = "cap"
    } else {
        phase = "search"
    }
}

{
    line = $0
    sub(/\r$/, "", line)

    # Boundary delimiters (checked against every open multipart level).
    if (nb > 0 && substr(line, 1, 2) == "--") {
        bline = line
        sub(/[ \t]+$/, "", bline)
        for (i = nb; i >= 1; i--) {
            if (bline == "--" bstack[i]) {
                if (phase == "cap") exit
                flush_hdr()
                nb = i
                reset_entity()
                phase = "phdr"
                next
            }
            if (bline == "--" bstack[i] "--") {
                if (phase == "cap") exit
                nb = i - 1
                phase = "search"
                next
            }
        }
    }

    if (phase == "top" || phase == "phdr") {
        if (line == "") {
            flush_hdr()
            entity_done()
            next
        }
        if (line ~ /^[ \t]/) {
            sub(/^[ \t]+/, " ", line)
            hcur = hcur line
            next
        }
        flush_hdr()
        hcur = line
        next
    }

    if (phase == "cap") print line
    # phase "search": skip preamble/epilogue and unwanted parts
}
AWK
)

# Decode quoted-printable (portable awk, byte-oriented under LC_ALL=C).
AWK_QP=$(cat <<'AWK'
BEGIN {
    for (i = 0; i < 256; i++)
        hex2ch[sprintf("%02X", i)] = sprintf("%c", i)
}
{
    line = $0
    sub(/\r$/, "", line)
    soft = 0
    if (line ~ /=$/) {                 # soft line break
        soft = 1
        line = substr(line, 1, length(line) - 1)
    }
    out = ""
    while ((p = index(line, "=")) > 0) {
        out = out substr(line, 1, p - 1)
        h = toupper(substr(line, p + 1, 2))
        if (length(h) == 2 && h in hex2ch) {
            out = out hex2ch[h]
            line = substr(line, p + 3)
        } else {                       # invalid escape: keep literal "="
            out = out "="
            line = substr(line, p + 1)
        }
    }
    out = out line
    printf "%s", out
    if (!soft) printf "\n"
}
AWK
)

# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

# Sender domain -> file base name: the registrable name without its public
# suffix (@centris.ca and @e.centris.ca both become "centris"; two-part
# suffixes such as .qc.ca or .co.uk are handled).
file_base_name() {
    local two_part=" qc.ca on.ca bc.ca ab.ca mb.ca sk.ca ns.ca nb.ca nl.ca pe.ca gc.ca co.uk org.uk ac.uk com.au net.au org.au "
    local -a labels
    local IFS=.
    read -r -a labels <<< "$1"
    local n=${#labels[@]} name
    if [ "$n" -ge 3 ] && [[ "$two_part" == *" ${labels[n-2]}.${labels[n-1]} "* ]]; then
        name=${labels[n-3]}
    elif [ "$n" -ge 2 ]; then
        name=${labels[n-2]}
    else
        name=${labels[0]}
    fi
    name=$(printf '%s' "$name" | tr -cd 'a-z0-9-')
    printf '%s' "${name:0:64}"
}

# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------

from_domain=$(LC_ALL=C awk "$AWK_FROM" "$RAW_FILE")
if [ -z "$from_domain" ]; then
    fail "could not determine sender domain from the From header"
fi

# Allowlist: space-separated domains; subdomains match automatically.
if [ -n "$ALLOWED_SENDER_DOMAINS" ]; then
    allowed_lc=$(printf '%s' "$ALLOWED_SENDER_DOMAINS" | tr 'A-Z' 'a-z')
    allowed=0
    for d in $allowed_lc; do
        case "$from_domain" in
            "$d" | *".$d") allowed=1; break ;;
        esac
    done
    if [ "$allowed" -ne 1 ]; then
        log "skipped: sender domain $from_domain is not in ALLOWED_SENDER_DOMAINS"
        exit 0
    fi
fi

PART_FILE="$(mktemp "${TMPDIR:-/tmp}/email-pipe.XXXXXX")"
LC_ALL=C awk "$AWK_MIME" "$RAW_FILE" > "$PART_FILE"

if [ ! -s "$PART_FILE" ]; then
    fail "no text/html part found in email from $from_domain"
fi

meta=$(head -n 1 "$PART_FILE")
case "$meta" in
    "META "*) ;;
    *) fail "unexpected extractor output for email from $from_domain" ;;
esac
cte=$(printf '%s' "$meta" | sed -n 's/.*cte=\([^ ]*\).*/\1/p')
charset=$(printf '%s' "$meta" | sed -n 's/.*charset=\([^ ]*\).*/\1/p' | tr -cd 'a-z0-9._-')

name=$(file_base_name "$from_domain")
name=${name:-unknown}
# index.html is reserved for the generated file list.
[ "$name" = "index" ] && name="index-mail"
TMP_OUT="$(mktemp "$OUTPUT_DIR/.$name.XXXXXX")"

decode_body() {
    case "$cte" in
        base64)           tr -d ' \t\r' | base64 -d ;;
        quoted-printable) LC_ALL=C awk "$AWK_QP" ;;
        *)                cat ;;   # 7bit / 8bit / binary / unset
    esac
}

set -o pipefail
if ! tail -n +2 "$PART_FILE" | decode_body > "$TMP_OUT"; then
    set +o pipefail
    fail "could not decode ${cte:-7bit} body from $from_domain"
fi
set +o pipefail

if [ ! -s "$TMP_OUT" ]; then
    fail "decoded HTML body is empty (from $from_domain)"
fi

# The bytes are written unchanged (no transcoding), so the charset declared
# in the MIME headers is the true encoding of the file. Newsletter templates
# often carry a stale <meta charset> that disagrees with it, so relabel any
# existing meta to the header charset; when the HTML declares no charset at
# all, prepend one (the HTML5 encoding prescan honors it regardless of
# position).
if grep -qi '<meta[^>]*charset' "$TMP_OUT"; then
    if [ -n "$charset" ]; then
        FIXED="$(mktemp "$OUTPUT_DIR/.$name.XXXXXX")"
        sed 's/\(<[Mm][Ee][Tt][Aa][^>]*[Cc][Hh][Aa][Rr][Ss][Ee][Tt][[:space:]]*=[[:space:]]*["'\'']\{0,1\}\)[A-Za-z0-9_.:-]*/\1'"$charset"'/g' \
            "$TMP_OUT" > "$FIXED" && mv -f "$FIXED" "$TMP_OUT"
    fi
else
    INJECTED="$(mktemp "$OUTPUT_DIR/.$name.XXXXXX")"
    { printf '<meta charset="%s">\n' "${charset:-utf-8}"; cat "$TMP_OUT"; } > "$INJECTED"
    mv -f "$INJECTED" "$TMP_OUT"
fi

chmod 644 "$TMP_OUT"

# --------------------------------------------------------------------------
# Publish: one numbered file per email, counter restarting each day
# --------------------------------------------------------------------------
#
# Alert sites send one email per saved search, so a single day can yield
# centris-1.html, centris-2.html, ... The first email from a domain on a
# later day (file mtimes are compared against today) moves that domain's
# previous batch into archive/ and restarts the counter at 1. The published
# files are listed in an auto-generated index.html.

ARCHIVE_DIR="$OUTPUT_DIR/archive"
if ! mkdir -p "$ARCHIVE_DIR"; then
    fail "cannot create archive folder: $ARCHIVE_DIR"
fi

# Serialize the numbering/rotation against a second email arriving at the
# same moment.
LOCK_DIR="$OUTPUT_DIR/.lock"
tries=0
while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    # Steal locks left behind by a crashed run.
    if [ -n "$(find "$LOCK_DIR" -maxdepth 0 -mmin +2 2>/dev/null)" ]; then
        rmdir "$LOCK_DIR" 2>/dev/null
        continue
    fi
    tries=$((tries + 1))
    if [ "$tries" -ge 60 ]; then
        log "WARNING: could not acquire $LOCK_DIR after 30s, proceeding anyway"
        break
    fi
    sleep 0.5
done
[ "$tries" -lt 60 ] && HAVE_LOCK=1

archive_by_mtime() {
    local stamp dest n
    stamp=$(date -r "$1" '+%Y%m%d-%H%M%S')
    dest="$ARCHIVE_DIR/$name-$stamp.html"
    n=2
    while [ -e "$dest" ]; do    # two files can share an mtime second
        dest="$ARCHIVE_DIR/$name-$stamp-$n.html"
        n=$((n + 1))
    done
    mv "$1" "$dest"
}

# File left over from the older one-file-per-domain scheme.
if [ -e "$OUTPUT_DIR/$name.html" ]; then
    archive_by_mtime "$OUTPUT_DIR/$name.html"
fi

today=$(date '+%Y%m%d')
max=0
for f in "$OUTPUT_DIR/$name-"[0-9]*.html; do
    [ -e "$f" ] || continue
    if [ "$(date -r "$f" '+%Y%m%d')" != "$today" ]; then
        archive_by_mtime "$f"
    else
        idx=${f##*-}
        idx=${idx%.html}
        if [ "$idx" -gt "$max" ] 2>/dev/null; then
            max=$idx
        fi
    fi
done

DEST="$OUTPUT_DIR/$name-$((max + 1)).html"
if ! mv -f "$TMP_OUT" "$DEST"; then
    fail "could not move HTML into place: $DEST"
fi

size=$(wc -c < "$DEST")
log "wrote $DEST (${size:-?} bytes, cte=${cte:-7bit}, from $from_domain)"

# Regenerate index.html so the currently published files are discoverable
# from the root URL alone.
INDEX_TMP="$(mktemp "$OUTPUT_DIR/.index.XXXXXX")"
{
    printf '<!DOCTYPE html>\n<html><head><meta charset="utf-8"><title>Alert mirror</title></head><body>\n'
    printf '<h1>Alert mirror</h1>\n'
    printf '<p>Last updated: %s</p>\n<ul>\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    for f in "$OUTPUT_DIR"/*.html; do
        [ -e "$f" ] || continue
        base=${f##*/}
        [ "$base" = "index.html" ] && continue
        printf '<li><a href="%s">%s</a> &#8212; %s</li>\n' \
            "$base" "$base" "$(date -r "$f" '+%Y-%m-%d %H:%M')"
    done
    printf '</ul>\n</body></html>\n'
} > "$INDEX_TMP"
chmod 644 "$INDEX_TMP"
mv -f "$INDEX_TMP" "$OUTPUT_DIR/index.html"

if [ -n "$HAVE_LOCK" ]; then
    rmdir "$LOCK_DIR" 2>/dev/null
    HAVE_LOCK=""
fi

exit 0

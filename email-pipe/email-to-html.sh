#!/bin/bash
#
# email-to-html.sh - cPanel "pipe to a program" handler.
#
# Receives one raw email on stdin, extracts the HTML body, and publishes it
# as $OUTPUT_DIR/<sender>.html, where <sender> is derived from the sender's
# domain (mail from search-alerts@centris.ca becomes centris.html).
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

# Load settings, exported so extract-html.py sees them as environment vars.
if [ -f "$SCRIPT_DIR/settings.env" ]; then
    set -a
    . "$SCRIPT_DIR/settings.env"
    set +a
fi

LOG_FILE="${LOG_FILE:-$SCRIPT_DIR/pipe.log}"
FAILED_DIR="${FAILED_DIR:-$SCRIPT_DIR/failed}"

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
trap 'rm -f "$RAW_FILE"' EXIT
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

if [ -z "$PYTHON_BIN" ]; then
    for candidate in python3 /usr/bin/python3 /usr/local/bin/python3; do
        if command -v "$candidate" >/dev/null 2>&1; then
            PYTHON_BIN="$candidate"
            break
        fi
    done
fi
if [ -z "$PYTHON_BIN" ]; then
    fail "python3 not found; set PYTHON_BIN in settings.env"
fi

if "$PYTHON_BIN" "$SCRIPT_DIR/extract-html.py" < "$RAW_FILE"; then
    rm -f "$RAW_FILE"
else
    fail "extract-html.py failed"
fi

exit 0

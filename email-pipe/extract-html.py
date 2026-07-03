#!/usr/bin/env python3
"""Extract the HTML body of an email and publish it as <sender>.html.

Reads one raw email on stdin. Configuration arrives through environment
variables exported by email-to-html.sh (see settings.env.example):

    OUTPUT_DIR              required; folder the HTML file is written to
    ALLOWED_SENDER_DOMAINS  optional space-separated sender-domain allowlist
    ARCHIVE_DIR             optional folder for timestamped copies

Never writes to stdout (cPanel would bounce the email); diagnostics go to
stderr, which email-to-html.sh redirects into the log file.

Exit codes: 0 = written or intentionally skipped, 1 = failure (the shell
script then saves the raw email to FAILED_DIR).
"""

import os
import re
import sys
import tempfile
import time
from email import policy
from email.parser import BytesParser
from email.utils import parseaddr

# Suffixes where the registrable name sits one label deeper than usual
# (mail from @foo.qc.ca should become foo.html, not qc.html).
TWO_PART_SUFFIXES = {
    "qc.ca", "on.ca", "bc.ca", "ab.ca", "mb.ca", "sk.ca", "ns.ca", "nb.ca",
    "nl.ca", "pe.ca", "gc.ca",
    "co.uk", "org.uk", "ac.uk",
    "com.au", "net.au", "org.au",
}


def log(message):
    print("extract-html: " + message, file=sys.stderr)


def sender_domain(message):
    address = parseaddr(str(message.get("From", "")))[1]
    if "@" not in address:
        return ""
    return address.rsplit("@", 1)[1].strip().lower()


def file_base_name(domain):
    labels = domain.split(".")
    if len(labels) >= 3 and ".".join(labels[-2:]) in TWO_PART_SUFFIXES:
        name = labels[-3]
    elif len(labels) >= 2:
        name = labels[-2]
    else:
        name = labels[0]
    return re.sub(r"[^a-z0-9-]", "", name)[:64]


def ensure_utf8_charset(html):
    """The decoded body is written out as UTF-8, so any other charset the
    email declared in a <meta> tag must be rewritten or the browser will
    mis-decode the file."""
    fixed, count = re.subn(
        r"""(<meta[^>]*charset=["']?)([A-Za-z0-9_.:-]+)""",
        r"\g<1>utf-8", html, flags=re.IGNORECASE)
    if count:
        return fixed
    match = re.search(r"<head[^>]*>", html, re.IGNORECASE)
    if match:
        pos = match.end()
        return html[:pos] + '<meta charset="utf-8">' + html[pos:]
    return '<meta charset="utf-8">\n' + html


def write_atomic(directory, filename, content):
    """Write via a temp file + rename so the web server never serves a
    half-written page."""
    fd, tmp_path = tempfile.mkstemp(prefix="." + filename + ".", dir=directory)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(content)
        os.chmod(tmp_path, 0o644)
        os.replace(tmp_path, os.path.join(directory, filename))
    finally:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)


def main():
    output_dir = os.environ.get("OUTPUT_DIR", "").strip()
    if not output_dir:
        log("OUTPUT_DIR is not set")
        return 1

    message = BytesParser(policy=policy.default).parsebytes(
        sys.stdin.buffer.read())

    domain = sender_domain(message)
    if not domain:
        log("could not determine sender domain from the From header")
        return 1

    allowlist = os.environ.get("ALLOWED_SENDER_DOMAINS", "").lower().split()
    if allowlist and not any(domain == allowed or domain.endswith("." + allowed)
                             for allowed in allowlist):
        log("skipped: sender domain %s is not in ALLOWED_SENDER_DOMAINS"
            % domain)
        return 0

    body = message.get_body(preferencelist=("html",))
    if body is None:
        log("no text/html part found in email from %s" % domain)
        return 1
    html = ensure_utf8_charset(body.get_content())

    name = file_base_name(domain) or "unknown"
    filename = name + ".html"
    write_atomic(output_dir, filename, html)
    log("wrote %s (%d chars, from %s)"
        % (os.path.join(output_dir, filename), len(html), domain))

    archive_dir = os.environ.get("ARCHIVE_DIR", "").strip()
    if archive_dir:
        os.makedirs(archive_dir, exist_ok=True)
        stamped = "%s-%s.html" % (name, time.strftime("%Y%m%d-%H%M%S"))
        write_atomic(archive_dir, stamped, html)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:  # any bug must not bounce the email
        log("unhandled error: %r" % error)
        sys.exit(1)

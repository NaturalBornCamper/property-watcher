# Email → HTML pipe for cPanel

Turns search-alert newsletter emails (Centris, Realtor.ca, ...) into public
HTML pages. A cPanel email filter pipes each incoming email into
`email-to-html.sh`; the script extracts the HTML body and writes it into the
document root of a subdomain, named after the sender's domain:

    search-alerts@centris.ca  →  https://alerts.yourdomain.com/centris-1.html

Alert sites send one email per saved search (e.g. one for LaSalle, one for
Verdun), so every email of the day gets the next number for its sender
domain: `centris-1.html`, `centris-2.html`, ... The first email from a
domain on a later day moves the previous batch into `archive/` and restarts
at 1. An auto-generated `index.html` lists the currently published files, so
the AI only needs the root URL. These mirror URLs are the "public newsletter
mirror" intake sources described in `AGENTS.md`.

## Files

| File                   | Purpose                                                  |
| ---------------------- | -------------------------------------------------------- |
| `email-to-html.sh`     | Entry point the cPanel email filter pipes into           |
| `settings.env.example` | Settings template; copy to `settings.env` on the server  |

The script is self-contained bash: MIME parsing and base64/quoted-printable
decoding are done with embedded `awk` programs and coreutils (`base64`,
`tr`, `sed`), all present on any cPanel server. No Python or Perl needed.

Created at runtime next to the script: `pipe.log` (log, rotated at ~1 MB) and
`failed/` (raw copies of emails that could not be processed). Created inside
`OUTPUT_DIR`: `archive/` (previous days' files, renamed with their date and
time) and `index.html` (auto-generated list of the published files).

## Server setup

1. **Subdomain** — cPanel → *Domains* → create e.g. `alerts.yourdomain.com`
   and note its document root (e.g. `/home/YOURUSER/alerts.yourdomain.com`).
   The script maintains an `index.html` there itself.
2. **Upload** — put this folder in your home directory, e.g.
   `/home/YOURUSER/email-pipe/`. Do **not** put it inside `public_html`
   (the settings and logs must not be web-accessible).
3. **Settings** — `cp settings.env.example settings.env`, then edit
   `OUTPUT_DIR` (the subdomain document root) and `ALLOWED_SENDER_DOMAINS`.
   `chmod 600 settings.env`.
4. **Permissions** — `chmod 700 email-to-html.sh`.
5. **Email address** — cPanel → *Email Accounts* → create a dedicated
   address to receive the alerts, ideally with an unguessable local part
   (e.g. `alerts-x7k2q@yourdomain.com`), and subscribe it to the search
   alerts.
6. **Filter** — cPanel → *Email* → *Email Filters* → manage filters for that
   account → *Create a New Filter*:
   - Rule: `To` — `contains` — `alerts-x7k2q@yourdomain.com`
     (or `From` — `contains` — `centris.ca`).
   - Action: *Pipe to a Program* — `email-pipe/email-to-html.sh`
     (path relative to your home directory, no leading slash).
   - With only the pipe action the email is **not** stored in the mailbox;
     add a second action *Deliver to folder* → INBOX if you want a copy.

## Testing

In cPanel → *Terminal* (or over SSH):

```sh
cd ~/email-pipe
./email-to-html.sh < message.eml   # a raw email saved from webmail
tail pipe.log
```

To get a `message.eml`, open an alert email in webmail and use
"Download" / "Show message source". Then open
`https://alerts.yourdomain.com/` in a browser: the index lists the published
files (e.g. `centris-1.html`). After that, send a real email through the
filter and check `pipe.log` again.

## Behavior notes

- **Filename** — sender domain minus the public suffix, plus the day's
  counter: `@centris.ca` and `@e.centris.ca` both become `centris-N.html`;
  common two-part suffixes such as `qc.ca` or `co.uk` are handled. The name
  is sanitized to `a-z0-9-`.
- **Daily batches** — numbering restarts when the first email from a domain
  arrives on a later day (file dates are compared against today); the
  previous batch moves to `archive/`, renamed with its date and time (e.g.
  `archive/centris-20260703-153000.html`). The latest batch stays published
  until the next one arrives. `archive/` lives under the subdomain too, so
  old versions stay reachable by URL; delete old archive files whenever you
  want to reclaim space.
- **index.html** — regenerated after every email; point the AI at
  `https://alerts.yourdomain.com/` and it can discover the current batch
  without knowing how many files there are.
- **Day boundary** — "today" comes from the server clock. If `date` in the
  cPanel Terminal is not in your timezone, uncomment `TZ` in `settings.env`
  so the counter resets at your midnight; the shared-hosting system clock
  itself cannot be changed, but `TZ` applies per-process and the pipe
  exports it to everything it runs.
- **Allowlist** — anyone who emails the pipe address publishes HTML on your
  subdomain, so keep `ALLOWED_SENDER_DOMAINS` set; list as many domains as
  you need, separated by spaces. (Sender addresses can be spoofed; the
  unguessable address is the second layer.)
- **Charset** — the HTML bytes are written unchanged; the charset declared
  in the email's MIME headers is relabeled into (or injected as) the
  `<meta charset>` so browsers decode accents correctly.
- **Never bounces** — the script always exits 0 and writes nothing to
  stdout, because cPanel/Exim turns either into a bounce to the newsletter
  sender. Failures are logged to `pipe.log` and the raw email is saved in
  `failed/`.

## Troubleshooting

- **"bad interpreter" or the filter does nothing** — the scripts were
  uploaded with Windows CRLF line endings. Re-upload with LF endings (the
  repo's `.gitattributes` enforces LF; avoid editors that convert on save).
- **Nothing in `pipe.log`** — check the script path in the filter, the
  execute bit, and cPanel → *Track Delivery* for pipe errors.
- **Email arrived but no HTML file** — see `pipe.log`; the raw email is in
  `failed/` if parsing failed (e.g. text-only email with no HTML part).

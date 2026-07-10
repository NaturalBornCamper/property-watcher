@AGENTS.md

# CLAUDE.md

This file imports `AGENTS.md`, which is the source of truth for this repository's purpose, file structure, rental eligibility rules, request etiquette, compiled HTML schema, thumbnail handling, and commit expectations.

Do not duplicate the full project instructions here. Keep this file limited to Claude-specific notes or overrides only.

## Claude-specific notes

- Follow `AGENTS.md` unless this file later adds a more specific Claude-only instruction.
- Scheduled runs (Claude Routines) follow `routines/rental-watch.md`; the stored routine prompt only points there and supplies the source URLs.
- Fetch target pages through the Proxy Page Server (see `AGENTS.md`) whenever `PROXY_PAGE_SERVER_URL` and `PROXY_PAGE_SERVER_API_KEY` are set; this is mandatory in scheduled runs.
- Prefer newsletter-generated HTML as the normal intake source; user-provided listing pages and search-result pages are rare exceptions. This is about intake only — during a run, always fetch the detail page (and linked broker sheet) of every candidate headed to either table, per `AGENTS.md`.
- Keep request volume low and do not bypass bot protection.
- Use at most one active request per domain, but allow safe parallel requests across different domains when supported.
- If a source is blocked by CAPTCHA, bot detection, 403, 429, or similar access restrictions, record it, continue with other sources, and report blocked sources at the end.
- Check free-text listing descriptions for square footage, room count, floor, laundry, courtyard, postal code, and address details when structured fields are missing.
- Put the main thumbnail image in the `Listing` column, linked to the listing page with a stable named `target`.
- For normal updates to `docs/index.html`, only add or update accurate listing rows, update the visible `Last updated` date, and keep both tables sorted by `Date added` newest first, then `Date listed` newest first.
- Put unresolved or postal-code-missing candidates in the unresolved candidates table below the accepted table; never put them in the accepted table.
- Do not claim GitHub changes were made unless a GitHub write action actually succeeded.

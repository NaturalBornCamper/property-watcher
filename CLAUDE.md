@AGENTS.md

# CLAUDE.md

This file imports `AGENTS.md`, which is the source of truth for this repository's purpose, file structure, rental eligibility rules, request etiquette, compiled HTML schema, and commit expectations.

Do not duplicate the full project instructions here. Keep this file limited to Claude-specific notes or overrides only.

## Claude-specific notes

- Follow `AGENTS.md` unless this file later adds a more specific Claude-only instruction.
- Keep request volume low and do not bypass bot protection.
- Use at most one active request per domain, but allow safe parallel requests across different domains when supported.
- If a source is blocked by CAPTCHA, bot detection, 403, 429, or similar access restrictions, record it, continue with other sources, and report blocked sources at the end.
- Check free-text listing descriptions for square footage, room count, floor, laundry, courtyard, postal code, and address details when structured fields are missing.
- For normal updates to `docs/index.html`, only add or update accurate listing rows, update the visible `Last updated` date, and keep the table sorted newest first.
- Keep unresolved or postal-code-missing candidates out of the accepted rental table unless the user explicitly approves a temporary review section.
- Before committing, show proposed changes for user review if the user asked to review first.
- Do not claim GitHub changes were made unless a GitHub write action actually succeeded.

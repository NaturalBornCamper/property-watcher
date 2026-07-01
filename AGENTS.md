# AGENTS.md

## Project purpose

This repository maintains the agent instructions, skills, and compiled output for filtering property listings into a small, useful watch list.

The project is not a general real-estate crawler and is not intended for resale, lead generation, competitive scraping, or any commercial use. The goal is to save personal time by filtering out misleading or irrelevant rental and purchase listings.

The current active workflow is rental filtering. Future workflows may add purchase filtering for a forever-home search, but all property workflows should share the same conservative extraction, throttling, deduplication, blocked-source reporting, and review principles.

## Canonical files

Primary files:

- `docs/index.html` - compiled rental-listings output and current canonical accepted-listings file.
- `AGENTS.md` - project instructions and source of truth for agents.
- `CLAUDE.md` - Claude-specific entry point that should reference this file instead of duplicating these rules.
- `skills/rental-property-filter/SKILL.md` - current ChatGPT Skill for rental property filtering.

Future supporting files may include more property-type outputs, skills, scripts, notes, templates, or deployment workflows. Keep this file as the repository-wide source of truth when rules overlap.

## Compiled output location

Use `docs/index.html` as the compiled output file.

Reasoning:

- ChatGPT can update GitHub repository files directly.
- GitHub can serve `docs/index.html` through GitHub Pages when Pages is enabled for the `main` branch and `/docs` folder.
- If the user wants the same file on shared hosting later, add a GitHub Actions workflow that uploads `docs/index.html` to Interserver/cPanel using repository secrets.

Do not store FTP, SFTP, SSH, cPanel, or hosting passwords in this repository. Use GitHub Actions secrets for deployment credentials if shared-hosting upload is added later.

## Source of truth

When updating accepted listings, use `docs/index.html` as the source of truth for current accepted listings and prior decisions.

Use listing websites, public listing pages, and public newsletter/search-alert HTML only as sources for current property data. Do not assume rendered website summaries are complete. Listing cards often omit floor, laundry, courtyard, square footage, postal code, exact address, or date details.

Prefer official listing details from the listing page when available. Use search-result cards only when they contain enough reliable information to decide eligibility.

## Property intake sources

Supported inputs:

- Listing-result page URLs already pre-filtered by the user on a property website.
- Individual listing URLs.
- Public URLs containing HTML from a search-alert newsletter.
- Raw HTML pasted by the user.

For newsletter HTML, extract listing URLs, listing cards, prices, dates, and summary details from the HTML before deciding whether to fetch detail pages.

## Request etiquette, concurrency, and blocked sources

Be conservative with requests, but use safe parallelism across different domains.

- Do not send high-frequency requests.
- Allow at most one active request at a time per domain.
- Requests to different domains may run in parallel when the tool environment supports it.
- Example: one request to `domain-a.com`, one request to `domain-b.com`, and one request to `domain-c.com` may run at the same time; do not run three simultaneous requests to `domain-a.com`.
- Wait at least 5 seconds between requests to the same domain when using a live browser or HTTP client.
- Use longer waits, around 10 seconds, when opening many individual detail pages from the same site.
- Follow detail-page links only when the list page or newsletter card does not contain enough information to decide eligibility or fill important fields.
- Deduplicate URLs before fetching detail pages.
- If a site returns bot protection, CAPTCHA, 403, 429, unusual blocking behavior, or an access error, record the blocked source and continue with the next source or next domain.
- Report blocked sources at the end with the URL, domain, observed block type, and what information could not be checked.
- Do not attempt to bypass bot protection, paywalls, logins, rate limits, IP limits, CAPTCHA, or access controls.
- Do not use multiple IPs, proxy rotation, credential stuffing, or browser fingerprint evasion.
- Prefer public pages and the user's public newsletter mirror URLs.

The purpose is personal filtering, not bulk scraping.

## Shared property fields

Extract these fields whenever available. Information may appear in structured listing fields, listing cards, page metadata, image captions, tables, or the free-text description.

1. `DATE ADDED` - date the listing was added to the compiled table, normalized to `YYYY-MM-DD`.
2. `DATE LISTED` - listing publication date or best available relative date normalized to `YYYY-MM-DD` when possible.
3. `PRICE` - rental monthly price in CAD for rental workflows.
4. `ROOMS` - bedrooms or rooms, preserving the source label when ambiguous.
5. `SIZE` - living area in square feet.
6. `LOCATION / POSTAL CODE` - exact address, postal code, borough/neighborhood, or other location text.
7. `FLOOR` - floor, level, basement, ground floor, elevator context, or unknown.
8. `LAUNDRY` - in-unit hookups, washer/dryer, shared laundry, none, or unknown.
9. `COURTYARD` - courtyard, yard, shared yard, balcony/patio only, none, or unknown.
10. `URL` - canonical listing URL.
11. `NOTES` - concise uncertainty notes or source-specific caveats.

Do not fabricate missing fields. Use `Unknown` when a field cannot be found after reasonable inspection.

## Current rental eligibility rules

A rental listing is accepted only when it satisfies all current rental filters:

1. Postal code prefix must be `H4H` or `H8P`.
2. Rooms must be at least 2 using the clearest available room or bedroom count.
3. Size must be at least 900 square feet when a real size is available.

Postal code handling:

- Normalize postal codes to uppercase.
- Accept `H4H` and `H8P` prefixes with or without a space in the full postal code.
- Do not accept a listing only because it says Verdun, LaSalle, Montreal, or a nearby neighborhood. The postal code prefix or an exact address that can reliably establish the prefix is required.
- If the postal code is missing after checking available details, keep the listing out of the accepted table and mention it separately as an unresolved candidate if it otherwise looks promising.

Room handling:

- Prefer the source's bedroom count when available.
- Check the free-text description for room count when structured fields are missing or ambiguous.
- If the source uses a different room notation, preserve the source label in the table and explain the interpretation in `NOTES` when needed.
- Reject studios, bachelor apartments, 1-room, and 1-bedroom listings.
- Treat ambiguous room counts conservatively and keep unresolved cases out of the accepted table until clarified.

Size handling:

- Check both structured fields and the free-text description for square footage.
- If a plausible size is available and it is less than 900 sqft, reject the listing.
- If size is missing, keep evaluating the listing; missing size alone is not a rejection.
- Treat obvious platform defaults such as `1 sqft`, `0 sqft`, or similarly impossible values as `Unknown`, not as real size.
- If a listing says less than 900 sqft in prose or structured data, reject it even if another field is missing.

## Compiled HTML table schema

`docs/index.html` contains the accepted rental table.

The table must include these columns, in this order:

1. `Date added`
2. `Date listed`
3. `Price`
4. `Rooms`
5. `Size`
6. `Location / postal code`
7. `Floor`
8. `Laundry`
9. `Courtyard`
10. `URL`
11. `Notes`

Each accepted listing row must have exactly eleven cells.

Use short cell values. Escape HTML special characters in user-visible text. Use a normal link for the URL cell:

```html
<a href="https://example.com/listing/123">Listing</a>
```

Use `Unknown` for unavailable values.

## Sorting and deduplication

Keep the accepted-listings table sorted by `Date listed` newest first.

When listing dates are equal, sort by `Date added` newest first. Put `Unknown` listing dates below dated listings unless the user explicitly asks for another behavior.

Deduplicate before adding rows. Treat listings as likely duplicates when they share any of these:

- same canonical URL;
- same listing ID;
- same exact address and price;
- same address with very similar photos/details from the same source.

If a listing already exists but has improved details, update only the relevant cells and preserve its original `Date added` unless the user explicitly asks otherwise.

## Updating `docs/index.html`

For a normal rental update, preserve the file as-is except for the specific update being made.

Only change:

1. Add newly accepted listing rows.
2. Update existing rows when newly fetched details clarify unknown fields.
3. Update the visible `Last updated` date.
4. Re-sort the accepted-listings table newest first.
5. Update the blocked/unresolved notes section when useful.

Do not rewrite unrelated rows, change the schema, or perform opportunistic cleanup unless the user explicitly asks.

Before final output or commit, verify that every accepted row satisfies postal-code, room, and size rules.

## Review workflow

For filtering tasks, provide:

- Accepted listings added or updated.
- Rejected listings with short rejection reasons when they were close or ambiguous.
- Unresolved candidates that need manual review, especially missing postal code or ambiguous room count.
- Blocked sources that could not be checked because of bot protection, CAPTCHA, HTTP errors, or access restrictions.
- Files changed.
- Proposed commit message.

Do not claim a file has been committed unless a GitHub write action has actually succeeded.

## Commit style

Use clear, boring commit messages.

Examples:

- `Add property watcher instructions and rental skill`
- `Switch rental output to compiled HTML`
- `Add rental listings from daily search`
- `Update rental listing details`

Prefer one logical change per commit unless the user asks otherwise.

## Do not do these things

- Do not bypass bot protection, CAPTCHA, rate limits, logins, paywalls, or blocked pages.
- Do not stop the whole run because one source is blocked; record the blocked source, continue with other sources, and report it at the end.
- Do not run multiple simultaneous requests to the same domain.
- Do not flood listing websites with requests.
- Do not add listings outside `H4H` or `H8P` to the accepted table.
- Do not reject a listing only because size is missing or obviously defaulted to `1 sqft`.
- Do not include less-than-900-sqft listings when a plausible size is available.
- Do not include studios, bachelor apartments, 1-room, or 1-bedroom listings.
- Do not ignore the free-text description when structured fields are missing.
- Do not fabricate postal codes, addresses, square footage, floor, laundry, courtyard, listing dates, or added dates.
- Do not silently change table schemas.
- Do not commit to GitHub before review when the user explicitly asks to review first.

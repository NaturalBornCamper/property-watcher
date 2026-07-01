# AGENTS.md

## Project purpose

This repository maintains the source files and skills for filtering property listings into a small, useful watch list.

The project is not a general real-estate crawler and is not intended for resale, lead generation, competitive scraping, or any commercial use. The goal is to save personal time by filtering out misleading or irrelevant rental and purchase listings.

The current active workflow is rental filtering. Future workflows may add purchase filtering for a forever-home search, but all property workflows should share the same conservative extraction, throttling, deduplication, and review principles.

## Canonical files

Primary files:

- `rental-listings.md` - accepted rental listings table.
- `rental-listings-changelog.md` - newest-first changelog for rental updates.
- `AGENTS.md` - project instructions and source of truth for agents.
- `CLAUDE.md` - Claude-specific entry point that should reference this file instead of duplicating these rules.
- `skills/rental-property-filter/SKILL.md` - current ChatGPT Skill for rental property filtering.

Future supporting files may include more property-type tables, skills, scripts, notes, or templates. Keep this file as the repository-wide source of truth when rules overlap.

## Source of truth

When updating listing tables, use the repository Markdown files as the source of truth for accepted listings and prior decisions.

Use listing websites, public listing pages, and public newsletter/search-alert HTML only as sources for current property data. Do not assume rendered website summaries are complete. Listing cards often omit floor, laundry, courtyard, square footage, postal code, or exact address details.

Prefer official listing details from the listing page when available. Use search-result cards only when they contain enough reliable information to decide eligibility.

## Property intake sources

Supported inputs:

- Listing-result page URLs already pre-filtered by the user on a property website.
- Individual listing URLs.
- Public URLs containing HTML from a search-alert newsletter.
- Raw HTML pasted by the user.

For newsletter HTML, extract listing URLs, listing cards, prices, dates, and summary details from the HTML before deciding whether to fetch detail pages.

## Request etiquette and anti-blocking rules

Be conservative with requests.

- Do not send high-frequency requests.
- Fetch pages sequentially by default.
- Wait at least 5 seconds between requests to the same domain when using a live browser or HTTP client.
- Use longer waits, around 10 seconds, when opening many individual detail pages from the same site.
- Follow detail-page links only when the list page or newsletter card does not contain enough information to decide eligibility or fill important fields.
- Deduplicate URLs before fetching detail pages.
- Stop or ask for review if a site returns bot protection, CAPTCHA, 403, 429, or unusual blocking behavior.
- Do not attempt to bypass bot protection, paywalls, logins, rate limits, IP limits, or access controls.
- Do not use multiple IPs, proxy rotation, credential stuffing, or browser fingerprint evasion.
- Prefer public pages and the user's public newsletter mirror URLs.

The purpose is personal filtering, not bulk scraping.

## Shared property fields

Extract these fields whenever available:

1. `DATE LISTED` - listing publication date or best available relative date normalized to `YYYY-MM-DD` when possible.
2. `PRICE` - rental monthly price in CAD for rental workflows.
3. `ROOMS` - bedrooms or rooms, preserving the source label when ambiguous.
4. `SIZE` - living area in square feet.
5. `LOCATION / POSTAL CODE` - exact address, postal code, borough/neighborhood, or other location text.
6. `FLOOR` - floor, level, basement, ground floor, elevator context, or unknown.
7. `LAUNDRY` - in-unit hookups, washer/dryer, shared laundry, none, or unknown.
8. `COURTYARD` - courtyard, yard, shared yard, balcony/patio only, none, or unknown.
9. `URL` - canonical listing URL.
10. `NOTES` - concise uncertainty notes or source-specific caveats.

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
- If the postal code is missing after checking the detail page, keep the listing out of `rental-listings.md` and mention it separately as an unresolved candidate if it otherwise looks promising.

Room handling:

- Prefer the source's bedroom count when available.
- If the source uses a different room notation, preserve the source label in the table and explain the interpretation in `NOTES` when needed.
- Reject studios, bachelor apartments, 1-room, and 1-bedroom listings.
- Treat ambiguous room counts conservatively and keep unresolved cases out of the accepted table until clarified.

Size handling:

- If a plausible size is available and it is less than 900 sqft, reject the listing.
- If size is missing, keep evaluating the listing; missing size alone is not a rejection.
- Treat obvious platform defaults such as `1 sqft`, `0 sqft`, or similarly impossible values as `Unknown`, not as real size.
- If a listing says less than 900 sqft in prose or structured data, reject it even if another field is missing.

## Rental table schema

`rental-listings.md` uses this table schema:

```markdown
|DATE LISTED|PRICE|ROOMS|SIZE|LOCATION / POSTAL CODE|FLOOR|LAUNDRY|COURTYARD|URL|NOTES|
|:-|:-|:-|:-|:-|:-|:-|:-|:-|:-|
```

Every row must have exactly ten columns:

1. `DATE LISTED`
2. `PRICE`
3. `ROOMS`
4. `SIZE`
5. `LOCATION / POSTAL CODE`
6. `FLOOR`
7. `LAUNDRY`
8. `COURTYARD`
9. `URL`
10. `NOTES`

Use short cell values. Escape literal `|` characters inside table cells as `\|`.

For the `URL` cell, use a Markdown link with a stable display label:

```markdown
[Listing](https://example.com/listing/123)
```

## Sorting and deduplication

Keep `rental-listings.md` sorted by `DATE LISTED` newest first.

When dates are equal, sort newly discovered listings above older rows from the same date. Put `Unknown` dates below dated listings unless the user explicitly asks for another behavior.

Deduplicate before adding rows. Treat listings as likely duplicates when they share any of these:

- same canonical URL;
- same listing ID;
- same exact address and price;
- same address with very similar photos/details from the same source.

If a listing already exists but has improved details, update only the relevant cells and mention the update in the changelog.

## Updating `rental-listings.md`

For a normal rental update, preserve the file as-is except for the specific update being made.

Only change:

1. Add newly accepted listing rows.
2. Update existing rows when newly fetched details clarify unknown fields.
3. Update the visible `LAST UPDATED` date.
4. Re-sort the table newest first.

Do not rewrite unrelated rows, change the schema, or perform opportunistic cleanup unless the user explicitly asks.

Before final output or commit, verify that every accepted row satisfies postal-code, room, and size rules.

## Updating `rental-listings-changelog.md`

`rental-listings-changelog.md` is newest-first.

Use this date format:

```markdown
**YYYY-MM-DD**
```

Use short changelog lines:

- `Added 123 Example Street rental listing`
- `Updated floor for 123 Example Street`
- `Rejected duplicate listing from Kijiji`

Do not over-explain in the changelog. Put detailed reasoning in the response to the user when useful.

## Review workflow

For filtering tasks, provide:

- Accepted listings added or updated.
- Rejected listings with short rejection reasons when they were close or ambiguous.
- Unresolved candidates that need manual review, especially missing postal code or ambiguous room count.
- Files changed.
- Proposed commit message.

Do not claim a file has been committed unless a GitHub write action has actually succeeded.

## Commit style

Use clear, boring commit messages.

Examples:

- `Add property watcher instructions and rental skill`
- `Add rental listings table`
- `Add rental listings from daily search`
- `Update rental listing details`

Prefer one logical change per commit unless the user asks otherwise.

## Do not do these things

- Do not bypass bot protection, CAPTCHA, rate limits, logins, paywalls, or blocked pages.
- Do not flood listing websites with requests.
- Do not add listings outside `H4H` or `H8P` to `rental-listings.md`.
- Do not reject a listing only because size is missing or obviously defaulted to `1 sqft`.
- Do not include less-than-900-sqft listings when a plausible size is available.
- Do not include studios, bachelor apartments, 1-room, or 1-bedroom listings.
- Do not fabricate postal codes, addresses, square footage, floor, laundry, courtyard, or listing dates.
- Do not silently change table schemas.
- Do not commit to GitHub before review when the user explicitly asks to review first.

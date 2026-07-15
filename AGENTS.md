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
- `skills/rental-property-filter/SKILL.md` - ChatGPT Skill for rental property filtering (ChatGPT/manual runs).
- `routines/rental-watch.md` - scheduled Claude routine for unattended rental filtering runs; the prompt stored in Claude Routines only points here and supplies the source URLs.
- `routines/rental-listing-check-log.tsv` - scheduled routine detail-check cache/log, keyed by raw candidate listing URL.
- `.github/workflows/pages.yml` - GitHub Pages deployment workflow; it publishes `docs/` only when `docs/index.html` changes, plus manual workflow dispatch.
- `email-pipe/` - cPanel email-pipe scripts that publish search-alert newsletter emails as public HTML mirror pages (see `email-pipe/README.md`).

Future supporting files may include more property-type outputs, skills, scripts, notes, templates, or deployment workflows. Keep this file as the repository-wide source of truth when rules overlap.

## Compiled output location

Use `docs/index.html` as the compiled output file.

Reasoning:

- ChatGPT can update GitHub repository files directly.
- GitHub can serve `docs/index.html` through GitHub Pages when Pages is enabled for the `main` branch and `/docs` folder.
- GitHub Pages deployment is handled by `.github/workflows/pages.yml`; keep it path-filtered to `docs/index.html` so unrelated instruction, skill, README, or routine-log commits do not deploy the site.
- If the user wants the same file on shared hosting later, add a GitHub Actions workflow that uploads `docs/index.html` to Interserver/cPanel using repository secrets.

Do not store FTP, SFTP, SSH, cPanel, or hosting passwords in this repository. Use GitHub Actions secrets for deployment credentials if shared-hosting upload is added later.

## Source of truth

When updating accepted listings, use `docs/index.html` as the source of truth for current accepted listings and prior decisions.

Use listing websites, public listing pages, and public newsletter/search-alert HTML only as sources for current property data. Do not assume rendered website summaries are complete. Listing cards often omit floor, laundry, courtyard, square footage, postal code, exact address, thumbnail image, or date details.

Prefer the user's newsletter-generated HTML mirror as the default intake source for discovering candidates. Card data from newsletters and search pages is used to discover candidates and to reject clear failures, never as the final source of a table row: every new, uncached listing headed for either table gets its detail page fetched (see the detail-page rules under request etiquette).

## Property intake sources

Supported inputs, in preferred order:

- Public URLs containing newsletter-generated HTML from a search-alert email.
- A newsletter-mirror root URL whose `index.html` lists one or more numbered files per site for the current batch.
- Raw newsletter/search-alert HTML pasted by the user.
- Individual listing URLs, as a rare fallback or explicit user-provided exception.
- Listing-result page URLs, as a rare fallback or explicit user-provided exception.

For newsletter HTML, extract listing URLs, thumbnail image URLs, listing cards, prices, dates, and summary details from the HTML first. Card data may reject a candidate outright, but any new, uncached candidate headed for a table row still gets its detail page fetched.

The email-pipe mirror publishes each alert email as a numbered file per sender domain and day (for example `centris-1.html`, `centris-2.html`), because alert sites send one email per saved search. The mirror root serves an auto-generated `index.html` listing the currently published files, and an `archive/` folder holds previous days. When given the mirror root URL, read `index.html` and process every listed file.

## Scheduled rental check log

Scheduled rental runs use `routines/rental-listing-check-log.tsv` as a small persistent cache so the routine does not re-fetch the same detail pages every run.

The log is tab-separated, has no header, and uses this row shape:

```text
raw_url<TAB>canonical_id_or_url<TAB>date_checked<TAB>decision<TAB>reason
```

- `raw_url` is the exact candidate listing URL discovered in a newsletter or search-result source, before canonicalization or tracking cleanup. This is the lookup key.
- `canonical_id_or_url` is the best canonical listing ID or canonical listing URL known after deduplication or detail extraction; use the raw URL if nothing better is known.
- `date_checked` is normalized to `YYYY-MM-DD`.
- `decision` must be one of `accepted`, `rejected`, or `unresolved`.
- `unresolved` means the detail page was successfully checked and the listing belongs in the unresolved candidates table because required property facts are missing or ambiguous. It never means blocked, unreachable, CAPTCHA, proxy failure, or any other access failure.
- `reason` is a concise decision reason with no tabs or newlines.

At the start of a scheduled run, read the log and use the latest row for each raw URL. After building and deduplicating the current candidate list, skip detail-page fetches for raw URLs already logged with a conclusive `accepted`, `rejected`, or `unresolved` decision. This cache skip must not create or update a table row by itself.

Do not cache blocked or unreachable sources as conclusive decisions. Report them as blocked/unreachable instead, and retry them on later runs.

After `docs/index.html` has been updated and accepted rows have been validated, append new conclusive decisions from the run to `routines/rental-listing-check-log.tsv` before committing. Append only new raw URLs that do not already have a conclusive row.

## Proxy Page Server

Listing sites and newsletter mirrors often use long tracking URLs that assistants refuse to open, or serve heavy HTML. The user runs a Proxy Page Server that fetches a target page and returns its content as markdown, text, or HTML.

- Configuration comes from environment variables: `PROXY_PAGE_SERVER_URL` (endpoint) and `PROXY_PAGE_SERVER_API_KEY` (sent as header `X-API-Key`). Never store the endpoint or key in this repository.
- Fetch a page with a POST to the endpoint, headers `X-API-Key`, `Content-Type: application/json` (describes the request body being sent; the response is the page content in the requested format, not JSON), and a normal browser `User-Agent` (Cloudflare may block empty or tool-like agents), and this JSON body:

```json
{
  "url": "<target page URL>",
  "dom_unchanged_ms": 0,
  "output_format": "markdown"
}
```

- Prefer `"markdown"` output. Re-request a single page as `"html"` only when the markdown is missing something the page should have, such as thumbnail image URLs. Retry once with `"dom_unchanged_ms": 500` when a page returns clearly incomplete client-rendered content.
- Every proxy response includes the response header `proxy-fetcher-blocked-suspected` (boolean). Always capture and check response headers (for example with curl `-D`). When the header is `true`, the proxy suspects the target page hit bot protection or a similar block: treat the returned content as invalid, do not extract listing data from it, record the source as blocked, and report it at the end.
- Scheduled routine runs must fetch all target pages through the proxy; the one allowed exception is the newsletter-mirror index, which is light HTML and may be fetched directly. Interactive runs should use the proxy whenever both environment variables are set.
- When fetching through the proxy, apply all per-domain request-etiquette rules below to the target domain inside the request body, not to the proxy's own domain.
- A block from the proxy itself (401/403, Cloudflare) and a target-site block passed through the proxy are both blocked sources: record them, continue, and report them at the end.

## Request etiquette, concurrency, and blocked sources

Be conservative with requests, but use safe parallelism across different domains.

- Do not send high-frequency requests.
- Allow at most one active request at a time per domain.
- Requests to different domains may run in parallel when the tool environment supports it.
- Example: one request to `domain-a.com`, one request to `domain-b.com`, and one request to `domain-c.com` may run at the same time; do not run three simultaneous requests to `domain-a.com`.
- Wait at least 5 seconds between requests to the same domain when using a live browser or HTTP client.
- Use longer waits, around 10 seconds, when opening many individual detail pages from the same site.
- Always fetch the detail page of every new, uncached candidate that survives card-level rejection — even when the card already shows postal code, rooms, and price. Cards are only good enough to reject; the detail page is the source for size, floor, laundry, courtyard, year built, exact address, date listed, the free-text description, and any other table field.
- Skip the detail page only for candidates the card data already rejects outright (wrong postal prefix, real size under 900 sqft, 1 bedroom or fewer, clear below-grade wording), or for scheduled-run candidates whose raw URL is already conclusively checked in `routines/rental-listing-check-log.tsv`.
- When a detail page links to a fuller external broker sheet (for example Centris's `See detailed sheet` link to the broker's own website), follow that link too and merge its details into the listing's fields — posters often leave most of the information on the broker page instead of the listing itself. Per-domain etiquette applies to the broker's domain like any other, and scheduled runs fetch it through the proxy like any other target page.
- Build the complete candidate list from all sources first, then deduplicate it (across sources, against `docs/index.html`, and for scheduled runs against `routines/rental-listing-check-log.tsv`) before fetching any detail page, so the same listing is never requested twice.
- If a site returns bot protection, CAPTCHA, 403, 429, unusual blocking behavior, or an access error, record the blocked source and continue with the next source or next domain.
- Report blocked sources at the end with the URL, domain, observed block type, and what information could not be checked.
- Do not attempt to bypass bot protection, paywalls, logins, rate limits, IP limits, CAPTCHA, or access controls.
- Do not use multiple IPs, proxy rotation, credential stuffing, or browser fingerprint evasion.
- Prefer public pages and the user's public newsletter mirror URLs.
- Geocoding lookups (Nominatim) follow the same per-domain etiquette: at most one request at a time, at least 1 second between requests, a descriptive `User-Agent`, and only for addresses that actually need postal-code resolution. The lookup is a light JSON API and may be fetched directly, without the Proxy Page Server.

The purpose is personal filtering, not bulk scraping.

## Shared property fields

Extract these fields whenever available. Information may appear in structured listing fields, listing cards, page metadata, image captions, tables, or the free-text description.

1. `DATE ADDED` - date the listing was added to the compiled table, normalized to `YYYY-MM-DD`.
2. `DATE LISTED` - listing publication date or best available relative date normalized to `YYYY-MM-DD` when possible.
3. `PRICE` - rental monthly price in CAD for rental workflows.
4. `ROOMS` - bedrooms or rooms, preserving the source label when ambiguous.
5. `SIZE` - living area in square feet.
6. `LOCATION / POSTAL CODE / MAP` - exact address, postal code, borough/neighborhood, or other location text, linked to Google Maps when enough location data exists.
7. `FLOOR` - floor, level, basement, ground floor, elevator context, or unknown.
8. `LAUNDRY` - in-unit hookups, washer/dryer, shared laundry, none, or unknown.
9. `COURTYARD` - courtyard, yard, shared yard, balcony/patio only, none, or unknown.
10. `YEAR BUILT` - building construction year (or date, when the source gives one), from structured fields or the free-text description.
11. `LISTING` - main listing thumbnail image linked to the canonical listing URL.
12. `NOTES` - concise uncertainty notes or source-specific caveats.

Do not fabricate missing fields. Leave the table cell empty when a field cannot be found after reasonable inspection; an empty cell means the information was looked for and not found.

## Current rental eligibility rules

A rental listing is accepted only when it satisfies all current rental filters:

1. Postal code prefix must be `H4H` or `H8P`.
2. Rooms must be at least 2 using the clearest available room or bedroom count.
3. Size must be at least 900 square feet when a real size is available.
4. The unit must not be a basement, semi-basement, or partly below-grade apartment.

Postal code handling:

- Normalize postal codes to uppercase.
- Accept `H4H` and `H8P` prefixes with or without a space in the full postal code.
- Do not accept a listing only because it says Verdun, LaSalle, Montreal, or a nearby neighborhood. The postal code prefix or an exact address that can reliably establish the prefix is required.
- When the source gives an exact street address (street number + street name + borough/city) but no postal code, resolve the postal code from the address with a geocoding lookup before treating it as missing. Use the Nominatim search API (`https://nominatim.openstreetmap.org/search?format=jsonv2&addressdetails=1&countrycodes=ca&limit=1&q=<URL-encoded address>`) with a descriptive `User-Agent`, and use the returned `postcode` only when the match corresponds to the same street number and street. Note `Postal code resolved from address` in `NOTES` so the derivation is auditable.
- A postal code resolved by geocoding an exact address is a lookup, not fabrication. Guessing a postal code without a lookup remains fabrication and is forbidden.
- If the geocoding lookup fails, is ambiguous, or returns only a street- or city-level match, keep the listing out of the accepted table and treat the postal code as still missing.
- If the postal code is missing after checking available details (including the geocoding lookup when an exact address exists), keep the listing out of the accepted table and put it in the unresolved candidates table if it otherwise looks promising.

Room handling:

- Prefer the source's bedroom count when available.
- Check the free-text description for room count when structured fields are missing or ambiguous.
- If the source uses a different room notation, preserve the source label in the table and explain the interpretation in `NOTES` when needed.
- Reject studios, bachelor apartments, 1-room, and 1-bedroom listings.
- Treat ambiguous room counts conservatively and keep unresolved cases in the unresolved candidates table until clarified.

Size handling:

- Check both structured fields and the free-text description for square footage.
- If a plausible size is available and it is less than 900 sqft, reject the listing.
- If size is missing, keep evaluating the listing; missing size alone is not a rejection.
- Treat obvious platform defaults such as `1 sqft`, `0 sqft`, or similarly impossible values as unknown (empty size cell), not as real size.
- If a listing says less than 900 sqft in prose or structured data, reject it even if another field is missing.

Basement and demi-sous-sol handling:

- Check structured floor fields, listing titles, amenities, tags, and free-text descriptions for basement indicators.
- Reject listings described in French as `demi sous-sol`, `demi-sous-sol`, `sous-sol`, `semi sous-sol`, `semi-sous-sol`, or `rez-de-jardin` when the context indicates a partly below-grade unit.
- Reject listings described in English as `basement`, `basement apartment`, `semi-basement`, `semi basement`, `half-basement`, `half basement`, `partly below grade`, `partially below grade`, `below grade`, `partly underground`, `partially underground`, or `garden level` when the context indicates a partly below-grade unit.
- Do not reject a listing only because it mentions basement storage, basement parking, basement locker access, or a building basement amenity. The exclusion is for the dwelling unit itself being fully or partly below ground.
- If the wording is ambiguous, keep the listing out of the accepted table and put it in the unresolved candidates table rather than accepting it.

## Thumbnail handling

Use the main thumbnail image for the `Listing` column.

Preferred thumbnail sources, in order:

1. The primary image from the newsletter-generated HTML listing card.
2. The primary image from a user-provided search-result page listing card.
3. The first listing photo or `og:image` from the detail page, which is fetched for new, uncached candidates headed to either table.
4. A linked visual fallback only when no source thumbnail is available.

Do not fetch a detail page solely to improve a thumbnail for a listing the card data already rejects.

Preserve the source image URL when it is public and stable enough for browser display. Do not download or rehost listing images unless the user explicitly asks for a separate image-mirroring workflow.

Every listing image must be inside the listing link. Use descriptive `alt` text such as the address or `Listing thumbnail for 123 Example St`. Use `loading="lazy"` and `referrerpolicy="no-referrer"` on thumbnail images.

If no source thumbnail is available, use a linked visual fallback such as a small `No image` placeholder, keep the listing link, and note `Thumbnail unavailable from source` in `NOTES` when helpful.

## Compiled HTML table schema

`docs/index.html` contains the accepted rental table and, below it, a separate unresolved candidates table.

Both tables must include these columns, in this order:

1. `Date added`
2. `Date listed`
3. `Price`
4. `Rooms`
5. `Size`
6. `Location / postal code / map`
7. `Floor`
8. `Laundry`
9. `Courtyard`
10. `Year built`
11. `Listing`
12. `Notes`

Each listing row in either table must have exactly twelve cells. Use the construction year (for example `1962`) in `Year built`, or leave the cell empty when the source does not state it.

Use short cell values. Escape HTML special characters in user-visible text.

Use a stable named `target` value for every external link. Do not use `_blank` for listing or map links. A stable named target opens a new tab/window the first time and reuses the same tab/window when the same link is clicked again.

For the listing cell, use a linked thumbnail image with a stable target derived from the canonical listing URL or listing ID:

```html
<a href="https://example.com/listing/123" target="listing-123" class="listing-link">
  <img src="https://example.com/photo.jpg" alt="Listing thumbnail for 123 Example St" class="listing-thumb" loading="lazy" referrerpolicy="no-referrer">
</a>
```

For the location cell, link the visible address/location text to Google Maps when there is enough location information to form a useful search. Use the most precise available query in this order: exact address with postal code, exact address, full postal code, partial postal code plus city/neighborhood, then neighborhood/borough only if nothing more precise exists. URL-encode the Google Maps query and use a stable target derived from the normalized map query:

```html
<a href="https://www.google.com/maps/search/?api=1&amp;query=123%20Example%20St%2C%20Montreal%2C%20QC%20H4H%201A1" target="map-123-example-st-h4h-1a1">123 Example St, H4H 1A1</a>
```

If no useful location information exists, leave the cell empty.

Leave the cell empty (`<td></td>`) for unavailable values; do not write `Unknown` or any other placeholder text. An empty cell signals the information was looked for and not found.

## Unresolved candidates table

Below the accepted table, `docs/index.html` keeps a second table for unresolved candidates: listings that look promising but cannot be fully filtered yet — usually a missing postal code, no clear (closed) bedroom count, or ambiguous basement/semi-basement wording.

- Same twelve columns as the accepted table, with empty cells for missing values.
- `NOTES` must state exactly what is missing or ambiguous, for example `No postal code in listing` or `Bedroom count unclear`.
- Only plausible candidates belong here. Listings that positively fail a filter (wrong postal prefix, under 900 sqft with a real size, 1 bedroom or fewer, below-grade unit) are rejected, not unresolved.
- When later information resolves a row, move it to the accepted table preserving its original `Date added`, or remove it if it now fails a filter.
- Keep this table sorted the same way as the accepted table.
- When the table has no rows, keep the single placeholder row `<tr><td colspan="12" class="empty">No unresolved candidates.</td></tr>`; remove it when adding the first real row and restore it if the table empties again.

## Sorting and deduplication

Keep both listings tables sorted by `Date added` newest first, then by `Date listed` newest first.

Within the same `Date added` group, put listings with an empty `Date listed` cell below dated listings unless the user explicitly asks for another behavior.

Build the complete candidate list from all sources (newsletter files and search pages) and deduplicate it before fetching any listing page — the same listing often appears in more than one source. For scheduled runs, apply `routines/rental-listing-check-log.tsv` after deduplication and before fetching detail pages. Never fetch the same listing URL twice in a run.

Deduplicate before adding rows, checking both the accepted table and the unresolved candidates table. Treat listings as likely duplicates when they share any of these:

- same canonical URL;
- same listing ID;
- same exact address and price;
- same address with very similar photos/details from the same source.

If a listing already exists but has improved details, update only the relevant cells and preserve its original `Date added` unless the user explicitly asks otherwise.

## Updating `docs/index.html`

For a normal rental update, preserve the file as-is except for the specific update being made.

Only change:

1. Add newly accepted listing rows.
2. Add or update rows in the unresolved candidates table, and move rows to the accepted table when new details resolve them.
3. Update existing rows when newly fetched details clarify unknown fields.
4. Update the visible `Last updated` date.
5. Re-sort both tables by `Date added` newest first, then `Date listed` newest first.
6. Update the blocked/unresolved notes section when useful.

Do not rewrite unrelated rows, change the schema, or perform opportunistic cleanup unless the user explicitly asks.

Before final output or commit, verify that every accepted row satisfies postal-code, room, size, and basement/semi-basement exclusion rules.

## Commit behavior

Automatic commits for normal rental filtering/update runs are limited to `docs/index.html` and, for scheduled runs, `routines/rental-listing-check-log.tsv`. Update `docs/index.html`, append the scheduled check log when applicable, and commit directly after best-effort validation, without asking for confirmation unless the user explicitly requests review-only or no-commit behavior.

Routine commits of `docs/index.html` and `routines/rental-listing-check-log.tsv` must be pushed to the `main` branch: GitHub deploys the live website from `main`, so output left on a session branch (for example `claude/...`) or in a pull request is not deployed. Never push routine output anywhere other than `main`.

Prefer one commit containing both files. If the available GitHub write tool can commit only one file at a time, commit and push `docs/index.html` first, then commit and push `routines/rental-listing-check-log.tsv` only after the index commit succeeds. This keeps the visible output ahead of the routine-state log if GitHub Pages reacts to each commit separately.

For every other file (`AGENTS.md`, `CLAUDE.md`, skills, routine instruction files, workflows, scripts), do not commit automatically. When instructions or workflow defaults change, update `AGENTS.md` and the affected skill/routine/workflow files directly, then present the changes for review with a proposed commit message and let the user commit manually.

If the available GitHub tool writes one file per commit, make sequential commits in the order above and report each commit SHA.

## Review workflow

For filtering tasks, provide:

- Accepted listings added or updated.
- Rejected listings with short rejection reasons when they were close or ambiguous.
- Unresolved candidates that need manual review, especially missing postal code, ambiguous room count, ambiguous basement/semi-basement wording, or missing thumbnail when no source image exists.
- Scheduled check-log rows appended, with a count and decision breakdown when applicable.
- Blocked sources that could not be checked because of bot protection, CAPTCHA, HTTP errors, or access restrictions.
- Files changed.
- Commit message and commit SHA when committed; otherwise a proposed commit message.

Do not claim a file has been committed unless a GitHub write action has actually succeeded.

## Commit style

Use clear, boring commit messages.

Examples:

- `Add property watcher instructions and rental skill`
- `Switch rental output to compiled HTML`
- `Add rental listings from daily search`
- `Update rental listing details`
- `Update rental filtering rules`
- `Use thumbnails for listing links`

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
- Do not include basement, semi-basement, demi-sous-sol, or otherwise partly below-grade dwelling units.
- Do not ignore the free-text description when structured fields are missing.
- Do not add or update a table row from card data alone; fetch the detail page (and the linked broker sheet when one exists) for every new, uncached candidate headed to either table. Only card-level rejections and scheduled-run raw-URL check-log hits skip the detail fetch.
- Do not fabricate postal codes, addresses, square footage, floor, laundry, courtyard, construction years, listing dates, added dates, Google Maps links, or thumbnail image URLs.
- Do not silently change table schemas.
- Do not ask for commit approval on normal filtering/update runs unless the user explicitly requests review-only or no-commit behavior.

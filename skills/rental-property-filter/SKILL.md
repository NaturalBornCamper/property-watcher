---
name: rental-property-filter
description: Filter rental property listings for the Property Watcher project and maintain the compiled tables in docs/index.html. A parameterized workflow — the caller (usually a routine) supplies the sources (search-result pages, a newsletter mirror, pasted HTML, or listing URLs) plus the filter thresholds it cares about (allowed postal-code prefixes, minimum bedrooms, minimum size, price range, below-grade exclusion), and the skill fetches, verifies details on each listing's own page, deduplicates, applies whichever filters were given, and writes accepted and unresolved rows with thumbnails. Use for any rental search; works interactively or as a scheduled/unattended run. Any agent (Claude, Codex, OpenClaw, ChatGPT) can load it.
---

# Rental Property Filter

Filter rental listings for the Property Watcher repository and keep `docs/index.html` current. This skill is a reusable **function**: it has no hardcoded neighborhood, size, price, or bedroom values. The caller passes those as parameters (see below), so the same skill serves the Verdun/LaSalle routine today and any other rental search later. A separate skill will cover property *purchases* with the same structure.

`AGENTS.md` is the repository-wide source of truth. Follow it for shared infrastructure — the Proxy Page Server, request etiquette and concurrency, the Nominatim geocoding lookup, blocked-source handling, commit/push policy, and the do-not list. This skill does not restate those; it references them and adds the rental workflow: parameters, intake, deduplication, filtering, field extraction, the compiled table schema, thumbnails, and the scheduled-run procedure.

## Parameters (the caller supplies these)

The routine (or interactive user) invoking this skill provides the values below. This skill defines only their meaning and how they are applied — never their values.

| Parameter | Meaning |
|---|---|
| `search_urls` | Search-result page URLs to scan for candidate listings. |
| `newsletter_mirror_root` | Root URL of the newsletter mirror whose `index.html` lists the current batch of alert files. |
| `postal_code_prefixes` | Allowed postal-code prefixes (e.g. `H4H`, `H8P`). Accept only listings whose postal prefix matches one, and require a postal code that can be established (from the listing or by geocoding an exact address). |
| `min_bedrooms` | Minimum bedroom/room count. |
| `min_size_sqft` | Minimum living area, in square feet, when a real size is available. |
| `price_min` / `price_max` | Monthly-rent bounds in CAD, applied when a price is known. |
| `exclude_below_grade` | When true, reject basement / semi-basement / demi-sous-sol / partly-below-grade dwelling units. |

**Semantics — an omitted filter is not enforced.** Apply each filter only when its parameter is supplied; a filter the caller leaves out simply does not constrain the results (another routine reusing this skill may supply a different set). At least one source parameter (`search_urls` or `newsletter_mirror_root`, or an interactive input) must be present, or there is nothing to do. A listing is **accepted** only when it passes every supplied filter. When a supplied filter cannot be evaluated because the needed fact is missing or ambiguous after checking the detail page (and, for postal code, the geocoding lookup), the listing is **unresolved**, not accepted.

## Modes

- **Interactive run** — a person supplies the input and parameters (often pasted newsletter HTML or a URL, with filters stated in the request or implied by the existing table) and watches. Use the proxy whenever `PROXY_PAGE_SERVER_URL` and `PROXY_PAGE_SERVER_API_KEY` are set.
- **Scheduled / unattended run** — no human is present; the routine file supplies the sources and filter parameters. The proxy and the check-log cache are mandatory, and the run ends by committing and pushing to `main`. See "Scheduled / unattended runs" at the end of this file. Everything else on this page applies to both modes.

## Intake sources

Candidates come from the source parameters, plus any interactive input, in preferred order:

1. `newsletter_mirror_root` — its `index.html` lists one or more numbered files per site for the current batch (for example `centris-1.html`, `centris-2.html`, because alert sites send one email per saved search). Read the index and process every file it lists. The index is light HTML and may be fetched directly; the listed files can be heavy, so fetch those through the proxy as markdown.
2. Public URLs containing newsletter-generated HTML from a search-alert email.
3. `search_urls` — listing-result pages to scan.
4. Raw newsletter/search-alert HTML pasted into the conversation (interactive).
5. Individual listing URLs (interactive), as a rare fallback or explicit exception.

Prefer newsletter-generated HTML as the normal intake source. For newsletter HTML, extract listing URLs, thumbnail image URLs, cards, prices, dates, and summary details from the HTML first. Card data may reject a candidate outright, but any new, uncached candidate headed for a table row still gets its detail page fetched.

## Build the candidate list, then deduplicate

Build the complete candidate list from all sources before fetching any detail page — the same listing often appears in more than one source. For each candidate record the raw URL, canonical URL, listing ID when visible, thumbnail URL, price, rooms, size, location/postal code, dates, and any floor/laundry/courtyard/year-built hints.

Then deduplicate before fetching or adding rows, checking both tables in `docs/index.html`. Treat listings as likely duplicates when they share any of:

- the same canonical URL;
- the same listing ID;
- the same exact address and price;
- the same address with very similar photos/details from the same source.

Never fetch the same listing URL twice in a run. For scheduled runs, also apply the check log after deduplication and before fetching (see the scheduled section).

## Detail pages are mandatory

Card data is only good enough to **reject**. It never accepts a listing and never fills a table row.

- Fetch the detail page of every new, uncached candidate that survives card-level rejection — even when the card already shows postal code, rooms, and price. The detail page is the source for size, floor, laundry, courtyard, year built, exact address, date listed, and the free-text description.
- When the detail page links to a fuller external broker sheet (for example Centris's `See detailed sheet` link to the broker's own website), fetch that too and merge its details — posters often leave most of the information on the broker page. Per-domain etiquette applies to the broker's domain like any other.
- Skip the detail page only for candidates the card data already proves fail a supplied filter (a postal prefix outside `postal_code_prefixes`, a real size below `min_size_sqft`, a bedroom count below `min_bedrooms`, clear below-grade wording when `exclude_below_grade` is set, a price outside `price_min`/`price_max`), or — in scheduled runs — for raw URLs already conclusively decided in the check log.
- Do not fetch a detail page solely to improve a thumbnail for a listing the card already rejects.

## Applying the filters

Apply each of the following only when the caller supplied its parameter (see "Parameters"). A listing is **accepted** only when it passes every supplied filter. A listing that clearly fails a supplied filter is **rejected**. A listing that would pass but has a fact needed by a supplied filter still missing or ambiguous after the detail page (and geocoding, for postal code) is **unresolved**.

### Postal code — when `postal_code_prefixes` is set

- Accept only listings whose postal-code prefix is one of `postal_code_prefixes`. Normalize to uppercase; match with or without a space in the full code.
- A neighborhood or city name (Verdun, LaSalle, Montreal, …) is never enough — the postal prefix, or an exact address that reliably establishes it, is required.
- When the source gives an exact street address but no postal code, resolve it with the Nominatim lookup described in `AGENTS.md` before treating it as missing. Use the result only when it matches the same street number and street. Note `Postal code resolved from address` in `NOTES`.
- A prefix that is present and not in the list is a **rejection**. A postal code that is still missing after the lookup (or a lookup that is ambiguous or only street/city-level) makes the listing **unresolved**, not accepted.
- When `postal_code_prefixes` is not set, do not filter on location, and a missing postal code is not by itself a blocker.

### Bedrooms — when `min_bedrooms` is set

- Use the clearest available bedroom/room count; prefer the source's count and check the free-text description when structured fields are missing or ambiguous.
- Fewer than `min_bedrooms` is a **rejection** (e.g. with `min_bedrooms` = 2, reject studios, bachelors, 1-room, and 1-bedroom units).
- Preserve the source label when the notation differs, and explain the interpretation in `NOTES` when needed. An ambiguous count is **unresolved** until clarified.

### Size — when `min_size_sqft` is set

- Check both structured fields and the free-text description.
- A plausible real size below `min_size_sqft` is a **rejection** — even if another field is missing, and even when the under-size figure appears only in prose.
- Missing size is never by itself a rejection. Treat platform defaults such as `1 sqft`, `0 sqft`, or similarly impossible values as unknown (empty size cell), not as real size.

### Price — when `price_min` / `price_max` are set

- When a monthly rent is known, reject listings below `price_min` or above `price_max` (whichever bound was given).
- A missing price is not by itself a rejection; note the uncertainty.

### Below grade — when `exclude_below_grade` is true

- Check structured floor fields, titles, amenities, tags, and free-text descriptions.
- Reject French indicators — `demi sous-sol`, `demi-sous-sol`, `sous-sol`, `semi sous-sol`, `semi-sous-sol`, `rez-de-jardin` — when the context indicates a partly below-grade unit.
- Reject English indicators — `basement`, `basement apartment`, `semi-basement`, `semi basement`, `half-basement`, `half basement`, `partly below grade`, `partially below grade`, `below grade`, `partly underground`, `partially underground`, `garden level` — when the context indicates a partly below-grade unit.
- Do not reject only for basement storage, basement parking, basement locker access, or a building basement amenity. The exclusion is for the dwelling unit itself being fully or partly below ground.
- Ambiguous wording makes the listing **unresolved**, not accepted.

Only promising listings that cannot yet be fully filtered against a supplied parameter go in the unresolved table; a listing that positively fails any supplied filter is rejected.

## Shared property fields

Extract these whenever available, from structured fields, cards, page metadata, image captions, tables, or the free-text description. Do not fabricate; leave a cell empty when a field cannot be found after reasonable inspection.

1. `DATE ADDED` — date added to the compiled table, `YYYY-MM-DD`.
2. `DATE LISTED` — publication date or best available date, `YYYY-MM-DD` when possible.
3. `PRICE` — monthly rent in CAD.
4. `ROOMS` — bedrooms/rooms, preserving the source label when ambiguous.
5. `SIZE` — living area in square feet.
6. `LOCATION / POSTAL CODE / MAP` — exact address, postal code, borough/neighborhood, or other location text, linked to Google Maps.
7. `FLOOR` — floor, level, basement, ground floor, elevator context, or empty.
8. `LAUNDRY` — in-unit hookups, washer/dryer, shared laundry, none, or empty.
9. `COURTYARD` — courtyard, yard, shared yard, balcony/patio only, none, or empty.
10. `YEAR BUILT` — construction year from structured fields or description.
11. `LISTING` — main thumbnail image linked to the canonical listing URL.
12. `NOTES` — concise uncertainty notes or source caveats.

## Compiled table schema

`docs/index.html` holds the accepted rental table and, below it, a separate unresolved candidates table. Both use the same twelve columns, in this order:

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

Each row has exactly twelve cells. Use short values. Escape HTML special characters in visible text; HTML-escape `&` in URLs as `&amp;`; URL-encode map query parameters. Leave a cell empty (`<td></td>`) for unavailable values — never write `Unknown` or another placeholder. An empty cell signals the information was looked for and not found.

Use a stable named `target` for every external link; never `_blank`. A stable named target opens a new tab the first time and reuses it afterward.

Example accepted row:

```html
<tr>
  <td>2026-07-01</td>
  <td>2026-07-01</td>
  <td>$2,100/mo</td>
  <td>2 bedrooms</td>
  <td>950 sqft</td>
  <td><a href="https://www.google.com/maps/search/?api=1&amp;query=123%20Example%20St%2C%20Montreal%2C%20QC%20H4H%201A1" target="map-123-example-st-h4h-1a1">123 Example St, H4H 1A1</a></td>
  <td>2nd floor</td>
  <td>In-unit hookups</td>
  <td>Shared courtyard</td>
  <td>1962</td>
  <td>
    <a href="https://example.com/listing/123" target="listing-123" class="listing-link">
      <img src="https://example.com/photo.jpg" alt="Listing thumbnail for 123 Example St" class="listing-thumb" loading="lazy" referrerpolicy="no-referrer">
    </a>
  </td>
  <td>Size verified on detail page</td>
</tr>
```

For the listing cell, derive the target from the canonical listing URL or listing ID (`target="listing-123"`).

For the location cell, link the visible text to Google Maps when there is enough location data, using the most precise available query in this order: exact address with postal code, exact address, full postal code, partial postal code plus city/neighborhood, then neighborhood/borough only if nothing more precise exists. Derive the target from the normalized map query (`target="map-123-example-st-h4h-1a1"`). If no useful location data exists, leave the cell empty.

### Unresolved candidates table

- Same twelve columns, empty cells for missing values.
- `NOTES` must state exactly what is missing or ambiguous (for example `No postal code in listing` or `Bedroom count unclear`).
- Only plausible candidates belong here; positive filter failures are rejected instead.
- When later information resolves a row, move it to the accepted table preserving its original `Date added`, or remove it if it now fails a filter.
- Keep it sorted the same way as the accepted table.
- When it has no rows, keep the placeholder `<tr><td colspan="12" class="empty">No unresolved candidates.</td></tr>`; remove it when adding the first real row and restore it if the table empties again.

## Thumbnails

The `Listing` cell must show the main thumbnail image as the clickable link to the listing. Preferred sources, in order:

1. The primary image from the newsletter-generated HTML card.
2. The primary image from a user-provided search-result card.
3. The first listing photo or `og:image` from the detail page (fetched for every new, uncached candidate headed to either table).
4. A linked visual fallback only when no source thumbnail is available.

Preserve public source image URLs directly; do not download or rehost images unless the user asks for a separate image-mirroring workflow. Use descriptive `alt` text (the address, or `Listing thumbnail for 123 Example St`), `loading="lazy"`, and `referrerpolicy="no-referrer"`. If no thumbnail exists, use a small linked `No image` placeholder, keep the listing link, and note `Thumbnail unavailable from source` in `NOTES` when helpful.

## Sorting

Keep both tables sorted by `Date added` newest first, then `Date listed` newest first. Within the same `Date added` group, put listings with an empty `Date listed` cell below dated listings unless the user asks otherwise.

## Updating docs/index.html

For a normal update, preserve the file as-is except for the specific change. Only:

1. Add newly accepted rows to the accepted table.
2. Add or update rows in the unresolved table, and move rows to the accepted table when new details resolve them.
3. Update existing rows only when newly fetched details clarify unknown fields; preserve the original `Date added`.
4. Update the visible `Last updated` date.
5. Re-sort both tables.
6. Update the blocked/unresolved notes section when useful.

Do not rewrite unrelated rows, change the schema, or do opportunistic cleanup unless the user asks. Before output or commit, verify every accepted row passes every supplied filter (postal-code prefix, bedrooms, size, price, below-grade — each only if its parameter was given), and that its `Listing` cell holds a linked thumbnail or linked fallback.

**Files this skill maintains** (the only files it may auto-commit, per `AGENTS.md` → Commit behavior): `docs/index.html`, and — in scheduled runs — `routines/rental-listing-check-log.tsv`. It never writes any other file on a normal run.

## Review / report format

Provide:

- Accepted listings added or updated (address, price, one-line reason).
- Rejected listings with short reasons when they were close or ambiguous.
- Unresolved candidates needing manual review, stating what is missing.
- Blocked sources: URL, domain, observed block type, what could not be checked.
- Files changed, and the commit message and SHA when committed (or a proposed message when review-only).

Do not claim a file was committed unless a git write action actually succeeded.

---

## Scheduled / unattended runs

A scheduled run is triggered by the scheduling platform (ChatGPT scheduled task, Claude Code routine, or OpenClaw). The platform's stored prompt is only a one-line pointer to a routine file (for example `Follow routines/lasalle-verdun-rental-watch.prompt.md`); that version-controlled file names this skill and supplies the run's parameters (sources + filter thresholds). Work autonomously — there is no human to ask. Everything above still applies; this section adds only what a scheduled run needs.

### Preconditions

- Verify `PROXY_PAGE_SERVER_URL` and `PROXY_PAGE_SERVER_API_KEY` both exist. If either is missing, stop and report — do not fetch target pages directly or improvise endpoints/keys.
- If the prompt provides no source URLs, stop and report that instead of guessing sources.
- All target pages go through the proxy (see `AGENTS.md` → Proxy Page Server for the policy and `reference/proxy-page-server.md` for how to call it). The only fetches allowed to skip it are the newsletter-mirror index and the Nominatim lookup.

### Listing check log

`routines/rental-listing-check-log.tsv` is the persistent detail-check cache. Create it if it does not exist, starting with the header line.

The file is tab-separated. Its first line is a header naming the columns; every line after it is one row:

```text
raw_url<TAB>canonical_id_or_url<TAB>date_checked<TAB>decision<TAB>reason
```

- `raw_url` — the exact candidate listing URL discovered in a source, before canonicalization or tracking cleanup. This is the lookup key.
- `canonical_id_or_url` — the best canonical listing ID or URL known after deduplication/extraction; use the raw URL if nothing better is known.
- `date_checked` — the run date, `YYYY-MM-DD`.
- `decision` — exactly one of `accepted`, `rejected`, `unresolved`.
- `unresolved` means the detail page was successfully checked and the listing belongs in the unresolved table because required facts are missing or ambiguous. It never means blocked, unreachable, CAPTCHA, proxy failure, or any other access failure.
- `reason` — concise, no tabs or newlines.

Skip the header when reading; never treat it as a candidate row and never append a second one. Read the log at the start of every run and use the latest row for each raw URL. After deduplicating the candidate list and before fetching any detail page, skip any candidate whose raw URL already has a conclusive `accepted`, `rejected`, or `unresolved` decision. This skip is only a request-saving cache hit; it must not create or update a table row by itself.

Do not cache blocked or unreachable pages as conclusive decisions — report those as blocked/unreachable and retry them on later runs.

Append new rows only at the end of the run, after the `docs/index.html` update and accepted-row validation have succeeded, and before the commit. Append one row per candidate conclusively decided this run (including card-level rejections). Do not append duplicate rows for raw URLs that already have a conclusive entry. Appends always go after the last line.

### Procedure

1. Verify the environment variables and read the run's parameters (sources + filter thresholds) from the routine file.
2. Read the check log and build a lookup keyed by raw URL.
3. If `newsletter_mirror_root` is given, fetch its index (directly or through the proxy), then fetch every file it lists through the proxy as markdown and extract the links that redirect to listing pages.
4. Fetch each URL in `search_urls` through the proxy.
5. Build the complete candidate list from all sources.
6. Deduplicate: across sources, against both tables in `docs/index.html`, and — after that — skip raw URLs already conclusively checked in the check log. Never send the same listing to the proxy twice.
7. Apply the supplied filters to each remaining unique candidate using card data, for rejection only.
8. Fetch the detail page (and any linked broker sheet) of every surviving uncached candidate through the proxy, and extract every table field.
9. Re-apply the supplied filters with merged details. For candidates that would pass every filter except an unestablished postal code (only when `postal_code_prefixes` is set) and that have an exact street address, run the geocoding lookup before consigning them to the unresolved table.
10. Update `docs/index.html` per the rules above.
11. Verify every accepted row passes every supplied filter.
12. Append new conclusive decisions to the check log, then commit and push to `main`.

### Git (scheduled)

Commit only `docs/index.html` and `routines/rental-listing-check-log.tsv`, with a boring message (`Add rental listings from daily search`), and push to `main` on `origin` — see `AGENTS.md` → Commit behavior. Never create or push to a session branch and never open a pull request; if the environment started you on another branch, get the change onto `main` before pushing. If pushing to `main` fails, report the exact error and where the commit currently sits — do not fall back to another branch and never claim the change reached GitHub when it did not.

### Fetch scratch files

Write proxy response headers and bodies to a temp directory outside the repository (such as `/tmp`), one pair per fetch. These are ephemeral and must never be committed. Do not modify anything in the repository other than `docs/index.html` and `routines/rental-listing-check-log.tsv` during a scheduled run.

### End every scheduled run with a summary

- **Per-source coverage** — for every source (each search-result page and each newsletter file), report how many listings it presented and, of those, how many were newly fetched, rejected from card data, blocked/unreachable, or skipped because the check log already had them. The counts must reconcile (listings presented = fetched + card-rejected + blocked + cache-skipped), which is how the run proves every result on every page was read. If a search page paginates, page through all pages and count them all; flag any page whose count looks truncated.
- Accepted listings added or updated (address, price, one-line reason).
- Rejected listings with one-line reasons when close or ambiguous.
- Unresolved candidates added, with what is missing.
- Check-log rows appended: count and decision breakdown.
- Blocked/unreachable sources: URL, domain, what was observed, what could not be checked.
- Files changed, commit message, and SHA (or the exact failure).

---
name: rental-property-filter
description: Filter rental property listings for the Property Watcher project. Use when the user provides newsletter-generated rental alert HTML, newsletter-mirror URLs, raw listing HTML, individual listing URLs, or rare search-result URLs and wants ChatGPT to extract property details and thumbnails from structured fields or descriptions, use safe per-domain request limits, reject listings outside H4H or H8P, reject listings with fewer than 2 rooms, reject listings under 900 square feet when real size is available, reject basement/semi-basement units, report blocked sources, and update and commit docs/index.html compiled-table changes directly unless the user explicitly asks for review-only or no-commit behavior.
---

# Rental Property Filter

Use this skill to filter rental listings for the Property Watcher repository.

The repository-wide source of truth is `AGENTS.md`. Follow it for eligibility rules, request etiquette, compiled HTML output schema, thumbnail handling, sorting, blocked-source reporting, and commit expectations. This skill adds the operational workflow for rental-specific filtering.

## Expected input

The user will usually provide newsletter-generated HTML from rental search alerts.

The user may provide:

- Public URLs containing HTML copied from search-alert newsletters.
- A newsletter-mirror root URL whose `index.html` lists one or more numbered files per site for the current batch (for example `centris-1.html`, `centris-2.html`); fetch and process every listed file.
- Raw newsletter/search-alert HTML copied directly into the conversation.
- Individual rental listing URLs, as rare exceptions.
- Listing-result page URLs already pre-filtered on rental/property websites, as rare exceptions.
- Notes overriding a specific run, such as temporary price limits or preferred sites.

Normalize each input into one or more candidate listing URLs, thumbnail URLs, and listing cards before filtering.

## Core output

For each run, provide:

1. Accepted rental listings added to or updated in `docs/index.html`.
2. Rejected listings with concise reasons when inspected.
3. Unresolved candidates that look promising but are missing required proof, especially postal code, room count, basement/semi-basement status, or thumbnail when no source image exists.
4. Blocked sources that could not be inspected because of CAPTCHA, bot detection, 403, 429, or access restrictions.
5. Compiled-table rows sorted newest first.
6. Files changed and commit SHA when committed.

Commit directly for normal filtering/update runs after best-effort validation. Do not ask for a separate commit confirmation unless the user explicitly says to review first, draft only, do not commit, or otherwise asks for approval before writing.

## Request etiquette

Use the minimum number of requests that still fills the table completely: reject from card data when possible, but the detail page is mandatory for every listing that gets a table row.

- Fetch newsletter HTML first.
- Extract all available card-level details and thumbnail images before opening detail pages.
- Build the complete candidate list from all sources first, then deduplicate it (across sources and against `docs/index.html`) before opening any detail page; the same listing often appears in both a search page and a newsletter.
- Always open the detail page of every candidate that survives card-level rejection — even when the card already shows postal code, rooms, and price. The detail page is the source for size, floor, laundry, courtyard, year built, exact address, date listed, and the free-text description.
- When the detail page links to a fuller external broker sheet (for example Centris's `See detailed sheet` link to the broker's own website), follow that link too and merge its details — posters often leave most of the information on the broker page. Per-domain etiquette applies to the broker's domain like any other.
- Skip a detail page only when the card data already proves rejection.
- Do not fetch a detail page solely to improve a thumbnail for a listing the card data already rejects.
- Allow at most one active request at a time per domain.
- Requests to different domains may run in parallel when the tool environment supports it.
- Wait at least 5 seconds between requests to the same domain when using a live browser or HTTP client.
- Wait around 10 seconds when opening many detail pages from the same site.
- If a site returns CAPTCHA, 403, 429, obvious bot protection, or unusual blocking behavior, record the blocked source and continue with the next source or next domain.
- Report blocked sources at the end with the URL, domain, observed block type, and missing check.
- Do not bypass access controls, rate limits, paywalls, logins, bot protection, or CAPTCHA.

## Extraction workflow

For each candidate listing:

1. Record the source URL, canonical listing URL, and thumbnail image URL when present.
2. Extract price, date listed, rooms, size, location text, postal code, address, floor, laundry, courtyard, year built, basement/semi-basement indicators, thumbnail image, and notes from the newsletter/listing card if possible.
3. Search both structured fields and free-text descriptions for key details. Square footage, room count, floor, laundry hookups, courtyard access, postal code, address, and basement/semi-basement wording may appear only in the description.
4. Fetch the detail page for every candidate not already rejected by card data, and merge its details over the card data. Follow the external broker sheet link (such as `See detailed sheet`) when the detail page has one, and merge those details too.
5. Normalize values without inventing missing facts:
   - Date added is the date the listing is added to `docs/index.html`.
   - Postal codes uppercase, preserving full code when available.
   - Prices as CAD monthly rental prices when source allows.
   - Size as sqft, or an empty cell when missing.
   - Impossible sizes such as `1 sqft`, `0 sqft`, blank, or impossible tiny sizes as unknown (empty cell).
   - Dates as `YYYY-MM-DD` when possible, with an empty cell when not recoverable.
   - Year built as a 4-digit construction year when the source states one, or an empty cell.
6. Apply the rental eligibility rules.
7. Update `docs/index.html` with accepted rows and useful run notes.
8. Commit the changed file directly unless the user explicitly requested review-only or no-commit behavior.
9. Report accepted rows, rejected rows, unresolved rows, blocked sources, changed files, and commit SHA.

## Rental eligibility rules

Accept a listing only when all these conditions are satisfied:

1. Postal code prefix starts with `H4H` or `H8P`.
2. Listing has at least 2 rooms or bedrooms using the clearest source label.
3. Listing has at least 900 sqft when a plausible real size is available.
4. Listing is not a basement, semi-basement, demi-sous-sol, or otherwise partly below-grade dwelling unit.

Do not accept listings with missing postal code unless an exact address or official detail page reliably establishes the postal prefix. When a listing gives an exact street address but no postal code, resolve the postal code from the address with a geocoding lookup (Nominatim search with `addressdetails=1`; see `AGENTS.md`) before treating it as missing, use the result only when it matches the same street number and street, and note `Postal code resolved from address` in `NOTES`.

Do not reject solely for missing size or obvious platform default size. Treat values such as `1 sqft`, `0 sqft`, blank, or impossible tiny sizes as unknown (empty size cell).

Reject listings with a plausible size below 900 sqft.

Reject studios, bachelor apartments, 1-room, and 1-bedroom listings.

Reject listings whose dwelling unit is fully or partly below ground. French indicators include `demi sous-sol`, `demi-sous-sol`, `sous-sol`, `semi sous-sol`, `semi-sous-sol`, and `rez-de-jardin` when the context indicates a partly below-grade unit. English indicators include `basement`, `basement apartment`, `semi-basement`, `semi basement`, `half-basement`, `half basement`, `partly below grade`, `partially below grade`, `below grade`, `partly underground`, `partially underground`, and `garden level` when the context indicates a partly below-grade unit.

Do not reject only because a listing mentions basement storage, basement parking, basement locker access, or a building basement amenity. The exclusion is for the dwelling unit itself being fully or partly below ground.

Keep ambiguous room counts or ambiguous basement/semi-basement wording out of the accepted table and put them in the unresolved candidates table unless the user has already provided a trusted interpretation rule.

## Thumbnail handling

The `Listing` cell must show the main thumbnail image as the clickable link to the listing.

Preferred thumbnail sources, in order:

1. The primary image from the newsletter-generated HTML listing card.
2. The primary image from a user-provided search-result page listing card.
3. The first listing photo or `og:image` from the detail page, which is always fetched for candidates headed to either table.
4. A linked visual fallback only when no source thumbnail is available.

Preserve public source image URLs directly in the HTML. Do not download or rehost listing images unless the user explicitly asks for a separate image-mirroring workflow.

Use descriptive `alt` text such as the address or `Listing thumbnail for 123 Example St`. Use `loading="lazy"` and `referrerpolicy="no-referrer"` on thumbnail images.

If no source thumbnail is available, use a linked visual fallback such as a small `No image` placeholder, keep the listing link, and note `Thumbnail unavailable from source` in `NOTES` when helpful.

## Compiled table row format

`docs/index.html` holds two tables with the same schema: the accepted table and, below it, the unresolved candidates table for promising listings that cannot be fully filtered yet. Draft rows for either table with exactly twelve cells:

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

Example row:

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

Leave the cell empty (`<td></td>`) for unavailable values; do not write `Unknown` or any other placeholder text. An empty cell signals the information was looked for and not found.

Escape HTML special characters in text cells. URL-encode map query parameters. HTML-escape `&` in image and listing URLs as `&amp;`.

Use a stable named `target` value for every listing and map link. Do not use `_blank`. A stable named target opens a new tab/window the first time and reuses the same tab/window when the same link is clicked again.

For listing links, derive the target from the canonical listing URL or listing ID, such as `target="listing-123"`.

For Google Maps links, derive the target from the normalized map query, such as `target="map-123-example-st-h4h-1a1"`.

Sort rows by `Date added` newest first, then `Date listed` newest first, before committing updates. Within the same `Date added` group, put listings with an empty `Date listed` cell below dated listings.

## Location and Google Maps link handling

The `Location / postal code / map` cell should be a Google Maps link whenever enough location information exists.

Use the most precise available map query in this order:

1. Exact address plus full postal code.
2. Exact address.
3. Full postal code.
4. Partial postal code plus city/neighborhood.
5. Neighborhood/borough only if nothing more precise exists.

Do not fabricate missing address or postal-code details. If no useful location data exists, leave the cell empty.

## Rejection, unresolved, and blocked summary format

Use compact, auditable explanations:

```markdown
### Rejected

- [Listing](https://example.com/1) - postal code starts with H3Z, not H4H or H8P.
- [Listing](https://example.com/2) - 1 bedroom.
- [Listing](https://example.com/3) - 750 sqft real listed size.
- [Listing](https://example.com/4) - described as demi-sous-sol / semi-basement.

### Unresolved

- [Listing](https://example.com/5) - location says Verdun, but no postal code or exact address found.
- [Listing](https://example.com/6) - floor text mentions garden level, but unclear whether the unit is below grade.
- [Listing](https://example.com/7) - accepted details are otherwise available, but no thumbnail was present in the newsletter or source page.

### Blocked

- `example-rentals.com` - CAPTCHA on detail pages, could not verify postal code or size.
```

Unresolved candidates also get a row in the unresolved candidates table in `docs/index.html`, with `NOTES` stating exactly what is missing or ambiguous.

Do not spend excessive effort on clearly rejected listings once the rejection reason is reliable.

## Preparing HTML changes

Before committing edits:

1. Check both tables in `docs/index.html` for duplicate URLs, duplicate listing IDs, and matching address/price rows.
2. Add accepted rows to the accepted table and promising-but-unresolved candidates to the unresolved candidates table below it.
3. Update existing rows only when newly fetched details clarify unknown fields.
4. Preserve unrelated HTML exactly.
5. Update only the visible `Last updated` date.
6. Keep the table sorted newest first.
7. Preserve original `Date added` for existing rows unless the user explicitly asks otherwise.
8. Update blocked/unresolved notes when useful.
9. Verify listing links and Google Maps links use stable named `target` values.
10. Verify accepted rows do not contain basement, semi-basement, demi-sous-sol, or otherwise partly below-grade dwelling units.
11. Verify the `Listing` cell contains a linked thumbnail image or a linked visual fallback when no thumbnail exists.

## GitHub commit behavior

For normal rental filtering/update requests:

1. Update `docs/index.html`.
2. Preserve unrelated content as much as practical.
3. Commit directly with a clear commit message.
4. Report the commit SHA.

If the user explicitly asks for review-only, draft-only, no commit, or approval before writing, do not commit.

If the available GitHub tool can only write one file per commit, say so and make sequential commits. Do not claim a single commit was made if multiple commits were required.

## Failure modes to avoid

- Do not include listings outside `H4H` or `H8P`.
- Do not include studios, bachelor apartments, 1-room, or 1-bedroom listings.
- Do not include basement, semi-basement, demi-sous-sol, or otherwise partly below-grade dwelling units.
- Do not reject missing or obviously defaulted size values as under 900 sqft.
- Do not ignore free-text descriptions when structured fields are missing.
- Do not fabricate postal codes, addresses, sizes, floors, laundry, courtyard, construction years, listing dates, added dates, map links, or thumbnail image URLs. A postal code resolved by geocoding an exact address is a lookup, not fabrication.
- Do not bypass bot protection or rate limits.
- Do not stop the full run when a source is blocked; record it, continue, and report it at the end.
- Do not run multiple simultaneous requests to the same domain.
- Do not fetch detail pages for listings the cards already prove rejected.
- Do not add or update a table row from card data alone; the detail page (and the linked broker sheet when one exists) must be fetched first.
- Do not rewrite unrelated HTML during a normal daily update.
- Do not ask for commit approval on normal filtering/update runs unless the user explicitly requests review-only or no-commit behavior.

---
name: rental-property-filter
description: Filter rental property listings for the Property Watcher project. Use when the user provides rental listing-result URLs, individual listing URLs, raw listing HTML, or public newsletter/search-alert HTML URLs and wants ChatGPT to extract property details from structured fields or descriptions, use safe per-domain request limits, reject listings outside H4H or H8P, reject listings with fewer than 2 rooms, reject listings under 900 square feet when real size is available, report blocked sources, and prepare reviewable docs/index.html compiled-table updates.
---

# Rental Property Filter

Use this skill to filter rental listings for the Property Watcher repository.

The repository-wide source of truth is `AGENTS.md`. Follow it for eligibility rules, request etiquette, compiled HTML output schema, sorting, blocked-source reporting, and commit expectations. This skill adds the operational workflow for rental-specific filtering.

## Expected input

The user may provide:

- Listing-result page URLs already pre-filtered on rental/property websites.
- Individual rental listing URLs.
- Public URLs containing HTML copied from search-alert newsletters.
- Raw HTML copied directly into the conversation.
- Notes overriding a specific run, such as temporary price limits or preferred sites.

Normalize each input into one or more candidate listing URLs or listing cards before filtering.

## Core output

For each run, provide:

1. Accepted rental listings ready for `docs/index.html`.
2. Rejected listings with concise reasons when inspected.
3. Unresolved candidates that look promising but are missing required proof, especially postal code or room count.
4. Blocked sources that could not be inspected because of CAPTCHA, bot detection, 403, 429, or access restrictions.
5. Proposed compiled-table rows sorted newest first.
6. Proposed commit message.

Do not commit until the user explicitly approves, unless the user already gave clear commit authorization.

## Request etiquette

Use the minimum number of requests needed to make an accurate decision.

- Fetch listing-result pages or newsletter HTML first.
- Extract all available card-level details before opening detail pages.
- Deduplicate candidate URLs before opening detail pages.
- Open an individual listing page only when required to resolve postal code, rooms, size, floor, laundry, courtyard, address, price, date listed, or ambiguity.
- Allow at most one active request at a time per domain.
- Requests to different domains may run in parallel when the tool environment supports it.
- Wait at least 5 seconds between requests to the same domain when using a live browser or HTTP client.
- Wait around 10 seconds when opening many detail pages from the same site.
- If a site returns CAPTCHA, 403, 429, obvious bot protection, or unusual blocking behavior, record the blocked source and continue with the next source or next domain.
- Report blocked sources at the end with the URL, domain, observed block type, and missing check.
- Do not bypass access controls, rate limits, paywalls, logins, bot protection, or CAPTCHA.

## Extraction workflow

For each candidate listing:

1. Record the source URL and canonical listing URL.
2. Extract price, date listed, rooms, size, location text, postal code, address, floor, laundry, courtyard, and notes from the listing card if possible.
3. Search both structured fields and free-text descriptions for key details. Square footage, room count, floor, laundry hookups, courtyard access, postal code, and address may appear only in the description.
4. Follow the detail page only when card-level information is insufficient or suspicious.
5. Normalize values without inventing missing facts:
   - Date added is the date the listing is added to `docs/index.html`.
   - Postal codes uppercase, preserving full code when available.
   - Prices as CAD monthly rental prices when source allows.
   - Size as sqft, or `Unknown` when missing.
   - Impossible sizes such as `1 sqft` or `0 sqft` as `Unknown`.
   - Dates as `YYYY-MM-DD` when possible, with `Unknown` when not recoverable.
6. Apply the rental eligibility rules.
7. Prepare accepted rows, then rejected, unresolved, and blocked-source summaries.

## Rental eligibility rules

Accept a listing only when all these conditions are satisfied:

1. Postal code prefix starts with `H4H` or `H8P`.
2. Listing has at least 2 rooms or bedrooms using the clearest source label.
3. Listing has at least 900 sqft when a plausible real size is available.

Do not accept listings with missing postal code unless an exact address or official detail page reliably establishes the postal prefix.

Do not reject solely for missing size or obvious platform default size. Treat values such as `1 sqft`, `0 sqft`, blank, or impossible tiny sizes as `Unknown`.

Reject listings with a plausible size below 900 sqft.

Reject studios, bachelor apartments, 1-room, and 1-bedroom listings.

Keep ambiguous room counts out of the accepted table and show them as unresolved unless the user has already provided a trusted interpretation rule.

## Compiled table row format

Draft accepted rows for the `docs/index.html` table with exactly eleven cells:

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

Example row:

```html
<tr>
  <td>2026-07-01</td>
  <td>2026-07-01</td>
  <td>$2,100/mo</td>
  <td>2 bedrooms</td>
  <td>950 sqft</td>
  <td>123 Example St, H4H 1A1</td>
  <td>2nd floor</td>
  <td>In-unit hookups</td>
  <td>Shared courtyard</td>
  <td><a href="https://example.com/listing/123">Listing</a></td>
  <td>Size verified on detail page</td>
</tr>
```

Use `Unknown` for unavailable values.

Escape HTML special characters in text cells.

Sort accepted rows by `Date listed` newest first before proposing updates. For equal dates, sort by `Date added` newest first. Put `Unknown` listing dates below dated listings.

## Rejection, unresolved, and blocked summary format

Use compact, auditable explanations:

```markdown
### Rejected

- [Listing](https://example.com/1) - postal code starts with H3Z, not H4H or H8P.
- [Listing](https://example.com/2) - 1 bedroom.
- [Listing](https://example.com/3) - 750 sqft real listed size.

### Unresolved

- [Listing](https://example.com/4) - location says Verdun, but no postal code or exact address found.

### Blocked

- `example-rentals.com` - CAPTCHA on detail pages, could not verify postal code or size.
```

Do not spend excessive effort on clearly rejected listings once the rejection reason is reliable.

## Preparing HTML changes

Before proposing edits:

1. Check `docs/index.html` for duplicate URLs, duplicate listing IDs, and matching address/price rows.
2. Add only accepted rows.
3. Update existing rows only when newly fetched details clarify unknown fields.
4. Preserve unrelated HTML exactly.
5. Update only the visible `Last updated` date.
6. Keep the table sorted newest first.
7. Preserve original `Date added` for existing rows unless the user explicitly asks otherwise.
8. Update blocked/unresolved notes when useful.

## GitHub commit behavior

If the user approves committing:

1. Update `docs/index.html`.
2. Preserve unrelated content exactly.
3. Use a clear commit message.

If the available GitHub tool can only write one file per commit, say so and make sequential commits. Do not claim a single commit was made if multiple commits were required.

## Failure modes to avoid

- Do not include listings outside `H4H` or `H8P`.
- Do not include studios, bachelor apartments, 1-room, or 1-bedroom listings.
- Do not reject missing or obviously defaulted size values as under 900 sqft.
- Do not ignore free-text descriptions when structured fields are missing.
- Do not fabricate postal codes, addresses, sizes, floors, laundry, courtyard, listing dates, or added dates.
- Do not bypass bot protection or rate limits.
- Do not stop the full run when a source is blocked; record it, continue, and report it at the end.
- Do not run multiple simultaneous requests to the same domain.
- Do not fetch every detail page when listing cards already prove rejection.
- Do not rewrite unrelated HTML during a normal daily update.
- Do not commit before approval when approval is required.

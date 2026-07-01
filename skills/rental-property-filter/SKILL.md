---
name: rental-property-filter
description: Filter rental property listings for the Property Watcher project. Use when the user provides rental listing-result URLs, individual listing URLs, raw listing HTML, or public newsletter/search-alert HTML URLs and wants ChatGPT to extract property details, avoid excessive requests, reject listings outside H4H or H8P, reject listings with fewer than 2 rooms, reject listings under 900 square feet when real size is available, and prepare reviewable rental-listings.md table updates.
---

# Rental Property Filter

Use this skill to filter rental listings for the Property Watcher repository.

The repository-wide source of truth is `AGENTS.md`. Follow it for eligibility rules, request etiquette, table schema, sorting, changelog behavior, and commit expectations. This skill adds the operational workflow for rental-specific filtering.

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

1. Accepted rental listings ready for `rental-listings.md`.
2. Rejected listings with concise reasons when inspected.
3. Unresolved candidates that look promising but are missing required proof, especially postal code or room count.
4. Proposed `rental-listings.md` rows sorted newest first.
5. Proposed `rental-listings-changelog.md` block.
6. Proposed commit message.

Do not commit until the user explicitly approves, unless the user already gave clear commit authorization.

## Request etiquette

Use the minimum number of requests needed to make an accurate decision.

- Fetch listing-result pages or newsletter HTML first.
- Extract all available card-level details before opening detail pages.
- Deduplicate candidate URLs before opening detail pages.
- Open an individual listing page only when required to resolve postal code, rooms, size, floor, laundry, courtyard, address, price, date listed, or ambiguity.
- Fetch pages sequentially by default.
- Wait at least 5 seconds between requests to the same domain when using a live browser or HTTP client.
- Wait around 10 seconds when opening many detail pages from the same site.
- Stop if a site returns CAPTCHA, 403, 429, obvious bot protection, or unusual blocking behavior.
- Do not bypass access controls, rate limits, paywalls, logins, bot protection, or CAPTCHA.

## Extraction workflow

For each candidate listing:

1. Record the source URL and canonical listing URL.
2. Extract price, date listed, rooms, size, location text, postal code, address, floor, laundry, courtyard, and notes from the listing card if possible.
3. Follow the detail page only when card-level information is insufficient or suspicious.
4. Normalize values without inventing missing facts:
   - Postal codes uppercase, preserving full code when available.
   - Prices as CAD monthly rental prices when source allows.
   - Size as sqft, or `Unknown` when missing.
   - Impossible sizes such as `1 sqft` or `0 sqft` as `Unknown`.
   - Dates as `YYYY-MM-DD` when possible, with `Unknown` when not recoverable.
5. Apply the rental eligibility rules.
6. Prepare accepted rows, then rejected and unresolved summaries.

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

## Table row format

Draft accepted rows using the `rental-listings.md` schema:

```markdown
|DATE LISTED|PRICE|ROOMS|SIZE|LOCATION / POSTAL CODE|FLOOR|LAUNDRY|COURTYARD|URL|NOTES|
|:-|:-|:-|:-|:-|:-|:-|:-|:-|:-|
```

Each row must have exactly ten cells:

```markdown
|2026-07-01|$2,100/mo|2 bedrooms|950 sqft|123 Example St, H4H 1A1|2nd floor|In-unit hookups|Shared courtyard|[Listing](https://example.com/listing/123)|Size verified on detail page|
```

Use `Unknown` for unavailable values.

Escape literal `|` characters inside cells as `\|`.

Sort accepted rows by `DATE LISTED` newest first before proposing updates. Put `Unknown` dates below dated listings.

## Rejection and unresolved summary format

Use compact, auditable explanations:

```markdown
### Rejected

- [Listing](https://example.com/1) - postal code starts with H3Z, not H4H or H8P.
- [Listing](https://example.com/2) - 1 bedroom.
- [Listing](https://example.com/3) - 750 sqft real listed size.

### Unresolved

- [Listing](https://example.com/4) - location says Verdun, but no postal code or exact address found.
```

Do not spend excessive effort on clearly rejected listings once the rejection reason is reliable.

## Preparing Markdown changes

Before proposing edits:

1. Check `rental-listings.md` for duplicate URLs, duplicate listing IDs, and matching address/price rows.
2. Add only accepted rows.
3. Update existing rows only when newly fetched details clarify unknown fields.
4. Preserve unrelated Markdown exactly.
5. Update only the visible `LAST UPDATED` date.
6. Keep the table sorted newest first.
7. Add a newest-first changelog block to `rental-listings-changelog.md`.

For the changelog, use short lines:

```markdown
**2026-07-01**

>Added 123 Example Street rental listing  
>Updated laundry details for 456 Example Avenue
```

## GitHub commit behavior

If the user approves committing:

1. Update `rental-listings.md`.
2. Update `rental-listings-changelog.md`.
3. Preserve unrelated content exactly.
4. Use a clear commit message.

If the available GitHub tool can only write one file per commit, say so and make sequential commits. Do not claim a single commit was made if multiple commits were required.

## Failure modes to avoid

- Do not include listings outside `H4H` or `H8P`.
- Do not include studios, bachelor apartments, 1-room, or 1-bedroom listings.
- Do not reject missing or obviously defaulted size values as under 900 sqft.
- Do not fabricate postal codes, addresses, sizes, floors, laundry, courtyard, or dates.
- Do not bypass bot protection or rate limits.
- Do not fetch every detail page when listing cards already prove rejection.
- Do not rewrite unrelated rows during a normal daily update.
- Do not commit before approval when approval is required.

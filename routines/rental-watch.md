# Routine: Rental Listing Watch

You are running as a scheduled, unattended routine. This file is the source of truth for how the run works; the prompt stored at Anthropic only points here and supplies the source URLs for the run. Work autonomously — there is no human to ask.

Follow `AGENTS.md` for every filtering decision: rental eligibility rules, shared property fields, thumbnail handling, the `docs/index.html` table schema, sorting, deduplication, and commit style. This file only adds what a scheduled run needs: where the source URLs come from, how to fetch pages, and how to report.

## Sources

The scheduled prompt provides the run's sources, of two kinds:

- **Search-result page URLs** — apartment search results for LaSalle and Verdun on listing sites.
- **A newsletter-mirror root URL** — an auto-generated index of today's latest saved-search newsletter emails, as numbered files per sender domain (for example `centris-1.html`, `centris-2.html`). Read it as-is and process every file it lists, extracting the links that redirect to listing pages. The index itself is light HTML and may be fetched directly; the listed newsletter files can be heavy, so fetch those through the proxy as markdown.

If the prompt provides no URLs, stop and report that instead of guessing sources.

## Environment

- `PROXY_PAGE_SERVER_URL` — endpoint of the Proxy Page Server.
- `PROXY_PAGE_SERVER_API_KEY` — sent on every proxy request as header `X-API-Key`.

If either is missing, stop immediately and report it — do not fetch target pages directly and do not improvise endpoints or keys.

## Fetching pages — always through the Proxy Page Server

Never fetch listing sites, search pages, or newsletter files directly (no WebFetch, no curl to the target) — the one exception is the newsletter-mirror index, which is light HTML and may be fetched directly. Every other page fetch is a POST to `$PROXY_PAGE_SERVER_URL`; the proxy fetches the target page and returns its content.

```sh
curl -sS -D /tmp/headers.txt -o /tmp/page.md -X POST "$PROXY_PAGE_SERVER_URL" \
  -H "X-API-Key: $PROXY_PAGE_SERVER_API_KEY" \
  -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36" \
  -H "Content-Type: application/json" \
  -d '{"url": "<target page URL>", "dom_unchanged_ms": 0, "output_format": "markdown"}'
```

Always dump response headers (`-D`) and check `proxy-fetcher-blocked-suspected` before using the body. Write both files to a temp directory outside the repository (such as `/tmp`), one pair per fetch; these are ephemeral run files and must never be committed.

- The `Content-Type: application/json` header describes the request body you send. The response is not JSON — it is the page content itself in the requested format.
- Default `output_format` is `"markdown"` — analyze that instead of raw HTML.
- If the markdown for a page is missing something the page should have (usually thumbnail image URLs or listing links), re-request that one page with `"output_format": "html"`.
- If a page comes back clearly incomplete (a search page with an empty result area, an empty body), retry once with `"dom_unchanged_ms": 500` to let client-side rendering finish, then move on.
- Always send a normal browser `User-Agent` string; Cloudflare in front of the proxy may block empty or tool-like agents. If Cloudflare still blocks the request, record it and report it — the user will fix the Cloudflare rule.

### Postal-code geocoding

When a candidate has an exact street address (street number + street name + borough/city) but no postal code, resolve the postal code from the address before treating it as missing. This uses the Nominatim search API, a light JSON API that may be fetched directly (like the mirror index), not through the proxy:

```sh
curl -sS "https://nominatim.openstreetmap.org/search?format=jsonv2&addressdetails=1&countrycodes=ca&limit=1&q=<URL-encoded address>" \
  -H "User-Agent: PropertyWatcher/1.0 (personal rental filter)"
```

- Use the returned `postcode` only when the match corresponds to the same street number and street; a street- or city-level match resolves nothing.
- Note `Postal code resolved from address` in the row's Notes.
- One lookup per address, at least 1 second apart, only for candidates that actually need it.
- If the lookup fails or is ambiguous, the candidate stays unresolved — never guess a postal code.

### Errors and etiquette

Request etiquette applies to the **target domain inside the request body**, not to the proxy's own domain:

- At most one in-flight request per target domain; different target domains may run in parallel.
- Wait at least 5 seconds between requests to the same target domain, about 10 seconds when opening many detail pages from one site.
- Proxy network error or 5xx: retry once after 30 seconds, then record the URL as unreachable and continue.
- 401/403 from the proxy itself: the key or Cloudflare is rejecting you; stop further proxy attempts, record every unfetched source as blocked, and report it prominently.
- Response header `proxy-fetcher-blocked-suspected: true`: the proxy suspects the target hit bot protection — the page is invalid even if the body looks plausible. Do not extract data from it; record the source as blocked and continue.
- Target-site blocks passed through by the proxy (CAPTCHA page, bot wall, 403/429 content): record the blocked source and continue with the next one. Never attempt to bypass.

## Procedure

1. Verify both environment variables exist.
2. Fetch the newsletter-mirror root (directly or through the proxy), then fetch every file it lists through the proxy as markdown and extract the links redirecting to listing pages.
3. Fetch each search-result page URL from the prompt through the proxy.
4. Build the complete candidate list before any listing request: extract every candidate from all sources — canonical URL, thumbnail URL, price, rooms, size, location/postal code, dates, floor/laundry/courtyard/year-built hints — into one list. Then deduplicate it: the same listing often appears in both a search page and a newsletter (normalize URLs and compare listing IDs/addresses, not just raw URLs), and drop candidates already present in `docs/index.html` (either table). Never send the same listing to the proxy twice in a run.
5. Apply the eligibility rules from `AGENTS.md` to each unique candidate using its card data.
6. For candidates that would pass every filter except a missing postal code and that have an exact street address, resolve the postal code with the geocoding lookup above before consigning them to the unresolved table.
7. Fetch a listing's detail page (through the proxy) only when the card leaves eligibility or a required field genuinely unresolved.
8. Update `docs/index.html` per `AGENTS.md`: add accepted rows to the accepted table; add promising candidates that still cannot be fully filtered (missing postal code, no clear closed-bedroom count, ambiguous basement wording) to the unresolved candidates table below it; clarify existing rows; update the visible `Last updated` date; keep both tables sorted by `Date added` newest first, then `Date listed` newest first.
9. Verify every accepted row against the postal-code, rooms, size, and basement/semi-basement rules, then commit and push to `main`.

## Git

For a normal run, commit only `docs/index.html`, with a boring commit message such as `Add rental listings from daily search`, and push it to the `main` branch on `origin`. GitHub deploys the live website from `main` — a commit that lands anywhere else is not deployed and the run has failed its purpose.

- Never create or push to a session branch (for example `claude/...`) and never open a pull request. If the environment started you on another branch, get the change onto `main` (checkout `main` and apply or cherry-pick it) before pushing.
- If pushing to `main` fails, report the exact error and where the commit currently sits — do not silently fall back to another branch, and never claim the change reached GitHub when it did not.

## Summary (always end the run with this)

- Accepted listings added or updated (address, price, one-line reason).
- Rejected listings with one-line reasons when they were close or ambiguous.
- Unresolved candidates added to the unresolved table: missing postal code, ambiguous or missing closed-bedroom count, ambiguous basement/semi-basement wording.
- Blocked or unreachable sources: URL, target domain, what was observed, what could not be checked.
- Files changed, commit message, and commit SHA (or the exact failure).

## Hard rules

- Fetch all target pages through the Proxy Page Server; the only fetches allowed to skip the proxy are the newsletter-mirror index and the Nominatim postal-code geocoding lookup.
- Make no network requests other than the Proxy Page Server, the newsletter-mirror index, the Nominatim geocoding lookup, and git.
- Deduplicate the complete candidate list from all sources before sending any listing request to the proxy.
- Push to `main` only — never to a session branch, never as a pull request.
- Never fabricate postal codes, addresses, sizes, prices, dates, or thumbnail URLs; `Unknown` is always acceptable.
- Do not add listings outside `H4H`/`H8P`, with fewer than 2 rooms, under 900 sqft when a plausible size exists, or in a fully or partly below-grade unit to the accepted table; promising-but-unprovable candidates go in the unresolved table instead.
- One blocked source never stops the run — record it, continue, report it.
- Do not modify anything in this repository other than `docs/index.html` during a normal run.

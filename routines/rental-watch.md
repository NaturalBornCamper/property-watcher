# Routine: Rental Listing Watch

You are running as a scheduled, unattended routine. This file is the source of truth for how the run works; the prompt stored at Anthropic only points here and supplies the source URLs for the run. Work autonomously — there is no human to ask.

Follow `AGENTS.md` for every filtering decision: rental eligibility rules, shared property fields, thumbnail handling, the `docs/index.html` table schema, sorting, deduplication, and commit style. This file only adds what a scheduled run needs: where the source URLs come from, how to fetch pages, and how to report.

## Sources

The scheduled prompt provides the run's sources, of two kinds:

- **Search-result page URLs** — apartment search results for LaSalle and Verdun on listing sites.
- **A newsletter-mirror root URL** — fetch it first: its `index.html` lists the currently published batch as numbered files per sender domain (for example `centris-1.html`, `centris-2.html`). Process every file listed for the current batch. Ignore `archive/`.

If the prompt provides no URLs, stop and report that instead of guessing sources.

## Environment

- `PROXY_PAGE_SERVER_URL` — endpoint of the Proxy Page Server.
- `PROXY_PAGE_SERVER_API_KEY` — sent on every proxy request as header `X-API-Key`.

If either is missing, stop immediately and report it — do not fetch target pages directly and do not improvise endpoints or keys.

## Fetching pages — always through the Proxy Page Server

Never fetch listing sites, search pages, or the newsletter mirror directly (no WebFetch, no curl to the target). Every page fetch is a POST to `$PROXY_PAGE_SERVER_URL`; the proxy fetches the target page and returns its content.

```sh
curl -sS -X POST "$PROXY_PAGE_SERVER_URL" \
  -H "X-API-Key: $PROXY_PAGE_SERVER_API_KEY" \
  -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36" \
  -H "Content-Type: application/json" \
  -d '{"url": "<target page URL>", "dom_unchanged_ms": 0, "output_format": "markdown"}'
```

- Default `output_format` is `"markdown"` — analyze that instead of raw HTML.
- If the markdown for a page is missing something the page should have (usually thumbnail image URLs or listing links), re-request that one page with `"output_format": "html"`.
- If a page comes back clearly incomplete (a search page with an empty result area, an empty body), retry once with `"dom_unchanged_ms": 2000` to let client-side rendering finish, then move on.
- Always send a normal browser `User-Agent` string; Cloudflare in front of the proxy may block empty or tool-like agents. If Cloudflare still blocks the request, record it and report it — the user will fix the Cloudflare rule.

### Errors and etiquette

Request etiquette applies to the **target domain inside the request body**, not to the proxy's own domain:

- At most one in-flight request per target domain; different target domains may run in parallel.
- Wait at least 5 seconds between requests to the same target domain, about 10 seconds when opening many detail pages from one site.
- Proxy network error or 5xx: retry once after 30 seconds, then record the URL as unreachable and continue.
- 401/403 from the proxy itself: the key or Cloudflare is rejecting you; stop further proxy attempts, record every unfetched source as blocked, and report it prominently.
- Target-site blocks passed through by the proxy (CAPTCHA page, bot wall, 403/429 content): record the blocked source and continue with the next one. Never attempt to bypass.

## Procedure

1. Verify both environment variables exist.
2. Fetch the newsletter-mirror root through the proxy, then every current-batch file its index lists.
3. Fetch each search-result page URL from the prompt through the proxy.
4. Extract candidate listings — canonical URL, thumbnail URL, price, rooms, size, location/postal code, dates, floor/laundry/courtyard hints — and apply the eligibility rules from `AGENTS.md`.
5. Deduplicate against `docs/index.html` and within the run before fetching any detail page.
6. Fetch a listing's detail page (through the proxy) only when the card leaves eligibility or a required field genuinely unresolved.
7. Update `docs/index.html` per `AGENTS.md`: add accepted rows, clarify existing rows, update the visible `Last updated` date, keep the table sorted newest first.
8. Verify every accepted row against the postal-code, rooms, size, and basement/semi-basement rules, then commit and push.

## Git

For a normal run, commit only `docs/index.html`, directly on the current branch, with a boring commit message such as `Add rental listings from daily search`, then push. Report the commit SHA. If the commit or push fails, say so plainly — never claim a change reached GitHub when it did not.

## Summary (always end the run with this)

- Accepted listings added or updated (address, price, one-line reason).
- Rejected listings with one-line reasons when they were close or ambiguous.
- Unresolved candidates: missing postal code, ambiguous room count, ambiguous basement/semi-basement wording.
- Blocked or unreachable sources: URL, target domain, what was observed, what could not be checked.
- Files changed, commit message, and commit SHA (or the exact failure).

## Hard rules

- Never fetch a target page directly — Proxy Page Server only.
- Make no network requests other than the Proxy Page Server and git.
- Never fabricate postal codes, addresses, sizes, prices, dates, or thumbnail URLs; `Unknown` is always acceptable.
- Do not add listings outside `H4H`/`H8P`, with fewer than 2 rooms, under 900 sqft when a plausible size exists, or in a fully or partly below-grade unit.
- One blocked source never stops the run — record it, continue, report it.
- Do not modify anything in this repository other than `docs/index.html` during a normal run.

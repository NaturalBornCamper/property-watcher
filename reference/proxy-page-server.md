# Proxy Page Server — API reference

The Proxy Page Server fetches a target web page from a residential IP and returns its content, so agents can read listing sites and newsletter mirrors that block tool-like clients or serve heavy client-rendered HTML. It is a **proxy**: on success the response body is the fetched page itself (optionally converted to markdown or text), and all metadata comes back as `Proxy-Fetcher-*` response headers — the response is not JSON.

This file documents how to *call* the server. For request etiquette, when the proxy is mandatory, and how to treat blocked sources, see `AGENTS.md` → Shared infrastructure.

## Configuration

Two environment variables, never stored in this repository:

- `PROXY_PAGE_SERVER_URL` — the server's base URL (the `POST /fetch` endpoint, or the host it lives on).
- `PROXY_PAGE_SERVER_API_KEY` — sent on every `/fetch` request as the `X-API-Key` header. A missing or wrong key returns `401`.

## Endpoints

- `POST /fetch` — fetch one URL. Requires `X-API-Key`. This is the only endpoint the workflow uses.
- `GET /health` — no auth; returns `{"status":"ok"}`. Handy to confirm the server is reachable before a run.

## Request

`POST` to the endpoint with `Content-Type: application/json`, the `X-API-Key` header, a normal browser `User-Agent` (Cloudflare in front of the proxy may block empty or tool-like agents), and a JSON body. Only `url` is required; everything else has a server-side default.

```sh
curl -sS -D headers.txt -o page.md -X POST "$PROXY_PAGE_SERVER_URL" \
  -H "X-API-Key: $PROXY_PAGE_SERVER_API_KEY" \
  -H "Content-Type: application/json" \
  -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36" \
  -d '{"url": "https://example.com/listing/123", "output_format": "markdown", "dom_unchanged_ms": 0}'
```

`Content-Type: application/json` describes the **request body you send**; the **response** is the page content, not JSON.

### Body fields this workflow uses

| Field | Type | Default | Purpose |
|---|---|---|---|
| `url` | string (required) | — | Page to fetch. Must start with `http://` or `https://`. |
| `output_format` | `html` \| `text` \| `markdown` | `html` | What the body comes back as. Prefer `markdown` (keeps headings, lists, tables, links, images; drops markup). Re-request one page as `html` only when the markdown is missing something the page should have, such as thumbnail image URLs. Applies to HTML pages; other content (JSON, etc.) comes back as-is. |
| `dom_unchanged_ms` | int ms | `1000` | Capture only once the page's element count has been unchanged for this many ms (a "content settled" signal, so client-rendered pages capture fully). Omitting it uses the server's 1000 ms settle. This workflow sends `0` explicitly (no settle wait — faster on the common server-rendered page) and retries once at `500` when a page comes back clearly incomplete (empty result area on a search page, empty body). |
| `timeout_ms` | int ms | `30000` | Overall fetch ceiling in ms (hard max 120000; keep well under ~90000 if the server sits behind a Cloudflare free tunnel). |

Other fields exist (`min_tier`, `user_agent`, `wait_for_dom_ready`, `wait_for_selector`, `network_idle_max_wait_ms`, cooldown ranges) but the server and its per-domain config handle tier escalation and identity automatically — leave them unset unless a specific page needs tuning.

## Response

On **success** (`200`): the body is the fetched page in the requested format, with the page's media type in `Content-Type`. Metadata is in `Proxy-Fetcher-*` headers — always capture headers (curl `-D`) and check them before trusting the body.

| Response header | Meaning |
|---|---|
| `Proxy-Fetcher-Ok` | `true` on success, `false` otherwise. |
| `Proxy-Fetcher-Blocked-Suspected` | **Check this first.** `true` means every allowed tier still looked blocked — the body may be a challenge/bot-wall page. Treat the content as invalid, record the source as blocked, and do not extract listing data from it. |
| `Proxy-Fetcher-Final-Url` | Where the fetch ended after redirects (useful for canonicalizing/deduplicating). |
| `Proxy-Fetcher-Status-Code` | HTTP status of the fetched page (e.g. `200`). |
| `Proxy-Fetcher-Format` | Which format the body is in: `html`, `text`, or `markdown`. |
| `Proxy-Fetcher-Title` | The page `<title>`, when present. |
| `Proxy-Fetcher-Requested-Url` / `Proxy-Fetcher-Tier-Used` / `Proxy-Fetcher-Elapsed-Ms` / `Proxy-Fetcher-Cookies` | Diagnostics; rarely needed by the workflow. |
| `Proxy-Fetcher-Error` | Present only on failure; a short message. |

On **failure**: the body is a short plain-text error (never JSON or a stack trace) and `Proxy-Fetcher-Ok` is `false`.

## Status codes

| Code | Meaning | What to do |
|---|---|---|
| `200` | Fetched. | Use the body, after checking `Proxy-Fetcher-Blocked-Suspected`. |
| `401` | Missing/invalid API key (or Cloudflare in front of the proxy is rejecting you). | Stop further proxy attempts, record every unfetched source as blocked, report it prominently. |
| `422` | Invalid request (e.g. a non-http URL). | Fix the request; don't retry as-is. |
| `502` | Fetch failed (network error, timeout, refused target). | Retry once after ~30s, then record as unreachable and continue. |
| `503` | Target domain is on cooldown after a recent block; includes a `Retry-After` header (also surfaced as `Proxy-Fetcher-Cooldown`, seconds). | Reschedule that domain after the given delay; move on to other domains meanwhile. |
| `409` | Domain needs a saved login and none exists (`Proxy-Fetcher-Login-Required: true`). | Record as blocked/needs-login; retrying as-is won't help. |
| `500` | Unexpected server error. | Record as unreachable and continue. |

A `Proxy-Fetcher-Blocked-Suspected: true` on a `200`, a proxy `401/403`, and a target-site bot wall passed through the proxy are all **blocked sources**. Handle them as `AGENTS.md` → Request etiquette directs: record, continue with the next source, report at the end, and never attempt to bypass a block.

## Notes for this project

- The server picks the fetch engine and escalates through tiers on its own, and remembers per-domain settings; callers normally send just `url` + `output_format` (+ `dom_unchanged_ms` when a page renders late).
- Per-domain request etiquette (one request at a time per domain, spacing, parallelism across domains) applies to the **target domain inside the request body**, not to the proxy's own host — see `AGENTS.md`.
- Write response headers and bodies to a temp directory outside the repository; they are ephemeral run files and must never be committed.

# AGENTS.md

This is the repository-wide source of truth, read by every agent that works here (Claude Code loads it through `CLAUDE.md`; Codex, OpenClaw, and ChatGPT read it directly). It holds only what is true across the whole project: the purpose, the file layout, the shared infrastructure every workflow reuses (proxy, request etiquette, geocoding), and commit/push policy.

Workflow-specific rules do **not** live here. They follow a three-layer split:

- **Skills** (`skills/`) are reusable, parameterized workflows — like functions with no hardcoded values. A skill states which parameters it expects (sources, filter thresholds) and how to apply them, but never their concrete values. The active skill is `skills/rental-property-filter/SKILL.md`; a purchase skill will follow the same shape.
- **Routines** (`routines/`) are the concrete calls: one routine invokes a skill with specific arguments (the actual search URLs, postal-code prefixes, size/price/bedroom thresholds, etc.). Different routines reuse one skill with different arguments; a filter a routine omits is simply not enforced.
- **AGENTS.md** (this file) holds only what is true across every workflow.

For any rental task — interactive or scheduled — load and follow `skills/rental-property-filter/SKILL.md`.

## Project purpose

This repository maintains the agent instructions, skills, and compiled output for filtering property listings into a small, useful watch list.

The project is not a general real-estate crawler and is not intended for resale, lead generation, competitive scraping, or any commercial use. The goal is to save personal time by filtering out misleading or irrelevant rental and purchase listings.

The current active workflow is rental filtering. Future workflows may add purchase filtering for a forever-home search. All property workflows share the same conservative extraction, throttling, deduplication, blocked-source reporting, and review principles defined in this file, and add their own eligibility rules in their own skill.

## Repository layout

- `docs/index.html` — compiled output and canonical accepted-listings file; served live by GitHub Pages.
- `AGENTS.md` — this file; repo-wide source of truth.
- `CLAUDE.md` — thin Claude Code entry point that imports this file; holds Claude-specific overrides only (currently none).
- `skills/` — one folder per workflow skill, provider-neutral and portable:
  - `skills/rental-property-filter/SKILL.md` — the active rental filtering workflow (canonical).
  - `skills/rental-property-filter/agents/openai.yaml` — ChatGPT/OpenAI display metadata for the same skill.
- `.claude/skills/rental-property-filter/SKILL.md` — thin shim so Claude Code auto-discovers the skill; its body only points at the canonical skill above. Other agents ignore it and read the canonical skill by path.
- `routines/` — scheduled-run artifacts (not portable agent instructions):
  - `routines/lasalle-verdun-rental-watch.prompt.md` — the scheduled routine's version-controlled definition: which skill to run and the run's parameters (sources + filter thresholds). The scheduling platform holds only a one-line pointer (`Follow routines/lasalle-verdun-rental-watch.prompt.md`), so the parameters stay under version control. Name each routine file after the search it defines.
  - `routines/rental-listing-check-log.tsv` — persistent detail-check cache/state, read at the start of every scheduled run and committed back at the end.
- `email-pipe/` — cPanel email-pipe scripts that publish search-alert newsletter emails as public HTML mirror pages (see `email-pipe/README.md`).
- `.github/workflows/pages.yml` — GitHub Pages deploy; publishes `docs/` only when `docs/index.html` changes, plus manual dispatch.
- `reference/` — reference docs for external services this project uses:
  - `reference/proxy-page-server.md` — full API reference for the Proxy Page Server (endpoints, request fields, response headers, status codes).

Keep this file as the repository-wide source of truth when rules overlap. Do not duplicate workflow rules here that already live in a skill.

## Compiled output location

Use `docs/index.html` as the compiled output file.

- GitHub serves `docs/index.html` through GitHub Pages from the `main` branch and `/docs` folder.
- Deployment is handled by `.github/workflows/pages.yml`; keep it path-filtered to `docs/index.html` so unrelated instruction, skill, README, or routine-log commits do not deploy the site.
- Do not store FTP, SFTP, SSH, cPanel, or hosting passwords in this repository. Use GitHub Actions secrets if shared-hosting upload is added later.

## Source of truth for listings

When updating accepted listings, `docs/index.html` is the source of truth for current accepted listings and prior decisions.

Use listing websites, public listing pages, and public newsletter/search-alert HTML only as sources for current property data. Do not assume rendered website summaries or listing cards are complete: they often omit floor, laundry, courtyard, square footage, postal code, exact address, thumbnail, or dates. Card data may reject a candidate outright, but it never fills a final table row — see the detail-page rule in the active skill.

## Shared infrastructure

Every workflow reuses the following. Skills reference this section rather than restating it.

### Proxy Page Server

Listing sites and newsletter mirrors often use long tracking URLs that assistants refuse to open, or serve heavy HTML. The user runs a Proxy Page Server that fetches a target page from a residential IP and returns its content as markdown, text, or HTML.

**Its full usage — configuration/credentials, endpoints, request fields, response headers, and status codes — is documented once in [`reference/proxy-page-server.md`](reference/proxy-page-server.md). Do not restate those mechanics here or in any skill; link to that file.**

Only the repo-level policy for it lives here:

- The endpoint and API key come from the environment and are never stored in this repository.
- Scheduled routine runs must fetch every target page through the proxy; the only fetches allowed to skip it are the newsletter-mirror index and the Nominatim geocoding lookup below. Interactive runs use it whenever the proxy is configured.
- Whether the proxy reports a block or passes one through from the target site, treat it as a blocked source and handle it per Request etiquette below.

### Request etiquette, concurrency, and blocked sources

Be conservative with requests, but use safe parallelism across different domains. The purpose is personal filtering, not bulk scraping.

- Do not send high-frequency requests.
- Allow at most one active request at a time per domain. Requests to different domains may run in parallel when the tool environment supports it (e.g. one request each to `domain-a.com`, `domain-b.com`, and `domain-c.com` at once, but never three at once to `domain-a.com`).
- Wait at least 5 seconds between requests to the same domain when using a live browser or HTTP client; around 10 seconds when opening many detail pages from the same site.
- If a site returns bot protection, CAPTCHA, 403, 429, unusual blocking behavior, or an access error, record the blocked source and continue with the next source or domain.
- Report blocked sources at the end with the URL, domain, observed block type, and what could not be checked.
- Do not attempt to bypass bot protection, paywalls, logins, rate limits, IP limits, or CAPTCHA. Do not use multiple IPs, proxy rotation, credential stuffing, or browser fingerprint evasion.
- Prefer public pages and the user's public newsletter mirror URLs.
- One blocked source never stops a run.

### Postal-code geocoding (Nominatim)

When a candidate has an exact street address (street number + street name + borough/city) but no postal code, resolve the postal code from the address before treating it as missing. This is a lookup, not fabrication; guessing a postal code without a lookup remains forbidden.

- Use the Nominatim search API, a light JSON API that may be fetched directly (like the mirror index), not through the proxy:

```sh
curl -sS "https://nominatim.openstreetmap.org/search?format=jsonv2&addressdetails=1&countrycodes=ca&limit=1&q=<URL-encoded address>" \
  -H "User-Agent: PropertyWatcher/1.0 (personal rental filter)"
```

- Use the returned `postcode` only when the match corresponds to the same street number and street; a street- or city-level match resolves nothing.
- Follow the same etiquette: one request at a time, at least 1 second apart, only for addresses that actually need it.
- If the lookup fails or is ambiguous, treat the postal code as still missing.

## Commit behavior

- **A normal workflow run auto-commits only the output files the running skill declares it maintains** — nothing else. For the rental skill that is `docs/index.html` and, in scheduled runs, `routines/rental-listing-check-log.tsv`. Commit directly after best-effort validation without asking, unless the user explicitly requests review-only or no-commit behavior.
- **Every other file** (`AGENTS.md`, `CLAUDE.md`, skills, routine files, reference docs, workflows, scripts) is never auto-committed, even during a run. Update it, then present the change for review with a proposed commit message and let the user commit.
- Routine commits of `docs/index.html` and `routines/rental-listing-check-log.tsv` must be pushed to `main` — GitHub deploys the live site from `main`, so output on a session branch or in a PR is not deployed. Never push routine output anywhere other than `main`.
- Prefer one commit containing both files. If the available git write tool can commit only one file at a time, commit and push `docs/index.html` first, then `routines/rental-listing-check-log.tsv` only after the index commit succeeds, so the visible output stays ahead of the state log. Report each commit SHA.
- Do not claim a file was committed or pushed unless the git write action actually succeeded.

## Commit style

Use clear, boring commit messages, one logical change per commit unless the user asks otherwise. Examples:

- `Add rental listings from daily search`
- `Update rental listing details`
- `Update rental filtering rules`
- `Use thumbnails for listing links`

## Repo-wide do-not list

- Do not bypass bot protection, CAPTCHA, rate limits, logins, paywalls, or blocked pages.
- Do not stop a whole run because one source is blocked; record it, continue, and report it at the end.
- Do not run multiple simultaneous requests to the same domain, or flood listing websites.
- Do not fabricate data (postal codes, addresses, sizes, prices, dates, map links, thumbnail URLs). An empty cell is always acceptable. A postal code resolved by geocoding an exact address is a lookup, not fabrication.
- Do not silently change the compiled table schema.
- Do not push routine output anywhere other than `main`, and never open a pull request for a routine run.
- Do not make network requests other than the Proxy Page Server, the newsletter-mirror index, the Nominatim geocoding lookup, and git.

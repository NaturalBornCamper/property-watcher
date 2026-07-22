---
name: rental-property-filter
description: Filter rental property listings for the Property Watcher project and maintain the compiled tables in docs/index.html. A parameterized workflow — the caller (usually a routine) supplies the sources (search-result pages, a newsletter mirror, pasted HTML, or listing URLs) plus the filter thresholds it cares about (allowed postal-code prefixes, minimum bedrooms, minimum size, price range, below-grade exclusion), and the skill fetches, verifies details on each listing's own page, deduplicates, applies whichever filters were given, and writes accepted and unresolved rows with thumbnails. Use for any rental search; works interactively or as a scheduled/unattended run.
---

# Rental Property Filter (pointer)

This is a discovery shim so Claude Code can auto-find and trigger the skill. It holds no rules of its own.

The canonical skill lives at `skills/rental-property-filter/SKILL.md` (provider-neutral, shared by Claude, Codex, OpenClaw, and ChatGPT). **Read that file now and follow it in full.** Also follow `AGENTS.md` for shared infrastructure and commit policy.

Do not maintain rules here — edit the canonical skill instead, so there is only one source of truth.

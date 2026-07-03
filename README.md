# Property Watcher

ChatGPT agent instructions and Skills for filtering property rental and purchase listings into a small, useful watch list.

The repository currently focuses on **rental** listings, but it is intentionally organized so future skills can support purchase searches for a forever home.

## Main files

- `docs/index.html` - compiled rental-listings output. This is the file to refresh after each filtering run.
- `AGENTS.md` - source of truth for project rules, eligibility criteria, request etiquette, output schema, and update workflow.
- `CLAUDE.md` - Claude entry point that imports `AGENTS.md`.
- `skills/rental-property-filter/` - ChatGPT Skill instructions for filtering rental property URLs or public newsletter/search-alert HTML.

## Where the compiled output goes

Use `docs/index.html` as the canonical compiled output file.

This gives two practical publishing options:

1. **GitHub Pages:** enable Pages for this repository using the `main` branch and `/docs` folder. Then `docs/index.html` becomes a refreshable web page.
2. **Shared hosting deploy:** add a GitHub Actions workflow later that uploads `docs/index.html` to Interserver/cPanel by FTP using GitHub repository secrets. Do not put FTP, SFTP, SSH, or cPanel credentials directly in this repo.

For now, agents should update `docs/index.html` directly when a compiled rental table is approved.

## How updates work

Daily rental updates should keep `docs/index.html` unchanged except for:

1. adding newly accepted rental rows;
2. updating existing rows when newly fetched details clarify unknown fields;
3. updating the visible `Last updated` date;
4. keeping the table sorted by newest `Date listed` on top;
5. preserving blocked/unresolved source notes when useful.

The current rental filters are:

- Postal code prefix must be `H4H` or `H8P`.
- Listing must have at least 2 rooms or bedrooms, using the clearest label available from the source.
- Listing must be at least 900 square feet when a real size is available.
- Listing must not be a basement, semi-basement, `demi sous-sol`, or otherwise partly below-grade unit.
- Missing size, or an obvious site default such as `1 sqft`, should be treated as unknown size instead of an automatic rejection.

## Using the skill

Use `skills/rental-property-filter/SKILL.md` when analyzing listing-result URLs, listing pages, or public HTML URLs generated from rental search-alert newsletters. The skill workflow extracts listing data, follows detail pages only when needed, applies the current rental filters, and prepares reviewable `docs/index.html` updates before any GitHub commit.

For detailed rules, read `AGENTS.md`.

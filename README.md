# Property Watcher

Markdown source files and ChatGPT Skill instructions for filtering property rental and purchase listings into a short list of actually interesting options.

The repository currently focuses on **rental** listings, but the project is intentionally organized so future skills can support purchase searches for a forever home.

## Main files

- `rental-listings.md` - accepted rental listings table, newest listing date first.
- `rental-listings-changelog.md` - newest-first changelog for daily rental-listing updates.
- `AGENTS.md` - source of truth for project rules, eligibility criteria, scraping etiquette, table schema, and update workflow.
- `CLAUDE.md` - Claude entry point that imports `AGENTS.md`.
- `skills/rental-property-filter/` - ChatGPT Skill instructions for filtering rental property URLs or public newsletter/search-alert HTML.

## How updates work

Daily rental updates should keep `rental-listings.md` unchanged except for:

1. adding newly accepted rental rows;
2. updating the visible `LAST UPDATED` date;
3. keeping the table sorted by newest `DATE LISTED` on top;
4. adding a newest-first changelog block to `rental-listings-changelog.md`.

The current rental filters are:

- Postal code prefix must be `H4H` or `H8P`.
- Listing must have at least 2 rooms or bedrooms, using the clearest label available from the source.
- Listing must be at least 900 square feet when a real size is available.
- Missing size, or an obvious site default such as `1 sqft`, should be treated as unknown size instead of an automatic rejection.

## Using the skill

Use `skills/rental-property-filter/SKILL.md` when analyzing listing-result URLs, listing pages, or public HTML URLs generated from rental search-alert newsletters. The skill workflow extracts listing data, follows detail pages only when needed, applies the current rental filters, and prepares reviewable Markdown updates before any GitHub commit.

For detailed rules, read `AGENTS.md`.

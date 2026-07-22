# LaSalle / Verdun Rental Watch — scheduled routine

This file **is** what the scheduled LaSalle/Verdun rental-watch routine runs. The scheduling platform (Claude Code routine, ChatGPT scheduled task, or OpenClaw) holds only a one-line pointer:

```text
Follow routines/lasalle-verdun-rental-watch.prompt.md
```

Everything the routine actually needs — which skill to run and the source URLs for the run — lives here under version control, so the URL list has git history and every agent reads the same thing. *How* the run works (fetching, filtering, deduplication, the check log, updating `docs/index.html`, reporting, committing) is not repeated here; it lives in the skill and `AGENTS.md`.

## The run

Run the **rental-property-filter** skill in **scheduled mode**: load and follow `skills/rental-property-filter/SKILL.md`, including its "Scheduled / unattended runs" section, plus `AGENTS.md` for shared infrastructure and commit policy. Work autonomously; there is no human to ask.

Invoke the skill with the parameters below (see the skill's "Parameters" section for what each means). This search is LaSalle/Verdun rental; a different rental search would reuse the same skill with different values.

### Filters

- `postal_code_prefixes`: `H4H`, `H8P`
- `min_size_sqft`: 900
- `exclude_below_grade`: true

Bedrooms and price are intentionally omitted: every source URL below already filters for 2+ bedrooms and the $1,100–$2,000 range, so re-filtering here is redundant. The skill still records each listing's price and room count in the `Price` and `Rooms` columns; it just does not use them to reject.

### Sources

`search_urls`:

- https://www.centris.ca/en/properties~for-rent~montreal-lasalle?sort=DateDesc&q=H4sIAAAAAAAACo2RTU_DMAyG_wrKCaQdQk_ADQoDREHTinYBDqZxW4u0KUk6iKb9d5wNRCk77JbXfvz6IyvRaCfOhBQT8WrNG9rUKOQAa1OWVOAdhq3sHV6jqSx0dchr6JDr5ES4-FwQfrB8emGNYIv6AZpvl5K0RxuTK9GAL-rH0MVUSj5ckvOWCs-Yx0_P0XvTevvcS3l1CvrgMIMctMYjBkhx-iSRYs1NSkKt3AJ0j1vnTeBW_fddRuancjIEZ9Z0aH3YzPML5tRWGqfQkA43hrfYq2qOrU9Nq8wIT8FjZWz4gzpSjBPoEZyj1tx9h_UInBvTuAGSxIslFyMqoyW7nVuE4XrvPVicIo49M2jVvmwcacYHHo55nMjxhXdhTMUvXH8BAF5gx3kCAAA&v=2&sortSeed=472947337&pageSize=20
- https://www.centris.ca/en/properties~for-rent~montreal-verdun-ile-des-soeurs?sort=DateDesc&sortSeed=184015030&pageSize=20&q=H4sIAAAAAAAACo2QQU_DMAyF_wrKCaROdD0xblA2QAw0rWgX2CE07hqR1sVJB9G0_46zgSiFw27x8_ee7WxEZaw4F7GIxAvhK1CKCljgGotC53AHfl-2Fq4BVySb0melbIB9cSRseC40vHP5tOQaJOXlg6y-UgptHFBobkQlXV4--ia0Uu38lbaOdO4Yc_DhWL3H2tFzG8fjkTRHxwsg1danQUjHBgYK7CBDaMmesEcrdpwNR2LLcwsNRtmFNC3sh-2EW_V31Dow386oC84IGyDndyv-gJmuVwYmstLG3yAfdpBrDrVLsVbYw1PpYIXkf6FWK8a1ND04A2N4-j_RPXCOWNkOkoQ_Sy571FSvOe2CQHbPe2slwQSgnzmVtTqUDSvN-IO7aw6TOD4AY4qx5fYTS3UVUYwCAAA&v=2&view=Thumbnail
- https://www.kijiji.ca/b-a-louer/ville-de-montreal/c30349001l1700281?address=Lasalle%2C%20QC%20H8P&bedrooms=2__4__3__5&ll=45.4260435%2C-73.6007407&price=1100__2000&radius=4.0&view=list
- https://www.kijiji.ca/b-a-louer/ville-de-montreal/c30349001l1700281?address=Verdun%2C%20QC%20H4H%202G3&bedrooms=2__4__3__5&ll=45.4453575%2C-73.579127&price=1100__2000&radius=3.0&view=list
- https://www.rentcafe.com/apartments-for-rent/lasalle-montreal-qc/?PriceMin=1100&PriceMax=2000&role=renter&PropertyType=Apartment,Condo,Home,Townhouse,Affordable&Beds=Two,Three,FourPlus
- https://www.rentcafe.com/apartments-for-rent/verdun-montreal-qc/?PriceMin=1100&PriceMax=2000&role=renter&PropertyType=Apartment,Condo,Home,Townhouse,Affordable&Beds=Two,Three,FourPlus
- https://www.apartments.com/min-2-bedrooms-under-2000/entire-place/?sk=cc4ada4abaa92587f69d81cac3333959&bb=ppz9t1whiIwo64kM&so=8
- https://www.zumper.com/apartments-for-rent/montreal-qc/lasalle/2+beds/price-1100,2000?property-types=4,15,5,14,29,9,1,3,6,2,13,21&sort=newest&lease-length=long&min-square-feet=1000&listing-amenities=16&box=-73.67766380310059,45.40504892961485,-73.5853099822998,45.452936026887194
- https://www.zumper.com/apartments-for-rent/montreal-qc/verdun-centre/2+beds/price-1100,2000?property-types=4,15,5,14,29,9,1,3,6,2,13,21&sort=newest&lease-length=long&min-square-feet=100&listing-amenities=16&box=-73.61238956451416,45.440953005728055,-73.52132320404053,45.488809645587025
- https://www.padmapper.com/apartments/montreal-qc/2+beds/price-1100,2000?property-categories=apartment,condo,house&sort=newest&lease-length=long&box=-73.68204116821289,45.40553101471265,-73.5699462890625,45.46160557030758
- https://www.padmapper.com/apartments/montreal-qc/2+beds/price-1100,2000?property-categories=apartment,condo,house&sort=newest&lease-length=long&box=-73.61474990844727,45.426678448341285,-73.50265502929688,45.482731998239636
- https://www.facebook.com/marketplace/category/propertyrentals/?minPrice=1100&maxPrice=2000&minBedrooms=2&propertyType=house%2Capartment-condo&sortBy=creation_time_descend&exact=false&latitude=45.42158938373982&longitude=-73.61379738778749&radius=1
- https://www.facebook.com/marketplace/category/propertyrentals/?minPrice=1100&maxPrice=2000&minBedrooms=2&propertyType=house%2Capartment-condo&sortBy=creation_time_descend&exact=false&latitude=45.43477203638749&longitude=-73.59397326306008&radius=1
- https://www.facebook.com/marketplace/category/propertyrentals/?minPrice=1100&maxPrice=2000&minBedrooms=2&propertyType=house%2Capartment-condo&sortBy=creation_time_descend&exact=false&latitude=45.44532023349039&longitude=-73.58221169495482&radius=1
- https://www.logisquebec.com/result-search.php?tri=2&source=a_louer&type=&region=5&ville=222&prix_min=1100&prix_max=2000&room=2&from_search=true&from_filter=true
- https://www.logisquebec.com/result-search/?tri=2&source=a_louer&type=&region=5&ville=250&prix_min=1100&prix_max=2000&room=2&lq-query=Verdun%20(Montréal)&query=Verdun%20(Montréal)&page=1

`newsletter_mirror_root`:

- https://apartments-email-alerts.ashgun.com/index.html

## Notes

- To change what the routine searches or its thresholds, edit the parameters/URLs above and commit — the platform prompt never changes.
- Never put the proxy endpoint or API key here or anywhere in the repository; they come from the environment.
- Keep the platform prompt to the single `Follow routines/lasalle-verdun-rental-watch.prompt.md` line above, so this file stays the one source of truth.
- For a second scheduled workflow later (for example purchase filtering), add its own prompt file beside this one and its own skill under `skills/`.

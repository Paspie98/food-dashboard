# M13 — Readability restructure QA (`commodity_exposure.html`)

**Status: complete, committed (`9787078`), live.** Front-end + one static descriptive dictionary only. No analysis written; no pipeline/data-emit changes; analysis slots stay empty. Live: **https://paspie98.github.io/food-dashboard/**.

## What changed
1. **Reader-ordered segments** (config-driven `SEGMENTS`): Crops & Ingredients → Farm Inputs → Logistics & Energy → Packaging.
2. **Commodity-family sub-groups** (config `FAMILY_MAP`) replacing the raw/processed split. Distinct rows are **never merged** — raw & white sugar, and oilseed & refined oil, stay separate rows sitting **adjacent**. Region dropped as a layout axis (kept as a badge + in the bubble).
3. **Three-level hierarchy + slider**: segment → family (with a mechanical rollup) → cards in a horizontal carousel (all canvases drawn, incl. off-screen).
4. **Info bubble** per card (ⓘ): auto-pulled facts + a static descriptive gloss.
5. **Four-basis chart hover**: each point read vs '22 path / YTD / YoY / prior years at once.
6. **Region** no longer drives layout.

## Family mapping (every captured row; 17 families)
**Crops & Ingredients** — FAO Food Price Index *(IX-001, aggregate)* · Cereals & Grains *(WH-001/002/003, MZ-001/002, IX-002 agg)* · Oilseeds & Vegetable Oils *(VO-001/002/003/004/005, IX-003 agg)* · Dairy, Butter & Fats *(DY-001/002, IX-004 agg)* · Sugar & Sweeteners *(SG-001 raw, SG-002 + SG-003 white — separate & adjacent, IX-005 agg)* · Other Softs *(CO-001, CF-001/002, EG-001/002)*.
**Farm Inputs** — Nitrogen *(FE-001 urea global, FE-008 EU N)* · Phosphate *(FE-002 DAP, FE-003 TSP, FE-005 rock, FE-010 EU P)* · Potash *(FE-004 MOP, FE-011 EU K)* · Other inputs *(FE-006, FE-007, FE-009)*.
**Logistics & Energy** — Crude, Gas & Coal *(EN-003, EN-009, EN-001, EN-004, EN-010)* · Road & Retail Fuels *(EN-005/006/007/008)* · Freight & Logistics *(FR-001..005)*.
**Packaging** — Paper & Board *(PK-001/002/003/004)* · Metals *(PK-005, 1-card)* · Glass *(PK-006/007)* · Plastics *(PK-008/009)*.

FAO sub-indices carry a **"family aggregate · index"** label and a distinct card style, so they read as the family rollup, not a peer price. **Ammonia note (encoded):** the Nitrogen family lists urea + the EU N composite; if ammonia is ever wired it sits as its **own** line, **never merged into urea** (documented in `commodity_glossary.js` and inherent to the per-row card model).

## The glossary is DESCRIPTIVE, not analysis
`commodity_glossary.js` is a static dictionary: per-commodity definitions/uses, abbreviation expansions (DAP → Diammonium phosphate), and pricing-basis explanations (FOB US Gulf → "free-on-board at a US Gulf port: a global benchmark loading point, not a US-only price"). **No prices, no direction, no market commentary.** It is banned-words-scanned (clean), manifest-hashed (via the `dashboard/` glob), and bundled in the offline artifact. The per-card analysis slots remain empty (`data-analysis-slot` hooks, "Analysis pending — Claude layer"; 59 present).

## The rollups are MECHANICAL counts only
Each family header shows `over <lens>: ▲up ▬flat ▼down (· n/a k)`, computed as `sign(row's lens % change)` with a single tunable flat band `ROLLUP_FLAT_BAND = 0.5%`. No prose, no interpretation. Sanity-checked across lenses: at 3m, Cereals = ▲5 ▬0 ▼1 (Maize-EU −0.7% → ▼) and Phosphate = ▲3 ▬1 ▼0 (Phosphate Rock +0.0% → ▬); at event, larger Jan→now moves give Cereals ▲6 ▬0 ▼0. The band separates flat from up/down at fine resolution and isn't washing everything into one bucket.

## Evidence — live run `28335373787` (green), commit-back `1901b2d`→ this run
- **Rendered-DOM gate (CI, restructured page):** `canvases 236/236` across all 4 lenses **and inside sliders**, **families 17**, `console_errors 0`, `banned_hits 0`, `empty_summaries 0`, `analysis_slots 59`, `verdict PASS`, **external resources: 0**.
- **Offline artifact:** `hash verification 5/5` (data.js, display_contract.js, synthesis.js, commodity_exposure.html, **commodity_glossary.js**), extracted-copy QA `236/236` + 17 families + **0 external** PASS.
- **Secrets** (post-change): FRED 0 / EIA 0 / USDA 0. **Freshness:** 59 fresh / 0 kept-prior / families 7/7/0.
- **Live Pages URL:** serves the **restructured** page (segments "Crops & Ingredients", families "Cereals & Grains" present), `commodity_glossary.js` HTTP 200, `generated_utc 2026-06-28T20:47:07Z` = this run's committed manifest, **0 external refs on the live page**. Screenshot: `logs/exposure_qa/pages_live_m13.png`.
- **Fail-blank verified** (scratch fixture): 14 of 17 families resolved to 0 rows and were **omitted cleanly** (`families: 3`), the 1-card families rendered with **no arrows** (`arrows: 0`), a truncated row degraded to no-data (`nodata 3`), `console_errors 0`, `verdict PASS`. 1-card and 0-card groups do not break.

Sample-stage screenshots (reviewed before commit): `m13_slid_narrow.png` (off-screen slider card drawn), `m13_bubble_dap.png` (basis decode), `m13_3m.png`/`m13_event.png` (rollup under two lenses), `m13_hover.png` (four-basis hover).

## Discipline carried forward
0 external resources (enforced by `run_exposure_qa.ps1`); consumes committed pipeline data; data-emit paths untouched; analysis slots empty; fail-blank never fail-stale.

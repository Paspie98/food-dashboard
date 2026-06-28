# M11 — Production front-end QA (`commodity_exposure.html`)

**Status: built to ~90% (skeleton), locally green. Nothing committed pending review.**
Date: 2026-06-28. Page: `commodity_dashboard/dashboard/commodity_exposure.html`. Gate: `commodity_dashboard/scripts/run_exposure_qa.ps1`.

## What this is
A production front end in the v5 design language (`commodity_exposure_v5.html` reference: DM Sans / DM Mono / Instrument Serif, light theme, card grid, two-line rebased overlay) that **consumes the committed pipeline outputs** — `data.js`, `display_contract.js`, `synthesis.js`, `build_manifest.js` — via `<script src>` from the same directory. The page only reads; the pipeline only writes; they share the committed files, so the weekly commit-back updates the page with no redeploy, and the analysis layer can drop in later without touching the pipeline.

## What's wired
- **Five segment sections** read from `meta.segment` (not hardcoded): S1 farm inputs · S2 raw crops · S3 processed ingredients · S4 logistics & energy · S5 packaging. Each section header carries the segment's synthesis state from `synthesis.js`, dated by its **slowest contributing row** (min latest-obs across that unit's evidence) so the headline doesn't imply daily precision.
- **Region as a visible pairing, never a toggle.** Within a segment, cards are sorted by commodity then region (EU, US, world, origin) so regional variants sit adjacently, each with a region badge. Examples surfaced side by side: eggs (EU weekly ‖ US monthly), wheat (EU FR weekly ‖ US CMO monthly), soybean oil ‖ rapeseed oil, diesel/gasoline (US EIA ‖ EU Oil Bulletin), all packaging & fertiliser (US PPI ‖ EU Eurostat).
- **Four period lenses** (pure front-end slice/rebase of the captured history — no new data):
  - **Event overlay** — calendar-aligned, v5-faithful: each row's Jan 2022→H1 (orange, mapped onto the 2026 calendar) and Jan 2026→H1 (blue), each rebased to 100 at its January start.
  - **YTD** — rebased to 100 at the first 2026 observation.
  - **YoY** — trailing-12m line rebased to 100; stat = now vs 12 months prior.
  - **Last 3 months** — trailing quarter rebased to 100.
- **Card anatomy** (v5 preserved): commodity name + series subtitle → hand-rolled two-line overlay chart (dependency-free canvas, v5 colors `#d4650a`/`#2558c7`) → **lens-adaptive stat strip** ('22 pk / '26 pk / now for event; YTD / YoY / 3M % otherwise) → **source line auto-rendered from the registry** (`institution` + `tier`) → **two reserve lines** carrying data (latest value/date/cadence; lens-specific period stat) → crosscheck line for the 8 rows that carry one (labelled unofficial daily, supplement not spine) → **empty labelled analysis slot**.
- **Cadence + freshness:** every card shows a native-cadence badge and its latest-obs date; monthly and weekly cards are visibly different vintages.

## Analysis slots are intentionally EMPTY
Every card ends in a dashed, labelled placeholder reading "Analysis pending — Claude layer" with a `data-analysis-slot="<row_id>"` hook. **No analysis is written and no context is fabricated here** — the analysis layer is out of scope for this mission and will populate these slots later. The QA gate counts 59 analysis slots present (one per card). The v5 reference's narrative intro/takeaway/reserve text was *not* copied: it is analysis (and contains banned words), so it stays in the empty-slot domain.

## Resolution honesty — which segments render at which cadence, and why
The page renders each card at the **true cadence of its underlying series** and labels it; it never interpolates monthly into fake weekly.
- **Weekly** (the feed is genuinely weekly): EIA energy EN-003..006 (WTI, Henry Hub, diesel, gasoline); EU Oil Bulletin EN-007/008 (EU diesel, petrol); DG AGRI physical WH-003, MZ-002, EG-001, VO-005, DY-001, DY-002.
- **Quarterly**: FE-007 (EU fertiliser input index), FR-005 (EU land-freight PPI).
- **Monthly** (everything else): World Bank CMO traded benchmarks (cocoa, coffee, wheat US, maize, sugar, oils, fertiliser raws, Brent, coal, aluminium), FRED US PPI rows, Eurostat monthly indices, FAO indices, BLS eggs.

Consequence: in the event-overlay lens the traded benchmarks (CMO) show ~monthly points (coarser than v5's weekly Bloomberg line, which the pipeline does not have for these), while energy and EU-physical show weekly. This is stated, not hidden. Quarterly obs are stored as `YYYY-MM` (quarter-end month), so date math is exact.

## Gate evidence (`run_exposure_qa.ps1`, headless Chrome, file://)
Rendered-DOM self-report (`?qa=1`), captured on attempt 1/5 (timer-based draws → headless `--dump-dom` captures them):
```
canvases_total : 236   (59 cards × 4 lenses)
canvases_drawn : 236   → every card's chart draws under all four lenses
nodata_card_lens: 2
console_errors : []
banned_hits    : []
empty_summaries: 0
analysis_slots : 59
footer_status  : PASS
verdict        : PASS
```
Screenshots archived (one tall capture per lens, each showing all five segments), `logs/exposure_qa/`:
`exposure_event_20260628_173945.png` (667 KB) · `exposure_ytd_*` (593 KB) · `exposure_yoy_*` (621 KB) · `exposure_3m_*` (587 KB).

The 2 `nodata_card_lens` are correct fail-blank, not defects: **FR-005** (quarterly, latest `2025-12` → no 2026 print) and **FE-007** (quarterly, latest `2026-03` → only one print since Jan) in the **YTD lens**, which needs ≥2 points to rebase a line. Those cards show "YTD n/a" + the honest latest-date reserve line — never a stale number dressed as current.

## Fail-blank verified (never fail-stale)
Controlled scratch fixtures:
- **Missing row** (`GHOST-1` present in `display_contract` + `synthesis` evidence but absent from `data`): skipped from rendering, synthesis date math guards it — 0 console errors, verdict PASS, `canvases_total` = 2×4 = 8 (only the real rows rendered).
- **Truncated row** (`SHORT-1`, a single 2026 observation): degrades to a clean no-data state in YTD/YoY/3M (`nodata_card_lens: 3`), draws the reference line, no error.
- **Missing data file** (`DASHBOARD_DATA=null`): neutral "nothing rendered" banner, footer still renders, no JS error markers — degrades, does not crash.

## Hosting
Per decision: **no GitHub Pages yet** (repo stays private). The page runs from `file://` and is suitable for the offline artifact. The architecture (`<script src>` for siblings) means enabling Pages later requires only pointing Pages at the dashboard folder (or copying the dashboard folder to `/docs` as a build step) — no code change. Pipeline scripts are untouched: the new page is QA'd via its own `run_exposure_qa.ps1`.

## Out of scope (left as labelled empty slots)
Per-card analysis/context text (the Claude analysis layer).

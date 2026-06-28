# Mission 1 QA — Master Source Registry

Date: 2026-06-12. Registry under test: `registry/commodity_registry_v1_active.csv`.
Spec written first: `docs/registry_spec.md` (schema, lifecycle, sourcing rules, three
documented schema extensions: `chartable`, `inbox_pattern`, `series_code`).

## Completion gate evidence

`scripts/tests/test_registry_integrity.ps1` — **RESULT: PASS (registry integrity)**,
exit 0, run 2026-06-12 (local). Checks enforced: duplicate/malformed row_ids, all
mandatory fields populated, enumerated values, every layer represented, tier-3 ⇒
non-chartable, licensed-lane invariants (access ⇔ uploads_inbox ⇔ inbox_pattern ⇔
probe_status=licensed), staleness-budget/cadence map, {KEY} placeholder discipline +
raw-key scan, banned-words scan over registry prose.

## Counts (verbatim from gate output)

```
rows_total=61
layer L1-product = 24
layer L2-ingredient = 17
layer L3-input = 11
layer L4-packaging = 9
tier 1 = 60
tier 2 = 1
tier 3 = 0
family eu_agrifood = 8
family eurostat = 7
family fao = 5
family fred = 7
family icco = 1
family ico = 1
family licensed_upload = 11
family mpob = 1
family usda = 3
family worldbank = 17
data_class realised = 58; forecast = 3
access open = 40; open-with-key = 10; licensed-upload = 11
```

61 rows is inside the 60–90 target without padding; every row earned its place via a
one-sentence procurement relevance.

## Composition notes

- **Licensed lane (11 rows)**: ICE cocoa London/NY, ICE arabica/robusta, white sugar
  No.5, raw sugar No.11, MATIF wheat/corn, CBOT wheat/corn, TTF. All carry
  `inbox_pattern=bloomberg_weekly_*.xlsx#settlements#<TICKER>`; all tickers marked
  provisional pending validation against the first real workbook (no fabrication).
- **Forecast class (3 rows)**: USDA PSD world wheat/corn ending stocks + world sugar
  production, `data_class=forecast`, fenced from realised rollups by spec §8.
- **Tier 2 (1 row)**: MPOB crude palm oil — the only tier-2 body with a plausibly
  machine-readable series; CEPI/Fertilizers Europe/GAPKI/ISMA/IEA excluded (gaps file).
- **Tier 3 (0 rows)**: by principle; gate still enforces non-chartable for any future row.
- **probe_status**: 50 `pending` + 11 `licensed`. Zero rows claim `proven` — nothing has
  been probed yet, and nothing will be captured before Mission 2 proves it.

## Exclusions summary (full detail in registry/commodity_registry_gaps.md)

- No open named-institution series: ammonia, AN/CAN spot, sulfur, agricultural lime spot.
- Licensed-no-upload-planned: FOEX PIX pulp, LME official cash, CME dairy, GDT.
- Redundant: MAP (DAP-class), FRED natgas-EU mirror, direct IMF SDMX (API in migration),
  USDA AMS US physical detail.
- Unstable endpoints registered-at-risk instead of hidden: ICCO daily, ICO composite,
  FAO FPI slugs, DG AGRI oilseeds/fertiliser APIs, 4-digit NACE PPIs, USDA PSD world
  aggregates — all listed on the watchlist with named risks.

## Inputs owed before Mission 2 completes (user actions)

1. `FRED_API_KEY` (exists in consumer build's CI secrets; not on this machine).
2. `USDA_FAS_KEY` (free registration) — only blocks the 3 forecast-row probes.
3. One real `bloomberg_weekly_YYYY-MM-DD.xlsx` in `uploads_inbox/` to validate the
   licensed lane contract (never fabricated by the build).

## Verdict

Mission 1 completion gate: **GREEN**. Registry is the foundation; no capture, build or
synthesis code exists yet, by design (spec-before-code, probe-before-wire).

# Mission 5 QA — QA Gates, Ratchets, Manifest, Orchestrator

Date: 2026-06-12.

## Full refresh_all.ps1 run — completion gate evidence

Final run (capture run `20260612_021304`): **OVERALL: PASS**, with every step named:

```
[PASS] validate-registry / capture / ingest-licensed / build-data / build-display-contract
[SKIPPED] synthesis + its two gates (Mission 7 pending — flips to fatal when shipped)
[PASS] gate-chart-integrity / gate-display-contract / gate-frontend-category /
       gate-axis-sanity / gate-banned-words / gate-licensed-contract
[PASS] qa-secrets-scan (no key-shaped content in emitted artifacts)
[PASS] qa-numeric-history (19115 observations, all castable, finite, unique)
[PASS] qa-ratchet (captured 41 floor 41 / charted 41 floor 41)
[WARN] data-freshness (fresh 40; stale-warn 1 NAMED: SG-003 age 103d vs 3m budget —
       the documented ~2-month EU sugar publication lag; escalation threshold 2x not hit)
[PASS] manifest (BUILD_STATUS=PASS; artifact hashes)
```

Run summary emitted as `logs/refresh_run_summary.json` + `.md` matching the consumer
schema (generated/started/overall/baseline/counts/capture/freshness/gates), and a
contract-schema row appended to `logs/cloud_refresh_freshness_log.csv`
(run_environment=local, runner marker, fetches/fresh/kept-prior/families, kept_prior_row_ids).

## Fail-closed proven live (not just designed)

The first orchestrated run FAILED honestly: `gate-licensed-contract` crashed (missing
.NET assembly reference in the new fixture test) → step FAILURE → **BUILD_STATUS=FAILURE**
in the manifest → run exit 1. No partial-pass, no default-pass. After the fix, the gate
passes and the ratchet from that failed run's manifest still applied (floors had already
risen to 41/41 and were enforced on the passing run) — ratchet and fail-closed verified
against real events in the same session.

## Ratcheted baselines

`build_manifest.json.baselines` carries `captured_floor`/`charted_floor`; refresh_all
reads the previous manifest, fails fatally on regression, and writes
`max(floor, current)` — floors only rise. Observed live: floor 0→41 on first manifest,
then enforced 41/41 on the next run.

## Manifest (dashboard/build_manifest.json)

`BUILD_STATUS`, `generated_utc`, `registry_version` (v6), `baselines`, `counts`,
per-step `gates` statuses, freshness summary with NAMED stale/escalated lists, and
SHA-256 of every emitted dashboard file (manifest itself excluded from its own hash
list). The Mission 6 footer will render strictly from this file — missing status renders
FAILURE (consumer footer-bug lesson).

## New fatal gates this mission

| gate | fixtures | live result |
|---|---|---|
| `test_banned_words.ps1` | positive (6 planted terms must be flagged — detector-alive proof) + negative (neutral %/window phrasing, 0 hits) | both fixtures pass; data.js + display_contract.js scan clean; synthesis.js/index.html auto-join the scan when built |
| `test_licensed_contract.ps1` | 4 rejection classes via scratch-inbox override: corrupt file, wrong columns, registry tickers absent, wrong sheet name | all rejected with named violations, exit 1, history SHA-256 unchanged in every case (never-partial-ingest holds) |
| `qa-secrets-scan` (in refresh_all) | patterns: non-placeholder api_key=, AKIA…, Bearer …, 32-hex | PASS |
| `qa-numeric-history` (in refresh_all) | every value castable+finite, ISO dates, no (row_id,date) duplicates | PASS over 19,115 obs |

## Defect found and fixed this mission (with reproduction)

PS 5.1: bare `@()` over a `List[object]` of Hashtables throws
`ArgumentException: Argument types do not match` (isolated to a 3-line repro; pipeline
materialisation unaffected — which is why probe/capture never hit it). Fixed in
`ingest_licensed_uploads.ps1` (two sites, comment records the repro); fixture writer
factored into `scripts/tests/mini_xlsx_helper.ps1`.

## Verdict

Mission 5 completion gate: **GREEN** — full local refresh_all run PASS, run summary
JSON+MD emitted on the consumer schema, every gate listed with status and detail,
fail-closed and ratchet behaviour both demonstrated on real runs.

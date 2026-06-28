# Capture Specification — Part A: Probe Engine (Mission 2) · Part B: Capture Engine (Mission 3)

Status: Part A written before `probe_endpoints.ps1` existed; Part B (§B1-§B8) appended at
Mission 3 start, before `capture_all.ps1` / `ingest_licensed_uploads.ps1` exist
(spec-before-code). Part A is not edited retroactively except to record probe-driven
endpoint corrections, which always also produce a new registry version.

## A1. Purpose

No registry row is wired into capture unprobed. The probe engine takes every
`access=open` and `access=open-with-key` row of the newest registry and proves, with
archived evidence, that its endpoint returns parseable observations whose latest value
is magnitude-sane. `access=licensed-upload` rows are NOT probed (nothing is fetched for
them, ever); their lane is validated separately (§A7).

## A2. Outcomes (exactly one per row per pass)

| outcome | meaning | registry consequence |
|---|---|---|
| `ok` | fetch + parse succeeded; status, obs count, first/last date, latest value recorded | candidate for `proven` after second pass agrees |
| `failed-fetch` | HTTP error / timeout after retries, with a same-minute control fetch (known-good endpoint) succeeding — failure attributable to the endpoint, not the pipeline (ONS-Revolut pattern) | `watchlist` with reproduction |
| `failed-parse` | bytes arrived but no (date, value) observations extractable | `watchlist` with reproduction |
| `blocked-no-key` | row needs `FRED_API_KEY`/`USDA_FAS_KEY` and the key is absent | stays `pending`; named in QA as user-input-owed |
| `skipped-licensed` | licensed-upload row | unchanged (`licensed`) |

`blocked-no-key` is an honest distinct state: the endpoint is neither proven nor failed.

## A3. Double-fetch proof

A row reaches `probe_status=proven` only when two independent passes ≥ 1 h apart (or
local + cloud) BOTH return `ok` with **identical latest values** (same last date, same
value to full precision). Disagreement (e.g. an intraday update) is recorded and the
later pass repeats once; persistent disagreement → `watchlist` (unstable read).

## A4. Safety rules (mandatory from day one)

- Plain identifying User-Agent: `commodity-dashboard-probe/1.0 (procurement research)`.
- Per-family pacing ≥ 3 s between fetches (one shared workbook fetch may serve many
  rows — pacing applies to physical fetches).
- Exponential backoff on 429/5xx: waits 5 s, 15 s, 45 s; max 3 retries; then the FAMILY
  is aborted for the pass (not the run) and its rows record `failed-fetch` with
  reason `family-throttled`.
- Timeout 60 s per request. No parallel hammering — strictly sequential within a family.
- Keys substituted into `{KEY}` at request time only; never logged, never archived
  (the archived URL is the redacted registry form).

## A5. Artifacts

- Raw responses: `raw_archive/probes/<pass-stamp>/<row_id>_<UTC-stamp>.<ext>` (shared
  family fetches stored once as `FAMILY_<family>_<UTC-stamp>.<ext>` and referenced).
- Results CSV per pass: `raw_archive/probes/probe_results_<pass-stamp>.csv` with columns:
  `pass,row_id,family,outcome,http_status,obs_count,first_date,last_date,latest_value,unit_sane,raw_file,reason`
- `unit_sane` is the order-of-magnitude check vs an external published reference,
  recorded per row in the QA doc with the reference named (EU-coffee-imports lesson).

## A6. Family parsers (probe-time)

| family | transport | parse |
|---|---|---|
| `worldbank` | one xlsx fetch shared by all rows | OpenXML unzip (no Excel COM — CI runners have no Excel); `Monthly Prices` sheet; header row of column codes; extract (month, value) per `series_code` |
| `fred` | JSON API, `{KEY}` from env/.env | `observations[]` → (date, value), drop '.' placeholders |
| `eu_agrifood` | JSON REST | family-specific arrays; price fields may carry currency symbols — strip and cast `[double]`; date fields per endpoint |
| `eurostat` | JSON-stat 2.0 | `value` map + `dimension.time` index; latest non-null |
| `fao` | CSV/XLS asset behind landing page | probe resolves the concrete asset; month-stamped slug risk documented |
| `icco` / `ico` / `mpob` | page/asset | probe records status + content-type; asset discovery documented; watchlist if no machine-readable asset |
| `usda` | JSON API, key header | PSD records → (marketYear, value) for `series_code` attribute/country |

Endpoint corrections discovered while probing NEVER overwrite v1: they are recorded in
the probe results, applied to `commodity_registry_v2_active.csv`, and re-probed. v1
stays untouched (versioned-registry doctrine).

## A7. Licensed lane validation (no fetch)

The lane is proven only by validating one REAL workbook the user drops into
`uploads_inbox/` against the contract (filename `bloomberg_weekly_YYYY-MM-DD.xlsx`,
sheet `settlements`, columns `ticker,date,settle,currency,unit`, every registry ticker
present, dates ISO, settles castable `[double]`). The build never creates a workbook.
Until a real workbook exists, the lane is `defined-awaiting-first-upload` and Mission 2
reports it as a named user-input-owed item — this does not block the open-row gate.

## A8. Mission 2 completion gate restated

Every registry row ends in exactly one of: `proven` (double-fetch agreed), `licensed`
(lane defined; validation owed only if no workbook was provided), or `watchlist`
(documented reproduction). Zero rows undefined. `qa/m2_probe_QA.md` carries the
double-fetch evidence table and the magnitude-sanity table.

---

# Part B — Capture Engine (Mission 3)

## B1. History store

- Single consolidated CSV (consumer pattern): `cleaned_data/commodity_series_history.csv`
  with columns `row_id,date,value`. `date` is ISO: `yyyy-MM` for monthly/quarterly-end
  periods (CMO `2026M05` → `2026-05`; Eurostat `2026-Q1` → quarter-end month `2026-03`),
  `yyyy-MM-dd` for weekly/daily. `value` is the invariant-culture decimal string of an
  explicitly cast `[double]`.
- One cadence per row (registry-defined); no mixing of period granularities on a series.
- No averaging, no interpolation, no padding, no backfill, no synthetic observations.
- File is written sorted by (`row_id`, `date`) — deterministic bytes; re-running the same
  day with unchanged sources produces an identical file (idempotency).

## B2. Eligibility and outcomes (per registry row, per run)

Eligible for API capture: `probe_status=proven` only. `licensed` rows are fed ONLY by
`ingest_licensed_uploads.ps1`. `pending`/`watchlist` rows are logged `not_captured`
with reason — never fetched.

| outcome | meaning |
|---|---|
| `captured` | fetch + parse + guards passed; row's observations REPLACED from this fetch |
| `kept_prior` | fetch or guard failed; existing history untouched (baseline never regresses); named in audit |
| `not_captured` | ineligible (pending/watchlist) or licensed-lane row with no validated upload yet |

Sources return full history each fetch, so replace-per-row is the idempotent merge: same
content → no diff; source revisions flow through; a transient outage cannot delete data
(kept_prior).

## B3. Guards (failure ⇒ kept_prior, never partial)

1. **Min-obs**: a successful fetch must yield ≥ 6 observations (consumer threshold) —
   guards against truncated/markup responses.
2. **Casting discipline**: recognised missing-markers (`…`, `..`, `.`, empty) are absent
   observations and are skipped; ANY other non-castable value in the value position fails
   the row. No silent coercion (string-multiply bug class).
3. **Ambiguity**: after series_code pinning, two records on the same date with different
   values fail the row (ambiguous pin); identical duplicates are deduped.
4. **Pinned-dimension strictness (Eurostat)**: every non-time dimension must be either
   pinned in `series_code` or single-valued in the response; otherwise the row fails.
   Pins from archived probe metadata: `sts_inppd_m` rows add `unit=I21` (2021=100);
   `apri_pi20_inq` adds `product=203000` (Fertilisers and soil improvers), `p_adj=NI`,
   `unit=I20`. Recorded as registry v5 (series_code-only change; endpoints unchanged, so
   Mission-2 proofs stand — extraction is deterministic post-processing of the same
   fetched documents, re-verified against both archived passes in m3 QA).
5. **History minimum at first capture**: target ≥ 36 monthly obs (or cadence equivalent)
   where the source provides it; actual depth recorded per row in the audit and m3 QA.

## B4. Transport

Same safety rules as Part A (§A4): UA, ≥3 s per-family pacing, 5/15/45 s backoff, 3
retries, family abort, 60 s timeout, redirect-following, per-run URL fetch-cache for
shared documents (CMO workbook, FAO CSV, FR cereals, fertiliser API, dairy-per-product).
Every response archived to `raw_archive/capture/<runstamp>/`. Keys substituted at request
time only; never logged.

## B5. Logs (schemas inherited verbatim — never changed without asking)

- `logs/capture_all_log.csv`: `Timestamp,row_id,commodity,family,outcome,obs,kept,raw_file,reason`
  (append per row per run; `kept` = `kept-prior` when applicable, else blank).
- `logs/source_refresh_audit.csv`: `row_id,commodity,source_family,attempted_this_run,fetch_succeeded,observations_fetched,history_source,latest_date_fresh,latest_date_final,failure_reason`
  (rewritten snapshot each run; `history_source` ∈ `fresh-from-source` | `kept-prior` |
  `none`; `latest_date_fresh` = newest date in this run's fetch, `latest_date_final` =
  newest date in stored history after merge).

## B6. Licensed ingestion (`ingest_licensed_uploads.ps1`)

- Reads the NEWEST `uploads_inbox/bloomberg_weekly_YYYY-MM-DD.xlsx` (by filename date).
- Contract validation — ANY violation rejects the whole workbook (no partial ingest):
  sheet `settlements` exists; header contains exactly the set
  `ticker,date,settle,currency,unit` (any order, row 1); every data row has non-empty
  ticker, ISO-parseable date, `[double]`-castable settle; no (ticker,date) duplicate with
  conflicting settle; every registry `licensed` row's `inbox_pattern` ticker present in
  the workbook (first-upload reconciliation: a mismatch is reported with the workbook's
  actual ticker list so the registry can be corrected in a new version — visible, never
  silent).
- On acceptance: workbook archived to `raw_archive/uploads/`, per-ticker observations
  replace that row's history (same idempotent merge, same casting discipline), rows
  appended to `capture_all_log.csv` with `family=licensed_upload`.
- The engine NEVER writes into `uploads_inbox/` (user-only surface).

## B7. CI freshness hook

`CMD_NO_SEED=1` (env) makes `capture_all.ps1` start from an empty in-memory history
(committed history ignored for the merge decision), so a cloud run can prove
fresh-from-source capture (consumer `V3_NO_SEED` pattern). Default behaviour seeds from
committed history.

## B8. Mission 3 completion gate restated

First full local run: every `proven` row `captured` (or honestly `kept_prior` with a
named transient reason), 0 undefined outcomes; both logs populated; ≥ 10 rows
spot-checked across families against the source's own published latest value;
`qa/m3_capture_QA.md` written with the depth table and spot-check table.

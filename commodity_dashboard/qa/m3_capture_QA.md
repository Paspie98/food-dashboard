# Mission 3 QA — Capture Engine

Date: 2026-06-12. Spec written first: `docs/capture_spec.md` Part B (§B1–B8), appended
before any capture code existed. Registry lineage this mission: v5 (Eurostat extraction
pins from archived probe metadata) → v6 (SG-003 `contractType=Monthly data` pin).
Integrity gate PASS on both.

## First full capture — completion gate evidence

Run `20260612_015249` (and idempotency re-run `20260612_015420`) against registry v6:

```
captured = 41; kept_prior = 0; not_captured = 22
history store: 19115 observations across 41 series
```

- **Every proven row captured (41/41), 0 undefined outcomes.** The 22 `not_captured`
  are all named-and-expected: 11 licensed-lane (fed only by ingest), 3 watchlist,
  8 pending-on-keys.
- `logs/capture_all_log.csv` (append, contract schema) and
  `logs/source_refresh_audit.csv` (per-run snapshot, contract schema) populated.
- Raw responses archived under `raw_archive/capture/<runstamp>/` with shared-fetch
  dedup (CMO workbook ×1 for 19 rows, FAO CSV ×1 for 5 rows, FR cereals ×1 for 2 rows,
  fertiliser API ×1 for 3 rows).

## Idempotency (re-running the same day changes nothing)

`commodity_series_history.csv` SHA-256 after run A and run B (76 s apart):
`FCE496FB575F821972A9E20F7EA81344D0E8C1ECB19C788F8E4A81BB4E0ECD63` — identical.
**IDEMPOTENCY: PASS.**

## Guards exercised on real data (not just designed)

1. **Casting discipline caught Excel scientific notation**: first run failed SG-001 with
   `non-castable value "7.0000000000000007E-2"` (kept_prior, exactly as specced — no
   silent coercion). Root cause: the stripping heuristic mangled the exponent. Fix:
   direct invariant-culture parse attempted first (`parse_helpers.ps1`); SG-001 then
   captured 797 obs. The lenient probe had silently skipped those cells (776 obs) — the
   strict capture guard caught what the probe tolerated, which is the point of it.
2. **Ambiguity guard caught a real parallel series**: SG-003 failed with `ambiguous pin:
   two values on 2025-12` — DG AGRI runs `Monthly data` and `Short term contracts`
   series side-by-side since 2025-12 (raw archived). v6 pins `contractType=Monthly data`.
   Without this guard the row would have nondeterministically mixed two price bases.

## Spot-check (gate: ≥10 rows across families)

**20/20 rows** — captured latest equals the source-published latest from the independent
probe pass-3 fetch (≥17 min earlier event, different process), to <0.005 tolerance:
CO-001, CF-001, WH-001, WH-003, MZ-002, SG-001, SG-002, VO-002, VO-004, VO-005, DY-001,
FE-001, FE-006, FE-008, PK-005, PK-002, IX-001, IX-005, EG-001, EN-001 — covering
worldbank, eurostat, eu_agrifood, fao. (SG-003 and FE-007 changed extraction definition
in v5/v6 and are verified instead against their archived raw records: SG-003 EU-Average
Monthly-data 2026/03 = 510.1677 ✓; FE-007 pinned product 203000/NI/I20.)

## History depth (gate: ≥36 monthly obs or cadence equivalent where source provides)

| cadence | series | obs range | assessment |
|---|---|---|---|
| monthly | 34 | 89–797 | min 89 (DG AGRI fertiliser, full source depth) — all ≥36 ✓ |
| weekly | 6 | 231–335 | ≈ 4.4–6.4 years ✓ |
| quarterly | 1 | 25 | ≈ 6.25 years ✓ |

## Licensed lane (tested paths + owed validation)

- **Idle path (real, empty inbox)**: "nothing ingested (lane idle)", exit 0, history hash
  unchanged. PASS.
- **Rejection path (scratch inbox via test-only `CMD_INBOX_DIR` override — the real
  inbox is never written by the build)**: corrupt workbook → `REJECTED … workbook
  unreadable as xlsx`, exit 1 via `-File` invocation, history hash unchanged. PASS.
  Whole-workbook rejection confirmed: no partial ingest path exists before validation
  completes.
- **Acceptance-path validation is owed to the first REAL workbook** (per contract and
  spec A7/B6 — never fabricated). Structural fixture tests for the remaining violation
  classes (missing column, conflicting duplicate, missing registry ticker) are scheduled
  into Mission 5's gate suite via the same scratch-inbox override.

## Engine honesty notes

- `usda` family parser is deliberately deferred until its rows are probe-proven (keys
  owed) — shipping untested parse code violates tested-code-is-shipped-code; the rows log
  `not_captured` with the probe_status reason meanwhile. `fred` parser ships (consumer-
  proven shape) but cannot run until proven.
- `CMD_NO_SEED=1` hook implemented for Mission 8's cloud freshness proof (consumer
  `V3_NO_SEED` pattern); unexercised in this mission's evidence.

## Verdict

Mission 3 completion gate: **GREEN** — first full local run captured every proven row,
zero undefined outcomes, both logs populated per inherited schemas, 20-row spot-check
passed, idempotency hash-proven. Licensed-lane acceptance validation remains owed to the
user's first workbook (named open thread, non-blocking).

# Mission 2 QA — Endpoint Probing

Date: 2026-06-12. Spec written first: `docs/capture_spec.md` Part A.
Registry lineage this mission: v1 (61 rows) → v2 (63: endpoint corrections + FE-010/FE-011
NPK rows) → v3 (VO-005 re-pin DE→RO) → v4 (probe statuses filled). All prior versions
untouched; integrity gate PASS on every version (v4 run 2026-06-12).

## Final row states (v4) — zero undefined

| probe_status | rows | meaning |
|---|---|---|
| `proven` | 41 | double-fetch agreed, magnitude-checked (below) |
| `licensed` | 11 | upload lane defined; validation owed to first real workbook (user action, never fabricated) |
| `watchlist` | 3 | documented reproductions (CO-002 ICCO, CF-003 ICO, VO-006 MPOB) |
| `pending` | 8 | `blocked-no-key`: 5 FRED rows await `FRED_API_KEY`, 3 USDA rows await `USDA_FAS_KEY` — honest distinct state per spec A2; named user inputs, not failures. Not capturable until proven. |

## Double-fetch evidence

| pass | UTC start | registry | outcome |
|---|---|---|---|
| 1 | 2026-06-12 00:12:48 | v1 | 17 ok / 16 failed-parse (label scheme discovered) / 8 failed-fetch / control fetch OK — failures endpoint-side |
| 2 | 2026-06-12 00:29:13 | v2 | 41 ok, 0 failures |
| 3 | 2026-06-12 01:40:55 | v3 | 41 ok, 0 failures (started ≥1h07 after pass-2 fetches began) |

- **40 rows**: pass 2 vs pass 3 identical `(last_date, latest_value)` to full precision —
  comparison script output "AGREE … : 40", archived results CSVs
  `probe_results_20260612_002913.csv` / `_014055.csv`.
- **VO-005**: extraction definition changed between passes (DE→RO re-pin), so the proof is
  RO re-extraction from the archived pass-2 raw (fetched 00:31Z) = `2026-06-07, 1085.91`
  vs pass-3 live = `2026-06-07, 1085.91` → AGREE. The raw file is the fetch; extraction is
  deterministic post-processing.
- **Eurostat rows** additionally agree with pass 1 (00:12Z) — three consecutive identical
  reads.
- Every raw response archived under `raw_archive/probes/<pass>/`; shared fetches stored
  once per pass (CMO workbook, FAO CSV, FR cereals, fertiliser API).

## Magnitude sanity (order-of-magnitude vs external references)

References used: (a) the archived Dec-2024 CMO release (pass-1 artifact — the v1 URL
served the "Updated on January 03, 2025" snapshot, giving an independent prior release of
the same institution's series), (b) cross-institution corroboration within this run.

| row(s) | latest (2026M05 / latest week) | reference & verdict |
|---|---|---|
| CO-001 cocoa | 4.16 USD/kg | Dec-24 release: 10.32 → −60% normalization from the 2024 squeeze; SANE |
| CF-001/002 coffee | 6.95 / 3.67 USD/kg | Dec-24: 7.57 / 5.22; arabica>robusta ordering preserved; SANE |
| WH-001/002/003 wheat | 303 / 259.5 USD/t / 195.2 EUR/t | HRW>SRW ordering; FR physical ≈ 15% under US Gulf SRW in USD — plausible EU-harvest discount; SANE |
| MZ-001/002 maize | 216.2 USD/t / 217.2 EUR/t | Dec-24: 202.6; modest firming, FR premium small; SANE |
| SG-001/002/003 sugar | 0.34 / 0.38 USD/kg / 510.2 EUR/t | FAO sugar index 95.1 (below 2014-16 base) corroborates soft sugar; EU white over world raw is structural; SANE |
| VO-001..005 oils | soy 1775, sun 1505, rape 1473, palm 1140 USD/t; RO rape oil 1086 EUR/t | FAO oils index 185 corroborates a strong oils complex; soy-over-sun spread inversion noted as unusual but cross-confirmed by index level; RO≈WB gap is cif-vs-domestic basis; SANE-WITH-NOTE |
| EG-001 eggs | 292.7 EUR/100kg (EU, barn) | within historical elevated band; EU aggregate consistent with member spread (AT 322 sample); SANE |
| FE-001/008 nitrogen | urea 770.5 USD/t; EU N composite 541 EUR/t | urea +119% vs Dec-24 corroborated by TTF 16.17 USD/MMBtu (+17%) and Eurostat C20.15 PPI 135.7; composite below pure-urea spot as expected; SANE |
| FE-002/003/005/010 phosphates | DAP 769.5, TSP 713.5, rock 152.5 USD/t; EU P 717 EUR/t | DAP +35% vs Dec-24; EU P composite ≈ DAP within FX; rock flat (contract pricing lag); SANE |
| FE-004/011 potash | MOP 405 USD/t; EU K 370 EUR/t | two institutions within FX distance; SANE |
| FE-006/007/009, PK-002/004/007/009 Eurostat PPIs | 113–175 index | plausible index levels (2021=100); three identical reads passes 1-3; SANE |
| EN-001 TTF | 16.17 USD/MMBtu | ≈ €47-50/MWh, elevated but consistent with the nitrogen complex; SANE |
| PK-005 aluminium | 3666.1 USD/t | +44% vs Dec-24; **single-source** (LME licensed, no open cross-check) — no contradiction available; flagged, accepted with note |
| IX-001..005 FAO | 130.8 / 114.3 / 185.0 / 119.2 / 95.1 | values read directly from FAO's published CSV (the publication itself); SANE |
| DY-001/002 dairy | butter 404.8, SMP 279.2 EUR/100kg | EU aggregate consistent with 13-member spread at same date; SMP ≈ €2,792/t plausible; butter level accepted as the source's EU aggregate (pass-1 lexicographic pick of Belgium 399.5 explained, not instability) |

Magnitude rejection exercised this mission: Belgium "Crude rape oil" at 245 EUR/t —
implausible for crude oil (≈ meal level) → excluded from VO-005 pinning (gaps file §2a).

## Watchlist reproductions (full detail in gaps file §2a)

- **CO-002 ICCO**: daily price rendered by wpDataTables `admin-ajax.php?action=get_wdtable`
  (table_id 6/26) → 200 with empty body without a session nonce; page archived pass 1.
- **CF-003 ICO**: legacy ico.org Excel host closes connections (3 backoff retries,
  reproduced); icocoffee.org offers PDFs (`cmr-MMYY-e.pdf`) and a paid statistics DB.
- **VO-006 MPOB**: landing exposes no machine-readable asset.

## Safety compliance

Plain UA `commodity-dashboard-probe/1.0 (procurement research)`; ≥3 s per-family pacing;
exponential backoff exercised live (dairy API 429 ×2 in pass 1, recovered); per-pass URL
fetch-cache dedupes shared fetches; `{KEY}` placeholders never substituted into archived
URLs or logs (no keys present this mission at all).

## Open threads (named, owed, non-blocking)

1. `FRED_API_KEY` (5 rows) and `USDA_FAS_KEY` (3 rows) — when provided in
   `commodity_dashboard/.env`, re-probe fills their double-fetch evidence and a v5
   registry promotes them; until then they stay `pending` and are excluded from capture.
2. Licensed lane validation — awaits the first real `bloomberg_weekly_*.xlsx` (11 rows
   remain `licensed`, never fetched, never fabricated).

## Verdict

Mission 2 completion gate: **GREEN** for every probeable row — 41 proven (double-fetch,
magnitude-checked), 3 watchlist (reproduced), 11 licensed (lane defined; validation owed
to the user's first workbook), 8 pending on named user-owed keys. Zero rows undefined.

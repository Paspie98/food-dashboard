# Mission 9 QA — Five-Segment Re-cut + Segment 4 (Logistics & Energy)

Date: 2026-06-28. Scope: re-cut existing rows into the five-segment × region taxonomy,
build Segment 4 (logistics & energy) from open named-institution sources, re-probe and
re-baseline. No rebuild of the proven skeleton/engine/gates/front-end mechanics.

## Keys & lineage (confirmed at start)
FRED (32), EIA (40), USDA-FAS (40) all live-authenticated before probing (EIA WTI 78.94 =
FRED WTI — cross-source check). A loose `EIA_API_KEY.env` at the repo root was folded into
the git-ignored `.env` (the `*.env` rule from the prior round caught it). **Prior version:
v6.** This mission emitted **v7** (re-cut + S4 candidates) → **v8** (probed + baselined,
the active version). All prior versions untouched.

## Before / after

| | v6 (4-layer) | v8 (5-segment) |
|---|---|---|
| rows | 63 | 62 |
| captured | 41 | **59** |
| charted | 41 | **59** |
| not captured | 22 | 3 (watchlist only) |
| licensed-upload rows | 11 | 0 (retired to gaps §3, lane dormant) |
| forecast rows | 3 (excluded) | 0 |

Ratchet floors re-baselined **41 → 59** (captured/charted) in the manifest.

## Segment × region × tier (v8, 62 rows; all tier 1 except MPOB tier 2)

| segment | rows | geography split |
|---|---|---|
| S1 farm inputs | 11 | origin-specific 5, EU 6 |
| S2 raw crops | 17 | world 10, US 3, EU 4 |
| S3 processed ingredients | 11 | world 6, EU 4, origin-specific 1 |
| S4 logistics & energy | 14 | US 8, EU 4, world 2 |
| S5 packaging | 9 | US 4, EU 4, world 1 |

De-dup applied: natural gas is one S4 row (EN-001), cited by S1, not duplicated;
raw (S2) / processed (S3) kept distinct; FRED energy mirrors dropped in favour of EIA as
the source; eggs S2 with US/EU via geography.

## Segment 4 — double-fetch proof (gate: ≥1h, identical values)

s4A 2026-06-28 11:43Z ↔ s4B 12:52Z (≥1h apart): **14/14 rows agree.** (EN-007/008 compared
via re-extraction of s4A's archived workbook with the fixed parser, since s4A predated the
oil-column fix — raw is the fetch, extraction is deterministic.) The 5 FRED rows from the
prior round: keyedA 11:18Z ↔ keyedB 12:23Z, **5/5 agree.**

| row | source | latest | unit |
|---|---|---|---|
| EN-003 WTI | EIA | 81.36 | USD/bbl |
| EN-004 Henry Hub | EIA | 3.12 | USD/MMBtu |
| EN-005 US diesel | EIA | 4.832 | USD/gal |
| EN-006 US gasoline | EIA | 4.048 | USD/gal |
| EN-007 EU diesel | EU Oil Bulletin | 1.7302 | EUR/L |
| EN-008 EU petrol | EU Oil Bulletin | 1.7615 | EUR/L |
| EN-009 Brent | WB CMO | 107.54 | USD/bbl |
| EN-010 coal | WB CMO | 136.86 | USD/t |
| EN-001 nat gas Europe | WB CMO | 16.17 | USD/MMBtu |
| FR-001 truck tonnage | FRED | 116.8 | index |
| FR-002 PPI truckload | FRED | 209.623 | index |
| FR-003 PPI rail | FRED | 268.732 | index |
| FR-004 PPI deep-sea freight | FRED | 466.381 | index |
| FR-005 EU land-freight PPI | Eurostat | 121.3 | index |

## Magnitude checks (vs the source's own figure)

All EIA/FRED/Eurostat/WB latest values read directly from the source and are magnitude-sane
(US diesel ~$4.8/gal, EU diesel ~€1.73/L with tax, Henry Hub ~$3/MMBtu, freight PPIs
~110–470 index). **Flagged cross-source divergence:** WB CMO's crude complex sits high
(Brent 107.54, its *own* WTI 99.09 at 2026-05) versus EIA WTI 81.36 — a ~$18–26 gap on the
same benchmark, a vintage/scenario difference between sources in this environment. EN-009
is faithful to WB CMO (workbook value verified = 107.54); kept as the global-crude leg with
this caveat recorded, while EIA WTI is the US leg.

## Honest findings resolved this mission (reproduced)

- **EU Oil Bulletin column bug**: the fuel labels repeat per-country and hashtable keys
  iterate unordered, so the first parser grabbed a stray column (stale 2020 data). Fixed to
  take the lowest-index match = the EU-aggregate block; verified €1.73/€1.76 at 2026-06-22.
- **FR-005 Eurostat pin**: pure road freight (NACE H494) has **no EU27 aggregate** series
  (reproduced); H49 land transport (road-dominated) is the populated EU-aggregate series —
  wired and labelled honestly as "land transport (road-dominated)", not "road freight".
- **Licensed lane now dormant**: with 0 licensed rows, the ingest lane gained a fail-closed
  guard (any uploaded workbook is rejected, "lane dormant"); the fixture gate now covers
  both the dormant rejection and the still-present contract validation (via a scratch active
  registry) — 5/5 cases pass.

## Gaps file (updated)
Ammonia (§1, distinct from fertiliser complex, not folded into urea), licensed freight
indices BDI/Drewry-WCI/FBX/UNCTAD/IATA (§6, context-only with FRED/Eurostat PPI proxies),
PIX/LME/CME (§1), USDA PSD forecast (§4), all retired licensed settlements (§3).

## Gate evidence (final refresh_all on v8 — OVERALL: PASS)
validate-registry, capture (59/59, 31,060 obs), build-data, build-display-contract,
synthesis, chart/display/frontend-category(5 segments)/axis/banned-words/licensed-contract/
no-secrets-in-archive/synthesis-fixtures/synthesis-stability gates, secrets scan,
numeric-history scan, ratchet (59/59). Browser QA: **74/74 canvases drawn, 0 console
errors, 0 banned words, footer PASS**, screenshots `dashboard_layers/groups_20260628_131229.png`.
data-freshness WARN (named, non-fatal): FR-001 (ATA truck tonnage, ~120d publication lag),
FR-005 (Eurostat quarterly lag), SG-003 (EU sugar lag).

## First segment synthesis read (2026-05)
S1 farm inputs **escalating** (0.90) · S2 raw crops tightening (0.30) · S3 processed
tightening (0.50) · S4 logistics & energy **escalating** (0.91) · S5 packaging tightening
(0.50) · composite tightening (0.62). Pressure is concentrated upstream (inputs + energy);
the diverging modifier is correctly NOT set (S2/S3 are tightening, not holding).

## Scope note
Built S4 + the re-cut as scoped. USDA **NASS**/AMS US-crop & dairy *realised* rows named in
the S2/S3 tiers are **deferred** (viable — keys work — but outside this mission's S4 add);
flagged as the next increment.

## Verdict
Mission 9 completion gate: **GREEN.** New version v8 (prior untouched), integrity green,
all rows re-tagged, all 14 S4 candidates captured+double-fetched+magnitude-checked, ratchet
re-baselined, gaps updated, QA documented. **Nothing committed (per mission).**

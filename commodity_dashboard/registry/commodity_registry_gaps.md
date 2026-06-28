# Registry Gaps — considered and excluded, or registered-at-risk

Honest-outcomes record, registry v1 (Mission 1) through registry v7 (review corrections
2026-06-12). Nothing here is papered over with a silent substitute. Reason codes per
`docs/registry_spec.md` §9.

## 1. Considered and excluded

| series considered | reason code | detail |
|---|---|---|
| Ammonia (CFR NW Europe / fob Black Sea) | `licensed-no-open-source` | Every ammonia spot benchmark (Argus, CRU, Profercy, ICIS) is licensed commercial intelligence; no open named-institution series exists. **Excluded** (review 2026-06-12: open-source doctrine, no Bloomberg lane). Kept categorically DISTINCT from the broader fertiliser complex and NOT folded into urea — urea (FE-001) remains the captured nitrogen benchmark; the nitrogen read is urea (FE-001) + EU N composite (FE-008) + EU fertiliser PPI (FE-006) + gas feedstock (EN-001). |
| Ammonium nitrate / CAN spot price | `no-named-institution-series` | No open named-institution spot series. Class is covered indirectly and honestly by FE-006 (Eurostat PPI, NACE C20.15 fertilisers & nitrogen compounds) and FE-008 (DG AGRI fertiliser API, N composite). |
| MAP (monoammonium phosphate) | `redundant` | World Bank CMO carries DAP and TSP only; MAP tracks DAP closely at benchmark granularity. DAP/TSP represent the phosphate complex. |
| Sulfur (elemental, fob Vancouver/Middle East) | `no-named-institution-series` | Contract L3 scope names sulfur; only licensed consultancy series exist. Watchlist: revisit if a primary-agency series appears. |
| Agricultural lime spot price | `no-named-institution-series` | No named-institution spot series. FE-009 registers the nearest honest candidate (Eurostat PPI NACE C23.52 lime & plaster). The 3-digit C23.5 fallback was **rejected** as a misleading proxy (cement-dominated). |
| NBSK / BHKP pulp (FOEX PIX) | `licensed-no-upload-planned` | PIX indices are licensed; never scraped (principle 5). Pulp direction is read via PK-001 (US PPI wood pulp) and PK-002 (Eurostat C17.1) under their own honest names — not labelled NBSK. |
| LME aluminium official cash / real-time | `licensed-no-open-source` | LME real-time/official is licensed. The open WB CMO monthly aluminium (PK-005, LME-referenced) covers direction. No Bloomberg lane. |
| CME butter futures; GDT auction (dairy) | `licensed-no-upload-planned` / family-not-listed | CME real-time is licensed; GDT (Fonterra platform) is not among the contract's allowed families. EU Milk Market Observatory weekly butter/SMP (DY-001/002) is the European lens and suffices. |
| FRED PNGASEUUSDM (natural gas EU) | `redundant` | Same IMF concept as WB CMO Natural gas, Europe already registered (EN-001). |
| IMF PCPS via direct SDMX API | `no-stable-endpoint` + `redundant` | dataservices.imf.org SDMX service is in migration/retirement; the same commodities are covered by WB CMO. |
| WB CMO sunflower oil column | n/a (resolved) | Confirmed alive in the current CMO release; registered as VO-003 (CMO direct). |
| Rapeseed oil in WB CMO | n/a (resolved) | Confirmed alive; registered as VO-004 (CMO direct) plus DG AGRI oilseeds physical (VO-005). |
| USDA AMS/NASS physical eggs & dairy detail | `redundant` (for v1 scope) | European lens is primary; US egg read is covered by EG-002 (BLS via FRED). |
| WASDE report attachments (Cornell ESMIS) | `no-stable-endpoint` + `forecast-only` | Per-release attachment slugs. The USDA PSD API is the machine route to WASDE-cycle projections, but the PSD forecast rows are themselves excluded as a model misfit — see §4. |
| CEPI statistics | `no-stable-endpoint` (tier 2) | Annual PDF statistics, no machine-readable series. Context only. |
| Fertilizers Europe data | `no-stable-endpoint` (tier 2) | Member-gated; no public series. |
| GAPKI, ISMA | `no-stable-endpoint` (tier 2) | Press releases only; no stable series. |
| IEA gas market reports | `forecast-only` / context | Outlook documents, not a price series; EN-001 carries the gas read. |
| Reuters, StoneX, Sucafina wires | `tier-3-context-only` | By principle: context only, never charted. v1+ register zero tier-3 rows; any future tier-3 row must be `chartable=context-only` (gate-enforced). |
| Social media sources | excluded by principle | Excluded entirely. |

## 2. Watchlist — registered rows carrying known probe risk (v1 framing)

These rows were registered with a named risk; Mission 2 resolved each to `proven` or to
`watchlist` with a reproduced finding. None may be captured before that.

| row_id | risk |
|---|---|
| CO-002 | ICCO daily price asset behind statistics page; unstable-slug risk. |
| CF-003 | ICO legacy asset path; host migration (ico.org → icocoffee.org). |
| IX-001..IX-005 | FAO FPI CSV slug is month-stamped; pattern must prove resolvable deterministically. |
| VO-005 | DG AGRI oilseeds API existence and product naming unverified. |
| VO-006 | MPOB monthly price table may not be machine-readable (tier 2). |
| FE-006, FE-009 | 4-digit NACE availability in `sts_inppd_m` unverified (C2015, C2352). |
| FE-007 | `apri_pi20_inq` dataset id and fertiliser product dimension code unverified. |
| FE-008 | DG AGRI fertiliser API existence unverified. |

## 2a. Mission 2 probe outcomes (2026-06-12) — updates to the v1 watchlist

| item | outcome |
|---|---|
| CO-002 ICCO daily | **watchlist confirmed** — statistics page serves the daily price via wpDataTables `admin-ajax.php?action=get_wdtable` (table_id 6/26) which returns empty without a session nonce; only quarterly bulletin PDF pages linked. Raw page archived. |
| CF-003 ICO composite | **watchlist confirmed** — legacy ico.org Excel host closes connections (3 retries, reproduced); icocoffee.org publishes market reports as PDF (`cmr-MMYY-e.pdf`) and a subscription statistics database. No open machine series. |
| VO-006 MPOB | **watchlist confirmed** — bepi.mpob.gov.my landing exposes no machine-readable asset (interactive portal). |
| IX-001..005 FAO slug | **resolved** — stable unstamped CSV `food_price_indices_data.csv?download=true` found on the landing page; month-stamped slug candidates all 404. |
| FE-006/FE-009 4-digit NACE | **resolved** — `sts_inppd_m` carries C2015 and C2352; both returned data. |
| FE-007 apri dataset | **resolved** — `apri_pi20_inq` live (5152 obs); fertiliser product dimension pinned at capture from archived dimension metadata. |
| FE-008 DG AGRI fertiliser API | **resolved — exists**. EU-level monthly N/P/K composites in EUR/t; FE-010 (P) and FE-011 (K) added so each composite is its own row. |
| WB CMO workbook URL | **corrected** — thedocs doc-hash rotates per release; resolved from the stable landing page `worldbank.org/en/research/commodity-markets` per run. |
| VO-005 crude rape oil pin | **corrected (v3)** — Germany ceased reporting 2025-03 (reproduced); Belgium rejected on magnitude (245 EUR/t implausible for crude oil); Romania pinned (weekly, current). |
| EU API transport note | ec.europa.eu/agrifood redirects to api.tech.ec.europa.eu — clients must follow redirects; dairy API 429s readily (backoff proven). |
| FRED-keyed rows (EG-002, PK-001/003/006/008) | **proven & promoted (v7, 2026-06-12)** — `FRED_API_KEY` provided; double-fetch ok; see §5. |

## 3. Licensed-upload rows — retired to documented exclusions (review 2026-06-12)

The 11 exchange-settlement rows previously fed by manual Bloomberg `GET PRICE` Excel
pulls are **excluded** from the active registry (v7). Decision: the dashboard's doctrine
is open-source *replacement* of that manual workflow, not its recreation; there is no
weekly workbook and none is expected. `ingest_licensed_uploads.ps1` and its fixture gate
remain in the tree but **dormant** — no registry row references the lane, and no row sits
in a pending-upload state. Each settlement series is superseded by an open counterpart
already captured:

| retired row | settlement series (ticker) | superseded by (open, captured) |
|---|---|---|
| CO-003 | ICE London cocoa (LCOA) | CO-001 WB CMO cocoa (ICCO-basis monthly) |
| CO-004 | ICE US cocoa (CC) | CO-001 WB CMO cocoa |
| CF-004 | ICE Coffee C arabica (KC) | CF-001 WB CMO arabica |
| CF-005 | ICE Robusta (RC) | CF-002 WB CMO robusta |
| WH-004 | Euronext MATIF milling wheat (CA) | WH-001/WH-002 WB CMO wheat + WH-003 EU physical (French milling wheat) |
| WH-005 | CBOT SRW wheat (W) | WH-001/WH-002 WB CMO wheat |
| MZ-003 | Euronext MATIF corn (EMA) | MZ-001 WB CMO maize + MZ-002 EU physical (French maize) |
| MZ-004 | CBOT corn (C) | MZ-001 WB CMO maize |
| SG-004 | ICE White Sugar No.5 (QW) | SG-001/SG-002 WB CMO sugar + SG-003 EU ex-works |
| SG-005 | ICE Raw Sugar No.11 (SB) | SG-001 WB CMO world sugar |
| EN-002 | ICE Endex TTF settlement (TTF) | EN-001 WB CMO Natural gas, Europe (monthly, TTF-referenced index) |

**EN-001 relabel (v7):** "Natural gas, Europe, monthly (World Bank CMO)" (commodity
`natural gas`). It is the open WB monthly index (TTF-referenced in recent vintages),
**not** an exchange settlement; the earlier "(TTF basis)" framing is removed.

## 4. USDA PSD forecast rows — excluded as a model misfit (review 2026-06-12)

FC-001 (world wheat ending stocks), FC-002 (world corn ending stocks), FC-003 (world
sugar production) are **excluded** from the active registry. Reproduced findings:

- The registered endpoint `apps.fas.usda.gov/PSDOnlineDataServices/...` is **deprecated
  (HTTP 404)** — reproduced in probe pass A (2026-06-12) with a same-pass control fetch
  succeeding (failure attributable to the endpoint, not the pipeline).
- The current API `api.fas.usda.gov/api/psd/commodity/{code}/world/year/{year}`
  (`X-Api-Key`) **works** (wheat world MY2026 → 15 records) but returns **one
  balance-sheet value per marketing year**, keyed by numeric `attributeId` — an
  **annual** datum, not the **monthly price time series** this dashboard's realised-price
  model, cadence enum (daily/weekly/monthly/quarterly) and synthesis are built around.
- Forcing an annual marketing-year figure into the monthly model would be a misfit; per
  the "honest outcomes / don't force a misfit / document and STOP the thread" doctrine
  the thread is stopped, not bodged. The front-end forecast block remains designed and
  ready; a future dedicated forecast feed (annual balance-sheet trajectory, its own
  cadence) can populate it as a scoped addition. No realised row depends on these.

## 5. Inputs / status (updated 2026-06-12)

- `FRED_API_KEY` — **provided** (git-ignored `commodity_dashboard/.env`; GitHub Actions
  secret for CI). Five FRED rows promoted: EG-002 (US eggs, BLS), PK-001 (wood pulp PPI),
  PK-003 (containerboard PPI), PK-006 (glass PPI), PK-008 (plastics/resin PPI).
- `USDA_FAS_KEY` — **provided**; authenticates against `api.fas.usda.gov`, but the PSD
  rows are excluded per §4 (data-model misfit, not a key problem).
- Bloomberg weekly workbook — **not expected** (§3); lane dormant.
- Key hygiene: keys live only in `.env` (now `*.env`-ignored) and CI secrets; a fatal
  `test_no_secrets_in_archive.ps1` gate scans raw_archive/logs/cleaned_data/dashboard for
  literal key values and `api_key=`-bearing URLs (both FRED and EIA embed the key in the
  request URL — same leak vector; the gate covers both).

## 6. Segment 4 logistics — freight licensing wall (review 2026-06, M9)

Open energy/fuel is fully captured (EIA US fuel/gas/crude, EU Oil Bulletin EU fuel, WB CMO
crude/gas/coal, FRED freight PPIs, Eurostat road-freight PPI). The freight INDEX complex is
the licensing wall — same shape as the parked Bloomberg settlements: documented here, never
scraped, carried as context names only. The open FRED PPI freight rows (truckload FR-002,
rail FR-003, deep-sea FR-004) and EU road-freight PPI (FR-005) are the captured proxies.

| freight index | reason code | detail |
|---|---|---|
| Baltic Dry Index (BDI) | `licensed-context-only` | Baltic Exchange licensed; not charted. Dry-bulk direction proxied by WB CMO commodity levels + FR-004 deep-sea PPI. |
| Drewry World Container Index (WCI) | `licensed-context-only` | Headline sometimes openly quoted but the series is licensed; not scraped. Container direction proxied by FR-004. |
| Freightos Baltic Index (FBX) | `licensed-context-only` | Some prints openly published; full series licensed → context only. |
| UNCTAD maritime statistics | `low-frequency-annual` | Open but annual/structural — not a monthly price series; context only. |
| IATA air-cargo rates | `licensed-context-only` (tier 2) | No open machine series; context only. |

EU road-freight VOLUMES (Eurostat `road_go_*`) are open but annual/lagged → not wired
(annual cadence is outside the enum); the quarterly road-freight PPI (FR-005) carries the
EU road read instead.

## 7. Daily/weekly cadence-upgrade candidates — probed live, excluded (2026-06-28, M10)

Goal was to lift the traded benchmarks (cocoa, coffee, wheat, corn, soybeans, sugar, veg
oils, aluminium) from WB CMO **monthly** to free, named, reliable **daily/weekly**. Every
candidate was fetched live and classified on observed evidence. **None passed**; the
monthly WB CMO average remains the honest floor (it is itself named/verified/double-fetched).

| candidate | reason code | reproduced finding |
|---|---|---|
| Nasdaq Data Link (ICE softs / CHRIS continuous) | `free-tier-unreachable` | anonymous returns **HTTP 403 on everything incl. the LBMA/GOLD control**; CHRIS continuous-futures DB discontinued; softs paywalled |
| Alpha Vantage commodities | `no-cadence-gain` | demo key works but SUGAR/COFFEE/WHEAT/CORN return **monthly "Global Price of …"** (re-served IMF/World Bank macro — same class we already hold); energy is EIA redistribution, redundant |
| Yahoo Finance `=F` | `unofficial-sole-source-forbidden` | daily & broad coverage confirmed (cocoa CC=F, coffee KC=F, wheat ZW/KE=F, corn ZC=F, soybeans ZS=F, sugar SB=F, soyoil ZL=F, aluminium ALI=F; robusta RC=F = 404) but unofficial/redistributed, no exchange attribution in payload → permissible only as labelled cross-check, **never a row's sole source**; no second daily source to pair → not wireable |
| CME CmeWS settlements | `no-open-eod` | **HTTP 403** (bot-blocked, all product ids); redistribution ToS-restricted |
| ICE delayed settlement | `no-open-eod` | **HTTP 403** |
| Databento | `key-required-credit-exhausts` | **HTTP 401** (account key required); free credit is one-off and does not sustain a recurring weekly pull |
| Black-box aggregators (commodities-api.com, API Ninjas, Twelve Data, Tradefeeds, Finnworlds, FinanceFlow, etc.) | `provenance-not-attributable` | excluded by rule at the root — upstream source unnamed; not probed beyond noting existence |

Honest limitation recorded: the monthly floor is genuinely lagged on fast markets (e.g.
cocoa daily front-month ≈ +25% vs the WB May average), but no credibly-attributable free
daily source exists to close that gap. A cross-check-overlay schema addition (WB spine +
labelled Yahoo cross-check field) is the only compliant way to surface daily corroboration;
flagged for user decision (schema change), not implemented.

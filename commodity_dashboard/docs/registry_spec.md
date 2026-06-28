# Registry Specification — Commodity Cost Dashboard

Status: v1 (Mission 1). Written BEFORE the registry CSV, per the spec-before-code principle.
Scope: defines the master source registry schema, allowed values, identifier scheme,
sourcing rules, and the lifecycle every row passes through. The registry is the single
foundation: capture, build, display and synthesis all hang off it.

---

## 1. Purpose and doctrine

The registry enumerates every commodity price series the dashboard may ever chart or cite.
Doctrine inherited from the consumer build:

- **Registry-first**: no series exists in the pipeline unless it has a registry row.
- **Probe-before-wire**: a row is never captured until Mission 2 has proven its endpoint
  live (or validated its licensed-upload lane). `probe_status` records this.
- **No fabricated data**: the registry carries *sources*, never values. Every value in the
  dashboard must trace to a raw file fetched from a row's named endpoint (or its validated
  upload lane).
- **Honest outcomes**: a series we wanted but could not source honestly lives in
  `commodity_registry_gaps.md` with a reason — never silently substituted.
- **Versioned registries**: `commodity_registry_v1_active.csv`, then v2, v3 … Prior
  versions are never edited. Readers select the highest version with fallback to earlier.

## 2. Taxonomy

**v7 re-cut (2026-06): the registry taxonomy is the FIVE-SEGMENT scheme below; the
`segment` field replaces `layer`. Region is a tag (`geography` = EU|US|world), not a
parallel structure.**

| segment | name | scope |
|---|---|---|
| `S1` | Farm inputs | urea, DAP, TSP, potash, phosphate rock, EU N/P/K composites, fertiliser/input PPIs |
| `S2` | Raw crops | cocoa, coffee, milling/soft wheat, maize, eggs, raw/world sugar, FAO food/cereals/sugar indices |
| `S3` | Processed ingredients | white sugar, vegetable oils, butter, SMP, FAO oils/dairy indices |
| `S4` | Logistics & energy | crude (WTI/Brent), natural gas, coal, US + EU fuel, truck/rail/ocean/road freight |
| `S5` | Packaging | pulp, paper/containerboard, aluminium, glass, plastics/PET PPIs |

De-dup rules: each row appears once at its chain position; **natural gas is a single S4
price row (EN-001), cited by S1 as feedstock, not duplicated**; raw (S2) and processed
(S3) stay distinct rows (the refined-minus-raw spread is signal); eggs are S2 with the
US/EU split via `geography`. `data_class` stays a hard line (forecast separate).

New source families (v7): `eia` (US EIA; key embedded in request URL like FRED),
`eu_oil_bulletin` (EU Weekly Oil Bulletin history xlsx, download GUID resolved from the
landing page each run, like the CMO workbook). Adding any further family still requires
asking first.

Optional `crosscheck` field (v9, user-approved overlay): `yahoo#<ticker>#<mult>#<native_unit>`
on chartable realised rows only. It attaches an UNOFFICIAL daily Yahoo Finance figure
(converted to the spine unit via `<mult>`) as a labelled cross-check *field* on the named
spine row — never its own row (Yahoo may never be a sole source). Fetched by
`build_crosscheck.ps1` into a separate store `cleaned_data/crosscheck_latest.csv` (never
the spine history); guarded by `test_crosscheck_integrity.ps1` (ratio 0.33–3.0, no history
pollution, "unofficial" label). Daily overlay and monthly spine stay categorically
distinct and are never reconciled.

### (superseded by the segments above) original four-layer taxonomy

| layer code | name | commodities in scope (v1) |
|---|---|---|
| `L1-product` | Finished/traded softs & grains | cocoa, coffee Arabica, coffee Robusta, wheat (MATIF milling + CBOT SRW + WB benchmarks + EU physical), maize (MATIF + CBOT variants + WB + EU physical), eggs |
| `L2-ingredient` | Intermediate ingredients | white sugar, raw sugar, soybean oil, palm oil, rapeseed oil, sunflower oil, butter, SMP |
| `L3-input` | Agricultural inputs | urea, DAP/MAP-class phosphates, TSP, potash, phosphate rock, fertiliser cost indices, TTF natural gas (nitrogen feedstock, flagged `feedstock=yes` in notes) |
| `L4-packaging` | Packaging | pulp, paper & containerboard, aluminium, glass, PET/plastics |

Cross-commodity composite indices (FAO Food Price Index family) are registered under the
layer whose cost story they inform (cereals → L1; vegetable oils, dairy, sugar → L2;
overall food index → L1) and are marked `index` in `unit`.

Commodities demanded by the build contract but not sourceable from a named open
institution in v1 (ammonia, ammonium nitrate/CAN, sulfur, agricultural lime if the
4-digit Eurostat PPI is absent) are handled per the gaps file — see §9.

## 3. Row schema (CSV column order, exact)

Columns marked (opt) may be blank; all others are mandatory for every row.

| # | column | definition / allowed values |
|---|---|---|
| 1 | `row_id` | Stable id, `^[A-Z]{2}-\d{3}$`. Never reused, never renumbered. Prefix map in §4. |
| 2 | `commodity` | Canonical commodity name, lowercase (e.g. `cocoa`, `wheat`, `white sugar`). |
| 3 | `layer` | `L1-product` \| `L2-ingredient` \| `L3-input` \| `L4-packaging`. |
| 4 | `series_name` | Precise series description incl. grade/contract/geography. |
| 5 | `relevance` | One sentence: why it matters to a European food producer's cost base. |
| 6 | `data_class` | `realised` \| `forecast`. Hard categorical line — never mixed downstream. |
| 7 | `tier` | `1` (exchange settlement / primary agency) \| `2` (recognised industry body) \| `3` (commercial intelligence — context only). |
| 8 | `institution` | Named source institution. "X via FRED"-style attribution allowed (consumer pattern). |
| 9 | `source_family` | Parser family: `worldbank` \| `fred` \| `eu_agrifood` \| `eurostat` \| `usda` \| `icco` \| `ico` \| `fao` \| `mpob` \| `licensed_upload`. Adding any other family requires asking the user first (contract §10). |
| 10 | `endpoint` | Exact retrievable URL/API call (best-known candidate until Mission 2 proves it), or literal `uploads_inbox` for licensed rows. FRED endpoints embed `{KEY}`, substituted at fetch time from `FRED_API_KEY` (env or git-ignored `.env`) — consumer convention. USDA PSD endpoints authenticate via `USDA_FAS_KEY` header, same handling. |
| 11 | `series_code` (opt) | Machine hint for the family parser: World Bank CMO column code, FRED series id, Eurostat dataset#dimension filter, EU agri-food product/market filter. Deliberate schema extension — see §10. |
| 12 | `access` | `open` \| `open-with-key` \| `licensed-upload`. `licensed-upload` ⇔ `endpoint=uploads_inbox`. |
| 13 | `refresh_cadence` | `daily` \| `weekly` \| `monthly` \| `quarterly`. |
| 14 | `staleness_budget` | Fixed map from cadence, inherited day one: daily→`7d`, weekly→`3w`, monthly→`3m`, quarterly→`2q`. The integrity gate enforces the map. |
| 15 | `unit` | e.g. `USD/t`, `EUR/t`, `EUR/100kg`, `index`, `USD per dozen`. |
| 16 | `geography` | `EU` \| `US` \| `world` \| `origin-specific` (detail stays in `series_name`). |
| 17 | `chartable` | `yes` \| `context-only`. Every `tier=3` row MUST be `context-only` (fatal gate). Deliberate schema extension — see §10. |
| 18 | `inbox_pattern` (opt) | Mandatory for `access=licensed-upload`: `bloomberg_weekly_*.xlsx#settlements#<TICKER>`. Blank otherwise. Deliberate schema extension — see §10. |
| 19 | `probe_status` | Lifecycle state, §6: `pending` → `proven` \| `failed` \| `watchlist` \| `licensed`. v1 ships with `pending` (open rows) and `licensed` (upload rows, lane validation still owed by Mission 2). |
| 20 | `notes` (opt) | Caveats: probe risk, publication lag, `feedstock=yes`, ticker-confirmation owed, code uncertainty. |

CSV conventions: UTF-8, header row, every field double-quoted, one line per row, no
blank lines. Numeric-looking fields (`tier`) are still read as strings and cast
explicitly (`[int]`/`[double]`) at every consumer boundary — the string-multiply bug class.

## 4. row_id prefix map

| prefix | domain | | prefix | domain |
|---|---|---|---|---|
| `CO` | cocoa | | `DY` | dairy (butter, SMP) |
| `CF` | coffee (both varieties) | | `IX` | FAO composite indices |
| `WH` | wheat | | `FE` | fertilisers & phosphates |
| `MZ` | maize/corn | | `EN` | energy feedstock (TTF) |
| `EG` | eggs | | `PK` | packaging |
| `SG` | sugar | | `FC` | forecast-class rows (USDA PSD) |
| `VO` | vegetable oils | | | |

Numbering is append-only within a prefix. A retired row keeps its id (status moves to
watchlist/failed); the id is never reassigned.

## 5. Sourcing rules

- **Tier 1**: ICE/Euronext/CBOT settlement via licensed Bloomberg uploads, World Bank
  (CMO "Pink Sheet"), IMF, USDA, EU Commission DG AGRI agri-food data portal, Eurostat,
  FRED (incl. "X via FRED" mirrors), ICCO, ICO, FAO.
- **Tier 2**: CEPI, Fertilizers Europe, MPOB, GAPKI, ISMA, IEA. v1 registers MPOB only;
  the others have no stable machine-readable series (gaps file).
- **Tier 3**: Reuters, StoneX, Sucafina — context only, never charted. v1 registers zero
  tier-3 rows; the integrity gate still enforces the non-chartable rule for any future ones.
- **Social media: excluded entirely.**
- **Licensing safety**: Bloomberg/ICE/LME/CME real-time, FOEX PIX are never scraped or
  proxied. Exchange settlements enter ONLY through the weekly Bloomberg Excel upload lane
  (`access=licensed-upload`, `endpoint=uploads_inbox`).
- One physical fetch may feed many rows (World Bank CMO workbook, EU agri-food API calls);
  per-family pacing ≥ 3 s and retry-with-backoff apply per fetch, not per row.

## 6. probe_status lifecycle

```
pending ──(Mission 2 probe ×2, identical latest values)──► proven
   │            └─(fetch/parse fails, reproduced with control fetch)──► failed ──► watchlist
   └─(access=licensed-upload)──► licensed  (lane contract validated against one real workbook)
```

- `pending`: registered, unprobed. Mission 1 exit state for open rows. No capture allowed.
- `proven`: two independent fetches ≥ 1 h apart (or local+cloud) returned identical latest
  values; magnitude sanity-checked against an external published reference.
- `failed`: endpoint dead/unparseable, with the reproduction documented (control fetch in
  the same minute proving the pipeline works — the ONS-Revolut pattern).
- `watchlist`: failed rows and known-unstable-slug rows we still want; listed in the gaps
  file; excluded from capture until re-proven.
- `licensed`: upload lane defined (sheet/column contract, §7). Mission 2 validates the
  contract against one real uploaded workbook before first ingestion.

## 7. Licensed upload lane (contract summary)

- Inbox: `uploads_inbox/`, workbook filename `bloomberg_weekly_YYYY-MM-DD.xlsx`.
- One sheet named `settlements`, columns exactly:
  `ticker` (string) · `date` (ISO `yyyy-mm-dd`) · `settle` (numeric) · `currency` · `unit`.
- Each licensed registry row binds to one ticker via `inbox_pattern`
  (`bloomberg_weekly_*.xlsx#settlements#<TICKER>`).
- Tickers in v1 are **provisional** (noted per row) and are confirmed against the first
  real workbook; nothing is ever committed to the inbox by the build itself — uploads are
  the user's manual weekly action.
- A workbook violating the contract is rejected whole (no partial ingest) — Mission 3.

## 8. Forecast/realised separation (registry duties)

`data_class=forecast` rows (USDA PSD/WASDE-cycle projections) carry the same schema but:
- are never members of a like-for-like comparable group with realised rows,
- are routed to a visually distinct forecast block by the display contract (Mission 4),
- never enter realised-price rollups or synthesis price-momentum axes (Mission 7 may use
  them only in an explicitly-labelled forward-context axis, if ever).

## 9. Gaps file contract

`commodity_registry_gaps.md` lists every considered-and-excluded series with one of the
reasons: `licensed-no-upload-planned`, `no-stable-endpoint`, `no-named-institution-series`,
`redundant`, `forecast-only`, `tier-3-context-only`, plus a watchlist section mirroring
every `watchlist` row. Exclusions are honest outcomes, not failures to hide.

## 10. Deliberate schema extensions vs the build contract

The contract's field list is extended by exactly three columns, each forced by a gate the
contract itself demands, and each documented here before implementation:

1. `chartable` — the Mission 1 gate "every tier-3 row flagged non-chartable" needs a
   machine-checkable flag.
2. `inbox_pattern` — the Mission 1 gate "every licensed-upload row has a defined inbox
   filename pattern" needs a per-row pattern field.
3. `series_code` — deterministic capture (Mission 3) needs the parser hint separated from
   the fetch URL (consumer build's `fetch_ref` precedent).

No contract field was removed or renamed. Log schemas are untouched.

## 11. Known failure classes this spec guards against

- **Magnitude errors** (EU-coffee-imports lesson): every newly proven row's latest value
  is order-of-magnitude checked against an external published reference before
  `probe_status=proven` (Mission 2 records the comparison).
- **String-multiply vote bug**: numeric casts are explicit at every boundary; the registry
  never relies on implicit coercion.
- **Unstable slugs** (INE lesson): month-stamped URLs (FAO FPI) and CMS-hosted files
  (ICCO/ICO) are flagged in `notes` at registration; probe decides proven vs watchlist.
- **Key leakage**: endpoints embed `{KEY}` placeholders only; real keys live in env /
  git-ignored `.env` / GitHub Actions secrets. A fatal QA gate scans emitted files.

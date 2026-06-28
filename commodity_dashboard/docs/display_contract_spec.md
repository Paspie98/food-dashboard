# Build & Display Contract Specification (Mission 4)

Status: written before `build_data.ps1` / `build_display_contract.ps1` exist
(spec-before-code).

## 1. build_data.ps1 — emitted payload

Consumes ONLY `cleaned_data/commodity_series_history.csv` (captured history; no fetches)
plus the newest registry for metadata. Emits `dashboard/data.js`:

```
window.DASHBOARD_DATA = { generated_utc, registry_version, counts, series };
```

- `counts`: `selected` (all registry rows), `captured` (rows with history),
  `charted` (captured ∧ ≥2 obs ∧ chartable=yes), `latest_only` (captured ∧ exactly 1 obs),
  `not_captured` (selected − captured).
- `series[row_id]`: `meta` (row_id, commodity, layer, series_name, relevance, unit,
  geography, institution, tier, data_class, access, refresh_cadence, staleness_budget,
  chartable, probe_status) + `obs` as `[[date, value], …]` ascending.
- Deliberately EXCLUDED from the payload: `endpoint`, `series_code`, `inbox_pattern`
  (capture-lane detail; also keeps any key-shaped text out of emitted JS by construction).
- Values emitted as JSON numbers (explicit `[double]` casting at read).

## 2. build_display_contract.ps1 — per-row contracts

Emits `dashboard/display_contract.js` (`window.DISPLAY_CONTRACT = { rows, groups,
colors, layout }`). Every captured row gets a COMPLETE, non-generic contract:

| field | rule |
|---|---|
| `title` | `commodity — short qualifier` derived from series_name; never the raw row_id; unique across rows |
| `unit_label` | registry unit verbatim |
| `basis` | `level` \| `index` (registry unit `index`) — realised prices are levels; PPI/FAO rows are indices |
| `decimals` | USD/kg, USD/MMBtu → 2; index, USc/lb, EUR/100kg, USD/t-class with sub-1000 values → 1; ≥1000-class levels → 0 |
| `window_primary` | cadence-based: monthly → `3m`; weekly → `13w`; quarterly → `4q` |
| `window_secondary` | monthly → `12m`; weekly → `52w`; quarterly → `8q` (rendered only if depth allows) |
| `layer_block` | registry layer (L1→L4 section routing) |
| `class_block` | `realised` \| `forecast` — forecast rows route to a visually distinct block, never into realised rollups or groups |
| `comparable` | `yes:<group_id>` or `no` |
| `staleness_budget` | from registry (front-end staleness flag input) |

## 3. Like-for-like metric groups (comparable=yes must be defensible)

| group_id | members | basis | defence |
|---|---|---|---|
| `cocoa_complex` | CO-001 (+ CO-003/004 when captured) | `indexed` | mixed GBP/USD venues once licensed rows arrive; indexed from day one so the basis never silently changes |
| `coffee_complex` | CF-001, CF-002 (+ CF-004/005 when captured) | `indexed` | same reasoning as cocoa |
| `wheat_complex` | WH-001, WH-002, WH-003 (+ WH-004/005 when captured) | `indexed` (rebase 100 at common start) | same commodity, mixed FX/venues — only index-basis comparison is honest |
| `maize_complex` | MZ-001, MZ-002 (+ MZ-003/004 when captured) | `indexed` | as wheat |
| `vegoil_complex` | VO-001, VO-002, VO-003, VO-004 | `level` | same source (CMO), same unit (USD/t), same cadence |
| `sugar_complex` | SG-001, SG-002, SG-003 (+ SG-004/005 when captured) | `indexed` | mixed USD/kg vs EUR/t bases |
| `dairy_eu` | DY-001, DY-002 | `level` | same source, unit (EUR/100kg), cadence |
| `nitrogen_complex` | FE-001, FE-008, EN-001 (+ EN-002 when captured) | `indexed` | feedstock-transmission view across USD/t, EUR/t, USD/MMBtu |
| `phosphate_complex` | FE-002, FE-003, FE-005, FE-010 | `indexed` | mixed FX |
| `potash_complex` | FE-004, FE-011 | `indexed` | mixed FX |
| `fao_indices` | IX-001..IX-005 | `level` | identical basis (2014-16=100) |
| `eu_packaging_ppi` | PK-002, PK-004, PK-007, PK-009 | `level` | identical basis (Eurostat I21) |
| `eggs_regions` | EG-001 (+ EG-002 when captured) | `indexed` | EUR/100kg vs USD/dozen |

Indices never join price groups; forecast rows never join any group (Principle 3).
Fixed colours per geography: EU `#1f5fbf`, US `#b3413c`, world `#3f7a4e`,
origin-specific `#8a6d3b` (light-theme safe).

## 4. Mission 4 gates

1. `test_chart_integrity.ps1` — every charted series in data.js has aligned dates/values,
   length ≥2, all values finite numbers, dates strictly ascending.
2. `test_display_contract.ps1` — every captured row has a contract; no empty/generic
   field; titles unique; every `comparable=yes:<g>` references a defined group whose
   members share the group basis; forecast rows excluded from groups.
3. `test_frontend_category_integrity.ps1` — every contract routes to one of the four
   layer blocks; every layer block has ≥1 charted row; `class_block` consistent with
   registry `data_class`.
4. `test_axis_sanity.ps1` — for every charted series: min < max over the full series
   (no degenerate axis), and the primary comparison window contains ≥2 observations.

All four fatal; run locally now, wired into refresh_all + CI at Missions 5/8.

# Mission 4 QA — build_data + Display Contract

Date: 2026-06-12. Spec written first: `docs/display_contract_spec.md` (payload shape,
contract rules, the 13 like-for-like groups with per-group defensibility, gate
definitions) — amended once BEFORE code to add cocoa/coffee groups.

## Builder outputs (counts table — gate requirement)

```
data.js: selected=63 captured=41 charted=41 latest_only=0 not_captured=22
         registry=v6; bytes=361683
display_contract.js: 41 row contracts, 13 groups
```

- Hand-rolled deterministic JSON in both emitters (fixed key order, invariant number
  formatting) — a deliberate choice for Mission 5/8 hash-stable artifacts; PS hashtable
  enumeration order is not contractual, so `ConvertTo-Json` was rejected.
- `endpoint` / `series_code` / `inbox_pattern` deliberately excluded from the payload —
  capture-lane detail, and keeps key-shaped text out of emitted JS by construction.

## Gate evidence (all four fatal gates, first run)

| gate | result | detail |
|---|---|---|
| `test_chart_integrity.ps1` | **PASS** | 41 series: aligned `[date,value]` pairs, ≥2 obs, finite values, strictly ascending dates; payload counts re-derived and matched |
| `test_display_contract.ps1` | **PASS** | 41 complete contracts; no empty/generic field; unique titles; all `yes:<group>` references resolve; zero forecast rows in groups |
| `test_frontend_category_integrity.ps1` | **PASS** | L1=11, L2=13, L3=12, L4=5 charted realised rows; every layer populated; layer/class routing consistent with registry |
| `test_axis_sanity.ps1` | **PASS** | 41 series: min<max over full series; primary window (3m/13w/4q) holds ≥2 obs everywhere |

## Like-for-like groups shipped (comparable=yes only where defensible)

- `indexed` basis (mixed FX/venue/unit): cocoa, coffee, wheat, maize, sugar, nitrogen
  (urea + EU N + TTF feedstock), phosphates, potash, eggs-regions.
- `level` basis (identical unit + source + cadence): veg-oils (CMO USD/t), EU dairy
  (EUR/100kg), FAO indices (2014-16=100), EU packaging PPIs (I21).
- Groups list potential members (licensed/keyed rows included) so captured additions
  join automatically on later runs; contracts attach only to captured rows today.
- Forecast rows: none captured yet; `class_block` routing exists and the
  forecast-never-grouped rule is gate-enforced (tested against the schema, will bite on
  first forecast capture).

## Verdict

Mission 4 completion gate: **GREEN** — both emitters deterministic, all four integrity
gates pass locally on the first build.

# Mission 7 QA — Synthesis Layer (cost-pressure read)

Date: 2026-06-12. Spec written FIRST (`docs/synthesis_spec.md`), refined against a
scratch computation on the real captured history BEFORE implementation — the scratch
pass forced one material spec change (value-at-month carry-forward within staleness
budget; a strict in-month rule had silently reduced L4 to one voter) and calibrated the
±2%/±1pt thresholds against real moves (spec §9 records the evidence).

## Architecture (consumer pattern, procurement-adapted)

Pure rule functions in `scripts/synthesis_rules.ps1`, dot-sourced by BOTH
`build_synthesis.ps1` (engine) and `test_synthesis_fixtures.ps1` (gate) — tested code is
shipped code. All vote inputs explicitly `[double]`-cast; a dedicated fixture feeds
STRING weights/votes and asserts identical results (the "-1" string-multiply class).

## Gate evidence

- `test_synthesis_fixtures.ps1`: **PASS — 36/36 fixtures**: direction classes incl. the
  real cocoa mixed case (+15.9% 3m vs −53.7% 12m → votes 0); every state reachable;
  supermajority clause (score .63 / breadth .67 → tightening, NOT escalating); neutral
  voting (stale/flat/mixed ⇒ 0); insufficient-data both by voters<2 and freshShare<0.6;
  hysteresis h1–h5 plus initial/availability/return-from-insufficient; diverging; banned
  + causal language positive AND negative fixtures.
- `test_synthesis_stability.ps1`: **PASS** — full state-log replay reproduces every
  published state and candidate tuple; emitted synthesis.js equals the log tail.
- Same-month rebuild exercised live: refresh_all re-ran build_synthesis for 2026-05
  after the log rows existed → `same-month-noop`, nothing appended, stability green.
- All three synthesis steps now FATAL in refresh_all; full pipeline **OVERALL: PASS**.

## First real read (note=initial) — synthesis month 2026-05

| unit | published | score | breadth | Δ3m med | voters | volatility |
|---|---|---|---|---|---|---|
| L1-product | **tightening** | 0.500 | 60% | +5.2% | 11 | normal |
| L2-ingredient | **tightening** | 0.391 | 48% | +6.2% | 13 | normal |
| L3-input | **escalating** | 0.905 | 90% | +13.5% | 12 | normal |
| L4-packaging | **tightening** | 0.500 | 50% | +2.9% | 5 | normal |
| composite | **tightening** | 0.586 | 64% | +6.2% | 41 | normal |

- L3 escalating passes the supermajority clause honestly: 11 of 12 voters rising
  (urea +63.2%, TTF +43.9%, TSP +33.1%, EU-N +30.0%, DAP +22.8%, …; lone non-riser:
  phosphate rock, flat).
- The machinery's nuance shows in L1/L2: cocoa, eggs, world raw sugar and the FAO sugar
  index all classify `mixed` (3m rebound inside a 12m down-move) and correctly vote 0
  rather than feeding either direction.
- Diverging modifier correctly NOT set (L1/L2 are not calm). fresh_share = 1.0
  everywhere (carry-forward rule); zero stale voters this month.
- `logs/synthesis_state_log.csv` holds the 5 initial rows (schema defined and frozen
  this mission per the contract's "adapted per Mission 7").

## Tiles + evidence click-through (gate)

Five tiles render above the layer sections (screenshot
`dashboard_layers_20260612_023634.png`): state-coloured (escalating red / tightening
orange / easing green / insufficient purple-grey), score/breadth/Δ3m/volatility mono
line, confidence ("broad base: N series voting, 100% fresh" / "rests on N series" when
thin), and a per-tile `evidence (N rows)` expander listing every contributing row with
direction arrow, weight, Δ3m and an explicit "stale, votes 0" marker when applicable.

## Honest friction this mission

The file-level banned-words gate flagged `index.html` after the tiles landed — the CSS
property `border-collapse` contains a banned substring. Fixed by switching the table to
`border-spacing:0` (equivalent rendering) rather than weakening the gate. Browser QA
re-run: 52/52 canvases, 0 console errors, 0 DOM banned hits, footer PASS.

## Verdict

Mission 7 completion gate: **GREEN** — fixtures + stability pass (local and wired fatal
into refresh_all + manifest), first real read published with note=initial, state log
appended, tiles render with full evidence click-through.

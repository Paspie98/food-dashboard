# Synthesis Specification — Cost-Pressure Read (Mission 7)

Status: written BEFORE `synthesis_rules.ps1` / `build_synthesis.ps1` exist, and refined
against a scratch computation on the real captured history (2026-05, §9) before any
implementation. Procurement adaptation of the consumer synthesis (same machinery class:
weighted votes, supermajority, hysteresis with candidate streaks, fixtures-gated).

## 1. Unit of synthesis

The four value-chain layers (L1-product, L2-ingredient, L3-input, L4-packaging) plus an
all-layers composite. Never countries. Monthly cadence.

## 2. Synthesis month and the value-at-month rule

- `synthesis_month M` = the last FULL calendar month relative to the run date (UTC).
- `value_at(row, M)` = the row's last observation dated ≤ end-of-M, provided that
  observation is within the row's staleness budget measured from end-of-M; otherwise
  the row has no value at M.
  - *Scratch-forced refinement*: a strict "observation inside M" rule left every
    Eurostat PPI (latest 2026-04), the quarterly input index (2026-Q1) and EU sugar
    (2026-03) valueless, reducing L4 to one voter. Carry-forward WITHIN BUDGET is the
    latest-known-price reality of procurement, not interpolation: no value is invented,
    the carried observation keeps its own date, and beyond-budget rows are excluded
    (they vote 0 and are named stale).
- `Δ3m` = value_at(M) vs value_at(M−3); `Δ12m` = vs value_at(M−12). Missing base ⇒ the
  delta is null (never approximated).

## 3. Row vote (realised, chartable, captured rows only — forecast rows NEVER vote)

- Direction class from Δ3m with Δ12m sign check (consumer `mixed` rule):
  - level rows (prices): threshold ±2.0% on Δ3m%; index rows (FAO, PPIs): ±1.0 point.
  - `flat` if |Δ3m| < threshold or Δ3m null; `mixed` if Δ3m and Δ12m exceed threshold
    with opposite signs (e.g. cocoa 2026-05: +15.9% 3m vs −53.7% 12m → mixed → votes 0);
    else `up` / `down`.
- All commodity rows are cost-`pressure` mode: `up` → vote +1 (pressure building),
  `down` → −1 (easing), `flat`/`mixed` → 0.
- Weight: price-level rows = 2 (headline), index rows = 1 (context breadth). Data-driven
  (unit=index ⇒ context), no hand lists.
- Stale rows (no value_at(M)) vote 0, carry weight 0, and are NAMED in evidence.
- **Every numeric input is explicitly `[double]`-cast at the function boundary** (the
  "-1" string-multiply vote bug class — regression-tested in fixtures).

## 4. Layer read (pure function over the votes)

- `Wup/Wdown/Wzero` = summed weights by vote sign; `Wtotal` = all voting weight;
  `score` = (Wup − Wdown) / Wtotal ∈ [−1, 1]; `breadth` = Wup / Wtotal.
- voters = rows with weight > 0 (i.e. non-stale); freshShare = non-stale / all rows.
- Raw state:
  | condition (first match) | raw state |
  |---|---|
  | voters < 2 or freshShare < 0.6 | `insufficient-data` |
  | score ≥ 0.5 AND breadth ≥ 0.7 (supermajority clause) | `escalating` |
  | score ≥ 0.25 | `tightening` |
  | score ≤ −0.25 | `easing` |
  | otherwise | `stable` |
- Axes reported alongside (context, non-voting): median Δ3m of voters (momentum),
  breadth %, volatility regime (`elevated` if median |MoM%| of the layer's voters over
  the trailing 12 months > 1.5× the prior 12 months, else `normal`), coverage
  (voters / rows).

## 5. Hysteresis (2-distinct-month, candidate streaks, same-month-never-flips)

State machine per layer (and composite), persisted in `logs/synthesis_state_log.csv`:

1. If the log already holds an entry for (unit, M): the published state IS the logged
   state — same-month rebuilds never flip, regardless of raw drift (source revisions).
2. `raw == published` → candidate cleared (streak 0).
3. `raw != published` → if raw equals the standing candidate AND M is a NEW month →
   streak+1; streak ≥ 2 ⇒ publish raw (flip) and clear; otherwise (new candidate or
   changed candidate) candidate = raw, streak = 1, published unchanged.
4. `insufficient-data` bypasses hysteresis in BOTH directions immediately — it is an
   availability fact, not a market read; on data return the machine resumes from the
   last real published state in the log.

## 6. Composite and the diverging modifier

- Composite = the same §4 machinery over ALL realised voters pooled (weighted as §3).
- Diverging modifier (input-cost transmission read): set when L3 published ∈
  {tightening, escalating} AND both L1 and L2 published ∈ {stable, easing}. Note text:
  "input layer under cost pressure while product layers hold — structural drag watch"
  (descriptive, non-causal).

## 7. Confidence and language

- Confidence names thin axes: voters < 5 ⇒ "rests on N series"; stale rows named;
  freshShare reported. First-ever published read carries `note=initial`.
- Language gates: the dramatic banned-words list AND the consumer causal-language regex
  (`will/because/due to/driven by/causes/leads to/explains/as a result`) over every
  generated sentence — fixtures include both.

## 8. Artifacts

- `dashboard/synthesis.js`: `window.SYNTHESIS = { month, units: { L1..L4, composite },
  generated_utc }`; each unit: published/raw/score/breadth/momentum/volatility/
  voters/stale[]/confidence/note/evidence[] where evidence rows carry
  `{row_id, title, weight, vote, d3m, d12m, stale}` (click-through requirement).
- `logs/synthesis_state_log.csv` (schema defined this mission, then frozen):
  `month,unit,raw_state,published_state,candidate_state,candidate_streak,score,breadth_pct,momentum_3m_med,voters,stale_voters,note`
- Idempotent log append: an existing (unit, month) row is never rewritten; a same-month
  rebuild verifies match and appends nothing.

## 9. Scratch computation evidence (2026-05, real captured history)

Selected rows (full table reproduced by the build):
urea +63.2%/+96.6% (3m/12m), TSP +33.1%/+31.8%, EU-N +30.0%/+53.3%, TTF +43.9%/+38.7%,
DAP +22.8%/+15.0% → L3 reads escalating-class pressure with supermajority breadth.
Cocoa +15.9%/−53.7% → mixed → 0 (machinery handles the rebound-within-easing case).
Coffee arabica −1.8% → flat; robusta −7.3%/−30.0% → easing votes.
Soy oil +38.5%/+52.6%, SMP +19.1%, butter −5.5%/−46.2% → L2 mixed-to-tightening.
Aluminium +19.6%/+49.7% vs EU packaging PPIs (April, ~flat) → L4 split read.
Calibration held: ±2% level threshold separates noise (rape oil RO +1.1 → flat) from
signal (French wheat +6.6 → up); ±1pt index threshold keeps FAO dairy −0.2pt flat.

## 10. Gates (both fatal, local + CI + manifest)

- `test_synthesis_fixtures.ps1`: pure-function fixtures — every state reachable,
  supermajority clause, neutral voting (stale/flat/mixed ⇒ 0), insufficient-data,
  string-vote cast regression, hysteresis h1–h5 (h1 candidate-no-flip, h2 two-distinct-
  month flip, h3 candidate interrupted, h4 same-month-never-flips, h5 candidate
  retarget resets streak), banned + causal language over generated notes.
- `test_synthesis_stability.ps1`: replays the full state log through the hysteresis
  machine — every logged published state must be reproduced (persistence inviolable);
  then verifies the current build's states equal the log tail.

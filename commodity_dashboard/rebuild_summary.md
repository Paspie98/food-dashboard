# Rebuild Summary — Food & Beverage Commodity Cost Dashboard

Built 2026-06-12, missions 1–8 in order, each behind its completion gate
(`qa/m1…m8_*.md` carry the artifact-backed evidence). Consumer-build doctrine applied
throughout: registry-first, probe-before-wire, capture-gated, ratcheted baselines,
deterministic synthesis, offline-verifiable artifact.

## What was built and why

- **Registry (v1→v6, 63 rows)**: four value-chain layers (L1 softs/grains, L2
  ingredients, L3 agricultural inputs, L4 packaging), every row a named institution with
  an exact endpoint, data_class (realised/forecast), tier, cadence and staleness budget.
  Six versions exist because probing and capture each forced honest corrections (stale
  CMO snapshot URL → landing-page resolver; DG AGRI product/dimension pins; Romania
  re-pin for rape oil; NPK rows added when the fertiliser API proved real; sugar
  contract-type pin). Prior versions untouched.
- **Probe engine**: 3 passes, double-fetch proof (41/41 identical values ≥1h apart),
  magnitude table vs the archived Dec-2024 CMO release and cross-institution
  corroboration. Watchlist with reproductions: ICCO (nonce-gated widget), ICO (PDF +
  paid DB), MPOB (no machine asset).
- **Capture engine**: 41 series, 19,115 observations, idempotency SHA-256-proven;
  kept-prior doctrine; strict casting (caught Excel scientific notation) and ambiguity
  guards (caught DG AGRI's parallel "Short term contracts" sugar series). Licensed lane:
  whole-workbook validation with 4 rejection classes fixture-tested; never fetches.
- **Build + display contract**: deterministic hand-rolled JSON emitters; 41 complete
  non-generic contracts; 13 like-for-like groups (indexed where FX/venues differ, level
  only where unit+source+cadence match); forecast class fenced from realised.
- **Gates + manifest**: refresh_all orchestrator, ratcheted floors (41/41), SHA-256
  manifest, fail-closed footer, secrets scan, numeric-history scan, banned-words gate
  (positive + negative fixtures + live scan + in-browser DOM scan).
- **Front-end**: one offline file, zero external resources, light theme, 52 canvases,
  metric-group view, synthesis tiles with full evidence click-through.
- **Synthesis (first read, 2026-05, note=initial)**: L3-input **escalating** (score
  0.905, breadth 90%, urea +63%/TTF +44%/TSP +33% over 3m); L1/L2/L4 **tightening**;
  composite **tightening**. Hysteresis (2-distinct-month) and same-month-never-flips
  enforced by fixtures + log replay.
- **Cloud CI**: weekly + dispatch workflow, every gate a named step, freshness audit
  log proving genuine refresh, determinism step (cloud emission vs committed state log),
  artifact packaging with N/N hash verification and DOM QA on the extracted artifact
  (local run: 4/4 hashes, QA PASS).

## Honest outcomes (nothing papered over)

- 8 rows remain `pending` on user-owed keys (5 FRED, 3 USDA) — excluded from capture
  until probed; they re-enter via the standard probe → registry-version path.
- 11 licensed rows await the first real Bloomberg workbook; tickers provisional;
  acceptance-path validation deliberately impossible until then (no fabrication).
- 3 watchlist rows with documented reproductions (gaps file §2a).
- SG-003 carries a persistent freshness WARN (EU sugar ~2-month publication lag vs the
  inherited 3m budget) — named on every run, escalation threshold not hit.
- Ammonia, AN/CAN spot, sulfur, agricultural lime spot: no open named-institution
  series exists; covered indirectly (EU N composite, fertiliser PPI, lime PPI candidate)
  and recorded in the gaps file. Proposal pending user decision: add an NH3 ticker to
  the weekly Bloomberg workbook.
- The Dec-2024 CMO snapshot fetched by the v1 URL became the trajectory reference for
  magnitude QA — an accident converted into evidence.
- Raw-archive policy deviation, documented: the ~15 MB CMO workbook is git-ignored from
  commit-back (unbounded growth) and preserved per-run as a 90-day Actions artifact;
  all other raw responses commit normally.
- **Cloud completion gate (two consecutive green runs) is pending the user's push
  approval** — everything cloud-side is staged; nothing has been committed or pushed,
  per the user's standing instruction.

# Front-end Specification (Mission 6)

Status: written before `dashboard/index.html` exists (spec-before-code).

## Constraints (contract)

- ONE file `dashboard/index.html`; **zero external resources** — all CSS/JS inline,
  system font stacks only; data arrives via sibling local scripts `data.js`,
  `display_contract.js`, `synthesis.js` (optional until M7), `build_manifest.js`.
- Light theme only. Banned-words discipline applies to every rendered string.
- Single-line, non-wrapping, monospace summary line per card.
- Footer renders BUILD_STATUS **strictly from the manifest**; a missing manifest or
  missing status renders FAILURE (fail-closed; consumer footer-bug lesson).

## Why build_manifest.js exists

`fetch('build_manifest.json')` is blocked on `file://` (not a secure context, CORS).
The manifest step in `refresh_all.ps1` therefore ALSO emits
`dashboard/build_manifest.js` (`window.BUILD_MANIFEST = {...};`) — same content, loadable
offline. Neither manifest file appears in its own hash list. In-browser SHA-256
verification is impossible on `file://` (no `crypto.subtle`); the footer shows the
manifest's artifact-hash count and verification is performed externally by the artifact
QA (Mission 8 packaging proof). When served over http(s) the footer verifies
data.js/display_contract.js hashes live via `crypto.subtle` and shows the result.

## Views

1. **By layer (default)**: four sections L1→L4 (labels from display contract layout).
   Per-commodity card: title; badges (tier, geography colour chip, institution,
   forecast-class badge when applicable, staleness chip when over budget — orange
   >1x, red >2x); canvas line chart of the last 5 years of observations (full history
   stays in data.js; the window is a display choice, not a data cut); summary line
   (monospace, nowrap): `latest unit · Δ<primary> · Δ<secondary> · @date`.
   Realised and forecast rows render in separate sub-blocks; forecast cards carry a
   visible `forecast` badge and never join group charts (Principle 3).
2. **Metric groups**: one card per display-contract group with ≥2 captured members:
   overlaid lines, fixed per-geography colours from the contract; `indexed` groups
   rebase each member to 100 at the first date ≥ the common 3-year window start
   (each member's own base — no interpolation, no padding); `level` groups draw raw
   values (identical units by construction). Legend lists member, geography, latest.

## Movement quantification

- `level` basis rows: percentage change vs the observation nearest to (but not after)
  `last_date − window`; shown as `+x.x%`/`−x.x%`. If no base observation exists inside
  1.3× window, render `Δ n/a` (insufficient window) — never a fabricated number.
- `index` basis rows: change in index points (1 dp) plus % in parentheses.
- Comparison period is always named (the window label is part of the summary line).

## QA mode (`?qa=1` — used by headless browser QA)

After render, the page runs self-checks and writes a JSON report into `#qa-results`
and sets `document.title = 'QA:PASS'` or `'QA:FAIL'`:
- every canvas `toDataURL().length > 1000` (it actually drew),
- captured `console.error` + `window.onerror` count == 0,
- banned-words scan over `document.body.innerText` == 0 hits,
- every card has a non-empty summary line,
- footer status text present.
`scripts/run_browser_qa.ps1` drives headless Chrome/Edge: `--dump-dom` on `?qa=1`
(parses the report), `--screenshot` archived to `logs/qa_screenshots/`.

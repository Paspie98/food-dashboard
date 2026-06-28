# M12 — Join the front-end to the automation

**Status: complete. One source of truth (`commodity_exposure.html`); the weekly run QAs, packages, and serves it; the live Pages URL reflects the committed feed.**
Date: 2026-06-28. Live URL: **https://paspie98.github.io/food-dashboard/** → `commodity_dashboard/dashboard/commodity_exposure.html`.

## Step 1 — reference audit (before/after)
Active wiring repointed from the old page/driver to the new one:

| Location | Was | Now |
|---|---|---|
| `.github/workflows/refresh.yml` browser-QA step | `run_browser_qa.ps1` (→ index.html) | `run_exposure_qa.ps1` (→ commodity_exposure.html, 4 lenses) |
| `scripts/package_artifact.ps1` offline QA entry | extracted `index.html` via `run_browser_qa.ps1` | extracted `commodity_exposure.html` via `run_exposure_qa.ps1` |
| `scripts/tests/test_banned_words.ps1` targets | `…, index.html` | `…, commodity_exposure.html` (index.html dropped) |

Automatic (no code change): the manifest hash list globs `dashboard/` (`refresh_all.ps1`) → it picked up `commodity_exposure.html` and dropped the deleted `index.html` on its own (5 → 4 artifacts across the run sequence). Data-emit paths untouched.

## Step 2 — repoint (committed)
`862e91f` repoint + root redirect; `c5daa7e` `.nojekyll`; `878934c` self-contained page + delete index.html + gate enforces 0-external.

## Step 3 — Pages setup
- **Repo made public** (full-history secret scan first: 22 commits, FRED/EIA/USDA = 0/0/0, no key-bearing URLs in archive history — public exposes no secret). Pages on a private repo would have needed a paid plan and is public-served regardless; public + root is plan-agnostic and adds no data duplication.
- **Pages source: `main` / root**, `build_type: legacy`, with a root **`.nojekyll`** (serve files statically; the first Jekyll build errored).
- Root **`index.html` redirect** → `commodity_dashboard/dashboard/commodity_exposure.html`. The page loads its data via relative `<script src>` from its own directory, so it fetches the committed `data.js`/`synthesis.js`/etc. at load → the weekly commit-back updates the live URL with no redeploy (Pages auto-rebuilds on push).

## Step 4 — live-run proof (actual numbers, two runs)
First join run **`28332954724`** (green) proved (a),(c),(d),(e) and (b) render+hashes. Confirming run **`28333742197`** (green) proved the final **0-external** state after removing the font link and deleting index.html.

- **(a) browser-QA on the NEW page, in CI** (`browser-qa-rendered-dom (commodity_exposure.html, 4 lenses)` = success): `canvases 236/236` (59 cards × 4 lenses), `console_errors []`, `banned_hits []`, `empty_summaries 0`, `analysis_slots 59`, `footer PASS`, **verdict PASS**.
- **(b) offline artifact**: `hash verification: 4/4 manifest hashes match` (data.js, display_contract.js, synthesis.js, commodity_exposure.html — index.html gone); extracted-copy QA `236/236` + **`external resources: 0 (fully self-contained)`** → `RESULT: PASS (artifact hash-verified, packaged, and DOM-QA-passed offline)`.
- **(c) secrets** over committed HEAD after touching packaging: **FRED 0 / EIA 0 / USDA 0**.
- **(d) freshness**: overall PASS, **59 fresh / 0 kept-prior**, families **7/7/0**.
- **(e) live Pages URL reflects the committed feed** — the load-bearing proof: before the join the live page showed `generated 2026-06-28T16:09:50Z`; after run `28332954724` it showed `19:16:09Z`; after run `28333742197` it showed **`19:45:50Z`** — each time matching that run's committed `build_manifest` exactly. The live served page also has **0 external src/href** (self-contained), renders **5 segments**, `composite tightening · 2026-05`, `data.js` HTTP 200. The old entry `…/dashboard/index.html` now returns **404**; the root redirect returns **200**. Screenshot: `logs/exposure_qa/pages_live_28332954724.png`.

## Step 5 — index.html disposition
**Deleted** (your call). `dashboard/index.html` (the M6 page) is removed: gone from the repo, the manifest, the banned-words targets, the offline zip, and Pages (404). `commodity_exposure.html` is the single source of truth. The root `index.html` is only a redirect, not a second front end.

## Fonts / offline integrity
The M11 page used a Google Fonts `<link>` (1 external resource). Per your call it was **removed**; the page now uses system-font fallbacks (DM Sans → system-ui, Instrument Serif → Georgia/serif, DM Mono → ui-monospace) and references **0 external resources**, restoring the prior offline-integrity bar. `run_exposure_qa.ps1` now **enforces** 0 external resources (fails on any external `src`/`href`), so this can't regress silently.

## Net result
GitHub refreshes → the front end reflects it, end to end: the Monday cron runs the pipeline, QAs `commodity_exposure.html` across 4 lenses, packages it as a self-contained offline artifact, commits the fresh data back, and GitHub Pages serves the updated page at the live URL with no redeploy.

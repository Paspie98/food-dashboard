# Mission 8 QA — Cloud CI + Artifact Integrity

Date: 2026-06-12. Status: **local side GREEN; cloud side PREPARED-AWAITING-PUSH** (the
user has not yet authorised commits/pushes; two consecutive green cloud runs cannot
exist until the repo is pushed and secrets are set — named blocking items below).

## Workflow (`/.github/workflows/refresh.yml` — repo root, where Actions reads it)

- Weekly schedule (Mon 06:30 UTC) + `workflow_dispatch`; `windows-latest` with the
  `powershell` shell = Windows PowerShell 5.1, the exact engine every script targets.
- **Every gate is a named step**: refresh-all, then registry/chart/display/category/
  axis/banned-words/licensed-contract/synthesis-fixtures as individual named re-runs,
  then `determinism-synthesis-vs-committed-log`, `browser-qa-rendered-dom`,
  `package-offline-artifact`, artifact uploads, `commit-back`.
- **Determinism check**: the stability gate replays the COMMITTED state log and asserts
  the cloud emission equals it — cloud-built synthesis states must equal the
  same-history local build, and same-month rebuilds can never flip (already exercised
  locally: second build of 2026-05 was a `same-month-noop`).
- **Freshness audit**: refresh_all appends the contract-schema row to
  `cloud_refresh_freshness_log.csv` every run with `run_environment=github_actions`,
  runner marker (`runner/os/run_id/sha`), fetches attempted, rows fresh-from-source vs
  kept-prior WITH named row ids (verified locally with `run_environment=local` rows).
- **Licensed lane in CI**: ingest reads only the committed `uploads_inbox/`; no step
  fetches licensed sources (the engine cannot — `endpoint=uploads_inbox` by gate).
- **Secrets**: `FRED_API_KEY`/`USDA_FAS_KEY` flow ONLY via GitHub Actions secrets into
  step env; `.env` is git-ignored; the secrets-scan gate runs in CI like locally.
- **Browser QA in CI**: `run_browser_qa.ps1` auto-detects Edge on windows-latest.

## Offline artifact (consumer Phase B8) — executed locally, wired in CI

`scripts/package_artifact.ps1` run 2026-06-12:

```
hash verification: 4/4 manifest hashes match
packaged: commodity_dashboard_offline_20260612_023930.zip (101 KB)
[extracted artifact] QA: 52/52 canvases, 0 console errors, 0 banned hits, footer PASS
RESULT: PASS (artifact hash-verified, packaged, and DOM-QA-passed offline)
```

The DOM QA ran against the EXTRACTED ZIP COPY in a scratch directory — the artifact
itself, not the source tree. Packaging refuses a manifest whose BUILD_STATUS≠PASS.

## Repo hygiene before any push

- `.gitignore` extended: `.env` (secrets), per-run `FAMILY_worldbank_*.xlsx` raw copies
  (~15 MB each; preserved instead as 90-day Actions artifacts via `upload-raw-archive` —
  deliberate, documented deviation), `logs/artifact/` zips (uploaded, not committed).
- `commodity_dashboard/.github/workflows/README.md` records why the live yml sits at
  the repo root.

## Completion gate status

| item | status |
|---|---|
| workflow with named gate steps | DONE (file ready) |
| freshness audit proving genuine refresh | DONE (mechanism verified locally) |
| determinism check cloud vs local | DONE (gate wired; semantics proven locally) |
| licensed lane CI-safe | DONE |
| artifact hash-verified + offline DOM QA | **DONE — executed locally, PASS** |
| secrets via Actions secrets + scan in CI | DONE (pending user adding the two secrets) |
| **two consecutive green cloud runs** | **BLOCKED — user actions required:** (1) authorise commit+push of the build, (2) add `FRED_API_KEY` (+optional `USDA_FAS_KEY`) as repo Actions secrets, (3) trigger `workflow_dispatch` twice or await two weekly runs |
| `rebuild_summary.md` | DONE (consumer style, honest-outcomes section included) |

## Verdict

Mission 8: **AMBER — everything buildable without the user is built and locally
verified; the cloud-run evidence is the only outstanding item and it is gated on
authorisation only the user can give.** No commit, push, or upload has been performed.

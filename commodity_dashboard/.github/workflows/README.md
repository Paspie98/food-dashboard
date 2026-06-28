# Workflow location pointer

GitHub Actions only reads workflows from the repository root: the live workflow for this
project is **`/.github/workflows/refresh.yml`** (repo root), which runs with
`working-directory: commodity_dashboard`. This directory exists to honour the contract's
project layout; do not place a duplicate yml here (duplicates rot).

window.BUILD_MANIFEST = {
    "BUILD_STATUS":  "PASS",
    "generated_utc":  "2026-08-03T10:17:03Z",
    "registry_version":  "v9",
    "baselines":  {
                      "captured_floor":  59,
                      "charted_floor":  59
                  },
    "counts":  {
                   "selected":  62,
                   "captured":  59,
                   "charted":  59,
                   "latest_only":  0,
                   "not_captured":  3
               },
    "gates":  {
                  "validate-registry":  "PASS",
                  "capture":  "PASS",
                  "ingest-licensed":  "PASS",
                  "build-crosscheck":  "PASS",
                  "build-data":  "PASS",
                  "build-display-contract":  "PASS",
                  "synthesis":  "PASS",
                  "gate-chart-integrity":  "PASS",
                  "gate-display-contract":  "PASS",
                  "gate-frontend-category":  "PASS",
                  "gate-axis-sanity":  "PASS",
                  "gate-banned-words":  "PASS",
                  "gate-licensed-contract":  "PASS",
                  "gate-no-secrets-in-archive":  "PASS",
                  "gate-crosscheck-integrity":  "PASS",
                  "gate-synthesis-fixtures":  "PASS",
                  "gate-synthesis-stability":  "PASS",
                  "qa-secrets-scan":  "PASS",
                  "qa-numeric-history":  "PASS",
                  "qa-ratchet":  "PASS",
                  "data-freshness":  "WARN"
              },
    "freshness":  {
                      "fresh":  51,
                      "stale_warn":  [
                                         "FE-006 (age 94d, budget 3m)",
                                         "FE-009 (age 94d, budget 3m)",
                                         "FR-001 (age 124d, budget 3m)",
                                         "PK-002 (age 94d, budget 3m)",
                                         "PK-004 (age 94d, budget 3m)",
                                         "PK-007 (age 94d, budget 3m)",
                                         "PK-009 (age 94d, budget 3m)",
                                         "SG-003 (age 94d, budget 3m)"
                                     ],
                      "escalated":  [

                                    ]
                  },
    "artifact_hashes_sha256":  {
                                   "commodity_exposure.html":  "D1C0DF58D2ACC2241CE7583292C6939DB26C8DE85E6FC218EDADC61196BD3808",
                                   "commodity_glossary.js":  "C61F45C7F4D4037AE2C8CB7D3D6C4AFF4B377F9308CD2AB2EA8ED2C250A79686",
                                   "data.js":  "1AD6D8E43CE2B227410CA6943526EA31EB1FD66984F02AF272DA2774C238C8BD",
                                   "display_contract.js":  "2306A6AE1B02EB6289F6121C2EC6ED360813CFFFDFA589DD06ED79F3D903E569",
                                   "synthesis.js":  "FCEFFE0180979659BA31B5E79D04BEF1F7FBD1A25DF61A1505EDA51A4C9EB1E2"
                               }
};
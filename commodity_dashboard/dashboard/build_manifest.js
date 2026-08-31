window.BUILD_MANIFEST = {
    "BUILD_STATUS":  "PASS",
    "generated_utc":  "2026-08-31T14:19:28Z",
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
                      "fresh":  56,
                      "stale_warn":  [
                                         "FR-001 (age 123d, budget 3m)",
                                         "MZ-002 (age 37d, budget 3w)",
                                         "WH-003 (age 37d, budget 3w)"
                                     ],
                      "escalated":  [

                                    ]
                  },
    "artifact_hashes_sha256":  {
                                   "commodity_exposure.html":  "D1C0DF58D2ACC2241CE7583292C6939DB26C8DE85E6FC218EDADC61196BD3808",
                                   "commodity_glossary.js":  "C61F45C7F4D4037AE2C8CB7D3D6C4AFF4B377F9308CD2AB2EA8ED2C250A79686",
                                   "data.js":  "94789E49DF856FC9A1E088AFFDAD28E5D1006CE36CBB4506F4A21CD8F2AA5A9E",
                                   "display_contract.js":  "2306A6AE1B02EB6289F6121C2EC6ED360813CFFFDFA589DD06ED79F3D903E569",
                                   "synthesis.js":  "6EFAD32F407207D257CCBAD12231D30C22527303ECF6B17349024D622F20FD4C"
                               }
};
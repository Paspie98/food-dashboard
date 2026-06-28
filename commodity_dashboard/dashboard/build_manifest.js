window.BUILD_MANIFEST = {
    "BUILD_STATUS":  "PASS",
    "generated_utc":  "2026-06-28T15:34:00Z",
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
                                         "FR-001 (age 120d, budget 3m)",
                                         "FR-005 (age 210d, budget 2q)",
                                         "SG-003 (age 120d, budget 3m)"
                                     ],
                      "escalated":  [

                                    ]
                  },
    "artifact_hashes_sha256":  {
                                   "data.js":  "635FE231B61E46A2AF62B911D07A765165F2B255412D673C82A14DEDC14EEFE4",
                                   "display_contract.js":  "2306A6AE1B02EB6289F6121C2EC6ED360813CFFFDFA589DD06ED79F3D903E569",
                                   "index.html":  "157ADCB955AAA144929F2DB6A974947553173F72D3928A8DB1BE49F6D21841BB",
                                   "synthesis.js":  "BA5B39806A15A7B49A4E85112A214D77AC547AAC8C9D70721C5300D458D92789"
                               }
};
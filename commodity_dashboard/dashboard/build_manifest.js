window.BUILD_MANIFEST = {
    "BUILD_STATUS":  "PASS",
    "generated_utc":  "2026-06-28T14:16:13Z",
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
                                   "data.js":  "CCB0B807C6195E7AB27731413153A02CCD97D0F8B818B4CF9BEEB7606C6F63E1",
                                   "display_contract.js":  "2306A6AE1B02EB6289F6121C2EC6ED360813CFFFDFA589DD06ED79F3D903E569",
                                   "index.html":  "88BBA774A17AB3B59342FA52934F1097822CB848C7992A681D952E6F5F344A24",
                                   "synthesis.js":  "D619E6BE96A6C0B00FF800F57F7CAF1700C4E862666416AC0C31F3D65342EB7A"
                               }
};
window.BUILD_MANIFEST = {
    "BUILD_STATUS":  "PASS",
    "generated_utc":  "2026-06-28T19:16:09Z",
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
                                   "commodity_exposure.html":  "484F585ED5E117C13FADB35C69302E86E3CF291812C1702E02E354F511ECA281",
                                   "data.js":  "1562E06CBE898D99D4D451DA0E6E0BA778ED23741AC1E17546265B0DBEE375CE",
                                   "display_contract.js":  "2306A6AE1B02EB6289F6121C2EC6ED360813CFFFDFA589DD06ED79F3D903E569",
                                   "index.html":  "D6D63183569838A1B39C77B845B39C88206D0FEFB2BBD1C337191298E832F5B4",
                                   "synthesis.js":  "7DB192D0608378392CEC1C21C62572230A3D9AE89B72D95936E3547F09B6421F"
                               }
};
window.BUILD_MANIFEST = {
    "BUILD_STATUS":  "PASS",
    "generated_utc":  "2026-08-24T07:40:47Z",
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
                      "fresh":  55,
                      "stale_warn":  [
                                         "FR-001 (age 115d, budget 3m)",
                                         "MZ-002 (age 29d, budget 3w)",
                                         "SG-003 (age 115d, budget 3m)",
                                         "WH-003 (age 29d, budget 3w)"
                                     ],
                      "escalated":  [

                                    ]
                  },
    "artifact_hashes_sha256":  {
                                   "commodity_exposure.html":  "D1C0DF58D2ACC2241CE7583292C6939DB26C8DE85E6FC218EDADC61196BD3808",
                                   "commodity_glossary.js":  "C61F45C7F4D4037AE2C8CB7D3D6C4AFF4B377F9308CD2AB2EA8ED2C250A79686",
                                   "data.js":  "3FDE12F7CD7489BDA79231882171D987FBEC0A7398FC2767C4905C555355F874",
                                   "display_contract.js":  "2306A6AE1B02EB6289F6121C2EC6ED360813CFFFDFA589DD06ED79F3D903E569",
                                   "synthesis.js":  "60A2532544487A859ADD1F777F0A2BBF22DA612003D048D1D786ACBC712FE55F"
                               }
};
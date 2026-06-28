window.BUILD_MANIFEST = {
    "BUILD_STATUS":  "PASS",
    "generated_utc":  "2026-06-28T16:00:10Z",
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
                                   "data.js":  "DC019400DA2E5DF076CB5F6A1BD8780B24ACA46639532D8C92B3DC28BB9A1987",
                                   "display_contract.js":  "2306A6AE1B02EB6289F6121C2EC6ED360813CFFFDFA589DD06ED79F3D903E569",
                                   "index.html":  "D6D63183569838A1B39C77B845B39C88206D0FEFB2BBD1C337191298E832F5B4",
                                   "synthesis.js":  "9F3C3256570ACFDAD43D7F0D3C14A09784CDB0CA72484D7AD99D36760487F31A"
                               }
};
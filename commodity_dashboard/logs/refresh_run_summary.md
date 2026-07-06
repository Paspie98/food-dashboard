# commodity dashboard refresh run summary

**Overall: PASS**  -  generated 2026-07-06T17:28:18Z

| step | status | detail |
|---|---|---|
| validate-registry | PASS |  |
| capture | PASS |  |
| ingest-licensed | PASS |  |
| build-crosscheck | PASS |  |
| build-data | PASS |  |
| build-display-contract | PASS |  |
| synthesis | PASS |  |
| gate-chart-integrity | PASS |  |
| gate-display-contract | PASS |  |
| gate-frontend-category | PASS |  |
| gate-axis-sanity | PASS |  |
| gate-banned-words | PASS |  |
| gate-licensed-contract | PASS |  |
| gate-no-secrets-in-archive | PASS |  |
| gate-crosscheck-integrity | PASS |  |
| gate-synthesis-fixtures | PASS |  |
| gate-synthesis-stability | PASS |  |
| qa-secrets-scan | PASS | no key-shaped content in emitted artifacts |
| qa-numeric-history | PASS | 31106 observations, all castable, finite, unique |
| qa-ratchet | PASS | captured 59 (floor 59) / charted 59 (floor 59) |
| data-freshness | WARN | fresh 57; stale-warn 2; escalated 0 / stale: FR-001 (age 97d, budget 3m), SG-003 (age 128d, budget 3m) |
| manifest | PASS | BUILD_STATUS=PASS; 5 artifact hashes |

counts: captured 59 / charted 59 / floors 59/59 / history obs 31106

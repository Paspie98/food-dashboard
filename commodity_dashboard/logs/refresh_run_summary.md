# commodity dashboard refresh run summary

**Overall: PASS**  -  generated 2026-06-28T16:09:50Z

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
| qa-numeric-history | PASS | 31060 observations, all castable, finite, unique |
| qa-ratchet | PASS | captured 59 (floor 59) / charted 59 (floor 59) |
| data-freshness | WARN | fresh 56; stale-warn 3; escalated 0 / stale: FR-001 (age 120d, budget 3m), FR-005 (age 210d, budget 2q), SG-003 (age 120d, budget 3m) |
| manifest | PASS | BUILD_STATUS=PASS; 4 artifact hashes |

counts: captured 59 / charted 59 / floors 59/59 / history obs 31060

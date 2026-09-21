# commodity dashboard refresh run summary

**Overall: PASS**  -  generated 2026-09-21T13:11:48Z

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
| qa-numeric-history | PASS | 31334 observations, all castable, finite, unique |
| qa-ratchet | PASS | captured 59 (floor 59) / charted 59 (floor 59) |
| data-freshness | ESCALATED | fresh 53; stale-warn 4; escalated 2 / ESCALATED: MZ-002 (age 58d, budget 3w), WH-003 (age 58d, budget 3w) |
| manifest | PASS | BUILD_STATUS=PASS; 5 artifact hashes |

counts: captured 59 / charted 59 / floors 59/59 / history obs 31334

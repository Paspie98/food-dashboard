# commodity dashboard refresh run summary

**Overall: PASS**  -  generated 2026-08-03T10:17:03Z

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
| qa-numeric-history | PASS | 31167 observations, all castable, finite, unique |
| qa-ratchet | PASS | captured 59 (floor 59) / charted 59 (floor 59) |
| data-freshness | WARN | fresh 51; stale-warn 8; escalated 0 / stale: FE-006 (age 94d, budget 3m), FE-009 (age 94d, budget 3m), FR-001 (age 124d, budget 3m), PK-002 (age 94d, budget 3m), PK-004 (age 94d, budget 3m), PK-007 (age 94d, budget 3m), PK-009 (age 94d, budget 3m), SG-003 (age 94d, budget 3m) |
| manifest | PASS | BUILD_STATUS=PASS; 5 artifact hashes |

counts: captured 59 / charted 59 / floors 59/59 / history obs 31167

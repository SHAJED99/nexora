# Traceability matrix

> **Generated — do not edit by hand.** Regenerate with `make trace`.
> Every number below is derived from `spec/srs.md`, `traces_to:` frontmatter,
> `files:` lists and EARS-named tests. If this report and the repo disagree,
> the repo wins: regenerate, never patch.

Generated from commit `8b70cd1` (2026-09-22) by `agent/orchestrator/traceability.py`.

## Coverage

| Metric | Count | Share |
|---|---:|---:|
| Requirements in `spec/srs.md` | 113 | — |
| …of which descoped (held out of orphan classes) | 1 | 0.9% |
| …mapped to an epic | 111 | 98.2% |
| …mapped to a task | 107 | 94.7% |
| …owning an EARS criterion | 100 | 88.5% |
| …reaching an EARS-named test | 99 | 87.6% |

| Artifact | Count |
|---|---:|
| Epics | 16 |
| Tasks | 232 |
| EARS criteria declared | 286 |
| EARS ids with >=1 test | 255 |
| Distinct EARS ids found in tests | 262 |
| ADRs | 8 |
| Design contracts | 26 |

**A requirement is *proven* only when the chain reaches a passing test.**
This report proves the chain reaches a test that *exists*; whether the suite
is green is the CI gate's answer, not this file's.

## Chain matrix

| Requirement | Epics | Tasks | EARS | Tests |
|---|---|---|---|---:|
| `FR-ABUSE-001` | E13, E15 | E13-B01, E13-T01, E13-T02, E13-T03, E13-T04, E13-T05, E13-T07, E15-T06 | EARS-ABUSE-1, EARS-ABUSE-10, EARS-ABUSE-11, EARS-ABUSE-2, EARS-ABUSE-3, EARS-ABUSE-3b, EARS-ABUSE-4, EARS-ABUSE-5, EARS-ABUSE-6, EARS-ABUSE-7, EARS-ABUSE-8, EARS-ABUSE-9 | 11 |
| `FR-AUTH-001` | E01, E12 | E01-B01, E01-T01, E12-B01 | EARS-AUTH-1, EARS-AUTH-3, EARS-AUTH-x1, EARS-AUTH-x2 | 3 |
| `FR-AUTH-002` | E01, E15 | E01-T01, E15-T07 | EARS-AUTH-13 | 1 |
| `FR-AUTH-003` | E01 | E01-T01 | EARS-AUTH-2 | 1 |
| `FR-AUTH-004` | E01, E11 | E01-T01, E01-T02, E11-T03, E11-T04 | EARS-AUTH-3, EARS-FB-7, EARS-FB-8 | 4 |
| `FR-AUTH-005` | E01 | E01-T01 | EARS-AUTH-4 | 1 |
| `FR-AUTH-006` | E15 | E15-B01, E15-T01, E15-T07, E15-T12 | EARS-AUTH-5 | 2 |
| `FR-AUTH-007` | E15 | E15-T01, E15-T07 | EARS-AUTH-7 | 2 |
| `FR-AUTH-008` | E15 | E15-T01, E15-T07, E15-T12 | EARS-AUTH-11, EARS-AUTH-5 | 2 |
| `FR-AUTH-009` | E15 | E15-T01, E15-T02 | EARS-AUTH-6 | 2 |
| `FR-AUTH-010` | E15 | E15-T02 | EARS-AUTH-8 | 1 |
| `FR-AUTH-011` | E15 | E15-T02 | EARS-AUTH-9 | 1 |
| `FR-AUTH-012` | E15 | E15-T02 | EARS-AUTH-10 | 1 |
| `FR-AUTH-013` | E15 | E15-T07, E15-T11 | EARS-AUTH-12 | 1 |
| `FR-BLOCK-001` | E02, E06, E07 | E02-B01, E02-T01, E02-T02, E06-T09, E07-T07, E07-T08 | EARS-BLOCK-1, EARS-CALL-4, EARS-COMM-17, EARS-COMM-33, EARS-DEV-2 | 5 |
| `FR-BLOCK-002` | E02 | E02-T01 | — | — |
| `FR-BLOCK-003` | E02 | E02-T01 | — | — |
| `FR-CALL-001` | E07 | E07-T09, E07-T10, E07-T11, E07-T12, E07-T13 | EARS-CALL-10, EARS-CALL-2, EARS-CALL-3, EARS-CALL-4, EARS-CALL-5 | 3 |
| `FR-CALL-002` | E07 | E07-B02, E07-T10, E07-T11 | EARS-CALL-6, EARS-CALL-7, EARS-CALL-8 | 2 |
| `FR-CALL-003` | E07 | E07-B03, E07-T11, E07-T12 | EARS-CALL-1, EARS-CALL-10, EARS-CALL-9 | 1 |
| `FR-COMM-001` | E04, E06, E07 | E04-B15, E06-B02, E06-B03, E06-B04, E06-T03, E06-T07, E06-T08, E06-T09, E06-T10, E06-T11, E06-T12, E06-T13, E06-T14, E07-T09, E07-T13 | EARS-COMM-1, EARS-COMM-14, EARS-COMM-17, EARS-COMM-19, EARS-COMM-20, EARS-COMM-21, EARS-COMM-22, EARS-COMM-23, EARS-COMM-25, EARS-COMM-27, EARS-COMM-28, EARS-COMM-7, EARS-UI-7 | 9 |
| `FR-COMM-002` | E07 | E07-B01, E07-T01, E07-T03, E07-T04, E07-T06, E07-T07, E07-T08, E07-T09, E07-T12, E07-T13, E07-T14 | EARS-COMM-29, EARS-COMM-30, EARS-COMM-33, EARS-COMM-35, EARS-UI-3, EARS-UI-7 | 4 |
| `FR-DIAG-001` | E13, E15 | E13-T06, E15-T06, E15-T10 | EARS-DIAG-2, EARS-DIAG-3 | 1 |
| `FR-DIAG-002` | E13, E15 | E13-B02, E13-T06, E15-T06, E15-T10 | EARS-DIAG-1, EARS-DIAG-4, EARS-VER-19 | 4 |
| `FR-DIAG-003` | E15 | E15-T06 | EARS-DIAG-4, EARS-DIAG-5 | 3 |
| `FR-DISC-001` | E04, E09, E15 | E04-B04, E04-B05, E04-B06, E04-B07, E04-B08, E04-B09, E04-B10, E04-B11, E04-B12, E04-B13, E04-B15, E04-B17, E04-B18, E04-B19, E04-B21, E04-B22, E04-B28, E04-B29, E04-B30, E04-B31, E04-B32, E04-B33, E04-T03a, E04-T03b, E04-T03c, E04-T05, E04-T06, E04-T07, E09-B03, E15-T08 | EARS-DEV-3, EARS-DISC-2, EARS-TRANSPORT-2, EARS-TRANSPORT-3 | 2 |
| `FR-DISC-002` | E04 | E04-B04, E04-B21, E04-B22, E04-T03b | — | — |
| `FR-DISC-003` | E04, E15 | E15-T08 | EARS-ROUTE-15 | 1 |
| `FR-FB-001` | E01, E11 | E01-T02, E11-B01, E11-B02, E11-B03, E11-B04, E11-B05, E11-B06, E11-T01, E11-T02, E11-T03, E11-T04, E11-T05, E11-T06 | EARS-FB-1, EARS-FB-10, EARS-FB-13, EARS-FB-16, EARS-FB-17, EARS-FB-19, EARS-FB-2, EARS-FB-3, EARS-FB-4, EARS-FB-6, EARS-FB-7, EARS-FB-8 | 8 |
| `FR-FB-002` | E01, E05, E11 | E01-T02, E05-T04, E11-B02, E11-B04, E11-B05, E11-T01, E11-T02, E11-T04, E11-T06 | EARS-FB-1, EARS-FB-13, EARS-FB-17, EARS-FB-2, EARS-FB-4, EARS-FB-5, EARS-MSG-6 | 7 |
| `FR-GROUP-001` | E07 | E07-T01, E07-T02, E07-T03, E07-T07, E07-T08, E07-T12 | EARS-GROUP-3, EARS-GROUP-4, EARS-UI-3 | 2 |
| `FR-GROUP-002` | E07 | E07-B01, E07-B04, E07-T01, E07-T02, E07-T03, E07-T12 | EARS-COMM-34, EARS-GROUP-10, EARS-GROUP-3, EARS-GROUP-6, EARS-GROUP-8 | 5 |
| `FR-GROUP-003` | E07 | E07-B04, E07-T02, E07-T03, E07-T12 | EARS-GROUP-7, EARS-GROUP-9 | 3 |
| `FR-GROUP-004` | E07 | E07-T01, E07-T04, E07-T05, E07-T06 | EARS-GROUP-1, EARS-GROUP-11, EARS-GROUP-12, EARS-GROUP-16, EARS-GROUP-5 | 6 |
| `FR-GROUP-005` | E07 | E07-T04, E07-T05, E07-T06 | EARS-COMM-31, EARS-GROUP-14, EARS-GROUP-15 | 3 |
| `FR-GROUP-006` | E07 | E07-T01, E07-T04, E07-T05 | EARS-GROUP-13, EARS-GROUP-2 | 2 |
| `FR-LOC-001` | E09, E15 | E09-B04, E09-B05, E09-B07, E09-B12, E09-T01, E09-T02, E09-T05, E15-T05 | EARS-LOC-1, EARS-LOC-17, EARS-LOC-3, EARS-LOC-6, EARS-SEC-4 | 5 |
| `FR-LOC-002` | E09, E15 | E09-B04, E09-B05, E09-B07, E09-B12, E09-T01, E09-T02, E15-T05 | EARS-LOC-1, EARS-LOC-4, EARS-LOC-6, EARS-LOC-7 | 3 |
| `FR-LOC-003` | E09, E15 | E09-B01, E09-B02, E09-B03, E09-B04, E09-B05, E09-B06, E09-B08, E09-B09, E09-B10, E09-B11, E09-B13, E09-T02, E09-T03, E09-T04, E09-T05, E15-T05 | EARS-LOC-1, EARS-LOC-10, EARS-LOC-14, EARS-LOC-15, EARS-LOC-16, EARS-LOC-17, EARS-LOC-9, EARS-SEC-4 | 5 |
| `FR-LOC-004` | E09 | E09-B02, E09-B04, E09-B05, E09-B06, E09-B08, E09-B09, E09-B11, E09-T01, E09-T03, E09-T05 | EARS-LOC-10, EARS-LOC-11, EARS-LOC-12, EARS-LOC-5, EARS-LOC-8 | 4 |
| `FR-LOC-005` | E09 | E09-B01, E09-B04, E09-T01, E09-T04 | EARS-LOC-13, EARS-LOC-14, EARS-LOC-2 | 1 |
| `FR-MSG-001` | E04, E05, E06 | E04-B23, E04-B24, E04-B25, E04-B26, E05-B01, E05-B02, E05-B03, E05-T01, E05-T02, E06-T03, E06-T06, E06-T07, E06-T11 | EARS-COMM-13, EARS-COMM-14, EARS-COMM-23, EARS-COMM-6, EARS-MSG-1 | 5 |
| `FR-MSG-002` | E05, E06, E07 | E05-B03, E05-T01, E06-T06, E06-T08, E06-T11, E07-T06 | EARS-COMM-24, EARS-COMM-30, EARS-MSG-2a, EARS-MSG-2b, EARS-MSG-7, EARS-MSG-8, EARS-MSG-9 | 4 |
| `FR-MSG-003` | E04, E05, E06, E07, E08 | E04-B27, E05-B01, E05-T01, E05-T03, E06-T02, E06-T05, E06-T08, E07-T06, E08-B04 | EARS-COMM-10, EARS-COMM-32, EARS-COMM-4, EARS-COMM-5, EARS-COMM-8, EARS-MSG-2 | 6 |
| `FR-MSG-004` | E05, E06, E07 | E05-B01, E05-T01, E05-T03, E06-T05, E06-T09, E06-T11, E07-T06, E07-T07 | EARS-COMM-18, EARS-MSG-3 | 3 |
| `FR-MSG-005` | E05, E06 | E05-T02, E06-T06 | EARS-COMM-12 | 1 |
| `FR-MSG-006` | E05 | E05-T04 | EARS-MSG-5 | 1 |
| `FR-MSG-007` | E05, E09, E11, E12 | E05-T05, E09-B07, E09-T02, E11-T04, E11-T05, E12-B03 | EARS-FB-11, EARS-FB-15, EARS-LOC-4, EARS-MSG-4 | 3 |
| `FR-MSG-008` | E05 | — | — | — |
| `FR-NOTIFY-001` | E10, E15 | E10-B03, E10-B09, E10-B10, E10-T01, E10-T02, E10-T03, E10-T04, E10-T05, E10-T06, E10-T07, E15-T04 | EARS-NOTIFY-1, EARS-NOTIFY-10, EARS-NOTIFY-11, EARS-NOTIFY-12, EARS-NOTIFY-13, EARS-NOTIFY-14, EARS-NOTIFY-15, EARS-NOTIFY-16, EARS-NOTIFY-3, EARS-NOTIFY-5, EARS-NOTIFY-6, EARS-NOTIFY-8, EARS-NOTIFY-9, EARS-PLAT-5 | 13 |
| `FR-NOTIFY-002` | E10, E15 | E10-B03, E10-T02, E10-T03, E15-T04, E15-T05 | EARS-NOTIFY-17, EARS-NOTIFY-2, EARS-NOTIFY-3, EARS-NOTIFY-4, EARS-NOTIFY-6, EARS-NOTIFY-7, EARS-SEC-5 | 6 |
| `FR-NOTIFY-003` | E15 | E15-T04 | EARS-NOTIFY-16, EARS-NOTIFY-17 | 1 |
| `FR-PLAT-001` | E10, E15 | E10-B01, E10-B04, E10-B05, E10-B06, E10-T08, E10-T10, E15-B03, E15-T08 | EARS-PLAT-10, EARS-PLAT-14, EARS-PLAT-2, EARS-PLAT-4, EARS-PLAT-7, EARS-PLAT-9 | 2 |
| `FR-PLAT-002` | E04, E10, E15 | E04-T03b, E04-T03c, E10-B02, E10-T08, E10-T09, E10-T10, E15-B03, E15-T08 | EARS-DISC-1, EARS-PLAT-1, EARS-PLAT-11, EARS-PLAT-12, EARS-PLAT-13, EARS-PLAT-15, EARS-PLAT-17, EARS-PLAT-8 | 5 |
| `FR-PLAT-003` | E04, E06, E10, E15 | E04-B03, E04-T03a, E06-B02, E10-B04, E10-B09, E10-B10, E10-T01, E10-T08, E10-T09, E15-B03 | EARS-PLAT-17, EARS-PLAT-3, EARS-PLAT-5, EARS-PLAT-6, EARS-PLAT-7, EARS-TRANSPORT-1 | 5 |
| `FR-PLAT-004` | E15 | E15-T08 | EARS-PLAT-15, EARS-PLAT-16 | 1 |
| `FR-RECOVER-001` | E12 | E12-B01, E12-B02, E12-B03, E12-B04, E12-B06, E12-B08, E12-B09, E12-B10, E12-T01, E12-T02, E12-T03 | EARS-RECOVER-1, EARS-RECOVER-10, EARS-RECOVER-3, EARS-RECOVER-4, EARS-RECOVER-5, EARS-RECOVER-6, EARS-RECOVER-7, EARS-RECOVER-8, EARS-RECOVER-9 | 6 |
| `FR-RECOVER-002` | E12, E15 | E12-B07, E12-T03, E15-T07 | EARS-AUTH-7, EARS-RECOVER-11, EARS-RECOVER-2 | 3 |
| `FR-ROUTE-001` | E04, E06 | E04-B03, E04-B17, E04-B24, E04-B26, E04-T02, E06-T04 | EARS-ROUTE-1, EARS-ROUTE-10, EARS-ROUTE-11 | 2 |
| `FR-ROUTE-002` | E04, E06, E07 | E04-B03, E04-B16, E04-T02, E06-T04, E06-T05, E06-T06, E07-T10 | EARS-CALL-7, EARS-COMM-9, EARS-ROUTE-11 | 4 |
| `FR-ROUTE-003` | E04, E06, E07 | E04-B05, E04-B06, E04-B07, E04-B16, E04-T04, E06-B02, E06-T02, E06-T05, E07-T06 | EARS-COMM-9, EARS-ROUTE-3, EARS-STORE-6, EARS-TRANSPORT-6 | 5 |
| `FR-ROUTE-004` | E04, E05, E06, E07 | E04-B02, E04-B05, E04-B06, E04-B07, E04-T04, E05-B02, E06-T02, E06-T06, E07-T10 | EARS-CALL-8, EARS-COMM-11, EARS-COMM-3, EARS-COMM-4, EARS-ROUTE-4b | 4 |
| `FR-ROUTE-005` | E04 | E04-T02 | — | — |
| `FR-ROUTE-006` | E04 | E04-B01, E04-T02 | EARS-ROUTE-2 | 2 |
| `FR-ROUTE-007` | E04, E06 | E06-T04 | EARS-COMM-26, EARS-ROUTE-10, EARS-ROUTE-12, EARS-ROUTE-13 | 4 |
| `FR-ROUTE-008` | E04 | — | — | — |
| `FR-ROUTE-009` | E04, E06, E07 | E04-B01, E04-B23, E04-B35, E04-B36, E04-B37, E04-B38, E04-B39, E04-T02, E06-T12, E07-B02, E07-T11 | EARS-CALL-11, EARS-ROUTE-14, EARS-ROUTE-4, EARS-TRANSPORT-10, EARS-TRANSPORT-11, EARS-TRANSPORT-4, EARS-TRANSPORT-5, EARS-TRANSPORT-8, EARS-TRANSPORT-9 | 4 |
| `FR-ROUTE-010` | E15 | E15-T08 | EARS-ROUTE-13, EARS-ROUTE-15 | 1 |
| `FR-SEC-001` | E03, E04, E07 | E03-B02, E03-B03, E03-T03, E04-B18, E04-B20, E04-B27, E07-T04, E07-T09 | EARS-CALL-2, EARS-GROUP-10, EARS-GROUP-13, EARS-SEC-1 | 6 |
| `FR-SEC-002` | E03, E07 | E03-T03, E07-T04, E07-T05 | EARS-GROUP-12, EARS-GROUP-16, EARS-SEC-2 | 3 |
| `FR-SEC-003` | E03, E04, E15 | E03-T01b, E03-T03, E04-B14, E15-T06 | EARS-SEC-3d | 1 |
| `FR-SEC-004` | E03 | E03-B01, E03-B02, E03-T01, E03-T01b, E03-T02, E03-T03 | EARS-SEC-3, EARS-SEC-3a, EARS-SEC-3b, EARS-SEC-3c, EARS-SEC-3d | 7 |
| `FR-SEC-005` | E15 | E15-T05 | EARS-SEC-4, EARS-SEC-5 | 1 |
| `FR-STORE-001` | E08 | E08-B03, E08-T02 | EARS-STORE-5 | 1 |
| `FR-STORE-002` | E08 | — | — | — |
| `FR-STORE-003` | E08 | — | — | — |
| `FR-STORE-004` | E08, E15 | E08-B01, E08-B04, E08-B07, E08-T01, E08-T05, E08-T07, E15-T09 | EARS-STORE-11, EARS-STORE-12, EARS-STORE-20, EARS-STORE-3, EARS-STORE-4 | 6 |
| `FR-STORE-005` | E08, E15 | E08-B02, E08-B03, E08-B05, E08-T01, E08-T02, E08-T03, E08-T04, E08-T06, E15-T09 | EARS-STORE-1, EARS-STORE-10, EARS-STORE-13, EARS-STORE-14, EARS-STORE-15, EARS-STORE-21, EARS-STORE-3, EARS-STORE-5, EARS-STORE-7, EARS-STORE-8, EARS-STORE-9 | 10 |
| `FR-STORE-006` | E08, E15 | E08-B02, E08-B06, E08-T07, E08-T08, E15-T09 | EARS-STORE-17, EARS-STORE-19, EARS-STORE-2, EARS-STORE-22 | 2 |
| `FR-STORE-007` | E08, E15 | E08-B01, E08-B02, E08-B04, E08-B05, E08-B06, E08-B07, E08-T01, E08-T06, E08-T07, E08-T08, E15-T09 | EARS-STORE-13, EARS-STORE-18, EARS-STORE-21, EARS-STORE-3, EARS-STORE-9 | 7 |
| `FR-TRUST-001` | E02 | E02-T01 | EARS-TRUST-4 | 1 |
| `FR-TRUST-002` | E02 | E02-T01 | — | — |
| `FR-TRUST-003` | E02, E06 | E02-T01, E02-T02, E06-T07, E06-T09, E06-T10 | EARS-COMM-15, EARS-COMM-17, EARS-COMM-20, EARS-DEV-1, EARS-TRUST-1, EARS-TRUST-2 | 6 |
| `FR-TRUST-004` | E02 | E02-T01, E02-T02 | EARS-TRUST-1, EARS-TRUST-2 | 2 |
| `FR-TRUST-005` | E02, E06 | E02-T01, E02-T02, E06-T07 | EARS-COMM-15, EARS-COMM-25, EARS-TRUST-3 | 3 |
| `FR-TRUST-006` | E02 | E02-T03 | — | — |
| `FR-TRUST-007` | E02, E11, E12 | E02-T03, E11-T05, E12-B02, E12-B03, E12-B09, E12-B11 | EARS-FB-14 | — |
| `FR-UI-001` | E06, E08, E15 | E06-T01, E06-T10, E06-T11, E06-T12, E06-T13, E08-T07, E15-T03 | EARS-COMM-28, EARS-STORE-16, EARS-UI-1, EARS-UI-2 | 1 |
| `FR-UI-002` | E06 | E06-T01 | EARS-UI-2 | 1 |
| `FR-UI-003` | E06 | E06-T10, E06-T12 | — | — |
| `FR-UI-004` | E01, E04, E06, E07, E08, E12, E15 | E01-B01, E04-B25, E04-B27, E04-B28, E04-B34, E04-B35, E04-B37, E04-T05, E06-B05, E06-B06, E06-T04, E06-T12, E07-T08, E07-T12, E08-T08, E12-B05, E12-B12, E12-B13, E12-B14, E15-T08 | EARS-AUTH-x2, EARS-COMM-2, EARS-COMM-26, EARS-DEV-4, EARS-ROUTE-14, EARS-TRANSPORT-9, EARS-UI-4, EARS-UI-5 | 5 |
| `FR-UI-005` | E06, E15 | E06-T10, E06-T11, E15-T03 | — | — |
| `FR-UI-006` | E15 | E15-T03, E15-T11, E15-T13 | EARS-UI-8 | 2 |
| `FR-UI-007` | E15 | E15-T03, E15-T04, E15-T05, E15-T06, E15-T08, E15-T09, E15-T10 | EARS-NOTIFY-17, EARS-UI-11, EARS-UI-9 | 8 |
| `FR-UI-008` | E15 | E15-T03, E15-T11, E15-T13 | EARS-UI-10 | 2 |
| `FR-VER-001` | E14 | E14-T05 | EARS-VER-14 | 1 |
| `FR-VER-002` | E14 | E14-T05 | EARS-VER-13 | 1 |
| `FR-VER-003` | E14 | E14-B04, E14-T06 | EARS-VER-15, EARS-VER-16 | 1 |
| `FR-VER-004` | E04, E14 | E04-T01 | EARS-SIM-1, EARS-SIM-2, EARS-SIM-3 | 1 |
| `FR-VER-005` | E14, E15 | E14-B01, E14-B03, E14-T01, E14-T02, E15-T10 | EARS-VER-18, EARS-VER-6, EARS-VER-7, EARS-VER-8, EARS-VER-9 | 2 |
| `FR-VER-006` | E14 | E14-B01, E14-B02, E14-B03, E14-B05, E14-T04 | EARS-AUTH-9, EARS-VER-1, EARS-VER-10, EARS-VER-11 | 3 |
| `FR-VER-007` | E14 | E14-B07, E14-T04 | EARS-VER-12 | 1 |
| `FR-VER-008` | E14, E15 | E14-B01, E14-B06, E14-T01, E15-T10 | EARS-VER-18, EARS-VER-3, EARS-VER-4, EARS-VER-5, EARS-VER-9 | 4 |
| `FR-VER-009` | E14 | E14-B04, E14-T04, E14-T06 | EARS-VER-15, EARS-VER-2 | 1 |
| `FR-VER-010` | E14 | E14-B01, E14-B02, E14-B03, E14-T01, E14-T02 | EARS-VER-20 | 1 |
| `FR-VER-011` | E14 | E14-T03 | EARS-VER-17 | 2 |
| `FR-VER-012` | E15 | E15-T10 | EARS-VER-18, EARS-VER-19 | 1 |
| `NFR-BATT-001` | E04, E06, E10 | E04-B35, E06-T06, E10-B02, E10-T10 | EARS-PLAT-12, EARS-TRANSPORT-5 | 2 |
| `NFR-PERF-001` | — | — | — | — |
| `NFR-PRIV-001` | E08, E11, E15 | E08-T02, E08-T06, E11-B01, E11-B02, E11-B05, E11-B06, E11-T01, E11-T02, E11-T06, E15-T01 | EARS-FB-18, EARS-FB-5, EARS-STORE-14, EARS-STORE-6 | 5 |
| `NFR-REL-001` | — | — | EARS-FB-12, EARS-MSG-6, EARS-UI-11 | 10 |
| `NFR-SCALE-001` | E08 | E08-T04 | EARS-STORE-10, EARS-STORE-19 | 2 |
| `NFR-SEC-001` | E04, E05, E06, E09, E10 | E04-B02, E05-B02, E06-B04, E06-T02, E06-T03, E06-T05, E06-T06, E06-T07, E06-T08, E06-T11, E09-B11, E10-B05, E10-B07 | EARS-COMM-11, EARS-COMM-16, EARS-COMM-5, EARS-COMM-6, EARS-COMM-8, EARS-MSG-8, EARS-PLAT-14, EARS-PLAT-4 | 7 |

## Orphans

Both directions. Forward gaps hide missing work; backward gaps hide
**unspecified** work, which is worse, because unspecified work still ships.

| Class | Count | Means | Route to | Release blocker |
|---|---:|---|---|---|
| requirement with no epic | 2 | scope never planned | `skills/epic-breakdown` | no |
| requirement with no task | 6 | epic never sharded, or sharded incompletely | `skills/epic-breakdown` | no |
| requirement owning no EARS criterion | 13 | invisible to the join; prose cross-references do not count | `skills/task-sharding` | no |
| requirement with no test | 13 | rule 7 breach — unproven, not done | `new test task` | **yes** |
| task with empty `traces_to:` | 1 | rule 1 breach — it isn't a task | `skills/question-resolution` | no |
| task citing a requirement not in `spec/srs.md` | 1 | building something nobody specified | `skills/change-impact` | no |
| `done` task with no EARS test | 8 | "done" that isn't | `revalidation task` | **yes** |
| `done` task tracing only descoped requirements | 1 | no test owed — its requirement was withdrawn; its own record must say why | `skills/change-impact` | no |
| EARS criterion with no test | 31 | criterion asserted, never proven | `new test task` | no |
| EARS criterion citing no requirement | 5 | proves nothing traceable | `skills/task-sharding` | no |
| test matching no declared EARS id | 7 | proves nothing traceable | `rename or delete task` | no |
| ADR nothing cites | 0 | dead decision, or decisions being made in diffs | `audit or supersede` | no |
| superseded ADR still cited | 0 | task honouring a reversed decision | `skills/change-impact` | **yes** |
| design contract no task builds | 10 | rule 2 breach — screen unbuilt or built off-contract | `skills/design-fidelity` | no |
| `done` task whose `depends_on` is not done | 0 | state-ordering violation; `make validate` does NOT catch this | `skills/review` | **yes** |
| `done` task carrying a 🟡 open question | 39 | blocked in fact but not in status | `skills/question-resolution` | no |

### requirement with no epic — 2

Route to `skills/epic-breakdown`.

- `NFR-PERF-001`
- `NFR-REL-001`

### requirement with no task — 6

Route to `skills/epic-breakdown`.

- `FR-MSG-008`
- `FR-ROUTE-008`
- `FR-STORE-002`
- `FR-STORE-003`
- `NFR-PERF-001`
- `NFR-REL-001`

### requirement owning no EARS criterion — 13

Route to `skills/task-sharding`.

- `FR-BLOCK-002`
- `FR-BLOCK-003`
- `FR-DISC-002`
- `FR-MSG-008`
- `FR-ROUTE-005`
- `FR-ROUTE-008`
- `FR-STORE-002`
- `FR-STORE-003`
- `FR-TRUST-002`
- `FR-TRUST-006`
- `FR-UI-003`
- `FR-UI-005`
- `NFR-PERF-001`

### requirement with no test — 13

Route to `new test task`.

- `FR-BLOCK-002`
- `FR-BLOCK-003`
- `FR-DISC-002`
- `FR-MSG-008`
- `FR-ROUTE-005`
- `FR-ROUTE-008`
- `FR-STORE-002`
- `FR-STORE-003`
- `FR-TRUST-002`
- `FR-TRUST-006`
- `FR-UI-003`
- `FR-UI-005`
- `NFR-PERF-001`

### task with empty `traces_to:` — 1

Route to `skills/question-resolution`.

- `E06-B01`

### task citing a requirement not in `spec/srs.md` — 1

Route to `skills/change-impact`.

- `NFR-OBS-001 (in E12-B08)`

### `done` task with no EARS test — 8

Route to `revalidation task`.

- `E04-B35`
- `E04-B36`
- `E04-T03b`
- `E04-T03c`
- `E06-T13`
- `E07-T12`
- `E07-T13`
- `E08-T07`

### `done` task tracing only descoped requirements — 1

Route to `skills/change-impact`.

- `E12-B11`

### EARS criterion with no test — 31

Route to `new test task`.

- `EARS-AUTH-x1`
- `EARS-AUTH-x2`
- `EARS-COMM-28`
- `EARS-DISC-1`
- `EARS-DISC-2`
- `EARS-FB-14`
- `EARS-FB-15`
- `EARS-NOTIFY-1`
- `EARS-NOTIFY-2`
- `EARS-PLAT-1`
- `EARS-PLAT-2`
- `EARS-PLAT-3`
- `EARS-PLAT-4`
- `EARS-RECOVER-2`
- `EARS-SET-2`
- `EARS-STORE-16`
- `EARS-STORE-17`
- `EARS-TRANSPORT-10`
- `EARS-TRANSPORT-11`
- `EARS-TRANSPORT-3`
- `EARS-TRANSPORT-4`
- `EARS-TRANSPORT-5`
- `EARS-TRANSPORT-6`
- `EARS-TRANSPORT-7`
- `EARS-TRANSPORT-8`
- `EARS-TRANSPORT-9`
- `EARS-TRUST-3`
- `EARS-UI-5`
- `EARS-UI-6`
- `EARS-UI-7`
- `EARS-VER-2`

### EARS criterion citing no requirement — 5

Route to `skills/task-sharding`.

- `EARS-FB-9`
- `EARS-SET-1`
- `EARS-SET-2`
- `EARS-TRANSPORT-7`
- `EARS-UI-6`

### test matching no declared EARS id — 7

Route to `rename or delete task`.

- `EARS-ABUSE-17`
- `EARS-FB-20`
- `EARS-FB-21`
- `EARS-RECOVER-6b`
- `EARS-ROUTE-004`
- `EARS-TRUST-4b`
- `EARS-VER-20b`

### design contract no task builds — 10

Route to `skills/design-fidelity`.

- `design/screens/call.md`
- `design/screens/chat-attachment.md`
- `design/screens/chat-location.md`
- `design/screens/chat-voice.md`
- `design/screens/group-create.md`
- `design/screens/group-manage.md`
- `design/screens/login.md`
- `design/screens/settings-battery.md`
- `design/screens/sign-out-confirm.md`
- `design/screens/welcome.md`

### `done` task carrying a 🟡 open question — 39

Route to `skills/question-resolution`.

- `E02-T02`
- `E02-T03`
- `E04-B37`
- `E05-B01`
- `E05-T03`
- `E05-T04`
- `E06-T02`
- `E06-T03`
- `E06-T04`
- `E06-T07`
- `E06-T08`
- `E07-T02`
- `E07-T03`
- `E07-T04`
- `E07-T06`
- `E07-T07`
- `E07-T09`
- `E07-T11`
- `E08-T05`
- `E08-T07`
- `E08-T08`
- `E09-T02`
- `E10-T01`
- `E10-T03`
- `E10-T04`
- `E10-T05`
- `E10-T06`
- `E10-T10`
- `E11-T04`
- `E11-T06`
- `E13-T01`
- `E13-T02`
- `E15-T01`
- `E15-T04`
- `E15-T05`
- `E15-T06`
- `E15-T07`
- `E15-T08`
- `E15-T10`

## Release gate

`skills/release` treats these classes as **blockers, not release notes**.

| Blocking class | Count | Clear? |
|---|---:|---|
| requirement with no EARS-named test | 13 | ❌ |
| `done` task with no passing EARS test | 8 | ❌ |
| `done` task whose dependency is not done | 0 | ✅ |
| superseded ADR still cited | 0 | ✅ |

**Blocking orphans: 21.** These are release blockers. Orphans knowingly shipped belong in the changelog's Known gaps.


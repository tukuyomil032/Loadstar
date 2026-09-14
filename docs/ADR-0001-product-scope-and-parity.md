# ADR-0001: Product Scope and Parity Contract

- Status: Accepted
- Date: 2026-09-14
- Supersedes: ADR-0001, ADR-0034
- Related: ADR-0001, ADR-0017

## Context

LoadStar must reproduce observable behavior of the Java Minecraft server manager. Complete parity includes normal paths, guards, branches, errors, cancellation, retry, partial success, recovery, and persisted results, not the old product identity.

## Decision

- Reference baseline is HEAD 4b718b9b1813157be49bf55c08a970da073b63f7.
- Record every feature at observable-branch granularity in the parity matrix.
- Keep FACT, DECISION, INFERRED, TEST, REAL-APP, MANUAL-QA, and RELEASE-QA separate.
- Correct a clear runtime bug only with reproduction evidence, an ADR note, a matrix entry, and an acceptance test.
- Safety, macOS rules, data integrity, accessibility, and HIG may supersede unsafe reference behavior only when explicit and testable.
- The new product name and identity are not exposed in new README, bundle, file, or folder names.

## Consequences

Parity is claimed from evidence, not visual resemblance or one passing unit test. The matrix and acceptance suite are release gates.

## Verification

The matrix, domain/integration/UI tests, Real App checks, manual QA, and release QA cover every applicable branch.

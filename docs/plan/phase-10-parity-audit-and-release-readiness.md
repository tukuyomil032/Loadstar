# Phase 10: Parity Audit and Release Readiness

- Status: Planned
- Depends on: Phase 00 through Phase 09
- ADRs: ADR-0001, ADR-0015, ADR-0017

## Goal

Perform the final observable parity audit and release gate without reopening settled high-level decisions.

## Tasks

- [ ] Compare the reference baseline against the complete matrix.
- [ ] Verify guard, success, failure, cancel, retry, partial, recovery, and persisted-result branches.
- [ ] Verify every intentional safety/platform/accessibility deviation.
- [ ] Verify migrations, exact proxy/artifact rows, redaction, Keychain, paths, and release hashes.
- [ ] Select and annotate Visualize/image-generation targets only after screen contracts are stable.
- [ ] Confirm clean build, CI, Real App, manual QA, Release QA, Sparkle, and Homebrew gates.

## Exit criteria

The active ADR set is consistent, the active Plan has no duplicate Phase files, all applicable evidence exists, and the release gate is auditable.

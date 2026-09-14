# Feature Parity Matrix

Each row describes an observable branch, not only a feature label.

| Area | Required branches | Required evidence |
| --- | --- | --- |
| Server/process | preflight, spawn, EULA, running, SLP-ready, timeout, quit, force, cancel | Domain, integration, Real App |
| Files/editor | read, edit, conflict, save, permission, running guard, rollback | Domain, filesystem, UI |
| Backup/restore | schedule, retention, manifest, checksum, pre-restore, stale cleanup, recovery | Domain, integration, Real App |
| Plugin/provider | compatibility, manual choice, dependency, checksum, cancel, partial, provenance | Provider fixture, integration |
| Proxy | exact row, mode, port, bind, secret, artifact, rollback | Fixture, integration, Real App |
| UI state | loading, empty, stale, partial, permission, repair, focus, announcement | UI, Accessibility, Manual QA |
| Release | version, appcast, signature, DMG hash, duplicate release, Homebrew | CI, Release QA |

Evidence labels are separate: FACT, DECISION, INFERRED, TEST, REAL-APP, MANUAL-QA, and RELEASE-QA. A unit test is not proof of real process behavior or distribution correctness.

Reference baseline: 4b718b9b1813157be49bf55c08a970da073b63f7. The full branch inventory and exact artifact rows are Phase 00 and Phase 10 gates.

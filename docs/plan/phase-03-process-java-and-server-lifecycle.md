# Phase 03: Process, Java, and Server Lifecycle

- Status: Planned
- Depends on: Phase 02
- ADRs: ADR-0006, ADR-0013

## Goal

Implement server create/import/start/stop/quit/recovery with explicit process and readiness states.

## Tasks

- [ ] Implement Java selection, JVM validation, artifact resolver, staging, checksum, and rollback.
- [ ] Implement process group, stdout/stderr separation, UTF-8 replacement, EULA, and quit.
- [ ] Implement running versus SLP-ready state and timeouts.
- [ ] Implement operation snapshots, checkpoints, cancellation, retry, and history.
- [ ] Add fixture server and real process tests.

## Exit criteria

Start, stop, force, cancel, EULA, SLP failure, import, duplicate, and rollback branches are tested.

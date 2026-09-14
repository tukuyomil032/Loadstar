# ADR-0008: Backup, Restore, and Destructive World Actions

- Status: Accepted
- Date: 2026-09-14
- Supersedes: ADR-0011 backup parts, ADR-0028 backup parts, ADR-0036
- Related: ADR-0005, ADR-0006, ADR-0013

## Context

Backups must be selectable, verifiable, and recoverable; world deletion is a destructive action.

## Decision

- Backup selector is connected to the selected server and actual catalog; stale selection is rejected.
- Automatic backup uses retain count or retain days; missed schedules are skipped.
- Concurrent manual backup is rejected and a running backup is not cancellable.
- Manifest records IDs, format, consistency, origin, time, counts, normalized per-file paths, size, kind, SHA-256, root fingerprint, archive SHA-256, and catalog metadata.
- Restore requires stopped state, validates manifest and fingerprint, creates a pre-restore snapshot, stages, verifies, and removes stale files only after commit.
- Partial restore is never success; pre-restore recovery is available.
- World candidates use level.dat and top-level world directories. Deletion is permanent, requires two confirmations, and does not make an automatic backup.
- Normalize paths, reject collisions and symlinks, and fail closed on checksum errors.

## Consequences

World removal matches observed behavior, so its confirmation and recovery wording must be explicit.

## Verification

Manifest, checksum, retention, pre-restore, stale cleanup, world detection, and deletion acceptance tests pass.

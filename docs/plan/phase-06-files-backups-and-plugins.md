# Phase 06: Files, Backups, Restore, and Plugins

- Status: Planned
- Depends on: Phase 02, Phase 03, Phase 05
- ADRs: ADR-0007, ADR-0008, ADR-0009

## Goal

Implement file editing, transactional backup/restore, world deletion, and trusted artifact installation.

## Tasks

- [ ] Implement file tree, metadata, search, STTextView, atomic save, and external conflict.
- [ ] Implement stopped-state guards, revalidation, rollback, and temporary cleanup.
- [ ] Implement backup selector, schedule/retention, manifest, fingerprint, checksum, pre-restore snapshot, and stale cleanup.
- [ ] Implement world candidate detection and permanent two-step deletion.
- [ ] Implement providers, compatible versions, dependencies, partial success, cancellation, and provenance.

## Exit criteria

Files, backups, restore, world deletion, and plugin/mod flows have branch-level fixtures and integration evidence.

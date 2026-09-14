# Phase 02: Domain Model and Persistence

- Status: Planned
- Depends on: Phase 01
- ADRs: ADR-0005

## Goal

Implement typed server models, managed root, schema, migration, provenance, Keychain, and safe paths.

## Tasks

- [ ] Implement identity, runtime configuration, policies, discovery, artifacts, Java, templates, and provenance.
- [ ] Implement managed-root layout, atomic writes, unknown-field retention, and migrations.
- [ ] Implement migration backup/verify/rollback and read-only fallback.
- [ ] Implement Keychain redaction and path/archive validation.
- [ ] Add schema fixtures and corruption/interruption tests.

## Exit criteria

Every persisted field has an owner, schema version, migration behavior, and test; secrets and unsafe paths fail closed.

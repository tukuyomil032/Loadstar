# ADR-0005: Persistence, Managed Root, Schema, and Security

- Status: Accepted
- Date: 2026-09-14
- Supersedes: ADR-0005, ADR-0015, ADR-0031, ADR-0039
- Related: ADR-0003, ADR-0008, ADR-0013

## Context

User-owned configuration, discovered facts, secrets, artifacts, and recovery metadata need separate ownership.

## Decision

- Managed root is Application Support/LoadStar with app-state.json, servers/index.json, one directory per server ID, server-files, backups, logs, and operations snapshots.
- Defaults stores small preferences only; Codable JSON uses atomic write and verification.
- Keychain stores tokens and secrets; plaintext secret persistence is rejected.
- Every document has a schema version and migration. Unknown fields are retained where possible. Migration backs up, verifies, and rolls back on failure.
- The server index owns stable identity. Metadata separates identity, runtime configuration, policies, discovery, artifacts, Java, JVM arguments, templates, and timestamps.
- Runtime status, PID, SLP readiness, and process handles are not persisted as live truth.
- User-owned and discovered values carry provenance.
- External paths are handled only through explicit Import, Export, backup, or proxy-output actions.
- Traversal, symlink escape, unsafe extraction, and checksum failures fail closed.

## Consequences

The model is verbose but makes migration, repair, provenance, and recovery deterministic.

## Verification

Schema, migration, interruption, Keychain redaction, path, and archive attack tests pass.

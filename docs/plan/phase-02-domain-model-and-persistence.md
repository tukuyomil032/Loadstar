# Phase 02: Domain Model, Persistence, Schema, and Security

- Status: In Progress; implementation and evidence are being recorded below
- Canonical ADRs: ADR-0003, ADR-0005
- Source transcript: `01a0908e-5282-71e2-aaed-82e67c119e45`
- Phase 01 relationship: Consumes the frozen Phase 01 foundation where applicable.

## Goal

Implement the typed domain and durable storage contracts that every later feature can depend on without placing runtime truth or secrets in unsafe documents.

## Why this phase exists

This phase is not a feature checklist. It turns the decisions recorded in its ADRs into an implementation order with explicit boundaries, failure behavior, and exit evidence. The implementation must not make a hidden product decision merely to finish a task.

## Entry gate reconciliation

- Phase 01 remains a frozen completed record; this phase does not rewrite its canonical file.
- `target_structure` is decided as the Xcode `LoadStar` App host plus seven SwiftPM library targets: `LoadStarDomain`, `LoadStarPersistence`, `LoadStarPlatform`, `LoadStarServices`, `LoadStarFeatures`, `LoadStarUI`, and `LoadStarGuide`.
- No `LoadStarApp` SwiftPM target is added.
- `swift-markdown` remains `PROVISIONAL` and is deferred to the Phase 06 editor design.
- `Package.swift` remains the dependency authority; no new external dependency is introduced for Phase 02.

## Current implementation record

| Area | Contract / target | Status |
| --- | --- | --- |
| Domain | Typed Sendable values, document envelopes, validation, policies, artifacts, operations, recovery issues, and side-effect protocols | IMPLEMENTED; tests pending full-suite verification |
| Persistence | Flattened deterministic JSON codec, unknown-field retention, atomic writer, migration coordinator, quarantine record store, and typed recovery state | IMPLEMENTED; tests pending full-suite verification |
| Managed path | Production/Debug namespace roots, canonical path validation, filesystem client, archive entry validation, opaque Keychain boundary, redaction | IMPLEMENTED; tests pending full-suite verification |
| Fixtures | Fixed JSON documents and migration inputs/expected outputs under `Tests/LoadStarPersistenceTests/Fixtures` | PENDING |
| Integration | Fixed managed-root index/metadata, migration, quarantine/LKG, namespace, secret, path, and archive scenarios | PENDING |

The canonical wire examples for `server-index`, `server-metadata`, unknown fields, migration revisions, and quarantine/Last Known Good references are recorded in ADR-0005.

## Source-backed inputs

- ADR-0003 and ADR-0005.
- Phase 00 domain/reference inventory.
- Phase 01 Package and target boundaries.
- Transcript topics: `server_metadata_shape`, `server_index_shape`, `schema_*`, `unknown_json_fields`, `provenance_*`, `legacy_data_import`, `migration_*`, `managed_path_*`.

## Transcript topics assigned to this phase

`app_state_storage_split`, `data_compatibility`, `dependency_policy`, `detected_configuration_drift`, `identifier_encoding`, `json_corruption_recovery_policy`, `json_document_shape`, `last_known_good_restore_confirmation`, `legacy_data_import`, `legacy_migration`, `loadstar_license_choice`, `loadstar_schema_migration_policy`, `managed_path_missing_policy`, `metadata_canonical_provenance`, `metadata_invalid_values`, `metadata_path_representation`, `metadata_structure`, `migration_backup_retention`, `optional_field_encoding`, `persistence_strategy`, `policy_schema`, `profile_template_schema`, `project_structure`, `provenance_storage_shape`, `runtime_event_backpressure`, `runtime_event_transport`, `schema_migration_execution`, `schema_version_encoding`, `schema_version_format`, `schema_version_granularity`, `server_group_storage`, `server_id_strategy`, `server_index_entry_fields`, `server_index_responsibility`, `server_index_shape`, `server_metadata_shape`, `server_metadata_storage_layout`, `server_metadata_timestamps`, `server_policy_defaults`, `server_provenance_storage`, `server_storage_policy`, `server_template_scope`, `spm_dependency_policy`, `state_architecture`, `sttextview_license`, `swift_concurrency_mode`, `swift_markdown_role`, `swift_package_dependency_direction`, `swift_package_module_strategy`, `swift_package_ui_placement`, `swift_toolchain_policy`, `template_copy_scope`, `timestamp_encoding`, `ui_architecture`, `unknown_field_storage`, `unknown_json_fields`, `unknown_schema_version_policy`

## Work packages

1. Define server identity, metadata, runtime configuration, policies, provenance, artifact identity, Java selection, JVM arguments, backup, plugin, proxy, operation, and error models.
2. Define independent document envelopes and schema versions for app state, server index, server metadata, operations, backup catalog, and feature-specific documents.
3. Implement atomic Codable JSON load/save with temporary-file validation and replacement.
4. Implement unknown-field retention, invalid-value classification, migration backup, automatic conversion, rollback, and quarantine.
5. Implement managed-root and path validation, symlink/traversal checks, archive extraction checks, and Debug namespace isolation.
6. Implement Keychain-backed secret interfaces and redacted diagnostics.
7. Add deterministic persistence and migration fixtures before feature services consume them.

## Implementation contract

- `LoadStarDocument` carries document type, schema version, payload, unknown fields, and provenance.
- `ServerIndex` owns stable identity and display ordering; `ServerMetadata` owns per-server configuration and provenance.
- Runtime PID, process handle, SLP readiness, and live uptime are not durable truth.
- Migration returns `migrated`, `unchanged`, `unsupported`, `quarantined`, or `rolledBack` with a recoverable backup reference.
- Secret APIs return opaque values and never encode them into ordinary Codable documents.

### Dependency and sequencing rules

- Consume the previous Phase contracts rather than reaching around them.
- Keep effects behind the service/platform actor boundary defined by ADR-0003.
- Represent every user-visible asynchronous operation with typed state and an operation/recovery policy where applicable.
- Keep Debug and production state isolated.
- Preserve evidence labels: a fixture pass does not become Real App or Release QA evidence.

### Failure, rollback, and recovery

Corrupt JSON, unsupported schema, permission failure, path escape, checksum mismatch, interrupted migration, and failed atomic replacement preserve the original or recovery backup. Last Known Good is presented as a candidate and requires confirmation.

A failure report must identify the stage, target, user-visible result, retained data, cleanup, retry policy, and recovery action. Do not convert a failed or partial operation into an ordinary empty state.

## Test plan

Schema round trips, unknown fields, missing/invalid values, migration interruption, rollback, quarantine, atomic save, managed path security, Keychain redaction, Debug/Release root separation, and fixture recovery.

Use Swift Testing for deterministic domain/integration cases and XCTest/XCUITest for App/UI/accessibility behavior where the relevant ADR requires it. Add fixture/process/manual/release evidence only at the layer that can actually prove the behavior.

## Exit criteria

All document contracts compile under strict concurrency; migration and path tests pass; no feature stores secrets or live process truth in ordinary JSON.

Additionally:

- All new types and protocols compile under the selected Swift concurrency mode.
- All applicable parity rows touched by this phase link to a test or explicit evidence requirement.
- No new unresolved behavior is hidden in an implementation detail.
- Any newly discovered mismatch is recorded in the existing ADR/ledger rather than creating a duplicate numbered document.

## Evidence record template

```markdown
- Phase: 02
- Commit:
- Target / architecture:
- Scenario:
- Command:
- Evidence kind: TEST / REAL-APP / MANUAL-QA / RELEASE-QA
- Result:
- Parity rows:
- Redactions applied:
- Follow-up:
```

## Deferred work and gate

This phase is complete only when its exit criteria and evidence profile are satisfied. A documentation decision can be complete while the implementation gate remains pending; do not report the latter as complete until the code and evidence exist.

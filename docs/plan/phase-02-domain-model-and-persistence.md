# Phase 02: Domain Model, Persistence, Schema, and Security

- Status: Complete for package/local evidence; Real App, Manual QA, Accessibility QA, and Release QA remain open
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
| Domain | Typed Sendable values, document envelopes, validation, policies, artifacts, operations, recovery issues, and side-effect protocols | IMPLEMENTED; local tests verified |
| Persistence | Flattened deterministic JSON codec, unknown-field retention, atomic writer, migration coordinator, quarantine record store, and typed recovery state | IMPLEMENTED; local tests verified |
| Managed path | Production/Debug namespace roots, canonical path validation, filesystem client, archive entry validation, opaque Keychain boundary, redaction | IMPLEMENTED; local tests verified |
| Fixtures | Fixed JSON documents and migration inputs/expected outputs under `Tests/LoadStarPersistenceTests/Fixtures` | IMPLEMENTED; resource loading verified |
| Integration | Fixed managed-root index/metadata, migration, quarantine/LKG, namespace, secret, path, and archive scenarios | IMPLEMENTED; local tests verified |

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
- Migration returns `migrated`, `unsupportedReadOnly`, `repairRequired`, `rolledBack`, or `failed` with a recoverable backup reference where available.
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

## Phase 02 verification record

### Commit record

- `a175e3c docs: reconcile Phase 2 architecture gate`
- `61f09f3 feat: add domain document contracts`
- `87ea7a0 feat: add recoverable document persistence`
- `4c39b58 feat: add managed storage and keychain boundaries`
- `d8a5dd0 test: add persistence and security fixtures`
- `b413951 fix: harden secret and quarantine identifiers`
- `af28484 fix: harden migration backup retention`
- This verification record is committed in a dedicated documentation commit after the implementation commits above.

### Target and architecture

- Xcode `LoadStar` remains the App host.
- `Package.swift` exposes exactly seven library targets: `LoadStarDomain`, `LoadStarPersistence`, `LoadStarPlatform`, `LoadStarServices`, `LoadStarFeatures`, `LoadStarUI`, and `LoadStarGuide`.
- No `LoadStarApp` SwiftPM target was added.
- `LoadStarPersistence` depends on `LoadStarDomain` and `Defaults`; it does not depend on `LoadStarPlatform`.
- The package retains only the existing `Defaults`, `Sparkle`, and `STTextView` external dependencies. `swift-markdown` remains `PROVISIONAL` and deferred to Phase 06.

### Commands and results

- `swift package dump-package` — PASS. The manifest reports the seven library products, the expected Persistence dependency direction, and `Fixtures` as a copied resource for `LoadStarPersistenceTests`.
- `swift test --parallel` — PASS. 49/49 test cases were invoked successfully across Domain, Persistence, Platform, Integration, Services, UI, Features, and Acceptance targets.
- `swift-format lint --recursive Loadstar/ Tests/` — PASS.
- `swiftlint lint --no-cache` — PASS with 0 serious violations. 27 non-blocking style warnings remain in the current checkout, primarily legacy trailing-comma/layout rules and intentionally grouped persistence test/file-size warnings.
- `xcodebuild -quiet -project LoadStar.xcodeproj -scheme LoadStar -configuration Debug -arch arm64 ARCHS=arm64 ONLY_ACTIVE_ARCH=YES build CODE_SIGNING_ALLOWED=NO` — PASS for the arm64 App host. Xcode emitted only the existing multiple-destination and signed-Sparkle stripping warnings.
- A default x86_64 build was attempted separately and did not pass because the existing SwiftPM artifacts were arm64 while the project selected x86_64. Universal/dual-architecture App-host evidence is therefore not claimed.

### TEST evidence

- Domain: UUID v4 lowercase canonicalization, managed-path safety, nested JSON values, server index duplicate rejection, metadata validation, runtime configuration restrictions, and opaque secret descriptions.
- Persistence: flattened top-level wire format, sorted-key/ISO 8601 output, top-level and nested unknown-field retention, missing-versus-empty state, read-back validation, atomic replacement, temporary cleanup, malformed/type-mismatch quarantine, future-revision read-only behavior, migration chain success, transform failure, validation failure, backup failure, replace failure, rollback retention, explicit Last Known Good confirmation, and migration-backup retention cleanup.
- Platform: production/Debug root separation, missing-root creation, symlink escape rejection, managed-path validation, archive absolute/traversal/link/duplicate/checksum rejection, fake Keychain namespace/purpose separation, and diagnostic redaction.
- Integration: index order resolving server metadata, unknown metadata fields, migration failure retaining the original, quarantine plus confirmation-gated recovery, Debug namespace isolation, path/archive pre-commit rejection, and secret absence from ordinary JSON.

### Persistence parity rows

The following Phase 02 rows have direct package-test evidence: `json_document_shape`, `schema_version_encoding`, `schema_version_format`, `schema_version_granularity`, `loadstar_schema_migration_policy`, `unknown_schema_version_policy`, `unknown_field_storage`, `unknown_json_fields`, `json_corruption_recovery_policy`, `last_known_good_restore_confirmation`, `migration_backup_retention`, `server_index_shape`, `server_index_entry_fields`, `server_index_responsibility`, `server_metadata_shape`, `server_metadata_storage_layout`, `server_metadata_timestamps`, `metadata_invalid_values`, `identifier_encoding`, `optional_field_encoding`, and `timestamp_encoding`.

The `data_compatibility`, `legacy_data_import`, and `legacy_migration` rows remain explicit product boundaries: the old application store is not auto-migrated, and later Import work must provide its own evidence. `app_state_storage_split` has its document type and codec contract in place but requires App-host wiring evidence in a later phase.

### Managed path and security parity rows

The following rows have direct package-test evidence: `server_storage_policy`, `managed_path_missing_policy`, `metadata_path_representation`, `identifier_encoding`, `diagnostic_path_redaction`, plus the Phase 02 archive safety and Keychain namespace contracts. Archive extraction itself remains deferred to Phase 06; Phase 02 stops at fail-closed entry validation before staging or commit.

### Redactions applied

- Secret payloads are opaque and are not `Codable`; `String(describing:)` and debug descriptions return `<redacted>`.
- Ordinary document encoding and integration output contain no secret value.
- Diagnostics retain stable code, stage, relative managed target, retryability, and recovery action while redacting absolute paths, usernames embedded in paths, token/password/secret/credential values, and authorization headers.
- Migration and quarantine references use managed-relative paths and operation-scoped identifiers; no absolute filesystem path is persisted in the document model.

### Evidence boundaries and follow-up

- `REAL-APP`: NOT COMPLETED. The Xcode arm64 build proves compilation/linking of the App host only; it does not prove a launched app's runtime behavior.
- `MANUAL-QA`: NOT COMPLETED. Managed-root repair UI, recovery confirmation UI, and real filesystem behavior require a later manual pass.
- `ACCESSIBILITY-QA`: NOT COMPLETED.
- `RELEASE-QA`: NOT COMPLETED. No release metadata, `version.env`, tag, appcast, notarization, or distribution artifact was changed or validated.
- Live macOS Keychain behavior was not exercised by the package tests; Platform tests use a fake Keychain implementation while the Apple Security-backed service remains the production boundary.
- Migration backup cleanup is retryable: a successful same-path save removes the pending backup, while cleanup failure keeps the backup and records a retryable diagnostic. Recovery candidates remain available until cleanup succeeds.
- Actual archive extraction/commit and external-folder Import remain later-phase work.

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

The package/local implementation gate is complete and recorded above. Real App, Manual QA, Accessibility QA, and Release QA remain separate follow-up evidence and must not be inferred from these package tests.

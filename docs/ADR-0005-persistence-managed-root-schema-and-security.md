# ADR-0005: Persistence, Managed Root, Schema, and Security

- Status: Accepted for implementation planning; code/evidence status is tracked separately
- Source transcript: `01a0908e-5282-71e2-aaed-82e67c119e45`
- Primary Phase: Phase 02
- Decision authority: visible user decisions and later explicit corrections
- Implementation authority: this ADR plus the canonical Phase file
- Evidence authority: `docs/decision-ledger.md`, `docs/feature-parity-matrix.md`, and linked test/QA artifacts

## Context

The app owns server metadata, policies, artifacts, recovery records, and secrets while also interacting with user-selected server folders. These are different trust boundaries and must not be flattened into one unvalidated JSON blob.

## User intent recovered from the transcript

管理対象root、用途別保存、schema version、unknown field、provenance、Keychain、atomic write、migration rollbackを含む「壊れても戻せる」保存設計を決める。

## Question and answer trace
The raw occurrence-level question, options, answer, classification, and effective resolution remain in `docs/decision-ledger.md`. This table is a navigable responsibility index; it does not replace the occurrence history.
| Question ID | Transcript ordinals | Occurrence states | Effective resolution |
| --- | --- | --- | --- |
| `app_state_storage_split` | 3123 | `DECIDED` | 嗜好はDefaults・復旧状態はJSON (Recommended) |
| `data_compatibility` | 321 | `DECIDED` | 新規開始 |
| `detected_configuration_drift` | 3249 | `DECIDED` | 差分を知らせて確認 (Recommended) |
| `identifier_encoding` | 9799 | `DECIDED` | lowercase UUID v4 (Recommended) |
| `json_corruption_recovery_policy` | 3131 | `DECIDED` | quarantine＋復旧画面 (Recommended) |
| `json_document_shape` | 9603 | `DECIDED` | 型＋revision＋分野別field (Recommended) |
| `last_known_good_restore_confirmation` | 3141, 3149 | `CLARIFICATION_REQUIRED, DECIDED` | 候補を提示してユーザーが確認してから復元する。先行回答は英語表記への修正要求であり、決定ではない。 |
| `legacy_data_import` | 7184, 7258 | `SUPERSEDED, DECIDED` | serverのフォルダだけ（推奨） |
| `legacy_migration` | 5163 | `DECIDED` | 汎用Importのみ（推奨） |
| `loadstar_schema_migration_policy` | 3091 | `DECIDED` | versioned migration chain (Recommended) |
| `managed_path_missing_policy` | 3257 | `DECIDED` | 登録を残して修復案内 (Recommended) |
| `metadata_canonical_provenance` | 3241 | `DECIDED` | 正規設定＋検出情報 (Recommended) |
| `metadata_invalid_values` | 5192 | `DECIDED` | 不足は初期値、不正は修復（推奨） |
| `metadata_path_representation` | 9868 | `DECIDED` | IDから導出＋相対参照のみ (Recommended) |
| `metadata_structure` | 8877 | `DECIDED` | 分野別に分離（推奨） |
| `migration_backup_retention` | 9449 | `DECIDED` | 短期recovery保持（推奨） |
| `optional_field_encoding` | 9627 | `DECIDED` | 意味ごとに使い分ける (Recommended) |
| `persistence_strategy` | 559 | `DECIDED` | 用途別にApple標準を使い分ける |
| `policy_schema` | 8887 | `DECIDED` | 型付きPolicy（推奨） |
| `profile_template_schema` | 8989 | `DECIDED` | 両方を別管理（推奨） |
| `provenance_storage_shape` | 7174, 7242 | `SUPERSEDED, DECIDED` | server設定ファイル内で分ける（推奨） |
| `schema_migration_execution` | 7202, 7210, 7226 | `CLARIFICATION_REQUIRED, DECIDED` | 旧schemaを退避し、検証可能な自動変換を実行する。変換失敗時は旧データと退避を保持してrollbackする。中間回答は表記・質問理解への指摘であり、決定ではない。 |
| `schema_version_encoding` | 9441 | `DECIDED` | 整数＋document type（推奨） |
| `schema_version_format` | 9595 | `DECIDED` | 整数revision (Recommended) |
| `schema_version_granularity` | 7192, 7234 | `SUPERSEDED, DECIDED` | ファイルの種類ごとに別々（推奨） |
| `server_group_storage` | 5241 | `DECIDED` | metadata.jsonだけ（推奨） |
| `server_id_strategy` | 3107 | `DECIDED` | 登録時UUID (Recommended) |
| `server_index_entry_fields` | 9619 | `DECIDED` | IDだけ (Recommended) |
| `server_index_responsibility` | 3115 | `DECIDED` | identityと順序だけ (Recommended) |
| `server_index_shape` | 9611 | `DECIDED` | ID entryの配列 (Recommended) |
| `server_metadata_shape` | 5171 | `DECIDED` | 機能領域ごとに入れ子（推奨） |
| `server_metadata_storage_layout` | 3051 | `DECIDED` | 全体index＋server別JSON (Recommended) |
| `server_metadata_timestamps` | 7724 | `DECIDED` | 登録・設定変更・確認を分ける（推奨） |
| `server_policy_defaults` | 8913 | `DECIDED` | 参照値を固定（推奨） |
| `server_provenance_storage` | 5268 | `DECIDED` | metadata内の独立section（推奨） |
| `server_storage_policy` | 9553 | `DECIDED` | 固定managed root (Recommended) |
| `server_template_scope` | 5219 | `DECIDED` | 参照実装のsubsetを再現（推奨） |
| `template_copy_scope` | 9014 | `DECIDED` | 参照範囲を再現（推奨） |
| `timestamp_encoding` | 9635 | `DECIDED` | UTCのISO 8601文字列 (Recommended) |
| `unknown_field_storage` | 9457 | `DECIDED` | raw extension map（推奨） |
| `unknown_json_fields` | 7164, 7250 | `SUPERSEDED, DECIDED` | そのまま保持する（推奨） |
| `unknown_schema_version_policy` | 3099 | `DECIDED` | read-only＋更新要求 (Recommended) |

## Decision

- Use Application Support/LoadStar as the managed root with app state, server index, server directories, backups, logs, and operation snapshots separated by purpose.
- Use Defaults for small preferences and Codable JSON for structured documents.
- Store tokens and secrets in Keychain; never put secrets in settings JSON, logs, Changelog, Appcast, or generated guides.
- Give each document type an independent schema version.
- Preserve unknown JSON fields as raw fields where possible.
- Store discovery/Import provenance in a distinct metadata area.
- Import old data only through an explicit server-folder import flow; do not silently share old application state.
- Migrations back up, transform, validate, and roll back or quarantine on failure.
- Stable server identity belongs to the index; runtime truth such as PID and live readiness is not persisted as authoritative state.
- Managed paths, symlink escapes, archive traversal, unsafe extraction, and checksum failure are fail-closed.

## Why this decision was made

Purpose separation is required for recovery and security. A migration must be reversible, a discovered fact must not overwrite a user choice, and runtime process state must not survive as if it were live truth after a crash or relaunch.

## Rejected, superseded, or clarification-only alternatives

- One database or one untyped JSON document — rejected because it hides ownership and makes partial recovery difficult.
- Silent migration of legacy app state — rejected; the user chose explicit import and a new start.
- Plaintext secrets beside settings — rejected by the security boundary.

## Implementation contract

### Modules and ownership

`LoadStarDomain` defines document models and validation. `LoadStarPersistence` owns Codable encoding, atomic writes, migrations, indexes, and quarantine. `LoadStarPlatform` owns Keychain and filesystem primitives. Services coordinate multi-document transactions.

### Types and protocols

Define `SchemaVersion`, `DocumentEnvelope`, `ServerIndex`, `ServerIndexEntry`, `ServerMetadata`, `Provenance`, `UnknownFields`, `MigrationStep`, `MigrationBackup`, `ManagedPath`, and `PersistenceIssue`.

### Actors and concurrency boundaries

Side effects remain behind actors or service protocols. Values crossing an actor boundary are `Sendable`; Views observe state but do not own process, filesystem, network, Keychain, provider, or update side effects. A protocol-backed clock, filesystem, process client, network client, and credential client must be injectable wherever this ADR requires deterministic branches.

### Inputs and outputs

Inputs are validated at the boundary and revalidated immediately before an irreversible or externally visible commit. Outputs contain typed success, partial success, failure, cancellation, and recovery information. Raw framework errors are wrapped into the stable domain error contract before reaching feature state.

### State transitions

The canonical state machine for this ADR must be written as an exhaustive enum or equivalent typed contract. Boolean flags are not sufficient when the transcript distinguishes loading, ready, stale, partial, permission, repair, cancellation, rollback, or unknown states. Every transition has an initiating action, guard, visible result, persistence effect, cleanup, and recovery action.

### Persistence or wire shape

Persist only durable user intent, identity, provenance, operation checkpoints, and artifact evidence required by this ADR. Do not persist live process handles, secrets, unverifiable readiness, or simulated guide mutations as if they were real. JSON examples and migration rules belong in ADR-0005 and the relevant Phase file; this ADR references them rather than redefining ownership.

### Concrete wire examples

The wire object is flat at the document boundary: `documentType` is a string, `schemaVersion` is an integer, and typed payload fields are expanded into the same object. There is no extra `payload` key.

#### `server-index`

```json
{
  "documentType": "server-index",
  "entries": [
    { "id": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa" },
    { "id": "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb" }
  ],
  "schemaVersion": 1
}
```

`entries` owns identity and display order only. Name, group, path, and runtime configuration are not copied into the index.

#### `server-metadata` with an unknown nested field

```json
{
  "documentType": "server-metadata",
  "identity": {
    "displayName": "Example Server",
    "id": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
  },
  "profileTemplateID": null,
  "provenance": {
    "observedAt": "2026-09-15T00:00:00Z",
    "safeSourceReference": "manual-import",
    "source": "userCreated",
    "verification": "verified",
    "verifiedAt": "2026-09-15T00:00:00Z"
  },
  "policies": {},
  "runtimeConfiguration": {
    "futureRuntimeOption": { "mode": "preserve" },
    "javaSelection": { "kind": "systemDefault" },
    "jarFileName": "server.jar",
    "jvmArguments": {
      "raw": "-Xmx2G",
      "validatedTokens": ["-Xmx2G"],
      "validation": "valid"
    },
    "memoryMiB": 2048,
    "eulaAccepted": true
  },
  "schemaVersion": 1,
  "timestamps": {
    "configurationChangedAt": "2026-09-15T00:00:00Z",
    "lastVerifiedAt": "2026-09-15T00:00:00Z",
    "registeredAt": "2026-09-15T00:00:00Z"
  }
}
```

The `futureRuntimeOption` object is retained as a raw unknown field and is merged back into the same nested object on a subsequent save. The example uses an abbreviated `policies` object for readability; a persisted document must contain the validated typed policy sections.

#### Migration revision before and after

```json
// before
{ "documentType": "server-metadata", "name": "legacy", "schemaVersion": 1 }
```

```json
// after
{ "documentType": "server-metadata", "marker": "migrated", "name": "legacy", "schemaVersion": 2 }
```

Before replacement, the revision-1 bytes are copied to a managed recovery path. Each migration step must emit its declared next revision, and the final document is decoded, validated, read back, and atomically replaced.

#### Quarantine and Last Known Good recovery reference

```json
{
  "detectedAt": "2026-09-15T00:00:00Z",
  "detectedRevision": 1,
  "documentType": "server-metadata",
  "id": "cccccccc-cccc-4ccc-8ccc-cccccccccccc",
  "issueCode": "document.invalid",
  "path": ["quarantine", "documents", "server-metadata-cccccccc-cccc-4ccc-8ccc-cccccccccccc.json"]
}
```

The recovery UI may present a candidate such as `quarantine/migration-backups/server-metadata-<operation-id>.json`, but restoration requires an explicit confirmation carrying the selected candidate ID. A candidate is never restored automatically; a confirmed restore uses the ordinary atomic save path.

### Failure handling

Every failure path must identify whether the operation is retryable, cancellable, recoverable, partially successful, or terminal. Missing evidence, invalid input, incompatible artifacts, permission failure, stale selection, external change, timeout, and cancellation are distinct outcomes where the transcript requires them.

### Rollback and recovery

An operation that stages multiple mutations must state what is restored on failure, what remains intentionally persisted, and what the user can retry. Recovery actions must be explicit in the UI and recorded in the operation/evidence trace. No automatic restart, background helper, secret disclosure, or unsafe fallback may be introduced merely to make a happy path appear complete.

### Swift implementation examples

The implementation should use small typed contracts rather than large View models. A representative shape is:

```swift
struct OperationResult<Value: Sendable>: Sendable {
    let value: Value?
    let outcome: Outcome
    let recovery: RecoveryAction?
}

enum Outcome: Sendable {
    case success, partial, cancelled, failed
}
```

This is a design example, not a claim that this exact code already exists. The concrete types must be reconciled with the target graph and domain contracts before implementation.

## Test and acceptance contract

Cover schema versions, unknown fields, malformed JSON, missing fields, migration interruption, rollback, quarantine, atomic replacement, permission failure, symlink escape, archive traversal, Keychain redaction, and Debug/Release root isolation.

A unit test proves only the behavior it exercises. Process, filesystem, provider, UI, accessibility, Real App, and Release QA claims require the evidence layer declared in the parity matrix.

## Official and reference sources

[FileManager](https://developer.apple.com/documentation/foundation/filemanager), [FileCoordinator](https://developer.apple.com/documentation/foundation/filecoordinator), [Security Keychain Services](https://developer.apple.com/documentation/security/keychain_services), [Codable](https://developer.apple.com/documentation/swift/codable), and [Defaults](https://github.com/sindresorhus/Defaults).

MC-Vector paths, symbols, test names, and commit references are listed in Phase 00 and the decision ledger. They are facts about the reference implementation, not automatically authoritative over a later explicit safety/platform decision.

## Evidence state

- `DECISION`: see the linked transcript records and effective resolutions above.
- `FACT`: source/official references must be attached by the implementation phase.
- `IMPLEMENTED`: not claimed by this ADR rewrite.
- `VERIFIED`: not claimed by this ADR rewrite unless an existing evidence artifact is linked explicitly.

## Superseded decisions

Repeated IDs and earlier answers remain in the ledger with `SUPERSEDED` or `CLARIFICATION_REQUIRED`. They are not deleted because the reason for the final decision is part of the 28-hour decision history.

## Open or provisional decisions

Any topic that cannot be resolved from the visible transcript, reference facts, or explicit later correction remains `OPEN` or `PROVISIONAL` in the ledger and the canonical Phase file. It must not be silently filled by assistant preference.

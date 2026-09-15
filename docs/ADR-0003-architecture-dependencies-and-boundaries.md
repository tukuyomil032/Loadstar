# ADR-0003: Architecture, SPM Dependencies, and Boundaries

- Status: Accepted for implementation planning; code/evidence status is tracked separately
- Source transcript: `01a0908e-5282-71e2-aaed-82e67c119e45`
- Primary Phase: Phase 02
- Decision authority: visible user decisions and later explicit corrections
- Implementation authority: this ADR plus the canonical Phase file
- Evidence authority: `docs/decision-ledger.md`, `docs/feature-parity-matrix.md`, and linked test/QA artifacts

## Context

The app combines a macOS App host, a substantial domain model, process/filesystem/network effects, native UI, onboarding, Sparkle, and deterministic tests. Side effects in Views would make parity and failure testing unreliable.

## User intent recovered from the transcript

`Package.swift`を依存関係の正本にしつつ、Xcode projectをmacOS App hostとして使う。Apple公式APIを第一選択にし、必要な外部依存だけを導入する。

## Question and answer trace
The raw occurrence-level question, options, answer, classification, and effective resolution remain in `docs/decision-ledger.md`. This table is a navigable responsibility index; it does not replace the occurrence history.
| Question ID | Transcript ordinals | Occurrence states | Effective resolution |
| --- | --- | --- | --- |
| `dependency_policy` | 587 | `DECIDED` | Sparkle・Defaultsを基準に最小限 |
| `loadstar_license_choice` | 4367 | `DECIDED` | GPLv3で公開（推奨） |
| `project_structure` | 270, 10829, 10848 | `SUPERSEDED, DECIDED` | Xcode App target + Local Swift Package。初期のApp + Swift Packageという方向を、後続質問でXcode側のApp hostとPackage.swift側のLocal Packageへ具体化した。 |
| `runtime_event_backpressure` | 9405 | `DECIDED` | bounded＋drop通知（推奨） |
| `runtime_event_transport` | 9397 | `DECIDED` | typed AsyncStream（推奨） |
| `spm_dependency_policy` | 9364 | `DECIDED` | 範囲＋lockfile（推奨） |
| `state_architecture` | 784 | `DECIDED` | Observation + Swift Concurrency |
| `sttextview_license` | 4346 | `DECIDED` | GPLで公開すればOSSで配布できるって理解で合ってる？<br>homebrewでインストールは関係あんの？それライセンスに |
| `swift_concurrency_mode` | 9356 | `DECIDED` | Swift 6厳格化（推奨） |
| `swift_markdown_role` | 4232 | `PROVISIONAL` | The user requested an investigation of Swift-Markdown or alternatives. Do not add a dependency or claim a final role until the dependency review is completed. |
| `swift_package_dependency_direction` | 3026 | `DECIDED` | Appで注入 (Recommended) |
| `swift_package_module_strategy` | 3016 | `DECIDED` | 層＋feature集約 (Recommended) |
| `swift_package_ui_placement` | 3034 | `DECIDED` | 共有UIを独立化 (Recommended) |
| `swift_toolchain_policy` | 9372 | `DECIDED` | Swift 6下限＋CI固定（推奨） |
| `target_structure` | 3406 | `DECIDED` | Xcodeの`LoadStar` App targetをhostとし、`Package.swift`は`LoadStarDomain`、`LoadStarPersistence`、`LoadStarPlatform`、`LoadStarServices`、`LoadStarFeatures`、`LoadStarUI`、`LoadStarGuide`の7 library targetを管理する。`LoadStarApp`のSPM targetは追加しない。 |
| `ui_architecture` | 549 | `DECIDED` | SwiftUI-first + AppKit |

## Decision

- Use an Xcode `LoadStar` App target plus a local Swift Package defined by `Package.swift`.
- Keep `Package.resolved` reproducible.
- Keep the eight-layer boundary: the Xcode `LoadStar` App host plus the seven SwiftPM library targets `LoadStarDomain`, `LoadStarPersistence`, `LoadStarPlatform`, `LoadStarServices`, `LoadStarFeatures`, `LoadStarUI`, and `LoadStarGuide`.
- Do not add a `LoadStarApp` SwiftPM target; bundle-specific composition remains owned by the Xcode App host.
- Use Swift 6 strict concurrency, Observation, actors, typed errors, and Foundation.
- Require Sparkle, Defaults, and STTextView; do not introduce TourKit.
- Treat OpenSwiftUIAnimation and AwesomeSwift as references unless a later ADR explicitly adopts them.
- Keep process, filesystem, network, Keychain, update, and fixture effects behind services or actors.
- Do not let a feature View call a process or filesystem API directly.

## Why this decision was made

The App target must own bundle-specific concerns such as scenes, Info.plist, Sparkle embedding, archives, and universal builds. The Package must own reusable behavior and tests. Separating effects from Views lets the same contract run against real services, deterministic fixtures, and failure injectors.

## Rejected, superseded, or clarification-only alternatives

- SwiftPM executable only — rejected because the macOS App bundle, scenes, Sparkle integration, and archive responsibilities would be recreated manually.
- Xcode project-only dependency management — rejected because the user explicitly requested Package.swift as dependency authority.
- TCA or a broad utility package — not adopted because no transcript decision required it and Apple Observation/Concurrency cover the selected state model.

## Implementation contract

### Modules and ownership

The App target composes `LoadStarDomain`, `LoadStarPersistence`, `LoadStarPlatform`, `LoadStarServices`, `LoadStarFeatures`, `LoadStarUI`, and `LoadStarGuide`. `Package.swift` is the dependency authority for those seven library targets. Domain imports no UI or platform implementation. Features depend on protocols, not concrete process or filesystem types. `swift-markdown` remains `PROVISIONAL` and is deferred to the Phase 06 editor design.

### Types and protocols

Use protocols such as `ProcessClient`, `FileSystemClient`, `JavaRuntimeProvider`, `KeychainClient`, `ProviderClient`, `UpdateClient`, and `Clock`. Use `Sendable` value types across actor boundaries and typed `LoadStarError` cases with stable codes.

### Actors and concurrency boundaries

Side effects remain behind actors or service protocols. Values crossing an actor boundary are `Sendable`; Views observe state but do not own process, filesystem, network, Keychain, provider, or update side effects. A protocol-backed clock, filesystem, process client, network client, and credential client must be injectable wherever this ADR requires deterministic branches.

### Inputs and outputs

Inputs are validated at the boundary and revalidated immediately before an irreversible or externally visible commit. Outputs contain typed success, partial success, failure, cancellation, and recovery information. Raw framework errors are wrapped into the stable domain error contract before reaching feature state.

### State transitions

The canonical state machine for this ADR must be written as an exhaustive enum or equivalent typed contract. Boolean flags are not sufficient when the transcript distinguishes loading, ready, stale, partial, permission, repair, cancellation, rollback, or unknown states. Every transition has an initiating action, guard, visible result, persistence effect, cleanup, and recovery action.

### Persistence or wire shape

Persist only durable user intent, identity, provenance, operation checkpoints, and artifact evidence required by this ADR. Do not persist live process handles, secrets, unverifiable readiness, or simulated guide mutations as if they were real. JSON examples and migration rules belong in ADR-0005 and the relevant Phase file; this ADR references them rather than redefining ownership.

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

Run Swift package manifest/resolve checks, target dependency checks, strict-concurrency diagnostics, service contract tests, fixture tests, and App-host smoke builds.

A unit test proves only the behavior it exercises. Process, filesystem, provider, UI, accessibility, Real App, and Release QA claims require the evidence layer declared in the parity matrix.

## Official and reference sources

[Swift Package Manager PackageDescription](https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html), [Observation](https://developer.apple.com/documentation/observation), [Swift Concurrency](https://developer.apple.com/documentation/swift/concurrency), [Sparkle](https://sparkle-project.org/documentation/), [Defaults](https://github.com/sindresorhus/Defaults), and [STTextView](https://github.com/krzyzanowskim/STTextView).

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

# ADR-0016: Tooling, Scripts, CI, and Build Boundaries

- Status: Accepted
- Date: 2026-09-14
- Supersedes: ADR-0014, ADR-0042 tooling parts
- Related: ADR-0003, ADR-0015, ADR-0017

## Context

The repository must be reproducible without hiding checks in ad-hoc commands.

## Decision

- Package.swift owns dependencies and Package.resolved is committed.
- Shell is the default scripting language for local build, test, Debug bundle ID launch, and release preparation. Local release preparation prompts for the intended version, updates ignored version.env, and prints/copies a CHANGELOG-only stage-and-commit command without performing Git mutations. GitHub Actions keeps its build, test, Release, Appcast, and artifact commands inline instead of calling repository scripts.
- Lefthook pre-commit runs SwiftLint and SwiftFormat.
- GitHub Actions has separate CI, Test, and Release workflows. CI and Test do not read version.env; Release requires the final committed version.env.
- CI and Test use explicit `paths` filters for Swift sources, Swift tests, package manifests/lockfiles, the Xcode project where applicable, and their own workflow files. Documentation-only, README-only, script-only, and version.env-only branch changes do not start those workflows.
- Release remains tag-driven (`v*`) with explicit `workflow_dispatch`. GitHub does not evaluate path filters for tag pushes, so Release validates tracked `version.env` and its exact version/tag match inside the workflow instead of adding a branch `version.env` trigger that would start a non-release run without a tag.
- CI is noninteractive: Swift checks, a direct xcodebuild smoke build, and universal verification. Intel/device/manual/release are separate evidence layers. Workflow shell uses portable system tools such as grep, awk, and sed rather than rg.
- App Sandbox is disabled initially because managed-server/process/file boundaries need independent controls; path, Keychain, process, and permission boundaries remain mandatory.
- Debug never writes production state and uses com.tukuyomi032.loadstar.debug.

## Consequences

The toolchain stays small and inspectable, while disabled sandbox increases the need for defense-in-depth tests.

## Verification

Local Phase 01 evidence: `just lint`, `just test`, `just build`, `just build-release`, universal binary inspection, Debug/Release bundle-ID checks, native Settings launch, and Dashboard empty-state launch pass. The interactive release preparation flow also passes in a temporary clone. Hosted CI and Test use direct commands and do not call the local scripts.

- HOSTED-CI: run `34832852098` passed all direct quality, SwiftPM, Xcode Debug build, Bundle ID, and universal-binary steps at commit `342bbe4`.
- HOSTED-TEST: run `34832852113` passed `swift package resolve` and `swift test --parallel` at commit `342bbe4`.
- REAL-APP: the generated Debug app launched successfully and was terminated after process verification.

Clean-checkout, hosted CI, and Release workflow evidence remain deferred to their respective gates.

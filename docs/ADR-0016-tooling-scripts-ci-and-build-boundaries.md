# ADR-0016: Tooling, Scripts, CI, and Build Boundaries

- Status: Accepted
- Date: 2026-09-14
- Supersedes: ADR-0014, ADR-0042 tooling parts
- Related: ADR-0003, ADR-0015, ADR-0017

## Context

The repository must be reproducible without hiding checks in ad-hoc commands.

## Decision

- Package.swift owns dependencies and Package.resolved is committed.
- Shell is the default scripting language for local build, test, Debug bundle ID launch, and release preparation. GitHub Actions keeps its build, test, Release, Appcast, and artifact commands inline instead of calling repository scripts.
- Lefthook pre-commit runs SwiftLint and SwiftFormat.
- GitHub Actions has separate CI, Test, and Release workflows. CI and Test do not read version.env; Release requires the final committed version.env.
- CI is noninteractive: Swift checks, a direct xcodebuild smoke build, and universal verification. Intel/device/manual/release are separate evidence layers. Workflow shell uses portable system tools such as grep, awk, and sed rather than rg.
- App Sandbox is disabled initially because managed-server/process/file boundaries need independent controls; path, Keychain, process, and permission boundaries remain mandatory.
- Debug never writes production state and uses com.tukuyomi032.loadstar.debug.

## Consequences

The toolchain stays small and inspectable, while disabled sandbox increases the need for defense-in-depth tests.

## Verification

Local Phase 01 evidence: `just lint`, `just test`, `just build`, `just build-release`, universal binary inspection, Debug/Release bundle-ID checks, native Settings launch, and Dashboard empty-state launch pass. Hosted CI and Test use direct commands and do not call the local scripts.

Clean-checkout, hosted CI, and Release workflow evidence remain deferred to their respective gates.

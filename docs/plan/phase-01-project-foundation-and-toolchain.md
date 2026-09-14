# Phase 01: Project Foundation and Toolchain

- Status: Complete
- Depends on: Phase 00
- ADRs: ADR-0002, ADR-0003, ADR-0016

## Goal

Create the native Swift package, identity, dependency lock, scripts, hooks, and CI boundary.

## Tasks

- [x] Create seven library SPM targets and dependency direction; the App target remains hosted by Xcode.
- [x] Add Sparkle, Defaults, STTextView, and Package.resolved.
- [x] Configure Swift 6, String Catalog, SwiftLint, SwiftFormat, and Lefthook.
- [x] Add local version.env, build/test/Debug-run scripts, and bundle-ID isolation; version.env remains uncommitted during normal development.
- [x] Add direct-command CI and Test workflows; repository scripts remain local-only.
- [x] Verify arm64, x86_64, and universal output locally.
- [x] Verify a clean checkout and hosted CI/Test execution.

## Exit criteria

Local Xcode and SwiftPM builds, checks, Debug isolation, app launch, and hosted CI/Test execution pass. Feature behavior, manual screen QA, and release-runtime evidence remain in their later phases.

## Evidence

- LOCAL-TEST: `swift package dump-package`, `swift package resolve`, `swift build`, `swift test --parallel`, `just lint`, `just test`, `just build`, and `just build-release` passed.
- LOCAL-TEST: Debug and Release bundle identifiers were verified as `com.tukuyomi032.loadstar.debug` and `com.tukuyomi032.loadstar`; the Debug executable was verified as a universal `x86_64 arm64` binary.
- REAL-APP: the generated Debug `LoadStar.app` launched successfully and the test instance was terminated after process verification.
- HOSTED-CI: GitHub Actions CI run `34832852098` passed at commit `342bbe4`.
- HOSTED-TEST: GitHub Actions Test run `34832852113` passed at commit `342bbe4`.
- DEFERRED: feature implementation, manual accessibility/screen QA, and actual Sparkle/DMG/Homebrew publication remain later-phase gates.

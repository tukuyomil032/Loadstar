# Phase 01: Project Foundation and Toolchain

- Status: In progress (local implementation complete; clean-checkout and hosted CI evidence pending)
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
- [ ] Verify a clean checkout and hosted CI/Test execution.

## Exit criteria

Local Xcode and SwiftPM builds, checks, Debug isolation, and app launch pass. Clean-checkout and hosted-CI evidence remain as the next gate.

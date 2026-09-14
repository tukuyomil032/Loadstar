# Phase 08: Updates, Release, and Homebrew

- Status: Tooling scaffolded; feature integration and hosted Release evidence pending
- Depends on: Phase 01, Phase 04
- ADRs: ADR-0015, ADR-0016

## Goal

Implement reproducible Stable/Beta release preparation, Sparkle, Appcast, DMG, and Homebrew.

## Tasks

- [x] Implement local version.env validation and Release preparation without README or version.env mutation; commit/tag/push remain user-controlled.
- [ ] Implement Conventional Commit grouping and update-screen notes.
- [ ] Implement Sparkle Ed25519, one Appcast, channel filtering, validation, and fail-closed updates.
- [ ] Implement canonical universal DMG naming and hash propagation.
- [x] Define the direct-command Release workflow, duplicate cancellation, and Stable-only cask update boundary.
- [ ] Verify no notarization or stapling.

## Exit criteria

The same DMG is traceable through GitHub Release, Sparkle, and Homebrew.

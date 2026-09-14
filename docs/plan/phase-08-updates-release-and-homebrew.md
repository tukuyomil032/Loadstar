# Phase 08: Updates, Release, and Homebrew

- Status: Local release tooling and hosted workflow scaffold complete; app update integration and hosted Release evidence pending
- Depends on: Phase 01, Phase 04
- ADRs: ADR-0015, ADR-0016

## Goal

Implement reproducible Stable/Beta release preparation, Sparkle, Appcast, DMG, and Homebrew.

## Tasks

- [x] Implement interactive local version input, ignored version.env update, Changelog/release-note generation, and a clipboard-ready CHANGELOG-only stage-and-commit command; commit/tag/push remain user-controlled.
- [x] Implement Conventional Commit grouping for local and hosted release notes.
- [ ] Integrate the same release notes into the in-app update screen.
- [ ] Implement Sparkle Ed25519, one Appcast, channel filtering, validation, and fail-closed updates.
- [x] Implement canonical universal DMG naming and hash propagation in the direct Release workflow.
- [x] Define the direct-command Release workflow, duplicate cancellation, and Stable-only cask update boundary.
- [x] Verify statically that the direct Release workflow contains no notarization or stapling commands.

## Exit criteria

The same DMG is traceable through GitHub Release, Sparkle, and Homebrew.

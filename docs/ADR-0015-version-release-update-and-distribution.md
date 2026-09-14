# ADR-0015: Version, Release, Updates, and Distribution

- Status: Accepted
- Date: 2026-09-14
- Supersedes: ADR-0013, ADR-0027, ADR-0035
- Related: ADR-0016, ADR-0017

## Context

Version, tags, GitHub Releases, Sparkle, Appcast, DMG, and Homebrew must identify one artifact while Stable and Beta remain distinct.

## Decision

- version.env is ignored local release metadata, initially VERSION=1.0.0 and BUILD_NUMBER=1. The local release preparation command prompts for the release version before reading the existing metadata, so a stale manually edited VERSION cannot silently select the release. The entered version is normalized and written back to version.env; changing the version advances BUILD_NUMBER, while repeating the current version reuses it.
- First Stable is v1.0.0. Stable uses three components; Beta uses 1.0.1-beta.1. Normalize leading v and two-component stable input.
- BUILD_NUMBER is one monotonic sequence across Stable and Beta; rerun same prepared version reuses it.
- Local just release and just release-prepare call scripts/release.sh. `prepare` updates only local ignored version.env, CHANGELOG.md, and build/release-notes.md; it never updates README, commits, tags, or pushes.
- `prepare` prints a stage-and-commit command for CHANGELOG.md and copies that command with macOS pbcopy when available. version.env is explicitly excluded from that command; only the user may force-add it for the final v1.0 release.
- Conventional Commit changelog groups feat as Features, fix as Bug Fixes, others as Chore. English source, useful metadata retained, automation noise filtered, same-base Beta folded into Stable.
- Update UI and GitHub Release show Features and Bug Fixes. Notes are embedded in Appcast; app does not call GitHub API.
- Sparkle uses Ed25519; public key is embedded and private key is a GitHub secret.
- One appcast.xml is published at fixed GitHub Pages URL. Stable has no channel; Beta has beta and accepts beta plus default. XML/signature failures fail closed.
- DMG is LoadStar-v<version>.dmg and its SHA-256 is shared by Release, Sparkle, and Homebrew.
- Homebrew uses tukuyomil032/homebrew-tap, one universal Stable cask loadstar, auto_updates true, no loadstar@latest, and no Beta cask.
- GitHub Actions owns the hosted Release flow and does not call repository scripts. No notarization or stapling. Duplicate/inconsistent release state cancels; same-commit failure may retry before a Release is published.

## Consequences

Release automation is strict and cancels rather than producing a misleading green no-op.

## Verification

- LOCAL-TEST: `scripts/release.sh check` validates the current ignored metadata and duplicate-release state without changing files.
- LOCAL-TEST: interactive `prepare` was exercised in a temporary clone; entered `v1.0.1` produced `version.env` `VERSION=1.0.1` and `BUILD_NUMBER=2`, a versioned Changelog entry, release notes, and an unstaged `git add -- CHANGELOG.md && git commit ...` command.
- DEFERRED: Sparkle signature, Appcast publication, DMG hash propagation, Homebrew update, and final tag/release evidence require the later Release gate and configured secrets.

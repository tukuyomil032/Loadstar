# ADR-0009: Plugins, Mods, Providers, and Artifact Trust

- Status: Accepted
- Date: 2026-09-14
- Supersedes: ADR-0022, ADR-0030, ADR-0038
- Related: ADR-0005, ADR-0008

## Context

Third-party artifacts vary by provider, version, loader, filename, and checksum; guessing identity is unsafe.

## Decision

- Use Modrinth, Hangar, and Spigot in-app.
- Keep CurseForge external-only until formally approved API/key integration; no scraping or private endpoints.
- Default to latest compatible version. Manual selector lists only compatibility-confirmed versions.
- Unknown or incompatible candidates cannot be selected.
- Prefer SHA-256; missing, malformed, or mismatched checksums fail closed.
- Dependencies are explicit: successful dependencies remain while a failed main artifact stops; failed dependencies are retryable.
- Reuse compatible artifacts. Old or different artifacts require confirmation and backup when applicable.
- Managed-area provenance is canonical; strict filename is fallback.
- Do not integrate or auto-enable .jar.disabled. Clean temporary files on cancellation.

## Consequences

Provider success is not equivalent to a trusted installable artifact.

## Verification

Provider, malformed metadata, retry, checksum, dependency partial-success, cancellation, and provenance tests pass.

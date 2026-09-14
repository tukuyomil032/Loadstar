# ADR-0012: Proxy Matrix, Forwarding, and Provider Artifacts

- Status: Accepted
- Date: 2026-09-14
- Supersedes: ADR-0026, ADR-0033, ADR-0037
- Related: ADR-0005, ADR-0009, ADR-0010

## Context

Proxy setup changes multiple servers and artifacts, and unknown compatibility is unsafe.

## Decision

- Bundled rows are exact and include source, version, artifact, checksum, config path, managed key, and compatibility.
- Unknown combinations reject before writes. Zero backends reject; one warns and requires confirmation.
- Backend ports start at 25566 and skip conflicts. Listener defaults to 25565 and does not auto-change. Bind 0.0.0.0 warns; backend bind remains 127.0.0.1.
- Use modern forwarding only when all backends support it. Any legacy backend makes the whole network legacy with a warning. No common mode rejects.
- Detect BungeeGuard through existing plugin.yml first. Disabled JARs are not integrated.
- Forwarding mods require exact source, version, loader, Minecraft version, filename, and checksum. Compatible artifacts are reused; old/different ones need confirmation and backup.
- Velocity secret and BungeeGuard token are separate. Reuse valid same-network values; regenerate missing, invalid, or unsafe values.
- Use native save panel, generated targets only, atomic write, adjacent backup, rollback, and no auto-register/start. Setup Markdown is secret-free. Waterfall is an explicit warned row.

## Consequences

The artifact matrix is a maintained product asset, not a runtime guess.

## Verification

Exact-row fixtures or official sources, generated-file diff, port, secret, rollback, and full-network acceptance tests pass.

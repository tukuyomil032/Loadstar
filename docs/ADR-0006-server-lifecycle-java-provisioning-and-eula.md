# ADR-0006: Server Lifecycle, Java, Provisioning, and EULA

- Status: Accepted
- Date: 2026-09-14
- Supersedes: ADR-0010, ADR-0028, ADR-0041 server/process parts
- Related: ADR-0005, ADR-0008, ADR-0011, ADR-0013

## Context

Starting a server is a staged operation; process existence and Minecraft readiness are different facts.

## Decision

- Default to system Java; support managed Java 8/17/21 and an explicit custom executable.
- Validate JVM arguments as tokens with a maximum of 32 and revalidate before spawn.
- Support Paper, LeafMC, Vanilla, and Fabric through version, loader, artifact, and checksum verification.
- Roll back failed download, checksum, or staging operations without active metadata.
- Import needs a JAR or staged copy. Unsupported types may register but cannot start.
- Duplicate registration creates a new UUID and distinct path.
- EULA acceptance is explicit; no background auto-accept.
- Manage the child as a process group. Quit stops, waits 30 seconds, then offers force or cancel.
- Never auto-adopt or reconnect to an unknown process.
- running means process exists; ready means SLP succeeds. SLP failure does not crash or stop a running process.
- Defaults: auto-restart off, max 3 attempts, delay 5 minutes; auto-backup off, 60 minutes, 03:00, weekday 0, retention 0; safe backup before restart on.

## Consequences

The UI must not call a spawned process fully ready without SLP evidence.

## Verification

Fixture server, process-group, Java, EULA, SLP timeout, force, and rollback tests pass.

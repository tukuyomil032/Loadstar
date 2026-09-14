# ADR-0010: Users, Permission Lists, Network, and ngrok

- Status: Accepted
- Date: 2026-09-14
- Supersedes: ADR-0012 user/network parts, ADR-0021, ADR-0025 ngrok parts
- Related: ADR-0005, ADR-0006, ADR-0011

## Context

Operator lists, permissions, external connectivity, and ngrok have different sources of truth.

## Decision

- Support four JSON user/permission lists. JSON is local truth; online commands reconcile the server.
- Mojang UUID lookup is optional; unknown users may remain unconfirmed.
- Serialize sends, coalesce when safe, and expose queued/unconfirmed/confirmed states.
- Use a managed ngrok binary and Keychain token.
- ngrok starts online-only, stops with the server, and never silently reconnects.
- Do not expose remote proxy backends; backend addresses remain 127.0.0.1.
- Validate ports, bind addresses, secrets, and process state immediately before network commit.

## Consequences

The UI distinguishes local intent, command delivery, and observed connectivity.

## Verification

List, queue, UUID failure, Keychain, ngrok lifecycle, offline, and stop tests pass.

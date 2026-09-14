# ADR-0013: Operations, Recovery, History, and Automation

- Status: Accepted
- Date: 2026-09-14
- Supersedes: ADR-0029
- Related: ADR-0006, ADR-0008, ADR-0014

## Context

Long-running actions need progress, cancellation, recovery, and bounded history without an invisible daemon.

## Decision

- Restart always asks for confirmation and never auto-resumes.
- Persist latest operation snapshot plus safe checkpoint, not event sourcing.
- Cancellation is stage-aware; completed safe stages remain and unsafe stages roll back or finish by contract.
- Retain history 30 days and 200 entries. Orphans and mismatches need confirmation to repair.
- Automation runs only while app is running. No LaunchAgent, helper, daemon, or hidden reconnect.
- Missed schedules are skipped; Foundation Calendar handles DST.
- Quit follows process stop and reports operations that cannot safely finish.
- Partial success is explicit; retry failed items only unless full retry is chosen.

## Consequences

Each operation defines its checkpoint and rollback semantics.

## Verification

State-machine, interruption, cancellation, orphan, retention, DST, and quit tests pass.

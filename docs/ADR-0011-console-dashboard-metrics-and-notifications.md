# ADR-0011: Console, Dashboard, Metrics, and Notifications

- Status: Accepted
- Date: 2026-09-14
- Supersedes: ADR-0023, ADR-0024
- Related: ADR-0006, ADR-0010, ADR-0014

## Context

Live console and dashboard must remain bounded and honest about unavailable data.

## Decision

- Display stdout in console; keep stderr diagnostic-only. Replace invalid UTF-8.
- Retain at most 2,000 lines. Support basic ANSI, severity, regex search, filtered export, and five session pins.
- Keep up to 100 commands per server and validate stdin.
- Refresh metrics every 60 seconds; sample Paper/Leaf TPS every 5 seconds.
- Use TPS thresholds 18 and 15 and Swift Charts.
- High CPU notifications are off by default with five-minute cooldown per server/session.
- Uptime is unknown after app restart until a new interval is observed.
- Request notification permission just before the first actual notification. Denial suppresses repeated prompts; explicit retry is available.
- Distinguish process, SLP, metrics, and unavailable states.

## Consequences

The console remains bounded and the dashboard never fabricates readiness, metrics, or uptime.

## Verification

Log, ANSI, encoding, command, history, metrics, chart, cooldown, and permission tests pass.

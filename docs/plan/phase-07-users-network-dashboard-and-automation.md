# Phase 07: Users, Network, Dashboard, and Automation

- Status: Planned
- Depends on: Phase 03, Phase 04, Phase 05
- ADRs: ADR-0010, ADR-0011, ADR-0013

## Goal

Implement users, console, metrics, dashboard, notifications, ngrok, and app-running automation.

## Tasks

- [ ] Implement JSON-first lists, UUID lookup, command queue, confirmation, and reconciliation.
- [ ] Implement bounded console, ANSI/severity/search/export/pins/history, and stdin validation.
- [ ] Implement metrics, Paper/Leaf TPS, Swift Charts, unavailable states, and CPU cooldown.
- [ ] Implement notification permission denial/retry and redaction.
- [ ] Implement Keychain-backed ngrok lifecycle and Calendar/DST automation.
- [ ] Verify no hidden daemon, reconnect, or auto-resume.

## Exit criteria

Runtime displays distinguish process, readiness, metrics, and notification states.

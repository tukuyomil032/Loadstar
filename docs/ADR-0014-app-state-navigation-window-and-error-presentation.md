# ADR-0014: App State, Navigation, Windows, Screen State, and Errors

- Status: Accepted
- Date: 2026-09-14
- Supersedes: ADR-0016, ADR-0032, ADR-0040
- Related: ADR-0004, ADR-0005, ADR-0013

## Context

Main, Settings, Guide, and utility windows need predictable restoration and redacted diagnostics.

## Decision

- Main is singleton; Settings uses native scene; Guide and utility windows are one per kind.
- Persist and restore Main frame only. Do not auto-open auxiliary windows or persist their frames.
- Startup opens Dashboard. Restore valid selected server/sidebar; preserve invalid selection as repair state.
- All screens expose loading, ready, empty, stale, partial, permission, and repair states, with explicit exceptions.
- Refresh keeps useful view state. File reload keeps view and locks mutations during reconciliation.
- Provider partial success keeps successes and retries failures.
- Use stable lowerCamel dotted error codes such as server.start.eulaRequired and a Domain registry for classification, localization, recovery, and redaction.
- Normal errors show overview, reason, and recovery. Detail/copy explicitly reveals redacted diagnostics.
- Focus, announcements, keyboard, IDs, rotor, and Reduce Motion are screen-contract requirements.

## Consequences

The UI does not erase user intent during partial failure and error copy is a maintained localization surface.

## Verification

State, navigation, window, error registry, redaction, focus, announcement, and partial-success tests pass.

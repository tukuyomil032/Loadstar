# Phase 04: Main UI, Settings, Navigation, and Screen State

- Status: Planned
- Depends on: Phase 02, Phase 03
- ADRs: ADR-0004, ADR-0014

## Goal

Build the native Main, Settings, Guide, window shell, and common screen-state contract.

## Tasks

- [ ] Implement Main singleton, Dashboard startup, sidebar, selection repair, and Main-only frame restore.
- [ ] Implement native Settings, localization, appearance, setup completion, and staged save/cancel.
- [ ] Implement loading, empty, stale, partial, permission, and repair states.
- [ ] Implement semantic IDs, focus, keyboard, VoiceOver, announcements, rotor, Dynamic Type, and Reduce Motion.
- [ ] Implement error registry, redaction, detail/copy, and recovery actions.

## Exit criteria

Every initial screen has a tested state contract and native accessibility behavior.

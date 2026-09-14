# Phase 05: Interactive Onboarding and Guide

- Status: Planned
- Depends on: Phase 03, Phase 04
- ADRs: ADR-0004, ADR-0014

## Goal

Deliver functional first-run Guide and safe demonstration without TourKit or production mutations.

## Tasks

- [ ] Implement Guide target registry, collision handling, resume, close, and conflict revalidation.
- [ ] Implement staging state and explicit commit/cancel boundaries.
- [ ] Add fixture/demo services isolated from production data.
- [ ] Verify Reduce Motion, VoiceOver focus boundary, keyboard navigation, and restart.

## Exit criteria

Guide actions are real, reversible, accessible, and isolated from production data.

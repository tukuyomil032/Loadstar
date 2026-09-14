# ADR-0004: Settings, Onboarding, Guide, and Accessibility

- Status: Accepted
- Date: 2026-09-14
- Supersedes: ADR-0007, ADR-0008, ADR-0009, ADR-0017
- Related: ADR-0002, ADR-0014

## Context

The first-run and help surfaces must be native, functional, accessible, and safe.

## Decision

- Initial setup collects language, appearance, and completion; default is System.
- Support System, Japanese, and English, with unsupported system languages falling back to English.
- Use native Settings sidebar/detail navigation.
- Guide controls use real staging, validation, confirmation, and save/cancel behavior.
- Implement Guide with SwiftUI/AppKit, Observation, and Concurrency; do not introduce TourKit.
- Guide targets have stable IDs and collision handling; Reduce Motion and VoiceOver focus boundaries are respected.
- Every screen defines semantic IDs, focus order, keyboard equivalents, announcements, and rotor behavior where applicable.
- Use SF Symbols for ordinary icons.

## Consequences

Accessibility and semantic state are implemented together with visual layout. Generated images never replace HIG or acceptance criteria.

## Verification

XCTest/XCUITest and manual VoiceOver, keyboard, appearance, Dynamic Type, and Reduce Motion checks cover every screen.

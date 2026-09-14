# ADR-0002: Product Identity, macOS Platform, and Native UI Direction

- Status: Accepted
- Date: 2026-09-14
- Supersedes: ADR-0002, ADR-0003
- Related: ADR-0002, ADR-0003

## Context

The reimplementation is a native macOS product rather than a renamed cross-platform shell.

## Decision

- Product is LoadStar on macOS 26 or later.
- Build universal arm64 and x86_64.
- Production bundle ID is com.tukuyomi032.loadstar; Debug is com.tukuyomi032.loadstar.debug.
- Use SwiftUI first and AppKit only where native macOS behavior or APIs require it.
- Use Swift 6 strict concurrency, Observation, actors, and Foundation.
- Prefer SF Symbols, semantic colors, system controls, Dynamic Type, keyboard navigation, VoiceOver, and Reduce Motion.
- Visualize or image-generation output is direction and annotation only, never a design specification.

## Consequences

Reference visuals may be expressed through different native controls while preserving observable function and state.

## Verification

Universal build and screen-level keyboard, VoiceOver, Dynamic Type, appearance, and Reduce Motion checks pass.

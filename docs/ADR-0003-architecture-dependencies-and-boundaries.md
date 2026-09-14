# ADR-0003: Architecture, SPM Dependencies, and Boundaries

- Status: Accepted
- Date: 2026-09-14
- Supersedes: ADR-0004, ADR-0018, ADR-0042
- Related: ADR-0002, ADR-0016

## Context

Side effects must not live in Views, and dependency management must be reproducible.

## Decision

- Use targets LoadStarDomain, LoadStarPersistence, LoadStarPlatform, LoadStarServices, LoadStarFeatures, LoadStarUI, LoadStarGuide, and LoadStarApp.
- Use Package.swift and commit Package.resolved.
- Require Sparkle, Defaults, and STTextView.
- Do not use TourKit. OpenSwiftUIAnimation and AwesomeSwift are reference material unless separately adopted.
- Prefer Apple APIs for process, filesystem, Keychain, networking, charts, localization, accessibility, windows, and updates.
- Put process, filesystem, network, Keychain, and update effects in services or actors.
- Never place secrets in settings JSON, logs, changelogs, appcast notes, or exported setup Markdown.

## Consequences

Explicit boundaries make live-server behavior testable without a live server and keep platform code replaceable.

## Verification

Swift 6 diagnostics, package graph checks, dependency review, and target tests pass.

# ADR-0017: Test Fixtures, Parity Evidence, and Release Readiness

- Status: Accepted
- Date: 2026-09-14
- Supersedes: ADR-0034, ADR-0043
- Related: ADR-0001, ADR-0015, ADR-0016

## Context

Complete parity cannot be proven by one test target; deterministic fixtures and layered evidence are required.

## Decision

- Use targets LoadStarDomainTests, LoadStarPersistenceTests, LoadStarPlatformTests, LoadStarServicesTests, LoadStarFeaturesTests, LoadStarUITests, LoadStarIntegrationTests, LoadStarAcceptanceTests, LoadStarFixtureServer, and LoadStarFixtureProxy.
- Fixtures are state machines with deterministic JSON scenarios. Human logs remain readable; structured events use a normalized typed trace.
- Each matrix row declares applicable domain, filesystem/process, provider fixture, Real App, manual QA, and release QA evidence. Missing applicable evidence is incomplete.
- Compare guard, success, failure, cancel, retry, partial, recovery, persisted result, and user-visible state.
- Acceptance covers the reference baseline and every intentional safety/platform/accessibility deviation.
- Release readiness requires clean build, migrations, process/filesystem/provider/proxy/backup/UI/error tests, Real App, accessibility/native-window QA, universal/hash checks, Sparkle/Appcast/Homebrew verification, and no unresolved high-priority gate or exact artifact row.
- Visualize/image-generation output is direction and annotation only.

## Consequences

Evidence prevents local implementation success from being confused with parity or release readiness.

## Verification

The matrix, fixture output, CI artifacts, Real App logs, manual QA records, and release QA records are linked before the release gate passes.

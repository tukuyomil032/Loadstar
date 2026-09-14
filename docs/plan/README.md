# LoadStar Implementation Plan

The active plan has exactly one file for each phase. Addenda are historical only.

| Phase | File | Purpose |
| --- | --- | --- |
| 00 | phase-00-reference-analysis-and-requirements.md | Reference inventory and requirements |
| 01 | phase-01-project-foundation-and-toolchain.md | SPM, Swift, scripts, CI |
| 02 | phase-02-domain-model-and-persistence.md | Domain, schema, storage, security |
| 03 | phase-03-process-java-and-server-lifecycle.md | Java, process, server lifecycle |
| 04 | phase-04-main-ui-settings-and-navigation.md | Main UI, Settings, state, accessibility |
| 05 | phase-05-interactive-onboarding-sandbox.md | Guide and safe demo |
| 06 | phase-06-files-backups-and-plugins.md | Files, backups, restore, plugins |
| 07 | phase-07-users-network-dashboard-and-automation.md | Users, console, metrics, automation |
| 08 | phase-08-updates-release-and-homebrew.md | Sparkle, release, Homebrew |
| 09 | phase-09-test-qa-and-evidence.md | Tests, fixtures, QA, evidence |
| 10 | phase-10-parity-audit-and-release-readiness.md | Final parity and release gate |

Dependency flow: 00 → 01 → 02 → 03 → 04 → 05, then 06 and 07, then 08 → 09 → 10.

ADRs explain decisions; these files explain implementation order. Do not create a second file for an existing Phase number.

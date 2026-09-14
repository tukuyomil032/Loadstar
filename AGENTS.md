## Repository identity

- The repository directory is `Loadstar/`.
- The Xcode project, scheme, app bundle, and product name are `LoadStar`.
- Production bundle identifier: `com.tukuyomi032.loadstar`.
- Debug bundle identifier: `com.tukuyomi032.loadstar.debug`.
- Deployment target: macOS 26.
- Release builds must support arm64 and x86_64.

## Architecture and implementation

- Prefer Apple SDKs and official Swift, SwiftUI, AppKit, Foundation, OSLog, URLSession, Security, and related APIs before adding third-party dependencies.
- Use SwiftUI first and use AppKit only where the macOS windowing or process model requires it.
- Keep process, filesystem, network, Keychain, update, and other side effects behind services or actors.
- Record the reason and scope in the existing ADR when an external dependency is added.
- Do not invent behavior where the parity matrix or reference inventory is unresolved.

## Source control and versioning

- `version.env` is local release metadata and must not be committed during normal development or any intermediate Phase.
- Only the user may explicitly force-add `version.env` for the final v1.0 release.
- Do not create release tags, GitHub Releases, Homebrew updates, or Sparkle Appcast updates during ordinary feature development.
- Keep commits focused to one task. Commit messages and other repository-facing messages are written in English.
- Do not add `Co-Authored-By` trailers.
- Never use destructive Git commands to discard user changes.

## Local commands

- `just setup` installs Lefthook after required local tools are available.
- `just lint` runs SwiftFormat and SwiftLint.
- `just test` runs the Swift Package tests.
- `just build` and `just build-release` use the local `version.env`.
- `just run` launches the Debug app; Debug must never write production state.
- `just release` performs read-only local release checks.
- `just release-prepare` prompts for the release version, updates ignored local version.env, and prepares the Changelog and release notes without committing, tagging, or pushing.
- Files under `scripts/` are local development and local release-preparation tools only.

## GitHub Actions

- `.github/workflows/ci.yml`, `test.yml`, and `release.yml` run their commands inline; they do not call repository scripts or `just` recipes.
- CI and Test do not read, create, or validate `version.env`.
- Workflow shell must use portable system tools such as `grep`, `awk`, and `sed`; do not depend on `rg` being installed on a runner.
- Release requires a final commit containing tracked `version.env` and a matching `v<version>` tag.
- Duplicate Releases must cancel the workflow rather than produce a successful no-op.
- Release does not notarize or staple the app.

## Documentation and verification

- ADRs explain why; the canonical Phase files explain implementation order and exit criteria.
- Update the existing ADR or Phase file instead of creating duplicate numbered files.
- Keep FACT, DECISION, INFERRED, TEST, REAL-APP, MANUAL-QA, and RELEASE-QA evidence distinct.
- Run the relevant SwiftFormat, SwiftLint, Swift test, Xcode build, shell syntax, shellcheck, and actionlint checks before reporting completion.

# Contributing to LoadStar

Thanks for contributing to LoadStar.

LoadStar is a native macOS application for managing Minecraft servers. It is built with Swift and SwiftUI, targets macOS 26, and uses an Xcode application target alongside Swift Package targets. This guide explains the development workflow and conventions that help contributions stay easy to review.

## Ways to contribute

- Report bugs and unexpected behavior
- Propose features or improvements
- Improve documentation
- Submit focused code changes
- Test changes and share feedback from macOS

## Before you start

- Search existing issues and pull requests before opening a new one.
- For a large change, open an issue first so the problem and proposed direction can be discussed.
- Keep each pull request focused on one problem or feature.
- Read the relevant documentation in [`docs/`](docs/README.md) before changing behavior that is already described there.

## Development setup

### Requirements

- macOS 26 or later
- An Xcode version that supports Swift 6.2 and macOS 26
- Homebrew

The application project is [`LoadStar.xcodeproj`](LoadStar.xcodeproj), and the shared scheme is `LoadStar`.

### Install development tools

Install the tools used by the local checks:

```sh
brew install swiftlint swift-format lefthook xcbeautify just
just setup
```

Resolve Swift Package dependencies before building or testing:

```sh
swift package resolve
```

### Local build metadata

The local build scripts require an ignored `version.env` file containing `VERSION` and `BUILD_NUMBER`, for example:

```text
VERSION=<version>
BUILD_NUMBER=<positive integer>
```

Keep this file local. Do not include it in a normal pull request.

## Project structure

The repository keeps application code in `Loadstar/` and package tests in `Tests/`.

| Path | Responsibility |
| --- | --- |
| `Loadstar/App/` | Application entry point, app state, and dependency composition |
| `Loadstar/Domain/` | Shared domain values and contracts |
| `Loadstar/Persistence/` | Persistence-related package code |
| `Loadstar/Platform/` | macOS and system-platform primitives |
| `Loadstar/Services/` | Process, filesystem, network, credential, update, and other side-effecting services |
| `Loadstar/Features/` | User-facing feature workflows and state |
| `Loadstar/UI/` | SwiftUI views and UI composition |
| `Loadstar/Guide/` | Onboarding and guided-flow behavior |
| `Tests/LoadStar*Tests/` | Domain, persistence, platform, service, feature, UI, integration, and acceptance tests |

Keep feature-specific code close to the feature that owns it. Add shared code to a lower-level module only when it is genuinely shared.

## Local commands

Run commands from the repository root.

| Command | Purpose |
| --- | --- |
| `just lint` | Run SwiftFormat and SwiftLint checks without rewriting files |
| `just test` | Run the Swift Package test suite |
| `just build` | Build the Debug `LoadStar` application |
| `just build-release` | Build the Release `LoadStar` application |
| `just run` | Build and launch the Debug application |
| `just clean` | Remove Swift Package build artifacts from `.build/` |

Open the Xcode project when you need to run or debug application and UI tests that are not covered by the Swift Package command.

## Contribution workflow

1. Search for an existing issue or pull request related to the change.
2. Create a branch from `main` using a descriptive prefix such as `feat/`, `fix/`, `ref/`, `docs/`, `test/`, or `chore/`.
3. Make one focused change and keep unrelated cleanup out of the branch.
4. Add or update tests when behavior changes.
5. Run the relevant local checks and manual verification.
6. Open a pull request using the repository template and describe what you tested.

## Coding guidelines

- Follow the existing Swift and SwiftUI style in the repository.
- Prefer clear, descriptive type and file names.
- Prefer SwiftUI for UI work. Use AppKit when macOS windowing or process behavior requires it.
- Keep process, filesystem, network, Keychain, update, and other side effects behind services or actors.
- Keep changes compatible with the existing module boundaries and dependency direction.
- Avoid unrelated renames, directory moves, and formatting churn.
- Add comments only when the intent cannot be made clear through the code itself.
- Preserve existing user-facing behavior unless the change intentionally modifies it.

## Validation

Before opening a pull request, run the checks relevant to your change. For most code changes, start with:

```sh
just lint
just test
just build
```

If the change affects UI, windows, processes, files, network behavior, credentials, or other macOS-specific behavior, verify it in the running application as well. Include the macOS version, build configuration, steps, and result in the pull request when manual verification is relevant.

For UI changes, attach screenshots or a short recording when they make the result easier to review. Do not describe a check as completed if it was not run; explain any skipped validation instead.

## Commit messages

Use short, imperative commit messages in English. Prefixes such as `feat:`, `fix:`, `ref:`, `docs:`, `test:`, and `chore:` are preferred when they fit the change.

Examples:

- `fix: preserve server selection after refresh`
- `docs: clarify local development setup`
- `test: cover invalid server configuration`

## Security

- Do not include secrets, Keychain values, private paths, credentials, or personal information in issues, pull requests, logs, screenshots, or recordings.
- If a report may reveal a security vulnerability, do not disclose the details in a public issue. Contact the maintainers privately through GitHub instead.

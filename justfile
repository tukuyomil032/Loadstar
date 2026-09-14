# justfile — LoadStar local command runner
# Requires Homebrew tools: brew install swiftlint swift-format lefthook xcbeautify just

# Default: list available commands
default:
    @just --list

# Verify dev tools are available and install git hooks
setup:
    @command -v swiftlint >/dev/null 2>&1 || (echo "Error: swiftlint not found. Run 'brew install swiftlint'." && exit 1)
    @command -v swift-format >/dev/null 2>&1 || (echo "Error: swift-format not found. Run 'brew install swift-format'." && exit 1)
    @command -v lefthook >/dev/null 2>&1 || (echo "Error: lefthook not found. Run 'brew install lefthook'." && exit 1)
    @command -v xcbeautify >/dev/null 2>&1 || (echo "Error: xcbeautify not found. Run 'brew install xcbeautify'." && exit 1)
    lefthook install
    @echo "Dev environment ready. Git hooks installed."

# Build the app (Debug), formatted with xcbeautify
build:
    bash scripts/build.sh

# Build the app (Release)
build-release:
    CONFIG=Release bash scripts/build.sh

# Run all Swift Package tests
test:
    bash scripts/test.sh

# Format Swift files in-place
format:
    swift-format format --recursive --in-place Loadstar/ Tests/

# Lint Swift files (check only, no modification)
lint:
    swift-format lint --recursive Loadstar/ Tests/
    swiftlint lint

# Build (Debug) and run LoadStar
run:
    bash scripts/run.sh

# Same as `run` but Release configuration
run-release:
    CONFIG=Release bash scripts/run.sh

# Validate local release metadata without mutating the repository
release:
    bash scripts/release.sh check

# Prepare local changelog and release notes without committing, tagging, or pushing
release-prepare:
    bash scripts/release.sh prepare

# Remove Swift Package build artifacts
clean:
    rm -rf .build

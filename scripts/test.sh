#!/usr/bin/env bash
# scripts/test.sh — Run the Swift Package test matrix.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TEST_CMD=(swift test)
BUILD_ARGS=()

if [[ "${CONFIG:-Debug}" == "Release" ]]; then
    TEST_CMD+=(--configuration release)
    BUILD_ARGS+=(--configuration release)
fi

if [[ -n "${TEST_FILTER:-}" ]]; then
	TEST_CMD+=(--filter "${TEST_FILTER}")
fi

swift build --product LoadStarFixtureServer "${BUILD_ARGS[@]}"
FIXTURE_BIN_DIR="$(swift build --show-bin-path "${BUILD_ARGS[@]}")"
export LOADSTAR_FIXTURE_SERVER_PATH="${FIXTURE_BIN_DIR}/LoadStarFixtureServer"
"${TEST_CMD[@]}"

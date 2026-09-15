#!/usr/bin/env bash
# scripts/test.sh — Run the Swift Package test matrix.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

TEST_CMD=(swift test)

if [[ "${CONFIG:-Debug}" == "Release" ]]; then
	TEST_CMD+=(--configuration release)
fi

if [[ -n "${TEST_FILTER:-}" ]]; then
	TEST_CMD+=(--filter "${TEST_FILTER}")
fi

"${TEST_CMD[@]}"

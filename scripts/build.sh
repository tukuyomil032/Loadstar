#!/usr/bin/env bash
# scripts/build.sh — Build the LoadStar Xcode application target locally.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="${ROOT_DIR}/LoadStar.xcodeproj"
SCHEME="LoadStar"
CONFIGURATION="${CONFIG:-Debug}"
DESTINATION="platform=macOS"
VERSION_FILE="${ROOT_DIR}/version.env"

if [[ ! -f "${VERSION_FILE}" ]]; then
	printf 'error: %s is required for local builds\n' "${VERSION_FILE}" >&2
	printf 'Create it with VERSION=<version> and BUILD_NUMBER=<integer>.\n' >&2
	exit 1
fi

case "${CONFIGURATION}" in
Debug)
	EXPECTED_BUNDLE_ID="com.tukuyomi032.loadstar.debug"
	;;
Release)
	EXPECTED_BUNDLE_ID="com.tukuyomi032.loadstar"
	;;
*)
	printf 'error: CONFIG must be Debug or Release, got %s\n' "${CONFIGURATION}" >&2
	exit 2
	;;
esac

read_version_value() {
	local key="$1"
	awk -F= -v lookup_key="${key}" '$1 == lookup_key { print $2; exit }' "${VERSION_FILE}"
}

APP_VERSION="$(read_version_value VERSION)"
BUILD_NUMBER="$(read_version_value BUILD_NUMBER)"

if [[ -z "${APP_VERSION}" || -z "${BUILD_NUMBER}" ]]; then
	printf 'error: version.env must define VERSION and BUILD_NUMBER\n' >&2
	exit 1
fi

BUILD_CMD=(
	xcodebuild
	-project "${PROJECT_PATH}"
	-scheme "${SCHEME}"
	-configuration "${CONFIGURATION}"
	-destination "${DESTINATION}"
	ONLY_ACTIVE_ARCH=NO
	ARCHS="arm64 x86_64"
	MARKETING_VERSION="${APP_VERSION}"
	CURRENT_PROJECT_VERSION="${BUILD_NUMBER}"
	CODE_SIGNING_ALLOWED=NO
	CODE_SIGNING_REQUIRED=NO
)

if [[ -n "${DERIVED_DATA_PATH:-}" ]]; then
	BUILD_CMD+=(-derivedDataPath "${DERIVED_DATA_PATH}")
fi

BUILD_CMD+=(build)

if command -v xcbeautify >/dev/null 2>&1; then
	set +e
	"${BUILD_CMD[@]}" 2>&1 | xcbeautify --quiet --renderer terminal
	result_code=${PIPESTATUS[0]}
	set -e
else
	printf 'warning: xcbeautify not found; using raw xcodebuild output\n' >&2
	set +e
	"${BUILD_CMD[@]}"
	result_code=$?
	set -e
fi

if [[ "${result_code}" -ne 0 ]]; then
	exit "${result_code}"
fi

SHOW_SETTINGS_CMD=("${BUILD_CMD[@]:0:${#BUILD_CMD[@]}-1}" -showBuildSettings)
BUILD_SETTINGS="$("${SHOW_SETTINGS_CMD[@]}" 2>/dev/null)"
ACTUAL_BUNDLE_ID="$(printf '%s\n' "${BUILD_SETTINGS}" | awk -F' = ' '/^[[:space:]]+PRODUCT_BUNDLE_IDENTIFIER = / { print $2; exit }')"

if [[ "${ACTUAL_BUNDLE_ID}" != "${EXPECTED_BUNDLE_ID}" ]]; then
	printf 'error: expected bundle identifier %s, got %s\n' "${EXPECTED_BUNDLE_ID}" "${ACTUAL_BUNDLE_ID:-<missing>}" >&2
	exit 1
fi

printf 'Build succeeded: %s %s (%s)\n' "${SCHEME}" "${APP_VERSION}" "${CONFIGURATION}"
printf 'Bundle identifier verified: %s\n' "${ACTUAL_BUNDLE_ID}"

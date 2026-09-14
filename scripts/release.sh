#!/usr/bin/env bash
# scripts/release.sh — Local release metadata and Changelog preparation.
#
# This script is intentionally local-only. GitHub Actions implements its own
# inline release flow and must not call this script.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

VERSION_FILE="${ROOT_DIR}/version.env"
CHANGELOG_FILE="${ROOT_DIR}/CHANGELOG.md"
BUILD_DIR="${BUILD_DIR:-${ROOT_DIR}/build}"
VERSION_FILE_RELATIVE="version.env"

usage() {
    printf '%s\n' \
        'Usage: scripts/release.sh [check|prepare|verify-final]' \
        '' \
        'Modes:' \
        '  check         Validate local release metadata without changing files.' \
        '  prepare       Add a versioned Changelog entry and write release notes.' \
        '  verify-final  Validate a final tag against tracked version.env without publishing.' \
        '' \
        'The script never commits, tags, pushes, creates a GitHub Release, updates' \
        'Homebrew, or publishes a Sparkle Appcast.'
}

die() {
    printf 'error: %s\n' "$1" >&2
    exit 1
}

warn() {
    printf 'warning: %s\n' "$1" >&2
}

read_version_value() {
    local key="$1"
    awk -F= -v lookup_key="${key}" '
        $1 == lookup_key {
            value = $2
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            print value
            exit
        }
    ' "${VERSION_FILE}"
}

require_local_version_file() {
    [[ -f "${VERSION_FILE}" ]] || die "${VERSION_FILE} is required for local release preparation"
    [[ -f "${CHANGELOG_FILE}" ]] || die "${CHANGELOG_FILE} is required"
}

validate_version_values() {
    [[ -n "${APP_VERSION}" ]] || die "version.env must define VERSION"
    [[ "${APP_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] || \
        die "VERSION must be a stable or prerelease semver: ${APP_VERSION}"
    [[ "${BUILD_NUMBER}" =~ ^[1-9][0-9]*$ ]] || \
        die "BUILD_NUMBER must be a positive integer: ${BUILD_NUMBER}"
}

ensure_version_is_not_staged_or_tracked() {
    if git ls-files --error-unmatch "${VERSION_FILE_RELATIVE}" >/dev/null 2>&1; then
        die "version.env is tracked; keep it local until the user authorizes the final v1.0 release"
    fi
    if git diff --cached --name-only | rg -F -x -q "${VERSION_FILE_RELATIVE}"; then
        die "version.env is staged; remove it from the index during normal development"
    fi
}

github_repository() {
    local origin_url repository
    origin_url="$(git config --get remote.origin.url 2>/dev/null || true)"
    repository="${origin_url#https://github.com/}"
    repository="${repository#git@github.com:}"
    repository="${repository%.git}"
    printf '%s\n' "${repository}"
}

check_changelog_shape() {
    rg -F -x -q '## [Unreleased]' "${CHANGELOG_FILE}" || \
        die "CHANGELOG.md must contain exactly the expected Unreleased heading"
}

check_remote_release() {
    local tag="v${APP_VERSION}" repository
    if ! command -v gh >/dev/null 2>&1; then
        warn "gh is not installed; skipped GitHub Release duplicate check"
        return 0
    fi
    repository="$(github_repository)"
    if [[ "${repository}" != */* ]]; then
        warn "Could not determine the GitHub repository; skipped duplicate check"
        return 0
    fi
    if gh release view "${tag}" --repo "${repository}" >/dev/null 2>&1; then
        die "GitHub Release ${tag} already exists"
    fi
}

commit_entries() {
    local pattern="$1"
    git log --format='- %s (%h)' --grep="${pattern}" --extended-regexp HEAD 2>/dev/null \
        | rg -v '^- (chore: (prepare|release|update appcast)|release\()' || true
}

build_release_notes() {
    local features fixes maintenance
    features="$(commit_entries '^feat([(:]|$)')"
    fixes="$(commit_entries '^fix([(:]|$)')"
    maintenance="$(commit_entries '^(chore|refactor|perf|style|ci|docs|build)([(:]|$)')"

    {
        if [[ -n "${features}" ]]; then
            printf '### Features\n\n%s\n\n' "${features}"
        fi
        if [[ -n "${fixes}" ]]; then
            printf '### Bug Fixes\n\n%s\n\n' "${fixes}"
        fi
        if [[ -n "${maintenance}" ]]; then
            printf '### Chore\n\n%s\n\n' "${maintenance}"
        fi
        if [[ -z "${features}${fixes}${maintenance}" ]]; then
            printf '### Changes\n\n- No conventional commit entries were found.\n'
        fi
    } | sed '/^[[:space:]]*$/N;/^\n[[:space:]]*$/D'
}

prepare_changelog() {
    local notes date temporary
    notes="$(build_release_notes)"
    date="$(date +%Y-%m-%d)"
    temporary="$(mktemp "${TMPDIR:-/tmp}/loadstar-changelog.XXXXXX")"

    awk -v version="${APP_VERSION}" -v release_date="${date}" -v notes="${notes}" '
        !inserted && $0 == "## [Unreleased]" {
            print
            print ""
            print "## [" version "] - " release_date
            print ""
            print notes
            inserted = 1
            next
        }
        { print }
    ' "${CHANGELOG_FILE}" > "${temporary}"
    mv "${temporary}" "${CHANGELOG_FILE}"

    mkdir -p "${BUILD_DIR}"
    printf '%s\n' "${notes}" > "${BUILD_DIR}/release-notes.md"
    printf 'Prepared %s and %s\n' "${CHANGELOG_FILE}" "${BUILD_DIR}/release-notes.md"
}

check_local() {
    require_local_version_file
    ensure_version_is_not_staged_or_tracked
    check_changelog_shape
    check_remote_release
    printf 'Local release metadata is valid: v%s (build %s)\n' "${APP_VERSION}" "${BUILD_NUMBER}"
}

verify_final() {
    local tag expected_head actual_head
    require_local_version_file
    validate_version_values
    tag="${TAG:-v${APP_VERSION}}"
    [[ "${tag}" == "v${APP_VERSION}" ]] || die "tag ${tag} does not match version.env VERSION ${APP_VERSION}"
    git ls-files --error-unmatch "${VERSION_FILE_RELATIVE}" >/dev/null 2>&1 || \
        die "final verification requires tracked version.env"
    expected_head="$(git rev-parse "${tag}^{commit}" 2>/dev/null || true)"
    actual_head="$(git rev-parse HEAD)"
    [[ -n "${expected_head}" && "${expected_head}" == "${actual_head}" ]] || \
        die "HEAD must point at tag ${tag} for final verification"
    if command -v gh >/dev/null 2>&1 && gh release view "${tag}" --repo "$(github_repository)" >/dev/null 2>&1; then
        die "GitHub Release ${tag} already exists"
    fi
    printf 'Final release metadata is valid: %s (build %s)\n' "${tag}" "${BUILD_NUMBER}"
}

MODE="${1:-check}"
case "${MODE}" in
    -h|--help)
        usage
        ;;
    check)
        require_local_version_file
        APP_VERSION="$(read_version_value VERSION)"
        BUILD_NUMBER="$(read_version_value BUILD_NUMBER)"
        validate_version_values
        check_local
        ;;
    prepare)
        require_local_version_file
        APP_VERSION="$(read_version_value VERSION)"
        BUILD_NUMBER="$(read_version_value BUILD_NUMBER)"
        validate_version_values
        ensure_version_is_not_staged_or_tracked
        check_changelog_shape
        prepare_changelog
        ;;
    verify-final)
        APP_VERSION="$(read_version_value VERSION 2>/dev/null || true)"
        BUILD_NUMBER="$(read_version_value BUILD_NUMBER 2>/dev/null || true)"
        verify_final
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac

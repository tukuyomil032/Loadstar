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
        'Usage: scripts/release.sh [check|prepare|verify-final] [version]' \
        '' \
        'Modes:' \
        '  check         Validate local version metadata without changing files.' \
        '  prepare       Prompt for a release version and prepare the Changelog.' \
        '  verify-final  Validate a final tag against tracked version.env without publishing.' \
        '' \
        'prepare accepts an optional X.Y.Z or vX.Y.Z argument; otherwise it prompts.' \
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

require_local_files() {
    [[ -f "${VERSION_FILE}" ]] || die "${VERSION_FILE} is required for local release preparation"
    [[ -f "${CHANGELOG_FILE}" ]] || die "${CHANGELOG_FILE} is required"
}

normalize_version() {
    local requested="$1"
    requested="${requested#v}"
    [[ "${requested}" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] ||
        die "VERSION must be a stable or prerelease semver: ${requested}"
    printf '%s\n' "${requested}"
}

request_release_version() {
    local requested="${RELEASE_VERSION:-}"

    if [[ -z "${requested}" && $# -gt 0 && -n "${1:-}" ]]; then
        requested="$1"
    fi

    if [[ -z "${requested}" ]]; then
        printf 'Release version (X.Y.Z or vX.Y.Z): ' >&2
        IFS= read -r requested || true
    fi

    [[ -n "${requested}" ]] || die 'A release version is required'
    normalize_version "${requested}"
}

validate_version_values() {
    [[ -n "${APP_VERSION}" ]] || die "version.env must define VERSION"
    [[ "${APP_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] ||
        die "VERSION must be a stable or prerelease semver: ${APP_VERSION}"
    [[ "${BUILD_NUMBER}" =~ ^[1-9][0-9]*$ ]] ||
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
    rg -F -x -q '## [Unreleased]' "${CHANGELOG_FILE}" ||
        die 'CHANGELOG.md must contain an Unreleased heading'
}

check_preparation_targets() {
    git diff --quiet -- "${CHANGELOG_FILE}" ||
        die 'CHANGELOG.md has uncommitted changes; commit or stash it before preparing a release'
    git diff --cached --quiet -- "${CHANGELOG_FILE}" ||
        die 'CHANGELOG.md is staged; commit or unstage it before preparing a release'
}

check_existing_release_entry() {
    local tag="v${APP_VERSION}"
    if rg -F -q "## [${APP_VERSION}] -" "${CHANGELOG_FILE}"; then
        die "${tag} already has a Changelog entry"
    fi
    if git rev-parse --verify --quiet "${tag}^{commit}" >/dev/null 2>&1; then
        die "Git tag ${tag} already exists"
    fi
}

check_remote_release() {
    local tag="v${APP_VERSION}" repository
    if ! command -v gh >/dev/null 2>&1; then
        warn 'gh is not installed; skipped GitHub Release duplicate check'
        return 0
    fi
    repository="$(github_repository)"
    if [[ "${repository}" != */* ]]; then
        warn 'Could not determine the GitHub repository; skipped duplicate check'
        return 0
    fi
    if gh release view "${tag}" --repo "${repository}" >/dev/null 2>&1; then
        die "GitHub Release ${tag} already exists"
    fi
}

derive_build_number() {
    local current_version current_build
    current_version="$(read_version_value VERSION)"
    current_build="$(read_version_value BUILD_NUMBER)"
    [[ "${current_version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] ||
        die "Existing version.env VERSION is invalid: ${current_version}"
    [[ "${current_build}" =~ ^[1-9][0-9]*$ ]] ||
        die "Existing version.env BUILD_NUMBER is invalid: ${current_build}"

    if [[ "${current_version}" == "${APP_VERSION}" ]]; then
        BUILD_NUMBER="${current_build}"
    else
        BUILD_NUMBER="$((current_build + 1))"
    fi
}

write_version_file() {
    local temporary
    temporary="$(mktemp "${TMPDIR:-/tmp}/loadstar-version.XXXXXX")"
    printf 'VERSION=%s\nBUILD_NUMBER=%s\n' "${APP_VERSION}" "${BUILD_NUMBER}" >"${temporary}"
    mv "${temporary}" "${VERSION_FILE}"
}

commit_entries() {
    local pattern="$1"
    git log --format='- %s (%h)' --grep="${pattern}" --extended-regexp HEAD 2>/dev/null |
        rg -v '^- (chore: (prepare|release|update appcast)|release\()' || true
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
    local notes date temporary notes_file
    notes="$(build_release_notes)"
    date="$(date +%Y-%m-%d)"
    temporary="$(mktemp "${TMPDIR:-/tmp}/loadstar-changelog.XXXXXX")"
    notes_file="$(mktemp "${TMPDIR:-/tmp}/loadstar-release-notes.XXXXXX")"
    printf '%s\n' "${notes}" >"${notes_file}"

    awk -v version="${APP_VERSION}" -v release_date="${date}" -v notes_file="${notes_file}" '
        !inserted && $0 == "## [Unreleased]" {
            print
            print ""
            print "## [" version "] - " release_date
            print ""
            while ((getline line < notes_file) > 0) print line
            close(notes_file)
            inserted = 1
            next
        }
        { print }
    ' "${CHANGELOG_FILE}" >"${temporary}"
    rm -f "${notes_file}"
    mv "${temporary}" "${CHANGELOG_FILE}"

    mkdir -p "${BUILD_DIR}"
    printf '%s\n' "${notes}" >"${BUILD_DIR}/release-notes.md"
}

copy_to_clipboard() {
    local value="$1"
    if command -v pbcopy >/dev/null 2>&1 && printf '%s' "${value}" | pbcopy; then
        printf '%s\n' 'Copied the stage-and-commit command to the clipboard using pbcopy.'
    else
        printf '%s\n' 'Clipboard is unavailable; use the printed stage-and-commit command.'
    fi
}

print_prepare_result() {
    local tag="v${APP_VERSION}"
    local stage_command='git add -- CHANGELOG.md'
    local commit_command="git commit -m \"chore: prepare release ${tag}\""
    local clipboard_command="${stage_command} && ${commit_command}"

    printf 'Prepared release %s (build %s).\n' "${tag}" "${BUILD_NUMBER}"
    printf 'Updated files:\n- CHANGELOG.md\n- version.env (local-only, ignored)\n'
    printf 'Release notes: %s\n' "${BUILD_DIR}/release-notes.md"
    printf 'Next command:\n%s\n' "${clipboard_command}"
    copy_to_clipboard "${clipboard_command}"
    printf '%s\n' 'Do not commit version.env during normal development.'
    printf '%s\n' 'Final v1.0 only, after the user approves release readiness: git add -f version.env'
}

check_local() {
    require_local_files
    ensure_version_is_not_staged_or_tracked
    check_changelog_shape
    check_remote_release
    printf 'Local release metadata is valid: v%s (build %s)\n' "${APP_VERSION}" "${BUILD_NUMBER}"
}

verify_final() {
    local tag expected_head actual_head repository
    require_local_files
    validate_version_values
    tag="${TAG:-v${APP_VERSION}}"
    [[ "${tag}" == "v${APP_VERSION}" ]] || die "tag ${tag} does not match version.env VERSION ${APP_VERSION}"
    git ls-files --error-unmatch "${VERSION_FILE_RELATIVE}" >/dev/null 2>&1 ||
        die 'final verification requires tracked version.env'
    expected_head="$(git rev-parse "${tag}^{commit}" 2>/dev/null || true)"
    actual_head="$(git rev-parse HEAD)"
    [[ -n "${expected_head}" && "${expected_head}" == "${actual_head}" ]] ||
        die "HEAD must point at tag ${tag} for final verification"
    if command -v gh >/dev/null 2>&1; then
        repository="$(github_repository)"
        if [[ "${repository}" == */* ]] && gh release view "${tag}" --repo "${repository}" >/dev/null 2>&1; then
            die "GitHub Release ${tag} already exists"
        fi
    fi
    printf 'Final release metadata is valid: %s (build %s)\n' "${tag}" "${BUILD_NUMBER}"
}

MODE="${1:-prepare}"
case "${MODE}" in
-h | --help)
    usage
    ;;
check)
    [[ $# -le 1 ]] || die 'check does not accept a release version; use prepare for an explicit version'
    require_local_files
    APP_VERSION="$(read_version_value VERSION)"
    BUILD_NUMBER="$(read_version_value BUILD_NUMBER)"
    validate_version_values
    check_local
    ;;
prepare)
    [[ $# -le 2 ]] || die 'Usage: scripts/release.sh prepare [X.Y.Z|vX.Y.Z]'
    REQUESTED_VERSION="$(request_release_version "${2:-}")"
    APP_VERSION="${REQUESTED_VERSION}"
    require_local_files
    CURRENT_VERSION="$(read_version_value VERSION)"
    CURRENT_BUILD_NUMBER="$(read_version_value BUILD_NUMBER)"
    APP_VERSION="${CURRENT_VERSION}"
    BUILD_NUMBER="${CURRENT_BUILD_NUMBER}"
    validate_version_values
    APP_VERSION="${REQUESTED_VERSION}"
    ensure_version_is_not_staged_or_tracked
    check_preparation_targets
    check_changelog_shape
    check_existing_release_entry
    check_remote_release
    derive_build_number
    prepare_changelog
    write_version_file
    print_prepare_result
    ;;
verify-final)
    [[ $# -le 1 ]] || die 'verify-final does not accept a release version; commit version.env and tag it first'
    APP_VERSION="$(read_version_value VERSION 2>/dev/null || true)"
    BUILD_NUMBER="$(read_version_value BUILD_NUMBER 2>/dev/null || true)"
    verify_final
    ;;
*)
    usage >&2
    exit 2
    ;;
esac

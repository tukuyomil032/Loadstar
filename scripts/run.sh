#!/usr/bin/env bash
# scripts/run.sh — Build LoadStar (Debug) and launch it inline, like Xcode ⌘R.
#
# Streams the app's stdout/stderr into the terminal so print/os_log/print-style
# debug output is visible. Ctrl+C terminates the app cleanly.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="${ROOT_DIR}/LoadStar.xcodeproj"

# ──────────────────────────────────────────────────────────────────────────────
# Pretty output
# ──────────────────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
    BOLD=$'\033[1m'
    DIM=$'\033[2m'
    RESET=$'\033[0m'
    CYAN=$'\033[38;5;45m'
    GREEN=$'\033[38;5;42m'
    YELLOW=$'\033[38;5;214m'
    RED=$'\033[38;5;203m'
else
    BOLD='' DIM='' RESET='' CYAN='' GREEN='' YELLOW='' RED=''
fi

step()  { printf '\n%s==>%s %s%s%s\n' "${BOLD}${CYAN}" "${RESET}" "${BOLD}" "$1" "${RESET}"; }
ok()    { printf '%s  ✓%s %s\n' "${GREEN}" "${RESET}" "$1"; }
warn()  { printf '%s  !%s %s\n' "${YELLOW}" "${RESET}" "$1"; }
fail()  { printf '%s  ✗%s %s\n' "${RED}" "${RESET}" "$1" >&2; exit 1; }

# ──────────────────────────────────────────────────────────────────────────────
# Config
# ──────────────────────────────────────────────────────────────────────────────
SCHEME="LoadStar"
CONFIG="${CONFIG:-Debug}"
DESTINATION="platform=macOS"

# ──────────────────────────────────────────────────────────────────────────────
# 1. Kill any running instance BEFORE building so a stale process holding onto
#    the .app bundle can't lock the build output.
# ──────────────────────────────────────────────────────────────────────────────
if pgrep -x "${SCHEME}" >/dev/null 2>&1; then
    step "Stopping running ${SCHEME}"
    pkill -x "${SCHEME}" || true
    # Give AppKit a moment to release NSApplication resources
    sleep 0.3
    ok "Old instance terminated"
fi

# ──────────────────────────────────────────────────────────────────────────────
# 2. Build
# ──────────────────────────────────────────────────────────────────────────────
step "Building ${SCHEME} (${CONFIG})"
CONFIG="${CONFIG}" bash "${ROOT_DIR}/scripts/build.sh"

# ──────────────────────────────────────────────────────────────────────────────
# 3. Locate the built .app via -showBuildSettings (portable across DerivedData
#    hash changes — no hardcoded paths).
# ──────────────────────────────────────────────────────────────────────────────
step "Locating ${SCHEME}.app"

BUILT_PRODUCTS_DIR=$(
    xcodebuild \
        -project "${PROJECT_PATH}" \
        -scheme "${SCHEME}" \
        -configuration "${CONFIG}" \
        -destination "${DESTINATION}" \
        ONLY_ACTIVE_ARCH=NO \
        ARCHS='arm64 x86_64' \
        -showBuildSettings 2>/dev/null \
        | awk -F' = ' '/^[[:space:]]+BUILT_PRODUCTS_DIR = / { print $2; exit }'
)

APP_BUNDLE="${BUILT_PRODUCTS_DIR}/${SCHEME}.app"
BINARY="${APP_BUNDLE}/Contents/MacOS/${SCHEME}"

[[ -x "${BINARY}" ]] || fail "Could not locate executable at ${BINARY}"
ok "${DIM}${BINARY}${RESET}"

# ──────────────────────────────────────────────────────────────────────────────
# 4. Launch. exec replaces the shell — the app becomes the foreground process
#    so Ctrl+C is delivered straight to it (same as Xcode ⌘R's stop button).
# ──────────────────────────────────────────────────────────────────────────────
step "Launching ${SCHEME}   ${DIM}(Ctrl+C to stop)${RESET}"
printf '%s────────────────────────────────────────────────────────%s\n' "${DIM}" "${RESET}"

exec "${BINARY}"

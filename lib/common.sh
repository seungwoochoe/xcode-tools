#!/bin/bash

# Shared functions for xcode-build and xcode-test

# Print a usage error and exit.
# Usage: usage_error "message"
usage_error() {
    echo "$1" >&2
    echo "Use --help for usage information" >&2
    exit 1
}

# Parse the command line shared by both commands. Sets POSITIONAL, DEST_ARGS,
# EXTRA_ARGS and RESULT_PATH; -h/--help calls the caller's show_help.
# --result-path is accepted only when ACCEPTS_RESULT_PATH is 1.
# Usage: parse_arguments "$@"
# shellcheck disable=SC2034  # The sourcing command reads these globals.
parse_arguments() {
    POSITIONAL=()
    DEST_ARGS=()
    EXTRA_ARGS=()
    RESULT_PATH=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -destination)
                DEST_ARGS=(-destination "$2")
                shift 2
                ;;
            --result-path)
                [[ "${ACCEPTS_RESULT_PATH:-0}" == 1 ]] || usage_error "Unknown option: $1"
                RESULT_PATH="$2"
                shift 2
                ;;
            --)
                shift
                EXTRA_ARGS=("$@")
                break
                ;;
            -*)
                usage_error "Unknown option: $1"
                ;;
            *)
                POSITIONAL+=("$1")
                shift
                ;;
        esac
    done

    [[ ${#POSITIONAL[@]} -ge 1 ]] || usage_error "Error: scheme is required"
}

# Run xcodebuild, retrying while a concurrent build holds the build database.
# Sets XCODEBUILD_OUTPUT. Removes RESULT_PATH (when set) before each attempt.
# Usage: run_xcodebuild <xcodebuild args...>
run_xcodebuild() {
    local retries=0 max_retries=5 status
    while true; do
        [[ -n "${RESULT_PATH:-}" ]] && rm -rf "$RESULT_PATH"
        XCODEBUILD_OUTPUT=$(xcodebuild "$@" 2>&1)
        status=$?
        if [[ $status -eq 0 || $retries -ge $max_retries ||
              "$XCODEBUILD_OUTPUT" != *"database is locked"* ]]; then
            return $status
        fi
        retries=$((retries + 1))
        echo "Build database locked. Retrying ($retries/$max_retries)..."
        sleep 1
    done
}

# Extract compilation errors from xcodebuild output
# Usage: extract_errors "$BUILD_OUTPUT"
extract_errors() {
    local output="$1"
    echo "$output" | grep -oE "[^[:space:]]+:[0-9]+:[0-9]+: error:.*" | sort -fu || true
}

# Extract compilation warnings from xcodebuild output
# Usage: extract_warnings "$BUILD_OUTPUT"
extract_warnings() {
    local output="$1"
    echo "$output" | grep -E ":[0-9]+:[0-9]+: warning:" | sort -u || true
}

# Print warnings if present
# Usage: print_warnings "$BUILD_OUTPUT"
print_warnings() {
    local warnings
    warnings=$(extract_warnings "$1")
    if [[ -n "$warnings" ]]; then
        echo ""
        echo "⚠ Warnings:"
        echo "$warnings"
    fi
}

# Show broader error patterns when no source-located errors can be extracted
# (linker, signing, package resolution, unknown scheme or destination).
# Usage: show_fallback_errors "$BUILD_OUTPUT"
show_fallback_errors() {
    local output="$1"
    local broader_errors
    broader_errors=$(echo "$output" | grep -E "error:" | head -20 || true)

    if [[ -n "$broader_errors" ]]; then
        echo "$broader_errors"
    else
        echo "Could not extract specific errors. Last 20 lines:"
        echo "$output" | tail -20
    fi
}

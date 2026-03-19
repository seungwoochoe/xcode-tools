#!/bin/bash

# Shared functions for xcode-build and xcode-test

# Check that required dependencies are available
check_dependencies() {
    local missing=()

    if ! command -v xcodebuild &>/dev/null; then
        missing+=("xcodebuild (install Xcode Command Line Tools: xcode-select --install)")
    fi

    if ! command -v xcrun &>/dev/null; then
        missing+=("xcrun (install Xcode Command Line Tools: xcode-select --install)")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Missing required dependencies:" >&2
        for dep in "${missing[@]}"; do
            echo "  - $dep" >&2
        done
        exit 1
    fi
}

# Check if build output indicates a database lock error
# Usage: check_database_lock "$BUILD_OUTPUT"
# Returns 0 (true) if database is locked, 1 (false) otherwise
check_database_lock() {
    [[ "$1" == *"database is locked"* ]]
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

# Get a default iOS simulator destination (prefers iPhone Pro Max)
get_ios_simulator() {
    local name

    # Try iPhone Pro Max first - get the latest one
    name=$(xcrun simctl list devices available 2>/dev/null | \
           grep -oE "iPhone [0-9]+ Pro Max" | \
           sort -t' ' -k2 -n | \
           tail -1)

    if [[ -n "$name" ]]; then
        echo "platform=iOS Simulator,name=$name"
        return 0
    fi

    # Fallback: any iPhone
    name=$(xcrun simctl list devices available 2>/dev/null | \
           grep -oE "iPhone [0-9]+[^)]*" | \
           sort -t' ' -k2 -n | \
           tail -1)

    if [[ -n "$name" ]]; then
        echo "platform=iOS Simulator,name=$name"
        return 0
    fi

    return 1
}

# Show broader error patterns when specific errors can't be extracted
# Usage: show_fallback_errors "$BUILD_OUTPUT"
show_fallback_errors() {
    local output="$1"
    local broader_errors
    broader_errors=$(echo "$output" | grep -E "error:" | grep -v "xcodebuild:" | head -20 || true)

    if [[ -n "$broader_errors" ]]; then
        echo "$broader_errors"
    else
        echo "Could not extract specific errors. Last 20 lines:"
        echo "$output" | tail -20
    fi
}

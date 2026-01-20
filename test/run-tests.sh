#!/bin/bash

# Test runner for xcode-tools

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

TESTS_PASSED=0
TESTS_FAILED=0

# Helper to run a test
run_test() {
    local name="$1"
    local result="$2"
    local expected="$3"

    if [[ "$result" == "$expected" ]]; then
        echo "PASS: $name"
        ((TESTS_PASSED++))
    else
        echo "FAIL: $name"
        echo "  Expected: $expected"
        echo "  Got: $result"
        ((TESTS_FAILED++))
    fi
}

# Helper to check if result contains expected string
run_test_contains() {
    local name="$1"
    local result="$2"
    local expected="$3"

    if [[ "$result" == *"$expected"* ]]; then
        echo "PASS: $name"
        ((TESTS_PASSED++))
    else
        echo "FAIL: $name"
        echo "  Expected to contain: $expected"
        echo "  Got: $result"
        ((TESTS_FAILED++))
    fi
}

echo "Running xcode-tools tests..."
echo ""

# Source common.sh for testing its functions
source "$ROOT_DIR/lib/common.sh"

# Test 1: extract_errors finds Swift errors
echo "Testing extract_errors..."
BUILD_OUTPUT=$(cat "$SCRIPT_DIR/fixtures/build-output-swift-errors.txt")
ERRORS=$(extract_errors "$BUILD_OUTPUT")
run_test_contains "extract_errors finds Swift errors" "$ERRORS" "ContentView.swift:42:15: error:"
run_test_contains "extract_errors finds AppDelegate errors" "$ERRORS" "AppDelegate.swift:18:9: error:"

# Test 2: extract_errors deduplicates
ERROR_COUNT=$(echo "$ERRORS" | grep -c "ContentView.swift:42:15" || true)
run_test "extract_errors deduplicates (ContentView error appears once)" "$ERROR_COUNT" "1"

# Test 3: extract_errors returns empty for success
SUCCESS_OUTPUT=$(cat "$SCRIPT_DIR/fixtures/build-output-success.txt")
ERRORS=$(extract_errors "$SUCCESS_OUTPUT")
run_test "extract_errors returns empty for successful build" "$ERRORS" ""

# Test 4: extract_warnings finds warnings
echo ""
echo "Testing extract_warnings..."
WARNING_OUTPUT=$(cat "$SCRIPT_DIR/fixtures/build-output-warnings.txt")
WARNINGS=$(extract_warnings "$WARNING_OUTPUT")
run_test_contains "extract_warnings finds unused variable warning" "$WARNINGS" "warning: variable 'unused'"
run_test_contains "extract_warnings finds deprecation warning" "$WARNINGS" "warning: 'init()' is deprecated"

# Test 5: extract_warnings returns empty when no warnings
WARNINGS=$(extract_warnings "$SUCCESS_OUTPUT")
run_test "extract_warnings returns empty when no warnings" "$WARNINGS" ""

# Test 6: --help flag works
echo ""
echo "Testing --help flags..."
HELP_OUTPUT=$("$ROOT_DIR/xcode-build" --help 2>&1)
run_test_contains "xcode-build --help shows usage" "$HELP_OUTPUT" "Usage: xcode-build"

HELP_OUTPUT=$("$ROOT_DIR/xcode-test" --help 2>&1)
run_test_contains "xcode-test --help shows usage" "$HELP_OUTPUT" "Usage: xcode-test"

# Test 7: Missing scheme shows error
echo ""
echo "Testing error handling..."
ERROR_OUTPUT=$("$ROOT_DIR/xcode-build" 2>&1 || true)
run_test_contains "xcode-build without args shows error" "$ERROR_OUTPUT" "scheme is required"

ERROR_OUTPUT=$("$ROOT_DIR/xcode-test" 2>&1 || true)
run_test_contains "xcode-test without args shows error" "$ERROR_OUTPUT" "scheme is required"

# Summary
echo ""
echo "========================================"
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"
echo "========================================"

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi

#!/bin/bash

# Sourced by run-tests.sh. Exercise the CLI without Xcode or project changes.
echo ""
echo "Testing successful test reports..."
REPORT_TMP=$(mktemp -d)
export REPORT_TMP
trap 'rm -rf "$REPORT_TMP"' EXIT
mkdir "$REPORT_TMP/bin"
cat > "$REPORT_TMP/bin/xcodebuild" <<'MOCK'
#!/bin/bash
count=$(cat "$REPORT_TMP/calls" 2>/dev/null || echo 0)
count=$((count + 1))
echo "$count" > "$REPORT_TMP/calls"
if [[ "$count" == 1 ]]; then
    case "${REPORT_MODE:-normal}" in
        lock) echo 'error: database is locked'; exit 1 ;;
        fallback) echo '** TEST FAILED **'; exit 1 ;;
    esac
fi
printf '%s\n' "${REPORT_CONSOLE:-}" '** TEST SUCCEEDED **'
MOCK
cat > "$REPORT_TMP/bin/xcrun" <<'MOCK'
#!/bin/bash
case "$*" in
    *'get test-results summary'*) printf '%s\n' "$REPORT_SUMMARY" ;;
    *'get build-results'*) printf '%s\n' "$REPORT_BUILD" ;;
    *) exit 1 ;;
esac
MOCK
chmod +x "$REPORT_TMP/bin/xcodebuild" "$REPORT_TMP/bin/xcrun"

export REPORT_SUMMARY='{"totalTestCount":4,"passedTests":2,"failedTests":0,"skippedTests":1,"expectedFailures":1,"runtimeWarnings":[]}'
export REPORT_BUILD='{"warnings":[],"analyzerWarnings":[]}'
export REPORT_CONSOLE=''

run_report() {
    rm -f "$REPORT_TMP/calls"
    REPORT_RESULT=$(REPORT_MODE="${1:-normal}" PATH="$REPORT_TMP/bin:$PATH" \
        "$ROOT_DIR/xcode-test" Demo -destination 'platform=macOS' \
        --result-path "$REPORT_TMP/result with spaces.xcresult" 2>&1)
    REPORT_STATUS=$?
}

run_report
run_test "successful report preserves exit status" "$REPORT_STATUS" "0"
run_test_contains "reports summary counts including skipped and expected failures" "$REPORT_RESULT" \
    '4 total, 2 passed, 0 failed, 1 skipped, 1 expected failures'
run_test_contains "reports result path with spaces" "$REPORT_RESULT" "Result bundle: $REPORT_TMP/result with spaces.xcresult"
run_test "clean success stays at two lines" "$(printf '%s\n' "$REPORT_RESULT" | wc -l | tr -d ' ')" "2"

REPORT_BUILD='{"warnings":[{"message":"Failed to download profiles: Operation not permitted"},{"message":"Failed to download profiles: Operation not permitted"},{"message":"Failed to merge raw profiles: No profile data files were written"}],"analyzerWarnings":[{"message":"Analyzer diagnostic"}]}'
REPORT_SUMMARY=$(printf '%s\n' "$REPORT_SUMMARY" | jq '.runtimeWarnings = [{"message":"Runtime diagnostic\nwith another line"}]')
run_report
run_test "coverage warnings do not fail passing tests" "$REPORT_STATUS" "0"
run_test_contains "includes coverage permission failure" "$REPORT_RESULT" 'Failed to download profiles: Operation not permitted'
run_test_contains "includes coverage merge failure" "$REPORT_RESULT" 'Failed to merge raw profiles'
run_test "deduplicates repeated warnings" "$(printf '%s\n' "$REPORT_RESULT" | grep -c 'Failed to download profiles')" "1"
run_test_contains "includes analyzer warnings" "$REPORT_RESULT" 'Analyzer diagnostic'
run_test_contains "normalizes runtime warnings to one line" "$REPORT_RESULT" 'Runtime diagnostic with another line'

REPORT_BUILD=$(jq -nc '{warnings: [range(7) | {message: ((tostring) + ("x" * 500) + " end")}]}')
REPORT_SUMMARY=$(printf '%s\n' "$REPORT_SUMMARY" | jq '.runtimeWarnings = []')
run_report
run_test_contains "reports total warning count" "$REPORT_RESULT" 'Warnings (7)'
run_test "limits warning entries" "$(printf '%s\n' "$REPORT_RESULT" | grep -c '^- ')" "5"
run_test_contains "retains long diagnostic ending and marks truncation" "$REPORT_RESULT" ' end [truncated]'
run_test_contains "reports omitted warnings" "$REPORT_RESULT" '2 more; see result bundle.'
run_test "bounds warning report size" "$([[ ${#REPORT_RESULT} -lt 2500 ]] && echo yes)" 'yes'

REPORT_SUMMARY='not valid json'
REPORT_BUILD='{}'
REPORT_CONSOLE=$'  warning:Failed to download profiles: Operation not permitted\n/source/File.swift:1:2: warning: Compiler diagnostic\n/source/File.swift:1:2: warning: Compiler diagnostic (in target '\''Demo'\'' from project '\''Demo'\'')'
run_report
run_test "unreadable metadata does not fail passing tests" "$REPORT_STATUS" "0"
run_test_contains "labels unavailable counts" "$REPORT_RESULT" 'counts unavailable'
run_test_contains "labels unavailable structured warnings" "$REPORT_RESULT" 'Build warning details unavailable'
run_test_contains "falls back to console coverage warnings" "$REPORT_RESULT" 'warning:Failed to download profiles'
run_test "normalizes duplicate console compiler warnings" "$(printf '%s\n' "$REPORT_RESULT" | grep -c 'Compiler diagnostic')" "1"
run_test_contains "still includes result path with unreadable metadata" "$REPORT_RESULT" 'Result bundle:'

REPORT_SUMMARY='{"totalTestCount":4,"passedTests":4,"failedTests":0,"skippedTests":0}'
REPORT_BUILD='{"warnings":[{"message":"Retry warning"}]}'
for mode in lock fallback; do
    run_report "$mode"
    run_test "$mode retry succeeds" "$REPORT_STATUS" "0"
    run_test_contains "$mode retry uses count report" "$REPORT_RESULT" 'Tests passed (after retry) (4 total, 4 passed'
    run_test_contains "$mode retry includes warnings" "$REPORT_RESULT" 'Retry warning'
    run_test_contains "$mode retry includes result path" "$REPORT_RESULT" 'Result bundle:'
done

#!/bin/bash

# Print a bounded success report; keep complete diagnostics in the result bundle.
# Usage: print_test_success "$RESULT_PATH" "$TEST_OUTPUT" [" (after retry)"]
print_test_success() {
    local result_path="$1" output="$2" suffix="${3:-}"
    local summary counts build_warnings warnings

    summary=$(xcrun xcresulttool get test-results summary --path "$result_path" 2>/dev/null |
        jq -ce 'select(type == "object")') || summary='{}'
    counts=$(printf '%s\n' "$summary" | jq -er '
        select((.totalTestCount | type) == "number" and
               (.passedTests | type) == "number" and
               (.failedTests | type) == "number" and
               (.skippedTests | type) == "number") |
        "\(.totalTestCount) total, \(.passedTests) passed, \(.failedTests) failed, \(.skippedTests) skipped, \(.expectedFailures // 0) expected failures"
    ') || counts="counts unavailable"
    printf '✓ Tests passed%s (%s)\n' "$suffix" "$counts"

    build_warnings=$(xcrun xcresulttool get build-results --path "$result_path" 2>/dev/null |
        jq -ce 'select((.warnings | type) == "array") | .warnings + (.analyzerWarnings // [])') || build_warnings=''
    if [[ -z "$build_warnings" ]]; then
        echo "⚠ Build warning details unavailable; checking console output."
        build_warnings=$(printf '%s\n' "$output" | jq -Rsc '
            [split("\n")[] | select(test("(^|[[:space:]])warning:")) |
             sub("^[[:space:]]+"; "") | sub(" \\(in target .*\\)$"; "")]
        ')
    fi

    warnings=$(printf '%s\n' "$build_warnings" | jq -c --argjson summary "$summary" '
        . + ($summary.runtimeWarnings // []) |
        map(if type == "string" then . else (.message // .text // tostring) end |
            gsub("[[:space:]]+"; " ") | sub("^ +"; "") | sub(" +$"; "")) |
        map(select(length > 0)) | unique
    ')
    printf '%s\n' "$warnings" | jq -r '
        if length == 0 then empty else
            "⚠ Warnings (\(length)):",
            (.[:5][] | "- " + (if length > 400 then .[:220] + " … " + .[-160:] + " [truncated]" else . end)),
            (if length > 5 then "… \(length - 5) more; see result bundle." else empty end)
        end
    '
    printf 'Result bundle: %s\n' "$result_path"
}

#!/bin/bash

# Sourced by run-tests.sh. Exercise remote runs with recorded ssh and rsync calls.
echo ""
echo "Testing remote runs..."
REMOTE_TMP=$(cd "$(mktemp -d)" && pwd -P)
export REMOTE_TMP
mkdir -p "$REMOTE_TMP/bin" "$REMOTE_TMP/home/Projects/App/Shots" "$REMOTE_TMP/home/tools"
cp -R "$ROOT_DIR/xcode-remote" "$ROOT_DIR/xcode-test" "$ROOT_DIR/lib" "$REMOTE_TMP/home/tools/"
cat > "$REMOTE_TMP/bin/ssh" <<'MOCK'
#!/bin/bash
echo "ssh $*" >> "$REMOTE_TMP/calls"
case "$2" in
    *'printf %s'*) printf %s /remote/.xcode-remote ;;
    *run-in-desktop-session.sh*) exit "${REMOTE_STATUS:-0}" ;;
esac
MOCK
cat > "$REMOTE_TMP/bin/rsync" <<'MOCK'
#!/bin/bash
echo "rsync $*" >> "$REMOTE_TMP/calls"
MOCK
chmod +x "$REMOTE_TMP/bin/ssh" "$REMOTE_TMP/bin/rsync"

run_remote() {
    local status="$1"
    shift
    rm -f "$REMOTE_TMP/calls"
    REMOTE_RESULT=$(cd "$REMOTE_TMP/home/Projects/App" && REMOTE_STATUS="$status" HOME="$REMOTE_TMP/home" \
        PATH="$REMOTE_TMP/bin:$PATH" "$@" 2>&1)
    REMOTE_EXIT=$?
    REMOTE_CALLS=$(cat "$REMOTE_TMP/calls" 2>/dev/null)
}

MIRROR=/remote/.xcode-remote/Projects/App
run_remote 3 ../../tools/xcode-remote air --push Shots --pull Shots -- make 'two words'
run_test "xcode-remote exits with the command's status" "$REMOTE_EXIT" "3"
run_test_contains "mirrors the project without ignored files" "$REMOTE_CALLS" \
    "rsync -a --delete --exclude .git --filter=:- .gitignore $REMOTE_TMP/home/Projects/App/ air:$MIRROR/"
run_test_contains "pushes an ignored directory whole" "$REMOTE_CALLS" "rsync -a --delete Shots/ air:$MIRROR/Shots/"
run_test_contains "runs the quoted command in the desktop session" "$REMOTE_CALLS" \
    "ssh air cd $MIRROR && bash /remote/.xcode-remote/tools/lib/run-in-desktop-session.sh make two\\ words"
run_test_contains "copies outputs back after a failure" "$REMOTE_CALLS" "rsync -a --delete air:$MIRROR/Shots/ Shots/"

run_remote 0 ../../tools/xcode-test Demo --host air -destination 'platform=macOS' \
    --result-path "$REMOTE_TMP/Demo.xcresult" -- -only-testing:DemoUITests
run_test "xcode-test --host succeeds with the remote run" "$REMOTE_EXIT" "0"
run_test_contains "forwards the test arguments" "$REMOTE_CALLS" \
    "/remote/.xcode-remote/tools/xcode-test Demo -destination platform=macOS --result-path /remote/.xcode-remote/results/DemoTest.xcresult -- -only-testing:DemoUITests"
run_test_contains "copies the result bundle back" "$REMOTE_RESULT" "Copied to: $REMOTE_TMP/Demo.xcresult"

REMOTE_RESULT=$(cd / && HOME="$REMOTE_TMP/home" PATH="$REMOTE_TMP/bin:$PATH" \
    "$REMOTE_TMP/home/tools/xcode-remote" air -- true 2>&1)
run_test_contains "refuses a directory outside the home folder" "$REMOTE_RESULT" "it is outside"

rm -rf "$REMOTE_TMP"

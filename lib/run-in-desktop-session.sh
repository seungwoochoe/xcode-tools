#!/bin/bash

# Run a command in the logged-in desktop session of this Mac, from the current
# directory, and exit with its status.
#
# A command started over SSH runs in a background session, where the login
# keychain is locked (code signing fails with errSecInternalComponent) and UI
# tests have no screen. A launchd job in the user's gui domain has both.
#
# Usage: run-in-desktop-session.sh <command> [args...]

set -uo pipefail

[[ $# -ge 1 ]] || { echo "Usage: run-in-desktop-session.sh <command> [args...]" >&2; exit 1; }

DOMAIN="gui/$(id -u)"
LABEL="xcode-remote.$$"
JOB_DIR=$(mktemp -d "${TMPDIR:-/tmp}/xcode-remote.XXXXXX") || exit 1
OUTPUT="$JOB_DIR/output"
STATUS="$JOB_DIR/status"

if ! launchctl print "$DOMAIN" &>/dev/null; then
    echo "No desktop session: log in to this Mac's desktop as $(id -un) first" >&2
    exit 1
fi

{
    echo '#!/bin/bash'
    printf 'cd %q || exit 1\n' "$PWD"
    printf 'export LANG=%q\n' "${LANG:-en_US.UTF-8}"
    printf '%q ' "$@"
    printf '\necho $? > %q\nmv %q %q\n' "$STATUS.partial" "$STATUS.partial" "$STATUS"
} > "$JOB_DIR/run"

cat > "$JOB_DIR/job.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>$LABEL</string>
    <key>ProgramArguments</key><array><string>/bin/bash</string><string>$JOB_DIR/run</string></array>
    <key>RunAtLoad</key><true/>
    <key>StandardOutPath</key><string>$OUTPUT</string>
    <key>StandardErrorPath</key><string>$OUTPUT</string>
</dict>
</plist>
EOF

# Removing the job also stops a command that is still running.
# shellcheck disable=SC2329  # Invoked by the EXIT trap.
cleanup() {
    trap - EXIT INT TERM HUP PIPE
    launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null
    rm -rf "$JOB_DIR"
}
trap cleanup EXIT
trap 'exit 130' INT TERM HUP PIPE

: > "$OUTPUT"
launchctl bootstrap "$DOMAIN" "$JOB_DIR/job.plist" || exit 1

OFFSET=0
print_new_output() {
    local size
    size=$(stat -f%z "$OUTPUT")
    if (( size > OFFSET )); then
        tail -c "+$((OFFSET + 1))" "$OUTPUT" | head -c "$((size - OFFSET))"
        OFFSET=$size
    fi
}

until [[ -f "$STATUS" ]]; do
    print_new_output
    # A closed SSH connection leaves this script without a parent or a signal.
    [[ "$(ps -o ppid= -p $$ | tr -d ' ')" != 1 ]] || exit 129
    sleep 1
done
print_new_output

exit "$(cat "$STATUS")"

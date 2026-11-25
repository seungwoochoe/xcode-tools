#!/bin/bash

# Shared functions for running on another Mac over SSH.
#
# A directory under $HOME is mirrored to ~/.xcode-remote/<its path below $HOME>
# on the host, so sibling directories keep their relative positions and the
# host's own checkouts are never touched.

# Remote paths are quoted here for the host's shell.
# shellcheck disable=SC2029

# Print the host's mirror root and create it.
# Usage: remote_root <host>
remote_root() {
    # shellcheck disable=SC2016  # $HOME is the host's.
    ssh "$1" 'mkdir -p "$HOME/.xcode-remote" && printf %s "$HOME/.xcode-remote"'
}

# Print a local directory's absolute mirror path.
# Usage: remote_mirror_path <remote root> <local dir>
remote_mirror_path() {
    local root="$1" dir home
    dir=$(cd "$2" && pwd -P) || return 1
    home=$(cd "$HOME" && pwd -P)
    if [[ "$dir" != "$home"/* ]]; then
        echo "Cannot mirror $dir: it is outside $HOME" >&2
        return 1
    fi
    echo "$root/${dir#"$home"/}"
}

# Make a directory on the host identical to a local one. With "tracked", .git
# and git-ignored files are left out and the host keeps its own ignored files.
# A missing local directory removes the remote one.
# Usage: remote_push <host> <local dir> <remote dir> [tracked]
remote_push() {
    local host="$1" local_dir="$2" remote_dir="$3" mode="${4:-}"
    local -a filters=()
    [[ "$mode" == tracked ]] && filters=(--exclude .git --filter=':- .gitignore')

    if [[ ! -d "$local_dir" ]]; then
        ssh "$host" "rm -rf $(printf '%q' "$remote_dir")"
        return
    fi
    ssh "$host" "mkdir -p $(printf '%q' "$remote_dir")" &&
        rsync -a --delete ${filters[@]+"${filters[@]}"} \
            "$local_dir/" "$host:$(printf '%q' "$remote_dir")/"
}

# Replace a local directory with a directory from the host. Returns 1 without
# touching the local one when the remote directory does not exist.
# Usage: remote_fetch <host> <remote dir> <local dir>
remote_fetch() {
    local host="$1" remote_dir="$2" local_dir="$3"
    ssh "$host" "test -d $(printf '%q' "$remote_dir")" || return 1
    mkdir -p "$local_dir" &&
        rsync -a --delete "$host:$(printf '%q' "$remote_dir")/" "$local_dir/"
}

# Run a command in a directory on the host, inside the logged-in desktop
# session, and return its status.
# Usage: remote_run <host> <remote tools dir> <remote dir> <command> [args...]
remote_run() {
    local host="$1" tools_dir="$2" remote_dir="$3"
    shift 3
    ssh "$host" "cd $(printf '%q' "$remote_dir") && bash $(printf '%q ' \
        "$tools_dir/lib/run-in-desktop-session.sh" "$@")"
}

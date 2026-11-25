# xcode-tools

[![CI](https://github.com/seungwoochoe/xcode-tools/actions/workflows/ci.yml/badge.svg)](https://github.com/seungwoochoe/xcode-tools/actions/workflows/ci.yml)

Wrappers around `xcodebuild` that deduplicate build errors and report test failure reasons.
A run is retried only while a concurrent build holds the build database.

## Setup

Install Xcode with the required platform SDKs and simulators, select it with
`xcode-select`, and install `jq` (`brew install jq`) for test-result parsing.
Clone this repository and add its directory to your shell's `PATH`.

## Usage

Run from the project directory with an existing Xcode scheme:

```sh
xcode-build MyApp                 # Debug
xcode-build MyApp Release
xcode-test MyMacApp
xcode-test MyApp -destination "platform=iOS Simulator,name=iPhone 18 Pro"
xcode-test MyApp --result-path ./results.xcresult
xcode-test MyApp -- -only-testing:MyAppTests/SomeTest
xcode-test MyMacApp --host air -- -only-testing:MyMacAppUITests
xcode-remote air --pull Screenshots -- ./capture.sh
```

Without `-destination`, `xcodebuild` picks the destination; pass one for
simulator runs.

Both commands accept `-h`/`--help`, `-destination DEST`, and extra `xcodebuild`
flags after `--`. Only `xcode-test` accepts `--result-path PATH`; its default is
`$TMPDIR/<scheme>Test.xcresult` (or `/tmp` when `TMPDIR` is unset). The existing
result bundle at that path is replaced on each run.

Successful test runs print aggregate test counts, deduplicated build/runtime
warnings, and the result-bundle path. Counts follow `xcresulttool`'s test summary;
parameterized executions can outnumber the reported tests. Warning output is
limited to five messages, with long messages shortened; inspect the bundle for
complete diagnostics. If result metadata cannot be read, the output says so and
falls back to console warnings. A passing test suite can still report a coverage
collection failure.

## Running on another Mac

macOS UI tests take over the screen. `xcode-test --host HOST` runs the same
command on another Mac over SSH and copies the result bundle back;
`xcode-remote HOST [--with DIR] [--push DIR] [--pull DIR] -- COMMAND` does the
same for any command, such as a screenshot capture script.

Each run mirrors the current directory (and each `--with` directory) to
`~/.xcode-remote/<path below your home>` on the host, without `.git` and
git-ignored files, so local edits need no commit and the host's own checkouts
stay untouched. `--push` also sends a git-ignored directory, and `--pull` copies
a directory back after the command. The command runs in the host's logged-in
desktop session, where the screen and the login keychain are available; a plain
SSH session cannot sign code (`errSecInternalComponent`). Closing the
connection stops the command.

The host needs Remote Login with your SSH key, the same Xcode with the
project's platform components, automatic login without a screen lock, and
sleep disabled. Authorize UI automation once with
`sudo automationmodetool enable-automationmode-without-authentication`.

[MIT license](LICENSE).

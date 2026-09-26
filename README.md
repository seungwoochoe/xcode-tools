# xcode-tools

[![CI](https://github.com/seungwoochoe/xcode-tools/actions/workflows/ci.yml/badge.svg)](https://github.com/seungwoochoe/xcode-tools/actions/workflows/ci.yml)

Wrappers around `xcodebuild` that deduplicate build errors and report test failure reasons.

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
```

For iOS-only schemes, omitting `-destination` selects the latest available iPhone
Pro Max, falling back to another iPhone. Use the explicit destination above to
select iPhone 18 Pro; that simulator must be installed.

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

[MIT license](LICENSE).

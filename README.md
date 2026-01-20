# xcode-tools

[![CI](https://github.com/seungwoochoe/xcode-tools/actions/workflows/ci.yml/badge.svg)](https://github.com/seungwoochoe/xcode-tools/actions/workflows/ci.yml)

`xcodebuild` output is verbose and doesn't show test failure reasons. These tools extract and deduplicate the errors you care about.

## Before & After

**xcodebuild test** (hundreds of lines, ~20K tokens):
```
Resolved source packages:
  some-package @ 1.0.0
  another-package @ 2.0.0
  ...14 packages...

note: Target dependency graph (50 targets)
    Target 'MyAppTests' in project 'MyApp'
        ➜ Explicit dependency on target 'MyApp' in project 'MyApp'
    ...

Test case 'FeatureTests/testButtonTapped()' passed on 'My Mac' (0.001 seconds)
Test case 'FeatureTests/testNavigation()' passed on 'My Mac' (0.002 seconds)
Test case 'FeatureTests/testInitialState()' passed on 'My Mac' (0.001 seconds)
...100 more passing tests...
Test case 'FeatureTests/testOperation()' failed on 'My Mac' (0.500 seconds)

** TEST FAILED **
```

xcodebuild shows every passing test and doesn't show *why* tests fail.

**xcode-test** (only failures, and why):
```
✗ Tests failed:

FeatureTests/testOperation():
FeatureTests.swift:42: Expectation failed: (state.count → 0) == 1
```

## Installation

Clone the repository and add it to your PATH:

```bash
git clone https://github.com/seungwoochoe/xcode-tools.git
echo 'export PATH="$PATH:/path/to/xcode-tools"' >> ~/.zshrc
source ~/.zshrc
```

## Usage

### xcode-build

Build an Xcode project with concise error output:

```bash
xcode-build MyApp               # Build with Debug configuration
xcode-build MyApp Release       # Build with Release configuration
```

### xcode-test

Run tests with detailed failure reporting:

```bash
xcode-test MyApp                                                            # macOS app
xcode-test MyApp -destination "platform=iOS Simulator,name=iPhone 17"       # iOS app (explicit)
xcode-test MyApp --result-path ./results.xcresult                           # Custom result path
```

For iOS-only projects, if `-destination` is not provided, xcode-test automatically selects the latest iPhone Pro Max simulator.

### Passing Extra Flags

Both commands support `--` to pass additional flags to xcodebuild:

```bash
xcode-test MyApp -- -only-testing:MyAppTests/SomeTest
```

## Options

| Option | Description |
|--------|-------------|
| `-h, --help` | Show help message |
| `-destination DEST` | Build/test destination |
| `--result-path PATH` | (xcode-test only) Custom path for .xcresult bundle |

## Requirements

- Xcode Command Line Tools (`xcode-select --install`)
- `jq` for test failure parsing (`brew install jq`)

## License

This project is released under the MIT license. See [LICENSE](LICENSE) for details.

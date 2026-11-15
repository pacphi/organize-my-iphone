# Development

How to build, test and run the project while working on it. The `Makefile` at the project root wraps the common commands; everything it does can also be run by hand.

## Prerequisites

- macOS 15 or later
- Xcode 26 or later (Swift 6.2 or later). `swift --version` shows what you have.
- Nothing else for building and testing. A phone, Apple Configurator and a local model are only needed to use the tool for real; see [usage.md](usage.md).

## Using the Makefile

Run `make` with no arguments to see every target, grouped, with a one-line description:

```sh
make          # same as: make help
```

```
Usage:
  make <target> [VARIABLE=value]

General
  help       Show this help

Build
  build      Compile a debug build
  release    Compile an optimized build of the command-line tool
  install    Install the tool into PREFIX/bin (default ~/.local/bin)
  uninstall  Remove the installed tool from PREFIX/bin
  clean      Delete build products

Test
  test       Run the unit tests
  demo       Run the whole pipeline against a fake iPhone (no device, model or network)
  check      Everything CI runs: lint, unit tests, then the demo

Code style
  lint       Report formatting problems without changing files
  format     Reformat the Swift sources in place

Run
  doctor     Check cfgutil, the connected iPhone and local models
  schemes    List the layout schemes and the data each one uses
  run        Run the tool with ARGS, e.g. make run ARGS="run --open"
```

The screen ends with the variables you can set, their current values, and a few examples.

### Targets and what they run

| Target | Runs | Use it when |
| --- | --- | --- |
| `make build` | `swift build` | You want to know the code compiles. |
| `make release` | `swift build -c release --product organize-my-iphone` | You want an optimized binary. |
| `make install` | `release`, then copies the binary to `PREFIX/bin` | You want to type `organize-my-iphone` instead of `swift run …`. |
| `make uninstall` | Removes the binary from `PREFIX/bin` | You are done with it. |
| `make clean` | `swift package clean` | A build is behaving strangely. |
| `make test` | `swift test --parallel` | After any change. |
| `make demo` | `bash scripts/demo.sh` | You want to see scan through restore work end to end without a phone. |
| `make check` | `lint`, `test`, then `demo` | Before pushing. This is what CI runs. |
| `make lint` | `swift format lint --recursive Sources Tests Package.swift` | To see style drift. Reports only. |
| `make format` | `swift format --in-place --recursive Sources Tests Package.swift` | To fix style drift. Rewrites files. |
| `make doctor` | `swift run organize-my-iphone doctor` | To check `cfgutil`, the phone and local models. |
| `make schemes` | `swift run organize-my-iphone schemes` | To see the twelve layouts and the data each one uses. |
| `make run` | `swift run organize-my-iphone $(ARGS)` | To run any command of the tool from source. |

### Variables

Set these on the command line after the target.

| Variable | Default | Affects | Example |
| --- | --- | --- | --- |
| `PREFIX` | `~/.local` | `install`, `uninstall` | `make install PREFIX=/opt/tools` |
| `ARGS` | `--help` | `run` | `make run ARGS="apply folder-board --dry-run"` |
| `DEMO_WORKSPACE` | a new temporary folder | `demo` | `make demo DEMO_WORKSPACE=/tmp/omi-demo` |

### Common tasks

```sh
# Everyday loop
make test

# Before pushing: the same checks CI runs
make check

# See the tool work with no phone, and keep the preview page
make demo DEMO_WORKSPACE=/tmp/omi-demo
open /tmp/omi-demo/preview.html

# Run the real thing from source
make doctor
make run ARGS="run --open"
make run ARGS="apply folder-board --dry-run"

# Install to ~/.local/bin (no sudo); make sure that folder is on your PATH
make install
```

Avoid `sudo make install`: it would run the build as root and leave root-owned files in `.build`. To install system-wide, build first and copy the binary yourself:

```sh
make release
sudo install "$(swift build -c release --show-bin-path)/organize-my-iphone" /usr/local/bin/
```

`make run` passes `ARGS` straight to the tool, so quote it when it contains spaces.

### Adding a target

The help screen is generated from the Makefile itself:

- Put `## description` after a target's name and prerequisites to list it:

  ```make
  docs: ## Build the API documentation
  	swift package generate-documentation
  ```

- Start a new group with a line beginning `##@`:

  ```make
  ##@ Documentation
  ```

- Add the target's name to the `.PHONY` line, since targets here are commands, not files.

Recipe lines must start with a tab, not spaces.

## Tests

| Where | What it covers |
| --- | --- |
| `Tests/OrganizeCoreTests` | The logic: JSON handling, the layout codec, validation, classification, planning, rendering. No fakes needed, because the core does no I/O. |
| `Tests/OrganizeAdaptersTests` | The adapters, with processes and HTTP replaced by fakes, plus one test that drives the real subprocess path through `Tests/Fixtures/fake-cfgutil`. |
| `scripts/demo.sh` | The built tool end to end: scan, classify, plan all twelve layouts (with sample usage and icon-color files), preview, a dry-run apply of every layout, then a real apply and restore against the fake phone, with checks on the results. |

Run one suite or one test with SwiftPM's filter:

```sh
swift test --filter IconLayoutCodecTests
swift test --filter "PlannerTests/folderBoardCanPutEverythingInFolders"
```

In Xcode, open `Package.swift` and press ⌘U.

### The fake iPhone

`Tests/Fixtures/fake-cfgutil` is a shell script that answers the four `cfgutil` commands the tool uses, in the shapes the real `cfgutil` prints. Point the tool at it with `--cfgutil`:

```sh
swift run organize-my-iphone run --offline --engine heuristic \
  --cfgutil Tests/Fixtures/fake-cfgutil --workspace /tmp/omi-fake
```

Set `FAKE_CFGUTIL_STATE=<file>` to make it remember a layout written by `apply`. `scripts/demo.sh` does this for you.

## Continuous integration

`.github/workflows/ci.yml` runs on every push to `main` and every pull request, on GitHub's `xcode-27` and `macos-26` macOS runners:

| CI step | Local equivalent |
| --- | --- |
| Build | `swift build --build-tests` |
| Unit tests | `make test` |
| End-to-end run against a fake iPhone | `make demo` |
| Format check (separate job) | `make lint` |

The preview page from the demo is uploaded as a build artifact, so you can open it from the run's summary page.

`.github/workflows/release.yml` runs when a tag starting with `v` is pushed. It tests, builds the release binary, and publishes it with a checksum as a GitHub release:

```sh
git tag v0.1.0
git push origin v0.1.0
```

`.github/dependabot.yml` opens weekly pull requests for newer Swift packages and GitHub Actions.

## Code style

`swift format` ships with the toolchain and reads `.swift-format` (120-column lines, 4-space indentation). `make lint` reports; `make format` rewrites. CI's format check reports warnings without failing the build; add `--strict` to the workflow once the tree has been through `make format`.

## Where things go

See [architecture.md](architecture.md) for the module layout and the extension points (new model backend, device transport, or layout scheme).

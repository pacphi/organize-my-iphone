# AGENTS.md

Rules and context for AI coding agents working in this repository. This file is the single source of truth;
`CLAUDE.md` only imports it.

## What this project is

`organize-my-iphone` is a Swift command-line tool for macOS. Over USB, through Apple Configurator's `cfgutil`, it
reads the apps and Home Screen layout of a connected iPhone. It sorts the apps into categories using built-in rules
plus a model that runs on the Mac (Ollama, or Apple's on-device Foundation Models). Then it proposes twelve tidier
layouts (`category-pages`, `folder-board`, `alphabetical`, `most-used`, `time-of-day`, `verb-folders`, `rainbow`,
`thumb-reach`, `places`, `new-and-review`, `essentials`, `life-areas`; see `docs/layouts.md`) and shows them in an
HTML preview next to the current layout. It writes a layout back to the phone only when the user runs `apply`, and
`restore` puts a backed-up layout back.

Pipeline: `scan → enrich → classify → plan → preview`, then optionally `apply` / `restore`. Each step reads and
writes JSON files in a workspace folder (default `~/.organize-my-iphone`), so any step can be rerun alone. `run`
chains scan through preview.

## Layout

| Path | What lives there |
| --- | --- |
| `Sources/OrganizeCore/` | Pure logic: models, layout codec, validation, classification, planning, HTML rendering |
| `Sources/OrganizeAdapters/` | The outside world: `cfgutil`, App Store lookup, Ollama, Apple's model, disk |
| `Sources/OrganizeCLI/` | Command-line front end (swift-argument-parser) |
| `Tests/OrganizeCoreTests/` | Unit tests for the core, plain values, no fakes |
| `Tests/OrganizeAdaptersTests/` | Adapter tests with faked processes and HTTP |
| `Tests/Fixtures/fake-cfgutil` | Shell script that imitates `cfgutil`; used by tests, CI and the demo |
| `scripts/demo.sh` | End-to-end run (scan through restore) against the fake iPhone |
| `docs/` | Usage, development, architecture, PRD, personae, journey, use cases |

## Commands

Run `make` to list every target. Each is a thin wrapper around SwiftPM.

```sh
make build      # swift build
make test       # swift test --parallel
make demo       # bash scripts/demo.sh: full pipeline against the fake iPhone
make lint       # swift format lint --recursive Sources Tests Package.swift (reports only)
make format     # swift format --in-place ... (rewrites files)
make check      # lint + test + demo: what CI runs; run this before pushing
make run ARGS="run --open"   # run the tool from source
```

One suite or test: `swift test --filter IconLayoutCodecTests`.

Run the tool without a phone, model or network:

```sh
swift run organize-my-iphone run --offline --engine heuristic \
  --cfgutil Tests/Fixtures/fake-cfgutil --workspace /tmp/omi-fake
```

Set `FAKE_CFGUTIL_STATE=<file>` so the fake phone remembers a layout written by `apply`.

## Toolchain

- Swift 6.2 or later (Xcode 26 or later), Swift 6 language mode, macOS 15 or later. The floor comes from
  swift-subprocess 1.0; do not lower it.
- CI runs on GitHub's `xcode-27` (Swift 6.4) and `macos-26` runners; keep both green.
- Dependencies: swift-argument-parser, swift-subprocess, Swift Testing. Do not add a dependency without asking.
- Do not change the machine's global toolchain (no `mise use -g`, no global upgrades). Pin versions in the project
  if one is needed.

## Architecture rules

- Dependencies point one way: `OrganizeCLI → OrganizeAdapters → OrganizeCore`. `OrganizeCore` depends on nothing but
  Foundation.
- `OrganizeCore` does no I/O: no processes, network or disk. Put anything that touches the outside world in
  `OrganizeAdapters`.
- In `OrganizeAdapters`, each outside system has one type behind a protocol (`CommandRunning`, `DeviceClient`,
  `HTTPClient`, `TextCompletionModel`), so tests can swap in a fake.
- `OrganizeCLI` is wiring and wording only. Logic worth testing belongs in Core or Adapters.
- Extension points (see `docs/architecture.md`): a new model backend implements `TextCompletionModel`; a new device
  transport implements `DeviceClient`; a new layout scheme implements `LayoutPlanner`.
- Facts `cfgutil` cannot read (usage, install order, icon colors) reach planners through `PlanContext`, filled by the
  CLI from optional files. A planner must still work without them, use a documented stand-in, and say so in its
  `notes`. Never present a stand-in as real usage data.
- Loose-page layouts must stay within 15 pages: build them with `SectionPacker` or `RankedPacker`, which fold groups
  into folders when pages run out.

## Safety rules (do not weaken)

- Only `apply` and `restore` write to the phone. Never add another code path that writes to a device.
- `apply` and `restore` must reread the phone, validate the plan against it, show the size of the change, save a
  backup, and ask for confirmation before writing.
- Every scan and apply backs up the current layout to `~/.organize-my-iphone/backups/` in `cfgutil`'s format.
- Every `LayoutPlanner` keeps the dock unchanged and places every non-dock icon exactly once. `LayoutValidator`
  enforces the iOS limits in `GridSpec`: 4×6 icons per page, 4 dock slots, 9 icons per folder page, 15 pages.
- Web clips and unrecognized items are carried over, never dropped.
- Never run `apply` or `restore` against a real iPhone as part of agent work. Use the fake `cfgutil` and
  `apply --dry-run`.

## Privacy rules

- App lists stay on the Mac, in the workspace folder outside any repository. Never commit workspace files, scans or
  backups.
- The only network call is the optional App Store lookup, which sends bundle identifiers to Apple. `--offline`
  skips it. Do not add other network calls.
- Classification runs locally. Do not add cloud model backends; Private Cloud Compute is deliberately not used.
- The `--usage`, `--recent` and `--icon-colors` files are read locally and never sent anywhere. Downloading App Store
  icon artwork for the rainbow layout would be a new network call; do not add it without the owner's approval.

## Code style and tests

- `swift format` with `.swift-format`: 120-column lines, 4-space indentation, one argument per line when wrapped.
  `.editorconfig` sets 2 spaces for YAML, JSON and Markdown, tabs in the Makefile.
- Tests use Swift Testing. Add or update tests with every behavior change: Core tests with plain values, Adapter
  tests with fakes.
- Keep the performance budget in mind (`docs/architecture.md#performance-budget`): scan to preview under 2 minutes
  for 1,000 apps, apply under 5 minutes.
- Docs and user-facing text are written plainly: short sentences, no jargon without a definition. Update
  `README.md` and `docs/` when behavior or commands change.

## Git and releases

- Default branch is `main`. CI runs on pushes to `main` and on pull requests.
- Run `make check` before pushing.
- Releases are cut by pushing a `v*` tag; `.github/workflows/release.yml` builds and publishes the binary. Do not
  push tags, open PRs, or push to `main` unless asked.

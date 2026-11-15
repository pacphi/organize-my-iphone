# Usage

## Before you start

1. Install **Apple Configurator** from the Mac App Store. You only need it for the `cfgutil` tool inside it; you never have to open the app.
2. Connect the iPhone with a cable, unlock it, and tap **Trust** if it asks.
3. If the Apple Configurator window is open, quit it. It holds the phone while open.
4. Optional, for better classification: install [Ollama](https://ollama.com) and pull a chat model, or turn on Apple Intelligence (macOS 26 or later).
5. From the project folder, check everything:

```sh
swift run organize-my-iphone doctor
```

```
Workspace: /Users/you/.organize-my-iphone
[ok]   cfgutil: /Applications/Apple Configurator.app/Contents/MacOS/cfgutil
[ok]   iPhone: Your iPhone (iPhone17,1, ECID 0x1A2B3C4D5E6F)
[ok]   Ollama: <your models>
[miss] Apple on-device model: not available on this Mac
```

A `[miss]` on both models is fine: the tool falls back to built-in rules.

To avoid typing `swift run` each time, install the binary with `make install`. It goes to `~/.local/bin`, so make sure that folder is on your `PATH`. The examples below assume that. To install system-wide by hand instead:

```sh
swift build -c release --product organize-my-iphone
sudo install "$(swift build -c release --show-bin-path)/organize-my-iphone" /usr/local/bin/
```

## The usual flow

### 1. Build the proposals

```sh
organize-my-iphone run --open
```

This scans the phone, looks apps up in the App Store, classifies them, builds all twelve layout proposals, and opens a preview page. **Nothing on the phone changes.** [layouts.md](layouts.md) describes each layout.

The terminal shows each proposal's groups and how many icons would move. The preview page shows your current Home Screen and each proposal page by page, with a link to each proposal at the top and notes on any stand-in data it used.

While it runs, each step shows a spinner and a count of elapsed seconds that updates in place, then leaves a line with its total:

```
✓ Engine: Ollama model <model> (loading in the background)
✓ Read apps and Home Screen layout from the iPhone · Your iPhone · 6.2s
  Found 242 app icons on 4 page(s) with 13 folder(s).
✓ Look up 242 app(s) in the App Store · 1.4s
✓ Placed 150 app(s) by App Store genre and built-in rules
✓ Load Ollama model <model> into memory · 0.0s
⠹ Classify 92 app(s) with llm:<model> · batch 2/4 · 25/92 apps · about 9s left
```

What the classification lines mean:

| Line | What is happening |
| --- | --- |
| `Engine: …` | Which engine was chosen. An Ollama model starts loading here, in the background, while the phone is read. |
| `Placed N app(s) by App Store genre and built-in rules` | The apps that need no model: Apple's own, and apps whose store genre settles it. Instant. |
| `Load Ollama model … into memory` | Waiting for the model to finish loading. Often `0.0s`, because it loaded during the scan. |
| `Classify N app(s) with llm:…` | The model working through the remaining apps in batches. `batch 2/4 · 25/92 apps · about 9s left` advances as each batch returns. |

A step that fails ends with `✗ … · failed after 3.1s`.

When output is not a terminal (a pipe, a log file, CI), nothing is redrawn: each step prints one line when it starts and one when it ends. Set `OMI_NO_PROGRESS=1` to get that plain output in a terminal too.

### 2. Adjust if you want

Each step can be rerun on its own, using what earlier steps saved:

```sh
# Try a different model
organize-my-iphone classify --engine ollama --model <model-name>

# Rebuild the proposals with different layout rules
organize-my-iphone plan --one-page-per-category
organize-my-iphone plan --scheme folder-board --min-folder-size 3

# Tell the usage-based layouts how you really use your apps
organize-my-iphone plan --usage ~/my-usage.txt --scheme most-used --scheme essentials

# Build two layouts only
organize-my-iphone plan --scheme alphabetical --scheme rainbow --icon-colors ~/colors.json

# Refresh the page
organize-my-iphone preview --open
```

### 3. Apply

```sh
organize-my-iphone apply folder-board --dry-run   # report only
organize-my-iphone apply folder-board             # backs up, asks, then writes
```

`apply` rereads the phone first. If apps were installed or removed since the scan, it refuses and asks you to run `run` again, so a stale plan can never drop an icon.

### 4. Undo

```sh
organize-my-iphone restore            # the layout from just before the last apply
organize-my-iphone restore --list     # every backup
organize-my-iphone restore --backup ~/.organize-my-iphone/backups/<file>.json
```

## Command reference

### Options every command accepts

| Option | Meaning |
| --- | --- |
| `--workspace <folder>` | Where scans, plans, previews and backups go. Default: `$OMI_WORKSPACE`, else `~/.organize-my-iphone`. |
| `--ecid <ecid>` | Which iPhone to use when several are attached. `doctor` lists ECIDs. |
| `--cfgutil <path>` | Path to `cfgutil`. Default: `$CFGUTIL_PATH`, else the copy inside Apple Configurator. |
| `--taxonomy <file>` | A JSON file of your own categories. See below. |

### `run`

Scan, enrich, classify, plan and preview.

| Option | Meaning |
| --- | --- |
| `--offline` | Skip the App Store lookup. No bundle identifiers leave the Mac. |
| `--country <code>` | App Store storefront for lookups. Default `us`. |
| `--open` | Open the preview when done. |
| `--engine <auto\|heuristic\|ollama\|apple>` | Classification engine. Default `auto`. |
| `--model <name>` | Ollama model. Default: `$OMI_OLLAMA_MODEL`, else a chat-capable model already in memory, else the first installed model that can chat. |
| `--ollama-url <url>` | Ollama server. Default `http://127.0.0.1:11434`. |
| `--batch-size <n>` | Apps per model request. Default 25 for Ollama, 8 for Apple's model. |
| `--thorough` | Ask the model about every app, not only the ones the built-in rules are unsure about. Slower: expect several times the classification time. |
| `--scheme <scheme>` | Build only this layout. Repeat to build several. Default: all twelve. |
| `--one-page-per-category` | Category pages: start each category on a new page. |
| `--min-folder-size <n>` | Folder layouts: smaller groups stay loose. Default 2. |
| `--letter-folders` | Alphabetical: one folder per letter. |
| `--essentials <n>` | Essentials: apps on the essentials page. Default 12. |
| `--new-count <n>` | New and review: apps on the New page. Default 24. |
| `--usage <file>` | Apps, most-used first. Used by most-used, thumb-reach, essentials and new-and-review. |
| `--recent <file>` | Apps, newest install first. Used by new-and-review. |
| `--icon-colors <file>` | JSON of icon colors. Used by rainbow and the preview. |
| `--icon-colors-from-store` | Download App Store icons and find their main colors, for rainbow. Opt-in network call to Apple's image server; skipped with `--offline`. |

[layouts.md](layouts.md) explains each layout, the file formats, and what each layout does without the files.

### `scan`, `enrich`, `classify`, `plan`, `preview`

The individual steps of `run`. `enrich` accepts `--country`, `--refresh` (ignore the cache) and `--icon-colors-from-store` (also find icon colors from App Store artwork; see [layouts.md](layouts.md#icon-colors)). `classify` accepts the engine options listed under `run`. `plan` accepts the layout options, including `--scheme`. `preview` accepts `--open` and the three data files (`--usage`, `--recent`, `--icon-colors`); only `--icon-colors` changes what it shows, by tinting icons. It also writes `colors.html`, the color-wheel page for checking and fixing icon colors.

### `apply <scheme>`

`<scheme>` is one of `category-pages`, `folder-board`, `alphabetical`, `most-used`, `time-of-day`, `verb-folders`, `rainbow`, `thumb-reach`, `places`, `new-and-review`, `essentials` or `life-areas`. The plan must have been built by `run` or `plan` first.

| Option | Meaning |
| --- | --- |
| `--dry-run` | Check the plan against the phone, report what would change, and stop. |
| `--yes` | Do not ask for confirmation. |

### `restore`

| Option | Meaning |
| --- | --- |
| `--backup <file>` | Restore this backup instead of the most recent one. |
| `--list` | List backups and stop. |
| `--yes` | Do not ask for confirmation. |

### `schemes`

Lists every layout, one line on what it looks like, and the data it uses.

### `doctor`

Checks `cfgutil`, the phone, Ollama and Apple's on-device model. Accepts `--ollama-url`.

## Choosing a classification engine

| Engine | Needs | Notes |
| --- | --- | --- |
| `auto` (default) | Nothing | Uses Ollama if it answers, else Apple's model, else rules. Says which it picked and why. |
| `ollama` | Ollama running with a chat model | Best results. Pick the model with `--model`. The model's thinking mode is switched off, because it multiplies the time per request without helping here. |
| `apple` | macOS 26 or later, Apple Intelligence on | Fully on-device and built in. The model is small, so results are coarser. |
| `heuristic` | Nothing | Known Apple apps, a short keyword list, then the App Store genre. Fast and repeatable. |

With any model engine, the built-in rules go first and place the apps they are sure about; the model is asked only about the rest. Add `--thorough` to ask it about every app. Whatever a model skips or gets wrong is filled in by the rules, so every app always gets a category.

With `auto`, embedding models are skipped and a model that is already in memory is preferred. To pin the choice, name a model with `--model` or `OMI_OLLAMA_MODEL`.

### How long it takes

The target is under 2 minutes from scan to preview for a phone with 1,000 apps. Classification is the step that varies: it depends on the model's speed and on how many apps the rules could not place. If a run is slower than you expect:

- Check the `Classify …` line. If nearly every app went to the model, the App Store lookup probably did not run (`--offline`) or found little.
- Try a smaller or faster model with `--model`.
- Do not use `--thorough` on a large phone unless you are happy to wait.

## Your own categories

Copy `examples/taxonomy.json`, edit it, and pass it with `--taxonomy`:

```json
{
  "fallback": "Other",
  "categories": [
    { "name": "Daily", "hint": "apps opened every day: messaging, mail, calendar, notes, browser" },
    { "name": "Money", "hint": "banking, payments, investing, budgeting, tax" }
  ]
}
```

- `name` becomes the folder name on the phone, so keep it short.
- `hint` tells the model what belongs there.
- The order of the list is the order pages and folders appear in.
- `fallback` is where anything unassigned goes. It defaults to `Other`.

Use the same `--taxonomy` for `classify` and `plan` (or just use `run`).

Custom categories work best with a model. The rule-based engine only knows the built-in category names and the App Store's genre names.

## Files the tool writes

All in the workspace folder:

| File | Contents |
| --- | --- |
| `scan.json` | Device, installed apps and layout from the last scan |
| `metadata.json` | Cached App Store lookups |
| `classification.json` | Category, confidence and source for each app |
| `plan-<scheme>.json` | The proposals, one file per layout, such as `plan-rainbow.json` |
| `preview.html` | The comparison page |
| `colors.html` | The color wheel, for checking and fixing icon colors |
| `store-icon-colors.json` | Main colors found from App Store icons (only with `--icon-colors-from-store`) |
| `backups/icon-layout-<time>-scan.json` | Layout at each scan |
| `backups/icon-layout-<time>-before-apply.json` | Layout just before each apply or restore |

Backups are in `cfgutil`'s own format. In an emergency you can restore one without this tool:

```sh
"/Applications/Apple Configurator.app/Contents/MacOS/cfgutil" set-icon-layout <backup-file>
```

## Environment variables

| Variable | Meaning |
| --- | --- |
| `OMI_WORKSPACE` | Default workspace folder |
| `CFGUTIL_PATH` | Path to `cfgutil` |
| `OMI_OLLAMA_MODEL` | Default Ollama model |
| `OMI_NO_PROGRESS` | Set to any value to turn off the live step timers and print plain lines |

## Troubleshooting

| Symptom | Likely cause and fix |
| --- | --- |
| `cfgutil was not found` | Install Apple Configurator, or pass `--cfgutil`. |
| `No iPhone found` | Check the cable, unlock the phone, tap Trust. |
| `...in use...` | Quit the Apple Configurator app. |
| `cfgutil printed something unexpected` while reading the layout | Some `cfgutil` versions stumble on widgets or newer icon types. Note your iOS and Apple Configurator versions and open an issue. |
| Many apps in `Other` | You are on rules only. Start Ollama or pass `--engine apple`. Without `--offline`, App Store genres help too. |
| Classification takes minutes | See "How long it takes" above. The step's line shows batches done and time left. |
| `Ollama not used: …` | Ollama is not running, or has no chat model. Open the Ollama app, or `ollama pull` a model. |
| `This proposal cannot be applied as it stands` | Apps changed since the scan, or the plan needs more than 15 pages. Run `run` again; drop `--one-page-per-category` if you used it. |
| A layout's notes say it used your current icon order | You gave no `--usage` (or `--recent`) file. See [layouts.md](layouts.md#the-extra-data-and-what-happens-without-it). |
| `rainbow` puts most apps under "No color data" | Only Apple's apps have built-in colors. Run `enrich --icon-colors-from-store`, or add an `--icon-colors` file. |
| An app is in the wrong color band | Open `colors.html`, click the right slice on its row, save, and pass the file with `--icon-colors`. |
| The layout did not change after `apply` | Some iOS versions ignore or partly apply layouts. Run `restore`, and note your iOS version in an issue. |
| Icons are on unexpected pages after `apply` | Widgets take grid space the tool cannot see, so iOS may reflow a page. Rearrange by hand or `restore`. |

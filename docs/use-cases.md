# Use cases

Actors: the **User** at the Mac; the **iPhone** connected by cable; a **Local model** (Ollama or Apple's on-device model); the **App Store lookup** service.

| ID | Use case | Command |
| --- | --- | --- |
| UC-01 | Check the setup | `doctor` |
| UC-02 | Build proposals for a phone | `run` |
| UC-03 | Work entirely offline | `run --offline --engine heuristic` |
| UC-04 | Reclassify with a different model | `classify` |
| UC-05 | Use my own categories | `--taxonomy` |
| UC-06 | Change the layout rules | `plan` |
| UC-07 | Review proposals | `preview` |
| UC-08 | Apply a proposal | `apply` |
| UC-09 | Undo | `restore` |
| UC-10 | Pick one of several phones | `--ecid` |
| UC-11 | Try the tool without a phone | `bash scripts/demo.sh` |

---

## UC-01 Check the setup

**Goal:** Know whether a run will work before starting one.
**Preconditions:** The package builds.

**Main flow**
1. The User runs `doctor`.
2. The tool reports the workspace folder.
3. The tool looks for `cfgutil` and reports its path.
4. The tool lists attached iPhones with model and ECID.
5. The tool reports installed Ollama models and whether Apple's on-device model is available.

**Alternatives**
- 3a. `cfgutil` is missing: the tool says where it looked and suggests installing Apple Configurator.
- 4a. No phone answers: the tool suggests checking the cable, unlocking, and tapping Trust.
- 5a. No model is available: reported as missing; runs will use built-in rules.

**Result:** The User knows what, if anything, to fix.

## UC-02 Build proposals for a phone

**Goal:** Get layout proposals and a preview without changing the phone.
**Preconditions:** `cfgutil` installed; one iPhone connected and trusted.

**Main flow**
1. The User runs `run`.
2. The tool reads the layout and installed apps from the iPhone and saves a backup.
3. The tool looks up apps not already cached in the App Store.
4. The tool classifies every app with the best available engine.
5. The tool builds all twelve proposals, validates them, and prints a summary of each.
6. The tool writes the preview page and prints its path.

**Alternatives**
- 2a. The phone is in use by Apple Configurator: the tool says to quit that app.
- 3a. The lookup fails: the tool warns and continues without genres.
- 4a. No model answers: the tool says so and uses rules.
- 4b. The model fails mid-run: affected apps are classified by rules.
- 5a. A proposal breaks an iOS limit (for example, more than 15 pages): the issue is listed under that proposal; `apply` will refuse it.

**Result:** `scan.json`, `classification.json`, twelve plan files and `preview.html` exist in the workspace. The phone is unchanged.

## UC-03 Work entirely offline

**Goal:** Produce proposals with no network traffic at all.

**Main flow**
1. The User runs `run --offline --engine heuristic` (or `--engine ollama` with a model on this Mac).
2. The tool skips the App Store lookup.
3. The rest proceeds as UC-02.

**Result:** Proposals built from the phone's own data and built-in knowledge. Expect more apps in the fallback category when using rules alone.

## UC-04 Reclassify with a different model

**Goal:** Improve categories without rescanning.
**Preconditions:** A scan exists.

**Main flow**
1. The User runs `classify --engine ollama --model <name>`.
2. The tool classifies the scanned apps and replaces `classification.json`.
3. The User runs `plan` and `preview` to see the effect.

**Alternatives**
- 1a. The named model is not installed: Ollama's error is shown; nothing is replaced.

## UC-05 Use my own categories

**Goal:** Organize by categories that match how the User thinks.

**Main flow**
1. The User copies `examples/taxonomy.json` and edits names, hints and order.
2. The User runs `run --taxonomy my-taxonomy.json`.
3. The model is told to use exactly those categories; pages and folders follow the file's order.

**Alternatives**
- 2a. The file cannot be read or parsed: the tool reports the path and the reason and stops.
- 3a. No model is available: rules map only onto categories whose names match built-in or App Store genre names; the rest fall back.

## UC-06 Change the layout rules

**Goal:** Adjust how proposals are laid out without reclassifying.
**Preconditions:** A scan and a classification exist.

**Main flow**
1. The User runs `plan` with layout options such as `--one-page-per-category`, `--min-folder-size <n>`, `--letter-folders`, `--usage <file>` or `--scheme <scheme>` (see [layouts.md](layouts.md)).
2. The tool rebuilds and revalidates the proposal files.

## UC-07 Review proposals

**Goal:** See the current layout and each proposal side by side.
**Preconditions:** A scan exists. Proposals are optional; without them only the current layout is shown.

**Main flow**
1. The User runs `preview --open`.
2. The tool writes `preview.html` and opens it.
3. The User compares pages, folder contents and the number of icons that move.

## UC-08 Apply a proposal

**Goal:** Make the phone match the chosen proposal.
**Preconditions:** The proposal exists; the iPhone is connected.

**Main flow**
1. The User runs `apply <scheme>`.
2. The tool rereads the layout from the iPhone.
3. The tool validates the proposal against that layout and the iOS limits.
4. The tool reports how many icons will change page or folder.
5. The tool saves the current layout as a backup and prints its path.
6. The tool asks for confirmation; the User answers yes.
7. The tool writes the layout to the iPhone.

**Alternatives**
- 1a. `--dry-run`: the flow stops after step 4.
- 3a. The proposal is missing an icon that is on the phone, includes one that is not, or breaks a limit: the tool lists the problems and stops. The User reruns UC-02.
- 6a. The User answers anything but yes: nothing is written.
- 7a. `cfgutil` reports an error: it is shown. The backup from step 5 remains.

**Result:** The phone shows the new layout; a backup of the old one exists.

## UC-09 Undo

**Goal:** Return the phone to an earlier layout.
**Preconditions:** At least one backup exists; the iPhone is connected.

**Main flow**
1. The User runs `restore`.
2. The tool selects the backup made just before the most recent apply.
3. The tool rereads the phone and notes any differences in which icons exist.
4. The tool asks for confirmation; the User answers yes.
5. The tool backs up the current layout, then writes the selected one.

**Alternatives**
- 1a. `--list`: the tool lists backups and stops.
- 1b. `--backup <file>`: that file is used instead.
- 2a. No backups exist: the tool says so and stops.
- 3a. Apps were installed or removed since the backup: the differences are listed; the User decides whether to continue.

## UC-10 Pick one of several phones

**Goal:** Work on the right phone when more than one is attached.

**Main flow**
1. The User runs `doctor` and notes the ECID of the intended phone.
2. The User adds `--ecid <ecid>` to `run`, `apply` and `restore`.

**Alternatives**
- 2a. `--ecid` is omitted with several phones attached: the tool lists them and stops without touching any.
- 2b. The ECID matches no attached phone: the tool says so and stops.

**Note:** Use a separate `--workspace` per phone so scans and backups do not mix.

## UC-11 Try the tool without a phone

**Goal:** See the whole flow, or verify a change to the code, with no device.

**Main flow**
1. The User runs `bash scripts/demo.sh`.
2. The script points the tool at `Tests/Fixtures/fake-cfgutil`, a stand-in that answers like `cfgutil`.
3. The tool scans, classifies with rules, plans and writes a preview.
4. The script applies the folder board to the fake phone and checks the result.
5. The script restores the original layout and checks it is back.

**Result:** A preview page to look at, and confidence that scan through restore work together. CI runs this on every change.

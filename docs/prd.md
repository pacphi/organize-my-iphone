# Product requirements

| | |
| --- | --- |
| Product | organize-my-iphone |
| Version | 0.1.0 |
| Status | First implementation; not yet validated on real hardware |

## Problem

An iPhone that has been in use for years collects well over a hundred apps. The Home Screen ends up as pages of icons in the order they were installed, plus a few half-maintained folders. Finding an app means searching, and tidying up means dragging icons one at a time on a small screen, which few people finish.

iOS offers the App Library, but its categories cannot be changed and it does not touch the Home Screen. Tools that once rearranged icons from a computer mostly stopped working years ago.

## Goal

Let someone reorganize an entire iPhone Home Screen from their Mac in a few minutes, with a result they chose and can undo.

### Objectives

1. Read every app and the current layout from a connected iPhone without changing anything.
2. Sort apps into sensible, user-adjustable categories using a model that runs on the Mac.
3. Offer two complete layout proposals and show them next to the current layout.
4. Apply the chosen proposal to the phone, safely and reversibly.
5. Keep the list of apps private.

### Non-goals

- Installing, deleting or updating apps.
- Managing widgets, wallpapers, Focus modes or the App Library.
- Supervised-device or MDM management.
- Android, or iPadOS in this version.
- A graphical app. This version is a command-line tool.

## Users

Described in [personae.md](personae.md). In short: technically comfortable Mac and iPhone owners with many apps, people who care that their data stays local, and people who set up phones for others.

## Requirements

### Functional

| ID | Requirement | Priority |
| --- | --- | --- |
| F1 | List attached iPhones and select one, by ECID when several are attached | Must |
| F2 | Read installed apps (identifier, name, version) from the phone | Must |
| F3 | Read the Home Screen layout: dock, pages, folders, folder pages, web clips | Must |
| F4 | Preserve any layout item the tool does not recognize | Must |
| F5 | Back up the layout at every scan and before every write | Must |
| F6 | Look up App Store genre and description by bundle identifier, with a cache | Should |
| F7 | Run fully offline on request | Must |
| F8 | Classify apps with a model served by Ollama | Must |
| F9 | Classify apps with Apple's on-device model where available | Should |
| F10 | Classify apps with built-in rules when no model is available | Must |
| F11 | Guarantee every app receives exactly one category | Must |
| F12 | Accept a user-supplied taxonomy | Should |
| F13 | Produce a "category pages" proposal: loose apps clustered by category | Must |
| F14 | Produce a "folder board" proposal: one named folder per category | Must |
| F15 | Leave the dock unchanged | Must |
| F16 | Validate proposals against iOS limits and against the phone's current contents | Must |
| F17 | Render a self-contained HTML preview of the current layout and each proposal | Must |
| F18 | Report how many icons each proposal moves | Should |
| F19 | Apply a proposal only after an explicit command and a confirmation | Must |
| F20 | Refuse to apply a proposal that no longer matches the phone | Must |
| F21 | Restore any backup, defaulting to the layout before the last apply | Must |
| F22 | Offer a dry run of apply | Should |
| F23 | Diagnose the setup (`doctor`) | Should |

### Non-functional

| ID | Requirement |
| --- | --- |
| N1 | **Safety.** No command other than `apply` and `restore` writes to the phone. |
| N2 | **Privacy.** App lists stay on the Mac. The only network call sends bundle identifiers to Apple and can be turned off. |
| N3 | **Reversibility.** Backups are plain files in `cfgutil`'s own format, usable without this tool. |
| N4 | **Repeatability.** The same scan, classification and options give the same proposal. |
| N5 | **Testability.** Decision logic has no I/O; outside systems sit behind protocols. |
| N6 | **Speed.** Scan through preview completes in under 2 minutes for a phone with 1,000 apps, including the App Store lookup and model classification. Applying a proposal completes in under 5 minutes. |
| N9 | **Visible progress.** Every step shows its elapsed time while it runs; model work shows how many apps are done and an estimate of the time left. A run is never silent for long. |
| N7 | **Portability.** Builds with Swift 6.2 or later on macOS 15 or later; CI runs on the newest GitHub macOS image. |
| N8 | **Few dependencies.** Two Swift packages; everything else ships with the toolchain or the OS. |

## Success measures

- A first-time user reaches a preview within 10 minutes of cloning, including installing Apple Configurator.
- A 1,000-app phone goes from scan to preview in under 2 minutes with a local model, and a proposal applies in under 5 minutes.
- With a capable local model, fewer than 10% of apps land in the fallback category.
- Applying and then restoring returns the phone to its exact prior layout.
- No reported case of an icon lost by the tool.

## Risks

| Risk | Likelihood | Effect | Response |
| --- | --- | --- | --- |
| `cfgutil set-icon-layout` is ignored or partly applied on some iOS versions | Medium | Core feature fails on those versions | Dry run, backups, restore; document tested versions; keep `DeviceClient` swappable |
| `cfgutil get-icon-layout` fails on layouts with widgets | Medium | Scan fails | Clear error; add a second read path behind `DeviceClient` |
| Apple changes `cfgutil` output | Low | Parsing breaks | Tolerant parser; fixtures pin known shapes; CI catches regressions in our code |
| A small model classifies poorly | Medium | Proposals feel random | Rules fill gaps; user can name a larger model or a custom taxonomy |
| A model reasons at length or generates slowly | High without care | The 2-minute target is missed by a wide margin (first measured run: about a minute per 25 apps) | Thinking switched off, compact replies, rules place confident apps first, live progress with time left |
| Applying a layout takes longer than expected on a large phone | Unknown | The 5-minute target is missed | One `cfgutil` write, timed on screen; measure on real devices |
| Widgets occupy grid space the planner cannot see | Medium | Pages reflow after apply | Documented; restore available |

## Open questions

1. Which iOS versions accept layouts written by `cfgutil`, and how long does the write take on a phone with several hundred apps? Needs a test matrix on real phones.
2. How does `cfgutil` represent widgets and App Library-only apps in the layout?
3. Should frequently used apps be kept on the first page regardless of category? That needs usage data the tool does not have today.

## Later

- A second device transport as a fallback for reading layouts.
- Real app icons in the preview (`cfgutil get-app-icon`).
- A "keep these where they are" list, and manual ordering within a category.
- Let the model propose the taxonomy itself from the apps it sees.
- iPad grid support.
- A small Mac app on top of the same core.

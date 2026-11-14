# Personae

Four people the tool is built for. They are composites, not real individuals.

## 1. Dana, the app collector

> "I have nine pages of apps and I find everything through search. I'd fix it if it didn't mean an afternoon of dragging icons."

| | |
| --- | --- |
| Role | Independent consultant; tries new tools constantly |
| Devices | Recent MacBook Pro, current iPhone, 180+ apps |
| Comfort | At home in a terminal; runs local models already |

**Goals**
- A Home Screen that reflects how they think about their apps: client work, AI tools, money, travel.
- To see a proposal before anything changes.
- Their own category names, not Apple's.

**Frustrations**
- Dragging icons by hand; pages reflowing mid-drag.
- The App Library's fixed categories.
- Tools that promise this and turn out to be abandoned.

**What they need from the tool**
- `run --open` to get straight to a preview.
- A custom taxonomy and a choice of model.
- A reliable undo.

## 2. Priya, the privacy-first engineer

> "The list of apps on my phone says a lot about me. It's not going to someone's server."

| | |
| --- | --- |
| Role | Security-minded software engineer |
| Devices | Mac with a local model runtime; iPhone with 90 apps |
| Comfort | Reads source before running anything |

**Goals**
- Know exactly what leaves the machine.
- Run the whole thing with no network at all.
- Verify the tool does what it says.

**Frustrations**
- "AI" features that quietly call a cloud service.
- Tools that write to a device without asking.

**What they need from the tool**
- `--offline`, and a plain statement of the one network call there is.
- Local classification only.
- Readable code, tests, and backups in an open format.

## 3. Marcus, the family's IT department

> "I set up everyone's phones. My dad wants big obvious folders; my daughter wants her games on one page."

| | |
| --- | --- |
| Role | The relative everyone hands their phone to |
| Devices | Mac mini; four family iPhones passing through his hands |
| Comfort | Follows instructions happily; not a programmer |

**Goals**
- Tidy a phone in one sitting and hand it back.
- Simple, predictable results: a folder board for his father, category pages for his daughter.
- Not to break anything on someone else's phone.

**Frustrations**
- Being blamed when an app "disappears."
- Setups with many prerequisites.

**What they need from the tool**
- `doctor` to tell him what is missing.
- `--ecid` to be sure which phone he is working on.
- `apply --dry-run`, a confirmation prompt, and `restore`.

## 4. Elena, the advisor who demos

> "My clients ask what local models are actually good for. I want something concrete to show them."

| | |
| --- | --- |
| Role | Advises small teams on adopting AI tools |
| Devices | Laptop on stage or on a call; her own iPhone |
| Comfort | Technical, but short on preparation time |

**Goals**
- A demonstration that is easy to follow and shows a local model doing useful work.
- A visual result she can put on a screen.
- Something clients can try afterwards.

**Frustrations**
- Demos that depend on a network or a device behaving on the day.
- Results that differ every run.

**What they need from the tool**
- `bash scripts/demo.sh` to show the whole flow with no phone attached.
- The HTML preview as the thing to show.
- Repeatable output (temperature 0, deterministic planners).

## What they share

| Need | Dana | Priya | Marcus | Elena |
| --- | :-: | :-: | :-: | :-: |
| See before applying | ● | ● | ● | ● |
| Undo | ● | ● | ● | ○ |
| Fully local | ○ | ● | ○ | ● |
| Custom categories | ● | ○ | ○ | ○ |
| Works without a model | ○ | ○ | ● | ● |
| Clear setup check | ○ | ○ | ● | ● |

● essential  ○ nice to have

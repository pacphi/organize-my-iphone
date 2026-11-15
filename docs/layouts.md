# Layouts

`run` builds twelve layout proposals. They all appear in the preview page, and you can apply any one of them. Run `organize-my-iphone schemes` for a short list in the terminal.

Every layout follows the same rules:

- The dock stays as it is.
- Every icon on the phone is placed exactly once. Nothing is dropped, so nothing goes missing from your Home Screen.
- Web clips and items the tool does not recognize are kept.
- The plan has to fit within iOS limits: 24 icons per page, 9 per folder page and 15 pages. A layout that would need more than 15 pages folds its biggest groups into folders until it fits.

## At a glance

| Scheme | What you get | Extra data it uses |
| --- | --- | --- |
| `category-pages` | Apps stay loose on pages, clustered by category | None |
| `folder-board` | One named folder per category, on as few pages as possible | None |
| `alphabetical` | A to Z across pages, or one folder per letter | None |
| `most-used` | Most-used apps on page 1, the least-used at the back | `--usage` |
| `time-of-day` | Morning, Work day, Evening and Anytime pages | None |
| `verb-folders` | Folders named for what you do: Talk, Watch, Listen, Make, Buy, Go, Track… | None |
| `rainbow` | Pages sorted by each icon's main color | `--icon-colors-from-store`, `--icon-colors` |
| `thumb-reach` | Most-used apps in the bottom rows, where your thumb reaches | `--usage` |
| `places` | Home, Commute, Office, Travel, Gym and Everywhere pages | None |
| `new-and-review` | Newest apps on page 1, apps you no longer use on a Review page | `--recent`, `--usage` |
| `essentials` | One clean page of essentials, everything else in folders you can hide | `--usage` |
| `life-areas` | Work, Money, Health, Family, Learning, Play and Everyday pages | None |

"Extra data" is optional. Each layout still works without it and says in the preview what it used in its place.

## The extra data, and what happens without it

`cfgutil` reads which apps are installed and where their icons sit. It does not read how often you use an app, when you installed it, or what its icon looks like. Those facts come from small files you write, all optional:

| Option | File | Without it |
| --- | --- | --- |
| `--usage <file>` | Apps, most-used first, one per line | Your current icon order stands in for usage: page 1 counts as most-used. |
| `--recent <file>` | Apps, newest install first, one per line | The apps at the end of your current layout are treated as the newest. That is a guess: it holds when new apps were added after your last icon and you have not moved them since. |
| `--icon-colors <file>` | A JSON object from app to color | Colors come from App Store icons if you have run `--icon-colors-from-store`, else only Apple's own apps have colors, from a built-in table. Other apps go in "No color data". |

All three are read on your Mac and never sent anywhere. Pass them to `run`, `plan` or `preview`.

Icon colors can also be found automatically. See [Icon colors](#icon-colors) below.

### Usage and install-order files

One app per line, by bundle identifier (`com.spotify.client`) or display name (`Spotify`, ignoring case). Blank lines and lines that start with `#` are skipped. A leading `1.` or `1)` is ignored, so a numbered list works.

```text
# Copied from Settings > Screen Time > See All App & Website Activity
1. Messages
2. Safari
3. Spotify
4. com.openai.chat
```

To build a usage file, open **Settings > Screen Time > See All App & Website Activity** on the phone and copy the order of the apps list. Apps you leave out count as least used. Lines that match no app on the phone are listed as a warning and otherwise ignored. When a line matches both a bundle identifier and another app's name, the bundle identifier wins.

## Icon colors

The rainbow layout needs each icon's main color. Colors come from three places, and a later one overrides an earlier one:

1. **Built in.** Apple's own apps, from a table in the tool.
2. **App Store icons (opt-in).** `organize-my-iphone enrich --icon-colors-from-store` (or `run --icon-colors-from-store`) downloads each app's icon from Apple's image server, shrinks it to 32 by 32 pixels on your Mac, and matches every pixel to a slice of the color wheel. The slice with the most pixels wins, and the icon's color is the average of those pixels. So a blue icon with a white logo comes out blue, and a white icon with a small red mark comes out white. Results are saved in `store-icon-colors.json` in the workspace, so each icon is fetched once. `--refresh` fetches them again.
3. **Your file.** `--icon-colors <file>`, for anything you want to correct.

This is the one opt-in network call besides the App Store lookup. It requests only the icon links the lookup returned, only from Apple's image hosts (`mzstatic.com`), and the images are not kept. `--offline` skips it.

### Fixing colors on the color wheel

`preview` (and `run`) also write `colors.html` next to the preview page, linked from its top. It shows a color wheel with the number of apps in each slice: eight hues around the outside and white, gray and black in the middle. Click a slice to list its apps. To move an app, click the slice it belongs in on its row. **Save icon-colors.json** downloads your changes, plus anything already in your `--icon-colors` file, and you rebuild with:

```sh
organize-my-iphone plan --icon-colors ~/Downloads/icon-colors.json
```

The page works offline. Unlike the preview, it runs a small script, because it is a tool you click in.

### Icon-colors file

A JSON object. The keys are bundle identifiers or display names, and the values are `#RRGGBB` colors:

```json
{
  "Spotify": "#1DB954",
  "com.netflix.Netflix": "#E50914",
  "PayPal": "#003087"
}
```

Your colors override the built-in ones. The preview page tints each icon with its known color, so the file is easy to check.

## Each layout in detail

### `category-pages` and `folder-board`

The two original layouts. See the [README](../README.md). On a phone with more apps than 15 pages can hold, `category-pages` now folds its largest categories into folders instead of producing a plan iOS would refuse.

### `alphabetical`

Apps run A to Z across pages, filling each page. Accents are ignored (É files under E), and names that start with a digit or symbol go under `#` after Z. Page labels show the range, such as `A–F`.

With `--letter-folders` you get one folder per letter instead. Letters with fewer apps than `--min-folder-size` stay loose.

### `most-used`

Your most-used apps fill page 1, row by row from the top left, and the rest follow in order. When the apps need more than 15 pages, the least used go into folders by category on the last pages.

### `thumb-reach`

The same order as `most-used`, but on every full page the most-used apps of that page go in the bottom rows. Rank 1 sits bottom left, the bottom row fills first, and the top row holds the least used of the page. A page that is not full keeps plain rank order, because iOS moves icons up to fill any gap.

### `time-of-day`, `places` and `life-areas`

Each starts every bucket on a fresh page and clusters the apps inside it by category. If a bucket needs more than one page, its pages are numbered, such as `Home (2)`.

| Time of day | Categories |
| --- | --- |
| Morning | News & Reading, Health, Sports, Lifestyle |
| Work day | Work, Productivity, AI, Communication, Browsers, Finance |
| Evening | Entertainment, Games, Music & Audio, Social, Photo & Video, Shopping, Food & Drink |
| Anytime | Travel, Home, Learning, Utilities, Other |

| Place | Categories |
| --- | --- |
| Home | Home, Entertainment, Games, Food & Drink, Shopping, Lifestyle |
| Commute | Music & Audio, News & Reading, Learning |
| Office | Work, Productivity, AI, Browsers |
| Travel | Travel |
| Gym | Health, Sports |
| Everywhere | Communication, Social, Finance, Photo & Video, Utilities, Other |

| Life area | Categories |
| --- | --- |
| Work | Work, Productivity, AI, Browsers |
| Money | Finance, Shopping |
| Health | Health, Sports, Food & Drink |
| Family | Communication, Social, Home, Photo & Video |
| Learning | Learning, News & Reading |
| Play | Games, Entertainment, Music & Audio, Travel |
| Everyday | Lifestyle, Utilities, Other |

The tool cannot change Focus settings, but these pages are built to pair with them. After applying `places` or `time-of-day`, go to **Settings > Focus**, pick a Focus such as Work, tap the Home Screen picture under **Customize Screens**, and tick the matching page.

### `verb-folders`

One folder per verb:

| Verb | Categories |
| --- | --- |
| Talk | Communication, Social |
| Watch | Entertainment |
| Listen | Music & Audio |
| Make | Photo & Video |
| Buy | Shopping, Food & Drink |
| Go | Travel |
| Track | Health, Finance, Sports |
| Read | News & Reading, Learning |
| Play | Games |
| Work | Work, Productivity, AI |
| Browse | Browsers |
| Tools | Utilities, Home, Lifestyle, Other |

Verbs with fewer apps than `--min-folder-size` stay loose.

With your own `--taxonomy`, categories these tables do not name go to the last bucket of each table: Anytime, Everywhere, Everyday or Tools.

### `rainbow`

Apps are sorted into color bands: red, orange, yellow, green, teal, blue, purple, pink, then white, gray and black for pale or dark icons. Within a band they run by shade. Apps with no known color come last, under "No color data". The preview's notes say how many there are.

Only Apple's own apps have built-in colors. Run `enrich --icon-colors-from-store` once to color nearly everything else, then fix any odd matches on the [color wheel](#fixing-colors-on-the-color-wheel).

### `new-and-review`

- **Page 1, New:** the newest apps, one page of them by default. Change the count with `--new-count`.
- **The middle:** everything else, clustered by category.
- **Review, at the back:** the apps your `--usage` file does not mention. These are candidates to delete. Without a usage file there is no Review page.

### `essentials`

Page 1 holds your top apps by usage, 12 by default (`--essentials <n>`, up to 24). Everything else goes into category folders on the following pages. No app is removed, because a plan that drops icons would make iOS place them wherever it likes.

To see only the essentials, hide the other pages on the phone: touch and hold the Home Screen, tap the page dots, and untick every page except the first. The apps stay in the App Library and in search.

## Options for the layouts

| Option | Layouts | Meaning |
| --- | --- | --- |
| `--one-page-per-category` | category-pages | Start every category on a new page. |
| `--min-folder-size <n>` | folder-board, alphabetical, verb-folders, essentials | Groups smaller than this stay loose. Default 2. |
| `--letter-folders` | alphabetical | One folder per letter. |
| `--essentials <n>` | essentials | Apps on the essentials page. Default 12, at most 24. |
| `--new-count <n>` | new-and-review | Apps on the New page. Default one page (24). |
| `--usage <file>` | most-used, thumb-reach, essentials, new-and-review | Usage order. |
| `--recent <file>` | new-and-review | Install order. |
| `--icon-colors <file>` | rainbow, and icon tints in the preview | Icon colors that override the built-in and App Store ones. |
| `--icon-colors-from-store` | rainbow (on `run` and `enrich`) | Find colors from App Store icons. Opt-in network call. |
| `--scheme <scheme>` | all (`run` and `plan`) | Build only this layout. Repeat to build several. |

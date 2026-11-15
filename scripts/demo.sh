#!/bin/bash
# Runs the whole tool against a fake iPhone (Tests/Fixtures/fake-cfgutil): scan, classify,
# plan, preview, apply and restore. No device, model or network is needed, so this doubles
# as the end-to-end check in CI.
#
#   bash scripts/demo.sh [workspace-folder]

set -euo pipefail
cd "$(dirname "$0")/.."

WORKSPACE="${1:-$(mktemp -d)/omi-demo}"
FAKE="Tests/Fixtures/fake-cfgutil"
chmod +x "$FAKE"

# The fake phone remembers the layout it was last given in this file.
export FAKE_CFGUTIL_STATE="$WORKSPACE/fake-phone-layout.json"

omi() {
  swift run organize-my-iphone "$@" --cfgutil "$FAKE" --workspace "$WORKSPACE"
}

SCHEMES="category-pages folder-board alphabetical most-used time-of-day verb-folders rainbow thumb-reach places new-and-review essentials life-areas"

# Optional files some layouts use: how much each app is used, and icon colors.
mkdir -p "$WORKSPACE"
cat >"$WORKSPACE/usage.txt" <<'TXT'
# Most-used first, by name or bundle identifier
1. Spotify
2. ChatGPT
3. com.anthropic.claude
4. Instagram
TXT
cat >"$WORKSPACE/icon-colors.json" <<'JSON'
{"Spotify": "#1DB954", "com.netflix.Netflix": "#E50914", "PayPal": "#003087", "Duolingo": "#58CC02"}
JSON

echo "== Scan, classify, plan and preview =="
omi run --offline --engine heuristic --usage "$WORKSPACE/usage.txt" --icon-colors "$WORKSPACE/icon-colors.json"

for file in scan.json classification.json preview.html; do
  test -s "$WORKSPACE/$file" || { echo "missing $file" >&2; exit 1; }
done
for scheme in $SCHEMES; do
  test -s "$WORKSPACE/plan-$scheme.json" || { echo "missing plan-$scheme.json" >&2; exit 1; }
done

echo
echo "== Check every proposal against the fake phone (dry run) =="
for scheme in $SCHEMES; do
  omi apply "$scheme" --dry-run
done

python3 - "$WORKSPACE" <<'PY'
import json, os, sys
workspace = sys.argv[1]
most_used = json.load(open(os.path.join(workspace, "plan-most-used.json")))
assert not most_used.get("notes"), "a usage file was given, so there should be no stand-in note"
top = most_used["groups"][0]["bundleIDs"][:3]
# usage.txt names Spotify and ChatGPT by display name and Claude by bundle identifier.
assert top == ["com.spotify.client", "com.openai.chat", "com.anthropic.claude"], f"usage order not followed: {top}"
print("Most used, page 1:", most_used["pageLabels"][0])
rainbow = json.load(open(os.path.join(workspace, "plan-rainbow.json")))
bands = [group["category"] for group in rainbow["groups"]]
assert bands[0] == "Red", f"rainbow should start with red, found {bands}"
print("Rainbow bands:", ", ".join(bands))
PY

echo
echo "== Apply the folder board to the fake phone =="
omi apply folder-board --yes

python3 - "$FAKE_CFGUTIL_STATE" <<'PY'
import json, sys
layout = json.load(open(sys.argv[1]))
folders = [item[0] for item in layout[1] if isinstance(item, list)]
assert len(layout[0]) == 4, "the dock should be untouched"
assert "AI" in folders, f"expected an AI folder, found {folders}"
print("The fake phone now has these folders:", ", ".join(folders))
PY

echo
echo "== Restore the previous layout =="
omi restore --yes

python3 - "$FAKE_CFGUTIL_STATE" <<'PY'
import json, sys
layout = json.load(open(sys.argv[1]))
assert layout[1][0] == "com.apple.Maps", "the original first page should be back"
assert len(layout) == 3, "the original two pages should be back"
print("The fake phone is back to its original layout.")
PY

echo
echo "Demo finished. Preview: $WORKSPACE/preview.html"

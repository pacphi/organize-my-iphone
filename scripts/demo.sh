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

echo "== Scan, classify, plan and preview =="
omi run --offline --engine heuristic

for file in scan.json classification.json plan-category-pages.json plan-folder-board.json preview.html; do
  test -s "$WORKSPACE/$file" || { echo "missing $file" >&2; exit 1; }
done

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

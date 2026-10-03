#!/usr/bin/env bash
# Installs the lean Claude Code setup into ~/.claude.
# Backs up every file it replaces to ~/.claude/backup-<timestamp>/ first.
set -euo pipefail

SRC="$(cd "$(dirname "$0")/claude" && pwd)"
DEST="${CLAUDE_HOME:-$HOME/.claude}"
BACKUP="$DEST/backup-$(date +%Y%m%d-%H%M%S)"

mkdir -p "$DEST/agents"

backup() {
  if [ -e "$DEST/$1" ]; then
    mkdir -p "$BACKUP/$(dirname "$1")"
    cp -p "$DEST/$1" "$BACKUP/$1"
    echo "  backed up $1"
  fi
}

echo "Installing into $DEST"

for f in CLAUDE.md agents/explorer.md agents/researcher.md agents/worker.md; do
  backup "$f"
  cp "$SRC/$f" "$DEST/$f"
  echo "  installed $f"
done

# Merge only model, effortLevel and advisorModel; keep every other setting.
backup settings.json
python3 - "$SRC/settings.json" "$DEST/settings.json" <<'PY'
import json, os, sys
src, dest = sys.argv[1], sys.argv[2]
with open(src) as f:
    new = json.load(f)
cur = {}
if os.path.exists(dest):
    with open(dest) as f:
        cur = json.load(f)
cur.update(new)
with open(dest, "w") as f:
    json.dump(cur, f, indent=2)
    f.write("\n")
PY
echo "  merged settings.json (model, effortLevel, advisorModel)"

if [ -d "$BACKUP" ]; then
  echo "Previous files saved in $BACKUP"
  echo "If you had your own CLAUDE.md rules, copy them back from there."
fi
echo "Done. Start a new Claude Code session to use the setup."

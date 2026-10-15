#!/usr/bin/env bash
# Installs the lean Claude Code setup into ~/.claude.
# Backs up every file it changes to ~/.claude/backup-<timestamp>/ first.
# Usage: ./install.sh [--force]   (--force replaces model settings you already have)
set -euo pipefail

FORCE=0
case "${1:-}" in
  "") ;;
  --force) FORCE=1 ;;
  *) echo "Usage: $0 [--force]" >&2; exit 2 ;;
esac

SRC="$(cd "$(dirname "$0")/claude" && pwd)"
DEST="${CLAUDE_HOME:-$HOME/.claude}"
BACKUP="$DEST/backup-$(date +%Y%m%d-%H%M%S)"

echo "Installing into $DEST"
mkdir -p "$DEST"
MERGED="$(mktemp "$DEST/settings.json.XXXXXX")"
trap 'rm -f "$MERGED"' EXIT

# Build the merged settings in a temp file first, so a settings.json that
# isn't plain JSON stops the install before any file is touched.
if ! python3 - "$SRC/settings.json" "$DEST/settings.json" "$MERGED" "$FORCE" <<'PY'
import json, os, sys
src, dest, out, force = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] == "1"
with open(src) as f:
    new = json.load(f)
cur = {}
if os.path.exists(dest):
    try:
        with open(dest) as f:
            cur = json.load(f)
    except json.JSONDecodeError as e:
        sys.exit(f"Error: {dest} is not valid JSON ({e}).\n"
                 "Fix it (comments and trailing commas are not allowed), then run the installer again.")
    if not isinstance(cur, dict):
        sys.exit(f"Error: {dest} must contain a JSON object.")
def merge(cur, new, path=""):
    for key, value in new.items():
        name = path + key
        if isinstance(value, dict) and isinstance(cur.get(key), dict):
            # Nested objects such as modelSettings: merge entry by entry.
            merge(cur[key], value, name + ".")
        elif key not in cur or cur[key] == value:
            cur[key] = value
            print(f"  settings: {name} = {json.dumps(value)}")
        elif force:
            print(f"  settings: {name} = {json.dumps(value)} (was {json.dumps(cur[key])})")
            cur[key] = value
        else:
            print(f"  settings: kept your {name} = {json.dumps(cur[key])} (run with --force to use {json.dumps(value)})")
merge(cur, new)
with open(out, "w") as f:
    json.dump(cur, f, indent=2)
    f.write("\n")
PY
then
  exit 1
fi

backup() {
  if [ -e "$DEST/$1" ]; then
    mkdir -p "$BACKUP/$(dirname "$1")"
    cp -p "$DEST/$1" "$BACKUP/$1"
    echo "  backed up $1"
  fi
}

# Copies $1 to $DEST/$2, backing up the old file. Skips identical files.
install_file() {
  if [ -e "$DEST/$2" ] && cmp -s "$1" "$DEST/$2"; then
    echo "  unchanged $2"
    return
  fi
  backup "$2"
  mkdir -p "$(dirname "$DEST/$2")"
  cp "$1" "$DEST/$2"
  echo "  installed $2"
}

for f in CLAUDE.md agents/explorer.md agents/researcher.md agents/worker.md agents/reviewer.md \
         skills/ship/SKILL.md; do
  install_file "$SRC/$f" "$f"
done

# Earlier versions replaced the built-in Explore agent with a Haiku one, which
# weakened plan mode's research. Remove that override if it is ours.
OLD_EXPLORE="agents/Explore.md"
if [ -e "$DEST/$OLD_EXPLORE" ] && grep -qx 'name: Explore' "$DEST/$OLD_EXPLORE" \
   && grep -qx 'model: haiku' "$DEST/$OLD_EXPLORE"; then
  backup "$OLD_EXPLORE"
  rm "$DEST/$OLD_EXPLORE"
  echo "  removed $OLD_EXPLORE (built-in Explore restored)"
fi

if [ -e "$DEST/settings.json" ] && cmp -s "$MERGED" "$DEST/settings.json"; then
  echo "  unchanged settings.json"
else
  backup settings.json
  # Write through, not mv: keeps the file's permissions and any symlink.
  cat "$MERGED" > "$DEST/settings.json"
  echo "  merged settings.json"
fi

if [ -d "$BACKUP" ]; then
  echo "Previous files saved in $BACKUP"
  if [ -e "$BACKUP/CLAUDE.md" ]; then
    echo "If you had your own CLAUDE.md rules, copy them back from there."
  fi
fi
echo "Done. Start a new Claude Code session to use the setup."

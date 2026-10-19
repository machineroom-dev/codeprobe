#!/usr/bin/env bash
# Verify .claude-plugin/plugin.json .version matches the metadata.version in
# skills/codeprobe/SKILL.md. Exit 0 when equal, else print both and exit 1.
# Needs only bash + POSIX tools; jq or python3 are used when available.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
manifest="$root/.claude-plugin/plugin.json"
skill="$root/skills/codeprobe/SKILL.md"

for f in "$manifest" "$skill"; do
  if [ ! -f "$f" ]; then
    echo "check_version_sync: missing $f" >&2
    exit 1
  fi
done

if command -v jq >/dev/null 2>&1; then
  manifest_version="$(jq -r '.version // empty' "$manifest")"
elif command -v python3 >/dev/null 2>&1; then
  manifest_version="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("version", ""))' "$manifest")"
else
  manifest_version="$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$manifest" | head -n1 | sed 's/.*:[[:space:]]*"\([^"]*\)"/\1/' || true)"
fi

skill_version="$(grep -A2 '^metadata:' "$skill" | grep 'version' | head -n1 \
  | sed -e 's/^[[:space:]]*version:[[:space:]]*//' -e 's/[[:space:]]*$//' -e "s/^[\"']//" -e "s/[\"']\$//" || true)"

if [ -n "$manifest_version" ] && [ "$manifest_version" = "$skill_version" ]; then
  echo "version sync OK: $manifest_version"
  exit 0
fi

echo "version mismatch:"
echo "  .claude-plugin/plugin.json version: ${manifest_version:-<none>}"
echo "  skills/codeprobe/SKILL.md metadata.version: ${skill_version:-<none>}"
exit 1

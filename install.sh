#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$HOME/.claude/skills"

echo "Installing code-review-claude..."

# Create skills directory if needed
mkdir -p "$SKILLS_DIR"

# Symlink each skill
for skill_dir in "$SCRIPT_DIR"/skills/*/; do
    skill_name=$(basename "$skill_dir")
    target="$SKILLS_DIR/$skill_name"

    if [ -e "$target" ]; then
        echo "⚠️  $target already exists. Overwrite? (y/N)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            rm -rf "$target"
        else
            echo "Skipping $skill_name"
            continue
        fi
    fi

    ln -s "$skill_dir" "$target"
    echo "✅ Installed $skill_name"
done

# Check Python
if command -v python3 &>/dev/null; then
    echo "✅ Python 3 found: $(python3 --version)"
else
    echo "⚠️  Python 3 not found. /review health stats will be unavailable."
fi

echo ""
echo "Installation complete! Available commands:"
echo "  /review audit <path>         Full code audit"
echo "  /review quick <path>         Top 5 issues"
echo "  /review health <path>        Codebase vitals"
echo "  /review solid <path>         SOLID principles check"
echo "  /review security <path>      Security audit"
echo "  /review smells <path>        Code smells detection"
echo "  /review architecture <path>  Architecture analysis"

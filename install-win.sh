#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$HOME/.claude/skills"

echo "Installing code-review-claude (Windows)..."

# Create skills directory if needed
mkdir -p "$SKILLS_DIR"

# Copy each skill (Windows may not support symlinks without developer mode)
for skill_dir in "$SCRIPT_DIR"/skills/*/; do
    skill_name=$(basename "$skill_dir")
    target="$SKILLS_DIR/$skill_name"

    if [ -e "$target" ]; then
        if [ -t 0 ]; then
            echo "Warning: $target already exists. Overwrite? (y/N)"
            read -r response
            if [[ ! "$response" =~ ^[Yy]$ ]]; then
                echo "Skipping $skill_name"
                continue
            fi
        fi
        rm -rf "$target"
    fi

    # Try symlink first; fall back to copy if symlinks are not supported
    if ln -s "$skill_dir" "$target" 2>/dev/null; then
        echo "Installed $skill_name (symlink)"
    else
        cp -r "$skill_dir" "$target"
        echo "Installed $skill_name (copy)"
    fi
done

# Check Python
if command -v python3 &>/dev/null; then
    echo "Python 3 found: $(python3 --version)"
elif command -v python &>/dev/null; then
    echo "Python found: $(python --version)"
else
    echo "Warning: Python not found. /review health stats will be unavailable."
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
echo "  /review patterns <path>      Design patterns analysis"
echo "  /review performance <path>   Performance audit"
echo "  /review errors <path>        Error handling audit"
echo "  /review tests <path>         Test quality audit"
echo "  /review framework <path>     Framework best practices"

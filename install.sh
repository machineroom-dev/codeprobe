#!/bin/bash
set -e

SKILLS_DIR="$HOME/.claude/skills"

# Detect if running via curl pipe (no script file on disk)
if [ -t 0 ] || [ -f "$0" ]; then
    # Running directly -- use script's directory
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
else
    # Running via curl | bash -- clone to temp dir
    TMPDIR=$(mktemp -d)
    echo "Cloning code-review-claude..."
    git clone --quiet https://github.com/nishilbhave/code-review-claude.git "$TMPDIR/code-review-claude"
    SCRIPT_DIR="$TMPDIR/code-review-claude"
    trap "rm -rf '$TMPDIR'" EXIT
fi

echo "Installing code-review-claude..."

# Create skills directory if needed
mkdir -p "$SKILLS_DIR"

# Symlink each skill
for skill_dir in "$SCRIPT_DIR"/skills/*/; do
    skill_name=$(basename "$skill_dir")
    target="$SKILLS_DIR/$skill_name"

    if [ -e "$target" ]; then
        if [ -t 0 ]; then
            echo "⚠️  $target already exists. Overwrite? (y/N)"
            read -r response
            if [[ ! "$response" =~ ^[Yy]$ ]]; then
                echo "Skipping $skill_name"
                continue
            fi
        fi
        rm -rf "$target"
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
echo "  /review patterns <path>      Design patterns analysis"
echo "  /review performance <path>   Performance audit"
echo "  /review errors <path>        Error handling audit"
echo "  /review tests <path>         Test quality audit"
echo "  /review framework <path>     Framework best practices"

#!/usr/bin/env bash
# Laravel Best Practice Skills — Installer (macOS / Linux)
# Usage: curl -fsSL https://raw.githubusercontent.com/sasabajic/laravel-best-practice-skills/main/install.sh | bash
# Or locally: chmod +x install.sh && ./install.sh

set -e

VERSION="2.0.0"
SKILLS_DIR="$HOME/.copilot/skills"
TEMP_DIR="/tmp/laravel-best-practice-skills-$$"
REPO_URL="https://github.com/sasabajic/laravel-best-practice-skills.git"

echo ""
echo "================================================"
echo "  Laravel Best Practice Skills — Installer v$VERSION"
echo "  github.com/sasabajic/laravel-best-practice-skills"
echo "================================================"
echo ""

# Check if git is available
if ! command -v git &> /dev/null; then
    echo "ERROR: git is not installed or not in PATH."
    echo "Please install git and try again."
    exit 1
fi

# Create skills directory if it doesn't exist
if [ ! -d "$SKILLS_DIR" ]; then
    echo "Creating skills directory: $SKILLS_DIR"
    mkdir -p "$SKILLS_DIR"
fi

# Clone to temp directory
echo "Cloning repository..."
rm -rf "$TEMP_DIR"
git clone --depth 1 "$REPO_URL" "$TEMP_DIR" 2>/dev/null

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to clone repository."
    exit 1
fi

# Copy all skill folders (folders containing SKILL.md)
COUNT=0
for dir in "$TEMP_DIR"/*/; do
    if [ -f "${dir}SKILL.md" ]; then
        folder_name=$(basename "$dir")
        cp -r "$dir" "$SKILLS_DIR/$folder_name"
        echo "  Installed: $folder_name"
        COUNT=$((COUNT + 1))
    fi
done

# Also copy .github folder if it exists (prompt templates)
if [ -d "$TEMP_DIR/.github" ]; then
    cp -r "$TEMP_DIR/.github" "$SKILLS_DIR/.github"
    echo "  Installed: .github (prompt templates)"
fi

# Copy project documentation files
for file in README.md CHANGELOG.md CONTRIBUTING.md LICENSE; do
    if [ -f "$TEMP_DIR/$file" ]; then
        cp "$TEMP_DIR/$file" "$SKILLS_DIR/$file"
        echo "  Copied: $file"
    fi
done

# Cleanup temp directory
rm -rf "$TEMP_DIR"

echo ""
echo "Done! Installed $COUNT skills (v$VERSION) to:"
echo "  $SKILLS_DIR"
echo ""
echo "Installed skills:"
for dir in "$SKILLS_DIR"/laravel-*/; do
    if [ -f "${dir}SKILL.md" ]; then
        echo "  • $(basename "$dir")"
    fi
done
for dir in "$SKILLS_DIR"/ai-*/; do
    if [ -f "${dir}SKILL.md" ]; then
        echo "  • $(basename "$dir")"
    fi
done
for dir in "$SKILLS_DIR"/skill-*/; do
    if [ -f "${dir}SKILL.md" ]; then
        echo "  • $(basename "$dir")"
    fi
done
echo ""
echo "To update later, run this script again."
echo ""

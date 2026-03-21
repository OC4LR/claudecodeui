#!/bin/bash
# =============================================================================
# Install everything-claude-code Repository
# =============================================================================
# Repository: https://github.com/affaan-m/everything-claude-code
#
# This script clones the everything-claude-code repository which contains:
# - 18+ agents (architect, code-reviewer, tdd-guide, etc.)
# - 50+ skills (golang-patterns, python-testing, springboot-patterns, etc.)
# - 50+ commands (/tdd, /plan, /e2e, /build-fix, etc.)
# - rules (coding standards for common + language-specific)
# - hooks (hooks.json with automation scripts)
# Note: mcp-configs is excluded (using existing MCP setup instead)
#
# Usage:
#   TARGET_DIR=/opt/everything-claude-code ./install-everything-claude-code.sh
# =============================================================================

set -euo pipefail

TARGET_DIR="${TARGET_DIR:-/opt/everything-claude-code}"
REPO_URL="https://github.com/affaan-m/everything-claude-code"

echo "=================================================="
echo "Installing everything-claude-code"
echo "=================================================="
echo "Target Directory: $TARGET_DIR"
echo "Repository: $REPO_URL"
echo ""

# Check if git is available
if ! command -v git &> /dev/null; then
    echo "Error: git is required but not installed."
    exit 1
fi

# Remove existing directory if present
if [ -d "$TARGET_DIR" ]; then
    echo "Removing existing installation at $TARGET_DIR..."
    rm -rf "$TARGET_DIR"
fi

# Create parent directory
mkdir -p "$(dirname "$TARGET_DIR")"

# Clone the repository (shallow clone for faster download)
echo "Cloning repository..."
git clone --depth 1 "$REPO_URL" "$TARGET_DIR"

# Remove .git directory to save space (we don't need git history in production)
rm -rf "$TARGET_DIR/.git"

# Remove mcp-configs directory (using existing MCP setup instead)
rm -rf "$TARGET_DIR/mcp-configs"
echo "Removed mcp-configs (using existing MCP setup)"

# Verify installation
echo ""
echo "Verifying installation..."

if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Failed to create target directory"
    exit 1
fi

# Count components
AGENT_COUNT=$(find "$TARGET_DIR/agents" -name "*.md" 2>/dev/null | wc -l || echo "0")
SKILL_COUNT=$(find "$TARGET_DIR/skills" -type d -mindepth 1 -maxdepth 1 2>/dev/null | wc -l || echo "0")
COMMAND_COUNT=$(find "$TARGET_DIR/commands" -name "*.md" 2>/dev/null | wc -l || echo "0")
RULES_COUNT=$(find "$TARGET_DIR/rules" -type d -mindepth 1 -maxdepth 1 2>/dev/null | wc -l || echo "0")

echo ""
echo "=================================================="
echo "Installation Complete!"
echo "=================================================="
echo "Installed to: $TARGET_DIR"
echo ""
echo "Components:"
echo "  - Agents:   $AGENT_COUNT files"
echo "  - Skills:   $SKILL_COUNT directories"
echo "  - Commands: $COMMAND_COUNT files"
echo "  - Rules:    $RULES_COUNT language directories"
echo ""

# List some key components
if [ -d "$TARGET_DIR/agents" ]; then
    echo "Sample Agents:"
    ls "$TARGET_DIR/agents"/*.md 2>/dev/null | head -5 | xargs -n1 basename | sed 's/^/    - /'
    echo "    ..."
fi

if [ -d "$TARGET_DIR/skills" ]; then
    echo ""
    echo "Sample Skills:"
    ls -d "$TARGET_DIR/skills"/*/ 2>/dev/null | head -5 | xargs -n1 basename | sed 's/^/    - /'
    echo "    ..."
fi

echo ""
echo "Done!"

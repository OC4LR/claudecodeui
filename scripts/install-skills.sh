#!/bin/bash
# -----------------------------------------------------------------------------
# Install Claude Code Skills from GitHub Repositories
# -----------------------------------------------------------------------------
# This script downloads Claude Code skills from various GitHub repositories:
# - vercel-labs/agent-skills: react-best-practices
# - jeffallan/claude-skills: golang-pro, laravel-specialist
#
# NOTE: superpowers is installed as a PLUGIN via entrypoint.sh, not here.
# The plugin installation includes all 14+ superpowers skills with hooks.
# -----------------------------------------------------------------------------

set -e

SKILL_DIR="${SKILL_DIR:-/opt/claude-skills}"

mkdir -p "$SKILL_DIR"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           Installing Claude Code Skills                       ║"
echo "║   (superpowers installed separately as plugin)                ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# -----------------------------------------------------------------------------
# Download individual skills from other repos
# -----------------------------------------------------------------------------
BASE_URL="https://raw.githubusercontent.com"

# Skill definitions: "repo|path|output_name"
INDIVIDUAL_SKILLS=(
  # react-best-practices from vercel-labs/agent-skills
  "vercel-labs/agent-skills|skills/react-best-practices/SKILL.md|react-best-practices.md"
  # golang-pro from jeffallan/claude-skills
  "jeffallan/claude-skills|skills/golang-pro/SKILL.md|golang-pro.md"
  # laravel-specialist from jeffallan/claude-skills
  "jeffallan/claude-skills|skills/laravel-specialist/SKILL.md|laravel-specialist.md"
)

download_skill() {
  local repo=$1
  local path=$2
  local output=$3
  local url="$BASE_URL/$repo/main/$path"

  if curl -fsSL "$url" -o "$SKILL_DIR/$output" 2>/dev/null; then
    echo "  ✓ $output"
    return 0
  else
    echo "  ✗ $output (not found at $url)"
    return 1
  fi
}

echo ""
echo "📦 Downloading individual skills..."
for skill_def in "${INDIVIDUAL_SKILLS[@]}"; do
  repo="${skill_def%%|*}"
  rest="${skill_def#*|}"
  path="${rest%%|*}"
  output="${rest##*|}"
  download_skill "$repo" "$path" "$output"
done

TOTAL_SKILLS=$(find "$SKILL_DIR" -name "*.md" -type f 2>/dev/null | wc -l)

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "✅ Done! Installed $TOTAL_SKILLS individual skills in $SKILL_DIR"
echo "   Note: superpowers installed as plugin via entrypoint.sh"
echo "═══════════════════════════════════════════════════════════════"

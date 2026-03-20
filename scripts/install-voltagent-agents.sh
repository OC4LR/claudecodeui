#!/bin/bash
# -----------------------------------------------------------------------------
# Install VoltAgent Subagents from GitHub
# Repository: https://github.com/VoltAgent/awesome-claude-code-subagents
# -----------------------------------------------------------------------------

set -e

BASE_URL="https://raw.githubusercontent.com/VoltAgent/awesome-claude-code-subagents/main/categories"
AGENT_DIR="${AGENT_DIR:-/home/node/.claude/agents}"

# Create agents directory
mkdir -p "$AGENT_DIR"

# -----------------------------------------------------------------------------
# Language Specialists (02-language-specialists)
# -----------------------------------------------------------------------------
LANG_AGENTS=(
  "typescript-pro"
  "python-pro"
  "golang-pro"
  "rust-engineer"
  "php-pro"
  "laravel-specialist"
  "react-specialist"
  "vue-expert"
  "nextjs-developer"
  "javascript-pro"
  "sql-pro"
  "swift-expert"
  "angular-architect"
  "cpp-pro"
  "csharp-developer"
  "django-developer"
  "dotnet-core-expert"
  "elixir-expert"
  "flutter-expert"
  "java-architect"
  "kotlin-specialist"
  "rails-expert"
  "spring-boot-engineer"
)

# -----------------------------------------------------------------------------
# Infrastructure (03-infrastructure)
# -----------------------------------------------------------------------------
INFRA_AGENTS=(
  "cloud-architect"
  "database-administrator"
  "deployment-engineer"
  "devops-engineer"
  "docker-expert"
  "kubernetes-specialist"
  "network-engineer"
  "platform-engineer"
  "security-engineer"
  "sre-engineer"
  "terraform-engineer"
)

# -----------------------------------------------------------------------------
# Quality & Security (04-quality-security)
# -----------------------------------------------------------------------------
QA_AGENTS=(
  "code-reviewer"
  "debugger"
  "performance-engineer"
  "qa-expert"
  "security-auditor"
  "test-automator"
  "penetration-tester"
  "compliance-auditor"
  "chaos-engineer"
  "accessibility-tester"
)

# -----------------------------------------------------------------------------
# Meta & Orchestration (09-meta-orchestration)
# -----------------------------------------------------------------------------
META_AGENTS=(
  "agent-installer"
  "agent-organizer"
  "context-manager"
  "knowledge-synthesizer"
  "multi-agent-coordinator"
  "task-distributor"
  "workflow-orchestrator"
  "error-coordinator"
  "performance-monitor"
)

# -----------------------------------------------------------------------------
# Download function
# -----------------------------------------------------------------------------
download_agent() {
  local category=$1
  local agent=$2
  local url="$BASE_URL/$category/$agent.md"
  local output="$AGENT_DIR/$agent.md"

  if curl -fsSL "$url" -o "$output" 2>/dev/null; then
    echo "  ✓ $agent"
    return 0
  else
    echo "  ✗ $agent (not found)"
    return 1
  fi
}

# -----------------------------------------------------------------------------
# Main installation
# -----------------------------------------------------------------------------
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           Installing VoltAgent Subagents                     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

echo "📂 Target directory: $AGENT_DIR"
echo ""

echo "🔧 Language Specialists (${#LANG_AGENTS[@]} agents)..."
for agent in "${LANG_AGENTS[@]}"; do
  download_agent "02-language-specialists" "$agent"
done

echo ""
echo "🏗️  Infrastructure (${#INFRA_AGENTS[@]} agents)..."
for agent in "${INFRA_AGENTS[@]}"; do
  download_agent "03-infrastructure" "$agent"
done

echo ""
echo "🔒 Quality & Security (${#QA_AGENTS[@]} agents)..."
for agent in "${QA_AGENTS[@]}"; do
  download_agent "04-quality-security" "$agent"
done

echo ""
echo "🎯 Meta & Orchestration (${#META_AGENTS[@]} agents)..."
for agent in "${META_AGENTS[@]}"; do
  download_agent "09-meta-orchestration" "$agent"
done

# Count installed agents
INSTALLED=$(find "$AGENT_DIR" -name "*.md" -type f 2>/dev/null | wc -l)

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "✅ Done! Installed $INSTALLED agents in $AGENT_DIR"
echo "═══════════════════════════════════════════════════════════════"

#!/bin/bash
# =============================================================================
# Entrypoint Script untuk CloudCLI UI
# =============================================================================
# Script ini menjalankan setup saat container dimulai:
# - Setup Claude credentials dari environment variables
# - Switch ke non-root user
# =============================================================================

set -e

# Colors untuk output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# =============================================================================
# Install everything-claude-code Resources
# =============================================================================
install_everything_claude_code() {
    log_info "Installing everything-claude-code resources..."

    # Check if source directory exists
    if [ ! -d "/opt/everything-claude-code" ]; then
        log_warn "/opt/everything-claude-code not found, skipping"
        return 0
    fi

    # Determine config directory based on current user
    if [ "$(id -u)" = "0" ]; then
        local CONFIG_DIR="/home/node/.claude"
    else
        local CONFIG_DIR="$HOME/.claude"
    fi

    # Install Agents (merge with existing VoltAgent agents)
    if [ -d "/opt/everything-claude-code/agents" ]; then
        local AGENTS_DIR="$CONFIG_DIR/agents"
        mkdir -p "$AGENTS_DIR"
        local EXISTING_COUNT=$(ls -1 "$AGENTS_DIR"/*.md 2>/dev/null | wc -l)
        cp -r /opt/everything-claude-code/agents/*.md "$AGENTS_DIR/" 2>/dev/null || true
        local NEW_COUNT=$(ls -1 "$AGENTS_DIR"/*.md 2>/dev/null | wc -l)
        log_info "Agents: $EXISTING_COUNT -> $NEW_COUNT files in $AGENTS_DIR"
    fi

    # Install Skills (merge with existing skills)
    if [ -d "/opt/everything-claude-code/skills" ]; then
        local SKILLS_DIR="$CONFIG_DIR/skills"
        mkdir -p "$SKILLS_DIR"
        # Copy skill directories (each skill is a directory with content)
        for skill_dir in /opt/everything-claude-code/skills/*/; do
            if [ -d "$skill_dir" ]; then
                local skill_name=$(basename "$skill_dir")
                if [ ! -d "$SKILLS_DIR/$skill_name" ]; then
                    cp -r "$skill_dir" "$SKILLS_DIR/" 2>/dev/null || true
                fi
            fi
        done
        local SKILL_COUNT=$(ls -d "$SKILLS_DIR"/*/ 2>/dev/null | wc -l)
        log_info "Skills: $SKILL_COUNT skill directories in $SKILLS_DIR"
    fi

    # Install Commands (slash commands)
    if [ -d "/opt/everything-claude-code/commands" ]; then
        local COMMANDS_DIR="$CONFIG_DIR/commands"
        mkdir -p "$COMMANDS_DIR"
        cp -r /opt/everything-claude-code/commands/*.md "$COMMANDS_DIR/" 2>/dev/null || true
        local CMD_COUNT=$(ls -1 "$COMMANDS_DIR"/*.md 2>/dev/null | wc -l)
        log_info "Commands: $CMD_COUNT files in $COMMANDS_DIR"
    fi

    # Install Rules (coding standards)
    if [ -d "/opt/everything-claude-code/rules" ]; then
        local RULES_DIR="$CONFIG_DIR/rules"
        mkdir -p "$RULES_DIR"
        # Copy common rules
        if [ -d "/opt/everything-claude-code/rules/common" ]; then
            mkdir -p "$RULES_DIR/common"
            cp -r /opt/everything-claude-code/rules/common/*.md "$RULES_DIR/common/" 2>/dev/null || true
        fi
        # Copy language-specific rules
        for lang_dir in /opt/everything-claude-code/rules/*/; do
            local lang=$(basename "$lang_dir")
            if [ "$lang" != "common" ]; then
                mkdir -p "$RULES_DIR/$lang"
                cp -r "$lang_dir"*.md "$RULES_DIR/$lang/" 2>/dev/null || true
            fi
        done
        local RULES_COUNT=$(find "$RULES_DIR" -name "*.md" 2>/dev/null | wc -l)
        log_info "Rules: $RULES_COUNT files in $RULES_DIR"
    fi

    # Install Hooks (merge with superpowers hooks)
    if [ -d "/opt/everything-claude-code/hooks" ]; then
        local HOOKS_DIR="$CONFIG_DIR/hooks"
        mkdir -p "$HOOKS_DIR"
        # Copy hook scripts
        if [ -d "/opt/everything-claude-code/hooks/hooks" ]; then
            cp -r /opt/everything-claude-code/hooks/hooks/* "$HOOKS_DIR/" 2>/dev/null || true
        fi
        # Copy hooks.json if exists (will be merged by Claude)
        if [ -f "/opt/everything-claude-code/hooks/hooks.json" ]; then
            cp /opt/everything-claude-code/hooks/hooks.json "$CONFIG_DIR/hooks.json" 2>/dev/null || true
        fi
        log_info "Hooks installed to $HOOKS_DIR"
    fi

    # Install Contexts (development contexts)
    if [ -d "/opt/everything-claude-code/contexts" ]; then
        local CONTEXTS_DIR="$CONFIG_DIR/contexts"
        mkdir -p "$CONTEXTS_DIR"
        cp -r /opt/everything-claude-code/contexts/*.md "$CONTEXTS_DIR/" 2>/dev/null || true
        local CTX_COUNT=$(ls -1 "$CONTEXTS_DIR"/*.md 2>/dev/null | wc -l)
        log_info "Contexts: $CTX_COUNT files in $CONTEXTS_DIR"
    fi

    # Set permissions for node user
    if [ "$(id -u)" = "0" ]; then
        chown -R node:node "$CONFIG_DIR"
    fi

    log_info "everything-claude-code installation complete"
}

# =============================================================================
# Setup Claude Config Directory
# =============================================================================
setup_claude_config() {
    log_info "Setting up Claude config directory..."

    # Setup for both root and node user
    # When running terminal commands as root, we need config in /root
    # When running app as node, we need config in /home/node
    SETUP_USERS=""
    if [ "$(id -u)" = "0" ]; then
        SETUP_USERS="/root /home/node"
    else
        SETUP_USERS="$HOME"
    fi

    for USER_HOME in $SETUP_USERS; do
        CLAUDE_CONFIG_DIR="$USER_HOME/.claude"
        CLAUDE_JSON="$USER_HOME/.claude.json"

        log_info "Setting up Claude config for $USER_HOME..."

        # Ensure directory exists with correct permissions
        mkdir -p "$CLAUDE_CONFIG_DIR"
        mkdir -p "$CLAUDE_CONFIG_DIR/backups"

        # Create .claude.json (main config file) if not exists
        if [ ! -f "$CLAUDE_JSON" ]; then
            log_info "Creating $CLAUDE_JSON..."
            cat > "$CLAUDE_JSON" << 'CLAUDEJSON'
{
  "installMethod": "native",
  "hasSeenWelcome": true,
  "hasCompletedOnboarding": true
}
CLAUDEJSON
        fi
    done

    # Install VoltAgent subagents if available and not already installed
    if [ -d "/opt/voltagent-agents" ] && [ "$(ls -A /opt/voltagent-agents/*.md 2>/dev/null | wc -l)" -gt 0 ]; then
        AGENTS_DIR="$CLAUDE_CONFIG_DIR/agents"
        if [ ! -d "$AGENTS_DIR" ] || [ "$(ls -A $AGENTS_DIR/*.md 2>/dev/null | wc -l)" -eq 0 ]; then
            log_info "Installing VoltAgent subagents from /opt/voltagent-agents..."
            mkdir -p "$AGENTS_DIR"
            cp -r /opt/voltagent-agents/*.md "$AGENTS_DIR/" 2>/dev/null || true
            AGENT_COUNT=$(ls -1 "$AGENTS_DIR"/*.md 2>/dev/null | wc -l)
            log_info "Installed $AGENT_COUNT VoltAgent subagents to $AGENTS_DIR"
        else
            log_info "VoltAgent subagents already installed ($(ls -1 $AGENTS_DIR/*.md 2>/dev/null | wc -l) agents)"
        fi
    fi

    # Install individual Claude Code Skills from external repos (not available as plugins)
    # Note: superpowers skills are installed via plugin system (see install_claude_plugins)
    if [ -d "/opt/claude-skills" ] && [ "$(ls -A /opt/claude-skills/*.md 2>/dev/null | wc -l)" -gt 0 ]; then
        SKILLS_DIR="$CLAUDE_CONFIG_DIR/skills"
        if [ ! -d "$SKILLS_DIR" ] || [ "$(ls -A $SKILLS_DIR/*.md 2>/dev/null | wc -l)" -eq 0 ]; then
            log_info "Installing Claude Code skills from /opt/claude-skills..."
            mkdir -p "$SKILLS_DIR"
            cp -r /opt/claude-skills/*.md "$SKILLS_DIR/" 2>/dev/null || true
            SKILL_COUNT=$(ls -1 "$SKILLS_DIR"/*.md 2>/dev/null | wc -l)
            log_info "Installed $SKILL_COUNT Claude Code skills to $SKILLS_DIR"
        else
            log_info "Claude Code skills already installed ($(ls -1 $SKILLS_DIR/*.md 2>/dev/null | wc -l) skills)"
        fi
    fi

    # Create settings.json dari environment variable
    if [ -n "$CLAUDE_SETTINGS_JSON" ]; then
        log_info "Writing settings.json from CLAUDE_SETTINGS_JSON..."
        # Check if base64 encoded
        if echo "$CLAUDE_SETTINGS_JSON" | base64 -d 2>/dev/null | jq -e . >/dev/null 2>&1; then
            echo "$CLAUDE_SETTINGS_JSON" | base64 -d > "$CLAUDE_CONFIG_DIR/settings.json"
            log_info "Decoded base64 settings.json"
        else
            echo "$CLAUDE_SETTINGS_JSON" > "$CLAUDE_CONFIG_DIR/settings.json"
            log_info "Wrote raw settings.json"
        fi
    elif [ -n "$ANTHROPIC_AUTH_TOKEN" ]; then
        log_info "Creating settings.json with ANTHROPIC_AUTH_TOKEN..."
        cat > "$CLAUDE_CONFIG_DIR/settings.json" << EOF
{
  "\$schema": "https://json.schemastore.org/claude-code-settings.json",
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "$ANTHROPIC_AUTH_TOKEN",
    "ANTHROPIC_BASE_URL": "https://open.bigmodel.cn/api/anthropic",
    "API_TIMEOUT_MS": "9000000",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "glm-4.7",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-4.7",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "glm-5.1",
    "CLAUDE_CODE_MAX_OUTPUT_TOKENS": "16384",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
    "CLAUDE_CODE_DISABLE_TELEMETRY": "1",
    "DISABLE_COST_WARNING": "1",
    "DISABLE_MEMORY_WARNING": "1"
  },
  "permissions": {
    "allow": [
    "Bash(npm *)",
    "Bash(npx *)",
    "Bash(bun *)",
    "Bash(yarn *)",
    "Bash(pnpm *)",
    "Bash(node *)",
    "Bash(docker *)",
    "Bash(docker-compose *)",
    "Bash(git status*)",
    "Bash(git diff*)",
    "Bash(git log*)",
    "Bash(git branch*)",
    "Bash(git checkout*)",
    "Bash(git switch*)",
    "Bash(git pull*)",
    "Bash(git fetch*)",
    "Bash(git stash*)",
    "Bash(git rebase*)",
    "Bash(git merge*)",
    "Bash(git cherry-pick*)",
    "Bash(git restore*)",
    "Bash(git reset HEAD*)",
    "Bash(ls *)",
    "Bash(cat *)",
    "Bash(head *)",
    "Bash(tail *)",
    "Bash(find *)",
    "Bash(which *)",
    "Bash(whereis *)",
    "Bash(echo *)",
    "Bash(pwd)",
    "Bash(whoami)",
    "Bash(mkdir *)",
    "Bash(touch *)",
    "Bash(cp *)",
    "Bash(mv *)",
    "Bash(chmod *)",
    "Bash(chown *)",
    "Bash(grep *)",
    "Bash(sed *)",
    "Bash(awk *)",
    "Bash(jq *)",
    "Bash(yq *)",
    "Bash(curl *)",
    "Bash(wget *)",
    "Bash(python *)",
    "Bash(python3 *)",
    "Bash(pip *)",
    "Bash(pip3 *)",
    "Bash(poetry *)",
    "Bash(uv *)",
    "Bash(php *)",
    "Bash(composer *)",
    "Bash(go *)",
    "Bash(cargo *)",
    "Bash(rustc *)",
    "Bash(make *)",
    "Bash(cmake *)",
    "Bash(gcc *)",
    "Bash(g++ *)",
    "Bash(terraform *)",
    "Bash(kubectl *)",
    "Bash(helm *)",
    "Bash(aws *)",
    "Bash(gcloud *)",
    "Bash(az *)",
    "Bash(gh *)",
    "Bash(tsc *)",
    "Bash(eslint *)",
    "Bash(prettier *)",
    "Bash(vitest *)",
    "Bash(jest *)",
    "Bash(pytest *)",
    "Bash(php artisan *)",
    "Bash(./vendor/bin/*)",
    "Bash(./node_modules/.bin/*)",
    "mcp__*",
    "TodoWrite",
    "Agent",
    "TaskOutput",
    "TaskStop"
    ],
    "deny": []
  },
  "defaultMode": "bypassPermissions",
  "enabledPlugins": {
    "superpowers@superpowers-marketplace": true,
    "context-mode@context-mode": true
  },
  "skipDangerousModePermissionPrompt": true,
  "includeCoAuthoredBy": false,
  "language": "Bahasa Indonesia",
  "fastMode": true,
  "outputStyle": "Explanatory",
  "alwaysThinkingEnabled": true,
  "effortLevel": "medium"
}
EOF
        log_info "Created settings.json with auth token"
    else
        log_warn "No Claude credentials provided. Claude features may not work."
        log_warn "Set CLAUDE_SETTINGS_JSON or ANTHROPIC_AUTH_TOKEN environment variable."
    fi

    # Create credentials.json jika disediakan
    if [ -n "$CLAUDE_CREDENTIALS_JSON" ]; then
        log_info "Writing credentials.json from CLAUDE_CREDENTIALS_JSON..."
        # Check if base64 encoded
        if echo "$CLAUDE_CREDENTIALS_JSON" | base64 -d 2>/dev/null | jq -e . >/dev/null 2>&1; then
            echo "$CLAUDE_CREDENTIALS_JSON" | base64 -d > "$CLAUDE_CONFIG_DIR/.credentials.json"
        else
            echo "$CLAUDE_CREDENTIALS_JSON" > "$CLAUDE_CONFIG_DIR/.credentials.json"
        fi
        chmod 600 "$CLAUDE_CONFIG_DIR/.credentials.json"
    fi

    # Create CLAUDE.md jika disediakan
    if [ -n "$CLAUDE_MD" ]; then
        log_info "Writing CLAUDE.md from CLAUDE_MD..."
        # Check if base64 encoded
        if echo "$CLAUDE_MD" | base64 -d 2>/dev/null | head -1 | grep -q .; then
            echo "$CLAUDE_MD" | base64 -d > "$CLAUDE_CONFIG_DIR/CLAUDE.md"
        else
            echo "$CLAUDE_MD" > "$CLAUDE_CONFIG_DIR/CLAUDE.md"
        fi
    fi

    # Set permissions untuk node user
    chown -R node:node "$CLAUDE_CONFIG_DIR"
    chmod -R 755 "$CLAUDE_CONFIG_DIR"

    log_info "Claude config setup complete at $CLAUDE_CONFIG_DIR"

    # Debug: show what was created
    if [ -f "$CLAUDE_CONFIG_DIR/settings.json" ]; then
        log_info "settings.json created successfully"
    else
        log_warn "settings.json was NOT created"
    fi
}

# =============================================================================
# Setup MCP Servers
# =============================================================================
setup_mcp_servers() {
    log_info "Setting up MCP servers..."

    # Check if claude command is available
    if ! command -v claude &> /dev/null; then
        log_warn "Claude CLI not available, skipping MCP setup"
        return 0
    fi

    # Pre-install npm packages for MCP servers
    log_info "Pre-installing MCP server packages..."
    npm install -g @z_ai/mcp-server @modelcontextprotocol/server-sequential-thinking 2>/dev/null || log_warn "Some npm packages may have failed to install"

    # Add MCP servers using claude mcp add command
    log_info "Adding MCP servers..."

    # zai-mcp-server (stdio)
    claude mcp add -s user zai-mcp-server --env "Z_AI_API_KEY=$ANTHROPIC_AUTH_TOKEN" --env "Z_AI_MODE=ZAI" -- npx -y "@z_ai/mcp-server" 2>/dev/null || log_warn "Failed to add zai-mcp-server"

    # web-search-prime (http)
    claude mcp add -s user -t http web-search-prime "https://api.z.ai/api/mcp/web_search_prime/mcp" --header "Authorization: $ANTHROPIC_AUTH_TOKEN" 2>/dev/null || log_warn "Failed to add web-search-prime"

    # web-reader (http)
    claude mcp add -s user -t http web-reader "https://api.z.ai/api/mcp/web_reader/mcp" --header "Authorization: Bearer $ANTHROPIC_AUTH_TOKEN" 2>/dev/null || log_warn "Failed to add web-reader"

    # zread (http)
    claude mcp add -s user -t http zread "https://api.z.ai/api/mcp/zread/mcp" --header "Authorization: Bearer $ANTHROPIC_AUTH_TOKEN" 2>/dev/null || log_warn "Failed to add zread"

    # context7 (http)
    claude mcp add -s user -t http context7 "https://gitmcp.io/upstash/context7" 2>/dev/null || log_warn "Failed to add context7"

    # sequentialthinking (stdio)
    claude mcp add -s user sequentialthinking -- npx -y "@modelcontextprotocol/server-sequential-thinking" 2>/dev/null || log_warn "Failed to add sequentialthinking"

    log_info "MCP servers configured: zai-mcp-server, web-search-prime, web-reader, zread, context7, sequentialthinking"
}

# =============================================================================
# Fix Permissions (jika running as root)
# =============================================================================
fix_permissions() {
    log_info "Fixing permissions..."

    # Ensure /home/node exists
    mkdir -p /home/node

    # Fix ownership
    chown -R node:node /app
    chown -R node:node /home/node

    log_info "Permissions fixed"
}

# =============================================================================
# Final Claude Ownership Repair (after root-level Claude setup)
# =============================================================================
repair_claude_ownership() {
    local claude_dir="/home/node/.claude"

    log_info "Running final Claude ownership repair before switching users..."

    if [ "$(id -u)" != "0" ]; then
        log_info "Skipping Claude ownership repair because current user is not root"
        return 0
    fi

    if [ ! -e "$claude_dir" ]; then
        log_info "Skipping Claude ownership repair because $claude_dir does not exist"
        return 0
    fi

    chown -R node:node "$claude_dir"
    log_info "Claude ownership repaired for $claude_dir"
}

# =============================================================================
# Switch User dan Execute Command
# =============================================================================
execute_as_user() {
    if [ "$(id -u)" = "0" ]; then
        log_info "Switching to user node..."
        exec gosu node "$@"
    else
        exec "$@"
    fi
}

# =============================================================================
# Install Claude Plugins (includes superpowers with all skills + hooks)
# =============================================================================
install_claude_plugins() {
    log_info "Installing Claude plugins..."

    # Check if claude command is available
    if ! command -v claude &> /dev/null; then
        log_warn "Claude CLI not available, skipping plugin installation"
        return 0
    fi

    # Add marketplaces first (required before we can install from them)
    log_info "Adding plugin marketplaces..."

    # Add superpowers-marketplace from GitHub
    if claude plugins marketplace list 2>/dev/null | grep -q "superpowers-marketplace"; then
        log_info "superpowers-marketplace already configured"
    else
        log_info "Adding superpowers-marketplace..."
        if claude plugins marketplace add obra/superpowers-marketplace; then
            log_info "superpowers-marketplace added successfully"
        else
            log_warn "Failed to add superpowers-marketplace"
        fi
    fi

    # Add context-mode marketplace from GitHub
    if claude plugins marketplace list 2>/dev/null | grep -q "context-mode"; then
        log_info "context-mode marketplace already configured"
    else
        log_info "Adding context-mode marketplace..."
        if claude plugins marketplace add mksglu/context-mode; then
            log_info "context-mode marketplace added successfully"
        else
            log_warn "Failed to add context-mode marketplace"
        fi
    fi

    # Update marketplaces to get latest plugin manifests
    log_info "Updating plugin marketplaces..."
    claude plugins marketplace update 2>/dev/null || log_warn "Failed to update marketplaces"

    # Install superpowers plugin (includes 14+ skills with hooks)
    # This is the CORRECT way to install superpowers - not via file copying
    if claude plugins list 2>/dev/null | grep -q "superpowers"; then
        log_info "superpowers plugin already installed"
    else
        log_info "Installing superpowers plugin..."
        if claude plugins install superpowers@superpowers-marketplace; then
            log_info "superpowers plugin installed successfully"
        else
            log_warn "Failed to install superpowers plugin"
        fi
    fi

    # Install context-mode plugin
    if claude plugins list 2>/dev/null | grep -q "context-mode"; then
        log_info "context-mode plugin already installed"
    else
        log_info "Installing context-mode plugin..."
        if claude plugins install context-mode@context-mode; then
            log_info "context-mode plugin installed successfully"
        else
            log_warn "Failed to install context-mode plugin"
        fi
    fi

    log_info "Plugin installation complete"
}

# =============================================================================
# Main Execution
# =============================================================================
main() {
    # Ensure ~/.local/bin is in PATH for Claude CLI
    export PATH="$HOME/.local/bin:/root/.local/bin:$PATH"

    # Add to shell config for interactive shells (claude doctor check)
    # This must be done for BOTH the current user AND root (if different)
    for user_home in "$HOME" "/root" "/home/node"; do
        if [ -d "$user_home" ]; then
            for shell_rc in "$user_home/.bashrc" "$user_home/.zshrc"; do
                if [ -d "$(dirname "$shell_rc")" ] && ! grep -q 'export PATH.*\.local/bin' "$shell_rc" 2>/dev/null; then
                    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$shell_rc"
                    log_info "Added ~/.local/bin to PATH in $shell_rc"
                fi
            done
        fi
    done

    log_info "=========================================="
    log_info "CloudCLI UI Container Starting"
    log_info "=========================================="
    log_info "Current User: $(whoami) (uid: $(id -u))"
    log_info "HOME env: $HOME"
    log_info "Working Directory: $(pwd)"
    log_info "Claude CLI: $(which claude 2>/dev/null || echo 'not found')"
    log_info "ANTHROPIC_AUTH_TOKEN set: ${ANTHROPIC_AUTH_TOKEN:+YES}"
    log_info "CLAUDE_SETTINGS_JSON set: ${CLAUDE_SETTINGS_JSON:+YES}"
    log_info "=========================================="

    # Fix permissions first
    fix_permissions

    # Note: Claude is installed natively at /root/.local/bin/claude with the actual binary
    # at /root/.local/share/claude/versions/X.X.X/claude
    # We also have a symlink at /usr/local/bin/claude for system-wide access

    # Verify Claude CLI is accessible
    if ! command -v claude &> /dev/null; then
        log_warn "Claude CLI not found in PATH!"
        log_warn "PATH: $PATH"
        log_error "Claude CLI installation failed! Terminal features will not work."
    else
        log_info "Claude CLI verified at: $(which claude)"
    fi

    # Setup ~/.local/bin/claude symlink for claude doctor path check
    # This is needed for BOTH root and node users
    # The native installation is at /root/.local/bin/claude
    NATIVE_CLAUDE="/root/.local/bin/claude"

    if [ -x "$NATIVE_CLAUDE" ]; then
        # For current user (could be root or node)
        mkdir -p "$HOME/.local/bin" 2>/dev/null || true
        if [ ! -L "$HOME/.local/bin/claude" ]; then
            ln -sf "$NATIVE_CLAUDE" "$HOME/.local/bin/claude"
            log_info "Created symlink $HOME/.local/bin/claude -> $NATIVE_CLAUDE"
        fi

        # For root user (if we're running as root and HOME is /home/node)
        if [ "$(id -u)" = "0" ] && [ "$HOME" != "/root" ]; then
            mkdir -p /root/.local/bin 2>/dev/null || true
            if [ ! -L "/root/.local/bin/claude" ]; then
                ln -sf "$NATIVE_CLAUDE" /root/.local/bin/claude
                log_info "Created symlink /root/.local/bin/claude -> $NATIVE_CLAUDE"
            fi
        fi

        # For node user (always create if running as root)
        if [ "$(id -u)" = "0" ]; then
            mkdir -p /home/node/.local/bin 2>/dev/null || true
            if [ ! -L "/home/node/.local/bin/claude" ]; then
                ln -sf "$NATIVE_CLAUDE" /home/node/.local/bin/claude
                chown -R node:node /home/node/.local 2>/dev/null || true
                log_info "Created symlink /home/node/.local/bin/claude -> $NATIVE_CLAUDE"
            fi
        fi
    else
        log_warn "Native Claude installation not found at $NATIVE_CLAUDE"
    fi

    # Remove /usr/local/bin/claude to prevent "multiple installations" warning
    # claude doctor detects /usr/local/bin/claude as "npm-global" even if it's a symlink
    if [ -e "/usr/local/bin/claude" ]; then
        rm -f /usr/local/bin/claude
        log_info "Removed /usr/local/bin/claude to prevent multiple installation detection"
    fi

    # Setup Claude config
    setup_claude_config

    # Setup MCP servers
    setup_mcp_servers

    # Install everything-claude-code resources (agents, skills, commands, rules, hooks)
    install_everything_claude_code

    # Install Claude plugins (superpowers, context-mode)
    install_claude_plugins

    # Final repair in case Claude setup/plugins created root-owned files after initial fix
    repair_claude_ownership

    # Debug: list what's in .claude
    log_info "Contents of /home/node/.claude:"
    ls -la /home/node/.claude/ 2>/dev/null || log_warn "Directory /home/node/.claude not found"

    # Execute the command
    log_info "Starting application: $@"
    execute_as_user "$@"
}

# Run main with all arguments
main "$@"

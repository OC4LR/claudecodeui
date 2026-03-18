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
# Setup Claude Config Directory
# =============================================================================
setup_claude_config() {
    log_info "Setting up Claude config directory..."

    # Always use /home/node/.claude for node user
    CLAUDE_CONFIG_DIR="/home/node/.claude"

    # Ensure directory exists with correct permissions
    mkdir -p "$CLAUDE_CONFIG_DIR"

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
    "ANTHROPIC_BASE_URL": "${ANTHROPIC_BASE_URL:-https://api.anthropic.com}",
    "CLAUDE_CODE_DISABLE_TELEMETRY": "1"
  },
  "permissions": {
    "allow": ["*"],
    "deny": []
  }
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
# Main Execution
# =============================================================================
main() {
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

    # Setup Claude config
    setup_claude_config

    # Debug: list what's in .claude
    log_info "Contents of /home/node/.claude:"
    ls -la /home/node/.claude/ 2>/dev/null || log_warn "Directory /home/node/.claude not found"

    # Execute the command
    log_info "Starting application: $@"
    execute_as_user "$@"
}

# Run main with all arguments
main "$@"

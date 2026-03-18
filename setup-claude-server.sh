#!/bin/bash
# =============================================================================
# Setup Script untuk Claude CLI di Server Dokploy
# =============================================================================
# Jalankan script ini di server Dokploy sebelum deploy aplikasi
#
# Usage:
#   chmod +x setup-claude-server.sh
#   ./setup-claude-server.sh
# =============================================================================

set -e

echo "=== Claude CLI Setup untuk Dokploy ==="
echo ""

# 1. Check jika Claude CLI sudah terinstall
echo "[1/4] Checking Claude CLI installation..."
if command -v claude &> /dev/null; then
    CLAUDE_PATH=$(which claude)
    echo "✓ Claude CLI found at: $CLAUDE_PATH"
else
    echo "✗ Claude CLI not found!"
    echo ""
    echo "Installing Claude CLI..."
    curl -O "https://cdn.bigmodel.cn/install/claude_code_zai_env.sh" && bash ./claude_code_zai_env.sh

    # Add to PATH if needed
    if ! command -v claude &> /dev/null; then
        export PATH="$HOME/.local/bin:$PATH"
        echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> ~/.bashrc
    fi

    CLAUDE_PATH=$(which claude 2>/dev/null || echo "$HOME/.local/bin/claude")
    echo "✓ Claude CLI installed at: $CLAUDE_PATH"
fi

echo ""
echo "Claude CLI path untuk docker-compose.yml: $CLAUDE_PATH"
echo ""

# 2. Check authentication
echo "[2/4] Checking Claude authentication..."
if [ -f "$HOME/.claude/.credentials.json" ]; then
    echo "✓ Credentials found at: $HOME/.claude/.credentials.json"
else
    echo "✗ No credentials found!"
    echo ""
    echo "Please run: claude login"
    echo "Or copy credentials from your local machine:"
    echo "  scp ~/.claude/.credentials.json user@server:~/.claude/"
    exit 1
fi

# 3. Create minimal settings if not exist
echo "[3/4] Setting up Claude config..."
mkdir -p "$HOME/.claude"

if [ ! -f "$HOME/.claude/settings.json" ]; then
    cat > "$HOME/.claude/settings.json" << 'EOF'
{
  "permissions": {
    "allow": ["*"],
    "deny": []
  }
}
EOF
    echo "✓ Created minimal settings.json"
else
    echo "✓ settings.json already exists"
fi

# 4. Show summary
echo ""
echo "[4/4] Setup Summary:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Claude CLI Path : $CLAUDE_PATH"
echo "  Config Directory: $HOME/.claude"
echo ""
echo "  Files in config dir:"
ls -la "$HOME/.claude/" 2>/dev/null | head -10
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "NEXT STEPS:"
echo "1. Update docker-compose.yml volume path jika Claude CLI tidak di /usr/local/bin/claude"
echo "   Current path: $CLAUDE_PATH"
echo ""
echo "2. Deploy ke Dokploy"
echo ""
echo "3. Test dengan: curl http://localhost:3001/health"
echo ""

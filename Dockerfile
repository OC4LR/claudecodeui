# -----------------------------------------------------------------------------
# Stage 1: Builder - Build frontend and compile native modules
# -----------------------------------------------------------------------------
FROM node:22-trixie-slim AS builder

# Install build dependencies (will be discarded)
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    make \
    g++ \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy package files and scripts first (scripts needed for postinstall)
COPY package*.json ./
COPY scripts ./scripts

# Install all dependencies
# Note: Using npm install instead of npm ci for cross-platform compatibility.
# npm ci fails when optional platform-specific dependencies (like @rollup/rollup-linux-arm64-gnu)
# don't match the lock file's architecture (e.g., building ARM64 image from x86_64 host).
RUN rm -f package-lock.json && npm install --no-audit --no-fund

# Copy source and build frontend
COPY . .
RUN npm run build

# Prune devDependencies AFTER build
RUN npm prune --omit=dev

# Cleanup node_modules AFTER prune (this is the key fix!)
RUN npm cache clean --force && \
    rm -rf /root/.npm && \
    find node_modules -type f -name "*.md" -delete 2>/dev/null || true && \
    find node_modules -type f -name "*.ts" ! -name "*.d.ts" -delete 2>/dev/null || true && \
    find node_modules -type f -name "*.map" -delete 2>/dev/null || true && \
    find node_modules -type d -name "test" -exec rm -rf {} + 2>/dev/null || true && \
    find node_modules -type d -name "tests" -exec rm -rf {} + 2>/dev/null || true && \
    find node_modules -type d -name ".github" -exec rm -rf {} + 2>/dev/null || true && \
    find node_modules -type d -name "docs" -exec rm -rf {} + 2>/dev/null || true && \
    find node_modules -type d -name "examples" -exec rm -rf {} + 2>/dev/null || true && \
    find node_modules -type d -name ".git" -exec rm -rf {} + 2>/dev/null || true && \
    find node_modules -type f -name "LICENSE*" -delete 2>/dev/null || true && \
    find node_modules -type f -name "CHANGELOG*" -delete 2>/dev/null || true

# -----------------------------------------------------------------------------
# Stage 2: Production - Minimal runtime image
# -----------------------------------------------------------------------------
FROM node:22-trixie-slim

ARG GO_VERSION=1.24.2
ARG BUN_VERSION=latest

# Install ONLY essential runtime dependencies (NO build tools!)
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    sqlite3 \
    wget \
    curl \
    gosu \
    ca-certificates \
    git \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apt/archives/* \
    && apt-get clean

# Install Go from official binary distribution
RUN ARCH=$(dpkg --print-architecture) && \
    curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz" -o /tmp/go.tar.gz && \
    tar -C /usr/local -xzf /tmp/go.tar.gz && \
    rm /tmp/go.tar.gz && \
    rm -rf /usr/local/go/doc /usr/local/go/blog /usr/local/go/test /usr/local/go/misc && \
    /usr/local/go/bin/go version

# Install Bun - system-wide so both root and node user can access it
RUN curl -fsSL https://bun.sh/install | BUN_INSTALL=/usr/local bash -s -- "${BUN_VERSION}" && \
    bun --version

# Install Claude CLI - keep native installation structure for proper version management
# The install.sh creates:
#   - /root/.local/bin/claude (symlink to versioned binary)
#   - /root/.local/share/claude/versions/X.X.X/claude (actual binary)
RUN curl -fsSL https://claude.ai/install.sh | bash && \
    # Verify installation
    if [ -f "/root/.local/bin/claude" ]; then \
        chmod +x /root/.local/bin/claude; \
    fi && \
    # Remove any leftover at /usr/local/bin to prevent "multiple installations" warning
    # claude doctor detects /usr/local/bin/claude as "npm-global" even if it's a symlink
    rm -f /usr/local/bin/claude && \
    # FIX: Make claude binary accessible to non-root users (node user)
    # The /root directory is normally only accessible by root, but we need
    # the node user to be able to execute claude CLI for terminal sessions
    # CRITICAL: chmod 755 /root is required for non-root users to traverse to /root/.local
    chmod 755 /root && \
    chmod 755 /root/.local && \
    chmod 755 /root/.local/share && \
    chmod -R 755 /root/.local/share/claude && \
    chmod 755 /root/.local/bin

# Install VoltAgent subagents from GitHub to /opt (persisted, not overwritten by volume)
# Repository: https://github.com/VoltAgent/awesome-claude-code-subagents
COPY scripts/install-voltagent-agents.sh /tmp/install-voltagent-agents.sh
RUN chmod +x /tmp/install-voltagent-agents.sh && \
    AGENT_DIR=/opt/voltagent-agents /tmp/install-voltagent-agents.sh && \
    rm /tmp/install-voltagent-agents.sh

# Install Claude Code Skills from GitHub to /opt (persisted, not overwritten by volume)
# Sources: obra/superpowers, vercel-labs/agent-skills, jeffallan/claude-skills
COPY scripts/install-skills.sh /tmp/install-skills.sh
RUN chmod +x /tmp/install-skills.sh && \
    /tmp/install-skills.sh && \
    rm /tmp/install-skills.sh

# Install everything-claude-code from GitHub to /opt (persisted, not overwritten by volume)
# Repository: https://github.com/affaan-m/everything-claude-code
# Contains: 50+ skills, 18+ agents, 50+ commands, rules, hooks, mcp-configs
COPY scripts/install-everything-claude-code.sh /tmp/install-everything-claude-code.sh
RUN chmod +x /tmp/install-everything-claude-code.sh && \
    TARGET_DIR=/opt/everything-claude-code /tmp/install-everything-claude-code.sh && \
    rm /tmp/install-everything-claude-code.sh

# Setup node user
RUN mkdir -p /home/node && \
    chown -R node:node /home/node

WORKDIR /app

# Copy production node_modules from builder (already cleaned)
COPY --from=builder --chown=node:node /app/node_modules ./node_modules

# Copy package files
COPY --chown=node:node package*.json ./

# Copy built application files
COPY --from=builder --chown=node:node /app/dist ./dist
COPY --from=builder --chown=node:node /app/server ./server
COPY --from=builder --chown=node:node /app/shared ./shared
COPY --from=builder --chown=node:node /app/scripts ./scripts

# Copy entrypoint
COPY --chown=node:node docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Create directories
RUN mkdir -p /app/data /home/node/.claude /home/node/workspace /home/node/Projects /home/node/go && \
    chown -R node:node /app /home/node

# Environment - Claude CLI is in /usr/local/bin which is already in PATH
ENV NODE_ENV=production \
    SERVER_PORT=3001 \
    HOST=0.0.0.0 \
    DATABASE_PATH=/app/data/auth.db \
    HOME=/home/node \
    GOPATH=/home/node/go \
    BUN_INSTALL=/usr/local \
    PATH=/usr/local/go/bin:/home/node/.local/bin:/root/.local/bin:$PATH

EXPOSE 3001

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3001/health || exit 1

ENTRYPOINT ["/entrypoint.sh"]
CMD ["node", "server/index.js"]

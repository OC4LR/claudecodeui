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
RUN npm ci --prefer-offline --no-audit

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

# Install Claude CLI - keep native installation structure for proper version management
# The install.sh creates:
#   - /root/.local/bin/claude (symlink to versioned binary)
#   - /root/.local/share/claude/versions/X.X.X/claude (actual binary)
RUN curl -fsSL https://claude.ai/install.sh | bash && \
    # Verify installation
    if [ -f "/root/.local/bin/claude" ]; then \
        # Create shared bin directory and symlink for all users
        mkdir -p /usr/local/bin && \
        ln -sf /root/.local/bin/claude /usr/local/bin/claude && \
        chmod +x /root/.local/bin/claude; \
    fi && \
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
RUN mkdir -p /app/data /home/node/.claude /home/node/workspace /home/node/Projects && \
    chown -R node:node /app /home/node

# Environment - Claude CLI is in /usr/local/bin which is already in PATH
ENV NODE_ENV=production \
    SERVER_PORT=3001 \
    HOST=0.0.0.0 \
    DATABASE_PATH=/app/data/auth.db \
    HOME=/home/node

EXPOSE 3001

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3001/health || exit 1

ENTRYPOINT ["/entrypoint.sh"]
CMD ["node", "server/index.js"]

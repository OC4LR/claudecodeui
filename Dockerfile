# Multi-stage build untuk optimasi ukuran image
# Menggunakan Debian-slim (glibc) karena node-pty tidak support Alpine (musl)
FROM node:20-slim AS builder

# Install build dependencies untuk native modules
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    make \
    g++ \
    git \
    bash \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy semua source files
COPY . .

# Install all dependencies dan build native modules
RUN npm ci

# Build frontend
RUN npm run build

# Prune devDependencies setelah build (native modules sudah ter-compile)
RUN npm prune --omit=dev

# Production stage
FROM node:20-slim

# Install runtime dependencies dan Claude CLI
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    sqlite3 \
    wget \
    curl \
    gosu \
    ca-certificates \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Install Claude CLI dan Task-Master-AI during build
RUN curl -fsSL https://claude.ai/install.sh | bash || true && \
    npm install -g task-master-ai

# Pastikan user node memiliki home directory yang proper
# Di node:20-slim, user node sudah ada tapi mungkin tidak memiliki home dir
RUN mkdir -p /home/node && \
    chown -R node:node /home/node && \
    chmod 755 /home/node

WORKDIR /app

# Copy node_modules dengan native modules yang sudah di-compile
COPY --from=builder /app/node_modules ./node_modules

# Copy package files
COPY package*.json ./

# Copy built files from builder
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/server ./server
COPY --from=builder /app/shared ./shared
COPY --from=builder /app/scripts ./scripts

# Copy entrypoint script
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Create data directory, .claude directory, dan workspace directory
# WORKSPACES_ROOT adalah tempat user akan meletakkan project mereka
RUN mkdir -p /app/data && \
    mkdir -p /home/node/.claude && \
    mkdir -p /home/node/workspace && \
    mkdir -p /home/node/Projects && \
    chown -R node:node /app && \
    chown -R node:node /home/node && \
    chmod -R 755 /home/node

# Environment defaults
ENV NODE_ENV=production
ENV SERVER_PORT=3001
ENV HOST=0.0.0.0
ENV DATABASE_PATH=/app/data/auth.db
ENV HOME=/home/node
ENV PATH="/root/.local/bin:${PATH}"

EXPOSE 3001

# Health check (endpoint sudah ada di /health)
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3001/health || exit 1

# Use entrypoint to setup config at runtime
ENTRYPOINT ["/entrypoint.sh"]
CMD ["node", "server/index.js"]

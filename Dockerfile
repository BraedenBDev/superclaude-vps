# SuperClaude Docker Environment
# Expo + Supabase development with Claude Code
#
# Works on both Intel (amd64) and Apple Silicon (arm64)

FROM ubuntu:24.04

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install base dependencies (added jq for claude-start JSON parsing)
# Using chromium instead of google-chrome for ARM64 compatibility
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    wget \
    jq \
    ca-certificates \
    gnupg \
    build-essential \
    python3 \
    python3-pip \
    chromium-browser \
    && rm -rf /var/lib/apt/lists/*

# Set Chromium as the default browser for Chrome DevTools MCP
ENV CHROME_BIN=/usr/bin/chromium-browser
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

# Install Node.js 22 (required for Expo)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Bun
RUN curl -fsSL https://bun.sh/install | bash
ENV BUN_INSTALL="/root/.bun"
ENV PATH="$BUN_INSTALL/bin:$PATH"

# Install uv (for Python MCP servers)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

# Install Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code

# Install vtsls globally for TypeScript LSP
RUN bun add -g @vtsls/language-server typescript

# Install Expo CLI and EAS CLI
RUN bun add -g expo-cli eas-cli

# Install Maestro for E2E testing (skip on ARM if it fails)
RUN curl -Ls "https://get.maestro.mobile.dev" | bash || echo "Maestro install skipped (may not support this architecture)"
ENV PATH="/root/.maestro/bin:$PATH"

# Create workspace
WORKDIR /workspace

# Copy configuration files
COPY .claude/ /workspace/.claude/
COPY .mcp.json /workspace/.mcp.json
COPY CLAUDE.md /workspace/CLAUDE.md
COPY setup.sh /workspace/setup.sh
COPY claude-start /usr/local/bin/claude-start

# Make scripts executable
RUN chmod +x /workspace/setup.sh /usr/local/bin/claude-start

# Create entrypoint script with reset support
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
echo ""\n\
echo "╔═══════════════════════════════════════════╗"\n\
echo "║     SuperClaude Docker Environment        ║"\n\
echo "╚═══════════════════════════════════════════╝"\n\
echo ""\n\
\n\
# Handle reset request\n\
if [ "$SUPERCLAUDE_RESET" = "true" ]; then\n\
    echo "🔄 Resetting SuperClaude configuration..."\n\
    rm -f /root/.claude/plugins-installed\n\
    rm -f /root/.claude/mcp.json\n\
    rm -rf /root/.claude/plugins/\n\
    rm -rf /root/.claude/marketplaces/\n\
    echo "✓ Configuration reset complete"\n\
    echo ""\n\
fi\n\
\n\
# Show MCP-CLI status\n\
if [ "$ENABLE_EXPERIMENTAL_MCP_CLI" = "true" ]; then\n\
    echo "✓ MCP-CLI enabled (85%+ token savings)"\n\
else\n\
    echo "○ MCP-CLI disabled (set ENABLE_EXPERIMENTAL_MCP_CLI=true to enable)"\n\
fi\n\
echo ""\n\
\n\
# Check if Claude is authenticated\n\
if ! claude --version &> /dev/null; then\n\
    echo "Claude Code not configured."\n\
    echo "Run: claude"\n\
    echo "Then authenticate via browser."\n\
fi\n\
\n\
# Install plugins if not already installed\n\
if [ ! -f "/root/.claude/plugins-installed" ]; then\n\
    echo "Installing plugins..."\n\
    /workspace/setup.sh || true\n\
    touch /root/.claude/plugins-installed\n\
fi\n\
\n\
# Keep container running or run provided command\n\
if [ "$#" -eq 0 ]; then\n\
    echo ""\n\
    echo "Ready! Commands:"\n\
    echo "  docker exec -it claude-dev claude-start"\n\
    echo "  docker exec -it claude-dev claude"\n\
    echo ""\n\
    echo "To reset config (preserves login):"\n\
    echo "  docker exec -e SUPERCLAUDE_RESET=true -it claude-dev /entrypoint.sh"\n\
    echo ""\n\
    tail -f /dev/null\n\
else\n\
    exec "$@"\n\
fi\n\
' > /entrypoint.sh && chmod +x /entrypoint.sh

# Expose ports
# 8081 - Expo Metro bundler
# 19000 - Expo DevTools
# 19001 - Expo DevTools
# 19002 - Expo DevTools
# 37777 - claude-mem web viewer
EXPOSE 8081 19000 19001 19002 37777

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"]

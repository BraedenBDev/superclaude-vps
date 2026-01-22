#!/bin/bash

# SuperClaude Setup Script
# One-command setup for Expo + Supabase development with Claude Code

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        SuperClaude Setup                  ║${NC}"
echo -e "${BLUE}║   Expo + Supabase Development Config      ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════╝${NC}"
echo ""

# ─────────────────────────────────────────────
# Prerequisites Check
# ─────────────────────────────────────────────

echo -e "${BLUE}Checking prerequisites...${NC}"

# Check Claude Code
if ! command -v claude &> /dev/null; then
    echo -e "${RED}✗ Claude Code not found${NC}"
    echo "  Install: https://claude.ai/code"
    exit 1
fi
echo -e "${GREEN}✓ Claude Code${NC}"

# Check Bun
if ! command -v bun &> /dev/null; then
    echo -e "${YELLOW}⚠ Bun not found. Installing...${NC}"
    curl -fsSL https://bun.sh/install | bash
    export PATH="$HOME/.bun/bin:$PATH"
fi
echo -e "${GREEN}✓ Bun $(bun --version)${NC}"

# Check Node (still needed for some Expo commands)
if ! command -v node &> /dev/null; then
    echo -e "${RED}✗ Node.js not found (required for Expo)${NC}"
    echo "  Install Node.js 18+ from nodejs.org"
    exit 1
fi
echo -e "${GREEN}✓ Node.js $(node --version)${NC}"

echo ""

# ─────────────────────────────────────────────
# Step 1: Superpowers Plugin
# ─────────────────────────────────────────────

echo -e "${BLUE}[1/5] Installing Superpowers...${NC}"
claude plugin marketplace add obra/superpowers-marketplace 2>/dev/null || true
claude plugin install superpowers@superpowers-marketplace 2>/dev/null || echo "  Already installed"
echo -e "${GREEN}✓ Superpowers (TDD, planning, subagents)${NC}"
echo ""

# ─────────────────────────────────────────────
# Step 2: TypeScript LSP
# ─────────────────────────────────────────────

echo -e "${BLUE}[2/5] Installing TypeScript LSP...${NC}"
claude plugin marketplace add boostvolt/claude-code-lsps 2>/dev/null || true
claude plugin install vtsls@claude-code-lsps 2>/dev/null || echo "  Already installed"

# Install vtsls binary globally
if ! command -v vtsls &> /dev/null; then
    bun add -g @vtsls/language-server typescript 2>/dev/null || npm install -g @vtsls/language-server typescript
fi
echo -e "${GREEN}✓ vtsls LSP (code intelligence)${NC}"
echo ""

# ─────────────────────────────────────────────
# Step 3: Claude-Mem Plugin
# ─────────────────────────────────────────────

echo -e "${BLUE}[3/5] Installing Claude-Mem...${NC}"
claude plugin marketplace add thedotmack/claude-mem 2>/dev/null || true
claude plugin install claude-mem@claude-mem 2>/dev/null || echo "  Already installed"
echo -e "${GREEN}✓ claude-mem (persistent memory)${NC}"
echo ""

# ─────────────────────────────────────────────
# Step 4: Additional Plugins
# ─────────────────────────────────────────────

echo -e "${BLUE}[4/5] Installing additional plugins...${NC}"
claude plugin install code-simplifier 2>/dev/null || echo "  Already installed"
echo -e "${GREEN}✓ code-simplifier (refactoring)${NC}"
echo ""

# ─────────────────────────────────────────────
# Step 5: MCP Servers
# ─────────────────────────────────────────────

echo -e "${BLUE}[5/5] Installing MCP servers...${NC}"

claude mcp add apple-docs -- npx apple-doc-mcp-server@latest 2>/dev/null || echo "  apple-docs: skipped"
echo -e "  ${GREEN}✓${NC} Apple Docs"

claude mcp add context7 -- npx -y @upstash/context7-mcp@latest 2>/dev/null || echo "  context7: skipped"
echo -e "  ${GREEN}✓${NC} Context7"

claude mcp add chrome-devtools -- npx -y chrome-devtools-mcp@latest 2>/dev/null || echo "  chrome-devtools: skipped"
echo -e "  ${GREEN}✓${NC} Chrome DevTools (web debugging)"

claude mcp add --transport http linear-server https://mcp.linear.app/mcp 2>/dev/null || echo "  linear: skipped"
echo -e "  ${GREEN}✓${NC} Linear"

claude mcp add --transport http sentry https://mcp.sentry.dev/mcp 2>/dev/null || echo "  sentry: skipped"
echo -e "  ${GREEN}✓${NC} Sentry"

claude mcp add-json github '{"type":"http","url":"https://api.githubcopilot.com/mcp/"}' 2>/dev/null || echo "  github: skipped"
echo -e "  ${GREEN}✓${NC} GitHub"

claude mcp add git -- uvx mcp-server-git --repository "$(pwd)" 2>/dev/null || echo "  git: skipped"
echo -e "  ${GREEN}✓${NC} Git"

claude mcp add grep -- uvx grep-mcp 2>/dev/null || echo "  grep: skipped"
echo -e "  ${GREEN}✓${NC} Grep"

echo ""

# ─────────────────────────────────────────────
# Create Directory Structure
# ─────────────────────────────────────────────

echo -e "${BLUE}Creating directory structure...${NC}"
mkdir -p .claude/agents
mkdir -p .claude/commands
mkdir -p .claude/skills
mkdir -p .claude/context
mkdir -p .github/workflows

# Backup existing CLAUDE.md
if [ -f "CLAUDE.md" ]; then
    cp CLAUDE.md CLAUDE.md.backup
    echo -e "${YELLOW}⚠ Backed up existing CLAUDE.md${NC}"
fi

echo -e "${GREEN}✓ Directories created${NC}"
echo ""

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────

echo -e "${BLUE}╔═══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           Setup Complete! 🎉              ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Installed:${NC}"
echo "  • Superpowers (workflow orchestration)"
echo "  • vtsls LSP (TypeScript intelligence)"
echo "  • claude-mem (persistent memory)"
echo "  • code-simplifier (refactoring)"
echo "  • 8 MCP servers (including Chrome DevTools)"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo ""
echo "  1. ${GREEN}Restart Claude Code${NC}"
echo ""
echo "  2. ${GREEN}Enable MCP-CLI for 85%+ token savings:${NC}"
echo "     export ENABLE_EXPERIMENTAL_MCP_CLI=true"
echo "     claude"
echo ""
echo "  3. Verify setup:"
echo "     /plugin list"
echo "     /mcp"
echo ""
echo "  4. Authenticate MCP servers (Linear, Sentry)"
echo ""
echo "  5. Copy config files to your project:"
echo "     cp CLAUDE.md /path/to/your/project/"
echo "     cp -r .claude /path/to/your/project/"
echo ""
echo -e "${GREEN}Usage:${NC}"
echo "  Say \"Let's build [feature]\" and Superpowers takes over."
echo ""
echo -e "${YELLOW}Install global command (optional):${NC}"
echo "  ./install-global.sh"
echo "  # Then use 'claude-start' from any project directory"
echo ""

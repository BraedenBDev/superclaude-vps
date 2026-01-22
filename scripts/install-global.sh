#!/bin/bash

# install-global.sh - Install claude-start command globally
#
# This installs the claude-start command so you can run it from any directory.

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Install claude-start globally         ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════╝${NC}"
echo ""

# Check if claude-start exists
if [ ! -f "$SCRIPT_DIR/claude-start" ]; then
    echo -e "${RED}✗ claude-start not found in $SCRIPT_DIR${NC}"
    exit 1
fi

# Determine install location
INSTALL_DIR=""

if [ -d "/usr/local/bin" ] && [ -w "/usr/local/bin" ]; then
    INSTALL_DIR="/usr/local/bin"
elif [ -d "$HOME/.local/bin" ]; then
    INSTALL_DIR="$HOME/.local/bin"
elif [ -d "$HOME/bin" ]; then
    INSTALL_DIR="$HOME/bin"
else
    # Create ~/.local/bin
    mkdir -p "$HOME/.local/bin"
    INSTALL_DIR="$HOME/.local/bin"
fi

echo -e "Install location: ${CYAN}$INSTALL_DIR${NC}"
echo ""

# Check if we need sudo
NEEDS_SUDO=false
if [ ! -w "$INSTALL_DIR" ]; then
    NEEDS_SUDO=true
    echo -e "${YELLOW}⚠ Requires sudo to install to $INSTALL_DIR${NC}"
fi

# Install
echo -e "${BLUE}Installing claude-start...${NC}"

if [ "$NEEDS_SUDO" = true ]; then
    sudo cp "$SCRIPT_DIR/claude-start" "$INSTALL_DIR/claude-start"
    sudo chmod +x "$INSTALL_DIR/claude-start"
else
    cp "$SCRIPT_DIR/claude-start" "$INSTALL_DIR/claude-start"
    chmod +x "$INSTALL_DIR/claude-start"
fi

echo -e "${GREEN}✓${NC} Installed to $INSTALL_DIR/claude-start"

# Check if in PATH
if ! command -v claude-start &> /dev/null; then
    echo ""
    echo -e "${YELLOW}⚠ $INSTALL_DIR is not in your PATH${NC}"
    echo ""
    echo "Add this to your ~/.bashrc or ~/.zshrc:"
    echo ""
    echo -e "  ${GREEN}export PATH=\"$INSTALL_DIR:\$PATH\"${NC}"
    echo ""
    echo "Then run: source ~/.bashrc (or ~/.zshrc)"
fi

echo ""
echo -e "${GREEN}Installation complete!${NC}"
echo ""
echo -e "${YELLOW}Usage:${NC}"
echo "  claude-start              # Start in current directory"
echo "  claude-start /path/to/dir # Start in specified directory"
echo "  claude-start --status     # Show session status"
echo "  claude-start --new        # Force new session"
echo ""

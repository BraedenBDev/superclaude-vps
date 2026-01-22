#!/bin/bash

# SuperClaude Docker Setup
# One-command setup for Claude Code development environment
#
# Usage:
#   ./docker-setup.sh                    # Build and start
#   ./docker-setup.sh --with-supabase    # Include local Supabase
#   ./docker-setup.sh --shell            # Start and open shell
#   ./docker-setup.sh --claude           # Start and launch Claude Code
#   ./docker-setup.sh --reset            # Reset config volume and rebuild
#   ./docker-setup.sh --reset-soft       # Reset plugins only (preserves login)

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Parse arguments
WITH_SUPABASE=false
OPEN_SHELL=false
LAUNCH_CLAUDE=false
RESET_FULL=false
RESET_SOFT=false

for arg in "$@"; do
    case $arg in
        --with-supabase)
            WITH_SUPABASE=true
            ;;
        --shell)
            OPEN_SHELL=true
            ;;
        --claude)
            LAUNCH_CLAUDE=true
            ;;
        --reset)
            RESET_FULL=true
            ;;
        --reset-soft)
            RESET_SOFT=true
            ;;
        --help|-h)
            echo "SuperClaude Docker Setup"
            echo ""
            echo "Usage: ./docker-setup.sh [options]"
            echo ""
            echo "Options:"
            echo "  --with-supabase   Include local Supabase database"
            echo "  --shell           Open bash shell after starting"
            echo "  --claude          Launch Claude Code after starting"
            echo "  --reset           Full reset: remove config volume, rebuild (requires re-auth)"
            echo "  --reset-soft      Soft reset: clear plugins only (preserves login)"
            echo "  --help, -h        Show this help message"
            echo ""
            echo "Reset Examples:"
            echo "  ./docker-setup.sh --reset          # Clean slate, need to re-login"
            echo "  ./docker-setup.sh --reset --claude # Reset then launch Claude"
            echo "  ./docker-setup.sh --reset-soft     # Fix plugin conflicts, keep login"
            echo ""
            exit 0
            ;;
    esac
done

echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     SuperClaude Docker Setup              ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════╝${NC}"
echo ""

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker not found${NC}"
    echo "  Install Docker: https://docs.docker.com/get-docker/"
    exit 1
fi
echo -e "${GREEN}✓ Docker found${NC}"

# Check Docker Compose
if ! docker compose version &> /dev/null; then
    echo -e "${RED}✗ Docker Compose not found${NC}"
    echo "  Docker Compose v2 is required"
    exit 1
fi
echo -e "${GREEN}✓ Docker Compose found${NC}"
echo ""

# Handle soft reset
if [ "$RESET_SOFT" = true ]; then
    echo -e "${YELLOW}Performing soft reset (preserving login)...${NC}"
    
    # Check if container is running
    if docker ps --format '{{.Names}}' | grep -q "^claude-dev$"; then
        docker exec -e SUPERCLAUDE_RESET=true claude-dev /entrypoint.sh
        echo -e "${GREEN}✓ Soft reset complete${NC}"
        echo ""
        echo -e "${CYAN}Plugins cleared. Container still running.${NC}"
        echo "  Launch Claude: docker exec -it claude-dev claude"
        echo ""
        
        if [ "$LAUNCH_CLAUDE" = true ]; then
            echo -e "${BLUE}Launching Claude Code...${NC}"
            docker exec -it claude-dev claude
        fi
        exit 0
    else
        echo -e "${YELLOW}Container not running. Starting with reset...${NC}"
        # Will continue to normal startup with SUPERCLAUDE_RESET
        export SUPERCLAUDE_RESET=true
    fi
fi

# Handle full reset
if [ "$RESET_FULL" = true ]; then
    echo -e "${YELLOW}Performing full reset...${NC}"
    echo ""
    
    # Stop containers
    echo -e "${BLUE}Stopping containers...${NC}"
    docker compose down 2>/dev/null || true
    
    # Remove config volume
    echo -e "${BLUE}Removing config volume...${NC}"
    docker volume rm superclaude-config 2>/dev/null || true
    echo -e "${GREEN}✓ Config volume removed${NC}"
    
    # Rebuild without cache
    echo -e "${BLUE}Rebuilding image (no cache)...${NC}"
    docker compose build --no-cache
    echo -e "${GREEN}✓ Image rebuilt${NC}"
    echo ""
    
    echo -e "${YELLOW}⚠ You will need to re-authenticate Claude Code${NC}"
    echo ""
fi

# Create project directory if it doesn't exist
if [ ! -d "./project" ]; then
    mkdir -p ./project
    echo -e "${YELLOW}Created ./project directory${NC}"
    echo "  Mount your Expo project here or create a new one."
fi

# Build and start
echo -e "${BLUE}Building Docker image...${NC}"
echo ""

if [ "$WITH_SUPABASE" = true ]; then
    echo -e "${YELLOW}Including local Supabase...${NC}"
    docker compose --profile supabase build
    docker compose --profile supabase up -d
else
    # Only build if not already done in reset
    if [ "$RESET_FULL" = false ]; then
        docker compose build
    fi
    docker compose up -d
fi

echo ""
echo -e "${GREEN}✓ Container started${NC}"
echo ""

# Wait for container to be ready
echo -e "${BLUE}Waiting for container...${NC}"
sleep 3

# Show status
docker compose ps

echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           Setup Complete! 🎉              ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════╝${NC}"
echo ""

echo -e "${GREEN}Container is running!${NC}"
echo ""

if [ "$RESET_FULL" = true ]; then
    echo -e "${YELLOW}⚠ RESET COMPLETE - Authentication required${NC}"
    echo ""
fi

echo -e "${YELLOW}MCP-CLI Token Optimization:${NC}"
echo "  Enabled by default (85%+ token savings)"
echo "  To disable: Edit docker-compose.yml, set ENABLE_EXPERIMENTAL_MCP_CLI=false"
echo ""
echo -e "${YELLOW}Quick start:${NC}"
echo ""
echo "  1. Launch Claude Code:"
echo -e "     ${GREEN}docker exec -it claude-dev claude-start${NC}"
echo "     # Or: docker exec -it claude-dev claude"
echo ""
echo "  2. Login via browser when prompted"
echo ""
echo "  3. Verify setup inside Claude:"
echo "     /plugin list"
echo "     /mcp"
echo ""
echo -e "${YELLOW}Reset commands:${NC}"
echo ""
echo "  Soft reset (keep login):  ./docker-setup.sh --reset-soft"
echo "  Full reset (clean slate): ./docker-setup.sh --reset"
echo ""
echo -e "${YELLOW}Other commands:${NC}"
echo ""
echo "  Open shell:    docker exec -it claude-dev bash"
echo "  View logs:     docker compose logs -f"
echo "  Stop:          docker compose down"
echo "  Restart:       docker compose restart"
echo ""

if [ "$WITH_SUPABASE" = true ]; then
    echo -e "${YELLOW}Supabase:${NC}"
    echo "  URL: http://localhost:54321"
    echo "  DB:  postgresql://postgres:postgres@localhost:54322/postgres"
    echo ""
fi

echo -e "${YELLOW}Project directory:${NC}"
echo "  ./project → /workspace/project (inside container)"
echo ""
echo "  To use an existing project:"
echo "    cp -r /path/to/your-expo-app/* ./project/"
echo ""
echo "  To create a new project:"
echo "    docker exec -it claude-dev bash"
echo "    cd /workspace/project"
echo "    bunx create-expo-app@latest ."
echo ""

# Open shell or launch Claude if requested
if [ "$OPEN_SHELL" = true ]; then
    echo -e "${BLUE}Opening shell...${NC}"
    docker exec -it claude-dev bash
elif [ "$LAUNCH_CLAUDE" = true ]; then
    echo -e "${BLUE}Launching Claude Code...${NC}"
    docker exec -it claude-dev claude
fi

# claude-start.sh - Source this in your .bashrc or .zshrc
#
# Usage:
#   # Add to ~/.bashrc or ~/.zshrc:
#   source /path/to/superclaude-config/claude-start.sh
#
#   # Then use from any directory:
#   claude-start
#   claude-start /path/to/project
#   claude-start --status
#   claude-start --new

claude-start() {
    local GREEN='\033[0;32m'
    local YELLOW='\033[1;33m'
    local BLUE='\033[0;34m'
    local CYAN='\033[0;36m'
    local DIM='\033[2m'
    local NC='\033[0m'
    
    local FORCE_NEW=false
    local STATUS_ONLY=false
    local PROJECT_DIR=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --new|-n)
                FORCE_NEW=true
                shift
                ;;
            --status|-s)
                STATUS_ONLY=true
                shift
                ;;
            --help|-h)
                echo "claude-start - Start/resume Claude Code sessions"
                echo ""
                echo "Usage:"
                echo "  claude-start              Start in current directory"
                echo "  claude-start /path/to/dir Start in specified directory"
                echo "  claude-start --new        Force new session"
                echo "  claude-start --status     Show session status"
                return 0
                ;;
            *)
                PROJECT_DIR="$1"
                shift
                ;;
        esac
    done
    
    # Change to project directory if specified
    if [ -n "$PROJECT_DIR" ]; then
        cd "$PROJECT_DIR" || { echo "Directory not found: $PROJECT_DIR"; return 1; }
    fi
    
    local PROJECT_NAME=$(basename "$(pwd)")
    
    # Read session state
    local CURRENT_TASK=""
    local CURRENT_BRANCH=""
    local CURRENT_PHASE=""
    local NEXT_STEP=""
    
    if [ -f ".claude/session-state.json" ]; then
        CURRENT_TASK=$(jq -r '.currentTask // empty' .claude/session-state.json 2>/dev/null)
        CURRENT_BRANCH=$(jq -r '.branch // empty' .claude/session-state.json 2>/dev/null)
        CURRENT_PHASE=$(jq -r '.phase // empty' .claude/session-state.json 2>/dev/null)
        NEXT_STEP=$(jq -r '.nextStep // empty' .claude/session-state.json 2>/dev/null)
    fi
    
    # Status only
    if [ "$STATUS_ONLY" = true ]; then
        echo ""
        echo -e "${BLUE}Project:${NC} $PROJECT_NAME"
        echo -e "${DIM}$(pwd)${NC}"
        echo ""
        
        if [ -d ".claude" ]; then
            echo -e "${GREEN}✓${NC} SuperClaude configured"
        else
            echo -e "${YELLOW}○${NC} No .claude/ directory"
        fi
        
        if [ -n "$CURRENT_TASK" ]; then
            echo ""
            echo -e "${CYAN}Previous Session:${NC}"
            echo -e "  Task:   $CURRENT_TASK"
            [ -n "$CURRENT_BRANCH" ] && echo -e "  Branch: $CURRENT_BRANCH"
            [ -n "$CURRENT_PHASE" ] && echo -e "  Phase:  $CURRENT_PHASE"
            [ -n "$NEXT_STEP" ] && echo -e "  Next:   $NEXT_STEP"
        else
            echo -e "${DIM}No previous session${NC}"
        fi
        echo ""
        return 0
    fi
    
    # Header
    echo ""
    echo -e "${BLUE}━━━ claude-start ━━━${NC}"
    echo -e "${CYAN}$PROJECT_NAME${NC} ${DIM}$(pwd)${NC}"
    echo ""
    
    # Check for previous session
    if [ "$FORCE_NEW" = false ] && [ -n "$CURRENT_TASK" ]; then
        echo -e "${YELLOW}📋 Previous work:${NC} $CURRENT_TASK"
        [ -n "$NEXT_STEP" ] && echo -e "   ${DIM}Next: $NEXT_STEP${NC}"
        echo ""
        
        read -p "Resume? [Y/n] " -n 1 -r
        echo ""
        
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            # Archive old session
            [ -f ".claude/session-state.json" ] && \
                mv .claude/session-state.json ".claude/session-state.$(date +%Y%m%d-%H%M%S).json"
        fi
        echo ""
    fi
    
    # Initialize if needed
    if [ ! -d ".claude" ]; then
        echo -e "${YELLOW}No .claude/ found${NC}"
        read -p "Initialize SuperClaude? [Y/n] " -n 1 -r
        echo ""
        
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            mkdir -p .claude/{commands,context,skills}
            [ ! -f "CLAUDE.md" ] && echo "# Project: $PROJECT_NAME" > CLAUDE.md
            echo -e "${GREEN}✓${NC} Initialized"
        fi
        echo ""
    fi
    
    # Enable MCP-CLI
    export ENABLE_EXPERIMENTAL_MCP_CLI="${ENABLE_EXPERIMENTAL_MCP_CLI:-true}"
    
    if [ "$ENABLE_EXPERIMENTAL_MCP_CLI" = "true" ]; then
        echo -e "${GREEN}✓${NC} MCP-CLI enabled"
    fi
    
    echo -e "${DIM}Run /session-start to initialize${NC}"
    echo ""
    
    # Launch
    claude
}

# Alias for convenience
alias cs='claude-start'
alias cs-status='claude-start --status'
alias cs-new='claude-start --new'

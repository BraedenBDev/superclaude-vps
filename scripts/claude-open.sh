#!/bin/bash

# SuperClaude Project Opener
# Opens existing projects and ensures git MCP is configured

PROJECTS_DIR="/workspace/projects"

# If project name provided as argument
if [ -n "$1" ]; then
    PROJECT_NAME="$1"
else
    # List available projects
    echo "Available projects:"
    echo "==================="
    for dir in "$PROJECTS_DIR"/*; do
        if [ -d "$dir" ]; then
            basename "$dir"
        fi
    done
    echo ""
    echo -n "Enter project name: "
    read -r PROJECT_NAME
fi

PROJECT_PATH="$PROJECTS_DIR/$PROJECT_NAME"

# Check if project exists
if [ ! -d "$PROJECT_PATH" ]; then
    echo "Project '$PROJECT_NAME' not found!"
    echo ""
    echo "To create a new project, use: claude-init $PROJECT_NAME"
    exit 1
fi

cd "$PROJECT_PATH"

# Check if git repository
if [ ! -d "$PROJECT_PATH/.git" ]; then
    echo "Warning: Not a git repository"
    echo -n "Initialize git? (y/n): "
    read -r response
    if [ "$response" = "y" ]; then
        git init
        git add .
        git commit -m "Initial commit" || true
    fi
fi

# Ensure .mcp.json exists with git MCP
if [ ! -f "$PROJECT_PATH/.mcp.json" ]; then
    echo "Setting up git MCP for this project..."
    cat > "$PROJECT_PATH/.mcp.json" << EOF
{
  "mcpServers": {
    "git-$PROJECT_NAME": {
      "command": "uvx",
      "args": ["mcp-server-git", "--repository", "$PROJECT_PATH"],
      "server_instructions": "Git operations for $PROJECT_NAME repository. Use for: commits, branches, diffs, logs, stash, merge, rebase, cherry-pick, blame, file history, staged changes."
    }
  }
}
EOF
    echo "✓ Git MCP configured"
else
    # Check if git MCP is already configured
    if ! grep -q "git-$PROJECT_NAME" "$PROJECT_PATH/.mcp.json" 2>/dev/null; then
        echo "Updating .mcp.json with git MCP..."
        # This is simplified - in production you'd properly merge JSON
        echo "Warning: Manual .mcp.json update may be needed"
    fi
fi

# Update session state
mkdir -p /workspace/.claude
cat > /workspace/.claude/session-state.json << EOF
{
  "lastUpdated": "$(date -Iseconds)",
  "currentProject": "$PROJECT_NAME",
  "projectPath": "$PROJECT_PATH",
  "phase": "opened",
  "gitMcpConfigured": true
}
EOF

# Show git status
echo ""
echo "========================================="
echo "📂 Opened project: $PROJECT_NAME"
echo "========================================="
echo "Location: $PROJECT_PATH"

if [ -d "$PROJECT_PATH/.git" ]; then
    echo ""
    echo "Git status:"
    git status --short || true
    echo ""
    # Show recent commits
    echo "Recent commits:"
    git log --oneline -5 2>/dev/null || echo "No commits yet"
fi

echo ""
echo "Ready to work! Start Claude to begin coding."
echo ""
#!/bin/bash

# SuperClaude Project Initializer
# Automatically sets up new projects with git MCP configuration

PROJECT_NAME="$1"
PROJECTS_DIR="/workspace/projects"

if [ -z "$PROJECT_NAME" ]; then
    echo "Usage: claude-init <project-name>"
    echo "Example: claude-init my-awesome-app"
    exit 1
fi

PROJECT_PATH="$PROJECTS_DIR/$PROJECT_NAME"

# Create project directory
if [ -d "$PROJECT_PATH" ]; then
    echo "Project $PROJECT_NAME already exists!"
    echo -n "Open existing project? (y/n): "
    read -r response
    if [ "$response" = "y" ]; then
        cd "$PROJECT_PATH"
    else
        exit 1
    fi
else
    echo "Creating new project: $PROJECT_NAME"
    mkdir -p "$PROJECT_PATH"
    cd "$PROJECT_PATH"

    # Initialize git repository
    git init
    echo "# $PROJECT_NAME" > README.md
    git add README.md
    git commit -m "Initial commit"
fi

# Create project-specific .mcp.json with git MCP
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
    echo "✓ Git MCP configured for $PROJECT_NAME"
fi

# Create project-specific CLAUDE.md
if [ ! -f "$PROJECT_PATH/CLAUDE.md" ]; then
    cat > "$PROJECT_PATH/CLAUDE.md" << EOF
# $PROJECT_NAME

Project initialized on $(date)

## Project Structure
\`\`\`
$PROJECT_NAME/
├── README.md
└── .mcp.json (git MCP configured)
\`\`\`

## Available MCP Servers
- **git-$PROJECT_NAME**: Git operations for this repository

## Quick Commands
- \`git status\` - Check repository status
- \`git add .\` - Stage all changes
- \`git commit -m "message"\` - Commit changes
- \`git push\` - Push to remote

## Notes
Add project-specific documentation here...
EOF
    echo "✓ Project documentation created"
fi

# Update session state
mkdir -p /workspace/.claude
cat > /workspace/.claude/session-state.json << EOF
{
  "lastUpdated": "$(date -Iseconds)",
  "currentProject": "$PROJECT_NAME",
  "projectPath": "$PROJECT_PATH",
  "phase": "initialized",
  "gitMcpConfigured": true
}
EOF

echo ""
echo "========================================="
echo "✅ Project '$PROJECT_NAME' initialized!"
echo "========================================="
echo "Location: $PROJECT_PATH"
echo "Git MCP: Configured"
echo ""
echo "Now you can:"
echo "  cd $PROJECT_PATH"
echo "  claude  # Start Claude in this project"
echo ""
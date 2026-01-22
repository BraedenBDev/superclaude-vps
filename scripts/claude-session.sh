#!/bin/bash

# SuperClaude Session Manager
# Manage work sessions across projects

SESSION_FILE="/workspace/.claude/session-state.json"
PROJECTS_DIR="/workspace/projects"

show_help() {
    cat << EOF
SuperClaude Session Manager

Commands:
  claude-session status    - Show current session
  claude-session list      - List all projects
  claude-session resume    - Resume last session
  claude-session clear     - Clear session state
  claude-session help      - Show this help

Shortcuts:
  claude-init <name>       - Create new project
  claude-open <name>       - Open existing project
  claude-session           - Show status (default)

EOF
}

show_status() {
    if [ -f "$SESSION_FILE" ]; then
        echo "Current Session:"
        echo "================"

        # Parse JSON (basic parsing - in production use jq)
        current_project=$(grep '"currentProject"' "$SESSION_FILE" | cut -d'"' -f4)
        project_path=$(grep '"projectPath"' "$SESSION_FILE" | cut -d'"' -f4)
        last_updated=$(grep '"lastUpdated"' "$SESSION_FILE" | cut -d'"' -f4)

        if [ -n "$current_project" ]; then
            echo "Project: $current_project"
            echo "Path: $project_path"
            echo "Last active: $last_updated"

            if [ -d "$project_path/.git" ]; then
                echo ""
                echo "Git branch:"
                cd "$project_path" 2>/dev/null && git branch --show-current
            fi
        else
            echo "No active session"
        fi
    else
        echo "No session found"
        echo ""
        echo "Start a new session with:"
        echo "  claude-init <project-name>  # New project"
        echo "  claude-open <project-name>  # Existing project"
    fi
}

list_projects() {
    echo "Available Projects:"
    echo "==================="

    for dir in "$PROJECTS_DIR"/*; do
        if [ -d "$dir" ]; then
            project_name=$(basename "$dir")

            # Check for git
            if [ -d "$dir/.git" ]; then
                cd "$dir"
                branch=$(git branch --show-current 2>/dev/null || echo "no branch")
                status=$(git status --short 2>/dev/null | wc -l)
                echo "  📁 $project_name (git: $branch, $status changes)"
            else
                echo "  📂 $project_name (no git)"
            fi

            # Check for .mcp.json
            if [ -f "$dir/.mcp.json" ]; then
                echo "     ✓ Git MCP configured"
            fi
        fi
    done

    echo ""
    echo "Open a project with: claude-open <project-name>"
}

resume_session() {
    if [ -f "$SESSION_FILE" ]; then
        current_project=$(grep '"currentProject"' "$SESSION_FILE" | cut -d'"' -f4)
        project_path=$(grep '"projectPath"' "$SESSION_FILE" | cut -d'"' -f4)

        if [ -n "$current_project" ] && [ -d "$project_path" ]; then
            echo "Resuming session: $current_project"
            cd "$project_path"
            claude-open "$current_project"
        else
            echo "No valid session to resume"
        fi
    else
        echo "No session to resume"
    fi
}

clear_session() {
    echo -n "Clear session state? (y/n): "
    read -r response
    if [ "$response" = "y" ]; then
        rm -f "$SESSION_FILE"
        echo "Session cleared"
    fi
}

# Main command handling
case "$1" in
    status|"")
        show_status
        ;;
    list)
        list_projects
        ;;
    resume)
        resume_session
        ;;
    clear)
        clear_session
        ;;
    help)
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        show_help
        ;;
esac
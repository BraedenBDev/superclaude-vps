# Configuring Git MCP Per Project

The git MCP server should be configured per individual project, not globally. Here's how:

## Why Per-Project?

Each git repository needs its own MCP configuration pointing to that specific repo's path, not the entire `/workspace/projects` folder.

## How to Add Git MCP to a Project

When you start working on a specific project:

### Option 1: Project-specific .mcp.json

Create `.mcp.json` in your project root:

```bash
cd /workspace/projects/my-project
```

```json
{
  "mcpServers": {
    "git": {
      "command": "uvx",
      "args": ["mcp-server-git", "--repository", "."],
      "server_instructions": "Git operations for this project"
    }
  }
}
```

### Option 2: Use Claude's Built-in Git

Claude already has built-in git capabilities through the Bash tool, so you may not need the git MCP at all.

### Option 3: Add to Global Config with Project Path

If you have a primary project, you can add it to the global config:

```json
"git-myproject": {
  "command": "uvx",
  "args": ["mcp-server-git", "--repository", "/workspace/projects/my-project"],
  "server_instructions": "Git operations for my-project"
}
```

## Current Global MCPs

The global `.mcp.json` includes:
- **Hostinger**: VPS management
- **Grep**: Code search across GitHub
- **GitHub**: PR/issue management (requires auth)
- **Other tools**: Documentation, debugging, etc.

These are useful across all projects, while git MCP is project-specific.
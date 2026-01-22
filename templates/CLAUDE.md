# Project: [Your App Name]

---

## 🚀 Session Startup Protocol

**On every session start, Claude must run `/session-start` which:**

### 1. Check for Previous Work
```
If .claude/session-state.json exists:
  → Read last session context
  → Ask: "Resume work on [task]? (y/n)"
```

### 2. Check Tech Stack Versions
```
Run: bun outdated
Flag packages 2+ minor versions behind
Suggest migration if major updates available
```

### 3. Refresh Context Files
```
Update .claude/context/ files if stale:
  → project-structure.md (if files changed)
  → dependencies.md (if package.json changed)
  → api-contracts.md (if routes/types changed)
```

### 4. Load All Context
```
1. Read this CLAUDE.md
2. Read all .claude/context/*.md files
3. claude-mem injects session memory automatically
```

---

## 📦 Tech Stack (Version Check Required)

| Package | Declared | Check Command |
|---------|----------|---------------|
| Expo SDK | 52+ | `bunx expo --version` |
| React Native | 0.76+ | Check package.json |
| TypeScript | 5.3+ | `bunx tsc --version` |
| @supabase/supabase-js | 2.x | Check package.json |
| @tanstack/react-query | 5.x | Check package.json |
| expo-router | 4+ | Check package.json |

**On session start:** Run `bun outdated` and flag packages 2+ minor versions behind.

---

## 🛠 Tool Chain

| Tool | Purpose | Usage |
|------|---------|-------|
| **Superpowers** | Workflow orchestration | Auto-activates on feature requests |
| **vtsls LSP** | Code intelligence | go-to-definition, find-references |
| **claude-mem** | Cross-session memory | Automatic context preservation |
| **code-simplifier** | Post-implementation cleanup | Run after coding sessions |
| **Chrome DevTools MCP** | Web debugging | Network, console, performance |

### MCP-CLI (Experimental — 85%+ Token Savings)

Enable for dramatic token reduction:
```bash
export ENABLE_EXPERIMENTAL_MCP_CLI=true
claude
```

**How it works:**
- Loads minimal MCP metadata (not full tool definitions)
- Claude requests tool details on-demand when needed
- Tool calls execute via Bash commands
- Large outputs (JSON) piped to files or `jq`, bypassing context

**Benefits:**
- 85%+ token reduction on MCP overhead
- Fewer context compactions
- More MCP servers without limits
- Larger effective context for actual work

**To disable:** `unset ENABLE_EXPERIMENTAL_MCP_CLI`

### MCP Servers (8 total)

| Server | Purpose | Trigger |
|--------|---------|---------|
| **Apple Docs** | iOS/Swift APIs | Native feature research |
| **Context7** | Library docs | `use context7` in prompts |
| **Chrome DevTools** | Browser debugging | Web app testing, network analysis |
| **Grep** | GitHub search | Fallback when docs fail |
| **Linear** | Issue tracking | `/work-task LIN-XXX` |
| **Sentry** | Error monitoring | "What errors in last 24h?" |
| **GitHub** | PRs, issues | PR creation, review |
| **Git** | Repository ops | Branch management |

---

## 🔄 Dynamic Context Management

Context files are **living documents**, not static references. They must be updated:

### When to Update Context

| Trigger | Action |
|---------|--------|
| **Project init** | Generate all context files from codebase scan |
| **New feature complete** | Update project-structure.md, api-contracts.md |
| **Dependencies changed** | Regenerate dependencies.md |
| **Schema migration** | Update api-contracts.md with new types |
| **Every 5th session** | Full context refresh via `/context-refresh` |

### Context Files (.claude/context/)

| File | Content | Auto-Update Trigger |
|------|---------|---------------------|
| `project-structure.md` | Directory tree, key files | File system changes |
| `dependencies.md` | Package versions, purposes | package.json changes |
| `api-contracts.md` | Supabase schema, API routes | Migration or route changes |
| `design-system.md` | Colors, typography, spacing | Manual (design changes) |
| `feature-flags.md` | Current flags and states | Flag additions/removals |

### Context Refresh Command

Run `/context-refresh` to regenerate all context files from current codebase state.

---

## ⚡ Bun Runtime

All commands use Bun. Never use npm or yarn.

```bash
# Package management
bun install              # Install dependencies
bun add <pkg>            # Add package
bun add -d <pkg>         # Add dev dependency
bun outdated             # Check for updates

# Development
bunx expo start          # Start dev server
bunx expo start --web    # Web mode (for Chrome DevTools)
bun run typecheck        # TypeScript check
bun run lint             # ESLint

# Testing
bun test                 # Run Jest tests
bun test --watch         # Watch mode

# Supabase
bunx supabase start      # Local Supabase
bunx supabase gen types typescript --local > src/types/database.types.ts

# Build
bunx eas build --platform ios
bunx eas build --platform android
```

---

## 🔄 Superpowers Workflow

```
"Let's build [feature]"
    ↓
[brainstorming] → Design questions → Approved spec
    ↓
[writing-plans] → 2-5 min tasks with verification
    ↓
[subagent-driven-development] → TDD per task
    ↓
[code-simplifier] → Post-implementation cleanup
    ↓
[context-refresh] → Update context files with changes
    ↓
[finishing-a-development-branch] → PR or merge
```

**After every feature:** Run `/context-refresh` to capture changes.

---

## 🌐 Chrome DevTools MCP (Web Debugging)

For web app debugging and testing:

### Capabilities
- **Network analysis:** Inspect requests, CORS issues, API responses
- **Console monitoring:** Catch JS errors, warnings, logs
- **Performance traces:** Record and analyze performance
- **DOM inspection:** Query elements, check accessibility
- **Screenshot capture:** Visual verification

### Usage
```bash
# Start web mode
bunx expo start --web

# In Claude, use Chrome DevTools MCP:
"Take a screenshot of the current page"
"Show me console errors"
"Analyze network requests to /api/auth"
"Run a performance trace on the home page"
"Check accessibility issues on this form"
```

### Combined with Claude for Chrome
- Chrome DevTools MCP: Programmatic debugging
- Claude for Chrome extension: Visual UI/UX review

---

## 📋 Code Standards

### TypeScript
- Strict mode, no `any`
- Use `type` over `interface`
- Never use `enum` (use `as const` objects)

### React Native
- Functional components only
- `StyleSheet.create()` — no inline styles
- `FlatList` for lists — never `ScrollView` + `.map()`

### Supabase
- Always use generated types from `database.types.ts`
- RLS policies required on all tables
- Regenerate types after migrations

---

## 📁 Project Structure

```
app/                    # Expo Router screens
src/
  components/           # Reusable UI
  hooks/                # Custom hooks
  lib/                  # Supabase client, utilities
  stores/               # Zustand stores
  types/                # TypeScript types
supabase/
  migrations/           # SQL migrations
  functions/            # Edge Functions
.maestro/               # E2E tests
.claude/
  context/              # Dynamic context files (auto-updated)
  skills/               # Domain patterns
  agents/               # Specialist agents
  commands/             # Slash commands
  session-state.json    # Work-in-progress state
```

---

## 📄 Session State

Claude saves work-in-progress to `.claude/session-state.json`:

```json
{
  "lastUpdated": "ISO-8601 timestamp",
  "currentTask": "LIN-123: User authentication",
  "branch": "feature/auth",
  "phase": "implementation",
  "completedTasks": ["setup", "tests"],
  "nextStep": "Implement login screen",
  "contextLastRefreshed": "ISO-8601 timestamp"
}
```

On next session, Claude reads this and offers to resume.

---

## ❌ Common Mistakes

**Don't:**
- `console.log()` without `__DEV__` guard
- Inline styles
- `ScrollView` with `.map()` for lists
- Skip RLS policies
- Use `any` to silence TypeScript
- Use npm/yarn (use bun)
- Let context files go stale

**Do:**
- Run `/context-refresh` after features
- Update session-state.json during work
- Check versions with `bun outdated`

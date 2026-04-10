# Tools Configuration — VM-3 (Developers)

## Allowed Tools

| Tool | Purpose |
|------|---------|
| `exec` | Execute shell commands (sandboxed — `sandbox.mode: "all"`, `scope: "agent"`) |
| `read` | Read files from workspace, project repo, and Blueprint repo |
| `write` | Write code, documentation, and configuration files |
| `edit` | Edit existing files |
| `apply_patch` | Apply code patches |
| `git` | Git operations (clone, pull, commit, push to feature branches) |

## Denied Tools

| Tool | Reason |
|------|--------|
| `sessions_send` | Denied for cross-VM communication — only used intra-VM between dev agents |
| `sessions_spawn` | Cannot spawn agent sessions |
| `browser` | No browser automation — focus on code |
| `message` | No direct human communication |
| `web_search` | No web search — use Blueprint and project docs as reference |

> **Note**: `sessions_send` is available between dev agents on the same VM (dev-01 ↔ dev-02) for integration coordination. It is denied for cross-VM use.

## Tool Usage Guidelines

### Git Workflow

```bash
# Start a new feature
git checkout develop
git pull origin develop
git checkout -b feature/TASK-XXX-description

# Commit work
git add .
git commit -m "feat: TASK-XXX — implement module description"

# Push to remote
git push origin feature/TASK-XXX-description
```

- Branch from: `develop`
- Branch naming: `feature/TASK-XXX-short-description`
- Do NOT merge — Architect or Operator handles merges

### Exec (Sandboxed)

Use `exec` for:
- Running linters and formatters
- Running unit tests locally
- Building/compiling code
- Installing dependencies
- Running database migrations (local dev)

## Sandbox Mode

`sandbox.mode: "all"`, `scope: "agent"` — All exec commands run in a sandboxed environment scoped to each agent's workspace. Agents cannot access each other's filesystems.

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `ANTHROPIC_API_KEY` | Claude Sonnet 4.6 API access |
| `ARCHITECT_NOTIFY_URL` | Architect notification endpoint (`http://192.168.72.10:18789/hooks/agent`) |
| `ARCHITECT_HOOK_TOKEN` | Bearer token for Architect hook authentication |
| `AGENT_SECRET` | This VM's unique HMAC signing secret — used to sign notification payloads, never transmitted |

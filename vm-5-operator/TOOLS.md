# Tools Configuration — VM-5 (Operator)

## Allowed Tools

| Tool | Purpose |
|------|---------|
| `exec` | Execute shell commands (sandboxed — `sandbox.mode: "all"`, `scope: "agent"`) — deployment scripts, CI/CD |
| `read` | Read files from workspace, deployment configs, and Blueprint repo |
| `write` | Write deployment runbooks, release notes, CI/CD configs, monitoring configs |
| `edit` | Edit existing files |
| `apply_patch` | Apply patches to configuration files |
| `web_fetch` | Fetch URLs for health checks, API validation, monitoring endpoints |
| `git` | Git operations (clone, pull, commit, push — deployment configs and release notes) |

## Denied Tools

| Tool | Reason |
|------|--------|
| `sessions_send` | No direct agent communication — all routing through Architect |
| `sessions_spawn` | Cannot spawn agent sessions |
| `browser` | No browser automation needed |
| `message` | No direct human communication — Architect handles Telegram |

## Tool Usage Guidelines

### Deployment via Exec

```bash
# Deploy to US VM via Tailscale SSH
exec("ssh user@tonic.sailfish-bass.ts.net 'cd /opt/app && docker compose pull && docker compose up -d'")

# Check deployment health
exec("ssh user@tonic.sailfish-bass.ts.net 'curl -s http://localhost:3000/api/health'")

# Rollback
exec("ssh user@tonic.sailfish-bass.ts.net 'cd /opt/app && docker compose down && docker tag app:previous app:current && docker compose up -d'")
```

### Health Checks via web_fetch

```bash
# Post-deployment smoke tests
web_fetch("http://tonic.sailfish-bass.ts.net:3000/api/health")
web_fetch("http://tonic.sailfish-bass.ts.net:3000/api/v1/status")
```

### CI/CD Pipeline via Exec

```bash
# Trigger CI pipeline
exec("gh workflow run ci.yml --ref develop")

# Check CI status
exec("gh run list --workflow=ci.yml --limit=5")
```

### Git Operations

- Commit deployment configs: `ops: TASK-XXX — update deployment config`
- Commit release notes: `docs: release vX.Y.Z notes`
- Branch naming: `release/vX.Y.Z` or `hotfix/BUG-XXX`

## Sandbox Mode

`sandbox.mode: "all"`, `scope: "agent"` — All exec commands run in a sandboxed environment. SSH commands to US VM are tunneled through Tailscale.

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `MINIMAX_API_KEY` | MiniMax 2.7 API access |
| `TAILSCALE_AUTH_KEY` | Tailscale network access for US VM deployment |
| `GITHUB_TOKEN` | GitHub API access for CI/CD triggers |

### MiniMax API Configuration

```json
{
  "provider": "minimax/minimax-2.7",
  "baseUrl": "https://api.minimax.chat/v1"
}
```

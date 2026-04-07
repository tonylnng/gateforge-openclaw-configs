# Tools Configuration — VM-4 (QC Agents)

## Allowed Tools

| Tool | Purpose |
|------|---------|
| `exec` | Execute shell commands (sandboxed — `sandbox.mode: "all"`, `scope: "agent"`) — run tests, linters, scanners |
| `read` | Read files from workspace, project code, and Blueprint repo |
| `write` | Write test cases, test reports, and QA documentation |
| `edit` | Edit existing test files |
| `web_fetch` | Fetch URLs for API testing (contract validation, endpoint testing) |
| `git` | Git operations (pull code for inspection — read-only; push test artifacts to feature branches) |

## Denied Tools

| Tool | Reason |
|------|--------|
| `sessions_send` | Denied for cross-VM communication — only used intra-VM between QC agents |
| `sessions_spawn` | Cannot spawn agent sessions |
| `browser` | No browser automation (use Playwright/Cypress via `exec` for E2E tests) |
| `message` | No direct human communication |
| `git (push to code branches)` | QC agents do NOT push code fixes — only test artifacts |

> **Note**: `sessions_send` is available between QC agents on the same VM (qc-01 ↔ qc-02) for test coordination. It is denied for cross-VM use.

## Tool Usage Guidelines

### Test Execution via Exec

```bash
# Unit tests
exec("cd ~/workspace-qc-01/project-repo && npm test")

# API contract testing
exec("cd ~/workspace-qc-01 && npx openapi-validator specs/service-a.openapi.yaml")

# E2E tests
exec("cd ~/workspace-qc-01 && npx playwright test")

# Performance tests
exec("cd ~/workspace-qc-01 && k6 run load-test.js")

# Security scanning
exec("cd ~/workspace-qc-01 && trivy fs --severity HIGH,CRITICAL .")
```

### API Testing via web_fetch

```bash
# Test API endpoints directly
web_fetch("http://dev-environment:3000/api/health")
web_fetch("http://dev-environment:3000/api/v1/users", method="POST", body="{...}")
```

### Git (Read-Only Code Access)

```bash
# Pull latest code for inspection
exec("cd ~/workspace-qc-01/project-repo && git pull origin develop")

# Push test artifacts only
git commit -m "test: TASK-XXX — add test cases for module Y"
git push origin test/TASK-XXX-description
```

## Sandbox Mode

`sandbox.mode: "all"`, `scope: "agent"` — All exec commands run in a sandboxed environment scoped to each agent's workspace.

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `MINIMAX_API_KEY` | MiniMax 2.7 API access |
| `ARCHITECT_NOTIFY_URL` | Architect notification endpoint (`http://192.168.72.10:18789/hooks/agent`) |
| `ARCHITECT_HOOK_TOKEN` | Bearer token for Architect hook authentication |
| `AGENT_SECRET` | This VM's unique secret for identity verification with the Architect |

### MiniMax API Configuration

```json
{
  "provider": "minimax/minimax-2.7",
  "baseUrl": "https://api.minimax.chat/v1"
}
```

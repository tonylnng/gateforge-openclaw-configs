# Tools Configuration — VM-2 (System Designer)

## Allowed Tools

| Tool | Purpose |
|------|---------|
| `read` | Read files from workspace and Blueprint repo |
| `write` | Write design documents and deliverables |
| `edit` | Edit existing files |
| `exec` | Execute shell commands (sandboxed — `sandbox.mode: "all"`, `scope: "agent"`) |
| `web_search` | Search for technical references, documentation, best practices |
| `web_fetch` | Fetch content from URLs (docs, specs, references) |
| `git` | Git operations (clone, pull, commit, push to feature branches) |

## Denied Tools

| Tool | Reason |
|------|--------|
| `sessions_send` | No direct agent communication — all routing through Architect |
| `sessions_spawn` | Cannot spawn agent sessions |
| `browser` | No browser automation needed for design tasks |
| `message` | No direct human communication — Architect handles Telegram |

## Tool Usage Guidelines

### Git Workflow

- Branch from: `develop`
- Branch naming: `design/TASK-XXX-short-description`
- Commit deliverables with descriptive messages: `docs: TASK-XXX — <design description>`
- Do NOT merge — the System Architect handles all merges

### Web Search

Use `web_search` and `web_fetch` for:
- Kubernetes best practices and documentation
- Database design patterns
- Security guidelines (OWASP, CIS benchmarks)
- Technology comparisons and trade-offs

### Exec (Sandboxed)

Use `exec` for:
- Validating YAML/JSON configs
- Running schema validation tools
- Testing Helm chart templating
- Linting infrastructure configs

## Sandbox Mode

`sandbox.mode: "all"`, `scope: "agent"` — All exec commands run in a sandboxed environment scoped to this agent's workspace.

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `ANTHROPIC_API_KEY` | Claude Sonnet 4.6 API access |
| `ARCHITECT_NOTIFY_URL` | Architect notification endpoint (`http://192.168.72.10:18789/hooks/agent`) |
| `ARCHITECT_HOOK_TOKEN` | Bearer token for Architect hook authentication |
| `AGENT_SECRET` | This VM's unique HMAC signing secret — used to sign notification payloads, never transmitted |

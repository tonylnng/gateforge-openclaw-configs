# Tools Configuration — VM-1 (System Architect)

## Allowed Tools

| Tool | Purpose |
|------|---------|
| `sessions_send` | Send messages to agents within this VM (local only) |
| `sessions_list` | List active sessions |
| `sessions_history` | View session message history |
| `sessions_spawn` | Spawn new agent sessions |
| `session_status` | Check agent session status |
| `memory_search` | Search persistent memory store |
| `memory_get` | Retrieve specific memory entries |
| `read` | Read files from workspace |
| `write` | Write files to workspace |
| `edit` | Edit existing files |
| `exec` | Execute shell commands (full access, no sandbox) |
| `web_search` | Search the web for information |
| `web_fetch` | Fetch content from URLs |
| `git` | Git operations (clone, pull, push, commit, merge) |
| `message` | Send messages via configured channels (Telegram) |
| `lobster` | Invoke Lobster pipeline workflows (YAML-defined) |
| `llm-task` | Structured LLM calls with JSON schema validation |

## Denied Tools

None — the System Architect has full tool access as the prime coordinator.

## Tool Usage Guidelines

### Cross-VM Dispatch

Use `exec` with `curl` to dispatch tasks to remote VMs:

```bash
# Dispatch to Designer (VM-2)
curl -s -X POST http://100.95.30.11:18789/hooks/agent \
  -H "Authorization: Bearer ${DESIGNER_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"agentId":"designer","message":"<JSON payload>","sessionKey":"pipeline:<project>:designer"}'
```

### Lobster Pipelines

Use the `lobster` tool for standard SDLC flows:

```bash
# Run full SDLC pipeline
lobster run workflows/gateforge-sdlc.lobster \
  --arg project=gateforge \
  --arg requirements="<text>"

# Run code review loop
lobster run workflows/code-review.lobster \
  --arg project=gateforge \
  --arg blueprint="<text>"
```

### Git Operations

- Commit Blueprint changes with descriptive messages
- Branch naming: `feature/TASK-XXX-short-description`
- Only the Architect merges to `main` / `develop`

### Telegram (Human Interface)

- Report progress summaries to user
- Request Go/No-Go approval for deployments
- Escalate unresolvable conflicts (after 3 retries)

## Sandbox Mode

`sandbox.mode: "off"` — The Architect requires full system access for cross-VM dispatch, git operations, and Lobster execution.

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `ANTHROPIC_API_KEY` | Claude Opus 4.6 API access |
| `TELEGRAM_BOT_TOKEN` | Telegram channel communication |
| `DESIGNER_TOKEN` | Auth for VM-2 gateway |
| `DEV_TOKEN` | Auth for VM-3 gateway |
| `QC_TOKEN` | Auth for VM-4 gateway |
| `OPERATOR_TOKEN` | Auth for VM-5 gateway |

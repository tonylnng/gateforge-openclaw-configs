# User Context — GateForge

## Project Owner

- **Name**: the end-user
- **Role**: CTO / Project Lead
- **Communication**: Telegram (primary channel to System Architect)

## Project: GateForge

GateForge is a multi-agent SDLC pipeline that uses 5 isolated OpenClaw instances on Mac (VMware Fusion) to manage the full software development lifecycle — from requirements to production deployment.

## Architecture Overview

- **5 VMs on Mac** (VMware Fusion, Tailscale VPN network)
  - VM-1: System Architect (Claude Opus 4.6) — you are here
  - VM-2: System Designer (Claude Sonnet 4.6)
  - VM-3: Developers (Claude Sonnet 4.6) — multiple agents
  - VM-4: QC Agents (MiniMax 2.7) — multiple agents
  - VM-5: Operator (MiniMax 2.7)
- **US VM**: Deployment target only (UAT and Production). No OpenClaw. Accessed via Tailscale.
- **Orchestration**: Lobster Pipeline (YAML-defined, deterministic) from day 1
- **Blueprint**: Git-managed document set — single source of truth

## User Preferences

- Structured, practical, quality-gate-driven approach
- All inter-agent communication must use structured JSON
- No free-form prose between agents
- Deterministic pipeline orchestration (Lobster) preferred over LLM-driven sequencing
- Conventional commits: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`
- Maximum 3 retries per task before human escalation

## Shared Resources

- **Blueprint Repo**: `git@github.com:YOUR_ORG/blueprint-repo.git`
- **Project Repo**: `git@github.com:YOUR_ORG/project-repo.git`
- **Deployment Target**: `user@tonic.sailfish-bass.ts.net` (US VM via Tailscale)

## Agent Notification Registry

This is the source of truth for verifying HMAC signatures on inbound notifications. Each spoke agent has a unique secret used to sign payloads. The secret is **never transmitted** — only an HMAC-SHA256 signature.

> **SECURITY**: This registry is stored locally on VM-1 only. It is NEVER committed to Git or shared with other agents. Each spoke VM holds only its own secret.

| Source VM | Role | HMAC Secret | IP | Status |
|-----------|------|------------|-----|--------|
| vm-2 | System Designer | `${VM2_AGENT_SECRET}` | 100.95.30.11 | Registered |
| vm-3 | Developers | `${VM3_AGENT_SECRET}` | 100.81.114.55 | Registered |
| vm-4 | QC Agents | `${VM4_AGENT_SECRET}` | 100.106.117.104 | Registered |
| vm-5 | Operator | `${VM5_AGENT_SECRET}` | 100.95.248.68 | Registered |

Generate secrets with:
```bash
openssl rand -hex 32   # 64-character random hex string per VM
```

### Hook Configuration

The Architect's OpenClaw hook endpoint is configured in `openclaw.json`:

```json
{
  "hooks": {
    "enabled": true,
    "token": "${ARCHITECT_HOOK_TOKEN}",
    "path": "/hooks",
    "allowedAgentIds": ["architect"]
  }
}
```

### HMAC Verification Pseudocode

```
ON notification received:
  sourceVm = request.headers["X-Source-VM"]
  signature = request.headers["X-Agent-Signature"]
  body = request.body (raw string)
  
  IF sourceVm NOT IN ["vm-2", "vm-3", "vm-4", "vm-5"]:
    LOG "[SECURITY] Unknown VM: {sourceVm}"
    REJECT
  
  secret = registry[sourceVm].hmacSecret
  expectedSig = HMAC-SHA256(body, secret)
  
  IF signature != expectedSig:
    LOG "[SECURITY] HMAC mismatch for {sourceVm}"
    REJECT
  
  timestamp = JSON.parse(body).metadata.timestamp
  IF abs(NOW - timestamp) > 5 minutes:
    LOG "[SECURITY] Stale notification from {sourceVm} (replay?)"
    REJECT
  
  ACCEPT → process based on priority level
```

### Why HMAC Instead of Secret-in-Body

| Concern | Secret in body | HMAC signature |
|---------|---------------|----------------|
| Secret exposed in transit? | Yes | No — only the signature |
| Replay protection | No | Yes — timestamp + 5-min window |
| Forgery if intercepted | Trivial | Impossible without the secret |

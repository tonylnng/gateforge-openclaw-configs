# User Context — GateForge

## Project Owner

- **Name**: Tony NG
- **Role**: CTO / Project Lead
- **Communication**: Telegram (primary channel to System Architect)

## Project: GateForge

GateForge is a multi-agent SDLC pipeline that uses 5 isolated OpenClaw instances on Mac (VMware Fusion) to manage the full software development lifecycle — from requirements to production deployment.

## Architecture Overview

- **5 VMs on Mac** (VMware Fusion, host-only network 192.168.72.x)
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

This is the source of truth for authenticating inbound notifications from spoke agents. Each spoke agent has a unique secret. When a notification arrives, verify `metadata.agentSecret` against this registry.

> **SECURITY**: This registry is stored locally on VM-1 only. It is NEVER committed to Git or shared with other agents.

| Source VM | Role | Agent Secret | IP | Status |
|-----------|------|-------------|-----|--------|
| vm-2 | System Designer | `${VM2_AGENT_SECRET}` | 192.168.72.11 | Registered |
| vm-3 | Developers | `${VM3_AGENT_SECRET}` | 192.168.72.12 | Registered |
| vm-4 | QC Agents | `${VM4_AGENT_SECRET}` | 192.168.72.13 | Registered |
| vm-5 | Operator | `${VM5_AGENT_SECRET}` | 192.168.72.14 | Registered |

Secrets are loaded from environment variables. Generate with:
```bash
openssl rand -hex 32   # Generates a 64-character random hex string
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

### Validation Pseudocode

```
ON notification received:
  secret = notification.metadata.agentSecret
  vm = notification.metadata.sourceVm
  
  IF vm NOT IN ["vm-2", "vm-3", "vm-4", "vm-5"]:
    LOG "[SECURITY] Unknown VM: {vm}"
    REJECT
  
  IF secret != registry[vm].agentSecret:
    LOG "[SECURITY] Invalid secret for {vm}"
    REJECT
  
  ACCEPT → process based on priority level
```

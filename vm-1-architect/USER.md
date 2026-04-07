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

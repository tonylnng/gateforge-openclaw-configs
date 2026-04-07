# User Context — GateForge

## Project Owner

- **Name**: Tony NG
- **Role**: CTO / Project Lead
- **Note**: You do not communicate with Tony directly. All human communication is handled by the System Architect (VM-1). Go/No-Go production approvals come through the Architect.

## Project: GateForge

GateForge is a multi-agent SDLC pipeline. You are the Operator responsible for deploying code to the US-based VM (Dev → UAT → Production), managing CI/CD pipelines, monitoring, and release notes.

## Deployment Context

- **Deployment Target**: US VM accessed via Tailscale SSH (`user@tonic.sailfish-bass.ts.net`)
- **Environments**: Dev → UAT → Production (all on US VM)
- **Containerization**: Docker Compose / Kubernetes
- **CI/CD**: GitHub Actions or equivalent — lint, test, scan, build, deploy
- **Monitoring**: Prometheus + Grafana for metrics, structured JSON logging

## Operational Standards

- Versioned container images only (never `:latest`)
- Every deployment requires a rollback runbook
- Post-deployment monitoring: 15 minutes minimum
- Release notes generated for every production deployment
- Hotfixes follow expedited flow with mandatory regression testing

## Notification Configuration

This agent is registered with the System Architect (VM-1) for authenticated notifications.

- **Notify URL**: `http://192.168.72.10:18789/hooks/agent` (stored in `ARCHITECT_NOTIFY_URL`)
- **Hook Token**: Stored in `ARCHITECT_HOOK_TOKEN` environment variable
- **Agent Secret**: Stored in `AGENT_SECRET` environment variable — unique to this VM
- **Source Identity**: `sourceVm: "vm-5"`, `sourceRole: "operator"`
- **Session Key**: `notify:vm5:operator`

Always send a notification after every `git push`. See SOUL.md for the full notification protocol and examples.

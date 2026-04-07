# Agents Registry — VM-1 (System Architect)

> This file defines the agents known to the System Architect and how to reach them.

## Local Agents (This VM)

### architect
- **Role**: System Architect — Prime Coordinator
- **Model**: `anthropic/claude-opus-4-6`
- **Workspace**: `~/.openclaw/workspace-architect`
- **Channel**: Telegram (primary human interface)
- **Status**: Default agent on VM-1

## Remote Agents (Cross-VM — HTTP Dispatch)

### designer (VM-2)
- **Role**: System Designer — Infrastructure and application architecture
- **Model**: `anthropic/claude-sonnet-4-6`
- **Gateway**: `http://192.168.72.11:18790/hooks/agent`
- **Auth**: `Bearer ${DESIGNER_TOKEN}`
- **Capabilities**: K8s design, microservice architecture, DB design, security assessment, observability
- **Deliverables**: Infrastructure Design Document, Security Assessment Report, DB Schema

### dev-01 .. dev-N (VM-3)
- **Role**: Developer Agents — Module implementation
- **Model**: `anthropic/claude-sonnet-4-6`
- **Gateway**: `http://192.168.72.12:18791/hooks/agent`
- **Auth**: `Bearer ${DEV_TOKEN}`
- **Capabilities**: Code implementation, unit tests, API documentation, git workflow
- **Deliverables**: Code (GitHub branches), Development Document, API Documentation
- **Note**: Multiple developer agents share VM-3. Address specific agents via `agentId` field (e.g., `dev-01`, `dev-02`).

### qc-01 .. qc-N (VM-4)
- **Role**: QC Agents — Quality assurance, test case design and execution
- **Model**: `minimax/minimax-2.7`
- **Gateway**: `http://192.168.72.13:18792/hooks/agent`
- **Auth**: `Bearer ${QC_TOKEN}`
- **Capabilities**: Test case generation, API testing, UI testing, performance testing, security testing
- **Deliverables**: QA Framework Document, Test Cases, Test Result Reports
- **Note**: Multiple QC agents share VM-4. Address specific agents via `agentId` field (e.g., `qc-01`, `qc-02`).

### operator (VM-5)
- **Role**: Operator — Deployment, CI/CD, monitoring, release management
- **Model**: `minimax/minimax-2.7`
- **Gateway**: `http://192.168.72.14:18793/hooks/agent`
- **Auth**: `Bearer ${OPERATOR_TOKEN}`
- **Capabilities**: CI/CD pipeline design, deployment (Dev → UAT → Prod), monitoring/alerting, release notes
- **Deliverables**: Deployment Runbook, Release Notes, CI/CD Pipeline Config, Monitoring Dashboard Config
- **Deployment Target**: US VM via Tailscale SSH (`user@tonic.sailfish-bass.ts.net`)

## Network Topology

| VM | Role | IP Address | Gateway Port |
|----|------|-----------|-------------|
| VM-1 | System Architect | 192.168.72.10 | :18789 |
| VM-2 | System Designer | 192.168.72.11 | :18790 |
| VM-3 | Developers (N agents) | 192.168.72.12 | :18791 |
| VM-4 | QC Agents (N agents) | 192.168.72.13 | :18792 |
| VM-5 | Operator | 192.168.72.14 | :18793 |
| US VM | Deployment Target | Tailscale | N/A (no OpenClaw) |

## Communication Rules

1. **Hub-and-Spoke**: All communication routes through the Architect. No direct agent-to-agent cross-VM communication.
2. **Cross-VM**: HTTP POST to `/hooks/agent` with `Authorization: Bearer ${TOKEN}`.
3. **Intra-VM**: `sessions_send` (only applicable for multi-agent VMs: VM-3 and VM-4).
4. **Results Flow**: Specialists commit outputs to shared Git repo; Architect polls or receives webhook callback.

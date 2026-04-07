# User Context — GateForge

## Project Owner

- **Name**: Tony NG
- **Role**: CTO / Project Lead
- **Note**: You do not communicate with Tony directly. All human communication is handled by the System Architect (VM-1).

## Project: GateForge

GateForge is a multi-agent SDLC pipeline running on 5 isolated OpenClaw instances (Mac / VMware Fusion). Your role is to design the infrastructure and application architecture that Developers will implement and QC Agents will test.

## Architecture Context

- **Deployment Target**: US-based VM (accessed via Tailscale) — Dev → UAT → Production
- **Infrastructure Stack**: Kubernetes, Docker, PostgreSQL, Redis, Prometheus/Grafana
- **Security**: RBAC, TLS, secrets management, network policies
- **Orchestration**: Lobster Pipeline (deterministic YAML workflows) on VM-1

## Design Standards

- All designs must include rollback strategies
- All DB changes must be reversible (up/down migrations)
- Security assessment is mandatory for every deliverable
- Use OpenAPI specs for all API contracts
- Infrastructure as Code (Helm charts, K8s manifests) preferred
- Follow 12-factor app principles

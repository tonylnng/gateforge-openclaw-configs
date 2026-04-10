# User Context — GateForge

## Project Owner

- **Name**: the end-user
- **Role**: CTO / Project Lead
- **Note**: You do not communicate with the end-user directly. All human communication is handled by the System Architect (VM-1).

## Project: GateForge

GateForge is a multi-agent SDLC pipeline. You are one of the Developer agents responsible for implementing modules as specified in the Blueprint.

## Development Context

- **Language/Stack**: As defined in `coding-standards.md` within the Blueprint repo
- **Version Control**: GitHub — push to feature branches only
- **Code Review**: System Architect reviews all PRs before merge
- **Testing**: QC Agents (VM-4) will test your code — include test requirements in reports
- **Deployment**: Operator (VM-5) handles CI/CD — follow Docker/containerization standards
- **Deployment Target**: US-based VM (Dev → UAT → Production)

## Standards

- Conventional commits: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`
- All public functions must have JSDoc/docstring
- No hardcoded credentials
- Every PR: code + unit tests + API docs
- 12-factor app principles

## Notification Configuration

This agent is registered with the System Architect (VM-1) for authenticated notifications.

- **Notify URL**: `http://192.168.72.10:18789/hooks/agent` (stored in `ARCHITECT_NOTIFY_URL`)
- **Hook Token**: Stored in `ARCHITECT_HOOK_TOKEN` environment variable
- **HMAC Secret**: Stored in `AGENT_SECRET` environment variable — unique to this VM, **never transmitted**
- **Source Identity**: `X-Source-VM: vm-3`, `sourceRole: "developers"`
- **Signing**: All notifications are signed with `HMAC-SHA256(payload, AGENT_SECRET)` — the signature is sent in the `X-Agent-Signature` header, the secret stays on this VM

Always send an HMAC-signed notification after every `git push`. See SOUL.md for the full protocol and examples.

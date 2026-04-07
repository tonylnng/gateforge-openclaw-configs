# GateForge Admin Portal

> **You are reading the scope-of-work and orientation document for the GateForge Admin Portal.**
> Read this document completely before taking any action. It tells you what this project is, why it exists, what it does, how it fits into GateForge, and what you are expected to build. Once you understand the full picture, refer to the companion documents for detailed specifications and implementation instructions.

---

## Document Map

| Document | Purpose | When to Read |
|----------|---------|--------------|
| **This file (README.md)** | Scope of work, background, features, advantages, ideas | First — orientation |
| `GATEFORGE-ADMIN-PORTAL.md` | Complete feature specification (15 sections, all views, all statuses) | When you need the exact behaviour of a feature |
| `GATEFORGE-ADMIN-PORTAL-IMPLEMENTATION.md` | Developer-ready build guide (types, routes, components, configs) | When you are implementing a module |
| `README.md` (root) | GateForge architecture — hub-and-spoke, roles, communication | When you need to understand the parent system |

---

## Background

### What Is GateForge

GateForge is a **multi-agent software development lifecycle (SDLC) pipeline** designed by Tony NG (CTO / Project Lead). It uses 5 isolated AI agent instances — each running on its own VM inside OpenClaw — to collaboratively build, test, and deploy production-grade software.

GateForge is not a single AI working alone. It is a coordinated engineering team of specialised AI agents:

| VM | Role | AI Model | IP Address | Agents |
|----|------|----------|------------|--------|
| VM-1 | System Architect | Claude Opus 4.6 | 192.168.72.10:18789 | 1 (architect) |
| VM-2 | System Designer | Claude Sonnet 4.6 | 192.168.72.11:18789 | 1 (designer) |
| VM-3 | Developers | Claude Sonnet 4.6 | 192.168.72.12:18789 | Multiple (dev-01, dev-02..dev-N) |
| VM-4 | QC Agents | MiniMax 2.7 | 192.168.72.13:18789 | Multiple (qc-01, qc-02..qc-N) |
| VM-5 | Operator | MiniMax 2.7 | 192.168.72.14:18789 | 1 (operator) |

### How GateForge Communicates

GateForge uses a **hub-and-spoke** architecture:

```
                         Tony (Human)
                              │
                         via Telegram
                              │
                    ┌─────────▼──────────┐
                    │  VM-1: ARCHITECT   │ ← Hub (coordinator)
                    │  Claude Opus 4.6   │
                    └──┬────┬────┬────┬──┘
                       │    │    │    │
                  HTTP POST to each VM's /hooks/agent endpoint
                       │    │    │    │
              ┌────────┘    │    │    └────────┐
              ▼             ▼    ▼             ▼
         ┌─────────┐  ┌────────┐ ┌────────┐ ┌─────────┐
         │ VM-2    │  │ VM-3   │ │ VM-4   │ │ VM-5    │
         │Designer │  │Devs    │ │QC      │ │Operator │
         └─────────┘  └────────┘ └────────┘ └─────────┘
                           │
                           ▼
                    Blueprint (Git)
                           │
                           ▼
                  US VM (Dev → UAT → Prod)
```

**Key rules:**
- Only the Architect communicates with Tony (via Telegram)
- Only the Architect writes to the Blueprint (Git repository — single source of truth)
- No spoke-to-spoke communication — all messages route through the Architect
- All inter-agent messages use structured JSON, never free-form prose
- Spoke agents notify the Architect via fire-and-forget HTTP POST after git push
- Two-layer authentication: Hook Token (transport) + Agent Secret (identity per VM)

### The SDLC Pipeline

GateForge follows six phases for every feature or release:

| Phase | What Happens | Key Agent | Outcome |
|-------|-------------|-----------|---------|
| 1. Requirements & Feasibility | Tony sends requirements via Telegram → Architect clarifies and decomposes | Architect | Blueprint v0.1 |
| 2. Architecture & Infrastructure | Architect dispatches design tasks → Designer produces infrastructure/security/DB design | Designer | Blueprint v0.2 |
| 3. Development (Parallel) | Architect dispatches module tasks → Developers implement, push to feature branches | Developers | Blueprint v0.3 |
| 4. Quality Assurance (Parallel) | Architect dispatches test tasks → QC agents design and execute tests | QC Agents | Blueprint v0.4 |
| 5. Deployment & Release | Architect dispatches to Operator → Deploy to US VM (Dev → UAT → Prod) | Operator | Production release |
| 6. Iteration | Tony feedback → new requirements or hotfix flow | All | Next cycle |

### Quality Gates

No task advances without passing its quality gate:

| Gate | Criteria | Decision Model |
|------|----------|---------------|
| Design Gate | Security assessment, rollback strategy, Blueprint updated | Pass / Fail |
| Code Gate | Unit tests pass, coding standards met, JSDoc complete, no hardcoded secrets | Pass / Fail |
| QA Gate | Unit ≥ 95%, Integration ≥ 90%, E2E ≥ 85%, no P0/P1 open defects | PROMOTE / HOLD / ROLLBACK |
| Release Gate | All QA gates pass, deployment runbook ready, rollback tested, smoke tests pass | Go / No-Go |

---

## The Problem This Project Solves

Tony's only current window into GateForge is **Telegram messages from the System Architect** — a single-channel, summary-level view. He cannot see:

- What each agent is currently doing or whether it is idle, active, or blocked
- Where the SDLC pipeline is in its journey through six phases
- Which quality gates have passed, which are blocked, and why
- Live notifications from all VMs — only what the Architect chooses to relay
- Historical logs, Blueprint documents, QA metrics, or operations data
- The overall health of the system at a glance

**The GateForge Admin Portal makes the invisible visible.**

---

## What Is the GateForge Admin Portal

The GateForge Admin Portal is a **read-only observability dashboard** that gives Tony a single-pane-of-glass view into the entire GateForge multi-agent pipeline.

### One Sentence

> A web-based admin portal that monitors all GateForge AI agents, visualises the Lobster Pipeline progress, surfaces QA metrics and operations data, and provides a guided setup wizard — all without interfering with agent operations.

### Core Principles

These principles are non-negotiable. Every feature, every component, every API endpoint must honour them:

| Principle | What It Means | Why It Matters |
|-----------|--------------|----------------|
| **Read-Only** | The portal NEVER sends commands, prompts, or messages to any agent. It observes only. Tony continues to interact with the pipeline exclusively via Telegram → Architect. | Preserves the hub-and-spoke contract. If the portal could send instructions, it would bypass the Architect and break the communication model. |
| **Real-Time** | Live status updates via Server-Sent Events (SSE). No manual page refresh needed. Agent status changes appear within 2 seconds. | Tony needs to see what is happening now, not what happened last time he refreshed. |
| **Status Fidelity** | Every status value in the portal maps exactly to GateForge's canonical definitions. No invented states, no renamed labels, no approximate mappings. | If the portal says "in-progress" it must mean the same thing as "in-progress" in the Blueprint backlog. Misaligned status values would create confusion. |
| **5-Second Comprehension** | Tony should understand overall system health within 5 seconds of opening any page. | Executive users need rapid situational awareness, not data exploration. |
| **Graceful Degradation** | If a VM is unreachable, the portal shows "offline" for that VM and continues working for all others. One failure never breaks the whole portal. | VMs are independent. A network issue on VM-4 should not prevent Tony from seeing VM-3's developer status. |

---

## Features

### Feature 1: Agent Dashboard (Primary View)

The main view of the portal. A responsive card grid showing every agent across all 5 VMs.

**What each card shows:**
- Agent role name (e.g., "System Architect", "Developer (dev-01)")
- VM identifier (VM-1, VM-2, VM-3, etc.)
- AI model name (Claude Opus 4.6, Claude Sonnet 4.6, MiniMax 2.7)
- Live status with animated indicator:
  - `active` — green pulsing dot (agent is processing a task)
  - `idle` — gray static dot (agent has no current task)
  - `blocked` — orange blinking dot (agent cannot continue, waiting for input)
  - `error` — red blinking dot (agent encountered an error)
  - `offline` — dark dot with strikethrough (VM unreachable)
- Current task (task ID + title, e.g., "FEAT-014: Auth Module")
- Latest AI output snippet (truncated last few lines of model response)
- Notification priority badge if any active notification
- Time since last activity

**Click any card → Agent Detail View** with 4 tabs:
1. **Conversation History** — Full AI response timeline with timestamps, token count, latency
2. **Task History** — Completed, in-progress, and blocked tasks with filters
3. **Tools & Access** — Agent's available tool list, file system scope, masked env vars
4. **Performance** — Response time trends, token usage, task completion rate

**Multi-agent VMs:** VM-3 (Developers) and VM-4 (QC) display grouped cards with sub-agent IDs (dev-01, dev-02, qc-01, qc-02).

**Auto-refresh:** Configurable interval via SSE. No polling from the browser.

### Feature 2: Lobster Pipeline View

A visual horizontal pipeline showing the 6 SDLC phases as connected nodes.

**Each phase node shows:**
- Phase name and number (1–6)
- Current status: Not Started / In Progress (animated glow) / Completed / Blocked
- Task counters: ✓ passed / ⟳ working / ○ pending / ✗ blocked
- Click to expand phase detail panel

**Phase detail panel shows:**
- All tasks in this phase with status, assigned agent, and priority
- Quality gate status for this phase (Design Gate, Code Gate, QA Gate, Release Gate)
- Gate criteria checklist with pass/fail indicators
- PROMOTE / HOLD / ROLLBACK decision indicator for QA phases

**Pipeline connectors:** Lines between phase nodes with directional flow. Green for completed transitions, gray for pending.

**Pipeline history:** Dropdown to view past iterations.

### Feature 3: Blueprint Explorer

A file tree viewer for the Blueprint Git repository — the single source of truth for the entire GateForge project.

**Tree view:** Expandable/collapsible directory tree mirroring the Blueprint repo structure:
```
requirements/ → architecture/ → design/ → development/ → qa/ → operations/ → project/
```

**Document viewer:** Click any `.md` file to render it with full Markdown support.

**Status badges:** Each document shows its status: `Draft` / `In Review` / `Approved` / `Deprecated`.

**Recent changes:** Git commit log sidebar showing recent commits with agent prefixes.

**Decision log viewer:** Browse Architecture Decision Records (ADRs) from `project/decision-log.md`.

### Feature 4: Project Dashboard

Mirrors the project status tracking from the Blueprint's `project/status.md`.

- **Health cards:** 6 dimensions — Phase, Status, Schedule, Budget, Quality, Team — each Green/Yellow/Red
- **Active tasks table:** Filterable by module, status, assigned agent, priority
- **Backlog overview:** MoSCoW breakdown (Must / Should / Could / Won't)
- **Burndown chart:** Current iteration progress
- **Open blockers list:** Blocked tasks with details and responsible agent

### Feature 5: QA Metrics Dashboard

Surfaces all quality assurance data from GateForge's QA framework.

- **Coverage gauges:** Per-module bars for Unit / Integration / E2E with threshold markers (95% / 90% / 85%)
- **Gate decision cards:** PROMOTE / HOLD / ROLLBACK per module with criteria checklist
- **Defect summary:** Open defects by severity (Critical / Major / Minor / Cosmetic), defect density trend
- **Test automation metrics:** Coverage percentage, execution time, flaky test rate
- **Security panel:** OWASP Top 10 coverage checklist, Snyk dependency scan summary

### Feature 6: Operations Dashboard

Monitors deployment and runtime health.

- **Environment cards:** Dev / UAT / Production status with health indicators
- **SLO compliance gauges:** 5 gauges with thresholds:
  - API Availability ≥ 99.9%
  - p95 Latency ≤ 200ms
  - Error Rate ≤ 0.1%
  - DB Availability ≥ 99.95%
  - Query p95 ≤ 50ms
- **Error budget burn rate:** 4-tier alert visualization (Critical 14.4×, High 6×, Medium 3×, Low 1×)
- **Deployment log:** Recent deployments with status and rollback links
- **Incident timeline:** Chronological incident entries

### Feature 7: Notification Center

A real-time feed of all notifications from all VMs, colour-coded by priority.

| Priority | Colour | Meaning | Example |
|----------|--------|---------|---------|
| `CRITICAL` | Red | System down, data loss, security breach | Build failure on auth-module branch |
| `BLOCKED` | Orange | Agent cannot continue, waiting for decision | Cannot proceed with integration tests |
| `DISPUTE` | Yellow | Agent disagrees with another agent's output | Disagrees with Designer on caching strategy |
| `COMPLETED` | Green | Task done, results committed to Git | Database schema v2 review complete |
| `INFO` | Gray | Status update, no action needed | CI pipeline green, all tests passing |

**Features:** Filter by VM, priority, time range. Click to see full notification context and Git reference. Browser toast for CRITICAL/BLOCKED.

### Feature 8: Setup & Configuration Wizard

A guided 7-step wizard for first-time installation and ongoing configuration.

| Step | What It Configures |
|------|--------------------|
| 1. Admin Credentials | Username, password, JWT secret for portal access |
| 2. VM Registry | Add VM-1 through VM-5 with IP, port, hook token, agent secret. Auto-detect on 192.168.72.x subnet. Test connection button per VM. |
| 3. AI API Keys | Per-VM API keys for Anthropic, OpenAI, Google, MiniMax. Validated on save. |
| 4. Telegram Config | Bot token, chat ID for System Architect → Tony notifications |
| 5. Blueprint Repo | Git URL, SSH key or access token, branch selection |
| 6. Deployment Target | US VM Tailscale address, SSH credentials, environment paths (Dev/UAT/Prod) |
| 7. Review & Save | Summary of all settings, connection test for each service, export config |

**Post-setup health check dashboard:** Shows connection status for all VMs, gateway reachability, agent discovery, Blueprint repo accessible, Telegram bot active, US VM reachable.

**Import/export:** Configuration can be exported (secrets excluded) and imported for backup or migration.

---

## Complete Status Alignment

Every status value in the Admin Portal maps exactly to GateForge's canonical definitions. This table is the single source of truth for status rendering.

| Context | Values | Visual Treatment |
|---------|--------|-----------------|
| Task Status | `backlog` / `ready` / `in-progress` / `in-review` / `done` / `blocked` | Colour-coded chips |
| Task Priority | `Critical (P0)` / `High (P1)` / `Medium (P2)` / `Low (P3)` | Red / Orange / Yellow / Gray badges |
| MoSCoW | `Must` / `Should` / `Could` / `Won't` | Backlog prioritisation tags |
| Agent Activity | `active` / `idle` / `blocked` / `error` / `offline` | Animated dot (pulse / static / blink) |
| Notification Priority | `CRITICAL` / `BLOCKED` / `DISPUTE` / `COMPLETED` / `INFO` | Priority-coloured feed entries |
| QA Gate Decision | `PROMOTE` / `HOLD` / `ROLLBACK` | Green / Orange / Red banners |
| Quality Gate Type | `Design` / `Code` / `QA` / `Release` | Phase-specific gate cards |
| Pipeline Phase | Requirements → Architecture → Development → QA → Deployment → Iteration | Connected phase nodes |
| Phase Status | `not-started` / `in-progress` / `completed` / `blocked` | Phase node colour + animation |
| Document Status | `Draft` / `In Review` / `Approved` / `Deprecated` | Status badges in tree view |
| Project Health | `Green` (on track) / `Yellow` (at risk) / `Red` (blocked/behind) | Dashboard health cards |
| Deployment Environment | `Dev` / `UAT` / `Production` | Environment status cards |
| SLO Error Budget | `healthy (>50%)` / `warning (25-50%)` / `critical (<25%)` / `exhausted (0%)` | Colour-coded gauges |
| Defect Severity | `Critical` / `Major` / `Minor` / `Cosmetic` | Priority badges in defect list |

If you add a new status value, it must be defined here first. If you render a status, it must use the exact label and colour from this table.

---

## Technical Architecture

### Tech Stack

| Layer | Technology | Origin |
|-------|-----------|--------|
| Frontend | Next.js 14 + TypeScript + Tailwind CSS + shadcn/ui | Inherited from ClawDeck |
| Pipeline Visualization | React Flow | New for Admin Portal |
| Charts & Gauges | Recharts | Inherited from ClawDeck |
| Markdown Rendering | react-markdown + remark-gfm | Inherited from ClawDeck |
| Backend | Express.js + TypeScript | Inherited from ClawDeck |
| Git Integration | simple-git | New for Admin Portal |
| Real-Time Events | Server-Sent Events (SSE) | Backend EventEmitter → SSE stream |
| Authentication | JWT (HttpOnly cookie) + bcrypt | Inherited from ClawDeck |
| Portal Metadata | SQLite | New for Admin Portal |
| Deployment | Docker Compose | Inherited from ClawDeck |

### How the Portal Connects to GateForge

```
Admin Portal Backend
        │
        ├── Polls each VM's OpenClaw Gateway (HTTP GET, read-only)
        │     ├── Two-layer auth: X-Hook-Token + X-Agent-Secret headers
        │     ├── Retrieves: agent status, session data, tool usage, logs
        │     ├── Configurable interval (default 10s)
        │     └── One VM failure does not stop polling of others
        │
        ├── Clones Blueprint Git Repo (shallow clone, auto-pull)
        │     ├── File tree generation for Blueprint Explorer
        │     ├── File content reading for Document Viewer
        │     ├── Commit log extraction for Recent Changes
        │     └── Document status parsing from frontmatter
        │
        ├── Probes US VM via Tailscale SSH (health check only)
        │     └── Checks Dev / UAT / Prod environment status
        │
        └── Broadcasts changes to Frontend via SSE
              ├── agent.status — agent came online, went idle, started task
              ├── agent.output — new AI model response
              ├── notification.new — notification from any VM
              ├── pipeline.update — phase advanced, task counter changed
              ├── qa.gateUpdate — gate decision made (PROMOTE/HOLD/ROLLBACK)
              ├── ops.deployUpdate — deployment started/completed/failed
              ├── ops.sloAlert — SLO budget threshold crossed
              ├── blueprint.commit — new commit pushed to Blueprint repo
              └── system.health — VM went online/offline
```

### Read-Only Enforcement

The portal enforces read-only access at multiple levels:

1. **Gateway Client** — The `gatewayClient.ts` service ONLY uses HTTP GET. No POST, PUT, DELETE, or PATCH methods exist in the client.
2. **Route Layer** — No backend route accepts any payload that would be forwarded to a VM.
3. **Frontend** — No UI element exists that could trigger a write action to any agent. There is no chat input, no command box, no "send" button.
4. **Code Review Gate** — Any PR introducing a non-GET request to a VM gateway must be rejected.

This is not optional. If the portal could send instructions, it would bypass the System Architect and break the hub-and-spoke contract that is fundamental to GateForge.

---

## Advantages

### Why Build a Dedicated Admin Portal (vs. Alternatives)

| Alternative | Why the Admin Portal Is Better |
|-------------|-------------------------------|
| **Telegram only** | Telegram gives Tony a text-only, linear stream from the Architect. No visual pipeline, no multi-agent overview, no drill-down into individual agents, no QA metrics. |
| **Raw SSH into each VM** | Requires technical skill, no aggregated view, no real-time dashboard, scattered across 5 terminals. |
| **Generic monitoring (Grafana)** | Grafana monitors infrastructure metrics (CPU, RAM, disk), not agent-level state (which task, what AI output, what gate decision). The Admin Portal is purpose-built for GateForge's domain model. |
| **ClawDeck directly** | ClawDeck manages individual OpenClaw instances but has no concept of the SDLC pipeline, quality gates, Blueprint, or the hub-and-spoke topology. The Admin Portal is built on ClawDeck's tech stack but engineered for GateForge's workflow. |

### Key Advantages

1. **Full Pipeline Transparency** — See every phase, every gate, every task counter, every agent status in one view. No more waiting for the Architect to relay information via Telegram.

2. **Zero Interference** — Read-only design means the portal can be open 24/7 without any risk of disrupting agent operations or the hub-and-spoke communication model.

3. **Instant Situational Awareness** — 5-second comprehension rule. Open any page and immediately understand the system health, pipeline progress, or agent status.

4. **Historical Audit Trail** — Full conversation history per agent, complete notification log, Blueprint commit history, and decision log. Nothing is lost.

5. **Self-Service Setup** — 7-step wizard eliminates the need to manually SSH into VMs, edit config files, and test connections. First-time setup in minutes.

6. **Aligned Status Model** — Every status, every priority, every gate decision in the portal uses the exact same labels and values as the GateForge pipeline. No translation layer, no confusion.

7. **Built on Proven Stack** — Inherited from ClawDeck (Next.js 14, TypeScript, Tailwind, shadcn/ui, Express, Docker Compose) which is already tested with OpenClaw. Reduced risk, faster development.

---

## Ideas for Future Enhancement

These are not in scope for v1.0 but represent the roadmap for future iterations. They are documented here so that agents understand the long-term vision and can make architectural decisions that do not block these features.

### Lobster Pipeline YAML Editor (v2.0)
A visual editor for Lobster Pipeline YAML files. Drag-and-drop step creation, agent assignment, branching logic (on_pass/on_fail), and validation. This would allow Tony to define new pipeline workflows without writing YAML manually. **Requires** careful consideration of the read-only principle — this would be the first write feature and would need to go through the Architect's approval flow.

### Multi-Project Support (v2.0)
GateForge currently runs one project at a time. When it supports multiple concurrent projects, the Admin Portal should show a project selector and scope all views to the selected project. **Architecture impact:** All data models need a `projectId` field from the start.

### Role-Based Access Control (v1.5)
Currently Tony is the only user. RBAC would allow adding team members with different access levels:
- `admin` — full access including setup
- `viewer` — read-only dashboard access (no setup page)
- `auditor` — read-only with export capabilities
**Architecture impact:** JWT claims need a `role` field. Middleware needs role-checking.

### Mobile App (v2.5)
React Native mobile app for on-the-go monitoring. Push notifications for CRITICAL/BLOCKED events. Focused on the Agent Dashboard and Notification Center — not the full portal.

### Agent Cost Tracking (v1.5)
Track token usage per agent per day, compute cost based on model pricing (Claude Opus, Claude Sonnet, MiniMax), and display a cost dashboard. **Data needed:** Token count per response (from OpenClaw gateway), model pricing table (configurable).

### Historical Analytics (v2.0)
Trend reports over time: task throughput per iteration, defect density trends, pipeline cycle time, agent utilisation rates. Requires a time-series data store (could use SQLite with periodic snapshots or InfluxDB).

### Webhook Integration (v1.5)
Allow the portal to push notifications to external services (Slack, email, PagerDuty) when specific events occur (CRITICAL notification, QA gate ROLLBACK, deployment failure). Read-only principle still applies to GateForge agents — webhooks go to external systems, not back to agents.

---

## Implementation Roadmap

| Phase | Timeline | Deliverables |
|-------|----------|-------------|
| Phase 1: Foundation | Weeks 1–3 | Docker Compose scaffolding, Setup wizard (7-step), VM registry and health checks, JWT authentication |
| Phase 2: Core Views | Weeks 4–7 | Agent Dashboard with live status, Lobster Pipeline visualization, Notification Center with SSE, Blueprint Explorer |
| Phase 3: Dashboards | Weeks 8–10 | Project Dashboard, QA Metrics Dashboard, Operations Dashboard, SLO compliance gauges |
| Phase 4: Polish | Weeks 11–12 | Dark/light mode, responsive design, config import/export, documentation and testing |

---

## Agent Assignment Guide

When working on this project, each GateForge VM role has specific responsibilities:

| VM Role | What You Own for This Project |
|---------|------------------------------|
| **VM-1 Architect** | Task decomposition, Blueprint updates, progress tracking, quality gate enforcement, conflict resolution |
| **VM-2 Designer** | Infrastructure design (Docker, networking), database schema (SQLite), security assessment, monitoring design |
| **VM-3 Developers** | All frontend and backend code. Agent Dashboard, Pipeline View, Blueprint Explorer, QA page, Ops page, Notifications, Setup Wizard, API routes, SSE bus, Gateway client |
| **VM-4 QC Agents** | Test plans, test cases (unit, integration, E2E), test execution, coverage reporting, defect reporting |
| **VM-5 Operator** | Docker Compose deployment, CI/CD pipeline, install script, monitoring setup, deployment to target environment |

---

## Reference Project

The GateForge Admin Portal is built on the foundation of **ClawDeck** — an open-source dashboard for managing multiple OpenClaw instances.

- **Repository:** https://github.com/tonylnng/clawdeck
- **Tech Stack:** Next.js 14 + TypeScript + Tailwind CSS + shadcn/ui (frontend), Express.js + TypeScript (backend), Docker Compose (deployment)
- **What we inherit:** Component library (shadcn/ui), authentication flow (JWT + bcrypt), dashboard layout (sidebar + header), setup wizard pattern, agent card design, SSE log streaming, dark/light mode support
- **What we add:** Lobster Pipeline visualization (React Flow), Blueprint Git integration (simple-git), QA metrics dashboards (Recharts), Operations monitoring, Notification Center with priority-coded feed, 7-step setup wizard with auto-detect, complete status alignment with GateForge

---

## Quick Reference: Key Files

```
gateforge-admin-portal/
├── frontend/
│   ├── src/app/(portal)/           ← All authenticated pages
│   │   ├── page.tsx                   Agent Dashboard (primary view)
│   │   ├── pipeline/page.tsx          Lobster Pipeline View
│   │   ├── blueprint/page.tsx         Blueprint Explorer
│   │   ├── project/page.tsx           Project Dashboard
│   │   ├── qa/page.tsx                QA Metrics Dashboard
│   │   ├── operations/page.tsx        Operations Dashboard
│   │   ├── notifications/page.tsx     Notification Center
│   │   └── setup/page.tsx             Setup & Configuration
│   ├── src/components/                Reusable components per feature
│   ├── src/hooks/                     useSSE, useAgents, usePipeline, useNotifications
│   └── src/lib/
│       ├── api.ts                     Typed fetch wrapper with JWT cookie
│       └── constants.ts              ALL status colours, labels, mappings
│
├── backend/
│   ├── src/routes/                    API routes (agents, pipeline, blueprint, qa, ops, notifications, setup, auth, events)
│   ├── src/services/
│   │   ├── gatewayClient.ts           HTTP client for OpenClaw gateways (READ-ONLY)
│   │   ├── stateCache.ts             In-memory VM→Agent→State cache
│   │   ├── poller.ts                  Background polling loop with delta detection
│   │   ├── notificationBus.ts         EventEmitter-based SSE broadcaster
│   │   ├── blueprintGit.ts            Blueprint Git repo integration
│   │   └── usvmProbe.ts              US VM Tailscale health check
│   └── src/middleware/                auth.ts, rateLimiter.ts
│
├── docker-compose.yml                 One-command deployment
├── install.sh                         Guided installation script
└── .env.example                       All environment variables documented
```

---

## Summary

The GateForge Admin Portal is a read-only observability layer for the GateForge multi-agent SDLC pipeline. It exists because Tony needs to see what his AI agents are doing without interfering with their operation. It provides 6 core views (Agent Dashboard, Lobster Pipeline, Blueprint Explorer, Project Dashboard, QA Metrics, Operations), a Notification Center for real-time priority-coded events, and a Setup Wizard for guided configuration. Every status value aligns exactly with GateForge's canonical definitions. It inherits ClawDeck's proven tech stack and adds GateForge-specific visualisations.

**Remember:** Read-only. Always. No exceptions.

---

*GateForge Admin Portal — Designed by Tony NG | April 2026*

# GateForge Admin Portal — Implementation Plan

**Document Status:** Planning (pre-build)
**Version:** 1.0 (canonical, supersedes prior `…-IMPLEMENTATION.md` v2.5 and `…-EXTENDED-IMPLEMENTATION.md` v3.0)
**Created:** 2026-04-24
**Owners:** GateForge Agent Team (Architect-led, developer-executed)

> This is the **single canonical build plan** for the GateForge Admin Portal. It merges the previous two implementation documents (main v2.5 — 6707 lines, and extended v3.0 — 6139 lines) into one planning-stage guide aligned with the Control Tower spec.
>
> The portal is **not yet built**. This document describes *how we intend to build it*, phased to match the Control Tower roadmap. Detailed per-file code scaffolding, mock data, and full type dumps have been collapsed into the Control Tower data model (§5) and API outline (§6) so there is one source of truth per concern.

---

## Table of Contents

1. [Title & Status](#1-title--status)
2. [Relationship to the Control Tower Spec](#2-relationship-to-the-control-tower-spec)
3. [Product Scope and Non-Goals](#3-product-scope-and-non-goals)
4. [Architecture Overview](#4-architecture-overview)
5. [Tech Stack Assumptions](#5-tech-stack-assumptions)
6. [Target Repository & App Structure](#6-target-repository--app-structure)
7. [Phase 1 — Trust Visibility (default build target)](#7-phase-1--trust-visibility-default-build-target)
8. [Phase 2 — Blueprint Governance](#8-phase-2--blueprint-governance)
9. [Phase 3 — Security Posture](#9-phase-3--security-posture)
10. [Phase 4 — Healthcare Readiness](#10-phase-4--healthcare-readiness)
11. [Phase 5 — Controlled Actions (after RBAC & Audit)](#11-phase-5--controlled-actions-after-rbac--audit)
12. [Data Model Implementation](#12-data-model-implementation)
13. [API Implementation](#13-api-implementation)
14. [UI Pages & Routes](#14-ui-pages--routes)
15. [SSE / Live Event Stream](#15-sse--live-event-stream)
16. [Blueprint Validation Rules](#16-blueprint-validation-rules)
17. [Security & Safe-Evidence Rules](#17-security--safe-evidence-rules)
18. [Testing Plan](#18-testing-plan)
19. [Deployment & Operations Plan](#19-deployment--operations-plan)
20. [Agent Build Instructions](#20-agent-build-instructions)
21. [Open Questions](#21-open-questions)

---

## 1. Title & Status

**Title:** GateForge Admin Portal — Implementation Plan
**Status:** Planning. No code has been written yet; the site is not built. This document is the execution plan that will be handed to the GateForge multi-agent team once the Control Tower backlog (ADM-001 … ADM-012 for v1) is approved.
**Supersedes:**
- `GATEFORGE-ADMIN-PORTAL-IMPLEMENTATION.md` (v2.5, 2026-04-09)
- `GATEFORGE-ADMIN-PORTAL-EXTENDED-IMPLEMENTATION.md` (v3.0, 2026-04-10)

The two prior documents were pre-Control-Tower and partially conflicting. Their useful content — tech stack, setup commands, directory names, task IDs, schemas, acceptance criteria, milestone points — has been merged here.

---

## 2. Relationship to the Control Tower Spec

`GATEFORGE-ADMIN-PORTAL-CONTROL-TOWER.md` is the **product/architecture source of truth**. It defines:

- Positioning (read-only Control Tower and trust layer, v1)
- Operational modules (Mission Control, Agent Fleet, Notification Center, Dead-letter Queue, Blueprint Governance, Security & Secrets, Model & Provider Resilience, Healthcare Overlay, Setup & Installer, Audit & Management Reports, Future RBAC & Multi-project)
- ADM-xxx backlog (P0/P1/P2) with Given/When/Then acceptance criteria
- Suggested SQLite data model and API outline
- Five-phase roadmap and read-only v1 guardrails
- n8n positioning (integration layer, not SDLC orchestrator)

**This document does not redefine any of the above.** It translates the Control Tower decisions into concrete engineering steps: repo layout, per-phase task breakdowns, validation rules, and test plans. If this document and the Control Tower spec disagree on scope or positioning, the **Control Tower spec wins**. If they disagree on technical implementation choices (directory names, task IDs, library versions), **this document wins**.

Companion documents retained in `admin-portal/`:

- `README.md` — scope-of-work, 30-feature catalogue, orientation
- `GATEFORGE-ADMIN-PORTAL.md` — full behavioural feature specification (v1.0 features)
- `GATEFORGE-ADMIN-PORTAL-CONTROL-TOWER.md` — Control Tower product spec, ADM backlog, data model, roadmap
- `GATEFORGE-ADMIN-PORTAL-EXTENDED-FEATURES.md` — specification for the 22 extended features and Category G infra features

---

## 3. Product Scope and Non-Goals

### In scope (v1)

- A single-tenant, read-only operational control tower that surfaces fleet health, notification delivery, Blueprint governance, security posture, setup readiness, and evidence.
- Eight Phase-1 landing features (see §7) delivering "trust visibility" in the first shippable release.
- Append-only audit trail covering every state change the portal observes.
- SSE-based live updates so that an open tab reflects reality within ~2 s of upstream change.

### Explicitly out of scope (v1)

- **Agent control.** No start/stop/restart/redispatch/cancel/approve actions. Human↔pipeline interaction stays on Telegram → Architect.
- **Writes to the Blueprint repo.** The portal reads and links out only.
- **Multi-tenant / multi-project UX.** Data model carries `project_id` from day one, but the UI hides the switcher until v2.
- **Secret values.** Presence and metadata only, never contents.
- **Agent-to-agent dispatch / prompting from the portal.**

### Non-goals, even long term

- Becoming the SDLC orchestrator.
- Storing secret values.
- Acting as a code-review surface (code review lives in git).

---

## 4. Architecture Overview

```
┌─────────────── GateForge fleet (observed) ──────────────┐
│  VM-1 Architect   VM-2 Designer   VM-3..N Devs / QC     │
│  VM-5 Operator    Tailscale VPN   OpenClaw gateways     │
│  Blueprint Git    US VM (Dev/UAT/Prod)                  │
└─────────────┬───────────────────────────┬───────────────┘
              │ read-only                 │ read-only
              │ (HTTP GET, SSH stat,      │ (git clone/pull,
              │  journalctl, stat)        │  `test-communication` logs)
              ▼                           ▼
   ┌───────────────────────────────────────────────┐
   │  Admin Portal Backend (Node/Express + SQLite) │
   │                                               │
   │  Ingestion workers ──▶ SQLite (portal-owned)  │
   │     • gatewayClient      (GET /health, /status│
   │        two-layer auth: X-Hook-Token + X-Agent-│
   │        Secret)                                │
   │     • blueprintGit       (simple-git)         │
   │     • networkProbe       (Tailscale HTTPS)    │
   │     • notificationMonitor(journalctl parse)   │
   │     • setupValidator     (SSH stat)           │
   │     • testRunParser      (test-comm logs)     │
   │     • secretsInventory   (SSH stat, presence) │
   │     • openclawConfigFetcher (GET openclaw.json)│
   │     • usvmProbe          (Tailscale SSH health)│
   │                                               │
   │  Services that compose SQLite rows:           │
   │     missionControl, agentFleet, notifications,│
   │     dlq, blueprintGov, security, models,      │
   │     setup, compliance, reports, auditLogger,  │
   │     healthScore, webhookDispatcher            │
   │                                               │
   │  API layer (Express)   —  all GET in v1       │
   │  SSE bus (EventEmitter → /api/events/stream)  │
   └───────────────────────┬───────────────────────┘
                           │ JSON + SSE
                           ▼
   ┌───────────────────────────────────────────────┐
   │  Admin Portal Frontend (Next.js 14)           │
   │                                               │
   │  App Router pages (read-only UI)              │
   │  shadcn/ui components + Tailwind              │
   │  React Flow for topology / pipeline / DAGs    │
   │  Recharts for gauges / burndown / SLOs        │
   │  react-markdown for Blueprint rendering       │
   │  EventSource for SSE                          │
   └───────────────────────────────────────────────┘
```

### Read-only by construction

1. **Gateway client** uses HTTP GET only. PR gate rejects any non-GET method added to `gatewayClient.ts`.
2. **Middleware** rejects any non-GET verb under `/api/*` with HTTP 405 and writes an `audit_events` row (`event_type: rejected.write_attempt`).
3. **UI** contains no forms, buttons, or toggles that would send control instructions to agents. Remediation text is textual only, with deep links to Telegram for human action.
4. **Webhooks** flow outbound to Slack/email/PagerDuty/HTTP only, never back into any VM gateway.
5. **Secrets** are referenced by metadata only. Schema lint in CI rejects any new column named `*_value`/`*_secret`/`*_token` that isn't a presence flag or hash.

---

## 5. Tech Stack Assumptions

Inherited from ClawDeck where possible to reduce risk.

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| Frontend framework | Next.js 14 (App Router) + TypeScript 5 | Inherited from ClawDeck; SSR/streaming; strong typing |
| Styling | Tailwind CSS 3.4 + `tailwindcss-animate` | Inherited |
| Components | shadcn/ui (Radix primitives) + `lucide-react` icons | Inherited |
| Graphs / topology | `@xyflow/react` (React Flow v12) | Pipeline, Dependency Map, Network Topology |
| Charts | `recharts` ^3 | Gauges, SLOs, burndown, latency history |
| Markdown | `react-markdown` + `remark-gfm` + `react-syntax-highlighter` | Blueprint Explorer, YAML preview |
| Theming | `next-themes` | Dark/light mode |
| Virtualised lists | `react-window` + `react-virtualized-auto-sizer` | Audit feed, notification feed, DLQ |
| Backend framework | Express 4 + TypeScript | Inherited; minimal surface |
| HTTP client | `node-fetch` 2 | Only GET verbs used |
| Auth | JWT (`jsonwebtoken`) + `bcryptjs` + `cookie-parser` | HttpOnly cookie; SameSite=Strict |
| Hardening | `helmet`, `express-rate-limit`, `cors` | Baseline OWASP posture |
| Git integration | `simple-git` | Shallow clone + pull of Blueprint repo |
| Database | SQLite (single-tenant v1) | Low-ops; fits data volume; schema in §12 |
| SSH introspection (infra) | `node-ssh` | `stat`, `journalctl --no-pager`, `cat` of read-only artefacts |
| Real-time | Server-Sent Events (SSE) | One-way stream fits read-only model; no WebSocket server state |
| Deployment | Docker Compose (single host) | Inherited from ClawDeck |
| Test (frontend) | Jest + React Testing Library + Playwright | Unit + E2E |
| Test (backend) | Jest + supertest | Unit + integration |

### Package.json snapshots (high-signal entries)

Frontend `package.json` (selected):

```json
{
  "name": "gateforge-portal-frontend",
  "dependencies": {
    "next": "14.0.4",
    "react": "^18.2.0",
    "@xyflow/react": "^12.0.0",
    "recharts": "^3.8.0",
    "react-markdown": "^9.0.1",
    "remark-gfm": "^4.0.0",
    "react-syntax-highlighter": "^15.5.0",
    "react-window": "^1.8.10",
    "next-themes": "^0.2.1",
    "lucide-react": "^0.303.0",
    "class-variance-authority": "^0.7.0",
    "tailwind-merge": "^2.2.0",
    "tailwindcss-animate": "^1.0.7"
  },
  "devDependencies": {
    "typescript": "^5.3.2",
    "tailwindcss": "^3.4.0",
    "jest": "^29.7.0",
    "@playwright/test": "^1.40.0"
  }
}
```

Backend `package.json` (selected):

```json
{
  "name": "gateforge-portal-backend",
  "dependencies": {
    "express": "^4.18.2",
    "jsonwebtoken": "^9.0.2",
    "bcryptjs": "^2.4.3",
    "cookie-parser": "^1.4.6",
    "cors": "^2.8.5",
    "helmet": "^7.1.0",
    "express-rate-limit": "^7.1.5",
    "node-fetch": "^2.7.0",
    "simple-git": "^3.21.0",
    "node-ssh": "^13"
  },
  "devDependencies": {
    "typescript": "^5.3.2",
    "ts-node": "^10.9.1",
    "jest": "^29.7.0",
    "ts-jest": "^29.1.1"
  }
}
```

Versions are planning-stage pins; the first dev-01 bootstrap task may bump minors if a newer stable exists on build day.

### Naming & conventions

- Repository name (new): `gateforge-admin-portal`
- Container names: `gateforge-portal-frontend`, `gateforge-portal-backend`
- Commit prefix: `portal:`
- Branch convention: `feature/TASK-PORTAL-NNN-short-description`
- Env var prefix: `GATEFORGE_` for portal-specific; inherited names (JWT, ADMIN, etc.) for shared ClawDeck vars
- Task IDs: `TASK-PORTAL-NNN` (implementation), `ADM-xxx` (product backlog, owned by Control Tower)

---

## 6. Target Repository & App Structure

```
gateforge-admin-portal/
├── frontend/
│   ├── src/app/
│   │   ├── (auth)/login/page.tsx
│   │   └── (portal)/
│   │       ├── layout.tsx
│   │       ├── page.tsx                        ← Mission Control (Dashboard Home)
│   │       ├── agents/                          ← Agent Fleet
│   │       │   ├── page.tsx
│   │       │   └── [vmId]/[agentId]/page.tsx
│   │       ├── pipeline/                        ← Pipeline live + history
│   │       ├── project/                         ← Project Dashboard, iterations, releases
│   │       ├── quality/                         ← QA metrics, gate history
│   │       ├── operations/                      ← SLOs, deployments
│   │       ├── troubleshooting/                 ← Console, blockers, comms audit
│   │       ├── blueprint/                       ← Explorer, diff
│   │       ├── infrastructure/                  ← Network, notify, setup, tests, secrets, configs
│   │       ├── notifications/page.tsx
│   │       ├── dead-letters/page.tsx            ← ADM-005 (new)
│   │       ├── security/page.tsx                ← ADM-007
│   │       ├── models/page.tsx                  ← ADM-101..103
│   │       ├── compliance/page.tsx              ← ADM-201..203
│   │       ├── reports/page.tsx                 ← ADM-010, 110, 111
│   │       ├── audit/page.tsx                   ← ADM-009 Audit Event Feed
│   │       ├── webhooks/page.tsx                ← viewer only in v1.5
│   │       └── setup/page.tsx                   ← Setup & Configuration Wizard
│   ├── src/components/                          ← Feature-scoped folders
│   ├── src/hooks/                               ← useSSE, useAgents, useMissionControl …
│   └── src/lib/
│       ├── api.ts                               ← typed fetch wrapper (JWT cookie)
│       ├── sse.ts                               ← EventSource wrapper
│       └── constants.ts                         ← status colours/labels (single source)
│
├── backend/
│   ├── src/index.ts                             ← Express bootstrap, middleware, route registration
│   ├── src/config.ts                            ← env parsing + validation
│   ├── src/routes/                              ← auth, health, agents, notifications, dead-letters,
│   │                                              blueprint, security, models, setup, compliance,
│   │                                              reports, audit, events (SSE), infra/{network,
│   │                                              notifications, setup, tests, secrets, openclaw}
│   ├── src/services/
│   │   ├── gatewayClient.ts                     ← GET-only OpenClaw client
│   │   ├── stateCache.ts                        ← in-memory agent/VM state with delta detection
│   │   ├── poller.ts                            ← background polling orchestrator
│   │   ├── notificationBus.ts                   ← SSE broadcaster
│   │   ├── blueprintGit.ts                      ← simple-git wrapper
│   │   ├── usvmProbe.ts                         ← Tailscale SSH health check
│   │   ├── networkProbe.ts                      ← Tailscale HTTPS /health
│   │   ├── notificationMonitor.ts               ← journalctl parse
│   │   ├── setupValidator.ts                    ← SSH stat-only install validation
│   │   ├── testRunParser.ts                     ← test-communication log parser
│   │   ├── secretsInventory.ts                  ← SSH stat presence/metadata
│   │   ├── openclawConfigFetcher.ts             ← reads openclaw.json
│   │   ├── costTracker.ts                       ← token usage aggregation
│   │   ├── pipelineAnalytics.ts                 ← velocity + bottleneck
│   │   ├── healthScore.ts                       ← composite score
│   │   ├── rootCauseEngine.ts                   ← upstream trace
│   │   ├── webhookDispatcher.ts                 ← outbound only
│   │   └── auditLogger.ts                       ← append-only, immutable
│   ├── src/middleware/                          ← auth.ts, rateLimiter.ts, readOnlyGuard.ts
│   └── src/types/                               ← shared TypeScript types incl. infrastructure.ts
│
├── docker-compose.yml                           ← one-command deployment
├── install.sh                                   ← guided installer (wraps compose)
└── .env.example                                 ← every env var documented
```

Specific details preserved from prior docs:

- Docker containers `gateforge-portal-frontend`, `gateforge-portal-backend`, volumes `blueprint-clone`, `ssh-keys`, `config`, `test-logs`.
- Per-VM read-only SSH key mounted at `/data/ssh-keys/infra_rsa` (env: `INFRA_SSH_KEY_PATH`).
- `test-communication` outputs read from `/data/test-logs` (env: `TEST_LOGS_PATH`).

---

## 7. Phase 1 — Trust Visibility (default build target)

> **Goal:** The operator can open the portal and trust what it shows about fleet health and notifications.
> **Ships:** ADM-001 Mission Control, ADM-002 Agent Fleet, ADM-003 Notification Center, ADM-004 Notification Delivery Tracker, ADM-005 Dead-letter Queue viewer, ADM-008 Setup Checklist, ADM-009 Audit Event Feed, ADM-010 Release Readiness Report (initial), ADM-011 SSE event stream, ADM-012 Read-only guardrails.

Phase 1 is the **default build target** for any agent picking up the portal without further instruction. It must deliver:

1. **Mission Control** (landing `/`) — top banner `HEALTHY|DEGRADED|CRITICAL`, six module tiles with 24-hour rollups, live activity rail powered by SSE. ADM-001.
2. **Agent Fleet** — card grid of all agents across VMs, heartbeat freshness, `STALLED` pill when no heartbeat for `STALL_THRESHOLD_S` (default 120 s), detail drawer per agent. No action buttons. ADM-002.
3. **Notification Center** — priority-coded feed (`CRITICAL|BLOCKED|DISPUTE|COMPLETED|INFO`), filterable by VM/priority/time. ADM-003.
4. **Notification Delivery Tracker** — per-notification send→receive latency, retry count, `DELIVERED|RETRYING|DEAD_LETTER` outcome. Sub-view of the Notification Center. ADM-004.
5. **Dead-letter Queue viewer** — table with first-failure timestamp, retry count, final error; row detail drawer shows original payload and attempts; items > 24 h visually flagged; **no** replay button. ADM-005.
6. **Setup Checklist** — per-VM install-script status, `openclaw.json` checksum, Tailscale up, gateway reachable, `test-communication` matrix (Architect↔spoke, round-trip, HTTPS + MagicDNS, hook auth, agent auth). Textual remediation hints only. ADM-008.
7. **Audit Event Feed** — append-only reverse-chronological stream of every state change the portal observes. Filterable, CSV/JSON export (raw data only — rich PDF/hash-ledger lands in Phase 3). ADM-009.
8. **SSE event stream** — single `/api/events/stream` emitter covering `agent.status`, `agent.output`, `notification.new`, `pipeline.update`, `qa.gateUpdate`, `ops.deployUpdate`, `blueprint.commit`, `system.health`, `health.scoreUpdate`. ADM-011.
9. **Read-only guardrails** — 405 middleware + schema lint + UI gate. ADM-012.

### Phase 1 backlog (selected TASK-PORTAL-*** IDs, milestones)

| Task ID | Title | VM | Pts |
|---------|-------|----|-----|
| TASK-PORTAL-001 | Repo scaffolding + monorepo structure (`docker compose up --build` runs) | VM-3 dev-01 | 3 |
| TASK-PORTAL-002 | `config.ts` with `GATEFORGE_VMS` JSON parsing and env validation | VM-3 dev-01 | 2 |
| TASK-PORTAL-003 | JWT auth routes (`/api/auth/login`, `/logout`, `/me`) with HttpOnly cookie | VM-3 dev-01 | 3 |
| TASK-PORTAL-004 | Login rate limiter (5 req/min/IP) | VM-3 dev-01 | 2 |
| TASK-PORTAL-005 | Login page (`/login`) with form validation | VM-3 dev-02 | 3 |
| TASK-PORTAL-006 | Portal layout — Sidebar + Header shell, responsive | VM-3 dev-02 | 5 |
| TASK-PORTAL-007 | GET-only gateway client (X-Hook-Token + X-Agent-Secret); blocks non-GET at service layer | VM-3 dev-01 | 3 |
| TASK-PORTAL-008 | `stateCache` + `poller` (delta-only SSE publish) | VM-3 dev-01 | 5 |
| TASK-PORTAL-009 | `notificationBus` + `/api/events/stream` SSE endpoint | VM-3 dev-01 | 3 |
| TASK-PORTAL-010 | Mission Control page (ADM-001) | VM-3 dev-02 | 8 |
| TASK-PORTAL-011 | Agent Fleet page (ADM-002) with stall banner | VM-3 dev-02 | 8 |
| TASK-PORTAL-012 | Notification Center page (ADM-003, ADM-004) | VM-3 dev-02 | 8 |
| TASK-PORTAL-013 | DLQ viewer page (ADM-005) | VM-3 dev-02 | 5 |
| TASK-PORTAL-014 | `networkProbe` + Setup Checklist page (ADM-008) | VM-3 dev-01 + dev-02 | 13 |
| TASK-PORTAL-015 | `auditLogger` + Audit Event Feed page (ADM-009) | VM-3 dev-01 + dev-02 | 8 |
| TASK-PORTAL-016 | Read-only middleware + 405 response + audit row (ADM-012) | VM-3 dev-01 | 3 |
| TASK-PORTAL-017 | Release Readiness Report v1 (ADM-010 read-only JSON) | VM-3 dev-01 | 5 |
| TASK-PORTAL-018 | Phase 1 test pass — unit ≥ 90% backend / ≥ 85% frontend, E2E covers happy path + 405 path | VM-4 qc-01 | 13 |

### Phase 1 exit bar (from Control Tower §7)

- Mission Control loads real VM state within 5 s.
- Every required-trailer notification observed at the Architect relay produces a row in `notifications` within 2 s.
- DLQ depth = 0 in a healthy fleet; an injected failing notification reaches the DLQ within `retry_budget + 5 s`.
- Any non-GET request to `/api/*` returns 405 and appears in `audit_events`.

### Acceptance criteria (Given/When/Then) — condensed

*(Full text in `GATEFORGE-ADMIN-PORTAL-CONTROL-TOWER.md` §4. Reproduced here for developer convenience.)*

- **ADM-001 Mission Control.** Banner renders within 2 s; tiles within 5 s; unreachable upstream → `UNKNOWN` grey tile with tooltip, not false green.
- **ADM-002 Agent Fleet.** Heartbeat older than `STALL_THRESHOLD_S` → red banner + `STALLED` pill; no restart button.
- **ADM-003/004 Notification.** `DELIVERED` row with sent→received latency + zero retries on success; `DEAD_LETTER` row on retry exhaustion, payload copied to `dead_letters`, visible on DLQ page within 5 s.
- **ADM-005 DLQ.** Row shows id/source VM/task/priority/first-failure/retry count/final error; items > 24 h flagged; drawer shows payload and attempts; no replay button.
- **ADM-008 Setup.** Per-VM row shows `INSTALLED`, installer version, timestamp, exit code, checksum; failing `test-communication` check renders red cell with failing check name and last-success timestamp.
- **ADM-009 Audit.** State changes produce `audit_events` row within 2 s; rejected write attempt → HTTP 405 + `{error: "read_only_v1"}` + audit row.
- **ADM-010 Release Readiness.** `READY` only when all gates pass, zero blockers, zero DLQ depth, no open CRITICAL security findings.
- **ADM-011 SSE.** Same events enumerated in §15.

---

## 8. Phase 2 — Blueprint Governance

> **Goal:** The Blueprint is observed end-to-end; gate failures and missing artefacts are visible without reading git.
> **Ships:** ADM-006 Blueprint Governance, completes ADM-008 and ADM-010.

- **Blueprint Governance** (`/blueprint` and `/blueprint/compare`) — required-doc checklist (`PRD`, `ADR`, `QA-plan`, `Runbook` — set configurable per iteration), state `PRESENT|MISSING|STALE` (stale = > 7 days since iteration start with no updates), commit link per row. Gate board with evaluator agent id, commit SHA, reason string.
- **Blueprint Explorer** — file tree mirroring Blueprint repo; `react-markdown` rendering; status badges from frontmatter; commit log sidebar.
- **Release Readiness Report (final v1)** — JSON → PDF pipeline that reconciles the status against sample iterations.

### Phase 2 exit bar

- `READY` / `NOT READY` verdict matches human reviewer's conclusion from git + gate logs on five sample iterations.
- Setup page reflects `test-communication` results within 60 s of the suite's run.

---

## 9. Phase 3 — Security Posture

> **Goal:** Control-plane security is visible and actionable (as hints).
> **Ships:** ADM-007 Security & Secrets, ADM-101–103 Model & Provider Resilience, ADM-106 Hook/Agent auth health, ADM-107 Secret rotation, ADM-108 Topology, ADM-109 Config drift, ADM-110 Weekly Fleet Health Report, ADM-111 Report export with hashing, ADM-113 DLQ CSV export, ADM-114 Webhook config viewer.

Preserved specifics from prior `EXTENDED-IMPLEMENTATION`:

- `secretsInventory.ts` runs `stat` only — path, exists, mode (octal), owner, group, sizeBytes, mtime — never contents. Redaction lint asserts response bodies contain zero secret-content fields.
- Stale-secret threshold `SECRETS_ROTATION_THRESHOLD_DAYS` default 90.
- `openclawConfigFetcher.ts` reads `openclaw.json` at `OPENCLAW_CONFIG_PATH` (default `/opt/openclaw/openclaw.json`), redacts any field whose key matches `/token|secret|password|key|api/i`.
- `networkProbe.ts` targets `https://<hostname>.sailfish-bass.ts.net:18789/health` per VM; thresholds: green < 100 ms, amber 100–500 ms, red > 500 ms or unreachable; retains 200 latency points per VM.
- `notificationMonitor.ts` tails `journalctl -u gf-notify-architect` on VM-1 with `NOTIFY_JOURNAL_LINES` (default 1000 per poll) and reads dead-letter log.

### Phase 3 exit bar

- Zero secret-value leakage in any response body (automated test).
- Injected provider outage flips the provider tile to `DEGRADED|DOWN` within 60 s.
- Rotating a secret file updates `secret_inventory.rotated_at` within one ingestion cycle (≤ 5 min).

---

## 10. Phase 4 — Healthcare Readiness

> **Goal:** Healthcare/regulated customers can toggle an overlay that re-indexes existing signals against HIPAA / HITRUST controls and export an evidence bundle.
> **Ships:** ADM-201 Healthcare overlay + control matrix, ADM-202 Evidence bundler, ADM-203 BAA / subprocessor list.

- Overlay toggle persists in `projects.settings_json`.
- Control matrix rows: control id (e.g., HIPAA §164.312(a)(1), HITRUST 01.a), `COMPLIANT|GAP|UNKNOWN`, evidence link (→ `audit_events` or artefact), owner role, last verified.
- Evidence bundler assembles a reproducible zip (PDF + JSON) — same inputs → same `sha256`.
- BAA / subprocessor list is static, editable in config file.

### Phase 4 exit bar

- Curated sample of 10 controls resolves to `COMPLIANT|GAP` deterministically from `audit_events`, `secret_inventory`, `blueprint_artifacts`.
- Evidence bundle is reproducible.

---

## 11. Phase 5 — Controlled Actions (after RBAC & Audit)

> **Goal:** Carefully selected write actions, gated on RBAC + audit.
> **Ships:** ADM-204 RBAC, ADM-205 Multi-project, ADM-206 Controlled write actions (DLQ replay, secret-rotation trigger, provider manual failover), ADM-207 Incident postmortem report, ADM-208–211 advanced observability (Decision Graph, Session Replay, Root Cause, SLO Forecast).

Write-action rules (non-negotiable; from Control Tower §8.3):

1. Gated by RBAC — minimum role `approver`; no operation grants its own permission.
2. Confirmation modal shows the exact effect, affected agent/task/iteration, and a required `reason` field stored in `audit_events.payload_json`.
3. Paired audit events — `intent` before execution and `outcome` after. Missing outcome = in-doubt.
4. Notifies the Architect via the existing notification path (`CRITICAL` or `INFO`). Architect decides Telegram surface.
5. Rate-limited — e.g. ≤ 1 DLQ replay per (source VM, task id) per minute.
6. Reversibility labelled in the modal. DLQ replay is idempotent; secret rotation is not.
7. Never bypasses the Architect for SDLC actions.
8. Integration tests cover happy path and refused paths (wrong role, missing reason, Architect down).

### Phase 5 exit bar

- No write action exposed to role below `approver`.
- Every write action produces `intent` + `outcome` audit rows and a notification to the Architect.
- "Break-glass" read-only path exists with elevated severity logging.

**Cross-phase invariant:** until Phase 5 exits, the portal stays read-only.

---

## 12. Data Model Implementation

SQLite, single-tenant in v1, multi-project-ready via `project_id` on every row. The full DDL lives in `GATEFORGE-ADMIN-PORTAL-CONTROL-TOWER.md` §5 and is the **canonical schema**. Implementation notes only here:

| Table | Written by | Read by | Retention |
|-------|-----------|---------|-----------|
| `projects` | install wizard | all services | forever |
| `agents` | `openclawConfigFetcher` | fleet, mission control | refresh on config change |
| `heartbeats` | `poller` (gateway client) | fleet, analytics | 30 d rolling |
| `configs` | `openclawConfigFetcher` | config viewer, drift | 90 d rolling |
| `notifications` | `notificationMonitor` | notification center | 90 d rolling |
| `dead_letters` | `notificationMonitor` | DLQ viewer | 180 d rolling |
| `blueprint_checks` | `blueprintGit` + QA parser | governance, release readiness | forever |
| `blueprint_artifacts` | `blueprintGit` | governance, explorer | forever |
| `traceability_links` | `blueprintGit` + ADR parser | governance | forever |
| `security_checks` | `setupValidator`, `secretsInventory` | security | 180 d |
| `secret_inventory` | `secretsInventory` | security | snapshot per observation |
| `model_routes` | `openclawConfigFetcher` | models, drift | snapshot per observation |
| `provider_status` | provider probe | models | 90 d |
| `incidents` | incident aggregator | reports | forever |
| `audit_events` | every service | audit feed, reports | configurable (30/90/180/365 d) |
| `setup_checks` | `setupValidator`, `testRunParser` | setup dashboard | 90 d |
| `compliance_controls` | compliance config + rules engine | healthcare overlay | forever |
| `report_exports` | report generator | audit / compliance | forever (hash ledger) |

### Invariants (repeated here because they're easy to lose in migrations)

- Every table carries `project_id`. No cross-project joins.
- `secret_inventory` **must not** contain secret values. CI schema lint enforces.
- `audit_events.payload_json` schemas live next to the ingestion workers; changes require a migration test.
- Retention jobs are driven from `projects.settings_json`, not manual deletions.

---

## 13. API Implementation

All v1 endpoints are `GET`. Base URL `/api`. Auth via JWT cookie (browser) or `?token=` (SSE only — `EventSource` cannot set headers). Every endpoint accepts `?project_id=` and defaults to the single active project.

Canonical route list (expands the Control Tower §6 table):

| Method | Path | Feeds module | Notes |
|--------|------|--------------|-------|
| GET | `/api/health/summary` | Mission Control | Tile rollups |
| GET | `/api/agents` | Agent Fleet | `?vm=`, `?status=`, `?limit=`, `?cursor=` |
| GET | `/api/agents/{agent_id}` | Agent Fleet detail | joins heartbeats, cost, routes |
| GET | `/api/notifications` | Notification Center | filters by VM/priority/time |
| GET | `/api/notifications/{id}` | Notification detail | retry attempts inline |
| GET | `/api/dead-letters` | DLQ viewer | filterable by age/priority |
| GET | `/api/dead-letters/{id}` | DLQ detail | payload + attempt history |
| GET | `/api/blueprint/summary` | Blueprint Governance | docs + gate board + traceability |
| GET | `/api/blueprint/tree` | Blueprint Explorer | file tree |
| GET | `/api/blueprint/file` | Blueprint Explorer | `?path=` rendered markdown |
| GET | `/api/security/summary` | Security & Secrets | findings + secret inventory |
| GET | `/api/models/routes` | Models & Providers | routes + status + drift |
| GET | `/api/setup/checks` | Setup Checklist | installer + `test-communication` matrix + topology |
| GET | `/api/infra/network/topology` | Setup Checklist / Network | `NetworkTopology` |
| GET | `/api/infra/network/vm-status` | Setup Checklist | per-VM health |
| GET | `/api/infra/network/latency-history` | Setup Checklist | `?vmId=&points=` |
| GET | `/api/infra/notifications/log` | Notification Delivery | paginated |
| GET | `/api/infra/notifications/stats` | Notification Delivery | stat rollup |
| GET | `/api/infra/notifications/dead-letters` | DLQ viewer | overlay data |
| GET | `/api/infra/setup/vm-setup-status` | Setup Checklist | per-VM installer state |
| GET | `/api/infra/setup/drift-detection` | Setup Checklist | checksum mismatches |
| GET | `/api/infra/setup/history` | Setup Checklist | last 10 runs per VM |
| GET | `/api/infra/tests/latest-run` | Setup Checklist | TestRun with gate matrix |
| GET | `/api/infra/tests/history` | Setup Checklist | paginated |
| GET | `/api/infra/tests/agent-results/flaky` | Setup Checklist | `FlakyAgent[]` |
| GET | `/api/infra/secrets/inventory` | Security | presence metadata only |
| GET | `/api/infra/secrets/compliance` | Security | compliance summary |
| GET | `/api/infra/secrets/alerts` | Security | alerts |
| GET | `/api/infra/openclaw/config-per-vm` | Models / Setup | redacted JSON |
| GET | `/api/infra/openclaw/diff` | Models / Setup | `?left=&right=` |
| GET | `/api/infra/openclaw/validation` | Models / Setup | per-VM rules |
| GET | `/api/compliance/healthcare` | Healthcare Overlay | control matrix + gaps |
| GET | `/api/reports/release-readiness` | Reports | generate-and-return JSON |
| GET | `/api/reports/weekly-fleet-health` | Reports | weekly rollup |
| GET | `/api/audit/events` | Audit Feed | filter + cursor |
| GET | `/api/audit/events/{id}` | Audit Feed | single row |
| GET | `/api/events/stream` | SSE bus | see §15 |

### Response conventions

- Success: `{ ok: true, data, meta: { observed_at } }`.
- Degraded upstream: HTTP 200 with `{ ok: true, data, meta: { observed_at, degraded: true, reason } }` — UI renders grey `UNKNOWN` rather than a noisy error.
- Failure: `{ ok: false, error, meta: { observed_at } }`.
- Pagination: `?limit=` (default 100, max 1000), `?cursor=` opaque.
- Any non-GET verb on `/api/*` returns HTTP 405 `{ error: "read_only_v1" }` and writes `audit_events`.

---

## 14. UI Pages & Routes

*(Mapping from ADM-xxx to Next.js route. UI is in `frontend/src/app/(portal)/`.)*

| Route | Module | ADM |
|-------|--------|-----|
| `/` | Mission Control | ADM-001 |
| `/agents` | Agent Fleet | ADM-002 |
| `/agents/[vmId]/[agentId]` | Agent detail | ADM-002 |
| `/notifications` | Notification Center | ADM-003 |
| `/notifications/delivery` | Notification Delivery Tracker | ADM-004 |
| `/dead-letters` | Dead-letter Queue | ADM-005 |
| `/dead-letters/[id]` | DLQ detail drawer | ADM-005 |
| `/blueprint` | Blueprint Explorer | ADM-006 / F0 |
| `/blueprint/governance` | Required docs + gate board | ADM-006 |
| `/blueprint/compare` | Diff (Phase 2/3) | F2 |
| `/security` | Security & Secrets | ADM-007 |
| `/models` | Model & Provider Resilience | ADM-101..103 |
| `/infrastructure/network` | Network Topology | ADM-108 |
| `/infrastructure/notifications` | Delivery monitor (infra view) | ADM-004 |
| `/infrastructure/setup` | Setup & Installer Dashboard | ADM-008 |
| `/infrastructure/tests` | Communication Test Results | ADM-008 |
| `/infrastructure/secrets` | Secrets & Token Inventory | ADM-007 / ADM-107 |
| `/infrastructure/configs` | OpenClaw Config Viewer | ADM-109 |
| `/audit` | Audit Event Feed | ADM-009 |
| `/reports` | Report library (release, fleet, compliance) | ADM-010, 110 |
| `/compliance` | Healthcare Overlay | ADM-201..203 |
| `/pipeline` | Lobster Pipeline | B0 |
| `/project` | Project Dashboard | C0 |
| `/quality` | QA Metrics | D0 |
| `/operations` | Operations Dashboard | D1 |
| `/webhooks` | Webhook viewer (v1.5) | ADM-114 |
| `/setup` | Setup & Configuration Wizard | F1 |
| `/login` | Auth | — |

### UI rules inherited from prior specs

- Status colours/labels centralised in `frontend/src/lib/constants.ts`. Any new status must be added there first.
- 5-second comprehension target for every page's primary question.
- Graceful degradation: per-VM offline is isolated; one failing upstream never blanks the page.
- Project Health Score badge persistent in the Header (`healthScore.ts`).
- No component may render a secret value, even for debugging.

---

## 15. SSE / Live Event Stream

Single endpoint `/api/events/stream`. Authenticated via `?token=` (validated identically to the JWT cookie). Events:

| Event | Emitted by | Consumed by |
|-------|-----------|-------------|
| `agent.status` | `poller` delta vs `stateCache` | Mission Control, Agent Fleet |
| `agent.output` | `poller` (new AI response) | Agent detail |
| `agent.cost` | `costTracker` | Cost Tracker |
| `notification.new` | `notificationMonitor` | Mission Control, Notification Center |
| `notification.delivery` | `notificationMonitor` | Notification Delivery |
| `dlq.new` | `notificationMonitor` | DLQ viewer |
| `pipeline.update` | pipeline service | Pipeline |
| `pipeline.analytics` | `pipelineAnalytics` | Pipeline analytics |
| `qa.gateUpdate` | QA service | QA metrics, governance |
| `ops.deployUpdate` | ops service | Operations |
| `ops.sloAlert` | ops service | Operations |
| `ops.sloForecast` | ops service | SLO Forecast |
| `blueprint.commit` | `blueprintGit` | Blueprint Explorer, governance |
| `health.scoreUpdate` | `healthScore` | Header badge |
| `system.health` | `networkProbe`, `usvmProbe` | Mission Control, Setup |
| `security.finding` | `setupValidator`, `secretsInventory` | Security |
| `audit.new` | `auditLogger` (broadcast hook) | Audit Feed (tail mode) |
| `report.ready` | report generator | Reports |

Stream rules:

- Delivery must happen within ~2 s of upstream event (bounded by `AGENT_POLL_INTERVAL`, default 10 s for agent state; 30 s for network probes).
- Backpressure: if the client is slow, the server coalesces consecutive `agent.status` events per agent id.
- Disconnect → reconnect with `Last-Event-ID` to resume without loss of terminal events (`dlq.new`, `qa.gateUpdate`, `audit.new`).

---

## 16. Blueprint Validation Rules

Driven by `blueprintGit.ts` on each pull + commit webhook (if configured) and surfaced by `/api/blueprint/summary` and the governance page.

Required-doc checklist (configurable per iteration, default set):

| Key | File path pattern | Owner role | Freshness |
|-----|-------------------|-----------|-----------|
| `PRD` | `requirements/PRD.md` | Architect | ≤ 7 d since iteration start without updates |
| `ADR` | `architecture/decision-log.md` | Designer | — |
| `QA-plan` | `qa/test-plan.md` | QC | ≤ 7 d |
| `Runbook` | `operations/runbook.md` | Operator | ≤ 7 d |

States: `PRESENT|MISSING|STALE`. Stale is computed as "no git commit touching this path since iteration start + N days" (N default 7).

Traceability link check: for every requirement id (e.g. `FR-NNN`) there must be a chain requirement → design → code → test → defect (where defects exist). Broken chains land in `traceability_links` with `valid = 0`.

Gate board rules:

- Gate decision rows come from `blueprint_checks` (design / code / qa / release).
- QA gate thresholds from prior spec: Unit ≥ 95 %, Integration ≥ 90 %, E2E ≥ 85 %, critical failure < 70 %.
- Gate row highlights evaluator agent id, commit SHA, and reason string.

Release readiness rule (ADM-010):

```
READY  ≡ all blueprint_checks for current iteration = Pass
       ∧ open blockers for current iteration = 0
       ∧ dead_letters where first_failed_at > iteration_start = 0
       ∧ security_checks where severity = 'critical' and status = 'open' = 0
```

Anything else → `NOT READY` with enumerated failing conditions.

---

## 17. Security & Safe-Evidence Rules

1. **Secret values never touch the portal.** Schema lint rejects any column whose name suggests a secret value; response body test asserts no key matching `/token|secret|password|key|api_key|bearer/i` in any `/api/*` response is accompanied by a value field.
2. **JWT secret ≥ 32 hex chars**, validated at boot. Cookie flags `HttpOnly; Secure; SameSite=Strict` (fallback `SameSite=Lax` on non-HTTPS dev, logged as a warning).
3. **Rate limits:** login 5 req/min/IP with 5-minute lockout; setup test endpoints 10 req/min/IP (prevent subnet scanning); general endpoints 120 req/min/IP.
4. **CORS:** production allow-list = configured frontend URL only; localhost variants only in non-production.
5. **CSP (via `helmet`):** `default-src 'self'`, `connect-src 'self'`, `img-src 'self' data:`, no `unsafe-eval` / `unsafe-inline` in scripts.
6. **Read-only enforcement checklist:**
   - `gatewayClient.ts` exports GET-only helpers; PR that adds POST/PUT/DELETE there is rejected by CI (regex grep in CI).
   - No backend route proxies to `/hooks/agent`, `/v1/chat/completions`, or any gateway write endpoint.
   - Gateway auth credentials (`hookToken`, `agentSecret`) live in `.env` only; never sent to the frontend.
   - `/api/config/export` redacts tokens, keys, hashes.
   - Setup test endpoints require auth and are rate-limited.
7. **Evidence integrity:** `report_exports` stores `sha256` + path per export; generator is deterministic for identical inputs (required for Phase 4 Healthcare evidence bundler).
8. **Audit immutability:** `audit_events` is append-only; retention runs via scheduled job, never manual delete. No `UPDATE`/`DELETE` on `audit_events` anywhere outside retention.

---

## 18. Testing Plan

Coverage targets, aligned with GateForge QA gates (from prior spec):

| Layer | Target | HOLD threshold | ROLLBACK threshold |
|-------|--------|----------------|--------------------|
| Frontend unit | ≥ 85 % | < 85 % | < 60 % |
| Backend unit | ≥ 90 % | < 90 % | < 63 % |
| E2E (critical flows) | ≥ 85 % | < 85 % | < 60 % |

### Unit — frontend

Example pattern (inherited from prior spec):

```typescript
// StatusDot.test.tsx
it.each([
  ['active', 'WORKING'],
  ['idle', 'IDLE'],
  ['blocked', 'BLOCKED'],
  ['error', 'ERROR'],
  ['offline', 'OFFLINE'],
] as const)('renders status %s with label %s', (status, label) => {
  render(<StatusDot status={status} />);
  expect(screen.getByText(label)).toBeInTheDocument();
});
```

### Unit — backend

Pattern for service tests (inherited):

```typescript
// stateCache.test.ts
it('detects status change as delta', () => {
  cacheAgentState('vm-1', 'architect', mockAgent);
  expect(hasAgentChanged('vm-1', 'architect', { ...mockAgent, status: 'idle' })).toBe(true);
});
```

### Integration — API

`supertest` exercises each route with a running Express app and mock services. Every route has at least:

- 401 without auth.
- 200 with valid JWT.
- `meta.degraded = true` when upstream is stubbed failing (ensures graceful degradation).
- 405 for any non-GET verb (enforces ADM-012).

### E2E — Playwright

Scripted flows:

- Login → Mission Control renders with read-only banner.
- SSE → agent status updates live without reload (simulated via dev-only test endpoint).
- Notification → DLQ path: inject failing notification, verify DLQ row appears within retry budget + 5 s.
- 405 path: attempt `POST /api/agents` and assert body + `audit_events` row.

### Mock data strategy

`NEXT_PUBLIC_MOCK_API=true` toggles `src/lib/api.ts` to return from `src/lib/mockData/*.json`. The mock set covers agents, pipeline, notifications, QA coverage, ops SLOs, DLQ, blueprint tree, audit events. Useful for frontend development before backend is wired.

---

## 19. Deployment & Operations Plan

- **Target topology:** single host (portal VM) reachable on Tailscale from the GateForge fleet; US VM accessed via Tailscale SSH for health check.
- **Containers:** `gateforge-portal-frontend` (Next.js standalone), `gateforge-portal-backend` (Express). SQLite stored in a named volume (`portal-data`). Blueprint repo in named volume (`blueprint-clone`). Read-only SSH keys volume (`ssh-keys`). Test logs volume (`test-logs`).
- **Configuration:** `.env.example` documents every var. The install wizard (F1) generates the `.env` for first-time setup. Notable env vars:

```
# Auth
JWT_SECRET=                             # ≥ 32 hex chars
ADMIN_USERNAME=
ADMIN_PASSWORD_HASH=                    # bcrypt
# Fleet
GATEFORGE_VMS=[{...}]                   # JSON array: id, role, ip, port, model, hookToken,
                                        # agentSecret, agents[], isHub?
AGENT_POLL_INTERVAL=10
# Blueprint
BLUEPRINT_REPO_URL=
BLUEPRINT_BRANCH=main
BLUEPRINT_PULL_INTERVAL=60
BLUEPRINT_SSH_KEY=                      # or BLUEPRINT_PAT=
# Telegram (read-only observation)
TELEGRAM_BOT_TOKEN=
TELEGRAM_CHAT_ID=
# US VM
USVM_TAILSCALE_ADDR=
USVM_SSH_KEY=
# Infra (Phase 3)
INFRA_SSH_KEY_PATH=/data/ssh-keys/infra_rsa
INFRA_SSH_USER=gateforge
NETWORK_PROBE_INTERVAL=30
TEST_LOGS_PATH=/data/test-logs
SECRETS_ROTATION_THRESHOLD_DAYS=90
OPENCLAW_CONFIG_PATH=/opt/openclaw/openclaw.json
INFRA_MOCK_MODE=false
# Cost (Phase 3)
DAILY_COST_ALERT_USD=50
# Webhooks (Phase 3)
SMTP_HOST=
SMTP_PORT=
# Audit
AUDIT_RETENTION_DAYS=365
AUDIT_LOG_PATH=/data/audit.log
```

- **Installer:** `install.sh` wraps `docker compose up --build`, prompts for mandatory env values, generates bcrypt hash if a plain password is provided (dev-only path).
- **Performance budgets** (inherited): initial LCP < 3 s on 10 Mbps; client-side nav < 500 ms; Lighthouse desktop ≥ 90; per-page JS < 100 KB gzipped; initial JS < 150 KB gzipped. React Flow and Recharts are `next/dynamic`-loaded on relevant pages only.
- **SSE budgets:** agent status → frontend visible < 2 s; notification → toast < 500 ms after SSE receipt.
- **Backup:** SQLite dump + `audit_events` separate archive + `report_exports` hashes; nightly.

---

## 20. Agent Build Instructions

> This section tells each GateForge VM what it owns for portal delivery. It is an explicit contract so the Architect can dispatch cleanly.

| VM | Owns |
|----|------|
| **VM-1 Architect** | Decomposition of Phase-1 backlog into `TASK-PORTAL-NNN` dispatch tasks; Blueprint updates for portal specs; quality-gate enforcement; conflict resolution; prioritisation across ADM-001 … ADM-012 first, then Phase 2 onwards. |
| **VM-2 Designer** | Docker / networking infra design; SQLite schema migrations from §12 + Control Tower §5; security assessment (Phase 3 focus); monitoring design; read-only enforcement review; data-model migrations for multi-project. |
| **VM-3 Developers** | All frontend and backend code. Phase 1 = default build target (TASK-PORTAL-001 through TASK-PORTAL-018). Later phases add services listed in §4 and routes listed in §13. Pair dev-01 (backend) and dev-02 (frontend) on each ADM. |
| **VM-4 QC Agents** | Test plans + cases for every ADM (unit/integration/E2E); coverage reporting against the targets in §18; regression suite; automated test for "no secret value in any response body" (runs in CI every PR). |
| **VM-5 Operator** | `docker compose` + install script; CI/CD; monitoring setup; nightly backup of SQLite + audit log + report exports; verifies ingestion workers after deploy. |

### Default dispatch (new agent joining with no context)

1. Read `GATEFORGE-ADMIN-PORTAL-CONTROL-TOWER.md` end-to-end.
2. Read this document end-to-end.
3. If Phase 1 is unstarted: start at TASK-PORTAL-001 (scaffolding). If Phase 1 is partially done: pick the lowest-numbered unchecked task, confirm with Architect via Telegram, then dispatch.
4. Never author a new status value, column, event type, or ADM id without adding it first to `frontend/src/lib/constants.ts`, the Control Tower spec, or this document respectively.
5. If a required fact is missing, add it to §21 (Open Questions) and mark the task blocked — do not invent it.

### Cross-cutting rules

- Commit style: `portal: <verb> <scope>` (e.g. `portal: add MissionControl tiles`). No trailing punctuation.
- PRs must link their ADM id and the `TASK-PORTAL-NNN` id in the description.
- No PR may add a non-GET method to `gatewayClient.ts` or a non-GET route under `/api/*`. CI grep gate rejects both.
- No PR may add a response field that could contain a secret value. Schema lint rejects it.

---

## 21. Open Questions

Tracked here so that decisions are explicit, not silent. Each should resolve before the task that depends on it enters a dispatch.

1. **Stall threshold.** Is 120 s the right default for `STALL_THRESHOLD_S`? Per-role overrides (operator VMs may legitimately idle for much longer)?
2. **Audit retention default.** Project-level setting in `projects.settings_json` — what is the shipped default? Proposal: 180 days, tunable in install wizard.
3. **DLQ retention.** Proposed 180 d rolling; is that compatible with compliance obligations? Healthcare overlay (Phase 4) may require longer.
4. **Installer authentication for portal first-run.** Local-only bootstrap token vs. admin account on first boot?
5. **Provider probe source.** `status-page` scraping vs. internal gateway error-rate probe — which ships first in Phase 3? Likely both, ordered by reliability; needs confirmation.
6. **Compliance control set for Phase 4.** Which 10 controls form the "curated sample" the exit bar requires? Needs legal input.
7. **RBAC roles for Phase 5.** Control Tower enumerates `viewer|operator|approver|auditor`. Do we need a fifth (`compliance`) for evidence-bundle access?
8. **Multi-project UX.** When does the switcher appear in the Header? Proposal: as soon as `projects.count > 1`, not gated on explicit config.
9. **n8n boundaries.** Any portal-adjacent automation the operator expects to wire via n8n on day one (intake, approvals, digest notifications)? Control Tower §9 positions n8n outside the SDLC loop; which seams are in-scope for v1 observability?
10. **Webhook dispatcher PII posture.** Default redactions for outbound payloads (Slack, email) — any freely quotable fields vs. fields that must be scrubbed?

---

*Canonical implementation plan — supersedes the two prior implementation documents. For product direction, backlog, and phased roadmap see `GATEFORGE-ADMIN-PORTAL-CONTROL-TOWER.md`.*

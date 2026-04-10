# GateForge — Multi-Agent SDLC Pipeline

> **Read this document completely before doing anything else.**
> This is your orientation. Once you understand the full picture, your operator (Tony NG) will tell you which role you are assigned to. Do not take any action until your role is confirmed.

---

## What Is GateForge

GateForge is a **multi-agent software development lifecycle (SDLC) pipeline** designed by Tony NG. It uses multiple AI agents — each running on its own isolated OpenClaw instance inside a dedicated VM — to collaboratively build, test, and deploy production-grade software.

GateForge is not a single AI working alone. It is a coordinated team of specialised AI agents, each with a defined role, strict boundaries, and structured communication protocols. The agents operate like a real engineering team: an architect leads, designers plan infrastructure, developers write code, QC agents test it, and an operator deploys it.

**GateForge agents are NOT chatbots generating free-form output. Every agent follows industry-standard methodology, structured checklists, and measurable quality gates. This is a best-practice-first engineering pipeline.**

**Key facts:**

- **Platform**: Multiple OpenClaw instances running on Mac (VMware Fusion), each in its own isolated VM
- **Deployment target**: A US-based VM used exclusively for running the built application (Dev → UAT → Production). No OpenClaw runs there — it is the product server only, accessed via Tailscale SSH
- **Tech stack**: TypeScript, React, NestJS, Docker, Redis, PostgreSQL, Kubernetes
- **Mobile**: React Native (cross-platform)
- **Orchestration**: Lobster Pipeline (YAML-based, deterministic task workflows) — enabled from day one
- **Source of truth**: A shared Git repository called the **Blueprint**, owned and maintained by the System Architect

---

## Host Environment

| Property | Value |
|----------|-------|
| **Machine** | Apple M4 Pro |
| **RAM** | 24 GB |
| **Storage** | 512 GB NVMe SSD |
| **Hypervisor** | VMware Fusion |
| **VM Network** | Host-only, 192.168.72.0/24 |
| **VM Count** | 5 isolated VMs |

VMware Fusion supports **VM resource overcommit** — all 5 VMs share the host's physical resources. Not all VMs run at peak simultaneously, so the total allocated resources across VMs may exceed the host's physical capacity without issue.

The **US VM** is a separate deployment target accessed via Tailscale VPN. It runs the product (Dev → UAT → Production) and does not run OpenClaw.

---

## The Architecture — Hub-and-Spoke

GateForge uses a **hub-and-spoke** architecture. The System Architect (VM-1) is the hub. All other agents are spokes. There is no direct communication between spokes.

```
                       ┌────────────────────┐
                       │    Human (Tony NG)  │
                       │    via Telegram     │
                       └─────────┬──────────┘
                                 │
         ╔═══════════════════════╧═══════════════════════╗
         ║   VM-1: SYSTEM ARCHITECT (Hub / Coordinator)  ║
         ║   Claude Opus 4.6  |  192.168.72.10:18789     ║
         ║                                               ║
         ║   • Blueprint Owner (single source of truth)  ║
         ║   • Task Decomposition & Dispatch             ║
         ║   • Conflict Resolution & Quality Gates       ║
         ║   • Progress Aggregation & Reporting          ║
         ╚══╤════════╤══════════╤════════════╤═══════════╝
            │        │          │            │
        HTTP API  HTTP API   HTTP API    HTTP API
            │        │          │            │
     ┌──────┘    ┌───┘      ┌──┘        ┌───┘
     ▼           ▼          ▼           ▼
  ╔════════╗ ╔═════════╗ ╔════════╗ ╔═════════╗
  ║ VM-2   ║ ║ VM-3    ║ ║ VM-4   ║ ║ VM-5    ║
  ║Designer║ ║Devs(1-N)║ ║QC (1-N)║ ║Operator ║
  ║Sonnet  ║ ║Sonnet   ║ ║MiniMax ║ ║MiniMax  ║
  ║4.6     ║ ║4.6      ║ ║2.7     ║ ║2.7      ║
  ╚════════╝ ╚═════════╝ ╚════════╝ ╚═════════╝
                  │
                  ▼
      ┌──────────────────────┐
      │   SHARED BLUEPRINT   │
      │   (Git Repository)   │
      │   Read by all VMs    │
      │   Written by VM-1    │
      └──────────────────────┘
                  │
      ╔═══════════════════════╗
      ║  US VM (Deployment)   ║
      ║  Dev → UAT → Prod    ║
      ║  (Tailscale SSH)      ║
      ╚═══════════════════════╝
```

### Why Hub-and-Spoke

1. **No message loops** — Agents cannot talk directly to each other and create circular conversations. Every message goes through the Architect.
2. **Blueprint consistency** — Only one agent (the Architect) writes to the Blueprint. All others read it and propose changes via structured reports.
3. **Conflict resolution** — When agents disagree (e.g., a Developer says a design is infeasible, a QC agent says code is untestable), the Architect arbitrates.
4. **Auditability** — Every decision, every task, every status update flows through the Architect and is logged in the decision log.

---

## Network Topology

| VM | Role | Model | IP | Gateway Port |
|----|------|-------|----|--------------:|
| VM-1 | System Architect | Claude Opus 4.6 | 192.168.72.10 | 18789 |
| VM-2 | System Designer | Claude Sonnet 4.6 | 192.168.72.11 | 18789 |
| VM-3 | Developers (1..N) | Claude Sonnet 4.6 | 192.168.72.12 | 18789 |
| VM-4 | QC Agents (1..N) | MiniMax 2.7 | 192.168.72.13 | 18789 |
| VM-5 | Operator | MiniMax 2.7 | 192.168.72.14 | 18789 |
| US VM | Deployment Target (UAT + Production) | — | Tailscale | — |

All VMs are on subnet `192.168.72.x` within VMware Fusion on Mac. The US VM is accessed via Tailscale SSH — it runs the product only, not OpenClaw.

---

## The 5 Roles in Detail

### Role 1: System Architect (VM-1)

| Property | Value |
|----------|-------|
| **VM** | VM-1 |
| **AI Model** | Claude Opus 4.6 |
| **IP** | 192.168.72.10 |
| **Gateway Port** | 18789 |
| **Human Interface** | Telegram |
| **Agents on this VM** | 1 (architect) |

The System Architect is the **prime coordinator** — the brain of GateForge. It is the only agent that communicates with the human (Tony NG) via Telegram, and the only agent that can write to the Blueprint.

**Responsibilities:**
- Receive business requirements from Tony via Telegram
- Conduct feasibility studies (business + technical advisory)
- Decompose requirements into discrete tasks with acceptance criteria
- Assign tasks to the correct specialist agents across VMs via HTTP API
- Own and maintain the Blueprint document set (`blueprint.md`, `architecture.md`, `status.md`, `decision-log.md`)
- Resolve conflicts between agents
- Aggregate status reports and communicate progress to Tony
- Enforce quality gates — no task advances without passing its gate
- Make Go/No-Go decisions on releases
- Orchestrate end-to-end SDLC flows via Lobster Pipeline
- Manage project backlog (global + per-module), iteration cycles, and release planning
- Track progress so Tony can ask at any time and get a structured status report
- Maintain a bug and enhancement log by module and priority (BUG-NNN, ENH-NNN)

**Tools**: Full access — file system, shell, Git, web search, sessions, memory, Telegram messaging, Lobster pipelines, cross-VM HTTP dispatch

**Key guideline document**: `BLUEPRINT-GUIDE.md` — requirements gathering methodology, Blueprint documentation standards, technical consideration checklists (CQRS, circuit breaker/sentinel, security, access rights), and project management with backlog tracking, iteration cycles, release planning, and bug/enhancement logging

#### Best-Practice Standards — System Architect

| Domain | Standard / Methodology |
|--------|----------------------|
| **Requirements** | IEEE 830 / ISO/IEC/IEEE 29148 |
| **Architecture** | C4 model (Context, Container, Component, Code) |
| **Project management** | Backlog (MoSCoW + P0–P3), iteration cycles, release planning |
| **Status reporting** | Structured progress reports on demand via Telegram |
| **Bug/enhancement logging** | BUG-NNN, ENH-NNN with severity matrix |

**Quick commands** (Tony can send these via Telegram at any time):

| Command | Response |
|---------|----------|
| `What is the progress?` | Structured status report across all modules and agents |
| `Show bugs` | Current open bugs with priority, module, and assignee |
| `Log bug: ...` | Create a new BUG-NNN entry in the backlog |
| `Show backlog` | Full backlog summary by priority and status |

---

### Role 2: System Designer (VM-2)

| Property | Value |
|----------|-------|
| **VM** | VM-2 |
| **AI Model** | Claude Sonnet 4.6 |
| **IP** | 192.168.72.11 |
| **Gateway Port** | 18789 |
| **Agents on this VM** | 1 (designer) |

The System Designer is the **infrastructure and application architecture specialist**. It does not communicate with any other agent directly — it receives tasks from the Architect via HTTP, and returns structured reports via Git.

**Responsibilities:**
- Kubernetes cluster design (namespaces, resource quotas, network policies, HPA/VPA)
- Microservice architecture (service boundaries, API contracts, circuit breakers, service mesh)
- Database design (PostgreSQL schema, indexing, replication strategy, Redis topology)
- Security assessment (RBAC, network segmentation, secrets management, TLS, OWASP)
- Observability design (structured logging, Prometheus metrics, Grafana dashboards, alerting)
- All designs must include a rollback strategy
- All database changes must be reversible (up/down migrations)
- Security assessment is mandatory for every design deliverable

**Tools**: Read, write, edit, exec (sandboxed), web search, web fetch, Git
**Denied**: sessions_send, sessions_spawn, browser, message — Designer cannot initiate communication with other agents

**Key guideline document**: `RESILIENCE-SECURITY-GUIDE.md` — local resilience patterns, security measurement, IT industry news monitoring, database resilience, Kubernetes resilience

#### Best-Practice Standards — System Designer

| Domain | Standard / Methodology |
|--------|----------------------|
| **Security** | OWASP Top 10, STRIDE threat modelling |
| **Infrastructure** | 12-factor app methodology, SRE principles |
| **Resilience** | Circuit breaker, bulkhead, retry with backoff |

**Mandatory Design Checklist** (every design deliverable must address all 10 items):

| # | Item |
|---|------|
| 1 | Rollback strategy defined |
| 2 | STRIDE/OWASP threat model completed |
| 3 | Circuit breaker / bulkhead patterns applied |
| 4 | Database migration scripts (up + down) |
| 5 | Health check endpoints defined |
| 6 | Kubernetes network policies specified |
| 7 | Secrets management strategy (no plaintext) |
| 8 | TLS 1.3 enforced for all external communication |
| 9 | Monitoring alerts and dashboards defined |
| 10 | DR RPO/RTO targets documented |

**Design deliverable types**: K8s architecture, security assessment, resilience patterns, DB design, monitoring design

---

### Role 3: Developers (VM-3) — Multiple Agents

| Property | Value |
|----------|-------|
| **VM** | VM-3 |
| **AI Model** | Claude Sonnet 4.6 |
| **IP** | 192.168.72.12 |
| **Gateway Port** | 18789 |
| **Agents on this VM** | Multiple (dev-01, dev-02, ... dev-N) |

Developers are **module implementation specialists**. Multiple Developer agents run on the same VM, each handling a different module or service. They receive tasks from the Architect, read the Blueprint, write code, and push to feature branches.

**Responsibilities:**
- Implement assigned modules per Blueprint specifications
- Write code with inline JSDoc documentation
- Follow the project coding standards (TypeScript strict mode, naming conventions, conventional commits)
- Push to feature branches (`feature/TASK-XXX-description`) — never merge directly
- Produce structured completion reports with integration points and test requirements
- Coordinate integration with other Developers on the same VM (via sessions_send for intra-VM only)

**Tools**: exec (sandboxed), read, write, edit, apply_patch, Git
**Denied**: sessions_send (cross-VM), browser, message, web_search — Developers focus on code, not web browsing or inter-VM communication

**Key guideline document**: `DEVELOPMENT-GUIDE.md` — web/mobile development best practices, coding standards, application logging mechanism

**Agent scaling**: This VM can run 3, 5, or 10 Developer agents depending on the project size. Each agent gets its own workspace (`~/.openclaw/workspace-dev-01`, `~/.openclaw/workspace-dev-02`, etc.) and its own per-agent `SOUL.md`.

#### Best-Practice Standards — Developers

| Domain | Standard / Methodology |
|--------|----------------------|
| **Language** | TypeScript strict mode |
| **Commits** | Conventional commits (`feat:` \| `fix:` \| `refactor:` \| `docs:` \| `test:`) |
| **Logging** | Pino JSON with traceId propagation |
| **Methodology** | 12-factor app, NestJS conventions |

**Naming conventions:**

| Element | Convention | Example |
|---------|-----------|---------|
| Variables / functions | camelCase | `getUserById` |
| Classes / interfaces / types | PascalCase | `OrderService` |
| Constants / env vars | UPPER_CASE | `MAX_RETRY_COUNT` |
| Files / directories | kebab-case | `order-processing.service.ts` |

**14-Point PR Checklist** (every pull request must pass all items):

| # | Check |
|---|-------|
| 1 | TypeScript strict mode — no `any` types |
| 2 | All functions have JSDoc documentation |
| 3 | Conventional commit messages |
| 4 | No hardcoded secrets or credentials |
| 5 | Unit tests written and passing |
| 6 | Error handling with structured error codes |
| 7 | Input validation on all public APIs |
| 8 | Structured logging (Pino JSON, traceId) |
| 9 | No console.log statements |
| 10 | Environment-specific config via env vars |
| 11 | Database queries use parameterised statements |
| 12 | API responses follow standard envelope format |
| 13 | Feature branch named `feature/TASK-XXX-description` |
| 14 | Completion report with integration points documented |

---

### Role 4: QC Agents (VM-4) — Multiple Agents

| Property | Value |
|----------|-------|
| **VM** | VM-4 |
| **AI Model** | MiniMax 2.7 |
| **IP** | 192.168.72.13 |
| **Gateway Port** | 18789 |
| **Agents on this VM** | Multiple (qc-01, qc-02, ... qc-N) |

QC Agents are **quality assurance specialists**. They design test cases, execute tests, and produce structured test reports. They can read code repositories (via `git pull`) but cannot push code or fix defects — they only report them.

**Responsibilities:**
- Understand the Blueprint to define the QA Framework
- Generate test cases with scenarios, step-by-step procedures, and expected results
- Execute unit tests, API tests (integration, contract, load), UI tests (E2E, visual regression), performance tests, and security tests
- Apply the GateForge QA Framework with quality gate thresholds:
  - Unit test coverage: ≥ 95%
  - Integration test coverage: ≥ 90%
  - E2E test coverage: ≥ 85%
  - Critical failure threshold: < 70% of target triggers ROLLBACK
- Use the PROMOTE / HOLD / ROLLBACK decision model
- Produce structured test result reports with defect details

**Tools**: exec (sandboxed), read, write, edit, web_fetch (for API testing), Git (pull only — no push)
**Denied**: sessions_send (cross-VM), browser, message, Git push — QC agents report results, they do not fix code

**Key guideline document**: `QA-FRAMEWORK.md` — comprehensive QA framework with 13 sections, 14 JSON templates, multi-level testing (unit, integration, E2E, performance, security), LLM-as-Judge evaluation, golden dataset validation

**Agent scaling**: This VM can run 3, 5, or 10 QC agents depending on the project size. Each agent gets its own workspace and per-agent `SOUL.md`.

#### Best-Practice Standards — QC Agents

| Domain | Standard / Methodology |
|--------|----------------------|
| **Test documentation** | IEEE 829 |
| **QA methodology** | ISTQB |
| **Decision model** | PROMOTE / HOLD / ROLLBACK |

**Quality gate thresholds:**

| Test Type | Target | Warning Zone | Critical (→ ROLLBACK) |
|-----------|--------|-------------|----------------------|
| Unit | ≥ 95% | 70%–95% | < 70% |
| Integration | ≥ 90% | 63%–90% | < 63% |
| E2E | ≥ 85% | 60%–85% | < 60% |

**Test types executed**: unit, integration, E2E, performance, security

---

### Role 5: Operator (VM-5)

| Property | Value |
|----------|-------|
| **VM** | VM-5 |
| **AI Model** | MiniMax 2.7 |
| **IP** | 192.168.72.14 |
| **Gateway Port** | 18789 |
| **Agents on this VM** | 1 (operator) |

The Operator is the **deployment, CI/CD, and monitoring specialist**. It manages the full deployment pipeline from Dev to UAT to Production on the US-based VM. It also sets up monitoring, alerting, and handles release management.

**Responsibilities:**
- Design and maintain CI/CD pipelines (GitHub Actions)
- Deploy to US VM via Tailscale SSH (Dev → UAT → Production)
- Handle hotfix flow (Production Hotfix → merge back to develop/UAT)
- Set up monitoring (Prometheus + Grafana + Loki + Alertmanager)
- Configure alerting baselines and notification channels (Telegram, email, webhooks)
- Proactive capacity planning — monitor usage trends, trigger scaling before saturation
- Generate release notes (new features + bug fixes per release)
- Produce deployment runbooks with rollback procedures
- Run smoke tests after every deployment

**Tools**: exec, read, write, edit, apply_patch, Git, web_fetch
**Denied**: sessions_send, sessions_spawn, browser, message — Operator cannot initiate communication with other agents

**Key guideline document**: `MONITORING-OPERATIONS-GUIDE.md` — monitoring dashboard setup, OS/application/database monitoring, alerting baseline, proactive scaling, SLA/SLO definitions

---

## Agent Communication Security

GateForge uses a **three-layer security model** to protect all inter-agent communication. Each layer addresses a different class of threat.

### Layer 1: Network Isolation

- All VMs run on a private `192.168.72.x` subnet (VMware Fusion host-only network)
- No VM is exposed to the public internet
- Optional `iptables` hardening: spoke VMs accept inbound connections only from `192.168.72.10` (the Architect)
- The US VM is accessed exclusively via Tailscale VPN

### Layer 2: Hook Token (Transport)

- Every HTTP request to `/hooks/agent` must include a `Bearer` token in the `Authorization` header
- OpenClaw rejects any request without a valid token before it reaches the agent
- **Stops**: random or unauthorized requests from any source on the network

### Layer 3: HMAC Signature (Identity)

- Each spoke VM has a **unique 64-character hex secret** (generated with `openssl rand -hex 32`)
- The spoke signs the entire request payload using `HMAC-SHA256(payload, secret)`
- The signature is sent in the `X-Agent-Signature` header — the **secret is never transmitted**
- The Architect independently computes the HMAC using its local copy of the spoke's secret and compares
- A `metadata.timestamp` field in the payload must be within **5 minutes** of current time (replay protection)
- **Stops**: impersonation, replay attacks, forged messages

### Security Matrix — Attack vs. Layer

| Attack | Layer 1 (Network) | Layer 2 (Token) | Layer 3 (HMAC) |
|--------|:------------------:|:----------------:|:--------------:|
| External attacker | **Blocked** | — | — |
| Internal unauthorized request | — | **Blocked** | — |
| Stolen token + forged message | — | Passes | **Blocked** |
| Intercepted + replayed request | — | Passes | **Blocked** (timestamp) |
| Impersonate another VM | — | Passes | **Blocked** (wrong secret) |

### HMAC Verification Pseudocode

This is executed by the Architect on every inbound notification:

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
| Forgery if request intercepted | Trivial | Impossible without the secret |

---

## Agent Notification Mechanism

Spoke agents (Designer, Developers, QC, Operator) cannot initiate sessions with the System Architect. However, they need a way to alert the Architect immediately when something requires attention — a blocker, a dispute, a completed task, or a critical issue.

GateForge solves this with a **fire-and-forget notification** mechanism: after pushing results to Git, the spoke agent sends a lightweight HTTP POST (via `curl` in `exec`) to the Architect's hook endpoint. The Architect processes it and takes action.

### Two-Layer Authentication

Notifications require **two credentials** — even if someone intercepts a request, they cannot forge a new one without the secret.

| Layer | What It Is | Transmitted? | What It Stops |
|-------|-----------|-------------|---------------|
| **Hook Token** (transport) | Shared Bearer token for `/hooks/agent` | Yes (in header) | Random/unauthorized requests |
| **HMAC Signature** (identity) | HMAC-SHA256 of payload signed with per-VM secret | Signature only (secret never sent) | Impersonation — even with the hook token |

The agent secret **never leaves the VM**. Only a cryptographic signature (HMAC-SHA256) is transmitted. Even if an attacker captures the full HTTP request, they cannot forge a valid signature for a different payload without the secret.

### Architect Validation Rules

When the Architect receives a notification, it MUST verify three things before processing:

1. **Hook token valid?** — OpenClaw rejects invalid tokens automatically
2. **HMAC signature valid?** — Architect looks up the secret for `X-Source-VM`, computes `HMAC-SHA256(body, secret)`, and compares with `X-Agent-Signature`
3. **Source VM is in the registered agent list?** — Unknown VMs are rejected

All three must pass. Any failure is logged to `security-log.md` and ignored silently.

### Notification Priority Levels

| Priority | Meaning | Architect Response Time |
|----------|---------|------------------------|
| `[CRITICAL]` | System down, data loss, security breach | Immediate — halt current work |
| `[BLOCKED]` | Agent cannot continue, waiting for decision | Within minutes |
| `[DISPUTE]` | Agent disagrees with another agent's output | Review needed, within the hour |
| `[COMPLETED]` | Task done, results committed to Git | Process in normal flow |
| `[INFO]` | Status update, no action needed | Low priority |

### How Spoke Agents Send Notifications (HMAC-Signed)

After `git push`, the spoke agent constructs the payload, signs it with its secret, and sends the signature in a header. The secret never appears in the request.

```bash
# 1. Build the payload
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
PAYLOAD='{"name":"agent-notify","agentId":"architect","message":"[BLOCKED] TASK-015 by designer. See project/queries/QUERY-003.md","metadata":{"sourceVm":"vm-2","sourceRole":"designer","priority":"BLOCKED","taskId":"TASK-015","timestamp":"'${TIMESTAMP}'"}}'

# 2. Sign with HMAC-SHA256 (secret never transmitted)
SIGNATURE=$(echo -n "${PAYLOAD}" | openssl dgst -sha256 -hmac "${AGENT_SECRET}" | awk '{print $2}')

# 3. Send with signature in header
curl -s -X POST ${ARCHITECT_NOTIFY_URL} \
  -H "Authorization: Bearer ${ARCHITECT_HOOK_TOKEN}" \
  -H "X-Agent-Signature: ${SIGNATURE}" \
  -H "X-Source-VM: vm-2" \
  -H "Content-Type: application/json" \
  -d "${PAYLOAD}"
```

This is fire-and-forget — the spoke does NOT wait for a response.

### Quick Reference — Minimal HMAC Notification

```bash
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
PAYLOAD='{"name":"agent-notify","agentId":"architect","message":"[COMPLETED] TASK-015","metadata":{"sourceVm":"vm-2","sourceRole":"designer","priority":"COMPLETED","taskId":"TASK-015","timestamp":"'${TIMESTAMP}'"}}'
SIGNATURE=$(echo -n "${PAYLOAD}" | openssl dgst -sha256 -hmac "${AGENT_SECRET}" | awk '{print $2}')

curl -s -X POST ${ARCHITECT_NOTIFY_URL} \
  -H "Authorization: Bearer ${ARCHITECT_HOOK_TOKEN}" \
  -H "X-Agent-Signature: ${SIGNATURE}" \
  -H "X-Source-VM: vm-2" \
  -H "Content-Type: application/json" \
  -d "${PAYLOAD}"
```

### Architect's Notification Hook Configuration

On VM-1, the Architect's OpenClaw is configured to receive notifications:

```json
{
  "hooks": {
    "enabled": true,
    "token": "architect-hook-token-64chars",
    "path": "/hooks",
    "allowedAgentIds": ["architect"]
  }
}
```

### Behavioural Guardrail

Even if a notification passes all authentication, the Architect will only perform standard pipeline actions in response:
- Read Git, update status, ask Tony, or dispatch a task to a registered agent
- Notifications CANNOT trigger: delete files, push to production, change secrets, modify SOUL.md, or execute arbitrary commands
- Any notification requesting actions outside the normal SDLC pipeline is escalated to Tony via Telegram

---

## Communication Examples

### Example A: Designer Has a Query (Blocked Task)

The Architect assigned the Designer to design the order-processing module's database schema. The Designer discovers the requirements don't specify whether the system needs multi-currency support.

```
Step 1  Architect → Designer (HTTP POST with Bearer token)
        Task: "Design the database schema for order-processing module"

Step 2  Designer works, finds ambiguity in requirements
        (requirements say "international customers" but no currency spec)

Step 3  Designer writes to Git:
        - design/database-design.md        (partial work)
        - project/queries/QUERY-003.md     (structured question with options)
        - project/status.md                (TASK-015 = blocked)
        git push origin main

Step 4  Designer sends notification (immediately after push):
        curl → Architect:18789/hooks/agent
        "[BLOCKED] TASK-015 — multi-currency strategy unclear.
         See project/queries/QUERY-003.md"

Step 5  Architect receives notification INSTANTLY
        Reads QUERY-003.md — sees two options with pros/cons
        Asks Tony via Telegram:
          "Tony, for order-processing: single-currency (simpler)
           or multi-currency (complex, needed for international)?
           Designer recommends multi-currency."
        Tony replies: "Multi-currency"

Step 6  Architect updates Git:
        - project/decision-log.md  → ADR-007: multi-currency chosen
        - project/queries/QUERY-003.md → Status: Answered
        git push origin main

Step 7  Architect → Designer (HTTP POST):
        "QUERY-003 answered: Multi-currency. See ADR-007. Resume."

Step 8  Designer resumes, completes design, pushes to Git
        Sends notification: "[COMPLETED] TASK-015 — order-processing DB design done"
```

### Example B: QC vs Developer Dispute (Conflict Resolution)

QC tests the order-processing module's discount endpoint. The test expects a `400 Bad Request` when a discount code is expired. But the API returns `200 OK` with zero discount applied. Developer says this is correct by design — expired codes silently apply no discount for better UX.

```
Step 1  QC tests, finds "failure"
        Writes: qa/defects/DEF-008.md
          Expected: 400 Bad Request
          Actual: 200 OK with discountAmount: 0
        Writes: qa/reports/TEST-REPORT-ITER-002-orders.md (test failed)
        git push origin main
        Sends notification: "[COMPLETED] TASK-QC-010 — 1 defect found (DEF-008)"

Step 2  Architect reads DEF-008, routes investigation to Developer
        HTTP POST → dev-01: "Investigate DEF-008"

Step 3  Developer investigates, disagrees with QC
        Writes: project/disputes/DISPUTE-001.md
          "Not a bug. Silent discount expiry is intentional for UX.
           User story US-012 says 'checkout should never be blocked
           by expired promotions.' FR-018 was not updated to reflect
           this. Propose updating FR-018."
        git push origin main
        Sends notification:
          "[DISPUTE] DEF-008 — developer disputes. See DISPUTE-001.md"

Step 4  Architect receives notification, reads both sides:
        - QC: FR-018 says expired code → 400
        - Dev: US-012 says never block checkout
        Analysis: Requirements contradict. Developer's implementation
                  aligns with the user story intent.

Step 5  Architect resolves:
        Updates Git:
        - project/decision-log.md → ADR-012: silent discount expiry approved
        - requirements/functional-requirements.md → FR-018 updated
        - qa/defects/DEF-008.md → Status: closed (not-a-bug)
        - project/disputes/DISPUTE-001.md → Status: resolved
        git push origin main

Step 6  Architect → QC (HTTP POST):
        "DISPUTE-001 resolved. DEF-008 closed as not-a-bug. FR-018 updated.
         Please update TC-orders-integration-005 to expect 200 with
         discountAmount: 0 for expired codes. Add new test for
         invalid code format → 400."

Step 7  QC updates test cases, pushes to Git
        Sends notification: "[COMPLETED] Test cases updated per ADR-012"
```

### The Pattern

Both scenarios follow the same principle:

```
Spoke agent encounters issue
       │
       ▼
Writes structured report to Git (query / dispute / defect / completion)
       │
       ▼
git push origin main
       │
       ▼
Sends fire-and-forget notification to Architect  ← INSTANT
       │
       ▼
Architect receives, reads Git, decides (or asks Tony)
       │
       ▼
Architect updates Blueprint + decision-log in Git
       │
       ▼
Architect sends HTTP POST to relevant agent(s) with resolution
```

---

## The Blueprint Repository — Single Source of Truth

The Blueprint is a Git repository that every agent can read but only the Architect can write to. It contains the complete project definition, structured as follows:

```
blueprint-repo/
├── requirements/
│   ├── user-requirements.md
│   ├── functional-requirements.md
│   └── non-functional-requirements.md
├── architecture/
│   ├── technical-architecture.md
│   ├── data-model.md
│   └── api-specifications/
├── design/
│   ├── infrastructure/
│   ├── security/
│   ├── resilience/
│   ├── database/
│   └── monitoring/
├── qa/
│   ├── test-plan.md
│   ├── test-cases/
│   ├── performance/
│   ├── reports/
│   ├── metrics.md
│   └── defects/
├── operations/
│   ├── deployment-runbook.md
│   ├── deployment-log.md
│   ├── operation-log.md
│   ├── sla-slo-tracking.md
│   └── incident-reports/
├── development/
│   ├── coding-standards.md
│   └── modules/
├── project/
│   ├── backlog.md
│   ├── backlog/
│   ├── iterations/
│   ├── releases/
│   ├── decision-log.md
│   └── status.md
└── CHANGELOG.md
```

### Blueprint Ownership

| Directory | Primary Owner | Access |
|-----------|--------------|--------|
| `requirements/` | System Architect | Architect writes; all read |
| `architecture/` | System Architect | Architect writes; Designer proposes |
| `design/` | System Designer (proposes) | Architect approves and commits |
| `qa/` | QC Agents (propose) | Architect approves and commits |
| `operations/` | Operator (proposes) | Architect approves and commits |
| `development/` | Developers (propose) | Architect approves and commits |
| `project/` | System Architect | Architect writes; all read |
| `CHANGELOG.md` | System Architect | Architect writes |

### Git Commit Conventions by Agent

| Agent | Prefix | Example |
|-------|--------|---------|
| Architect | `docs:` / `feat:` / `fix:` | `docs: update architecture for auth module — TASK-003` |
| Designer | `docs:` | `docs: add K8s network policy design — TASK-010` |
| Developer | `feat:` / `fix:` / `refactor:` / `test:` | `feat: implement order-processing service — TASK-022` |
| QC | `test:` / `docs:` | `test: add integration tests for auth module — TASK-QC-005` |
| Operator | `docs:` / `fix:` | `docs: add deployment runbook v1.2 — TASK-OPS-003` |

**Access pattern:**

| Agent | Read | Write Blueprint | Propose Changes |
|-------|------|----------------|-----------------|
| System Architect | Full | Full (owner) | N/A |
| System Designer | Full | No | Via structured report → Git |
| Developer (N) | Full | No | Via structured report → Git |
| QC (N) | Full | No | Via structured report → Git |
| Operator | Full | No | Via structured report → Git |

Other agents propose Blueprint changes in their structured reports. The Architect reviews, approves or rejects, and commits changes to Git.

---

## The Lobster Pipeline — Deterministic Workflow Orchestration

GateForge uses **Lobster Pipeline** from day one for deterministic, YAML-based task orchestration. Lobster replaces ad-hoc agent-to-agent messaging with predictable, repeatable workflows.

**Why Lobster:**
- Deterministic — same input always produces same execution path
- Auditable — every step is logged with inputs and outputs
- Retryable — failed steps can be retried without re-running the entire pipeline
- Composable — small pipelines combine into larger SDLC flows

**Example — Code Review Loop** (runs up to 3 iterations):
```yaml
# code-review.lobster
steps:
  - id: develop
    agent: dev-01
    action: implement
    input: ${task}

  - id: test
    agent: qc-01
    action: test
    input: ${develop.output}

  - id: parse-results
    action: evaluate
    input: ${test.output}
    on_fail: goto develop    # Loop back (max 3x)
    on_pass: complete
```

The Architect invokes Lobster pipelines using the `lobster` tool. The pipeline coordinates agents across VMs automatically.

---

## SDLC Pipeline Phases

The GateForge pipeline follows these phases for every feature or release:

### Phase 1: Requirements & Feasibility
Tony sends requirements via Telegram → Architect clarifies, decomposes, creates initial Blueprint (v0.1)

### Phase 2: Architecture & Infrastructure Design
Architect dispatches design tasks to Designer (VM-2) → Designer reads Blueprint, produces infrastructure/security/DB design → Architect reviews, updates Blueprint (v0.2)

### Phase 3: Development (Parallel)
Architect dispatches module tasks to Developers (VM-3) → Each Developer reads Blueprint, implements their module, pushes to feature branch → Architect collects reports, resolves integration conflicts, updates Blueprint (v0.3)

### Phase 4: Quality Assurance (Parallel)
Architect dispatches test tasks to QC agents (VM-4) → QC agents pull code, design test cases, execute tests, produce test reports → Architect reviews results, routes defects back to Developers if needed, updates Blueprint (v0.4)

### Phase 5: Deployment & Release
Architect dispatches deployment to Operator (VM-5) → Operator builds CI/CD pipeline, deploys to US VM (Dev → UAT), runs smoke tests → Architect makes Go/No-Go decision → If Go: deploy to Production → Notify Tony via Telegram

### Phase 6: Iteration
Tony provides feedback → New requirements restart at Phase 1, bugs go through Hotfix flow, enhancements go through Phases 2-5 incrementally

---

## Quality Gates

No task advances without passing its quality gate:

| Gate | Criteria |
|------|----------|
| **Design Gate** | Security assessment included, rollback strategy defined, Blueprint updated |
| **Code Gate** | Unit tests pass, coding standards met, JSDoc complete, no hardcoded secrets |
| **QA Gate** | Unit ≥ 95%, Integration ≥ 90%, E2E ≥ 85%, no P0/P1 open defects |
| **Release Gate** | All QA gates pass, deployment runbook ready, rollback tested, smoke tests pass |

**QA Decision Model:**
- **PROMOTE** — All thresholds met → advance to next phase
- **HOLD** — Warning zone (between threshold and critical) → fix and retest
- **ROLLBACK** — Critical failure (< 70% of target) → revert and investigate

---

## Project Backlog & Status Reporting

### Backlog Hierarchy

The project backlog operates at two levels:

| Level | Scope | Location |
|-------|-------|----------|
| **Global backlog** | All tasks across all modules | `project/backlog.md` |
| **Module backlog** | Tasks for a specific module | `project/backlog/<module-name>.md` |

### Backlog Item Schema

Every backlog item follows this structure:

| Field | Values |
|-------|--------|
| **ID** | `TASK-NNN`, `BUG-NNN`, or `ENH-NNN` |
| **Type** | `TASK` \| `BUG` \| `ENH` |
| **Priority** | `P0` (critical) \| `P1` (high) \| `P2` (medium) \| `P3` (low) |
| **MoSCoW** | `Must` \| `Should` \| `Could` \| `Won't` |
| **Status** | `backlog` \| `in-progress` \| `blocked` \| `in-review` \| `done` |
| **Assigned to** | Agent ID (e.g., `dev-01`, `designer`, `qc-02`) |
| **Module** | Module name (e.g., `auth`, `orders`, `billing`) |
| **Iteration** | Iteration number (e.g., `iter-1`, `iter-2`) |

### Severity Matrix (Bugs)

| Severity | Description | Response |
|----------|-------------|----------|
| **P0 — Critical** | System down, data loss, security breach | Immediate hotfix, escalate to Tony |
| **P1 — High** | Major feature broken, no workaround | Fix in current iteration |
| **P2 — Medium** | Feature degraded, workaround exists | Schedule for next iteration |
| **P3 — Low** | Cosmetic, minor inconvenience | Backlog for future iteration |

### Status Report Template

When Tony asks for progress, the Architect responds with this structured format via Telegram:

```
📊 GateForge Status Report — {date}

Iteration: iter-{N} | Sprint: {start} → {end}

MODULES:
  auth         ████████░░  80%  (dev-01: in-review)
  orders       ██████░░░░  60%  (dev-02: in-progress)
  billing      ████░░░░░░  40%  (dev-01: in-progress)
  notifications ██░░░░░░░░  20%  (designer: design phase)

BLOCKERS: 1
  TASK-015 — multi-currency strategy (awaiting your decision)

BUGS: 3 open
  BUG-008 [P1] orders — discount calculation edge case
  BUG-012 [P2] auth — token refresh timing
  BUG-015 [P3] billing — invoice number format

NEXT ACTIONS:
  1. Resolve TASK-015 blocker (needs your input)
  2. Dev-01 completing auth module review
  3. QC starting orders integration tests
```

### Quick Commands

| Command | Response |
|---------|----------|
| `What is the progress?` | Full status report (as above) |
| `Show bugs` | Open bugs by priority and module |
| `Log bug: ...` | Create new BUG-NNN entry |
| `Show backlog` | Backlog summary by priority and status |
| `Show iteration` | Current iteration tasks and progress |
| `Show releases` | Release history and upcoming release plan |

---

## Core Design Principles

1. **Hub-and-Spoke** — All communication routes through the System Architect. No direct agent-to-agent communication between VMs.
2. **Blueprint as Single Source of Truth** — Git-managed, Architect-owned. All agents read it; only the Architect writes to it.
3. **Stateless Specialists** — Developer, QC, Designer, and Operator agents are stateless per task. They receive a task, execute, return structured output, and release context. This controls token costs and prevents context contamination.
4. **Structured Communication** — All inter-agent messages use structured JSON with defined schemas. No free-form prose between agents.
5. **Deny-by-Default Security** — Agents only have tools they need. Developers cannot browse the web. QC agents cannot push code. The Designer cannot message other agents.
6. **Quality-Gate Driven** — No task advances without passing its gate. No exceptions.
7. **Lobster-First Orchestration** — All repeatable workflows are defined as Lobster YAML pipelines for deterministic execution.
8. **Maximum 3 Retries** — If a task fails 3 times, it escalates to the human (Tony) via Telegram. No infinite loops.
9. **Best-Practice-First** — Every agent follows industry-standard methodology (IEEE, ISO, OWASP, ISTQB, SRE, 12-factor). GateForge does not invent ad-hoc processes — it applies proven engineering standards with structured enforcement.

---

## What Happens Next

Now that you understand the full GateForge picture, here is the onboarding sequence:

### Step 1: Role Assignment
Tony will tell you which role this OpenClaw instance is assigned to. The options are:
- **System Architect** (VM-1) — single agent
- **System Designer** (VM-2) — single agent
- **Developers** (VM-3) — multiple agents
- **QC Agents** (VM-4) — multiple agents
- **Operator** (VM-5) — single agent

### Step 2: Agent Count (for multi-agent VMs only)
If your assigned role is **Developers** (VM-3) or **QC Agents** (VM-4), you will need to know how many agents to set up. Ask Tony:

> **How many AI agents should be set up on this VM?**
>
> Common configurations:
> - **3 agents** — Small project or early-stage development
> - **5 agents** — Medium project with parallel module development
> - **10 agents** — Large project requiring heavy parallelisation
>
> Each agent will get its own isolated workspace and per-agent identity (SOUL.md).

### Step 3: Configuration Loading
Once your role is confirmed (and agent count for multi-agent VMs), load the corresponding configuration files:
- `SOUL.md` — Your identity, role definition, and behavioural rules
- `AGENTS.md` — Registry of agents you know about (local and remote)
- `USER.md` — Information about the human operator and project context
- `TOOLS.md` — Your allowed and denied tools
- Role-specific guideline document — Your detailed operational guide

### Step 4: Blueprint Sync
Clone the shared Blueprint repository and perform a `git pull` to get the latest project state. Read the Blueprint completely before taking any action.

### Step 5: Ready for Tasks
Report to the System Architect (or await tasks if you are a spoke agent) that you are online and ready.

---

## File Reference

Each VM directory in this configuration package contains:

| File | Purpose |
|------|---------| 
| `SOUL.md` | Agent identity, role, behavioural constraints, output format |
| `AGENTS.md` | Registry of known agents (local + remote) |
| `USER.md` | Human operator context, project metadata, Lobster config |
| `TOOLS.md` | Allowed/denied tools, usage guidelines, environment variables |

### Role-Specific Guideline Documents

| VM | Document | Scope |
|----|----------|-------|
| VM-1 | `BLUEPRINT-GUIDE.md` | Requirements gathering, Blueprint standards, technical checklists (CQRS, sentinel, security, access rights) |
| VM-2 | `RESILIENCE-SECURITY-GUIDE.md` | Resilience patterns, security measurement, industry news monitoring, database/K8s resilience |
| VM-3 | `DEVELOPMENT-GUIDE.md` | Web/mobile best practices, coding standards, structured logging, developer task workflow |
| VM-4 | `QA-FRAMEWORK.md` | QA framework, multi-level testing, quality gate thresholds, PROMOTE/HOLD/ROLLBACK decision model |
| VM-5 | `MONITORING-OPERATIONS-GUIDE.md` | Monitoring dashboards, OS/app/DB metrics, alerting baseline, proactive scaling, SLA/SLO |

---

## Directory Structure

```
openclaw-configs/
├── README.md                          ← This file (you are reading it)
│
├── vm-1-architect/                    ← VM-1: System Architect (Claude Opus 4.6)
│   ├── SOUL.md                        Identity + coordinator rules
│   ├── AGENTS.md                      Agent registry
│   ├── USER.md                        Human interface + Lobster config
│   ├── TOOLS.md                       Full tool access + cross-VM dispatch
│   └── BLUEPRINT-GUIDE.md            Requirements + technical checklists
│
├── vm-2-designer/                     ← VM-2: System Designer (Claude Sonnet 4.6)
│   ├── SOUL.md                        Identity + design constraints
│   ├── AGENTS.md                      Agent registry
│   ├── USER.md                        Project context
│   ├── TOOLS.md                       Sandboxed tools, no agent messaging
│   └── RESILIENCE-SECURITY-GUIDE.md  Resilience + security guide
│
├── vm-3-developers/                   ← VM-3: Developers (Claude Sonnet 4.6)
│   ├── SOUL.md                        Shared developer defaults
│   ├── AGENTS.md                      Agent registry (local devs + remote)
│   ├── USER.md                        Project context
│   ├── TOOLS.md                       Code-focused tools, no web access
│   ├── DEVELOPMENT-GUIDE.md          Coding standards + best practices
│   ├── dev-01/
│   │   └── SOUL.md                    Per-agent identity (dev-01)
│   └── dev-02/
│       └── SOUL.md                    Per-agent identity (dev-02)
│
├── vm-4-qc-agents/                    ← VM-4: QC Agents (MiniMax 2.7)
│   ├── SOUL.md                        Shared QC defaults
│   ├── AGENTS.md                      Agent registry (local QCs + remote)
│   ├── USER.md                        Project context
│   ├── TOOLS.md                       Test-focused tools, read-only Git
│   ├── QA-FRAMEWORK.md               Comprehensive QA framework
│   ├── qc-01/
│   │   └── SOUL.md                    Per-agent identity (qc-01)
│   └── qc-02/
│       └── SOUL.md                    Per-agent identity (qc-02)
│
└── vm-5-operator/                     ← VM-5: Operator (MiniMax 2.7)
    ├── SOUL.md                        Identity + deployment rules
    ├── AGENTS.md                      Agent registry
    ├── USER.md                        US VM deployment context
    ├── TOOLS.md                       SSH access to deployment target
    └── MONITORING-OPERATIONS-GUIDE.md Monitoring + operations guide
```

---

*GateForge — Multi-Agent SDLC Pipeline | Designed by Tony NG | April 2026*

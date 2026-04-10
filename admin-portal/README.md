# GateForge Admin Portal

> **You are reading the scope-of-work and orientation document for the GateForge Admin Portal.**
> Read this document completely before taking any action. It tells you what this project is, why it exists, what it does, how it fits into GateForge, and what you are expected to build. Once you understand the full picture, refer to the companion documents for detailed specifications and implementation instructions.

---

## Document Map

| Document | Purpose | When to Read |
|----------|---------|--------------| 
| **This file (README.md)** | Scope of work, background, full 30-feature set, advantages, ideas | First — orientation |
| `GATEFORGE-ADMIN-PORTAL.md` | Complete feature specification (15 sections, all views, all statuses) | When you need the exact behaviour of a feature |
| `GATEFORGE-ADMIN-PORTAL-IMPLEMENTATION.md` | Developer-ready build guide (types, routes, components, configs) | When you are implementing a module |
| `GATEFORGE-ADMIN-PORTAL-EXTENDED-FEATURES.md` | Full specification for the 22 new features (v1.5–v2.5), with priority matrix and nav structure | When you are implementing any non-v1.0 feature |
| `README.md` (root) | GateForge architecture — hub-and-spoke, roles, communication | When you need to understand the parent system |

---

## Background

### What Is GateForge

GateForge is a **multi-agent software development lifecycle (SDLC) pipeline** designed by the end-user (CTO / Project Lead). It uses 5 isolated AI agent instances — each running on its own VM inside OpenClaw — to collaboratively build, test, and deploy production-grade software.

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
                         the end-user (Human)
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
- Only the Architect communicates with the end-user (via Telegram)
- Only the Architect writes to the Blueprint (Git repository — single source of truth)
- No spoke-to-spoke communication — all messages route through the Architect
- All inter-agent messages use structured JSON, never free-form prose
- Spoke agents notify the Architect via fire-and-forget HTTP POST after git push
- Two-layer authentication: Hook Token (transport) + Agent Secret (identity per VM)

### The SDLC Pipeline

GateForge follows six phases for every feature or release:

| Phase | What Happens | Key Agent | Outcome |
|-------|-------------|-----------|---------|
| 1. Requirements & Feasibility | The end-user sends requirements via Telegram → Architect clarifies and decomposes | Architect | Blueprint v0.1 |
| 2. Architecture & Infrastructure | Architect dispatches design tasks → Designer produces infrastructure/security/DB design | Designer | Blueprint v0.2 |
| 3. Development (Parallel) | Architect dispatches module tasks → Developers implement, push to feature branches | Developers | Blueprint v0.3 |
| 4. Quality Assurance (Parallel) | Architect dispatches test tasks → QC agents design and execute tests | QC Agents | Blueprint v0.4 |
| 5. Deployment & Release | Architect dispatches to Operator → Deploy to US VM (Dev → UAT → Prod) | Operator | Production release |
| 6. Iteration | the end-user feedback → new requirements or hotfix flow | All | Next cycle |

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

the end-user's only current window into GateForge is **Telegram messages from the System Architect** — a single-channel, summary-level view. He cannot see:

- What each agent is currently doing or whether it is idle, active, or blocked
- Where the SDLC pipeline is in its journey through six phases
- Which quality gates have passed, which are blocked, and why
- Live notifications from all VMs — only what the Architect chooses to relay
- Historical logs, Blueprint documents, QA metrics, or operations data
- The overall health of the system at a glance
- How much each agent or pipeline phase costs in token spend
- The cause chain behind a blocked task or stalled pipeline

**The GateForge Admin Portal makes the invisible visible.**

---

## What Is the GateForge Admin Portal

The GateForge Admin Portal is a **read-only observability dashboard** that gives the end-user a single-pane-of-glass view into the entire GateForge multi-agent pipeline.

### One Sentence

> A web-based admin portal that monitors all GateForge AI agents, visualises the Lobster Pipeline progress, surfaces QA metrics and operations data, provides troubleshooting and analytics tools, and offers a guided setup wizard — all without interfering with agent operations.

### Core Principles

These principles are non-negotiable. Every feature, every component, every API endpoint must honour them:

| Principle | What It Means | Why It Matters |
|-----------|--------------|----------------|
| **Read-Only** | The portal NEVER sends commands, prompts, or messages to any agent. It observes only. the end-user continues to interact with the pipeline exclusively via Telegram → Architect. | Preserves the hub-and-spoke contract. If the portal could send instructions, it would bypass the Architect and break the communication model. |
| **Real-Time** | Live status updates via Server-Sent Events (SSE). No manual page refresh needed. Agent status changes appear within 2 seconds. | the end-user needs to see what is happening now, not what happened last time he refreshed. |
| **Status Fidelity** | Every status value in the portal maps exactly to GateForge's canonical definitions. No invented states, no renamed labels, no approximate mappings. | If the portal says "in-progress" it must mean the same thing as "in-progress" in the Blueprint backlog. Misaligned status values would create confusion. |
| **5-Second Comprehension** | the end-user should understand overall system health within 5 seconds of opening any page. | Executive users need rapid situational awareness, not data exploration. |
| **Graceful Degradation** | If a VM is unreachable, the portal shows "offline" for that VM and continues working for all others. One failure never breaks the whole portal. | VMs are independent. A network issue on VM-4 should not prevent the end-user from seeing VM-3's developer status. |

---

## Features

The portal has **30 features** organised into 6 categories. Features marked **● v1.0** are the original scope. Features marked **◆ New** are the extended set.

| Category | Feature | Tag |
|----------|---------|-----|
| **A. Agent Observability** | Agent Dashboard | ● v1.0 |
| | Agent Decision Graph | ◆ New |
| | Agent Session Replay | ◆ New |
| | Agent Cost Tracker | ◆ New |
| | Agent Comparison Matrix | ◆ New |
| **B. Pipeline & Progress** | Lobster Pipeline View | ● v1.0 |
| | Pipeline Run History & Replay | ◆ New |
| | Pipeline Analytics & Bottleneck Detection | ◆ New |
| | Pipeline YAML Preview & Validation | ◆ New |
| | Task Lifecycle Tracker | ◆ New |
| **C. Project Management** | Project Dashboard | ● v1.0 |
| | Iteration Manager | ◆ New |
| | Dependency Map | ◆ New |
| | Risk Register & Heat Map | ◆ New |
| | Decision Timeline | ◆ New |
| | Release Manager | ◆ New |
| **D. Quality & Operations** | QA Metrics Dashboard | ● v1.0 |
| | Operations Dashboard | ● v1.0 |
| | Defect Deep-Dive & Trend Analysis | ◆ New |
| | Deployment Diff & Rollback Viewer | ◆ New |
| | SLO Forecasting & Budget Projection | ◆ New |
| **E. Troubleshooting & Analysis** | Notification Center | ● v1.0 |
| | Troubleshooting Console | ◆ New |
| | Cross-Agent Communication Audit | ◆ New |
| | Root Cause Analyser | ◆ New |
| | Blocker Chain Visualiser | ◆ New |
| **F. Knowledge & Configuration** | Blueprint Explorer | ● v1.0 |
| | Setup & Configuration Wizard | ● v1.0 |
| | Blueprint Diff & Version Compare | ◆ New |
| | Activity Feed & Audit Log | ◆ New |
| | Project Health Score | ◆ New |
| | Webhook & External Alerts | ◆ New |

---

### Category A: Agent Observability

#### Feature A0: Agent Dashboard ● v1.0

The main view of the portal. A responsive card grid showing every agent across all 5 VMs.

**What it shows:** Agent role name, VM identifier, AI model, live status with animated indicator (`active` / `idle` / `blocked` / `error` / `offline`), current task ID and title, latest AI output snippet, notification priority badge, and time since last activity.

**Click any card → Agent Detail View** with 4 tabs: Conversation History (full AI response timeline with token count and latency), Task History (completed/in-progress/blocked with filters), Tools & Access (tool list, file system scope, masked env vars), and Performance (response time trends, token usage, task completion rate).

**Why it matters:** The primary situational awareness view. The end-user can see at a glance which agents are active, which are blocked, and what they are working on — information that was previously available only via Telegram relay.

**Multi-agent VMs:** VM-3 (Developers) and VM-4 (QC) display grouped cards with sub-agent IDs (dev-01, dev-02, qc-01, qc-02). Auto-refresh via SSE — no polling from the browser.

---

#### Feature A1: Agent Decision Graph ◆ New

**What it does:** Visualises the execution tree of a single agent session as a branching graph — not a flat log — showing how the agent reasoned, which tools it called, what data it received, and where it made decisions.

**What it shows:**
- Tree-structured execution graph where each node is a reasoning step, tool call, or model response
- Edges showing data flow between steps
- Colour-coded outcomes: success (green), error (red), retry (orange), skipped (gray)
- Token count and latency per node
- Expandable nodes revealing full prompt and response content

**Why it matters:** When an agent produces unexpected output, reading raw logs is slow and linear. The decision graph exposes the branching structure instantly — which tool calls fired, which returned errors, where the agent changed direction. Makes debugging agent behaviour significantly faster than reading conversation history line by line.

**Data source:** OpenClaw gateway session traces. **Implementation priority:** P2 (v2.0).

---

#### Feature A2: Agent Session Replay ◆ New

**What it does:** A chronological playback of an agent's full session — step by step — with timestamps, model I/O, and tool calls rendered in sequence. "Video playback" for agent activity.

**What it shows:**
- Timeline scrubber (horizontal bar with timestamps)
- Step-by-step playback: prompt → model response → tool call → tool result → next prompt
- Speed controls (1×, 2×, 4×, skip to next tool call)
- Pause on any step to inspect full content
- Overlay: token count, latency, and cost per step
- Jump-to shortcuts: "first error" and "longest step"

**Why it matters:** Sometimes you need to understand not just what happened, but in what order and how long each step took. Useful when an agent took far longer than expected — scrubbing to the longest step often reveals retry loops or environment failures.

**Data source:** OpenClaw gateway session logs (time-ordered). **Implementation priority:** P2 (v2.0).

---

#### Feature A3: Agent Cost Tracker ◆ New

**What it does:** Real-time and historical token usage and cost attribution per agent, per VM, per task, and per pipeline phase. Includes anomaly detection for runaway processes.

**What it shows:**
- **Cost Dashboard:** Total cost by day/week/month; breakdown by VM (pie chart), by model (Claude Opus vs Sonnet vs MiniMax), and by pipeline phase; top 10 most expensive tasks
- **Per-Agent Detail:** Input vs output tokens per session, average cost per task, token efficiency trend, and retry cost (tokens wasted on retries)
- **Alerts:** Configurable daily budget threshold; anomaly detection when an agent uses significantly more tokens than their baseline; runaway process alert for agents looping beyond 30 minutes

**Why it matters:** GateForge uses models with very different price points. Without cost visibility, token spend grows invisibly — especially when agents enter retry loops. The cost tracker surfaces this before it becomes a budget problem. Pricing per model is configurable in the settings.

**Data source:** OpenClaw gateway API (token counts per response) + configured pricing table. **Implementation priority:** P1 (v1.5).

---

#### Feature A4: Agent Comparison Matrix ◆ New

**What it does:** Side-by-side comparison of performance metrics across all agents or a selected subset — particularly useful for comparing multiple developer agents or multiple QC agents.

**What it shows:**
- Comparison table where rows are agents and columns are metrics: tasks completed, average completion time, average tokens per task, cost per task, error/retry rate, and QA first-pass rate
- Sortable by any column; outlier highlighting (top performer in green, underperformer in red)
- Trend sparklines per agent

**Why it matters:** With multiple dev-XX and qc-XX agents running in parallel, workload balance and performance variance become important to track. This view makes it immediately clear whether a slowdown is caused by one underperforming agent or a systemic issue.

**Implementation priority:** P3 (v2.5+).

---

### Category B: Pipeline & Progress

#### Feature B0: Lobster Pipeline View ● v1.0

A visual horizontal pipeline showing the 6 SDLC phases as connected nodes.

**What it shows:** Phase name and number (1–6), current phase status (Not Started / In Progress / Completed / Blocked) with animated glow for active phases, task counters (passed / working / pending / blocked), and quality gate status with criteria checklist per phase. Pipeline connectors between nodes: green for completed transitions, gray for pending.

**Click any phase node → Phase detail panel:** All tasks in this phase with status/agent/priority, quality gate criteria checklist, and PROMOTE / HOLD / ROLLBACK decision indicator for QA phases. Dropdown for pipeline history to view past iterations.

**Why it matters:** Gives the end-user the full pipeline status that was previously available only via Architect Telegram updates. Shows the exact phase, task counts, and gate decisions in one visual.

---

#### Feature B1: Pipeline Run History & Replay ◆ New

**What it does:** A log of all past pipeline runs (iterations) with the ability to inspect any historical run in full detail, including side-by-side run comparisons.

**What it shows:**
- Run list: all pipeline runs with start/end date, duration, outcome (completed/aborted/in-progress), and task counts
- Run detail: click any past run to see the Pipeline View frozen at that point in time
- Run comparison: select two runs to compare phase durations, task counts per phase, blocker counts, quality gate results, and cost per run
- Filters by date range, outcome, and project module

**Why it matters:** The live Pipeline View shows "now". History enables trend analysis — was this iteration faster or slower, did we have more blockers, which phase took longest? Without this, every iteration is evaluated in isolation.

**Implementation priority:** P1 (v1.5).

---

#### Feature B2: Pipeline Analytics & Bottleneck Detection ◆ New

**What it does:** Automated analysis of pipeline performance identifying where time is spent, what causes delays, and which phases are bottlenecks across iterations.

**What it shows:**
- **Phase Duration Analysis:** Average time per phase across iterations; current iteration vs historical average; bottleneck highlight when a phase exceeds average by more than 50%
- **Wait Time Analysis:** Time tasks spend waiting between phases, waiting for another agent, or in review vs active work
- **Throughput Metrics:** Tasks completed per day (velocity), pipeline cycle time (requirement to production), and lead time (task created to task completed)
- **Predictive Alerts:** Forward-looking warnings such as "At current velocity, Phase 4 (QA) will take 3 more days" or "QA gate coverage at 87% — may not pass threshold"

**Why it matters:** Turns raw pipeline data into actionable insight. Detects problems proactively rather than waiting for the end-user to notice a delay.

**Data source:** `pipelineAnalytics` service. **Implementation priority:** P2 (v2.0).

---

#### Feature B3: Pipeline YAML Preview & Validation ◆ New

**What it does:** View the Lobster Pipeline YAML definition in a structured, readable format with validation checks. Read-only in v1.0; editing scoped to v2.0.

**What it shows:**
- YAML source viewer with syntax highlighting
- Structured preview: steps rendered as a vertical flow with agent assignments, actions, inputs, and on_pass/on_fail branching
- Validation panel: checks for unreachable steps, missing on_fail handlers, undefined agent references, and circular dependencies
- Diff viewer comparing current YAML with previous version

**Why it matters:** The Lobster YAML defines the deterministic orchestration flow. the end-user should be able to read it visually without parsing raw YAML.

**Implementation priority:** P3 (v2.5+).

---

#### Feature B4: Task Lifecycle Tracker ◆ New

**What it does:** A detailed vertical timeline for any single task, showing every state change from creation to completion — including every agent touch, every commit, and every QA result.

**What it shows (for a single task):**
- Vertical event timeline: Created → Assigned → In-Progress → Commit → In-Review → QA Assigned → QA Result → (fix loop if HOLD) → PROMOTE → Deployed to Dev → Deployed to UAT → Deployed to Production
- Each event shows: timestamp, agent responsible, duration since previous event, and related Git commit or notification reference

**Why it matters:** When a task is delayed or blocked, a flat task status field gives no useful information. The lifecycle tracker answers "what has been done on this task, by whom, and when?" in one view.

**Implementation priority:** P1 (v1.5).

---

### Category C: Project Management

#### Feature C0: Project Dashboard ● v1.0

Mirrors the project status tracking from the Blueprint's `project/status.md`.

**What it shows:** 6 health cards (Phase, Status, Schedule, Budget, Quality, Team) each Green/Yellow/Red; active tasks table filterable by module/status/agent/priority; MoSCoW backlog breakdown (Must / Should / Could / Won't); burndown chart for the current iteration; and open blockers list with details and responsible agent.

**Why it matters:** Provides the executive summary view of project health across all dimensions. Each health card maps directly to a tracked dimension in the Blueprint.

---

#### Feature C1: Iteration Manager ◆ New

**What it does:** Dedicated view for managing and reviewing iterations (sprints), with scope tracking, execution progress, and retrospective data.

**What it shows:**
- Iteration list with dates, status (planned/active/completed), and velocity
- Active iteration detail: scope (tasks committed vs completed vs added mid-iteration), burndown and burnup charts, scope creep indicator, and velocity trend over last 5 iterations
- Retrospective data: planned vs actual points, unfinished tasks carried over, blockers encountered with resolution times, and quality gate pass rate vs previous iteration

**Why it matters:** Separates per-iteration accountability from the always-on project dashboard. Scope creep and velocity changes are only visible when you compare against an iteration baseline.

**Implementation priority:** P2 (v2.0).

---

#### Feature C2: Dependency Map ◆ New

**What it does:** Visual directed acyclic graph (DAG) of task and module dependencies, showing which tasks depend on others and where chains of dependency create risk.

**What it shows:**
- DAG where nodes are tasks and edges mean "depends on"
- Colour by status: green (done), blue (in-progress), orange (blocked), gray (pending)
- Critical path highlighted — the longest dependency chain
- Module-level aggregate view showing inter-module dependencies
- Click any task node to open the Task Lifecycle Tracker for that task

**Why it matters:** In a multi-agent parallel system, dependency chains create cascade risk. If FEAT-014 (Auth Module) is blocked, the Dependency Map immediately shows every downstream task that cannot start until it is resolved.

**Implementation priority:** P2 (v2.0).

---

#### Feature C3: Risk Register & Heat Map ◆ New

**What it does:** Maintains a structured risk register and plots risks on a 3×3 probability × impact heat map, including auto-detected risks derived from pipeline and operations data.

**What it shows:**
- Risk table: ID, description, probability (Low/Medium/High), impact (Low/Medium/High), mitigation, owner, and status (open/mitigated/escalated/closed)
- Heat map: 3×3 grid with risks plotted by probability and impact
- Auto-detected risks from live data (e.g., "QA coverage below threshold for 3 consecutive days → Quality risk", "2 developers blocked simultaneously → Resource risk", "SLO error budget at 30% → Operational risk")
- Historical risk trend: risks opened vs closed over time

**Why it matters:** Risk management is typically manual in SDLC projects. Auto-detection from pipeline data turns risk monitoring from a periodic manual activity into a continuous automated process.

**Implementation priority:** P2 (v2.0).

---

#### Feature C4: Decision Timeline ◆ New

**What it does:** A filterable chronological timeline of all architectural decisions, quality gate results, dispute resolutions, and project pivots. Sources from the Blueprint's `decision-log.md` and the notification history.

**What it shows:**
- Vertical timeline with event types: ADRs (Architecture Decision Records), quality gate decisions (PROMOTE/HOLD/ROLLBACK), dispute resolutions, scope changes, and blocker resolutions
- Each entry: date, decision, rationale, who made it, and what was affected
- Filters by date range, event type, and agent involved

**Why it matters:** Decisions in a multi-agent system are made by multiple agents across multiple phases. The Decision Timeline gives the end-user a single place to review why things were built the way they were.

**Implementation priority:** P2 (v2.0).

---

#### Feature C5: Release Manager ◆ New

**What it does:** Tracks releases from planning through deployment, with auto-generated release notes, changelogs, and version comparisons.

**What it shows:**
- Release list with version, date, status (planned/staging/released/rolled-back)
- Release detail: included features (task IDs + titles), bugs fixed, breaking changes, auto-generated release notes from commit messages, deployment status per environment (Dev ✓ / UAT ✓ / Prod ○), and quality gate summary for this release
- Release comparison: select two releases to diff included features, code changes, and test results

**Why it matters:** Closes the loop between the SDLC pipeline and the released product. The end-user can see exactly what was in any given release and how it compares to the previous one.

**Implementation priority:** P2 (v2.0).

---

### Category D: Quality & Operations

#### Feature D0: QA Metrics Dashboard ● v1.0

Surfaces all quality assurance data from GateForge's QA framework.

**What it shows:** Per-module coverage bars for Unit / Integration / E2E with threshold markers (95% / 90% / 85%); gate decision cards (PROMOTE / HOLD / ROLLBACK per module with criteria checklist); defect summary by severity (Critical / Major / Minor / Cosmetic) with defect density trend; test automation metrics (coverage %, execution time, flaky test rate); and security panel (OWASP Top 10 coverage checklist, Snyk dependency scan summary).

**Why it matters:** QA is a critical gate in GateForge. This dashboard lets the end-user see coverage gaps and gate decisions without asking the Architect to relay QC reports.

---

#### Feature D1: Operations Dashboard ● v1.0

Monitors deployment and runtime health across all three environments.

**What it shows:** Environment cards for Dev / UAT / Production with health indicators; 5 SLO compliance gauges with thresholds (API Availability ≥ 99.9%, p95 Latency ≤ 200ms, Error Rate ≤ 0.1%, DB Availability ≥ 99.95%, Query p95 ≤ 50ms); error budget burn rate with 4-tier alert visualisation (Critical 14.4×, High 6×, Medium 3×, Low 1×); deployment log with rollback links; and incident timeline.

**Why it matters:** Production health data was previously invisible unless the Operator reported it via the Architect. This dashboard surfaces it directly.

---

#### Feature D2: Defect Deep-Dive & Trend Analysis ◆ New

**What it does:** Extended defect analytics that go beyond the summary in the QA dashboard, covering lifecycle, aging, heatmaps, and root cause categorisation.

**What it shows:**
- Defect lifecycle timeline per defect (reported → assigned → in-progress → verified → closed)
- Defect aging: how long defects stay open, broken down by severity
- Defect heatmap: module × severity matrix showing which modules accumulate the most defects
- Bug escape rate: defects found in UAT/Prod that should have been caught earlier
- Defect trends: open vs closed over time by severity
- Root cause categories: code logic, missing requirement, integration issue, environment issue, test gap
- Correlation views: defect density vs code complexity, defect density vs test coverage

**Why it matters:** The QA dashboard shows current state. Defect Deep-Dive answers "where are our quality problems coming from and are they getting better or worse?"

**Implementation priority:** P3 (v2.5+).

---

#### Feature D3: Deployment Diff & Rollback Viewer ◆ New

**What it does:** Shows exactly what changed between any two deployments, with a visual diff and a clear rollback chain.

**What it shows:**
- Deployment history: all deployments with version, timestamp, environment, status, and deploying agent
- Deployment diff for any two selected deployments: files changed (added/modified/deleted), Git diff with syntax highlighting, config changes, and database migration changes
- Rollback chain: visual sequence showing current version → rollback target → what would be reverted
- Smoke test results per deployment with pass/fail detail

**Why it matters:** When something breaks in production, the end-user needs to know immediately what changed between the working version and the broken one. The diff view provides this without requiring SSH access to the server.

**Implementation priority:** P3 (v2.5+).

---

#### Feature D4: SLO Forecasting & Budget Projection ◆ New

**What it does:** Projects SLO error budget consumption into the future based on current burn rate, with what-if scenario modelling.

**What it shows:**
- Error budget runway: "At current burn rate, API availability error budget will be exhausted in 12 days"
- Projection chart: line chart showing error budget remaining over time with a forward projection line
- What-if scenarios: "If we reduce error rate by 50%, budget lasts 45 days instead of 12"
- Historical SLO compliance: monthly SLO achievement rate trend
- Breach history: past SLO breaches with root cause and resolution time

**Why it matters:** The Operations Dashboard shows current SLO health. Forecasting shows where it is heading — allowing the end-user to act before a budget is exhausted, not after.

**Implementation priority:** P3 (v2.5+).

---

### Category E: Troubleshooting & Analysis

#### Feature E0: Notification Center ● v1.0

A real-time feed of all notifications from all VMs, colour-coded by priority.

| Priority | Colour | Meaning | Example |
|----------|--------|---------|---------|
| `CRITICAL` | Red | System down, data loss, security breach | Build failure on auth-module branch |
| `BLOCKED` | Orange | Agent cannot continue, waiting for decision | Cannot proceed with integration tests |
| `DISPUTE` | Yellow | Agent disagrees with another agent's output | Disagrees with Designer on caching strategy |
| `COMPLETED` | Green | Task done, results committed to Git | Database schema v2 review complete |
| `INFO` | Gray | Status update, no action needed | CI pipeline green, all tests passing |

**Features:** Filter by VM, priority, and time range. Click any notification to see full context and Git reference. Browser toast for CRITICAL/BLOCKED notifications.

**Why it matters:** Previously the end-user only received notifications the Architect chose to relay. The Notification Center shows everything from all VMs in real time.

---

#### Feature E1: Troubleshooting Console ◆ New

**What it does:** A centralised troubleshooting workspace that aggregates all information related to a specific issue — across agents, tasks, and pipeline phases — in one place.

**What it shows:**
- Issue selector: start from a notification, a blocked task, or a failed gate
- Context panel: automatically gathers the agents involved, the tasks affected, the pipeline phase, related notifications (cross-referenced by task ID), related Git commits, related QA results, and related agent session logs
- Correlation timeline: all events from all sources on a single timeline, filtered to the specific issue
- Suggested actions based on issue type: "This is a blocked task → check dependency chain"; "This is a QA gate HOLD → check coverage gaps"; "This is a build failure → check agent decision graph for error"

**Why it matters:** When something goes wrong, information is scattered across agent logs, notifications, task status, and pipeline state. The console eliminates the context-switching required to investigate an issue.

**Implementation priority:** P2 (v2.0).

---

#### Feature E2: Cross-Agent Communication Audit ◆ New

**What it does:** A visual log of all inter-agent communications — every HTTP dispatch from the Architect to spokes, every notification back, every structured JSON payload — with delivery metrics and message search.

**What it shows:**
- Message flow diagram: Architect → spoke dispatch and spoke → Architect notification rendered as a sequence diagram
- Message log: chronological table with timestamp, source VM → destination VM, message type, priority, HMAC verification status (valid/expired/failed), and truncated payload (click to expand)
- Message search: full-text search across all payloads
- Delivery metrics: message delivery latency, failed deliveries (VM unreachable), retry count, and messages per hour/day trend

**Why it matters:** GateForge's hub-and-spoke model means all communication routes through the Architect. Auditing this verifies the right messages reached the right agents at the right time. Essential for diagnosing communication failures and for governance requirements.

**Data source:** Architect gateway logs and spoke notification records. **Implementation priority:** P1 (v1.5).

---

#### Feature E3: Root Cause Analyser ◆ New

**What it does:** When a pipeline stalls, a gate fails, or a task is blocked, the Root Cause Analyser traces backwards through the event chain to suggest the root cause and recommended resolution.

**How it works:**
1. Starts from the symptom (e.g., "Phase 4 QA is blocked")
2. Traces upstream: which Phase 3 tasks are incomplete?
3. For incomplete tasks: which agents are assigned and what is their current status?
4. For blocked agents: what are they waiting for and who dispatched the task?
5. Presents the full chain: "QA blocked → waiting for FEAT-014 → assigned to dev-01 → dev-01 status: error → last action: npm test failed → root cause: test environment misconfiguration"

**What it shows:** Visual cause chain from symptom to root cause; confidence level based on data completeness; suggested resolution based on root cause category; and similar past issues if matching patterns exist.

**Data source:** `rootCauseEngine` service. **Implementation priority:** P2 (v2.0).

---

#### Feature E4: Blocker Chain Visualiser ◆ New

**What it does:** Shows all currently blocked items and their full dependency chains — what is blocked, by what, how deep the chain goes, and what the downstream impact is.

**What it shows:**
- Blocked items list: all tasks and agents currently in "blocked" status
- Chain diagram: for each blocked item, the full chain (e.g., "Task A blocked → waiting for Task B in-progress → estimated completion: 2 hours"; "Task C blocked → waiting for Task A blocked → cascading block")
- Impact score: number of downstream items affected if this blocker persists
- Resolution priority: blockers ranked by impact score so the highest-impact blocker is addressed first

**Why it matters:** A single blocker can cascade. The Blocker Chain Visualiser surfaces the full blast radius of each blocker, enabling the end-user to prioritise resolution correctly.

**Implementation priority:** P1 (v1.5).

---

### Category F: Knowledge & Configuration

#### Feature F0: Blueprint Explorer ● v1.0

A file tree viewer for the Blueprint Git repository — the single source of truth for the entire GateForge project.

**What it shows:** Expandable/collapsible directory tree mirroring the Blueprint repo structure (`requirements/ → architecture/ → design/ → development/ → qa/ → operations/ → project/`); click any `.md` file to render it with full Markdown support; status badges per document (Draft / In Review / Approved / Deprecated); Git commit log sidebar showing recent commits with agent prefixes; and ADR viewer for `project/decision-log.md`.

**Why it matters:** The Blueprint is the authoritative record of all design decisions, requirements, and specifications. The Explorer makes it browsable without requiring Git CLI access.

---

#### Feature F1: Setup & Configuration Wizard ● v1.0

A guided 7-step wizard for first-time installation and ongoing configuration.

| Step | What It Configures |
|------|-------------------|
| 1. Admin Credentials | Username, password, JWT secret for portal access |
| 2. VM Registry | Add VM-1 through VM-5 with IP, port, hook token, agent secret. Auto-detect on 192.168.72.x subnet. Test connection button per VM. |
| 3. AI API Keys | Per-VM API keys for Anthropic, OpenAI, Google, MiniMax. Validated on save. |
| 4. Telegram Config | Bot token, chat ID for System Architect → the end-user notifications |
| 5. Blueprint Repo | Git URL, SSH key or access token, branch selection |
| 6. Deployment Target | US VM Tailscale address, SSH credentials, environment paths (Dev/UAT/Prod) |
| 7. Review & Save | Summary of all settings, connection test for each service, export config |

**Post-setup health check:** Shows connection status for all VMs, gateway reachability, agent discovery, Blueprint repo access, Telegram bot activity, and US VM reachability. Import/export available (secrets excluded).

---

#### Feature F2: Blueprint Diff & Version Compare ◆ New

**What it does:** Compare any two versions of any Blueprint document side-by-side, showing exactly what changed and who changed it.

**What it shows:**
- Version selector: pick two commits or dates
- Side-by-side or unified diff view with syntax highlighting
- Change summary: lines added/removed/modified, sections changed
- Author attribution: which agent made each change (from Git commit author)
- Approval status: whether the change was reviewed, by whom, and when

**Why it matters:** Blueprint documents evolve through multiple agent edits. When a decision changes or a specification is revised, the diff viewer makes that change immediately visible without reading entire documents.

**Data source:** `blueprintGit.ts` (existing service, extended). **Implementation priority:** P2 (v2.0).

---

#### Feature F3: Activity Feed & Audit Log ◆ New

**What it does:** A comprehensive, immutable audit log of everything that happens in GateForge — every agent action, every status change, every deployment, every gate decision — with export capability for compliance reporting.

**What it shows:**
- Unified activity feed: reverse-chronological stream of all system events including agent started/stopped/status changed, task created/assigned/status changed, pipeline phase advanced, quality gate evaluated, deployment executed, notification dispatched, Blueprint document updated, and configuration changed
- Filters by event type, VM, agent, date range, and severity
- CSV/JSON export for compliance reporting
- Configurable retention period (30/90/180/365 days)

**Why it matters:** Complete decision logging with chain-of-custody tracking across all agents is essential for enterprise and regulated environments. Immutability guarantees audit records cannot be altered after creation.

**Data source:** `auditLogger` service. **Implementation priority:** P1 (v1.5).

---

#### Feature F4: Project Health Score ◆ New

**What it does:** A single composite score (0–100) representing overall project health, computed from multiple weighted dimensions and visible on every page as a persistent header indicator.

**Scoring dimensions:**

| Dimension | Weight | Source | Example |
|-----------|--------|--------|---------|
| Pipeline Progress | 20% | % of pipeline phases completed | 3/6 phases = 50% |
| Agent Availability | 15% | % of agents online and active | 5/6 agents active = 83% |
| Task Velocity | 15% | Tasks completed vs planned | 12/15 done = 80% |
| Quality Gate Health | 15% | % of gates passing | 2/3 gates pass = 67% |
| Blocker Count | 15% | Inverse of blocked tasks | 1 blocker = 90%, 5 = 50% |
| SLO Compliance | 10% | % of SLOs within error budget | 5/5 healthy = 100% |
| Cost Efficiency | 10% | Actual cost vs budget | Within budget = 100% |

**Visual treatment:** Score badge in header bar (always visible): green 80–100, yellow 50–79, red 0–49. Score detail card on Project Dashboard with per-dimension breakdown and trend sparkline.

**Why it matters:** Operationalises the 5-second comprehension rule for overall project health. A single persistent number tells the end-user whether the project is healthy, at risk, or in trouble before he opens any specific view.

**Data source:** `healthScore` service (aggregates data from all other services). **Implementation priority:** P1 (v1.5).

---

#### Feature F5: Webhook & External Alerts ◆ New

**What it does:** Pushes selected portal events to external notification channels (Slack, email, PagerDuty, custom HTTP webhook). The read-only principle still applies — webhooks go to external systems, never back to agents.

**Configurable triggers:**
- CRITICAL notification received
- QA gate ROLLBACK decision
- Deployment failure
- SLO error budget below 25%
- Agent offline for more than 5 minutes
- Project health score drops below configured threshold
- Daily/weekly summary digest

**Supported channels:** Slack (incoming webhook URL), Email (SMTP config), PagerDuty (integration key), Custom HTTP POST (any URL with configurable payload template), Telegram (additional bot — separate from the Architect's Telegram).

**Why it matters:** the end-user may not have the portal open at all times. Webhooks ensure that critical events reach him through other channels he monitors, without requiring constant dashboard attention.

**Data source:** `webhookDispatcher` service. **Implementation priority:** P1 (v1.5).

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
| Risk Level | `Low` / `Medium` / `High` | Risk register and heat map cells |
| Health Score | `Green (80-100)` / `Yellow (50-79)` / `Red (0-49)` | Persistent header badge |
| Message Verification | `valid` / `expired` / `failed` | HMAC status badges in Comms Audit |

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
        │     ├── Retrieves: agent status, session data, tool usage, logs, token counts
        │     ├── Configurable interval (default 10s)
        │     └── One VM failure does not stop polling of others
        │
        ├── Clones Blueprint Git Repo (shallow clone, auto-pull)
        │     ├── File tree generation for Blueprint Explorer
        │     ├── File content reading for Document Viewer and Diff viewer
        │     ├── Commit log extraction for Recent Changes and audit trail
        │     └── Document status parsing from frontmatter
        │
        ├── Probes US VM via Tailscale SSH (health check only)
        │     └── Checks Dev / UAT / Prod environment status
        │
        ├── Internal Services (new for extended features)
        │     ├── costTracker          Token usage aggregation and cost calculation
        │     ├── pipelineAnalytics    Phase durations, velocity, bottleneck detection
        │     ├── healthScore          Composite project health score (weighted dimensions)
        │     ├── rootCauseEngine      Upstream trace from symptom to root cause
        │     ├── webhookDispatcher    Outbound push to Slack, email, PagerDuty, HTTP
        │     └── auditLogger          Immutable event log with retention policy
        │
        └── Broadcasts changes to Frontend via SSE
              ├── agent.status         Agent came online, went idle, started task
              ├── agent.output         New AI model response
              ├── agent.cost           Token count update (for Cost Tracker)
              ├── notification.new     Notification from any VM
              ├── pipeline.update      Phase advanced, task counter changed
              ├── pipeline.analytics   Bottleneck detected, velocity updated
              ├── qa.gateUpdate        Gate decision made (PROMOTE/HOLD/ROLLBACK)
              ├── ops.deployUpdate     Deployment started/completed/failed
              ├── ops.sloAlert         SLO budget threshold crossed
              ├── ops.sloForecast      Projection updated
              ├── blueprint.commit     New commit pushed to Blueprint repo
              ├── health.scoreUpdate   Project Health Score changed
              └── system.health        VM went online/offline
```

### Read-Only Enforcement

The portal enforces read-only access at multiple levels:

1. **Gateway Client** — The `gatewayClient.ts` service ONLY uses HTTP GET. No POST, PUT, DELETE, or PATCH methods exist in the client.
2. **Route Layer** — No backend route accepts any payload that would be forwarded to a VM.
3. **Frontend** — No UI element exists that could trigger a write action to any agent. There is no chat input, no command box, no "send" button.
4. **Webhook Direction** — The `webhookDispatcher` sends to external systems only. It never posts to any VM gateway.
5. **Code Review Gate** — Any PR introducing a non-GET request to a VM gateway must be rejected.

This is not optional. If the portal could send instructions, it would bypass the System Architect and break the hub-and-spoke contract that is fundamental to GateForge.

---

## Advantages

### Why Build a Dedicated Admin Portal (vs. Alternatives)

| Alternative | Why the Admin Portal Is Better |
|-------------|-------------------------------|
| **Telegram only** | Telegram gives the end-user a text-only, linear stream from the Architect. No visual pipeline, no multi-agent overview, no drill-down into individual agents, no QA metrics, no cost visibility. |
| **Raw SSH into each VM** | Requires technical skill, no aggregated view, no real-time dashboard, scattered across 5 terminals. |
| **Generic monitoring (Grafana)** | Grafana monitors infrastructure metrics (CPU, RAM, disk), not agent-level state (which task, what AI output, what gate decision, what token cost). The Admin Portal is purpose-built for GateForge's domain model. |
| **ClawDeck directly** | ClawDeck manages individual OpenClaw instances but has no concept of the SDLC pipeline, quality gates, Blueprint, or the hub-and-spoke topology. The Admin Portal is built on ClawDeck's tech stack but engineered for GateForge's workflow. |

### Key Advantages

1. **Full Pipeline Transparency** — See every phase, every gate, every task counter, every agent status in one view. No more waiting for the Architect to relay information via Telegram.

2. **Zero Interference** — Read-only design means the portal can be open 24/7 without any risk of disrupting agent operations or the hub-and-spoke communication model.

3. **Instant Situational Awareness** — 5-second comprehension rule. Open any page and immediately understand system health, pipeline progress, or agent status. The persistent Project Health Score provides this at a glance from any view.

4. **Historical Audit Trail** — Full conversation history per agent, complete notification log, Blueprint commit history, decision log, immutable activity feed, and pipeline run archive. Nothing is lost.

5. **Self-Service Setup** — 7-step wizard eliminates the need to manually SSH into VMs, edit config files, and test connections. First-time setup in minutes.

6. **Aligned Status Model** — Every status, every priority, every gate decision in the portal uses the exact same labels and values as the GateForge pipeline. No translation layer, no confusion.

7. **Built on Proven Stack** — Inherited from ClawDeck (Next.js 14, TypeScript, Tailwind, shadcn/ui, Express, Docker Compose) which is already tested with OpenClaw. Reduced risk, faster development.

8. **Cost Control** — The Agent Cost Tracker with anomaly detection makes token spend visible before it becomes a budget problem. Retry loops and runaway processes are surfaced in real time.

9. **Deep Troubleshooting** — The Troubleshooting Console, Root Cause Analyser, Blocker Chain Visualiser, and Cross-Agent Communication Audit eliminate the need to context-switch across multiple views when diagnosing an issue.

10. **Governance Ready** — The immutable Activity Feed & Audit Log with CSV/JSON export, the Cross-Agent Communication Audit with HMAC verification status, and the Webhook & External Alerts system support enterprise and regulated environments.

11. **Forward Intelligence** — Bottleneck Detection, SLO Forecasting, Risk Auto-Detection, and predictive pipeline alerts transform the portal from a reactive monitoring tool into a proactive intelligence layer.

---

## Implementation Priority Matrix

| Priority | Feature | Category | Effort | Value |
|----------|---------|----------|--------|-------|
| **P0 — Must (v1.0)** | Agent Dashboard | A | Done | High |
| | Lobster Pipeline View | B | Done | High |
| | Blueprint Explorer | F | Done | High |
| | Project Dashboard | C | Done | High |
| | QA Metrics Dashboard | D | Done | High |
| | Operations Dashboard | D | Done | High |
| | Notification Center | E | Done | High |
| | Setup Wizard | F | Done | High |
| **P1 — Should (v1.5)** | Agent Cost Tracker | A | Medium | High |
| | Task Lifecycle Tracker | B | Medium | High |
| | Pipeline Run History & Replay | B | Medium | High |
| | Activity Feed & Audit Log | F | Medium | High |
| | Cross-Agent Communication Audit | E | Medium | High |
| | Project Health Score | F | Small | High |
| | Blocker Chain Visualiser | E | Small | High |
| | Webhook & External Alerts | F | Medium | Medium |
| **P2 — Could (v2.0)** | Agent Decision Graph | A | Large | High |
| | Agent Session Replay | A | Large | High |
| | Pipeline Analytics & Bottleneck Detection | B | Medium | High |
| | Root Cause Analyser | E | Large | High |
| | Troubleshooting Console | E | Large | Medium |
| | Iteration Manager | C | Medium | Medium |
| | Dependency Map | C | Medium | Medium |
| | Blueprint Diff & Version Compare | F | Medium | Medium |
| | Release Manager | C | Medium | Medium |
| | Decision Timeline | C | Small | Medium |
| | Risk Register & Heat Map | C | Medium | Medium |
| **P3 — Want (v2.5+)** | Agent Comparison Matrix | A | Small | Medium |
| | Pipeline YAML Preview & Validation | B | Medium | Medium |
| | Defect Deep-Dive & Trend Analysis | D | Medium | Medium |
| | Deployment Diff & Rollback Viewer | D | Medium | Medium |
| | SLO Forecasting & Budget Projection | D | Medium | Medium |

---

## Revised Navigation Structure

With 30 features, the sidebar navigation is structured by category:

```
GATEFORGE ADMIN PORTAL
─────────────────────────
◉ Dashboard Home          ← Project Health Score + key metrics at a glance
│
├── Agents
│   ├── Overview          ← Agent Dashboard (card grid, primary view)
│   ├── Decision Graph    ← Per-agent execution tree (v2.0)
│   ├── Session Replay    ← Time-travel debugging (v2.0)
│   ├── Cost Tracker      ← Token usage and billing (v1.5)
│   └── Comparison        ← Side-by-side agent metrics (v2.5+)
│
├── Pipeline
│   ├── Live View         ← Lobster Pipeline (current state)
│   ├── Run History       ← Past pipeline runs and comparison (v1.5)
│   ├── Analytics         ← Bottleneck detection and velocity (v2.0)
│   ├── YAML Preview      ← Pipeline definition viewer (v2.5+)
│   └── Task Tracker      ← Per-task lifecycle timeline (v1.5)
│
├── Project
│   ├── Dashboard         ← Health cards, backlog, burndown
│   ├── Iterations        ← Sprint management (v2.0)
│   ├── Releases          ← Release tracking and changelogs (v2.0)
│   ├── Dependencies      ← Task/module dependency graph (v2.0)
│   ├── Risks             ← Risk register and heat map (v2.0)
│   └── Decisions         ← Decision timeline (v2.0)
│
├── Quality
│   ├── Metrics           ← Coverage, gates, defects
│   ├── Defect Analysis   ← Deep-dive and trend analysis (v2.5+)
│   └── Gate History      ← Historical PROMOTE/HOLD/ROLLBACK
│
├── Operations
│   ├── Dashboard         ← SLOs, environments, incidents
│   ├── Deployments       ← Diff and rollback viewer (v2.5+)
│   └── SLO Forecast      ← Error budget projection (v2.5+)
│
├── Troubleshooting
│   ├── Console           ← Centralised issue investigation (v2.0)
│   ├── Blockers          ← Blocker chain visualiser (v1.5)
│   ├── Root Cause        ← Automated root cause analysis (v2.0)
│   └── Comms Audit       ← Inter-agent message log (v1.5)
│
├── Blueprint
│   ├── Explorer          ← Git tree and document viewer
│   └── Compare           ← Version diff (v2.0)
│
├── Notifications         ← Priority-coded real-time feed
├── Activity Log          ← Full immutable audit trail (v1.5)
├── Webhooks              ← External alert configuration (v1.5)
└── Settings              ← Setup wizard and configuration
```

---

## Ideas for Future Enhancement

These are not in scope for any current release but represent the roadmap for future iterations. They are documented here so that agents understand the long-term vision and can make architectural decisions that do not block these features.

### Multi-Project Support (v3.0)
GateForge currently runs one project at a time. When it supports multiple concurrent projects, the Admin Portal should show a project selector and scope all views to the selected project. **Architecture impact:** All data models need a `projectId` field from the start — this should be included in v1.0 schemas even though the feature is deferred.

### Role-Based Access Control (v2.0)
Currently the end-user is the only user. RBAC would allow adding team members with different access levels:
- `admin` — full access including setup and webhook configuration
- `viewer` — read-only dashboard access (no setup page)
- `auditor` — read-only with export capabilities
**Architecture impact:** JWT claims need a `role` field from v1.0. Middleware needs role-checking scaffolded early.

### Mobile App (v3.0)
React Native mobile app for on-the-go monitoring. Push notifications for CRITICAL/BLOCKED events. Focused on the Agent Dashboard, Notification Center, Project Health Score, and Blocker Chain — not the full portal.

### AI-Generated Sprint Planning Suggestions (v3.0)
Using historical velocity data, current backlog, agent availability, and past iteration patterns, generate suggested task assignments and scope for the next iteration. This would be surfaced as a read-only recommendation panel inside the Iteration Manager — the end-user acts on suggestions via Telegram to the Architect.

### Interactive Dependency Editor (v3.0)
An editable version of the Dependency Map allowing the end-user to define or adjust task dependencies visually. Like the YAML Editor, this would be the first write-capable feature and would need to route changes through the Architect's approval flow rather than writing directly to the Blueprint.

### Historical Cost Benchmarking (v2.5)
Compare token spend and cost efficiency across projects or against industry benchmarks. Useful once multi-project support is added. Requires a persistent cost data store beyond the current iteration window.

### Automated Test Gap Detection (v2.5)
Analyse test coverage data alongside defect heatmaps to automatically identify code paths that are untested and historically defect-prone. Surface as prioritised recommendations inside the QA Metrics Dashboard.

---

## Agent Assignment Guide

When working on this project, each GateForge VM role has specific responsibilities:

| VM Role | What You Own for This Project |
|---------|------------------------------|
| **VM-1 Architect** | Task decomposition, Blueprint updates, progress tracking, quality gate enforcement, conflict resolution, feature prioritisation across the 30-feature roadmap |
| **VM-2 Designer** | Infrastructure design (Docker, networking), database schema (SQLite — including `projectId` field for future multi-project support), security assessment, monitoring design, schema for `auditLogger`, `costTracker`, `healthScore`, and `webhookDispatcher` |
| **VM-3 Developers** | All frontend and backend code. v1.0: Agent Dashboard, Pipeline View, Blueprint Explorer, QA page, Ops page, Notifications, Setup Wizard, API routes, SSE bus, Gateway client. v1.5: Cost Tracker, Task Lifecycle Tracker, Pipeline Run History, Activity Log, Comms Audit, Health Score, Blocker Chain, Webhooks. v2.0+: Decision Graph, Session Replay, Analytics, Root Cause, Troubleshooting Console, Iteration Manager, Dependency Map, Blueprint Diff, Release Manager, Decision Timeline, Risk Register. v2.5+: Agent Comparison, YAML Preview, Defect Deep-Dive, Deployment Diff, SLO Forecast |
| **VM-4 QC Agents** | Test plans and test cases (unit, integration, E2E) for all 30 features; test execution and coverage reporting; defect reporting with root cause categorisation; regression testing when new features are added |
| **VM-5 Operator** | Docker Compose deployment, CI/CD pipeline, install script, monitoring setup, deployment to target environment, verification of all new backend services (`costTracker`, `pipelineAnalytics`, `healthScore`, `rootCauseEngine`, `webhookDispatcher`, `auditLogger`) in production |

---

## Reference Project

The GateForge Admin Portal is built on the foundation of **ClawDeck** — an open-source dashboard for managing multiple OpenClaw instances.

- **Repository:** https://github.com/tonylnng/clawdeck
- **Tech Stack:** Next.js 14 + TypeScript + Tailwind CSS + shadcn/ui (frontend), Express.js + TypeScript (backend), Docker Compose (deployment)
- **What we inherit:** Component library (shadcn/ui), authentication flow (JWT + bcrypt), dashboard layout (sidebar + header), setup wizard pattern, agent card design, SSE log streaming, dark/light mode support
- **What we add:** Lobster Pipeline visualization (React Flow), Blueprint Git integration (simple-git), QA metrics dashboards (Recharts), Operations monitoring, Notification Center with priority-coded feed, 7-step setup wizard with auto-detect, complete status alignment with GateForge, cost tracking services, pipeline analytics, health score computation, root cause engine, webhook dispatcher, and immutable audit logging

---

## Quick Reference: Key Files

```
gateforge-admin-portal/
├── frontend/
│   ├── src/app/(portal)/              ← All authenticated pages
│   │   ├── page.tsx                      Dashboard Home (Health Score + key metrics)
│   │   ├── agents/
│   │   │   ├── page.tsx                  Agent Dashboard (card grid)
│   │   │   ├── decision-graph/page.tsx   Agent Decision Graph
│   │   │   ├── session-replay/page.tsx   Agent Session Replay
│   │   │   ├── cost-tracker/page.tsx     Agent Cost Tracker
│   │   │   └── comparison/page.tsx       Agent Comparison Matrix
│   │   ├── pipeline/
│   │   │   ├── page.tsx                  Lobster Pipeline Live View
│   │   │   ├── history/page.tsx          Pipeline Run History & Replay
│   │   │   ├── analytics/page.tsx        Pipeline Analytics & Bottleneck Detection
│   │   │   ├── yaml/page.tsx             Pipeline YAML Preview & Validation
│   │   │   └── tasks/page.tsx            Task Lifecycle Tracker
│   │   ├── project/
│   │   │   ├── page.tsx                  Project Dashboard
│   │   │   ├── iterations/page.tsx       Iteration Manager
│   │   │   ├── releases/page.tsx         Release Manager
│   │   │   ├── dependencies/page.tsx     Dependency Map
│   │   │   ├── risks/page.tsx            Risk Register & Heat Map
│   │   │   └── decisions/page.tsx        Decision Timeline
│   │   ├── quality/
│   │   │   ├── page.tsx                  QA Metrics Dashboard
│   │   │   ├── defects/page.tsx          Defect Deep-Dive & Trend Analysis
│   │   │   └── gate-history/page.tsx     Gate History
│   │   ├── operations/
│   │   │   ├── page.tsx                  Operations Dashboard
│   │   │   ├── deployments/page.tsx      Deployment Diff & Rollback Viewer
│   │   │   └── slo-forecast/page.tsx     SLO Forecasting & Budget Projection
│   │   ├── troubleshooting/
│   │   │   ├── page.tsx                  Troubleshooting Console
│   │   │   ├── blockers/page.tsx         Blocker Chain Visualiser
│   │   │   ├── root-cause/page.tsx       Root Cause Analyser
│   │   │   └── comms-audit/page.tsx      Cross-Agent Communication Audit
│   │   ├── blueprint/
│   │   │   ├── page.tsx                  Blueprint Explorer
│   │   │   └── compare/page.tsx          Blueprint Diff & Version Compare
│   │   ├── notifications/page.tsx        Notification Center
│   │   ├── activity/page.tsx             Activity Feed & Audit Log
│   │   ├── webhooks/page.tsx             Webhook & External Alerts
│   │   └── setup/page.tsx                Setup & Configuration Wizard
│   ├── src/components/                   Reusable components per feature
│   ├── src/hooks/                        useSSE, useAgents, usePipeline, useNotifications,
│   │                                     useCostTracker, useHealthScore, useBlockers
│   └── src/lib/
│       ├── api.ts                        Typed fetch wrapper with JWT cookie
│       └── constants.ts                 ALL status colours, labels, mappings
│
├── backend/
│   ├── src/routes/                       API routes (agents, pipeline, blueprint, qa,
│   │                                     ops, notifications, setup, auth, events,
│   │                                     cost, analytics, audit, webhooks, health)
│   ├── src/services/
│   │   ├── gatewayClient.ts              HTTP client for OpenClaw gateways (READ-ONLY)
│   │   ├── stateCache.ts                In-memory VM→Agent→State cache
│   │   ├── poller.ts                     Background polling loop with delta detection
│   │   ├── notificationBus.ts            EventEmitter-based SSE broadcaster
│   │   ├── blueprintGit.ts               Blueprint Git repo integration
│   │   ├── usvmProbe.ts                  US VM Tailscale health check
│   │   ├── costTracker.ts                Token usage aggregation and cost calculation
│   │   ├── pipelineAnalytics.ts          Phase durations, velocity, bottleneck detection
│   │   ├── healthScore.ts                Composite project health score computation
│   │   ├── rootCauseEngine.ts            Upstream trace from symptom to root cause
│   │   ├── webhookDispatcher.ts          Outbound push to Slack/email/PagerDuty/HTTP
│   │   └── auditLogger.ts                Immutable event log with retention policy
│   └── src/middleware/                   auth.ts, rateLimiter.ts
│
├── docker-compose.yml                    One-command deployment
├── install.sh                            Guided installation script
└── .env.example                          All environment variables documented
```

---

## Summary

The GateForge Admin Portal is a read-only observability layer for the GateForge multi-agent SDLC pipeline. It exists because the end-user needs to see what his AI agents are doing without interfering with their operation.

The portal provides **30 features** across 6 categories:

- **Agent Observability (5 features):** Agent Dashboard, Decision Graph, Session Replay, Cost Tracker, and Comparison Matrix — covering live status through deep per-agent debugging and cost governance.
- **Pipeline & Progress (5 features):** Lobster Pipeline View, Run History & Replay, Analytics & Bottleneck Detection, YAML Preview, and Task Lifecycle Tracker — covering current pipeline state through historical trend analysis.
- **Project Management (6 features):** Project Dashboard, Iteration Manager, Dependency Map, Risk Register, Decision Timeline, and Release Manager — covering executive health through detailed dependency and risk tracking.
- **Quality & Operations (5 features):** QA Metrics Dashboard, Operations Dashboard, Defect Deep-Dive, Deployment Diff, and SLO Forecasting — covering current quality gates through predictive SLO projections.
- **Troubleshooting & Analysis (5 features):** Notification Center, Troubleshooting Console, Cross-Agent Communication Audit, Root Cause Analyser, and Blocker Chain Visualiser — covering real-time alerts through structured root cause investigation.
- **Knowledge & Configuration (6 features):** Blueprint Explorer, Setup Wizard, Blueprint Diff, Activity Feed & Audit Log, Project Health Score, and Webhook & External Alerts — covering document browsing through immutable governance logging and outbound alerting.

The 8 v1.0 features provide solid real-time observability. The 22 extended features add depth (drill-down from dashboard to individual model response), history (full retrospective across iterations and releases), intelligence (bottleneck detection, forecasting, root cause analysis), troubleshooting (structured investigation tooling), governance (immutable audit log, communication audit), and cost control (token spend visibility with anomaly detection).

Every status value aligns exactly with GateForge's canonical definitions. The portal inherits ClawDeck's proven tech stack and adds GateForge-specific services and visualisations.

**Remember:** Read-only. Always. No exceptions. Webhooks go out to external systems. Nothing goes back to the agents.

---

*GateForge Admin Portal — Designed by Tony NG | April 2026*

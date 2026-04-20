# GateForge Admin Portal — Extended Feature Set

> This document proposes a comprehensive set of functions for the GateForge Admin Portal, going beyond the original 8 features to cover the full lifecycle of multi-agent SDLC observability: project management, pipeline analysis, troubleshooting, cost governance, audit, risk, intelligence, and infrastructure connectivity.

---

## Feature Map Overview

The features are organised into 7 categories. Original features (v1.0) are marked ●. New proposed features are marked ◆.

| Category | Feature | Tag |
|----------|---------|-----|
| **A. Agent Observability** | Agent Dashboard (card grid, status, detail) | ● v1.0 |
| | Agent Decision Graph | ◆ New |
| | Agent Session Replay | ◆ New |
| | Agent Cost Tracker | ◆ New |
| | Agent Comparison Matrix | ◆ New |
| **B. Pipeline & Progress** | Lobster Pipeline View (phase nodes, task counters) | ● v1.0 |
| | Pipeline Run History & Replay | ◆ New |
| | Pipeline Analytics & Bottleneck Detection | ◆ New |
| | Pipeline YAML Preview & Validation | ◆ New |
| | Task Lifecycle Tracker | ◆ New |
| **C. Project Management** | Project Dashboard (health, backlog, burndown) | ● v1.0 |
| | Iteration Manager | ◆ New |
| | Dependency Map | ◆ New |
| | Risk Register & Heat Map | ◆ New |
| | Decision Timeline | ◆ New |
| | Release Manager | ◆ New |
| **D. Quality & Operations** | QA Metrics Dashboard (coverage, gates, defects) | ● v1.0 |
| | Operations Dashboard (SLOs, deployments) | ● v1.0 |
| | Defect Deep-Dive & Trend Analysis | ◆ New |
| | Deployment Diff & Rollback Viewer | ◆ New |
| | SLO Forecasting & Budget Projection | ◆ New |
| **E. Troubleshooting & Analysis** | Notification Center (priority-coded feed) | ● v1.0 |
| | Troubleshooting Console | ◆ New |
| | Cross-Agent Communication Audit | ◆ New |
| | Root Cause Analyser | ◆ New |
| | Blocker Chain Visualiser | ◆ New |
| **F. Knowledge & Configuration** | Blueprint Explorer (git tree, documents) | ● v1.0 |
| | Setup & Configuration Wizard | ● v1.0 |
| | Blueprint Diff & Version Compare | ◆ New |
| | Activity Feed & Audit Log | ◆ New |
| | Project Health Score | ◆ New |
| | Webhook & External Alerts | ◆ New |
| **G. Infrastructure & Connectivity** | Network Topology & Health Monitor | ◆ New |
| | Notification Delivery Tracker | ◆ New |
| | Installation & Setup Dashboard | ◆ New |
| | Communication Test Results Viewer | ◆ New |
| | Secrets & Token Inventory | ◆ New |
| | OpenClaw Configuration Viewer | ◆ New |

**Total: 8 original + 28 new = 36 features**

---

## Category A: Agent Observability

### ● Agent Dashboard (v1.0 — existing)
Card grid with live status, latest AI output, click-to-detail. No changes needed.

---

### ◆ A1. Agent Decision Graph

**What it does:** Visualises the execution tree of a single agent session — not a linear log, but a branching graph showing how the agent reasoned, which tools it called, what data it received, and where it made decisions.

**Why it matters:** When an agent produces an unexpected output, reading the raw conversation log is slow and linear. The decision graph shows the branching structure instantly — which tool calls fired, which returned errors, where the agent changed direction. [Arize AI's research](https://arize.com/blog/best-ai-observability-tools-for-autonomous-agents-in-2026/) shows this approach makes debugging agent behaviour 10x faster than raw logs.

**What it shows:**
- Tree-structured execution graph (not flat log)
- Each node = a reasoning step, tool call, or model response
- Edges show data flow between steps
- Colour-coded by outcome: success (green), error (red), retry (orange), skipped (gray)
- Token count per node (input + output)
- Latency per node
- Expandable nodes showing full prompt/response content

**Example use case:** Dev-01 submitted code that failed QA. the end-user clicks dev-01 → Decision Graph → sees the agent called `git diff` (success), then `exec: npm test` (failed), then attempted a fix (re-edit), then `exec: npm test` again (still failed), then reported "blocked" to the Architect. The end-user can see exactly where and why the loop stopped.

**Data source:** OpenClaw gateway session traces

---

### ◆ A2. Agent Session Replay (Time-Travel Debugging)

**What it does:** A chronological playback of an agent's full session — step by step, with timestamps, model I/O, and tool calls rendered in sequence. Inspired by [AgentOps' time-travel debugging](https://latitude.so/blog/best-ai-agent-observability-tools-2026-comparison) concept.

**Why it matters:** Sometimes you need to understand not just what happened, but in what order and how long each step took. Session replay gives a "video playback" experience for agent activity.

**What it shows:**
- Timeline scrubber (horizontal bar with timestamps)
- Step-by-step playback: prompt → model thinking → tool call → tool result → next prompt
- Speed controls (1×, 2×, 4×, skip to next tool call)
- Pause on any step to inspect full content
- Overlay: token count, latency, cost per step
- Jump to "first error" or "longest step"

**Example use case:** QC-01 took 45 minutes on a task that should take 10. the end-user opens Session Replay → scrubs to the longest step → sees a retry loop where the agent tried the same test command 8 times with identical input. Root cause: flaky test environment.

**Data source:** OpenClaw gateway session logs (time-ordered)

---

### ◆ A3. Agent Cost Tracker

**What it does:** Real-time and historical token usage and cost attribution per agent, per VM, per task, and per pipeline phase.

**Why it matters:** GateForge uses multiple AI models with different pricing (Claude Opus 4.6 is premium, MiniMax 2.7 is budget). Without cost visibility, token spend can grow invisibly — especially when agents retry or enter reasoning loops. [Industry research](https://galileo.ai/blog/ai-agent-cost-optimization-observability) shows that teams without cost instrumentation experience 40-60% cost overruns.

**What it shows:**
- **Cost Dashboard:**
  - Total cost today / this week / this month (bar chart)
  - Cost breakdown by VM (pie chart)
  - Cost breakdown by model (Claude Opus vs Sonnet vs MiniMax)
  - Cost breakdown by pipeline phase
  - Cost per task (top 10 most expensive tasks)
- **Per-Agent Detail:**
  - Input tokens vs output tokens per session
  - Average cost per task
  - Token efficiency trend (tokens per useful output line)
  - Retry cost (tokens wasted on retries)
- **Alerts:**
  - Daily budget threshold (e.g., warn if >$50/day)
  - Anomaly detection (agent suddenly using 5× normal tokens)
  - Runaway process alert (agent in loop > 30 min)

**Pricing table (configurable):**

| Model | Input (per 1M tokens) | Output (per 1M tokens) |
|-------|----------------------|----------------------|
| Claude Opus 4.6 | Configurable | Configurable |
| Claude Sonnet 4.6 | Configurable | Configurable |
| MiniMax 2.7 | Configurable | Configurable |

**Data source:** OpenClaw gateway API (token counts per response), configured pricing table

---

### ◆ A4. Agent Comparison Matrix

**What it does:** Side-by-side comparison of agent performance metrics across all agents or selected groups.

**Why it matters:** With multiple developers (dev-01, dev-02...dev-N) and multiple QC agents (qc-01, qc-02...qc-N), the end-user needs to see which agents are most productive, which are struggling, and whether workload is balanced.

**What it shows:**
- Comparison table (rows = agents, columns = metrics):
  - Tasks completed (this iteration)
  - Average task completion time
  - Average tokens per task
  - Cost per task
  - Error/retry rate
  - QA pass rate (for developers: what % of their code passed QA first time)
- Sortable by any column
- Highlight outliers (top performer in green, underperformer in red)
- Trend sparklines per agent

**Example use case:** Dev-01 completes tasks in 15 min average but 40% fail QA. Dev-02 takes 25 min but 90% pass first time. The end-user can see this instantly and decide whether speed or quality is the bottleneck.

---

## Category B: Pipeline & Progress

### ● Lobster Pipeline View (v1.0 — existing)
Six-phase horizontal pipeline with task counters and quality gates. No changes needed.

---

### ◆ B1. Pipeline Run History & Replay

**What it does:** A log of all past pipeline runs (iterations) with the ability to inspect any historical run in full detail.

**Why it matters:** The current Pipeline View shows "now". But the end-user needs to compare: "Was this iteration faster than the last one? Did we have more blockers this time? Which phase took longer?" History enables trend analysis and continuous improvement.

**What it shows:**
- **Run list:** Table of all pipeline runs with start/end date, duration, outcome (completed/aborted/in-progress), task counts
- **Run detail:** Click any run → opens the Pipeline View frozen at that point in time, showing exactly how tasks progressed through each phase
- **Run comparison:** Select 2 runs → side-by-side comparison:
  - Phase durations (bar chart)
  - Task counts per phase
  - Blocker count
  - Quality gate results
  - Cost per run
- **Filters:** By date range, outcome, project module

---

### ◆ B2. Pipeline Analytics & Bottleneck Detection

**What it does:** Automated analysis of pipeline performance identifying where time is spent, what causes delays, and which phases are bottlenecks.

**Why it matters:** Observability dashboards cut issue detection from 4+ hours to under 15 minutes according to [industry trials](https://www.linkedin.com/pulse/top-10-ai-agent-trends-redefining-2026-data-proves-cubeoinnovation-of9kf). Automated bottleneck detection makes this proactive rather than reactive.

**What it shows:**
- **Phase Duration Analysis:**
  - Average time per phase across iterations (trend line)
  - Current iteration phase durations vs historical average
  - Bottleneck highlight: phase that exceeded average by >50% marked in red
- **Wait Time Analysis:**
  - Time tasks spend waiting between phases (queue time)
  - Time tasks spend blocked waiting for another agent
  - Time tasks spend in review vs active work
- **Throughput Metrics:**
  - Tasks completed per day (velocity)
  - Pipeline cycle time (requirement → production)
  - Lead time (task created → task completed)
- **Predictive Alerts:**
  - "At current velocity, Phase 4 (QA) will take 3 more days"
  - "Phase 3 has 2 blocked tasks — pipeline will stall if not resolved"
  - "QA gate coverage at 87% — 8% below target, may not pass"

---

### ◆ B3. Pipeline YAML Preview & Validation

**What it does:** View the Lobster Pipeline YAML definition in a structured, readable format with validation checks. Read-only in v1.0; editable in v2.0.

**Why it matters:** The Lobster YAML defines the deterministic orchestration flow. the end-user should be able to see it visually without reading raw YAML.

**What it shows:**
- YAML source viewer with syntax highlighting
- Structured preview: steps rendered as a vertical flow with agent assignments, actions, inputs, and on_pass/on_fail branching
- Validation panel: checks for unreachable steps, missing on_fail handlers, undefined agent references, circular dependencies
- Diff viewer: compare current YAML with previous version

---

### ◆ B4. Task Lifecycle Tracker

**What it does:** A detailed timeline view for any single task, showing every state change from creation to completion.

**Why it matters:** When a task is delayed or blocked, the end-user needs to see the full history: who created it, who assigned it, when it started, when it was blocked, why, when it was unblocked, when QA picked it up, etc.

**What it shows (for a single task):**
- Vertical timeline with events:
  - Created (by Architect, from requirement X)
  - Assigned (to dev-01, priority P1)
  - Status → in-progress (dev-01 started)
  - Commit (dev-01 pushed to branch feature/FEAT-014)
  - Status → in-review (Architect review requested)
  - Status → done (Architect approved)
  - QA assigned (to qc-01)
  - QA result: HOLD (unit coverage 88% < 95% threshold)
  - Reassigned (to dev-01 for fix)
  - Status → in-progress
  - Commit (dev-01 pushed fix)
  - QA result: PROMOTE (unit coverage 96%)
  - Deployed to Dev (by operator)
  - Deployed to UAT
  - Deployed to Production
- Each event shows: timestamp, agent, duration since previous event, relevant Git commit or notification

---

## Category C: Project Management

### ● Project Dashboard (v1.0 — existing)
Health cards, task table, backlog, burndown. No changes needed.

---

### ◆ C1. Iteration Manager

**What it does:** Dedicated view for managing and reviewing iterations (sprints), with planning, execution tracking, and retrospective data.

**What it shows:**
- **Iteration List:** All iterations with dates, status (planned/active/completed), velocity
- **Active Iteration Detail:**
  - Scope: tasks committed vs tasks completed vs tasks added mid-iteration
  - Burndown chart (points remaining by day)
  - Burnup chart (points completed by day)
  - Scope creep indicator: tasks added after iteration start
  - Velocity trend: last 5 iterations
- **Iteration Retrospective Data:**
  - Planned vs actual points
  - Unfinished tasks (carried over to next iteration)
  - Blockers encountered and resolution time
  - Quality gate pass rate this iteration vs previous

---

### ◆ C2. Dependency Map

**What it does:** Visual graph of task and module dependencies, showing which tasks depend on others and where chains of dependency create risk.

**Why it matters:** In a multi-agent system, agents work in parallel. If FEAT-015 (User API) depends on FEAT-014 (Auth Module), and FEAT-014 is blocked, the end-user needs to see the cascade immediately.

**What it shows:**
- Directed acyclic graph (DAG) of task dependencies
- Nodes = tasks, edges = "depends on"
- Colour by status (green=done, blue=in-progress, orange=blocked, gray=pending)
- Critical path highlighted (longest dependency chain)
- Click any task node → opens Task Lifecycle Tracker
- Module-level view: aggregate dependencies between modules (e.g., "API module depends on Auth module")

---

### ◆ C3. Risk Register & Heat Map

**What it does:** Maintains a risk register for the project and visualises risks on a probability × impact heat map.

**What it shows:**
- Risk table: ID, description, probability (Low/Medium/High), impact (Low/Medium/High), mitigation, owner, status (open/mitigated/escalated/closed)
- Heat map: 3×3 grid with risks plotted by probability and impact
- Auto-detected risks (from pipeline data):
  - "QA coverage below threshold for 3 consecutive days" → Quality risk
  - "2 developers blocked simultaneously" → Resource risk
  - "No deployment to UAT in 5 days" → Schedule risk
  - "SLO error budget at 30%" → Operational risk
- Historical risk trend: risks opened vs closed over time

---

### ◆ C4. Decision Timeline

**What it does:** A chronological timeline of all architectural decisions, quality gate results, dispute resolutions, and project pivots. Sources data from the Blueprint's `decision-log.md` and notification history.

**What it shows:**
- Vertical timeline with filterable event types:
  - ADR (Architecture Decision Records)
  - Quality gate decisions (PROMOTE/HOLD/ROLLBACK)
  - Dispute resolutions (e.g., "Designer vs Developer on caching strategy — Architect chose Redis")
  - Scope changes (requirement added/removed mid-iteration)
  - Blocker resolutions
- Each entry shows: date, decision, rationale, who made it, what was affected
- Filters by date range, type, agent involved

---

### ◆ C5. Release Manager

**What it does:** Tracks releases from planning through deployment, including release notes, changelog, and version comparisons.

**What it shows:**
- **Release List:** All releases with version, date, status (planned/staging/released/rolled-back)
- **Release Detail:**
  - Included features (task IDs + titles)
  - Bugs fixed (defect IDs + titles)
  - Breaking changes
  - Auto-generated release notes (from commit messages and task descriptions)
  - Auto-generated changelog (diff between this release and previous)
  - Deployment status per environment (Dev ✓ / UAT ✓ / Prod ○)
  - Quality gate summary for this release
- **Release Comparison:** Select 2 releases → diff of included features, code changes, test results

---

## Category D: Quality & Operations

### ● QA Metrics Dashboard (v1.0 — existing)
### ● Operations Dashboard (v1.0 — existing)

---

### ◆ D1. Defect Deep-Dive & Trend Analysis

**What it does:** Extended defect analytics beyond the basic summary in the QA dashboard.

**What it shows:**
- **Defect Lifecycle:** Timeline per defect (reported → assigned → in-progress → verified → closed)
- **Defect Aging:** How long defects stay open, by severity
- **Defect Heatmap:** Which modules have the most defects (module × severity matrix)
- **Bug Escape Rate:** Defects found in UAT/Prod that should have been caught earlier
- **Defect Trends:** Open vs closed over time, by severity
- **Defect Root Cause Categories:** Code logic, missing requirement, integration issue, environment issue, test gap
- **Correlation:** Defect density vs code complexity, defect density vs test coverage

---

### ◆ D2. Deployment Diff & Rollback Viewer

**What it does:** Shows exactly what changed between deployments and provides a visual diff for any two versions.

**What it shows:**
- **Deployment History:** All deployments with version, timestamp, environment, status, deployed-by (agent)
- **Deployment Diff:** Select any two deployments → see:
  - Files changed (added/modified/deleted)
  - Git diff viewer with syntax highlighting
  - Config changes
  - Database migration changes
- **Rollback Chain:** Visual chain showing: current version → rollback target → what would be reverted
- **Smoke Test Results:** Per-deployment smoke test pass/fail with detail

---

### ◆ D3. SLO Forecasting & Budget Projection

**What it does:** Projects SLO error budget consumption into the future based on current burn rate.

**What it shows:**
- **Error Budget Runway:** "At current burn rate, API availability error budget will be exhausted in 12 days"
- **Projection Chart:** Line chart showing error budget remaining over time with projection line
- **What-If Scenarios:** "If we reduce error rate by 50%, budget lasts 45 days instead of 12"
- **Historical SLO Compliance:** Monthly SLO achievement rate trend
- **Breach History:** Past SLO breaches with root cause and resolution

---

## Category E: Troubleshooting & Analysis

### ● Notification Center (v1.0 — existing)

---

### ◆ E1. Troubleshooting Console

**What it does:** A centralised troubleshooting workspace where the end-user can investigate issues across agents, tasks, and pipeline phases.

**Why it matters:** When something goes wrong, information is scattered across agent logs, notifications, task status, and pipeline state. The console aggregates everything related to a specific issue in one place.

**What it shows:**
- **Issue Selector:** Start from a notification, a blocked task, or a failed gate
- **Context Panel:** Automatically gathers:
  - The agent(s) involved
  - The task(s) affected
  - The pipeline phase
  - Related notifications (cross-referenced by task ID)
  - Related Git commits
  - Related QA results
  - Related agent session logs
- **Correlation Timeline:** All events from all sources on a single timeline, filtered to this issue
- **Suggested Actions:** Based on the issue type:
  - "This is a blocked task → check dependency chain"
  - "This is a QA gate HOLD → check coverage gaps"
  - "This is a build failure → check agent decision graph for error"

---

### ◆ E2. Cross-Agent Communication Audit

**What it does:** A visual log of all inter-agent communications — every HTTP dispatch from the Architect to spokes, every notification back, every structured JSON payload.

**Why it matters:** GateForge's hub-and-spoke model means all communication routes through the Architect. Auditing this communication helps verify that the right messages reached the right agents at the right time, and that no message was lost or corrupted. This is essential for [regulated industries](https://www.mindstudio.ai/blog/scaling-ai-agents-best-practices-multi-bot-deployment/) requiring complete decision logging.

**What it shows:**
- **Message Flow Diagram:** Architect → spoke dispatch and spoke → Architect notification rendered as a sequence diagram
- **Message Log:** Chronological table of all inter-agent messages with:
  - Timestamp
  - Source VM → Destination VM
  - Message type (task dispatch / notification / query / resolution)
  - Priority
  - HMAC verification status (valid / expired / failed)
  - Payload summary (truncated, click to expand)
- **Message Search:** Full-text search across all payloads
- **Delivery Metrics:**
  - Message delivery latency (time from send to acknowledge)
  - Failed deliveries (VM unreachable)
  - Retry count
  - Messages per hour/day trend

---

### ◆ E3. Root Cause Analyser

**What it does:** When a pipeline stalls, a gate fails, or a task is blocked, the Root Cause Analyser traces backwards through the event chain to suggest the root cause.

**How it works:**
1. Starts from the symptom (e.g., "Phase 4 QA is blocked")
2. Traces upstream: which tasks in Phase 3 are incomplete?
3. For incomplete tasks: which agents are assigned? What's their status?
4. For blocked agents: what are they waiting for? Who dispatched the task?
5. Presents a chain: "QA blocked → waiting for FEAT-014 → assigned to dev-01 → dev-01 status: error → last action: npm test failed → root cause: test environment misconfiguration"

**What it shows:**
- **Cause Chain:** Visual chain from symptom → intermediate causes → root cause
- **Confidence Level:** Based on data completeness (high if full trace available, low if data missing)
- **Suggested Resolution:** Based on root cause category
- **Similar Past Issues:** If a similar pattern was seen before

---

### ◆ E4. Blocker Chain Visualiser

**What it does:** Shows all currently blocked items and their dependency chains — what is blocked, by what, and how deep the chain goes.

**What it shows:**
- **Blocked Items List:** All tasks/agents currently in "blocked" status
- **Chain Diagram:** For each blocked item, trace the full chain:
  - Task A (blocked) → waiting for Task B (in-progress) → assigned to dev-02 → estimated completion: 2 hours
  - Task C (blocked) → waiting for Task A (blocked) → cascading block
- **Impact Score:** Number of downstream items affected if this blocker persists
- **Resolution Priority:** Blockers ranked by impact score (highest impact = resolve first)

---

## Category F: Knowledge & Configuration

### ● Blueprint Explorer (v1.0 — existing)
### ● Setup & Configuration Wizard (v1.0 — existing)

---

### ◆ F1. Blueprint Diff & Version Compare

**What it does:** Compare any two versions of any Blueprint document side-by-side.

**What it shows:**
- **Version Selector:** Pick two commits or dates
- **Side-by-side diff:** Unified or split diff view with syntax highlighting
- **Change Summary:** Lines added/removed/modified, sections changed
- **Author Attribution:** Which agent made each change (from Git commit author)
- **Approval Status:** Was this change reviewed? By whom? When?

---

### ◆ F2. Activity Feed & Audit Log

**What it does:** A comprehensive, immutable audit log of everything that happens in GateForge — every agent action, every status change, every deployment, every gate decision.

**Why it matters:** For enterprise and regulated environments, [complete decision logging with chain-of-custody tracking](https://www.mindstudio.ai/blog/scaling-ai-agents-best-practices-multi-bot-deployment/) across all agents is essential. Immutable audit records cannot be modified after creation.

**What it shows:**
- **Unified Activity Feed:** Reverse-chronological stream of all system events:
  - Agent started/stopped/status changed
  - Task created/assigned/status changed
  - Pipeline phase advanced
  - Quality gate evaluated
  - Deployment executed
  - Notification dispatched
  - Blueprint document updated
  - Configuration changed
- **Filters:** By event type, VM, agent, date range, severity
- **Export:** CSV/JSON export for compliance reporting
- **Retention:** Configurable retention period (30/90/180/365 days)

---

### ◆ F3. Project Health Score

**What it does:** A single composite score (0–100) representing overall project health, computed from multiple dimensions. Visible on every page as a persistent indicator.

**Scoring dimensions (weighted):**

| Dimension | Weight | Source | Example |
|-----------|--------|--------|---------|
| Pipeline Progress | 20% | % of pipeline phases completed | 3/6 phases = 50% |
| Agent Availability | 15% | % of agents online and active | 5/6 agents active = 83% |
| Task Velocity | 15% | Tasks completed vs planned | 12/15 done = 80% |
| Quality Gate Health | 15% | % of gates passing | 2/3 gates pass = 67% |
| Blocker Count | 15% | Inverse of blocked tasks | 1 blocker = 90%, 5 = 50% |
| SLO Compliance | 10% | % of SLOs within budget | 5/5 healthy = 100% |
| Cost Efficiency | 10% | Actual cost vs budget | Within budget = 100% |

**Visual treatment:**
- Score badge in header bar (always visible): 🟢 80-100 / 🟡 50-79 / 🔴 0-49
- Score detail card on Project Dashboard with per-dimension breakdown
- Score trend over time (sparkline)

---

### ◆ F4. Webhook & External Alerts

**What it does:** Pushes selected portal events to external channels (Slack, email, PagerDuty, custom HTTP webhook). Read-only principle still applies — webhooks go to external notification systems, never back to agents.

**Configurable triggers:**
- CRITICAL notification received
- QA gate ROLLBACK decision
- Deployment failure
- SLO error budget < 25%
- Agent offline > 5 minutes
- Project health score drops below threshold
- Daily/weekly summary digest

**Channels:**
- Slack (incoming webhook URL)
- Email (SMTP config)
- PagerDuty (integration key)
- Custom HTTP POST (any URL with configurable payload template)
- Telegram (additional bot — separate from the Architect's Telegram)

---

## Category G: Infrastructure & Connectivity

> All features in this category are read-only. The portal observes and reports on the GateForge infrastructure; it never controls or reconfigures it.

---

### ◆ G1. Network Topology & Health Monitor

**What it does:** Provides a real-time view of all 5 VM connections over the Tailscale VPN, showing the live connectivity status of every node in the GateForge hub-and-spoke network.

**Why it matters:** GateForge's inter-VM communication now runs over Tailscale VPN with MagicDNS hostnames and loopback-bound gateways exposed via Tailscale Serve. If any VM becomes unreachable — due to a Tailscale key expiry, a failed Serve process, or a UFW misconfiguration — agent dispatches and notifications will silently fail. A dedicated topology monitor surfaces these failures immediately so the end-user can act before the pipeline stalls.

**What it shows:**
- **Network Topology Diagram:** Hub-and-spoke layout rendered as an interactive graph
  - Hub: `tonic-architect` (VM-1, 100.73.38.28)
  - Spokes: `tonic-designer` (VM-2, 100.95.30.11), `tonic-developer` (VM-3, 100.81.114.55), `tonic-qc` (VM-4, 100.106.117.104), `tonic-operator` (VM-5, 100.95.248.68)
  - Each node shows: MagicDNS hostname, Tailscale IP, role label
  - Each edge shows: latency (ms), last successful heartbeat timestamp
- **Per-VM Status Cards:**
  - Tailscale connection status (connected / disconnected / key expired)
  - Tailscale Serve status (active / inactive)
  - OpenClaw gateway reachability (probed at `https://<hostname>.sailfish-bass.ts.net:18789/health`)
  - UFW firewall status (enabled / disabled / misconfigured)
  - Last heartbeat timestamp and round-trip latency
- **Live Status Indicators:** Green (all healthy) / Amber (degraded — high latency or partial failure) / Red (unreachable)
- **Alerts:**
  - VM unreachable for > 60 seconds
  - Gateway health probe returning non-200
  - Latency spike above configurable threshold (default: 200 ms)
  - Tailscale Serve inactive on any spoke

**Example use case:** The end-user notices BLOCKED notifications have stopped arriving from tonic-developer. The Network Topology Monitor shows tonic-developer's gateway health probe has been failing for 3 minutes — Tailscale Serve has stopped. The end-user can immediately identify which VM needs attention without manually SSH-ing into each machine.

**Data source:** Periodic health probes to `https://<hostname>.sailfish-bass.ts.net:18789/health` on each VM; Tailscale status API (read-only)

---

### ◆ G2. Notification Delivery Tracker

**What it does:** Monitors the host-side `gf-notify-architect` notification relay system, providing full visibility into every HMAC-signed notification sent from spoke VMs to the Architect, including delivery status and dead-letter queue contents.

**Why it matters:** GateForge's host-side notification relay (`gf-notify-architect.sh`) keeps the `AGENT_SECRET` off the LLM context entirely — but this means notification delivery is now a separate process from the agent itself. If a notification fails to reach the Architect's `/hooks/agent` endpoint, the pipeline loses the signal that a task completed or was blocked. The end-user needs a real-time view of delivery health, with visibility into dead-lettered notifications that require replay.

**What it shows:**
- **Notification Feed:** Chronological timeline of all notifications sent via the relay, with:
  - Timestamp (commit time → notification sent → delivery acknowledged)
  - Source VM and role (e.g., `tonic-developer` / developer)
  - Task ID (`GateForge-Task-Id` commit trailer)
  - Priority level (COMPLETED / BLOCKED / DISPUTE / CRITICAL / INFO)
  - HMAC-SHA256 signature status (valid / invalid / missing)
  - Delivery status badge: Delivered (green) / Failed (red) / Dead-Lettered (amber) / Pending Replay (blue)
- **Commit Trailer Compliance:**
  - Required trailers: `GateForge-Task-Id`, `GateForge-Priority`, `GateForge-Source-VM`, `GateForge-Source-Role`, `GateForge-Summary`
  - Commits with missing or malformed trailers are flagged — these auto-trigger a BLOCKED notification
  - Trailer compliance rate per VM (% of commits with all 5 trailers present)
- **Dead Letter Queue Viewer:**
  - List of all failed notifications awaiting replay via `gf-replay-deadletter.sh`
  - Per-entry: failure reason, retry count, original payload summary, time since failure
  - Replay history: when replays were attempted and whether they succeeded
- **Delivery Metrics:**
  - Notifications sent / delivered / failed (last 24h, 7d, 30d)
  - Average delivery latency (commit push → Architect acknowledgement)
  - Failed delivery rate trend

**Example use case:** The end-user sees that tonic-qc sent a COMPLETED notification 8 minutes ago but no task was updated in the pipeline view. The Notification Delivery Tracker shows the notification is dead-lettered — the Architect's hook endpoint returned a 503. The end-user can see the replay has been scheduled and monitor when it succeeds.

**Data source:** `gf-notify-architect` relay logs; `.git/refs` watch events; Architect `/hooks/agent` delivery receipts

---

### ◆ G3. Installation & Setup Dashboard

**What it does:** Shows the setup and configuration status of all 5 VMs, surfacing whether the automated install scripts have been run, whether their outputs are still valid, and whether any configuration drift has occurred since initial setup.

**Why it matters:** GateForge's install pipeline consists of `install-common.sh` plus per-VM setup scripts (`setup-vm1-architect.sh` through `setup-vm5-operator.sh`) — approximately 1,400 lines of bash automation. Each script is idempotent, but the end-user needs to know at a glance whether every VM is fully configured and whether anything has drifted from the expected state (e.g., a Tailscale Serve config was cleared, UFW rules were flushed, or a secrets file was deleted).

**What it shows:**
- **Per-VM Setup Checklist:** One card per VM, each showing a checklist of setup components:
  - `install-common.sh` — last run timestamp, exit status
  - Per-VM setup script — last run timestamp, exit status
  - OpenClaw gateway configuration — present and valid
  - Tailscale Serve — active and serving on expected port (18789)
  - UFW firewall — enabled, port 18789 restricted to the 5 GateForge Tailscale IPs
  - Secrets files — present with correct permissions (see G5)
  - SOUL.md / TOOLS.md / USER.md / AGENTS.md — present and up to date
- **Configuration Drift Detection:**
  - Compares live VM state against the expected configuration defined at install time
  - Flags any component that has diverged: "UFW rule for 100.73.38.28 missing on tonic-qc"
  - Drift severity: Info (cosmetic difference) / Warning (functional impact possible) / Critical (component non-functional)
- **Setup History:**
  - Log of all setup script runs with timestamp, operator, and outcome
  - Side-by-side comparison of successive runs to see what changed

**Example use case:** After a VMware snapshot restore on tonic-operator, the end-user opens the Installation & Setup Dashboard and sees the Tailscale Serve entry is red — the restore rolled back the Serve configuration. The end-user can immediately identify the affected VM and the specific component to remediate.

**Data source:** Setup script execution logs; live configuration probes per VM; file presence and permission checks via OpenClaw gateway API

---

### ◆ G4. Communication Test Results Viewer

**What it does:** Displays the results of GateForge's end-to-end communication test suite (`test-connectivity.sh` and `test-communication.sh`), giving the end-user a structured, visual record of every test run and historical trend.

**Why it matters:** The test framework validates the entire communication path from Architect dispatch through to HMAC callback and Git deliverable readability — 4 sequential gates per agent. Raw test output is bash terminal text; the end-user needs a structured view to understand pass/fail patterns, spot flaky agents, and confirm the network is healthy before starting a new iteration.

**What it shows:**
- **Test Run History:** Table of all test suite executions with timestamp, triggered-by, scope (all agents / specific agent), pass/fail summary
- **Gate-by-Gate Results Matrix:**
  - Rows = agents tested (dev-01, dev-02...dev-N, qc-01...qc-N, designer, operator)
  - Columns = the 4 communication gates:
    - **Gate A (Dispatch):** Architect → spoke dispatch accepted (HTTP 200 + runId returned)
    - **Gate B (Commit):** Spoke agent committed and pushed deliverable file to branch
    - **Gate C (Callback):** Architect received valid HMAC-signed callback within 90 seconds
    - **Gate D (Readable):** Deliverable readable by hub via `git cat-file`
  - Each cell: Pass (green) / Fail (red) / Warn (amber) / Not Run (gray)
  - Click any cell → drill down to the raw test output for that gate and agent
- **Trailer Validation Results:**
  - Per-agent validation of all 5 required commit trailers
  - Missing or malformed trailers highlighted by trailer name
- **Trend View:**
  - Pass rate per agent over the last N test runs (sparkline)
  - "Are tests getting more reliable?" — trend direction indicator
  - Flaky agent detection: agents with inconsistent pass/fail patterns across runs
- **Connectivity Test Results (`test-connectivity.sh`):**
  - Network reachability results per VM
  - Gateway authentication checks
  - HMAC notification round-trip results

**Example use case:** Before beginning a new development iteration, the end-user runs the full test suite and opens the Communication Test Results Viewer. Gate C fails for tonic-designer — the HMAC callback did not arrive within 90 seconds. Drilling into the raw output shows the Architect's hook endpoint returned a 404. The end-user investigates the Architect's OpenClaw config before proceeding.

**Data source:** `test-connectivity.sh` and `test-communication.sh` output logs; `test-spoke.sh` results for individual VM validation runs

---

### ◆ G5. Secrets & Token Inventory

**What it does:** Provides a read-only inventory of the secrets management layout across all 5 VMs — showing which token files exist, their permissions, and whether the 3-tier secrets architecture is correctly in place. Actual secret values are never displayed.

**Why it matters:** GateForge uses a structured 3-tier secrets layout to ensure that sensitive tokens (HMAC keys, GitHub PATs, LLM API keys) are stored in the correct locations with the correct permissions and are never exposed to agent LLM contexts. Without a centralised inventory view, a missing token file or wrong permission on one VM can cause silent failures that are hard to diagnose — a setup script re-run might not fix a file that was manually modified.

**What it shows:**
- **Per-VM Token Inventory:** One panel per VM listing all expected secret files and their status:
  - **Platform tier** (`/opt/secrets/gateforge.env`): present / missing / wrong permissions
    - Expected: `root:root`, mode `0600`
    - Expected tokens: HMAC_SECRET, ARCHITECT_HOOK_TOKEN, GATEWAY_API_KEY
  - **GitHub tier** (`~/.config/gateforge/github-tokens.env`): present / missing / wrong permissions
    - Expected: `<vm-user>:<vm-user>`, mode `0600`
    - Expected tokens: GITHUB_PAT, GITHUB_USERNAME, GITHUB_REPO
  - **App tier** (`~/.config/gateforge/<app>.env` per application): present / missing / wrong permissions
    - Apps vary by VM role: LLM provider key, Brave Search, Telegram (Architect only), etc.
- **Compliance Status per VM:**
  - All expected files present: Yes / No (with list of missing files)
  - All permissions correct: Yes / No (with list of mismatched files)
  - Expected token count vs actual token count per file
- **Alerts:**
  - Missing expected token file on any VM
  - Incorrect file permissions (e.g., file readable by group or world)
  - Stale tokens: file not modified in more than N days (configurable threshold, default: 90 days)
  - Token count mismatch: fewer tokens than expected in a file (possible partial write)
- **Last Modified Timestamps:** When each secrets file was last written (without revealing content)

**Example use case:** After rotating the GitHub PAT on tonic-developer, the end-user checks the Secrets & Token Inventory and sees `github-tokens.env` on tonic-qc still shows a last-modified date from 45 days ago — a different rotation schedule. The end-user notes the discrepancy for the next secrets rotation cycle.

**Data source:** File presence and `stat` metadata checks via OpenClaw gateway API on each VM (read-only filesystem introspection; no file content is transmitted)

---

### ◆ G6. OpenClaw Configuration Viewer

**What it does:** A read-only view of each VM's `openclaw.json` configuration, with a cross-VM diff capability to spot inconsistencies between configurations and a validation check against expected settings.

**Why it matters:** Each VM runs its own `openclaw.json` tailored to its role — gateway bind mode, Tailscale Serve settings, allowed origins, agent definitions, and environment variable mappings. Because each config is maintained separately, they can drift: an `allowedOrigins` entry might be missing from one VM, a port might be wrong, or the bind mode might have been changed during debugging. A centralised viewer with diff and validation makes auditing all 5 configs a one-minute task rather than a manual SSH exercise.

**What it shows:**
- **Per-VM Configuration Panel:** One tab per VM, showing the full `openclaw.json` rendered as a structured, syntax-highlighted JSON viewer (not raw text):
  - Gateway settings: bind mode (expected: `loopback`), port (expected: `18789`), TLS/Tailscale Serve settings
  - `allowedOrigins`: list of domains permitted to access the Control UI cross-VM
  - Agent definitions: list of configured agents with their model, system prompt reference, and tool access
  - Environment variable mappings: which env vars are injected into agent contexts (names only, not values)
- **Cross-VM Diff View:**
  - Select any two VMs → side-by-side diff of their `openclaw.json` contents
  - Differences highlighted at the field level (not just line level)
  - "All VMs" diff: shows a summary of fields that differ across any of the 5 VMs
- **Validation Checks:**
  - All 5 VM domains present in `allowedOrigins` on every VM (e.g., `https://tonic-architect.sailfish-bass.ts.net`)
  - Bind mode is `loopback` on all VMs (not `0.0.0.0`)
  - Gateway port is `18789` on all VMs
  - No agent definition references a missing environment variable
  - Tailscale Serve is configured to match the gateway port
- **Configuration History:** If `openclaw.json` is version-controlled, shows a changelog of recent edits with timestamps

**Example use case:** After onboarding a new QC agent on tonic-qc, the end-user uses the cross-VM diff to compare `tonic-qc`'s `openclaw.json` against `tonic-developer`'s. The diff reveals that the new agent definition on tonic-qc references `BRAVE_API_KEY` in its env var mapping, but the validation check flags that this variable is not in the app-tier secrets file for that VM — a configuration mismatch that would cause the agent to fail silently.

**Data source:** `openclaw.json` file contents read via OpenClaw gateway API on each VM (read-only); Git history if `openclaw.json` is tracked in the Blueprint repository

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
| | Network Topology & Health Monitor | G | Medium | High |
| | Notification Delivery Tracker | G | Medium | High |
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
| | Installation & Setup Dashboard | G | Medium | Medium |
| | Communication Test Results Viewer | G | Medium | Medium |
| **P3 — Want (v2.5+)** | Agent Comparison Matrix | A | Small | Medium |
| | Pipeline YAML Preview & Validation | B | Medium | Medium |
| | Defect Deep-Dive & Trend Analysis | D | Medium | Medium |
| | Deployment Diff & Rollback Viewer | D | Medium | Medium |
| | SLO Forecasting & Budget Projection | D | Medium | Medium |
| | Secrets & Token Inventory | G | Small | Medium |
| | OpenClaw Configuration Viewer | G | Small | Medium |

---

## Revised Navigation Structure

With 36 features, the sidebar navigation needs restructuring:

```
GATEFORGE ADMIN PORTAL
─────────────────────────
◉ Dashboard Home          ← Project Health Score + key metrics
│
├── Agents
│   ├── Overview          ← Agent Dashboard (card grid)
│   ├── Decision Graph    ← Per-agent execution tree
│   ├── Session Replay    ← Time-travel debugging
│   ├── Cost Tracker      ← Token usage and billing
│   └── Comparison        ← Side-by-side agent metrics
│
├── Pipeline
│   ├── Live View         ← Lobster Pipeline (current)
│   ├── Run History       ← Past pipeline runs
│   ├── Analytics         ← Bottleneck detection
│   ├── YAML Preview      ← Pipeline definition viewer
│   └── Task Tracker      ← Per-task lifecycle
│
├── Project
│   ├── Dashboard         ← Health, backlog, burndown
│   ├── Iterations        ← Sprint management
│   ├── Releases          ← Release tracking
│   ├── Dependencies      ← Task/module dependency graph
│   ├── Risks             ← Risk register & heat map
│   └── Decisions         ← Decision timeline
│
├── Quality
│   ├── Metrics           ← Coverage, gates, defects
│   ├── Defect Analysis   ← Deep-dive & trends
│   └── Gate History      ← Historical PROMOTE/HOLD/ROLLBACK
│
├── Operations
│   ├── Dashboard         ← SLOs, environments, incidents
│   ├── Deployments       ← Diff & rollback viewer
│   └── SLO Forecast      ← Budget projection
│
├── Troubleshooting
│   ├── Console           ← Centralised investigation
│   ├── Blockers          ← Blocker chain visualiser
│   ├── Root Cause        ← Automated root cause analysis
│   └── Comms Audit       ← Inter-agent message log
│
├── Blueprint
│   ├── Explorer          ← Git tree & document viewer
│   └── Compare           ← Version diff
│
├── Infrastructure
│   ├── Network Topology  ← Tailscale VPN health & latency
│   ├── Notifications     ← gf-notify-architect delivery tracker
│   ├── Setup Status      ← Install script & config drift
│   ├── Test Results      ← Communication test suite viewer
│   ├── Secrets Inventory ← Token file presence & permissions
│   └── OpenClaw Config   ← Per-VM openclaw.json viewer & diff
│
├── Notifications         ← Priority-coded feed
├── Activity Log          ← Full audit trail
├── Webhooks              ← External alert config
└── Settings              ← Setup wizard & configuration
```

---

## Summary

The original 8 features provide solid observability for "what is happening now." The 28 new features add:

- **Depth** — Decision graphs, session replay, and task lifecycle tracking let the end-user drill from a dashboard card all the way down to a specific model response on a specific timestamp
- **History** — Pipeline run history, iteration manager, release manager, and audit logs give full retrospective capability
- **Intelligence** — Bottleneck detection, root cause analysis, SLO forecasting, and project health scoring transform raw data into actionable insights
- **Troubleshooting** — Console, blocker chains, and communication audit let the end-user investigate any issue without switching between multiple views
- **Governance** — Audit log, risk register, decision timeline, and webhook alerts support enterprise and regulated environments
- **Cost Control** — Agent cost tracker with anomaly detection prevents invisible token spend from growing unchecked
- **Infrastructure** — Network topology monitoring, notification delivery tracking, setup validation, end-to-end test results, secrets inventory, and OpenClaw configuration review give the end-user full visibility into the Tailscale VPN networking layer, host-side relay health, and per-VM configuration state that underpins the entire GateForge system

Together, these 36 features make the GateForge Admin Portal a complete multi-agent SDLC command centre — not just a monitoring dashboard, but a tool for understanding, analysing, and improving the pipeline.

---

*GateForge Admin Portal Extended Features — April 2026*

# GateForge Admin Portal — Control Tower Specification

**Document Status:** Draft
**Version:** 0.3
**Created:** 2026-04-24
**Supersedes (positioning only, not feature set):** companion product framing in `GATEFORGE-ADMIN-PORTAL.md` §1

> This document extends the existing Admin Portal specification set (`GATEFORGE-ADMIN-PORTAL.md`, `…-EXTENDED-FEATURES.md`, and the canonical build plan `…-IMPLEMENTATION.md`) with the **Control Tower** product direction. It **preserves** the 30 + 36 feature catalogue already defined; it **re-groups** them into operational modules, adds the backlog IDs (ADM-xxx), acceptance criteria, a suggested SQLite data model, an API outline, and a phased delivery roadmap.
>
> Where this document and the existing specs disagree on *wording*, the existing specs remain the detailed reference. Where they disagree on *product positioning or scope* (read-only v1, Control Tower framing), **this document takes precedence**.

---

## Table of Contents

1. [Control Tower — Concept and Positioning](#1-control-tower--concept-and-positioning)
2. [Portal Areas / Modules](#2-portal-areas--modules)
3. [Backlog — ADM-xxx IDs](#3-backlog--adm-xxx-ids)
4. [Acceptance Criteria (Given / When / Then) — Key P0 Features](#4-acceptance-criteria-given--when--then--key-p0-features)
5. [Suggested SQLite Data Model](#5-suggested-sqlite-data-model)
6. [Suggested API Outline](#6-suggested-api-outline)
7. [Implementation Roadmap](#7-implementation-roadmap)
8. [Read-Only v1 Guardrails and Future Write-Action Cautions](#8-read-only-v1-guardrails-and-future-write-action-cautions)
9. [n8n — Integration Layer, Not SDLC Orchestrator](#9-n8n--integration-layer-not-sdlc-orchestrator)

---

## 1. Control Tower — Concept and Positioning

### 1.1 What the Portal Is (v1)

The GateForge Admin Portal is the **read-only operational control tower and trust layer** for the GateForge Agentic SDLC. It is the single place the end-user (CTO / Project Lead) goes to answer, in under five seconds:

- *Is my fleet healthy?* — agent heartbeats, VM reachability, model availability.
- *Are notifications reaching the Architect?* — delivery success, dead-letter queue depth.
- *Is the Blueprint governed?* — required documents present, trailers valid, traceability closed.
- *Is my security posture clean?* — secret hygiene, token rotation, hook/agent auth.
- *Is model and provider routing resilient?* — active routes, fallback state, provider outage impact.
- *Am I set up correctly?* — installer checks green, network topology green, communication tests pass.
- *Do I have evidence?* — audit events, release-readiness reports, exportable artefacts.
- *Am I healthcare-ready?* — HIPAA / HITRUST control overlay where applicable.

### 1.2 What the Portal Is Not (v1)

- **It is not an agent controller.** The portal does not start, stop, redirect, re-prompt, approve, or cancel any agent task in v1. Human interaction with the pipeline continues to route through Telegram → Architect (VM-1).
- **It is not the Blueprint.** The Blueprint Git repository remains the single source of truth. The portal *reads* the Blueprint, surfaces drift and gaps, and links to commits — it never writes.
- **It is not an SDLC orchestrator.** The deterministic SDLC loop lives inside GateForge (Architect ↔ spokes). The portal observes.

### 1.3 Why "Control Tower" (and not "Dashboard")

A dashboard shows numbers. A control tower establishes **trust**:

| Trust property | How the Control Tower delivers it |
|----------------|-----------------------------------|
| **Visibility** | Mission Control landing view — one pane, all signals, five-second read. |
| **Accountability** | Every surfaced state is traceable to a raw source (git commit, gateway trace, notification id, secret file path). |
| **Evidence** | Audit events, report exports, traceability links are first-class, not bolt-on. |
| **Safety** | Read-only by construction in v1. Any future write action requires RBAC + audit. |
| **Readiness** | Setup and installer checks, communication tests, and healthcare overlays confirm *the whole system is ready to run* — not just that a single agent responded. |

### 1.4 Relationship to Existing Specs

The existing specs catalogue **66 distinct feature surfaces** across two documents (30 in `GATEFORGE-ADMIN-PORTAL.md`, 36 in `…-EXTENDED-FEATURES.md`, with overlap). The Control Tower framing does not invent new surfaces — it **re-groups them into operational modules** and adds the missing trust-layer pieces (Dead-letter Queue, Model & Provider Resilience, Healthcare Readiness Overlay, Setup & Installer Dashboard, Audit & Management Reports).

Existing category letters (A–G) and feature numbering in `…-EXTENDED-FEATURES.md` remain intact. New ADM-xxx backlog IDs (§3) are **additive** and map onto existing features where they exist.

---

## 2. Portal Areas / Modules

Each module below specifies: **Purpose**, **Primary user question it answers**, **Page content / UX**, and **Upstream data sources**. Modules are the operational grouping; they compose the sidebar but do not replace the fine-grained features in `…-EXTENDED-FEATURES.md`.

### 2.1 Mission Control

**Purpose:** The landing page. One screen, all green/amber/red signals.

**Primary question:** *Is GateForge healthy right now?*

**Page content:**
- **Top banner:** system-wide status pill — `HEALTHY` / `DEGRADED` / `CRITICAL`, with the most recent state change timestamp.
- **Six status tiles** (each click-through to its module):
  1. Agent Fleet — `X/Y agents reporting`, last heartbeat age.
  2. Notifications — `delivered / failed / DLQ depth` (last 24h).
  3. Blueprint Governance — `required docs present`, open gate failures.
  4. Security Posture — `open high findings`, days since last rotation.
  5. Model & Provider — active route, fallback armed, provider incidents.
  6. Setup Readiness — `green / yellow / red` installer + connectivity.
- **Live activity rail** (right-hand column) — SSE stream of recent incidents, dead-letters, failed deliveries, blueprint gate failures. Capped at 50 items, newest on top.
- **Healthcare overlay toggle** — when enabled, tiles show a small HC badge summarising compliance control state (see §2.8).

**Upstream sources:** `/api/health/summary`, `/api/events/stream`.

---

### 2.2 Agent Fleet

**Purpose:** Health of every agent on every VM — the expansion of existing Agent Observability.

**Primary question:** *Which agents are alive, lagging, or silent — and on which VM?*

**Page content:**
- Card grid (preserves existing Agent Dashboard layout) — one card per agent, with heartbeat age, last tool call, model in use.
- Grouping toggle — by VM, by role, by model, by project (when multi-project lands).
- Filters — `status=active|idle|stalled|silent`, `role=architect|designer|dev|qc|operator`, `model=opus|sonnet|minimax`.
- Per-agent detail drawer — pulls in existing Agent Decision Graph, Session Replay, Cost Tracker for the selected agent.
- **Stalled-agent banner** — if any agent's last heartbeat is > `STALL_THRESHOLD_S` (default 120s), banner calls it out. v1: banner only, no restart button.

**Upstream sources:** `/api/agents`, OpenClaw gateway traces, `heartbeats` table.

---

### 2.3 Notification Center

**Purpose:** Prove that every cross-VM notification that *should* have reached the Architect *did* reach the Architect.

**Primary question:** *Is my hub-and-spoke messaging working?*

**Page content:**
- Priority-coded feed (existing Notification Center preserved).
- **Delivery Tracker pane** — for each notification: sent timestamp, receive timestamp at Architect, latency, retries, final outcome (`DELIVERED` / `RETRYING` / `DEAD_LETTER`).
- Filters — source VM, priority (`COMPLETED|BLOCKED|DISPUTE|CRITICAL|INFO`), outcome, date range.
- Required-trailer validator — flags any notification missing `GateForge-Task-Id`, `GateForge-Priority`, `GateForge-Source-VM`, `GateForge-Source-Role`, or `GateForge-Summary`.
- Notification statistics panel — counts, delivery rate %, median latency, top failing source VM.

**Upstream sources:** `/api/notifications`, `notifications` table, Architect inbox relay logs.

---

### 2.4 Dead-letter Queue

**Purpose:** First-class surface for notifications and tasks that failed all retries. A healthy system has DLQ depth = 0.

**Primary question:** *What is stuck, since when, and why?*

**Page content:**
- DLQ table — id, source VM, task id, priority, first-failure timestamp, last-attempt timestamp, retry count, final error.
- Detail drawer — full original payload, each retry attempt with gateway response, suggested next step (text only — no "retry" button in v1).
- **Age buckets** — `<1h`, `1–24h`, `1–7d`, `>7d`. Items older than 24h are flagged red.
- Export — CSV / JSON for incident review.
- *Deferred to post-RBAC:* "Replay" action (see §8).

**Upstream sources:** `/api/dead-letters`, `dead_letters` table.

---

### 2.5 Blueprint Governance

**Purpose:** The Blueprint is the source of truth. Governance answers: *is it complete, consistent, and traceable?*

**Primary question:** *Is the Blueprint in a releasable state?*

**Page content:**
- **Required-document checklist** — per active iteration, which of the mandated Blueprint documents (PRD, ADR, design notes, QA plan, runbook, rollback) are present, missing, stale, or flagged.
- **Gate / check board** — one row per blueprint check (Design Gate, Code Gate, QA Gate, Release Gate) with current decision (`Pass`/`Fail`/`Hold`/`Rollback`) and last evaluator (agent id + commit SHA).
- **Artefact viewer** — list of artefacts produced by the Blueprint (test reports, coverage reports, deployment runbooks) with direct links to commits.
- **Traceability links** — requirement → design → code commit → test → defect. Broken chains are highlighted.
- **Blueprint Diff & Activity Feed** — preserves existing features 5.6 / 5.7.

**Upstream sources:** `/api/blueprint/summary`, Blueprint Git repository (read-only clone / API), `blueprint_checks`, `blueprint_artifacts`, `traceability_links` tables.

---

### 2.6 Security & Secrets

**Purpose:** Operational security posture for the GateForge control plane itself (not the application being built).

**Primary question:** *Are my tokens, secrets, and hook authentications healthy?*

**Page content:**
- **Security Findings board** — open findings with severity (`CRITICAL|HIGH|MEDIUM|LOW`), source (hook auth check, token rotation check, openclaw.json lint, Tailscale ACL check), age, suggested remediation text.
- **Secret Inventory** — per VM, presence and file-mode of required secret files (hook token, agent secret, provider API keys). Never shows secret *values* — only presence, size, mode, modified time, owner.
- **Rotation status** — for each secret, last-rotated timestamp and days since. Red past policy threshold (default 90 days).
- **Hook & Agent auth health** — last successful auth probe per VM; failures ranked.
- **Healthcare overlay** (when enabled) — which findings map to HIPAA / HITRUST controls.

**Upstream sources:** `/api/security/summary`, `security_checks`, `secret_inventory` tables, OpenClaw gateway status probes.

---

### 2.7 Model & Provider Resilience

**Purpose:** Surface model/provider routing health so the end-user can see *at a glance* whether the fleet is single-provider-dependent, fallback-armed, or currently degraded.

**Primary question:** *If Anthropic (or MiniMax, or whoever) has an outage right now, what breaks?*

**Page content:**
- **Active routes table** — for each agent role, current primary provider, current model id, current fallback chain.
- **Provider status strip** — per provider (Anthropic, MiniMax, etc.): `UP` / `DEGRADED` / `DOWN`, source (provider status page probe or gateway error-rate).
- **Fallback preview** — "If primary fails, route X will switch to Y" — a dry-run visualisation, *not* a trigger.
- **Incident log** — timeline of provider incidents affecting GateForge in the last 30 days, with impact (`agents affected`, `tasks delayed`).
- **Routing config drift** — compares actual runtime route against declared config in `openclaw.json`; flags drift.

**Upstream sources:** `/api/models/routes`, `model_routes`, `provider_status`, `incidents` tables, OpenClaw gateway inspection.

---

### 2.8 Healthcare Compliance / Readiness Overlay

**Purpose:** An opt-in overlay that reframes existing signals against HIPAA / HITRUST control families, for healthcare and regulated-industry customers. It does not add new pipelines; it re-indexes what's already collected.

**Primary question:** *Am I ready to show a healthcare auditor, today?*

**Page content:**
- **Overlay toggle** — persistent setting. When on, Mission Control tiles, Security & Secrets, Audit & Management Reports, and Blueprint Governance each show an HC badge.
- **Control matrix** — rows are control ids (e.g., HIPAA §164.312(a)(1) Access Control, HITRUST 01.a), columns are `Status` (`COMPLIANT|GAP|UNKNOWN`), `Evidence` (link to audit event or artefact), `Owner` (role), `Last verified`.
- **Evidence bundler (read-only)** — assembles the current evidence set into a downloadable zip (PDF + JSON). v1: manual bundler button; no scheduled export.
- **Gap list** — controls currently `GAP` or `UNKNOWN`, ranked by severity.
- **BAA / vendor list** — static, editable-in-config list of subprocessors with BAA status.

**Upstream sources:** `/api/compliance/healthcare`, `compliance_controls`, `audit_events`, `report_exports` tables; Blueprint `compliance/` folder if present.

---

### 2.9 Setup & Installer Dashboard

**Purpose:** Prove the environment is correctly provisioned. Without this, half the other modules' green signals could be illusory.

**Primary question:** *Is GateForge set up correctly on every VM?*

**Page content:**
- **Installer checklist** — per VM: install script ran, version, last run timestamp, exit code, checksum of `openclaw.json`, Tailscale up, gateway reachable.
- **Communication test matrix** — results of the `test-communication` suite: Architect→spoke reachability, spoke→Architect notification round-trip, HTTPS + Tailscale MagicDNS resolution, hook auth, agent auth.
- **Config drift** — diff between declared `openclaw.json` (Blueprint or config repo) and what the gateway reports live.
- **Network topology** — Tailscale VPN graph (VM-1 … VM-5, US VM), latency, packet loss.
- **Remediation hints** — textual only; no "run installer" button in v1.

**Upstream sources:** `/api/setup/checks`, `setup_checks` table, `test-communication` output, OpenClaw gateway `/status`.

---

### 2.10 Audit & Management Reports

**Purpose:** The evidence surface. Everything the portal observes is an audit event; reports are curated rollups.

**Primary question:** *Can I show a stakeholder / auditor what happened, and when?*

**Page content:**
- **Audit Event Feed** — append-only, filterable (`actor`, `module`, `event_type`, `project`, time range). Every state change the portal surfaces produces an `audit_events` row.
- **Report library** — pre-built, read-only reports:
  - *Release Readiness Report* — current iteration, gate status, coverage, open blockers, DLQ depth, security findings.
  - *Weekly Fleet Health Report* — uptime, notification delivery rate, agent cost, incidents.
  - *Compliance Evidence Report* — filtered to healthcare overlay when enabled.
  - *Incident Postmortem Template* — pre-filled from `incidents` + `audit_events`.
- **Export** — PDF / JSON / CSV. File hashes recorded in `report_exports`.
- **Activity feed & full audit trail** — preserves existing feature 5.7.

**Upstream sources:** `/api/reports/release-readiness`, `audit_events`, `report_exports` tables.

---

### 2.11 Future RBAC & Multi-project

**Purpose:** Placeholder, deliberately surfaced so that every v1 decision is made with these in mind.

**What it anticipates:**
- **RBAC** — role-based access control. v1 assumes a single CTO/Project-Lead user. v2 anticipates *viewer*, *operator*, *approver*, *auditor* roles with least-privilege access per module. All write-actions deferred to §8 are gated on this landing.
- **Multi-project** — every data-model table (§5) already carries `project_id` so that a second project can be added without migration. UI exposes a project switcher in v2. v1 hides it when only one project exists.
- **Tenant isolation** — data files, secret inventories, and audit trails partitioned per project.

This module renders a short read-only explainer in v1 so stakeholders know the plan — no functionality.

---

## 3. Backlog — ADM-xxx IDs

P0 = must ship in v1.0 (Phase 1–2). P1 = v1.5 (Phase 3–4). P2 = v2.0+ (Phase 5 or later).

IDs are additive. Where a feature already exists in `…-EXTENDED-FEATURES.md`, the existing feature letter/number is shown in the "Maps to" column.

### P0 — Must (v1 Control Tower MVP)

| ID | Title | Module | Maps to |
|----|-------|--------|---------|
| ADM-001 | Mission Control landing page | 2.1 | (new composition) |
| ADM-002 | Agent Fleet card grid with heartbeat + stall banner | 2.2 | A (3.1–3.6) |
| ADM-003 | Notification Center priority feed | 2.3 | E (9.1–9.5) |
| ADM-004 | Notification Delivery Tracker | 2.3 | G (Notification Delivery Tracker) |
| ADM-005 | Dead-letter Queue table + detail drawer | 2.4 | (new — formalises existing DLQ file) |
| ADM-006 | Blueprint Governance — required-doc checklist + gate board | 2.5 | F (5.1–5.5) |
| ADM-007 | Security & Secrets — findings board + secret inventory (presence only) | 2.6 | G (Secrets & Token Inventory) |
| ADM-008 | Setup & Installer Dashboard — installer checklist + comms tests | 2.9 | G (Install & Setup Dashboard, Comms Test Viewer) |
| ADM-009 | Audit Event Feed (append-only) | 2.10 | F (5.7 Activity Feed & Audit Log) |
| ADM-010 | Release Readiness Report (v1, read-only) | 2.10 | (new) |
| ADM-011 | SSE event stream for Mission Control | cross-cutting | (existing SSE infra) |
| ADM-012 | Read-only v1 guardrails — no state-changing endpoints | cross-cutting | §8 |

### P1 — Should (v1.5)

| ID | Title | Module | Maps to |
|----|-------|--------|---------|
| ADM-101 | Model & Provider Resilience — routes table + provider status | 2.7 | (new) |
| ADM-102 | Provider incident log (30-day) | 2.7 | (new) |
| ADM-103 | Routing config drift detector | 2.7 | G (OpenClaw Config Viewer) |
| ADM-104 | Blueprint traceability link viewer | 2.5 | (new, extends 5.x) |
| ADM-105 | Blueprint artefact viewer with commit links | 2.5 | (new, extends 5.x) |
| ADM-106 | Security — hook & agent auth health probes | 2.6 | (new) |
| ADM-107 | Secret rotation tracker | 2.6 | G (Secrets & Token Inventory) |
| ADM-108 | Setup — Tailscale topology visualisation | 2.9 | G (Network Topology & Health Monitor) |
| ADM-109 | Setup — config drift diff (`openclaw.json` live vs declared) | 2.9 | G (OpenClaw Config Viewer) |
| ADM-110 | Weekly Fleet Health Report | 2.10 | (new) |
| ADM-111 | Report export (PDF/JSON/CSV) with hashing | 2.10 | (new) |
| ADM-112 | Agent Fleet — per-agent detail drawer wiring to Cost Tracker | 2.2 | A3 Cost Tracker |
| ADM-113 | DLQ age-bucket highlighting + CSV export | 2.4 | (extends ADM-005) |
| ADM-114 | Webhook & External Alerts — read-only config viewer | cross-cutting | F (Webhook & External Alerts, viewer only in v1.5) |

### P2 — Could (v2.0+)

| ID | Title | Module | Maps to |
|----|-------|--------|---------|
| ADM-201 | Healthcare Compliance / Readiness Overlay — toggle + control matrix | 2.8 | (new) |
| ADM-202 | Healthcare evidence bundler (read-only export) | 2.8 | (new) |
| ADM-203 | BAA / subprocessor list (config-driven) | 2.8 | (new) |
| ADM-204 | RBAC — viewer / operator / approver / auditor roles | 2.11 / cross-cutting | (new) |
| ADM-205 | Multi-project switcher + per-project data partitioning | 2.11 / cross-cutting | (new, uses existing `projectId`) |
| ADM-206 | Controlled write actions — DLQ replay, secret rotate, provider failover (gated on RBAC + audit) | cross-cutting | §8 |
| ADM-207 | Incident postmortem report generator | 2.10 | (new) |
| ADM-208 | Agent Decision Graph | 2.2 | A1 |
| ADM-209 | Agent Session Replay | 2.2 | A2 |
| ADM-210 | Root Cause Analyser | 2.10 / cross-cutting | E (Root Cause Analyser) |
| ADM-211 | SLO Forecasting & Budget Projection | 2.10 | D (SLO Forecasting) |

---

## 4. Acceptance Criteria (Given / When / Then) — Key P0 Features

Acceptance criteria are written for the operator (end-user) interacting with the portal browser. Data is assumed to be populated by the existing ingestion pipelines (gateway traces, notification relay, Blueprint git read-through).

### ADM-001 — Mission Control

> **Given** the portal is open at `/` and all upstream sources are reachable,
> **When** the landing page loads,
> **Then** the top banner renders `HEALTHY` / `DEGRADED` / `CRITICAL` within 2 s and all six status tiles render with current counts within 5 s.

> **Given** any upstream source is unreachable,
> **When** the landing page loads,
> **Then** the affected tile renders in a `UNKNOWN` (grey) state with a tooltip showing the failing source and last-known-good timestamp — **not** a misleading green.

> **Given** a notification with priority `CRITICAL` arrives on the SSE stream,
> **When** the stream receives it,
> **Then** the live activity rail prepends the item within 2 s and the Notification Center tile increments its 24h count within the next refresh cycle.

### ADM-002 — Agent Fleet stall banner

> **Given** an agent's last heartbeat is older than `STALL_THRESHOLD_S` (default 120 s),
> **When** the Agent Fleet page is open,
> **Then** a red banner displays `{agent_id} on {vm} has not reported for {age}` and the agent's card shows a `STALLED` pill.
>
> **And** no "restart" button is rendered (v1 guardrail §8).

### ADM-003 / ADM-004 — Notification Delivery Tracker

> **Given** a notification is sent from a spoke VM,
> **When** it is received at the Architect inbox relay,
> **Then** its row in the Notification Center shows `DELIVERED`, the sent→received latency, and zero retries.

> **Given** a notification has exhausted its retry budget,
> **When** the retry scheduler gives up,
> **Then** the row is updated to `DEAD_LETTER`, its payload is written to `dead_letters`, and it appears in the Dead-letter Queue (ADM-005) within 5 s.

### ADM-005 — Dead-letter Queue

> **Given** one or more items exist in the DLQ,
> **When** the DLQ page is opened,
> **Then** each row shows id, source VM, task id, priority, first-failure timestamp, retry count, and final error; items older than 24 h are visually flagged.

> **Given** the operator clicks an item,
> **When** the detail drawer opens,
> **Then** the drawer shows the original payload, each retry attempt with gateway response, and *no* replay/retry button (v1 guardrail).

### ADM-006 — Blueprint Governance

> **Given** the current iteration requires documents `{PRD, ADR, QA-plan, Runbook}`,
> **When** the Blueprint Governance page is opened,
> **Then** each required doc is listed with state `PRESENT` / `MISSING` / `STALE` (stale = > 7 days since iteration start without updates) and a direct link to its commit.

> **Given** a quality gate has a `Fail` decision for the latest commit,
> **When** the gate board is rendered,
> **Then** the gate row shows `FAIL`, the evaluator agent id, the commit SHA, and the reason string surfaced from the gate output.

### ADM-007 — Security & Secrets (presence only)

> **Given** secret file `/etc/gateforge/hook-token` is expected on VM-2,
> **When** the Security & Secrets page is opened,
> **Then** the row shows `PRESENT`, file mode, size, owner, and last-modified timestamp — **never** the secret value.

> **Given** `/etc/gateforge/hook-token` is missing on VM-2,
> **When** the Security & Secrets page is opened,
> **Then** a `CRITICAL` finding is displayed with remediation hint text, and no action button is rendered.

### ADM-008 — Setup & Installer Dashboard

> **Given** the installer ran on VM-3 at timestamp T,
> **When** the Setup page is opened,
> **Then** VM-3's row shows `INSTALLED`, the installer version, T, exit code 0, and the `openclaw.json` checksum.

> **Given** the `test-communication` suite last ran 10 minutes ago with 1 failure (spoke→Architect notification round-trip on VM-4),
> **When** the Setup page is opened,
> **Then** the matrix shows a red cell for VM-4 with the failing check name and the last-success timestamp.

### ADM-009 — Audit Event Feed

> **Given** a gate transitions from `Pass` to `Fail`,
> **When** the portal observes the transition,
> **Then** a new `audit_events` row is written with `{event_type: gate.decision_changed, actor: <evaluator agent id>, payload: {from:Pass,to:Fail,commit:<sha>}}` and appears in the feed within 2 s.

> **Given** an operator attempts a state-changing action in v1,
> **When** the request is sent,
> **Then** the server returns HTTP 405 with `{error: "read_only_v1"}` and an `audit_events` row records the rejected attempt.

### ADM-010 — Release Readiness Report

> **Given** the current iteration has open blockers, a failing QA gate, and non-zero DLQ depth,
> **When** the Release Readiness Report is generated,
> **Then** the report status is `NOT READY` and each failing condition is enumerated with a direct link to the relevant module.

> **Given** all gates pass, blockers are zero, DLQ depth is zero, and no open CRITICAL security findings exist,
> **When** the report is generated,
> **Then** the status is `READY`, a hash of the generated artefact is written to `report_exports`, and a download link is returned.

### ADM-011 — SSE stream

> **Given** the operator has Mission Control open,
> **When** the server emits any event on the stream,
> **Then** the event is delivered to the browser within 2 s over a single long-lived SSE connection, and a reconnect-with-backoff strategy recovers cleanly within 10 s if the connection drops.

### ADM-012 — Read-only v1 guardrails

> **Given** the portal is running in v1,
> **When** any HTTP method other than `GET`, `HEAD`, or `OPTIONS` is issued against any `/api/*` route,
> **Then** the server returns HTTP 405, no state is mutated, and the attempt is recorded in `audit_events`.

---

## 5. Suggested SQLite Data Model

SQLite is chosen for v1 because the portal is single-tenant, single-node, read-heavy, and the datasets are small (thousands of events per day, not millions). Every table carries a `project_id` column so multi-project (ADM-205) is a config change, not a migration.

> **Note on write model:** all portal-owned tables are written only by the portal's ingestion workers (pull/poll from gateway, git, file system). Nothing in this schema represents commands *into* agents — consistent with the read-only v1 guardrail.

```sql
-- Projects — single row in v1; multi-row in v2.
CREATE TABLE projects (
  project_id       TEXT PRIMARY KEY,
  name             TEXT NOT NULL,
  created_at       INTEGER NOT NULL,           -- unix epoch ms
  settings_json    TEXT NOT NULL DEFAULT '{}'
);

-- Agents — static inventory, refreshed from openclaw.json reads.
CREATE TABLE agents (
  agent_id         TEXT NOT NULL,
  project_id       TEXT NOT NULL REFERENCES projects(project_id),
  vm               TEXT NOT NULL,              -- 'vm-1' .. 'vm-5' or hostname
  role             TEXT NOT NULL,              -- architect|designer|dev|qc|operator
  model_id         TEXT,
  declared_route   TEXT,                       -- primary provider/model per config
  created_at       INTEGER NOT NULL,
  PRIMARY KEY (project_id, agent_id)
);

-- Heartbeats — append-only, partitioned by day in practice via retention job.
CREATE TABLE heartbeats (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id       TEXT NOT NULL,
  agent_id         TEXT NOT NULL,
  observed_at      INTEGER NOT NULL,
  status           TEXT NOT NULL,              -- active|idle|stalled|silent
  last_tool        TEXT,
  tokens_in        INTEGER,
  tokens_out       INTEGER
);
CREATE INDEX idx_heartbeats_agent_time ON heartbeats(project_id, agent_id, observed_at DESC);

-- Configs — snapshot of openclaw.json and related config per VM over time.
CREATE TABLE configs (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id       TEXT NOT NULL,
  vm               TEXT NOT NULL,
  captured_at      INTEGER NOT NULL,
  sha256           TEXT NOT NULL,
  body_json        TEXT NOT NULL
);

-- Notifications — one row per notification observed at the Architect relay.
CREATE TABLE notifications (
  notification_id  TEXT PRIMARY KEY,
  project_id       TEXT NOT NULL,
  task_id          TEXT,
  source_vm        TEXT NOT NULL,
  source_role      TEXT NOT NULL,
  priority         TEXT NOT NULL,              -- COMPLETED|BLOCKED|DISPUTE|CRITICAL|INFO
  summary          TEXT,
  sent_at          INTEGER NOT NULL,
  received_at      INTEGER,
  latency_ms       INTEGER,
  retries          INTEGER NOT NULL DEFAULT 0,
  outcome          TEXT NOT NULL,              -- DELIVERED|RETRYING|DEAD_LETTER
  trailers_valid   INTEGER NOT NULL            -- 0/1
);

-- Dead-letter queue — subset / link-out of notifications with outcome=DEAD_LETTER
-- plus any non-notification tasks that failed terminally.
CREATE TABLE dead_letters (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id          TEXT NOT NULL,
  ref_notification_id TEXT,                    -- nullable
  ref_task_id         TEXT,
  source_vm           TEXT,
  first_failed_at     INTEGER NOT NULL,
  last_attempt_at     INTEGER NOT NULL,
  retry_count         INTEGER NOT NULL,
  final_error         TEXT,
  payload_json        TEXT NOT NULL
);
CREATE INDEX idx_dlq_age ON dead_letters(project_id, first_failed_at);

-- Blueprint checks — one row per (iteration, gate).
CREATE TABLE blueprint_checks (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id       TEXT NOT NULL,
  iteration_id     TEXT NOT NULL,
  gate             TEXT NOT NULL,              -- design|code|qa|release
  decision         TEXT NOT NULL,              -- pass|fail|hold|rollback
  evaluator_agent  TEXT,
  commit_sha       TEXT,
  reason           TEXT,
  evaluated_at     INTEGER NOT NULL
);

-- Blueprint artefacts — test reports, coverage, runbooks.
CREATE TABLE blueprint_artifacts (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id       TEXT NOT NULL,
  iteration_id     TEXT,
  kind             TEXT NOT NULL,              -- prd|adr|runbook|coverage|qa-report|…
  path             TEXT NOT NULL,              -- path inside Blueprint repo
  commit_sha       TEXT,
  status           TEXT NOT NULL,              -- present|missing|stale
  captured_at      INTEGER NOT NULL
);

-- Traceability links — requirement → design → code → test → defect.
CREATE TABLE traceability_links (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id       TEXT NOT NULL,
  from_kind        TEXT NOT NULL,
  from_ref         TEXT NOT NULL,
  to_kind          TEXT NOT NULL,
  to_ref           TEXT NOT NULL,
  valid            INTEGER NOT NULL DEFAULT 1, -- 0 if chain broken
  observed_at      INTEGER NOT NULL
);

-- Security checks — findings surfaced by portal's probes.
CREATE TABLE security_checks (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id       TEXT NOT NULL,
  check_id         TEXT NOT NULL,              -- e.g., hook-auth.vm-3, secret-rotation.anthropic
  severity         TEXT NOT NULL,              -- critical|high|medium|low|info
  status           TEXT NOT NULL,              -- open|resolved|suppressed
  summary          TEXT NOT NULL,
  remediation_hint TEXT,
  first_seen_at    INTEGER NOT NULL,
  last_seen_at     INTEGER NOT NULL
);

-- Secret inventory — presence/metadata only, NEVER values.
CREATE TABLE secret_inventory (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id       TEXT NOT NULL,
  vm               TEXT NOT NULL,
  logical_name     TEXT NOT NULL,              -- e.g., 'hook-token', 'agent-secret'
  file_path        TEXT NOT NULL,
  present          INTEGER NOT NULL,           -- 0/1
  mode             TEXT,                       -- e.g., '0600'
  size_bytes       INTEGER,
  owner            TEXT,
  rotated_at       INTEGER,
  observed_at      INTEGER NOT NULL,
  UNIQUE (project_id, vm, logical_name, observed_at)
);

-- Model routes — active routing state per agent role.
CREATE TABLE model_routes (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id       TEXT NOT NULL,
  agent_role       TEXT NOT NULL,
  primary_provider TEXT NOT NULL,
  primary_model    TEXT NOT NULL,
  fallback_json    TEXT NOT NULL,              -- ordered array of {provider, model}
  drift            INTEGER NOT NULL DEFAULT 0, -- 1 if diverges from declared config
  observed_at      INTEGER NOT NULL
);

-- Provider status — periodic probe of each provider.
CREATE TABLE provider_status (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id       TEXT NOT NULL,
  provider         TEXT NOT NULL,
  status           TEXT NOT NULL,              -- up|degraded|down|unknown
  source           TEXT NOT NULL,              -- 'status-page' | 'gateway-error-rate'
  observed_at      INTEGER NOT NULL
);

-- Incidents — aggregated provider or fleet incidents.
CREATE TABLE incidents (
  incident_id      TEXT PRIMARY KEY,
  project_id       TEXT NOT NULL,
  kind             TEXT NOT NULL,              -- provider|fleet|network|security
  severity         TEXT NOT NULL,
  started_at       INTEGER NOT NULL,
  ended_at         INTEGER,
  summary          TEXT NOT NULL,
  impact_json      TEXT NOT NULL
);

-- Audit events — append-only, the spine of the evidence story.
CREATE TABLE audit_events (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id       TEXT NOT NULL,
  occurred_at      INTEGER NOT NULL,
  actor            TEXT NOT NULL,              -- agent id, 'portal', 'system'
  module           TEXT NOT NULL,              -- one of 2.1..2.11
  event_type       TEXT NOT NULL,
  payload_json     TEXT NOT NULL
);
CREATE INDEX idx_audit_time ON audit_events(project_id, occurred_at DESC);
CREATE INDEX idx_audit_module ON audit_events(project_id, module, occurred_at DESC);

-- Setup checks — installer + comms test results.
CREATE TABLE setup_checks (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id       TEXT NOT NULL,
  vm               TEXT NOT NULL,
  check_id         TEXT NOT NULL,              -- 'installer.ran', 'comms.architect->vm3', …
  status           TEXT NOT NULL,              -- pass|fail|unknown
  detail           TEXT,
  observed_at      INTEGER NOT NULL
);

-- Compliance controls — healthcare overlay.
CREATE TABLE compliance_controls (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id       TEXT NOT NULL,
  framework        TEXT NOT NULL,              -- 'HIPAA' | 'HITRUST' | 'SOC2' …
  control_id       TEXT NOT NULL,              -- e.g., '164.312(a)(1)'
  status           TEXT NOT NULL,              -- compliant|gap|unknown
  evidence_ref     TEXT,                       -- link to audit_events or artefact
  owner_role       TEXT,
  last_verified_at INTEGER,
  UNIQUE (project_id, framework, control_id)
);

-- Report exports — hash-ledger of generated reports.
CREATE TABLE report_exports (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id       TEXT NOT NULL,
  report_kind      TEXT NOT NULL,              -- 'release-readiness'|'weekly-fleet'|'compliance-evidence'|'incident-postmortem'
  generated_at     INTEGER NOT NULL,
  format           TEXT NOT NULL,              -- 'pdf'|'json'|'csv'
  sha256           TEXT NOT NULL,
  path             TEXT NOT NULL
);
```

### Data model invariants

- Every table carries `project_id` — **no** cross-project joins.
- Append-only tables (`heartbeats`, `audit_events`, `report_exports`) have retention jobs configured via `projects.settings_json`, not manual deletions.
- `secret_inventory` **must not** contain secret values. Static lint in CI verifies this by schema review.
- `audit_events.payload_json` is structured; schemas for each `event_type` live alongside the ingestion workers.

---

## 6. Suggested API Outline

All v1 endpoints are `GET` unless noted. All endpoints accept an optional `?project_id=` query parameter and default to the single active project in v1.

| Method | Path | Purpose | Feeds |
|--------|------|---------|-------|
| GET | `/api/health/summary` | Aggregated status for Mission Control tiles | 2.1 |
| GET | `/api/agents` | Fleet list with heartbeat state, filters via query string | 2.2 |
| GET | `/api/agents/{agent_id}` | Per-agent detail (joins heartbeats, cost, routes) | 2.2 |
| GET | `/api/notifications` | Notification feed with delivery metadata | 2.3 |
| GET | `/api/notifications/{id}` | Single notification detail incl. retry attempts | 2.3 |
| GET | `/api/dead-letters` | DLQ list, filterable by age/priority | 2.4 |
| GET | `/api/dead-letters/{id}` | DLQ item detail (payload, retry history) | 2.4 |
| GET | `/api/blueprint/summary` | Required docs, gate board, artefact list, traceability summary | 2.5 |
| GET | `/api/security/summary` | Findings board + secret inventory summary | 2.6 |
| GET | `/api/models/routes` | Active routes, provider statuses, drift flags | 2.7 |
| GET | `/api/setup/checks` | Installer checklist, comms test matrix, topology snapshot | 2.9 |
| GET | `/api/compliance/healthcare` | HC overlay control matrix and gap list | 2.8 |
| GET | `/api/reports/release-readiness` | Current release-readiness report (JSON), generate-and-return | 2.10 |
| GET | `/api/events/stream` | **SSE** event stream for Mission Control & live activity rail | cross-cutting |

### Response conventions

- All list endpoints support `?limit=` (default 100, max 1000) and `?cursor=` for opaque pagination.
- All responses include `meta.observed_at` (epoch ms) so the UI can show data freshness.
- Any endpoint whose upstream source is unreachable returns HTTP 200 with `meta.degraded=true` and `meta.reason=<source name>` rather than 5xx — the UI renders grey `UNKNOWN` rather than a noisy error.
- `/api/events/stream` emits newline-delimited JSON events with `event: <type>` and `data: <json>`; reconnect is the client's responsibility and the server honours `Last-Event-ID`.
- **v1: no POST/PUT/PATCH/DELETE endpoints.** Any such request returns HTTP 405; the attempt is recorded in `audit_events` (ADM-012).

### Auth

- v1: single-user session cookie issued after reverse-proxy SSO (or local bearer token if self-hosted without SSO).
- v2 (ADM-204): RBAC enforced at middleware level — per-route role matrix keyed off module.

---

## 7. Implementation Roadmap

Five phases. Each phase has an exit bar and a demonstrable outcome. No phase blocks the next on anything other than its own exit bar.

### Phase 1 — Trust Visibility  *(ship v1.0 MVP)*

**Goal:** The operator can open the portal and trust what it shows about fleet health and notifications.

**Ships:** ADM-001 Mission Control, ADM-002 Agent Fleet, ADM-003 Notification Center, ADM-004 Delivery Tracker, ADM-005 Dead-letter Queue, ADM-009 Audit Feed, ADM-011 SSE stream, ADM-012 v1 guardrails.

**Exit bar:**
- Mission Control loads and shows live state from real VMs within 5 s.
- Every required-trailer notification observed at the Architect relay produces a row in `notifications` within 2 s.
- DLQ depth = 0 in a healthy fleet; adding a deliberately failing notification reaches DLQ within its retry budget + 5 s.
- Attempting any non-GET request returns 405 and appears in `audit_events`.

### Phase 2 — Blueprint Governance  *(still v1.0)*

**Goal:** The Blueprint is observed end-to-end; gate failures and missing artefacts are visible without the operator reading git.

**Ships:** ADM-006 Blueprint Governance, ADM-008 Setup & Installer Dashboard, ADM-010 Release Readiness Report.

**Exit bar:**
- The `READY` / `NOT READY` verdict of the Release Readiness Report matches what a human reviewer would conclude from git + gate logs on five sample iterations.
- Setup page accurately reflects the result of `test-communication` within 60 s of its run.

### Phase 3 — Security Posture  *(v1.5)*

**Goal:** Operational security of the GateForge control plane is visible and actionable (as hints, not actions).

**Ships:** ADM-007 Security & Secrets, ADM-101–ADM-103 Model & Provider Resilience, ADM-106 Hook/Agent auth health, ADM-107 Secret rotation, ADM-108 Topology, ADM-109 Config drift, ADM-110 Weekly Fleet Health Report, ADM-111 Report export, ADM-113 DLQ CSV export, ADM-114 Webhook config viewer.

**Exit bar:**
- Zero instances of secret values appearing in any response body (automated test).
- Injected provider outage (via stubbed status probe) flips provider status tile to `DEGRADED`/`DOWN` within 60 s.
- Rotating a secret file updates `secret_inventory.rotated_at` within one ingestion cycle (≤ 5 min).

### Phase 4 — Healthcare Overlay  *(v2.0)*

**Goal:** Healthcare and regulated customers can toggle an overlay that re-indexes existing signals against HIPAA / HITRUST controls and export an evidence bundle.

**Ships:** ADM-201 Healthcare overlay + control matrix, ADM-202 Evidence bundler, ADM-203 BAA / subprocessor list.

**Exit bar:**
- A curated sample of 10 controls correctly resolve to `COMPLIANT` / `GAP` based on deterministic rules over `audit_events`, `secret_inventory`, `blueprint_artifacts`.
- Evidence bundle is reproducible (same inputs → same sha256).

### Phase 5 — Controlled Actions (after RBAC & Audit)  *(v2.0+)*

**Goal:** Carefully selected write actions become available to authorised roles — but only after RBAC and audit are in place.

**Ships:** ADM-204 RBAC, ADM-205 Multi-project, ADM-206 Controlled write actions (DLQ replay, secret rotation trigger, provider manual failover), ADM-207 Incident postmortem generator, ADM-208–ADM-211 advanced observability features.

**Exit bar:**
- No write action is exposed to a role without `approver` or higher.
- Every write action produces a paired `audit_events` row *and* a notification to the Architect before executing.
- A "break glass" path exists for emergency read-only access, logged with elevated severity.

**Cross-phase invariant:** until Phase 5 exits, the portal stays read-only.

---

## 8. Read-Only v1 Guardrails and Future Write-Action Cautions

### 8.1 Read-only by construction (v1)

- **No non-GET HTTP verbs** in `/api/*` — enforced at middleware; violations return 405 and append to `audit_events` (ADM-012).
- **No buttons that imply action** in the UI v1 — DLQ detail drawer has no "Replay", Security findings have no "Rotate now", Agent Fleet cards have no "Restart". Textual remediation hints only.
- **No outbound network calls on user interaction** — every module reads from local SQLite and the portal's ingestion workers; it does not prompt an agent, call a gateway write endpoint, or trigger a pipeline on click.
- **Schema does not model intents** — there is no `commands` table. Nothing in the portal's data model represents an instruction to an agent.
- **Telegram → Architect remains the only human→pipeline channel.** The portal explicitly links out to Telegram where an operator *would* want to act.

### 8.2 Why this is strict

GateForge agents operate autonomously and in parallel. A premature "Cancel task" button in the portal, without RBAC, audit, and Architect coordination, could corrupt the SDLC state (e.g., cancelling a task mid-commit, orphaning a branch, or racing the Architect's own dispatch). Read-only v1 protects the determinism of the SDLC loop while still delivering the full trust-layer value.

### 8.3 Cautions for future write actions (Phase 5)

When write actions land, each must:

1. **Be gated by RBAC** — minimum role `approver`; no operation grants its own permission.
2. **Be preceded by a confirmation modal** showing the precise effect, the affected agent/task/iteration, and a free-text "reason" field (required, stored in `audit_events.payload_json`).
3. **Produce a paired audit event** *before* execution (`intent`) and *after* execution (`outcome`). If the outcome event is missing, the action is considered in-doubt.
4. **Notify the Architect** via the existing notification path with priority `CRITICAL` or `INFO` as appropriate. The Architect decides whether to surface to the human via Telegram.
5. **Respect rate limits** — e.g., at most one DLQ replay per (source VM, task id) per minute; secret rotations require a quiet-window acknowledgement.
6. **Be reversible or clearly marked irreversible.** DLQ replay is reversible (idempotent notification). Secret rotation is not; its modal must say so.
7. **Never bypass the Architect** for actions inside the SDLC loop. If the action touches a task state, it goes *to the Architect*, not past it.
8. **Be covered by integration tests** that assert both the happy path and the refused path (wrong role, missing reason, Architect down).

### 8.4 Explicit non-goals, even long-term

- **The portal will not become the SDLC orchestrator.** It will not own task dispatch, task prioritisation, or agent coordination. Those remain in the Architect.
- **The portal will not store secret values.** Ever. Presence metadata only.
- **The portal will not act as a code-review surface.** Code review happens in git; the portal links to it.

---

## 9. n8n — Integration Layer, Not SDLC Orchestrator

n8n is a useful tool for **edge integrations** around GateForge. It is **not** a fit for the core deterministic SDLC loop, and v1 must be explicit about that boundary.

### 9.1 Where n8n sits (initially)

n8n lives **outside** the hub-and-spoke loop. It connects non-GateForge systems to GateForge through well-defined seams:

| Seam | n8n role | Direction |
|------|----------|-----------|
| **Intake** | Receive requirement tickets from Jira / Linear / email, normalise, forward to the Architect via Telegram webhook. | inbound |
| **Approvals** | Route human approval requests (e.g., a CTO sign-off gate) to Slack / email / SMS; collect the response; relay back. | bidirectional, human-mediated |
| **Notifications** | Fan out notifications from the Architect relay to secondary channels (PagerDuty, Slack, email digests) without adding coupling in GateForge itself. | outbound |
| **Reporting** | Schedule pulls of the portal's Release Readiness / Weekly Fleet Health reports and post them to stakeholder channels. | outbound |

### 9.2 Why n8n is *not* the SDLC orchestrator

- **Determinism.** GateForge's SDLC loop is deterministic, typed, and owned by the Architect. Adding an off-VM orchestrator introduces non-deterministic retry/branching behaviour that will fight the Architect.
- **Audit surface.** Every SDLC step already produces `audit_events`. n8n's execution history is a separate, weaker audit surface; splitting the audit story weakens both.
- **Failure modes.** If n8n is down, intake/approval/notification *edges* degrade — the SDLC loop keeps running. If n8n were the orchestrator, an n8n outage would stop the pipeline.
- **Security posture.** n8n credentials would need access to hook tokens and agent secrets — an unacceptable blast radius. Keeping n8n to edges means it only holds non-SDLC credentials (Slack, email, Jira).

### 9.3 What this means for the portal

- Setup & Installer Dashboard (§2.9) treats n8n as **optional** — a green n8n integration is not a precondition for a healthy GateForge fleet.
- Notification Center (§2.3) shows the *primary* delivery path (spoke → Architect). If n8n fan-out is enabled, its delivery status is surfaced as a **secondary** column, clearly labelled, so an n8n outage cannot masquerade as a GateForge outage.
- Webhook & External Alerts config viewer (ADM-114) is the place where n8n (or any other integration platform) is declared, not a location where n8n executes anything on the portal's behalf.

### 9.4 Future re-evaluation

Nothing here precludes n8n (or similar) moving closer to the core later. But the reversal criteria should be: **deterministic** step replay, **audit parity** with `audit_events`, and **fail-closed** behaviour. Until those are demonstrably in place, n8n stays at the edges.

---

## Appendix — Cross-Reference to Existing Specs

| This document | Existing spec | Relationship |
|---------------|---------------|--------------|
| §2.1 Mission Control | `GATEFORGE-ADMIN-PORTAL.md` §16 Project Health Score | Mission Control is the full landing view; Project Health Score is one tile. |
| §2.2 Agent Fleet | `GATEFORGE-ADMIN-PORTAL.md` §3 Agent Observability; Extended A1–A4 | Re-groups; no feature removed. |
| §2.3 Notification Center | `GATEFORGE-ADMIN-PORTAL.md` §9; Extended G (Notification Delivery Tracker) | Merges the two into one operational module. |
| §2.4 Dead-letter Queue | Extended (`…-IMPLEMENTATION.md`) DLQ references | Formalises as a first-class module. |
| §2.5 Blueprint Governance | `GATEFORGE-ADMIN-PORTAL.md` §5; Extended 5.6–5.7 | Governance frame over the explorer. |
| §2.6 Security & Secrets | Extended G (Secrets & Token Inventory) | Elevates to module; adds rotation & auth health. |
| §2.7 Model & Provider Resilience | *new module* | Reads from existing OpenClaw gateway data already captured. |
| §2.8 Healthcare Overlay | *new module* | Re-indexes existing signals; no new ingestion. |
| §2.9 Setup & Installer Dashboard | Extended G (Install & Setup Dashboard, Comms Test, Topology, OpenClaw Config) | Merges the four G-tiles into one module. |
| §2.10 Audit & Management Reports | Extended 5.7 Activity Feed & Audit Log | Adds report library on top of existing audit feed. |
| §2.11 Future RBAC & Multi-project | `README.md` §multi-project hints | Makes implicit plan explicit. |

**No existing feature in the 30-feature or 36-feature catalogue is removed or renamed by this document.**

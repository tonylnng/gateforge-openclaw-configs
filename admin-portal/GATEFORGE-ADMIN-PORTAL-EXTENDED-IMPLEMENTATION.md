# GateForge Admin Portal — Extended Implementation Guide

**Document Status:** Implementation-Ready  
**Version:** 3.0  
**Author:** GateForge Agent Team  
**Created:** 2026-04-10  
**Updated:** 2026-04-10  
**References:**
- Main Implementation Guide: `GATEFORGE-ADMIN-PORTAL-IMPLEMENTATION.md` (v2.5, 6707 lines)
- Category G Feature Specification: `GATEFORGE-ADMIN-PORTAL-EXTENDED-FEATURES.md`
- Infrastructure Summary: `new-infra-summary.md`

---

## Table of Contents

1. [Overview](#1-overview)
2. [Environment Variables](#2-environment-variables)
3. [Type Definitions](#3-type-definitions)
4. [Backend Implementation](#4-backend-implementation)
   - [4.1 G1 — Network Topology & Health Monitor](#41-g1--network-topology--health-monitor)
   - [4.2 G2 — Notification Delivery Tracker](#42-g2--notification-delivery-tracker)
   - [4.3 G3 — Installation & Setup Dashboard](#43-g3--installation--setup-dashboard)
   - [4.4 G4 — Communication Test Results Viewer](#44-g4--communication-test-results-viewer)
   - [4.5 G5 — Secrets & Token Inventory](#45-g5--secrets--token-inventory)
   - [4.6 G6 — OpenClaw Configuration Viewer](#46-g6--openclaw-configuration-viewer)
   - [4.7 Updated `index.ts` Route Registration](#47-updated-indexts-route-registration)
5. [Frontend Implementation](#5-frontend-implementation)
   - [5.1 G1 — Network Topology & Health Monitor](#51-g1--network-topology--health-monitor)
   - [5.2 G2 — Notification Delivery Tracker](#52-g2--notification-delivery-tracker)
   - [5.3 G3 — Installation & Setup Dashboard](#53-g3--installation--setup-dashboard)
   - [5.4 G4 — Communication Test Results Viewer](#54-g4--communication-test-results-viewer)
   - [5.5 G5 — Secrets & Token Inventory](#55-g5--secrets--token-inventory)
   - [5.6 G6 — OpenClaw Configuration Viewer](#56-g6--openclaw-configuration-viewer)
6. [Task Breakdown](#6-task-breakdown)
7. [Integration Notes](#7-integration-notes)
8. [Testing Strategy](#8-testing-strategy)

---

## 1. Overview

This document extends the main GateForge Admin Portal Implementation Guide (v2.5) with full production-quality TypeScript code for the 6 Category G **Infrastructure & Connectivity** features (G1–G6). These features provide read-only monitoring and visibility into the Tailscale VPN network, host-side notification relay, per-VM installation state, end-to-end communication test results, secrets compliance, and OpenClaw gateway configurations.

**All features in this document are strictly READ-ONLY.** No endpoint in this guide writes, modifies, triggers, or executes anything on any VM. The portal observes and displays; it never controls.

### New Files Added

**Backend (`backend/src/`):**
```
services/networkProbe.ts          ← G1: Periodic Tailscale health probes
services/notificationMonitor.ts   ← G2: Parse gf-notify journal output
services/setupValidator.ts        ← G3: SSH check install script status
services/testRunParser.ts         ← G4: Parse test-communication.sh logs
services/secretsInventory.ts      ← G5: SSH stat metadata (never contents)
services/openclawConfigFetcher.ts ← G6: Read openclaw.json from each VM

routes/network.ts                 ← G1: topology, vm-status, latency-history
routes/notifications-delivery.ts  ← G2: log, stats, dead-letters
routes/setup-status.ts            ← G3: vm-setup-status, drift-detection, history
routes/tests.ts                   ← G4: latest-run, history, agent-results
routes/secrets.ts                 ← G5: inventory, compliance, alerts
routes/openclaw-config.ts         ← G6: config-per-vm, diff, validation

types/infrastructure.ts           ← All Category G TypeScript types
```

**Frontend (`frontend/src/`):**
```
app/(portal)/infrastructure/network/page.tsx
app/(portal)/infrastructure/notifications/page.tsx
app/(portal)/infrastructure/setup/page.tsx
app/(portal)/infrastructure/tests/page.tsx
app/(portal)/infrastructure/secrets/page.tsx
app/(portal)/infrastructure/configs/page.tsx

components/infrastructure/
  network/    NetworkTopologyDiagram.tsx, VMHealthCard.tsx, LatencyChart.tsx
  notify/     NotificationTimeline.tsx, DeadLetterQueueTable.tsx, TrailerComplianceBadge.tsx
  setup/      SetupChecklist.tsx, ConfigDriftBanner.tsx, SetupHistoryTable.tsx
  tests/      TestGateMatrix.tsx, AgentTestHistoryChart.tsx, FlakyAgentBanner.tsx
  secrets/    SecretsComplianceMatrix.tsx, SecretsAlertList.tsx, TokenRotationReminder.tsx
  configs/    OpenClawConfigViewer.tsx, ConfigDiffPanel.tsx, ConfigValidationBadge.tsx

hooks/
  useNetworkTopology.ts
  useNotificationDelivery.ts
  useSetupStatus.ts
  useTestResults.ts
  useSecretsInventory.ts
  useOpenClawConfigs.ts
```

### New Dependencies

```bash
# Backend
npm install node-ssh @types/node-ssh        # SSH introspection for G3/G5
npm install node-fetch                      # Already installed — used by gatewayClient

# No new frontend dependencies required
# Recharts, React Query already present from main guide
```

---

## 2. Environment Variables

Add the following to `.env.example` (and your actual `.env`) after the existing `AGENT_POLL_INTERVAL` entry:

```bash
# ─── Category G: Infrastructure & Connectivity ────────────────────────────────

# G1: Network Topology & Health Monitor
# Interval (seconds) at which the backend probes each VM's /health endpoint
NETWORK_PROBE_INTERVAL=30
# Request timeout (ms) for each probe
NETWORK_PROBE_TIMEOUT_MS=5000
# How many latency datapoints to retain in memory per VM
NETWORK_LATENCY_HISTORY_SIZE=120

# G2: Notification Delivery Tracker
# Number of journal lines to tail from gf-notify-architect.service per poll
NOTIFY_JOURNAL_TAIL_LINES=500
# Dead-letter log file path on VM-1 (read via gateway API)
NOTIFY_DEADLETTER_PATH=/var/log/gf-notify-deadletter.log
# Poll interval (seconds) for refreshing the notification delivery monitor
NOTIFY_POLL_INTERVAL=15

# G3: Installation & Setup Dashboard
# SSH private key path used for read-only setup validation (same key as US VM or a dedicated infra key)
INFRA_SSH_KEY_PATH=/data/ssh-keys/infra_rsa
# SSH username on the GateForge VMs (usually the VM's local user)
INFRA_SSH_USER=gf
# Interval (seconds) between setup drift checks
SETUP_DRIFT_CHECK_INTERVAL=300
# Path to the install completion sentinel file on each VM
SETUP_SENTINEL_PATH=/opt/gateforge/.install-complete

# G4: Communication Test Results Viewer
# Directory on VM-1 (read via SSH) where test-communication.sh writes its output
TEST_LOG_DIR=/opt/gateforge/test-logs
# Max number of historical test runs to retain per agent
TEST_HISTORY_MAX_RUNS=50

# G5: Secrets & Token Inventory
# Stale token threshold (days): flag secret files not modified within this window
SECRETS_STALE_THRESHOLD_DAYS=90
# Poll interval (seconds) for refreshing the secrets inventory
SECRETS_POLL_INTERVAL=300

# G6: OpenClaw Configuration Viewer
# Path to openclaw.json on each VM (same path on all VMs)
OPENCLAW_CONFIG_PATH=/opt/openclaw/openclaw.json
# Poll interval (seconds) for refreshing configs
OPENCLAW_POLL_INTERVAL=120
```

### Updated `config.ts` Extension

Add the following fields to the `AppConfig` interface and `loadConfig()` function in `backend/src/config.ts`:

```typescript
// Additional fields for Category G infrastructure monitoring
export interface AppConfig {
  // ... (existing fields unchanged) ...

  // G1 Network Probe
  networkProbeInterval: number;
  networkProbeTimeoutMs: number;
  networkLatencyHistorySize: number;

  // G2 Notification Monitor
  notifyJournalTailLines: number;
  notifyDeadletterPath: string;
  notifyPollInterval: number;

  // G3 Setup Validator
  infraSshKeyPath: string;
  infraSshUser: string;
  setupDriftCheckInterval: number;
  setupSentinelPath: string;

  // G4 Test Run Parser
  testLogDir: string;
  testHistoryMaxRuns: number;

  // G5 Secrets Inventory
  secretsStaleDays: number;
  secretsPollInterval: number;

  // G6 OpenClaw Config Fetcher
  openclawConfigPath: string;
  openclawPollInterval: number;
}

// Inside loadConfig(), append:
networkProbeInterval:       parseInt(process.env.NETWORK_PROBE_INTERVAL       || '30',    10),
networkProbeTimeoutMs:      parseInt(process.env.NETWORK_PROBE_TIMEOUT_MS     || '5000',  10),
networkLatencyHistorySize:  parseInt(process.env.NETWORK_LATENCY_HISTORY_SIZE || '120',   10),
notifyJournalTailLines:     parseInt(process.env.NOTIFY_JOURNAL_TAIL_LINES    || '500',   10),
notifyDeadletterPath:       process.env.NOTIFY_DEADLETTER_PATH || '/var/log/gf-notify-deadletter.log',
notifyPollInterval:         parseInt(process.env.NOTIFY_POLL_INTERVAL         || '15',    10),
infraSshKeyPath:            process.env.INFRA_SSH_KEY_PATH || '/data/ssh-keys/infra_rsa',
infraSshUser:               process.env.INFRA_SSH_USER || 'gf',
setupDriftCheckInterval:    parseInt(process.env.SETUP_DRIFT_CHECK_INTERVAL   || '300',   10),
setupSentinelPath:          process.env.SETUP_SENTINEL_PATH || '/opt/gateforge/.install-complete',
testLogDir:                 process.env.TEST_LOG_DIR || '/opt/gateforge/test-logs',
testHistoryMaxRuns:         parseInt(process.env.TEST_HISTORY_MAX_RUNS        || '50',    10),
secretsStaleDays:           parseInt(process.env.SECRETS_STALE_THRESHOLD_DAYS || '90',    10),
secretsPollInterval:        parseInt(process.env.SECRETS_POLL_INTERVAL        || '300',   10),
openclawConfigPath:         process.env.OPENCLAW_CONFIG_PATH || '/opt/openclaw/openclaw.json',
openclawPollInterval:       parseInt(process.env.OPENCLAW_POLL_INTERVAL       || '120',   10),
```

---

## 3. Type Definitions

**File:** `backend/src/types/infrastructure.ts`  
**Also copy to:** `frontend/src/types/infrastructure.ts` (identical, shared)

```typescript
// ─── Category G: Infrastructure & Connectivity ────────────────────────────────
// All types in this file are READ-ONLY monitoring types.
// No mutation types are defined here by design.

// ─── G1: Network Topology & Health Monitor ────────────────────────────────────

/** Current health status of a single VM's OpenClaw gateway */
export type VMHealthStatus = 'healthy' | 'degraded' | 'unreachable' | 'unknown';

/** A single latency measurement at a point in time */
export interface LatencyPoint {
  /** ISO 8601 timestamp */
  timestamp: string;
  /** Round-trip latency in milliseconds; null if probe timed out */
  latencyMs: number | null;
  /** Whether the probe was successful */
  ok: boolean;
}

/** Health snapshot for a single GateForge VM */
export interface VMHealth {
  vmId: string;                          // 'vm-1' through 'vm-5'
  hostname: string;                      // 'tonic-architect' (without domain)
  fqdn: string;                          // 'tonic-architect.sailfish-bass.ts.net'
  tailscaleIp: string;                   // '100.73.38.28'
  role: string;                          // 'System Architect'
  status: VMHealthStatus;
  /** Latest probe latency in ms; null if unreachable */
  latencyMs: number | null;
  /** ISO 8601 timestamp of last successful probe */
  lastProbeAt: string;
  /** ISO 8601 timestamp of last successful response (may differ from probe if degraded) */
  lastSeenAt: string | null;
  /** OpenClaw gateway version string from /health endpoint */
  gatewayVersion?: string;
  /** Number of consecutive probe failures */
  consecutiveFailures: number;
  /** Recent latency history (up to NETWORK_LATENCY_HISTORY_SIZE points) */
  latencyHistory: LatencyPoint[];
}

/** Full topology snapshot of all 5 VMs with their inter-VM reachability */
export interface NetworkTopology {
  /** ISO 8601 timestamp when this snapshot was generated */
  capturedAt: string;
  vms: VMHealth[];
  /** Overall fleet health: 'all-healthy' | 'degraded' | 'partial' | 'down' */
  fleetStatus: 'all-healthy' | 'degraded' | 'partial' | 'down';
  /** VMs that are currently unreachable */
  unreachableVmIds: string[];
  /** Average latency across all reachable VMs */
  avgLatencyMs: number | null;
}

// ─── G2: Notification Delivery Tracker ────────────────────────────────────────

/** Priority levels as emitted by gf-notify-architect.sh */
export type NotificationPriority = 'COMPLETED' | 'BLOCKED' | 'DISPUTE' | 'CRITICAL' | 'INFO';

/** Delivery status of a single gf-notify HMAC hook call */
export type DeliveryStatus = 'delivered' | 'failed' | 'retrying' | 'dead-letter';

/**
 * A single notification delivery event as parsed from the
 * gf-notify-architect.service systemd journal.
 */
export interface NotificationEvent {
  /** Monotonic event ID derived from journal cursor */
  id: string;
  /** ISO 8601 timestamp from journal entry */
  timestamp: string;
  /** Source VM ID (parsed from GateForge-Source-VM trailer) */
  sourceVmId: string;
  /** Source role (parsed from GateForge-Source-Role trailer) */
  sourceRole: string;
  /** Task ID from GateForge-Task-Id trailer */
  taskId: string;
  priority: NotificationPriority;
  /** Human-readable summary from GateForge-Summary trailer */
  summary: string;
  /** HTTP status code returned by the Architect's /hooks/agent endpoint */
  httpStatus: number | null;
  deliveryStatus: DeliveryStatus;
  /** Round-trip delivery latency in ms */
  deliveryLatencyMs: number | null;
  /** Number of delivery attempts (1 = first try, >1 = retried) */
  attemptCount: number;
  /** Commit SHA that triggered this notification (if available) */
  commitSha?: string;
  /** Whether all 5 required trailers were present in the originating commit */
  trailersComplete: boolean;
  /** List of any missing trailer names */
  missingTrailers: string[];
}

/** Aggregated delivery statistics for a time window */
export interface NotificationDeliveryStats {
  period: '1h' | '6h' | '24h' | '7d';
  totalEvents: number;
  deliveredCount: number;
  failedCount: number;
  deadLetterCount: number;
  successRate: number;             // 0.0 – 1.0
  avgDeliveryLatencyMs: number | null;
  byPriority: Record<NotificationPriority, number>;
  bySourceVm: Record<string, number>;
  trailerComplianceRate: number;   // 0.0 – 1.0 — fraction of commits with all 5 trailers
}

/**
 * A dead-letter entry — a notification that could not be delivered after
 * all retry attempts and was written to the dead-letter log.
 */
export interface DeadLetterEntry {
  id: string;
  timestamp: string;
  sourceVmId: string;
  taskId: string;
  priority: NotificationPriority;
  summary: string;
  /** Number of delivery attempts before giving up */
  attemptCount: number;
  /** Last HTTP status code received (or null if connection refused) */
  lastHttpStatus: number | null;
  /** Last error message */
  lastError: string;
  /** Raw HMAC payload as logged (contains only metadata — no secrets) */
  payloadPreview: string;
}

/**
 * Trailer compliance status per VM — used by TrailerComplianceBadge.
 * Measures how well each VM's agents are following the commit trailer protocol.
 */
export interface TrailerCompliance {
  vmId: string;
  hostname: string;
  totalCommits: number;
  compliantCommits: number;        // All 5 trailers present
  missingTrailerBreakdown: Record<string, number>;  // trailer name → missing count
  complianceRate: number;          // 0.0 – 1.0
}

// ─── G3: Installation & Setup Dashboard ───────────────────────────────────────

/** Outcome of a single setup check on a VM */
export type SetupCheckStatus = 'pass' | 'fail' | 'warn' | 'unknown';

/** A single check within a VM's setup validation */
export interface SetupCheck {
  id: string;                      // e.g. 'sentinel-file', 'openclaw-config', 'ufw-active'
  name: string;                    // Human-readable check name
  description: string;             // What this check validates
  status: SetupCheckStatus;
  /** Detail message from the check (e.g. 'File found at /opt/gateforge/.install-complete') */
  detail: string;
  /** ISO 8601 timestamp of when this check was last run */
  checkedAt: string;
}

/** Full setup validation result for a single VM */
export interface VMSetupStatus {
  vmId: string;
  hostname: string;
  tailscaleIp: string;
  role: string;
  /** Whether SSH connectivity to this VM is available for introspection */
  sshReachable: boolean;
  /** ISO 8601 timestamp of last successful SSH check */
  lastCheckedAt: string;
  /** Whether the install-complete sentinel file is present */
  installComplete: boolean;
  /** Exit code of the last known setup script run (null if unknown) */
  lastSetupExitCode: number | null;
  /** ISO 8601 timestamp of the install sentinel file's mtime */
  installedAt: string | null;
  /** Overall pass rate: checks passing / total checks */
  checkPassRate: number;
  checks: SetupCheck[];
  /** Whether any expected config files are missing or have unexpected content */
  hasDrift: boolean;
}

/**
 * A configuration drift item — a file or setting that deviates from its
 * expected state since last validated setup.
 */
export interface ConfigDrift {
  vmId: string;
  hostname: string;
  /** Path of the drifted file */
  filePath: string;
  /** Type of drift detected */
  driftType: 'missing' | 'permissions-mismatch' | 'content-hash-changed' | 'unexpected-file';
  description: string;
  /** ISO 8601 timestamp when the drift was first detected */
  detectedAt: string;
  /** Expected state description (e.g. 'Expected mode 0600') */
  expected: string;
  /** Actual state description (e.g. 'Actual mode 0644') */
  actual: string;
}

/** Historical record of a setup validation run */
export interface SetupHistoryEntry {
  id: string;
  vmId: string;
  hostname: string;
  ranAt: string;                   // ISO 8601
  checksTotal: number;
  checksPassed: number;
  checksFailed: number;
  driftItemsFound: number;
  overallStatus: SetupCheckStatus;
}

// ─── G4: Communication Test Results Viewer ────────────────────────────────────

/** The 4 communication test gates per agent */
export type TestGateName = 'A' | 'B' | 'C' | 'D';

/** Pass/fail status for a single test gate */
export type TestGateStatus = 'pass' | 'fail' | 'skip' | 'timeout' | 'pending';

/** Result for a single gate within a single agent's test run */
export interface TestGate {
  gate: TestGateName;
  /** Human-readable gate description */
  description: string;
  status: TestGateStatus;
  /** Duration of the gate check in milliseconds */
  durationMs: number | null;
  /** Detail message from the test script output */
  detail: string;
  /**
   * For Gate C (Architect received HMAC callback within 90s):
   * actual callback latency in ms
   */
  callbackLatencyMs?: number | null;
}

/** Trailer validation result for a single agent within a test run */
export interface TrailerValidation {
  agentId: string;
  /** Whether all 5 required trailers were found in the test commit */
  allPresent: boolean;
  missingTrailers: string[];
  /** The test commit SHA that was inspected */
  commitSha: string;
}

/** Full test result for a single spoke agent within one test run */
export interface AgentTestResult {
  agentId: string;                 // e.g. 'dev-01', 'designer', 'qc-01'
  vmId: string;
  hostname: string;
  /** Whether this agent was included in the test run */
  tested: boolean;
  gates: TestGate[];               // Always 4 entries (A, B, C, D) when tested
  trailerValidation: TrailerValidation | null;
  /** Did the agent pass all 4 gates? */
  allGatesPassed: boolean;
  /** Total duration of testing this agent in ms */
  totalDurationMs: number | null;
}

/** A single execution of test-communication.sh */
export interface TestRun {
  id: string;                      // e.g. 'run-2026-04-09T14:30:00Z'
  ranAt: string;                   // ISO 8601 start time
  completedAt: string | null;      // ISO 8601 end time (null if interrupted)
  ranBy: string;                   // 'manual' | 'cron' | 'post-install'
  /** Which agents were included: 'all' | 'single:dev-01' | 'group:developers' */
  scope: string;
  agentResults: AgentTestResult[];
  /** Aggregate: how many agents passed all 4 gates */
  passCount: number;
  failCount: number;
  /** Total run duration in ms */
  totalDurationMs: number | null;
  /** Whether any gate C (HMAC callback) timed out */
  hasCallbackTimeout: boolean;
  /** Whether any gate A (dispatch HTTP 200) failed */
  hasDispatchFailure: boolean;
}

// ─── G5: Secrets & Token Inventory ────────────────────────────────────────────

/**
 * The 3-tier secrets architecture tier.
 * platform: /opt/secrets/gateforge.env (root:root 0600)
 * github:   ~/.config/gateforge/github-tokens.env (user:user 0600)
 * app:      ~/.config/gateforge/<app>.env (user:user 0600)
 */
export type TokenTier = 'platform' | 'github' | 'app';

/**
 * File metadata for a single secrets file.
 * IMPORTANT: Actual secret values are NEVER included in this type.
 * Only filesystem metadata is transmitted.
 */
export interface SecretFile {
  /** Full absolute path on the VM */
  path: string;
  /** Filename only (e.g. 'gateforge.env') */
  filename: string;
  tier: TokenTier;
  /** Whether the file exists on this VM */
  exists: boolean;
  /** File size in bytes (null if file does not exist) */
  sizeBytes: number | null;
  /** ISO 8601 last-modified timestamp from stat (null if not found) */
  mtimeIso: string | null;
  /** Unix permission octal string (e.g. '0600') */
  mode: string | null;
  /** File owner username */
  owner: string | null;
  /** File owner group */
  group: string | null;
  /** Number of KEY=VALUE lines in the file (wc -l proxy; no content transmitted) */
  lineCount: number | null;
  /** Expected number of key=value entries for this file; null if variable */
  expectedLineCount: number | null;
  /** Whether permissions match expected (mode 0600, correct owner) */
  permissionsCorrect: boolean;
  /** Whether file age exceeds SECRETS_STALE_THRESHOLD_DAYS */
  isStale: boolean;
  /** Age in days since last modification */
  ageDays: number | null;
}

/** Full secrets compliance result for a single VM */
export interface VMSecretsCompliance {
  vmId: string;
  hostname: string;
  tailscaleIp: string;
  role: string;
  /** Whether SSH was reachable for this inventory pass */
  sshReachable: boolean;
  lastCheckedAt: string;           // ISO 8601
  files: SecretFile[];
  /** Count of files present vs total expected */
  presentCount: number;
  expectedCount: number;
  /** Count of files with correct permissions */
  permCorrectCount: number;
  /** Count of stale files */
  staleCount: number;
  /** Overall compliance: all expected files present AND all permissions correct AND none stale */
  fullyCompliant: boolean;
}

/** A single alert generated by the secrets inventory */
export interface SecretsAlert {
  id: string;
  vmId: string;
  hostname: string;
  severity: 'critical' | 'warning' | 'info';
  /** Alert category */
  type: 'missing-file' | 'wrong-permissions' | 'stale-token' | 'count-mismatch' | 'ssh-unreachable';
  filePath: string;
  message: string;
  detectedAt: string;              // ISO 8601
}

// ─── G6: OpenClaw Configuration Viewer ────────────────────────────────────────

/**
 * Parsed representation of a VM's openclaw.json.
 * Covers the fields relevant to portal monitoring.
 * The raw JSON is also stored for diff and display purposes.
 */
export interface OpenClawConfig {
  vmId: string;
  hostname: string;
  tailscaleIp: string;
  role: string;
  /** ISO 8601 timestamp of when this config was fetched */
  fetchedAt: string;
  /** Whether the config was successfully retrieved */
  available: boolean;
  /** Error message if retrieval failed */
  fetchError?: string;
  // ─── Parsed fields ─────────────────────────────────────────────────────────
  /** Gateway bind address (expected: '127.0.0.1' or 'loopback') */
  bindMode: string | null;
  /** Gateway port (expected: 18789) */
  gatewayPort: number | null;
  /** Tailscale Serve target URL (e.g. 'https://tonic-architect.sailfish-bass.ts.net:18789') */
  tailscaleServeTarget: string | null;
  /** Full list of allowed origins for cross-VM UI access */
  allowedOrigins: string[];
  /** Agent definitions configured in this openclaw.json */
  agents: OpenClawAgentDef[];
  /** Environment variable names mapped into agent contexts (names only, not values) */
  injectedEnvVarNames: string[];
  /** Raw JSON string for diff and display */
  rawJson: string;
}

/** A single agent definition within openclaw.json */
export interface OpenClawAgentDef {
  id: string;                      // e.g. 'architect', 'dev-01'
  model: string;                   // e.g. 'claude-opus-4.6'
  /** Path to the system prompt file reference */
  systemPromptRef: string | null;
  /** Tool names this agent has access to */
  tools: string[];
  /** Environment variable names injected into this agent's context */
  envVarNames: string[];
}

/**
 * A field-level diff between two VMs' openclaw.json configurations.
 * Each DiffField represents a single field that differs.
 */
export interface ConfigDiffField {
  /** JSON path of the differing field (e.g. 'gateway.port', 'allowedOrigins[2]') */
  path: string;
  /** Value in the "from" VM */
  fromValue: unknown;
  /** Value in the "to" VM */
  toValue: unknown;
  /** Whether this difference is considered significant (e.g. port mismatch vs cosmetic label change) */
  significant: boolean;
}

/** Diff result between two VMs' openclaw.json */
export interface ConfigDiff {
  fromVmId: string;
  toVmId: string;
  fromHostname: string;
  toHostname: string;
  generatedAt: string;             // ISO 8601
  /** Number of differing fields */
  diffCount: number;
  /** Whether any significant differences were found */
  hasSignificantDiffs: boolean;
  fields: ConfigDiffField[];
}

/** Validation check result for a single VM's openclaw.json */
export interface ValidationResult {
  vmId: string;
  hostname: string;
  /** Whether the config passes all validation checks */
  valid: boolean;
  checks: ConfigValidationCheck[];
}

/** A single validation check item */
export interface ConfigValidationCheck {
  id: string;                      // e.g. 'bind-mode-loopback', 'port-18789', 'all-origins-present'
  name: string;
  status: 'pass' | 'fail' | 'warn';
  detail: string;
}
```

---

## 4. Backend Implementation

### 4.1 G1 — Network Topology & Health Monitor

#### `backend/src/services/networkProbe.ts`

```typescript
import fetch from 'node-fetch';
import { loadConfig } from '../config';
import { VMHealth, VMHealthStatus, LatencyPoint, NetworkTopology } from '../types/infrastructure';

const PROBE_URL_TEMPLATE = 'https://{hostname}.sailfish-bass.ts.net:18789/health';

const VM_METADATA: Record<string, { hostname: string; tailscaleIp: string; role: string }> = {
  'vm-1': { hostname: 'tonic-architect', tailscaleIp: '100.73.38.28',   role: 'System Architect'  },
  'vm-2': { hostname: 'tonic-designer',  tailscaleIp: '100.95.30.11',   role: 'System Designer'   },
  'vm-3': { hostname: 'tonic-developer', tailscaleIp: '100.81.114.55',  role: 'Developers'        },
  'vm-4': { hostname: 'tonic-qc',        tailscaleIp: '100.106.117.104',role: 'QC Agents'         },
  'vm-5': { hostname: 'tonic-operator',  tailscaleIp: '100.95.248.68',  role: 'Operator'          },
};

// In-memory state
const vmHealthMap = new Map<string, VMHealth>();
let probeIntervalHandle: ReturnType<typeof setInterval> | null = null;

/**
 * Probe a single VM's /health endpoint over its Tailscale FQDN.
 * Returns updated VMHealth regardless of success or failure.
 */
async function probeVM(vmId: string): Promise<VMHealth> {
  const cfg = loadConfig();
  const meta = VM_METADATA[vmId];
  if (!meta) throw new Error(`Unknown vmId: ${vmId}`);

  const fqdn = `${meta.hostname}.sailfish-bass.ts.net`;
  const url = PROBE_URL_TEMPLATE.replace('{hostname}', meta.hostname);
  const existing = vmHealthMap.get(vmId);

  const probeStart = Date.now();
  let status: VMHealthStatus = 'unknown';
  let latencyMs: number | null = null;
  let gatewayVersion: string | undefined;
  let consecutiveFailures = existing?.consecutiveFailures ?? 0;

  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), cfg.networkProbeTimeoutMs);

    const res = await fetch(url, {
      method: 'GET',
      headers: { Accept: 'application/json' },
      signal: controller.signal,
    });

    clearTimeout(timeout);
    latencyMs = Date.now() - probeStart;

    if (res.ok) {
      const body = await res.json() as { status?: string; version?: string };
      status = 'healthy';
      consecutiveFailures = 0;
      gatewayVersion = body.version;
    } else {
      status = 'degraded';
      consecutiveFailures += 1;
      console.warn(`[networkProbe] ${vmId} HTTP ${res.status}`);
    }
  } catch (err) {
    latencyMs = null;
    consecutiveFailures += 1;
    status = consecutiveFailures >= 3 ? 'unreachable' : 'degraded';
    console.warn(`[networkProbe] ${vmId} probe failed:`, (err as Error).message);
  }

  const latencyPoint: LatencyPoint = {
    timestamp: new Date().toISOString(),
    latencyMs,
    ok: status === 'healthy',
  };

  const historySize = cfg.networkLatencyHistorySize;
  const prevHistory = existing?.latencyHistory ?? [];
  const newHistory = [...prevHistory, latencyPoint].slice(-historySize);

  const health: VMHealth = {
    vmId,
    hostname: meta.hostname,
    fqdn,
    tailscaleIp: meta.tailscaleIp,
    role: meta.role,
    status,
    latencyMs,
    lastProbeAt: new Date().toISOString(),
    lastSeenAt: status === 'healthy'
      ? new Date().toISOString()
      : (existing?.lastSeenAt ?? null),
    gatewayVersion: gatewayVersion ?? existing?.gatewayVersion,
    consecutiveFailures,
    latencyHistory: newHistory,
  };

  vmHealthMap.set(vmId, health);
  return health;
}

/** Probe all 5 VMs in parallel. */
async function probeAll(): Promise<void> {
  const vmIds = Object.keys(VM_METADATA);
  await Promise.allSettled(vmIds.map(probeVM));
}

/** Start background probing on the configured interval. */
export function startNetworkProbe(): void {
  const cfg = loadConfig();
  if (probeIntervalHandle) return;

  // Immediate first probe
  probeAll().catch(e => console.error('[networkProbe] initial probe error:', e));

  probeIntervalHandle = setInterval(() => {
    probeAll().catch(e => console.error('[networkProbe] interval error:', e));
  }, cfg.networkProbeInterval * 1000);

  console.log(`[networkProbe] Started — probing every ${cfg.networkProbeInterval}s`);
}

/** Stop background probing (used in tests). */
export function stopNetworkProbe(): void {
  if (probeIntervalHandle) {
    clearInterval(probeIntervalHandle);
    probeIntervalHandle = null;
  }
}

/** Get the current topology snapshot. */
export function getNetworkTopology(): NetworkTopology {
  const vms = Object.keys(VM_METADATA).map(id => {
    return vmHealthMap.get(id) ?? {
      vmId: id,
      hostname: VM_METADATA[id].hostname,
      fqdn: `${VM_METADATA[id].hostname}.sailfish-bass.ts.net`,
      tailscaleIp: VM_METADATA[id].tailscaleIp,
      role: VM_METADATA[id].role,
      status: 'unknown' as VMHealthStatus,
      latencyMs: null,
      lastProbeAt: new Date().toISOString(),
      lastSeenAt: null,
      consecutiveFailures: 0,
      latencyHistory: [],
    };
  });

  const unreachable = vms.filter(v => v.status === 'unreachable').map(v => v.vmId);
  const healthy = vms.filter(v => v.status === 'healthy');
  const avgLatencyMs = healthy.length > 0
    ? healthy.reduce((sum, v) => sum + (v.latencyMs ?? 0), 0) / healthy.length
    : null;

  let fleetStatus: NetworkTopology['fleetStatus'];
  if (healthy.length === 5)                         fleetStatus = 'all-healthy';
  else if (healthy.length === 0)                    fleetStatus = 'down';
  else if (unreachable.length > 0)                  fleetStatus = 'partial';
  else                                              fleetStatus = 'degraded';

  return {
    capturedAt: new Date().toISOString(),
    vms,
    fleetStatus,
    unreachableVmIds: unreachable,
    avgLatencyMs,
  };
}

/** Get the health of a single VM. */
export function getVMHealth(vmId: string): VMHealth | null {
  return vmHealthMap.get(vmId) ?? null;
}

/** Get latency history for a single VM. */
export function getLatencyHistory(vmId: string, lastN?: number): LatencyPoint[] {
  const health = vmHealthMap.get(vmId);
  if (!health) return [];
  const history = health.latencyHistory;
  return lastN ? history.slice(-lastN) : history;
}
```

---

#### `backend/src/routes/network.ts`

```typescript
import { Router, Request, Response } from 'express';
import { requireAuth } from '../middleware/auth';
import {
  getNetworkTopology,
  getVMHealth,
  getLatencyHistory,
} from '../services/networkProbe';

const router = Router();

// All routes require authentication
router.use(requireAuth);

/**
 * GET /api/network/topology
 * Returns the current full network topology with all 5 VM health statuses.
 */
router.get('/topology', (_req: Request, res: Response) => {
  try {
    const topology = getNetworkTopology();
    res.json({ ok: true, data: topology });
  } catch (err) {
    console.error('[network/topology]', (err as Error).message);
    res.status(500).json({ ok: false, error: 'Failed to retrieve network topology' });
  }
});

/**
 * GET /api/network/vm-status/:vmId
 * Returns the health status for a single VM.
 */
router.get('/vm-status/:vmId', (req: Request, res: Response) => {
  const { vmId } = req.params;
  const validVmIds = ['vm-1', 'vm-2', 'vm-3', 'vm-4', 'vm-5'];

  if (!validVmIds.includes(vmId)) {
    res.status(400).json({ ok: false, error: `Invalid vmId. Must be one of: ${validVmIds.join(', ')}` });
    return;
  }

  const health = getVMHealth(vmId);
  if (!health) {
    res.status(404).json({ ok: false, error: `No probe data available for ${vmId}` });
    return;
  }

  res.json({ ok: true, data: health });
});

/**
 * GET /api/network/latency-history/:vmId?last=60
 * Returns the latency history for a single VM.
 * Query param `last` controls how many recent points to return (default: all).
 */
router.get('/latency-history/:vmId', (req: Request, res: Response) => {
  const { vmId } = req.params;
  const last = req.query.last ? parseInt(req.query.last as string, 10) : undefined;

  if (last !== undefined && (isNaN(last) || last < 1)) {
    res.status(400).json({ ok: false, error: '`last` must be a positive integer' });
    return;
  }

  const history = getLatencyHistory(vmId, last);
  res.json({ ok: true, data: history });
});

export default router;
```

---

### 4.2 G2 — Notification Delivery Tracker

#### `backend/src/services/notificationMonitor.ts`

```typescript
import { loadConfig } from '../config';
import { fetchAgentLogs } from './gatewayClient';
import {
  NotificationEvent,
  NotificationDeliveryStats,
  DeadLetterEntry,
  TrailerCompliance,
  NotificationPriority,
  DeliveryStatus,
} from '../types/infrastructure';

// In-memory rolling store
const eventStore: NotificationEvent[] = [];
const deadLetterStore: DeadLetterEntry[] = [];
let monitorIntervalHandle: ReturnType<typeof setInterval> | null = null;

/** Required commit trailer names per the GateForge notification protocol. */
const REQUIRED_TRAILERS = [
  'GateForge-Task-Id',
  'GateForge-Priority',
  'GateForge-Source-VM',
  'GateForge-Source-Role',
  'GateForge-Summary',
];

/**
 * Parse a gf-notify journal line into a NotificationEvent.
 * Expected log format (from gf-notify-architect.sh):
 *   [2026-04-09T14:22:01Z] [vm-3] [dev-01] TASK-042 COMPLETED HTTP/200 12ms sha:abc1234
 *   trailers: GateForge-Task-Id,GateForge-Priority,GateForge-Source-VM,GateForge-Source-Role,GateForge-Summary
 */
function parseJournalLine(line: string, index: number): NotificationEvent | null {
  // Flexible regex to match the structured log format from gf-notify-architect.sh
  const match = line.match(
    /\[(\S+)\]\s+\[(\S+)\]\s+\[(\S+)\]\s+(\S+)\s+(\S+)\s+HTTP\/(\d+)\s+(\d+)ms\s+sha:(\S+)\s+trailers:(\S*)/
  );

  if (!match) return null;

  const [, timestamp, sourceVmId, sourceRole, taskId, priority, httpStatus, latencyMs, commitSha, trailerList] = match;

  const presentTrailers = trailerList ? trailerList.split(',') : [];
  const missingTrailers = REQUIRED_TRAILERS.filter(t => !presentTrailers.includes(t));
  const httpStatusNum = parseInt(httpStatus, 10);

  let deliveryStatus: DeliveryStatus = 'delivered';
  if (httpStatusNum >= 400 || httpStatusNum === 0) {
    deliveryStatus = 'failed';
  }

  return {
    id: `evt-${Date.now()}-${index}`,
    timestamp,
    sourceVmId,
    sourceRole,
    taskId,
    priority: priority as NotificationPriority,
    summary: `${priority} — ${taskId}`,  // Extended by downstream log pass
    httpStatus: httpStatusNum,
    deliveryStatus,
    deliveryLatencyMs: parseInt(latencyMs, 10),
    attemptCount: 1,
    commitSha,
    trailersComplete: missingTrailers.length === 0,
    missingTrailers,
  };
}

/**
 * Parse a dead-letter log line into a DeadLetterEntry.
 * Format: [DEAD] [timestamp] [vmId] [taskId] [priority] attempts:N status:NNN error:MSG payload:{...}
 */
function parseDeadLetterLine(line: string, index: number): DeadLetterEntry | null {
  const match = line.match(
    /\[DEAD\]\s+\[(\S+)\]\s+\[(\S+)\]\s+(\S+)\s+(\S+)\s+attempts:(\d+)\s+status:(\d+)\s+error:(.+?)\s+payload:(.+)$/
  );
  if (!match) return null;

  const [, timestamp, sourceVmId, taskId, priority, attemptCount, lastHttpStatus, lastError, payloadPreview] = match;

  return {
    id: `dl-${Date.now()}-${index}`,
    timestamp,
    sourceVmId,
    taskId,
    priority: priority as NotificationPriority,
    summary: `Dead-letter: ${taskId}`,
    attemptCount: parseInt(attemptCount, 10),
    lastHttpStatus: parseInt(lastHttpStatus, 10) || null,
    lastError: lastError.trim(),
    payloadPreview: payloadPreview.slice(0, 200),  // Truncate for safety
  };
}

/** Fetch and parse the latest journal entries from VM-1 (Architect). */
async function refreshJournal(): Promise<void> {
  const cfg = loadConfig();
  const vm1 = cfg.vms.find(v => v.id === 'vm-1');
  if (!vm1) {
    console.warn('[notificationMonitor] vm-1 not configured — skipping journal refresh');
    return;
  }

  try {
    // Fetch notification journal entries via the gateway API
    const raw = await fetchAgentLogs(vm1, 'gf-notify') as unknown[];
    const lines = raw.map(r => String(r)).slice(-cfg.notifyJournalTailLines);

    const newEvents: NotificationEvent[] = [];
    lines.forEach((line, i) => {
      const evt = parseJournalLine(line, i);
      if (evt) newEvents.push(evt);
    });

    // Deduplicate by commitSha + timestamp
    const existingKeys = new Set(eventStore.map(e => `${e.commitSha}-${e.timestamp}`));
    for (const evt of newEvents) {
      const key = `${evt.commitSha}-${evt.timestamp}`;
      if (!existingKeys.has(key)) {
        eventStore.push(evt);
        existingKeys.add(key);
      }
    }

    // Keep rolling window: last 5000 events
    if (eventStore.length > 5000) {
      eventStore.splice(0, eventStore.length - 5000);
    }
  } catch (err) {
    console.warn('[notificationMonitor] journal refresh failed:', (err as Error).message);
  }
}

/** Start the background notification monitor. */
export function startNotificationMonitor(): void {
  const cfg = loadConfig();
  if (monitorIntervalHandle) return;

  refreshJournal().catch(e => console.error('[notificationMonitor] initial refresh error:', e));

  monitorIntervalHandle = setInterval(() => {
    refreshJournal().catch(e => console.error('[notificationMonitor] interval error:', e));
  }, cfg.notifyPollInterval * 1000);

  console.log(`[notificationMonitor] Started — polling every ${cfg.notifyPollInterval}s`);
}

/** Stop the background monitor (for tests). */
export function stopNotificationMonitor(): void {
  if (monitorIntervalHandle) {
    clearInterval(monitorIntervalHandle);
    monitorIntervalHandle = null;
  }
}

/** Get recent notification events, optionally filtered. */
export function getNotificationLog(opts: {
  limit?: number;
  vmId?: string;
  priority?: NotificationPriority;
  status?: DeliveryStatus;
}): NotificationEvent[] {
  let result = [...eventStore].reverse(); // Most recent first

  if (opts.vmId)    result = result.filter(e => e.sourceVmId === opts.vmId);
  if (opts.priority) result = result.filter(e => e.priority === opts.priority);
  if (opts.status)  result = result.filter(e => e.deliveryStatus === opts.status);

  return result.slice(0, opts.limit ?? 200);
}

/** Get aggregated delivery statistics for a time window. */
export function getDeliveryStats(period: NotificationDeliveryStats['period']): NotificationDeliveryStats {
  const periodMs: Record<typeof period, number> = {
    '1h': 3600_000, '6h': 21600_000, '24h': 86400_000, '7d': 604800_000,
  };
  const cutoff = new Date(Date.now() - periodMs[period]);
  const events = eventStore.filter(e => new Date(e.timestamp) >= cutoff);

  const delivered  = events.filter(e => e.deliveryStatus === 'delivered');
  const failed     = events.filter(e => e.deliveryStatus === 'failed');
  const deadLetter = events.filter(e => e.deliveryStatus === 'dead-letter');

  const avgLatency = delivered.length > 0
    ? delivered.reduce((s, e) => s + (e.deliveryLatencyMs ?? 0), 0) / delivered.length
    : null;

  const byPriority = {} as Record<NotificationPriority, number>;
  const bySourceVm: Record<string, number> = {};
  for (const p of ['COMPLETED', 'BLOCKED', 'DISPUTE', 'CRITICAL', 'INFO'] as NotificationPriority[]) {
    byPriority[p] = events.filter(e => e.priority === p).length;
  }
  for (const e of events) {
    bySourceVm[e.sourceVmId] = (bySourceVm[e.sourceVmId] ?? 0) + 1;
  }

  const compliant = events.filter(e => e.trailersComplete).length;

  return {
    period,
    totalEvents:            events.length,
    deliveredCount:         delivered.length,
    failedCount:            failed.length,
    deadLetterCount:        deadLetter.length,
    successRate:            events.length > 0 ? delivered.length / events.length : 1,
    avgDeliveryLatencyMs:   avgLatency,
    byPriority,
    bySourceVm,
    trailerComplianceRate:  events.length > 0 ? compliant / events.length : 1,
  };
}

/** Get the current dead-letter queue entries. */
export function getDeadLetters(limit = 50): DeadLetterEntry[] {
  return [...deadLetterStore].reverse().slice(0, limit);
}

/** Get per-VM trailer compliance breakdown. */
export function getTrailerCompliance(): TrailerCompliance[] {
  const vmIds = ['vm-1', 'vm-2', 'vm-3', 'vm-4', 'vm-5'];
  const hostnames: Record<string, string> = {
    'vm-1': 'tonic-architect', 'vm-2': 'tonic-designer',
    'vm-3': 'tonic-developer', 'vm-4': 'tonic-qc', 'vm-5': 'tonic-operator',
  };

  return vmIds.map(vmId => {
    const vmEvents = eventStore.filter(e => e.sourceVmId === vmId);
    const compliantEvents = vmEvents.filter(e => e.trailersComplete);
    const missingBreakdown: Record<string, number> = {};
    for (const e of vmEvents) {
      for (const t of e.missingTrailers) {
        missingBreakdown[t] = (missingBreakdown[t] ?? 0) + 1;
      }
    }
    return {
      vmId,
      hostname: hostnames[vmId] ?? vmId,
      totalCommits: vmEvents.length,
      compliantCommits: compliantEvents.length,
      missingTrailerBreakdown: missingBreakdown,
      complianceRate: vmEvents.length > 0 ? compliantEvents.length / vmEvents.length : 1,
    };
  });
}
```

---

#### `backend/src/routes/notifications-delivery.ts`

```typescript
import { Router, Request, Response } from 'express';
import { requireAuth } from '../middleware/auth';
import {
  getNotificationLog,
  getDeliveryStats,
  getDeadLetters,
  getTrailerCompliance,
} from '../services/notificationMonitor';
import { NotificationPriority, DeliveryStatus } from '../types/infrastructure';

const router = Router();
router.use(requireAuth);

const VALID_PERIODS = ['1h', '6h', '24h', '7d'] as const;
const VALID_PRIORITIES: NotificationPriority[] = ['COMPLETED', 'BLOCKED', 'DISPUTE', 'CRITICAL', 'INFO'];
const VALID_STATUSES: DeliveryStatus[] = ['delivered', 'failed', 'retrying', 'dead-letter'];

/**
 * GET /api/notifications-delivery/log
 * Query params: limit (default 200), vmId, priority, status
 */
router.get('/log', (req: Request, res: Response) => {
  const limit = req.query.limit ? parseInt(req.query.limit as string, 10) : 200;
  const vmId = req.query.vmId as string | undefined;
  const priority = req.query.priority as NotificationPriority | undefined;
  const status = req.query.status as DeliveryStatus | undefined;

  if (priority && !VALID_PRIORITIES.includes(priority)) {
    res.status(400).json({ ok: false, error: `Invalid priority. Valid: ${VALID_PRIORITIES.join(', ')}` });
    return;
  }
  if (status && !VALID_STATUSES.includes(status)) {
    res.status(400).json({ ok: false, error: `Invalid status. Valid: ${VALID_STATUSES.join(', ')}` });
    return;
  }

  const events = getNotificationLog({ limit, vmId, priority, status });
  res.json({ ok: true, data: events });
});

/**
 * GET /api/notifications-delivery/stats?period=24h
 * Returns aggregated delivery statistics.
 */
router.get('/stats', (req: Request, res: Response) => {
  const period = (req.query.period as string) ?? '24h';
  if (!VALID_PERIODS.includes(period as typeof VALID_PERIODS[number])) {
    res.status(400).json({ ok: false, error: `Invalid period. Valid: ${VALID_PERIODS.join(', ')}` });
    return;
  }

  const stats = getDeliveryStats(period as typeof VALID_PERIODS[number]);
  res.json({ ok: true, data: stats });
});

/**
 * GET /api/notifications-delivery/dead-letters?limit=50
 * Returns the current dead-letter queue entries.
 */
router.get('/dead-letters', (req: Request, res: Response) => {
  const limit = req.query.limit ? parseInt(req.query.limit as string, 10) : 50;
  const entries = getDeadLetters(limit);
  res.json({ ok: true, data: entries });
});

/**
 * GET /api/notifications-delivery/trailer-compliance
 * Returns per-VM commit trailer compliance breakdown.
 */
router.get('/trailer-compliance', (_req: Request, res: Response) => {
  const compliance = getTrailerCompliance();
  res.json({ ok: true, data: compliance });
});

export default router;
```

---

### 4.3 G3 — Installation & Setup Dashboard

#### `backend/src/services/setupValidator.ts`

```typescript
import { NodeSSH } from 'node-ssh';
import { loadConfig } from '../config';
import {
  VMSetupStatus,
  SetupCheck,
  SetupCheckStatus,
  ConfigDrift,
  SetupHistoryEntry,
} from '../types/infrastructure';

// In-memory stores
const vmSetupMap = new Map<string, VMSetupStatus>();
const driftStore: ConfigDrift[] = [];
const historyStore: SetupHistoryEntry[] = [];
let validatorIntervalHandle: ReturnType<typeof setInterval> | null = null;

const VM_SSH_HOSTS: Record<string, string> = {
  'vm-1': '100.73.38.28',
  'vm-2': '100.95.30.11',
  'vm-3': '100.81.114.55',
  'vm-4': '100.106.117.104',
  'vm-5': '100.95.248.68',
};

const VM_HOSTNAMES: Record<string, string> = {
  'vm-1': 'tonic-architect',
  'vm-2': 'tonic-designer',
  'vm-3': 'tonic-developer',
  'vm-4': 'tonic-qc',
  'vm-5': 'tonic-operator',
};

const VM_ROLES: Record<string, string> = {
  'vm-1': 'System Architect',
  'vm-2': 'System Designer',
  'vm-3': 'Developers',
  'vm-4': 'QC Agents',
  'vm-5': 'Operator',
};

/**
 * Expected config files on every VM with their expected permissions.
 * Checks are READ-ONLY — we only stat and check existence.
 */
const EXPECTED_FILES: Array<{ path: string; mode: string; owner: string }> = [
  { path: '/opt/openclaw/openclaw.json',     mode: '644', owner: 'gf'   },
  { path: '/opt/gateforge/.install-complete', mode: '644', owner: 'gf'  },
  { path: '/etc/tailscale/tailscaled.state', mode: '600', owner: 'root' },
];

/**
 * Run a read-only SSH check against a single VM.
 * Only executes non-destructive commands: stat, test, cat (for openclaw.json only), journalctl.
 */
async function validateVM(vmId: string): Promise<VMSetupStatus> {
  const cfg = loadConfig();
  const ip = VM_SSH_HOSTS[vmId];
  const hostname = VM_HOSTNAMES[vmId];
  const role = VM_ROLES[vmId];

  const ssh = new NodeSSH();
  let sshReachable = false;
  const checks: SetupCheck[] = [];
  const now = new Date().toISOString();

  try {
    await ssh.connect({
      host: ip,
      username: cfg.infraSshUser,
      privateKeyPath: cfg.infraSshKeyPath,
      readyTimeout: 8000,
    });
    sshReachable = true;

    // Check 1: Sentinel file presence
    const sentinelResult = await ssh.execCommand(`test -f ${cfg.setupSentinelPath} && echo FOUND || echo MISSING`);
    const sentinelFound = sentinelResult.stdout.trim() === 'FOUND';
    checks.push({
      id: 'sentinel-file',
      name: 'Install sentinel file',
      description: `${cfg.setupSentinelPath} must exist`,
      status: sentinelFound ? 'pass' : 'fail',
      detail: sentinelFound ? `Found at ${cfg.setupSentinelPath}` : `Missing: ${cfg.setupSentinelPath}`,
      checkedAt: now,
    });

    // Check 2: OpenClaw config presence
    const oclResult = await ssh.execCommand('test -f /opt/openclaw/openclaw.json && echo FOUND || echo MISSING');
    const oclFound = oclResult.stdout.trim() === 'FOUND';
    checks.push({
      id: 'openclaw-config',
      name: 'OpenClaw config file',
      description: '/opt/openclaw/openclaw.json must exist',
      status: oclFound ? 'pass' : 'fail',
      detail: oclFound ? 'Found at /opt/openclaw/openclaw.json' : 'Missing /opt/openclaw/openclaw.json',
      checkedAt: now,
    });

    // Check 3: Tailscale service running
    const tsResult = await ssh.execCommand('systemctl is-active tailscaled 2>/dev/null || echo inactive');
    const tsActive = tsResult.stdout.trim() === 'active';
    checks.push({
      id: 'tailscale-running',
      name: 'Tailscale daemon',
      description: 'tailscaled.service must be active',
      status: tsActive ? 'pass' : 'warn',
      detail: tsActive ? 'tailscaled is active' : `tailscaled status: ${tsResult.stdout.trim()}`,
      checkedAt: now,
    });

    // Check 4: OpenClaw gateway service running
    const gfResult = await ssh.execCommand('systemctl is-active openclaw 2>/dev/null || echo inactive');
    const gfActive = gfResult.stdout.trim() === 'active';
    checks.push({
      id: 'openclaw-service',
      name: 'OpenClaw gateway service',
      description: 'openclaw.service must be active',
      status: gfActive ? 'pass' : 'fail',
      detail: gfActive ? 'openclaw.service is active' : `openclaw.service status: ${gfResult.stdout.trim()}`,
      checkedAt: now,
    });

    // Check 5: UFW active
    const ufwResult = await ssh.execCommand('sudo ufw status 2>/dev/null | head -1 || echo unknown');
    const ufwActive = ufwResult.stdout.toLowerCase().includes('active');
    checks.push({
      id: 'ufw-active',
      name: 'UFW firewall',
      description: 'UFW firewall must be active',
      status: ufwActive ? 'pass' : 'warn',
      detail: ufwResult.stdout.trim().slice(0, 100),
      checkedAt: now,
    });

    // Check 6: Port 18789 accessible on loopback
    const portResult = await ssh.execCommand('ss -tlnp 2>/dev/null | grep ":18789" | head -1 || echo NOT_LISTENING');
    const portListening = !portResult.stdout.includes('NOT_LISTENING') && portResult.stdout.includes('18789');
    checks.push({
      id: 'gateway-port',
      name: 'Gateway port 18789',
      description: 'OpenClaw must be listening on :18789',
      status: portListening ? 'pass' : 'fail',
      detail: portListening ? 'Port 18789 listening' : 'Port 18789 not found in ss output',
      checkedAt: now,
    });

    // Drift detection: stat expected files
    for (const expected of EXPECTED_FILES) {
      const statResult = await ssh.execCommand(
        `stat -c '%a %U %G' ${expected.path} 2>/dev/null || echo MISSING`
      );
      const statOutput = statResult.stdout.trim();
      if (statOutput === 'MISSING') {
        driftStore.push({
          vmId, hostname, filePath: expected.path,
          driftType: 'missing',
          description: `Expected file ${expected.path} is missing`,
          detectedAt: now,
          expected: `Present with mode ${expected.mode}, owner ${expected.owner}`,
          actual: 'File not found',
        });
      } else {
        const [mode, owner] = statOutput.split(' ');
        if (mode !== expected.mode) {
          driftStore.push({
            vmId, hostname, filePath: expected.path,
            driftType: 'permissions-mismatch',
            description: `${expected.path} has wrong permissions`,
            detectedAt: now,
            expected: `Mode ${expected.mode}`,
            actual: `Mode ${mode}`,
          });
        }
      }
    }

    // Get sentinel mtime for installedAt
    const mtimeResult = await ssh.execCommand(
      `stat -c '%Y' ${cfg.setupSentinelPath} 2>/dev/null || echo 0`
    );
    const mtime = parseInt(mtimeResult.stdout.trim(), 10);
    const installedAt = mtime > 0 ? new Date(mtime * 1000).toISOString() : null;

    const passCount = checks.filter(c => c.status === 'pass').length;
    const hasDrift = driftStore.some(d => d.vmId === vmId);

    const result: VMSetupStatus = {
      vmId, hostname, tailscaleIp: ip, role,
      sshReachable: true,
      lastCheckedAt: now,
      installComplete: sentinelFound,
      lastSetupExitCode: null,  // Not reliably determinable post-install
      installedAt,
      checkPassRate: checks.length > 0 ? passCount / checks.length : 0,
      checks,
      hasDrift,
    };

    vmSetupMap.set(vmId, result);

    // Record history
    historyStore.push({
      id: `hist-${vmId}-${Date.now()}`,
      vmId, hostname, ranAt: now,
      checksTotal:    checks.length,
      checksPassed:   checks.filter(c => c.status === 'pass').length,
      checksFailed:   checks.filter(c => c.status === 'fail').length,
      driftItemsFound: driftStore.filter(d => d.vmId === vmId && d.detectedAt === now).length,
      overallStatus:  passCount === checks.length ? 'pass' : passCount > checks.length / 2 ? 'warn' : 'fail',
    });

    // Keep history bounded
    if (historyStore.length > 1000) historyStore.splice(0, historyStore.length - 1000);

    return result;
  } catch (err) {
    console.warn(`[setupValidator] SSH failed for ${vmId}:`, (err as Error).message);
    const result: VMSetupStatus = {
      vmId, hostname, tailscaleIp: ip, role,
      sshReachable: false,
      lastCheckedAt: now,
      installComplete: false,
      lastSetupExitCode: null,
      installedAt: null,
      checkPassRate: 0,
      checks: [{
        id: 'ssh-connect',
        name: 'SSH connectivity',
        description: 'SSH must be reachable for setup validation',
        status: 'fail',
        detail: `SSH connection failed: ${(err as Error).message}`,
        checkedAt: now,
      }],
      hasDrift: false,
    };
    vmSetupMap.set(vmId, result);
    return result;
  } finally {
    ssh.dispose();
  }
}

/** Validate all VMs sequentially (to avoid overwhelming SSH). */
async function validateAll(): Promise<void> {
  for (const vmId of Object.keys(VM_SSH_HOSTS)) {
    await validateVM(vmId).catch(e => console.error(`[setupValidator] ${vmId}:`, e.message));
  }
}

export function startSetupValidator(): void {
  const cfg = loadConfig();
  if (validatorIntervalHandle) return;

  validateAll().catch(e => console.error('[setupValidator] initial pass error:', e));

  validatorIntervalHandle = setInterval(() => {
    validateAll().catch(e => console.error('[setupValidator] interval error:', e));
  }, cfg.setupDriftCheckInterval * 1000);

  console.log(`[setupValidator] Started — checking every ${cfg.setupDriftCheckInterval}s`);
}

export function stopSetupValidator(): void {
  if (validatorIntervalHandle) {
    clearInterval(validatorIntervalHandle);
    validatorIntervalHandle = null;
  }
}

export function getAllVMSetupStatuses(): VMSetupStatus[] {
  return Object.keys(VM_SSH_HOSTS).map(id => vmSetupMap.get(id)).filter(Boolean) as VMSetupStatus[];
}

export function getVMSetupStatus(vmId: string): VMSetupStatus | null {
  return vmSetupMap.get(vmId) ?? null;
}

export function getConfigDrifts(vmId?: string): ConfigDrift[] {
  return vmId ? driftStore.filter(d => d.vmId === vmId) : [...driftStore];
}

export function getSetupHistory(vmId?: string, limit = 50): SetupHistoryEntry[] {
  const items = vmId ? historyStore.filter(h => h.vmId === vmId) : [...historyStore];
  return items.reverse().slice(0, limit);
}
```

---

#### `backend/src/routes/setup-status.ts`

```typescript
import { Router, Request, Response } from 'express';
import { requireAuth } from '../middleware/auth';
import {
  getAllVMSetupStatuses,
  getVMSetupStatus,
  getConfigDrifts,
  getSetupHistory,
} from '../services/setupValidator';

const router = Router();
router.use(requireAuth);

/**
 * GET /api/setup-status/vm-setup-status
 * Returns setup status for all 5 VMs.
 */
router.get('/vm-setup-status', (_req: Request, res: Response) => {
  const statuses = getAllVMSetupStatuses();
  res.json({ ok: true, data: statuses });
});

/**
 * GET /api/setup-status/vm-setup-status/:vmId
 * Returns setup status for a single VM.
 */
router.get('/vm-setup-status/:vmId', (req: Request, res: Response) => {
  const { vmId } = req.params;
  const status = getVMSetupStatus(vmId);
  if (!status) {
    res.status(404).json({ ok: false, error: `No setup data available for ${vmId}` });
    return;
  }
  res.json({ ok: true, data: status });
});

/**
 * GET /api/setup-status/drift-detection?vmId=vm-3
 * Returns config drift items, optionally filtered by vmId.
 */
router.get('/drift-detection', (req: Request, res: Response) => {
  const vmId = req.query.vmId as string | undefined;
  const drifts = getConfigDrifts(vmId);
  res.json({ ok: true, data: drifts });
});

/**
 * GET /api/setup-status/history?vmId=vm-2&limit=20
 * Returns historical setup validation runs.
 */
router.get('/history', (req: Request, res: Response) => {
  const vmId = req.query.vmId as string | undefined;
  const limit = req.query.limit ? parseInt(req.query.limit as string, 10) : 50;
  const history = getSetupHistory(vmId, limit);
  res.json({ ok: true, data: history });
});

export default router;
```

---

### 4.4 G4 — Communication Test Results Viewer

#### `backend/src/services/testRunParser.ts`

```typescript
import { NodeSSH } from 'node-ssh';
import { loadConfig } from '../config';
import {
  TestRun,
  AgentTestResult,
  TestGate,
  TestGateName,
  TestGateStatus,
  TrailerValidation,
} from '../types/infrastructure';

// In-memory store
const testRunStore: TestRun[] = [];
let parserIntervalHandle: ReturnType<typeof setInterval> | null = null;

/**
 * Parse a test-communication.sh output log file content into a TestRun.
 * Expected output structure from test-communication.sh:
 *
 * === TEST RUN START ===
 * RUN_ID: run-2026-04-09T14:30:00Z
 * SCOPE: all
 * STARTED_AT: 2026-04-09T14:30:00Z
 * RAN_BY: manual
 *
 * --- AGENT: dev-01 (vm-3) ---
 * GATE_A: PASS 1240ms Dispatch accepted HTTP/200 runId:abc-123
 * GATE_B: PASS 45000ms Commit pushed sha:def456
 * GATE_C: PASS 67000ms HMAC callback received latency:65420ms
 * GATE_D: PASS 2100ms Deliverable readable via git cat-file
 * TRAILERS: GateForge-Task-Id,GateForge-Priority,GateForge-Source-VM,GateForge-Source-Role,GateForge-Summary
 * SHA: def456abc123
 *
 * === TEST RUN END ===
 * COMPLETED_AT: 2026-04-09T15:02:33Z
 */
function parseTestLogContent(content: string, filename: string): TestRun | null {
  const lines = content.split('\n');

  const runId = filename.replace('.log', '');
  let startedAt = '';
  let completedAt: string | null = null;
  let ranBy = 'manual';
  let scope = 'all';
  const agentResults: AgentTestResult[] = [];

  let currentAgent: Partial<AgentTestResult> | null = null;
  let currentGates: TestGate[] = [];
  let currentSha = '';

  const REQUIRED_TRAILERS = [
    'GateForge-Task-Id', 'GateForge-Priority',
    'GateForge-Source-VM', 'GateForge-Source-Role', 'GateForge-Summary',
  ];

  for (const rawLine of lines) {
    const line = rawLine.trim();

    if (line.startsWith('STARTED_AT:'))    startedAt = line.split(': ')[1].trim();
    if (line.startsWith('COMPLETED_AT:'))  completedAt = line.split(': ')[1].trim();
    if (line.startsWith('RAN_BY:'))        ranBy = line.split(': ')[1].trim();
    if (line.startsWith('SCOPE:'))         scope = line.split(': ')[1].trim();

    // New agent section
    const agentMatch = line.match(/^--- AGENT: (\S+) \((\S+)\) ---$/);
    if (agentMatch) {
      if (currentAgent) finaliseAgent(currentAgent, currentGates, currentSha, agentResults);
      currentAgent = { agentId: agentMatch[1], vmId: agentMatch[2], tested: true };
      currentGates = [];
      currentSha = '';
      // Determine hostname from vmId
      const hostnames: Record<string, string> = {
        'vm-1': 'tonic-architect', 'vm-2': 'tonic-designer',
        'vm-3': 'tonic-developer', 'vm-4': 'tonic-qc', 'vm-5': 'tonic-operator',
      };
      currentAgent.hostname = hostnames[agentMatch[2]] ?? agentMatch[2];
      continue;
    }

    // Gate result line: GATE_A: PASS 1240ms Detail text
    const gateMatch = line.match(/^GATE_([ABCD]):\s+(PASS|FAIL|SKIP|TIMEOUT)\s+(\d+)ms\s+(.+)$/);
    if (gateMatch && currentAgent) {
      const [, gateLetter, statusStr, durationStr, detail] = gateMatch;
      const gate = gateLetter as TestGateName;
      const status = statusStr.toLowerCase() as TestGateStatus;
      const durationMs = parseInt(durationStr, 10);

      const gateDescriptions: Record<TestGateName, string> = {
        A: 'Architect → spoke dispatch accepted (HTTP 200 + runId)',
        B: 'Spoke agent committed + pushed file',
        C: 'Architect received HMAC callback (within 90s)',
        D: 'Deliverable readable by hub (git cat-file)',
      };

      // Extract callback latency for Gate C
      let callbackLatencyMs: number | null = null;
      if (gate === 'C') {
        const cbMatch = detail.match(/latency:(\d+)ms/);
        if (cbMatch) callbackLatencyMs = parseInt(cbMatch[1], 10);
      }

      currentGates.push({
        gate, description: gateDescriptions[gate],
        status, durationMs, detail,
        ...(gate === 'C' ? { callbackLatencyMs } : {}),
      });
      continue;
    }

    // Trailer list line
    const trailerMatch = line.match(/^TRAILERS:\s+(.+)$/);
    if (trailerMatch && currentAgent) {
      const present = trailerMatch[1].split(',').map(t => t.trim());
      const missing = REQUIRED_TRAILERS.filter(t => !present.includes(t));
      (currentAgent as Partial<AgentTestResult> & { _trailerValidation?: TrailerValidation })
        ._trailerValidation = {
          agentId: currentAgent.agentId!,
          allPresent: missing.length === 0,
          missingTrailers: missing,
          commitSha: currentSha,
        };
      continue;
    }

    // Commit SHA line
    const shaMatch = line.match(/^SHA:\s+(\S+)$/);
    if (shaMatch) currentSha = shaMatch[1];
  }

  // Finalise last agent
  if (currentAgent) finaliseAgent(currentAgent, currentGates, currentSha, agentResults);

  if (!startedAt) return null;

  const passCount = agentResults.filter(a => a.allGatesPassed).length;
  const failCount = agentResults.filter(a => a.tested && !a.allGatesPassed).length;
  const hasCallbackTimeout = agentResults.some(a =>
    a.gates.some(g => g.gate === 'C' && g.status === 'timeout')
  );
  const hasDispatchFailure = agentResults.some(a =>
    a.gates.some(g => g.gate === 'A' && g.status === 'fail')
  );

  return {
    id: runId,
    ranAt: startedAt,
    completedAt,
    ranBy,
    scope,
    agentResults,
    passCount,
    failCount,
    totalDurationMs: completedAt
      ? new Date(completedAt).getTime() - new Date(startedAt).getTime()
      : null,
    hasCallbackTimeout,
    hasDispatchFailure,
  };
}

function finaliseAgent(
  agent: Partial<AgentTestResult> & { _trailerValidation?: TrailerValidation },
  gates: TestGate[],
  sha: string,
  results: AgentTestResult[]
): void {
  const tv = agent._trailerValidation ?? null;
  if (tv) tv.commitSha = sha;

  const allGatesPassed = gates.length === 4 && gates.every(g => g.status === 'pass');
  const totalDurationMs = gates.reduce((s, g) => s + (g.durationMs ?? 0), 0);

  results.push({
    agentId:          agent.agentId!,
    vmId:             agent.vmId!,
    hostname:         agent.hostname!,
    tested:           true,
    gates,
    trailerValidation: tv,
    allGatesPassed,
    totalDurationMs,
  });
}

/** Fetch and parse test logs from VM-1 via SSH. */
async function refreshTestLogs(): Promise<void> {
  const cfg = loadConfig();
  const ssh = new NodeSSH();

  try {
    await ssh.connect({
      host: '100.73.38.28',
      username: cfg.infraSshUser,
      privateKeyPath: cfg.infraSshKeyPath,
      readyTimeout: 10000,
    });

    // List available log files
    const lsResult = await ssh.execCommand(`ls -1t ${cfg.testLogDir}/*.log 2>/dev/null | head -${cfg.testHistoryMaxRuns}`);
    const logFiles = lsResult.stdout.split('\n').filter(Boolean);

    const existingIds = new Set(testRunStore.map(r => r.id));

    for (const filePath of logFiles) {
      const filename = filePath.split('/').pop()!;
      const runId = filename.replace('.log', '');
      if (existingIds.has(runId)) continue;

      const catResult = await ssh.execCommand(`cat ${filePath} 2>/dev/null || echo ""`);
      const run = parseTestLogContent(catResult.stdout, filename);
      if (run) {
        testRunStore.push(run);
        existingIds.add(runId);
      }
    }

    // Sort by date desc, keep bounded
    testRunStore.sort((a, b) => new Date(b.ranAt).getTime() - new Date(a.ranAt).getTime());
    if (testRunStore.length > cfg.testHistoryMaxRuns) {
      testRunStore.splice(cfg.testHistoryMaxRuns);
    }

  } catch (err) {
    console.warn('[testRunParser] SSH refresh failed:', (err as Error).message);
  } finally {
    ssh.dispose();
  }
}

export function startTestRunParser(): void {
  if (parserIntervalHandle) return;

  refreshTestLogs().catch(e => console.error('[testRunParser] initial refresh:', e));

  parserIntervalHandle = setInterval(() => {
    refreshTestLogs().catch(e => console.error('[testRunParser] interval error:', e));
  }, 120_000);  // Refresh every 2 minutes

  console.log('[testRunParser] Started — refreshing every 120s');
}

export function stopTestRunParser(): void {
  if (parserIntervalHandle) {
    clearInterval(parserIntervalHandle);
    parserIntervalHandle = null;
  }
}

export function getLatestTestRun(): TestRun | null {
  return testRunStore[0] ?? null;
}

export function getTestRunHistory(limit = 20): TestRun[] {
  return testRunStore.slice(0, limit);
}

export function getTestRunById(id: string): TestRun | null {
  return testRunStore.find(r => r.id === id) ?? null;
}

export function getAgentTestResults(agentId: string, limit = 10): AgentTestResult[] {
  const results: AgentTestResult[] = [];
  for (const run of testRunStore) {
    const found = run.agentResults.find(a => a.agentId === agentId);
    if (found) results.push(found);
    if (results.length >= limit) break;
  }
  return results;
}
```

---

#### `backend/src/routes/tests.ts`

```typescript
import { Router, Request, Response } from 'express';
import { requireAuth } from '../middleware/auth';
import {
  getLatestTestRun,
  getTestRunHistory,
  getTestRunById,
  getAgentTestResults,
} from '../services/testRunParser';

const router = Router();
router.use(requireAuth);

/**
 * GET /api/tests/latest-run
 * Returns the most recent test-communication.sh execution.
 */
router.get('/latest-run', (_req: Request, res: Response) => {
  const run = getLatestTestRun();
  if (!run) {
    res.status(404).json({ ok: false, error: 'No test runs found' });
    return;
  }
  res.json({ ok: true, data: run });
});

/**
 * GET /api/tests/history?limit=20
 * Returns historical test run summaries.
 */
router.get('/history', (req: Request, res: Response) => {
  const limit = req.query.limit ? parseInt(req.query.limit as string, 10) : 20;
  const history = getTestRunHistory(limit);
  res.json({ ok: true, data: history });
});

/**
 * GET /api/tests/run/:runId
 * Returns a specific test run by ID.
 */
router.get('/run/:runId', (req: Request, res: Response) => {
  const run = getTestRunById(req.params.runId);
  if (!run) {
    res.status(404).json({ ok: false, error: `Test run ${req.params.runId} not found` });
    return;
  }
  res.json({ ok: true, data: run });
});

/**
 * GET /api/tests/agent-results/:agentId?limit=10
 * Returns historical gate results for a specific agent across runs.
 */
router.get('/agent-results/:agentId', (req: Request, res: Response) => {
  const { agentId } = req.params;
  const limit = req.query.limit ? parseInt(req.query.limit as string, 10) : 10;
  const results = getAgentTestResults(agentId, limit);
  res.json({ ok: true, data: results });
});

export default router;
```

---

### 4.5 G5 — Secrets & Token Inventory

#### `backend/src/services/secretsInventory.ts`

```typescript
/**
 * SECURITY NOTICE:
 * This service ONLY reads filesystem metadata (stat output: path, size, mtime, mode, owner).
 * Actual secret values are NEVER read, transmitted, logged, or stored.
 * The SSH commands used are limited to: stat, wc -l, test -f
 * No cat, echo, grep, awk, or any content-reading command is used.
 */

import { NodeSSH } from 'node-ssh';
import { loadConfig } from '../config';
import {
  SecretFile,
  VMSecretsCompliance,
  SecretsAlert,
  TokenTier,
} from '../types/infrastructure';

// In-memory store
const complianceMap = new Map<string, VMSecretsCompliance>();
const alertStore: SecretsAlert[] = [];
let inventoryIntervalHandle: ReturnType<typeof setInterval> | null = null;

const VM_SSH_HOSTS: Record<string, string> = {
  'vm-1': '100.73.38.28', 'vm-2': '100.95.30.11', 'vm-3': '100.81.114.55',
  'vm-4': '100.106.117.104', 'vm-5': '100.95.248.68',
};
const VM_HOSTNAMES: Record<string, string> = {
  'vm-1': 'tonic-architect', 'vm-2': 'tonic-designer', 'vm-3': 'tonic-developer',
  'vm-4': 'tonic-qc', 'vm-5': 'tonic-operator',
};
const VM_ROLES: Record<string, string> = {
  'vm-1': 'System Architect', 'vm-2': 'System Designer', 'vm-3': 'Developers',
  'vm-4': 'QC Agents', 'vm-5': 'Operator',
};
const VM_USERS: Record<string, string> = {
  'vm-1': 'gf', 'vm-2': 'gf', 'vm-3': 'gf', 'vm-4': 'gf', 'vm-5': 'gf',
};

/** Expected secret files per-VM. `owner` is a placeholder replaced by VM_USERS[vmId]. */
interface ExpectedSecretFile {
  path: (vmUser: string) => string;
  filename: string;
  tier: TokenTier;
  expectedMode: string;
  ownerIsRoot: boolean;
  expectedLineCount: number | null;
}

const EXPECTED_SECRET_FILES: ExpectedSecretFile[] = [
  {
    path: () => '/opt/secrets/gateforge.env',
    filename: 'gateforge.env',
    tier: 'platform',
    expectedMode: '600',
    ownerIsRoot: true,
    expectedLineCount: 3,  // HMAC_SECRET, ARCHITECT_HOOK_TOKEN, GATEWAY_API_KEY
  },
  {
    path: (vmUser) => `/home/${vmUser}/.config/gateforge/github-tokens.env`,
    filename: 'github-tokens.env',
    tier: 'github',
    expectedMode: '600',
    ownerIsRoot: false,
    expectedLineCount: 3,  // GITHUB_PAT, GITHUB_USERNAME, GITHUB_REPO
  },
  {
    path: (vmUser) => `/home/${vmUser}/.config/gateforge/llm.env`,
    filename: 'llm.env',
    tier: 'app',
    expectedMode: '600',
    ownerIsRoot: false,
    expectedLineCount: null,  // Variable by VM role
  },
];

// VM-1 only: Telegram app token
const ARCHITECT_ONLY_FILES: ExpectedSecretFile[] = [
  {
    path: (vmUser) => `/home/${vmUser}/.config/gateforge/telegram.env`,
    filename: 'telegram.env',
    tier: 'app',
    expectedMode: '600',
    ownerIsRoot: false,
    expectedLineCount: 2,  // TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID
  },
];

/**
 * Stat a single secrets file via SSH.
 * Returns only metadata — never file contents.
 */
async function statSecretFile(
  ssh: NodeSSH,
  spec: ExpectedSecretFile,
  vmId: string,
  staleDays: number
): Promise<SecretFile> {
  const vmUser = VM_USERS[vmId];
  const resolvedPath = spec.path(vmUser);
  const filename = spec.filename;
  const expectedOwner = spec.ownerIsRoot ? 'root' : vmUser;
  const expectedGroup = spec.ownerIsRoot ? 'root' : vmUser;

  // stat: permissions, owner, group, size, mtime (epoch)
  // wc -l: count lines (proxy for token count; no content revealed)
  // We use a single compound command that is safe and non-revealing.
  const statCmd = `stat -c '%a %U %G %s %Y' "${resolvedPath}" 2>/dev/null || echo MISSING`;
  const statResult = await ssh.execCommand(statCmd);
  const statOut = statResult.stdout.trim();

  if (statOut === 'MISSING') {
    return {
      path: resolvedPath,
      filename,
      tier: spec.tier,
      exists: false,
      sizeBytes: null,
      mtimeIso: null,
      mode: null,
      owner: null,
      group: null,
      lineCount: null,
      expectedLineCount: spec.expectedLineCount,
      permissionsCorrect: false,
      isStale: false,
      ageDays: null,
    };
  }

  const parts = statOut.split(' ');
  const [modeStr, owner, group, sizeStr, mtimeEpochStr] = parts;
  const sizeBytes = parseInt(sizeStr, 10);
  const mtimeEpoch = parseInt(mtimeEpochStr, 10);
  const mtimeIso = new Date(mtimeEpoch * 1000).toISOString();
  const ageDays = Math.floor((Date.now() - mtimeEpoch * 1000) / 86400_000);
  const isStale = ageDays >= staleDays;

  // Count lines WITHOUT reading content: wc -l is safe metadata
  const wcResult = await ssh.execCommand(`wc -l < "${resolvedPath}" 2>/dev/null || echo 0`);
  const lineCount = parseInt(wcResult.stdout.trim(), 10) || null;

  const permissionsCorrect =
    modeStr === spec.expectedMode &&
    owner === expectedOwner &&
    group === expectedGroup;

  return {
    path: resolvedPath,
    filename,
    tier: spec.tier,
    exists: true,
    sizeBytes,
    mtimeIso,
    mode: modeStr,
    owner,
    group,
    lineCount,
    expectedLineCount: spec.expectedLineCount,
    permissionsCorrect,
    isStale,
    ageDays,
  };
}

/** Run full secrets inventory for a single VM. */
async function inventoryVM(vmId: string): Promise<VMSecretsCompliance> {
  const cfg = loadConfig();
  const ip = VM_SSH_HOSTS[vmId];
  const hostname = VM_HOSTNAMES[vmId];
  const role = VM_ROLES[vmId];
  const ssh = new NodeSSH();
  const now = new Date().toISOString();

  try {
    await ssh.connect({
      host: ip,
      username: cfg.infraSshUser,
      privateKeyPath: cfg.infraSshKeyPath,
      readyTimeout: 8000,
    });

    const specsToCheck = [
      ...EXPECTED_SECRET_FILES,
      ...(vmId === 'vm-1' ? ARCHITECT_ONLY_FILES : []),
    ];

    const files: SecretFile[] = [];
    for (const spec of specsToCheck) {
      const f = await statSecretFile(ssh, spec, vmId, cfg.secretsStaleDays);
      files.push(f);

      // Generate alerts
      const alertBase = { vmId, hostname, filePath: f.path, detectedAt: now };
      if (!f.exists) {
        alertStore.push({
          id: `alert-${vmId}-missing-${f.filename}-${Date.now()}`,
          severity: 'critical',
          type: 'missing-file',
          message: `Missing secrets file: ${f.path}`,
          ...alertBase,
        });
      } else if (!f.permissionsCorrect) {
        alertStore.push({
          id: `alert-${vmId}-perms-${f.filename}-${Date.now()}`,
          severity: 'warning',
          type: 'wrong-permissions',
          message: `Incorrect permissions on ${f.path}: mode=${f.mode}, owner=${f.owner}`,
          ...alertBase,
        });
      } else if (f.isStale) {
        alertStore.push({
          id: `alert-${vmId}-stale-${f.filename}-${Date.now()}`,
          severity: 'warning',
          type: 'stale-token',
          message: `Stale secrets file: ${f.path} (${f.ageDays} days since last modification)`,
          ...alertBase,
        });
      }
      if (f.exists && f.expectedLineCount !== null && f.lineCount !== null &&
          f.lineCount < f.expectedLineCount) {
        alertStore.push({
          id: `alert-${vmId}-count-${f.filename}-${Date.now()}`,
          severity: 'warning',
          type: 'count-mismatch',
          message: `Token count mismatch in ${f.path}: expected ${f.expectedLineCount}, found ${f.lineCount}`,
          ...alertBase,
        });
      }
    }

    const presentCount      = files.filter(f => f.exists).length;
    const permCorrectCount  = files.filter(f => f.permissionsCorrect).length;
    const staleCount        = files.filter(f => f.isStale).length;
    const fullyCompliant    = presentCount === files.length && permCorrectCount === files.length && staleCount === 0;

    const result: VMSecretsCompliance = {
      vmId, hostname, tailscaleIp: ip, role,
      sshReachable: true,
      lastCheckedAt: now,
      files,
      presentCount,
      expectedCount: files.length,
      permCorrectCount,
      staleCount,
      fullyCompliant,
    };

    complianceMap.set(vmId, result);
    return result;

  } catch (err) {
    console.warn(`[secretsInventory] SSH failed for ${vmId}:`, (err as Error).message);
    alertStore.push({
      id: `alert-${vmId}-ssh-${Date.now()}`,
      vmId, hostname, filePath: '',
      severity: 'critical',
      type: 'ssh-unreachable',
      message: `SSH unreachable for ${hostname}: ${(err as Error).message}`,
      detectedAt: now,
    });
    const result: VMSecretsCompliance = {
      vmId, hostname, tailscaleIp: ip, role,
      sshReachable: false,
      lastCheckedAt: now,
      files: [],
      presentCount: 0,
      expectedCount: 0,
      permCorrectCount: 0,
      staleCount: 0,
      fullyCompliant: false,
    };
    complianceMap.set(vmId, result);
    return result;
  } finally {
    ssh.dispose();
  }
}

async function inventoryAll(): Promise<void> {
  for (const vmId of Object.keys(VM_SSH_HOSTS)) {
    await inventoryVM(vmId).catch(e => console.error(`[secretsInventory] ${vmId}:`, e.message));
  }
}

export function startSecretsInventory(): void {
  const cfg = loadConfig();
  if (inventoryIntervalHandle) return;

  inventoryAll().catch(e => console.error('[secretsInventory] initial pass error:', e));

  inventoryIntervalHandle = setInterval(() => {
    inventoryAll().catch(e => console.error('[secretsInventory] interval error:', e));
  }, cfg.secretsPollInterval * 1000);

  console.log(`[secretsInventory] Started — polling every ${cfg.secretsPollInterval}s`);
}

export function stopSecretsInventory(): void {
  if (inventoryIntervalHandle) {
    clearInterval(inventoryIntervalHandle);
    inventoryIntervalHandle = null;
  }
}

export function getAllSecretsCompliance(): VMSecretsCompliance[] {
  return Object.keys(VM_SSH_HOSTS)
    .map(id => complianceMap.get(id))
    .filter(Boolean) as VMSecretsCompliance[];
}

export function getVMSecretsCompliance(vmId: string): VMSecretsCompliance | null {
  return complianceMap.get(vmId) ?? null;
}

export function getSecretsAlerts(): SecretsAlert[] {
  // Deduplicate alerts: keep only most recent per (vmId, type, filePath)
  const seen = new Map<string, SecretsAlert>();
  for (const alert of [...alertStore].reverse()) {
    const key = `${alert.vmId}-${alert.type}-${alert.filePath}`;
    if (!seen.has(key)) seen.set(key, alert);
  }
  return [...seen.values()].sort((a, b) => {
    const sev = { critical: 0, warning: 1, info: 2 };
    return (sev[a.severity] - sev[b.severity]) || b.detectedAt.localeCompare(a.detectedAt);
  });
}
```

---

#### `backend/src/routes/secrets.ts`

```typescript
import { Router, Request, Response } from 'express';
import { requireAuth } from '../middleware/auth';
import {
  getAllSecretsCompliance,
  getVMSecretsCompliance,
  getSecretsAlerts,
} from '../services/secretsInventory';

const router = Router();
router.use(requireAuth);

/**
 * GET /api/secrets/inventory
 * Returns the full secrets compliance inventory for all VMs.
 * IMPORTANT: Contains ONLY metadata (path, size, mtime, permissions) — NEVER secret values.
 */
router.get('/inventory', (_req: Request, res: Response) => {
  const inventory = getAllSecretsCompliance();
  res.json({ ok: true, data: inventory });
});

/**
 * GET /api/secrets/inventory/:vmId
 * Returns the secrets compliance inventory for a single VM.
 */
router.get('/inventory/:vmId', (req: Request, res: Response) => {
  const compliance = getVMSecretsCompliance(req.params.vmId);
  if (!compliance) {
    res.status(404).json({ ok: false, error: `No inventory data for ${req.params.vmId}` });
    return;
  }
  res.json({ ok: true, data: compliance });
});

/**
 * GET /api/secrets/compliance
 * Returns a summary compliance matrix across all VMs.
 * { ok: true, data: Array<{ vmId, hostname, fullyCompliant, presentCount, expectedCount, ... }> }
 */
router.get('/compliance', (_req: Request, res: Response) => {
  const inventory = getAllSecretsCompliance();
  const matrix = inventory.map(v => ({
    vmId:            v.vmId,
    hostname:        v.hostname,
    sshReachable:    v.sshReachable,
    lastCheckedAt:   v.lastCheckedAt,
    fullyCompliant:  v.fullyCompliant,
    presentCount:    v.presentCount,
    expectedCount:   v.expectedCount,
    permCorrectCount: v.permCorrectCount,
    staleCount:      v.staleCount,
  }));
  res.json({ ok: true, data: matrix });
});

/**
 * GET /api/secrets/alerts
 * Returns deduplicated secrets compliance alerts across all VMs.
 */
router.get('/alerts', (_req: Request, res: Response) => {
  const alerts = getSecretsAlerts();
  res.json({ ok: true, data: alerts });
});

export default router;
```

---

### 4.6 G6 — OpenClaw Configuration Viewer

#### `backend/src/services/openclawConfigFetcher.ts`

```typescript
import { loadConfig } from '../config';
import { fetchAgentLogs } from './gatewayClient';
import {
  OpenClawConfig,
  OpenClawAgentDef,
  ConfigDiff,
  ConfigDiffField,
  ValidationResult,
  ConfigValidationCheck,
} from '../types/infrastructure';

// In-memory store
const configMap = new Map<string, OpenClawConfig>();
let fetcherIntervalHandle: ReturnType<typeof setInterval> | null = null;

const VM_META: Record<string, { hostname: string; tailscaleIp: string; role: string }> = {
  'vm-1': { hostname: 'tonic-architect', tailscaleIp: '100.73.38.28',    role: 'System Architect' },
  'vm-2': { hostname: 'tonic-designer',  tailscaleIp: '100.95.30.11',    role: 'System Designer'  },
  'vm-3': { hostname: 'tonic-developer', tailscaleIp: '100.81.114.55',   role: 'Developers'       },
  'vm-4': { hostname: 'tonic-qc',        tailscaleIp: '100.106.117.104', role: 'QC Agents'        },
  'vm-5': { hostname: 'tonic-operator',  tailscaleIp: '100.95.248.68',   role: 'Operator'         },
};

/** Parse raw openclaw.json content into an OpenClawConfig. */
function parseOpenClawJson(vmId: string, raw: string): OpenClawConfig {
  const meta = VM_META[vmId];
  const base: Omit<OpenClawConfig, 'bindMode' | 'gatewayPort' | 'tailscaleServeTarget' |
    'allowedOrigins' | 'agents' | 'injectedEnvVarNames'> = {
    vmId,
    hostname: meta.hostname,
    tailscaleIp: meta.tailscaleIp,
    role: meta.role,
    fetchedAt: new Date().toISOString(),
    available: true,
    rawJson: raw,
  };

  let parsed: Record<string, unknown>;
  try {
    parsed = JSON.parse(raw) as Record<string, unknown>;
  } catch {
    return {
      ...base,
      available: false,
      fetchError: 'Invalid JSON in openclaw.json',
      bindMode: null, gatewayPort: null, tailscaleServeTarget: null,
      allowedOrigins: [], agents: [], injectedEnvVarNames: [],
    };
  }

  const gateway = (parsed.gateway ?? {}) as Record<string, unknown>;
  const serve   = (parsed.serve ?? parsed.tailscaleServe ?? {}) as Record<string, unknown>;
  const rawAgents = Array.isArray(parsed.agents) ? parsed.agents : [];

  const agents: OpenClawAgentDef[] = rawAgents.map((a: unknown) => {
    const agent = a as Record<string, unknown>;
    return {
      id:              String(agent.id ?? agent.name ?? ''),
      model:           String(agent.model ?? ''),
      systemPromptRef: agent.systemPrompt ? String(agent.systemPrompt) : null,
      tools:           Array.isArray(agent.tools) ? (agent.tools as string[]) : [],
      envVarNames:     Array.isArray(agent.env) ? (agent.env as string[]).map(e => e.split('=')[0]) : [],
    };
  });

  // Collect all env var names from agents
  const injectedEnvVarNames = [...new Set(agents.flatMap(a => a.envVarNames))];

  return {
    ...base,
    bindMode:             String(gateway.bind ?? gateway.bindMode ?? ''),
    gatewayPort:          typeof gateway.port === 'number' ? gateway.port : null,
    tailscaleServeTarget: serve.target ? String(serve.target) : null,
    allowedOrigins:       Array.isArray(parsed.allowedOrigins)
                            ? (parsed.allowedOrigins as string[])
                            : [],
    agents,
    injectedEnvVarNames,
  };
}

/** Fetch openclaw.json for a single VM via the gateway API. */
async function fetchVMConfig(vmId: string): Promise<void> {
  const cfg = loadConfig();
  const vmConf = cfg.vms.find(v => v.id === vmId);
  const meta = VM_META[vmId];
  if (!vmConf || !meta) return;

  try {
    // Fetch the config file content via the gateway's file-read endpoint
    const data = await fetchAgentLogs(vmConf, `config/openclaw`) as unknown;
    const raw = typeof data === 'string' ? data : JSON.stringify(data);
    const config = parseOpenClawJson(vmId, raw);
    configMap.set(vmId, config);
  } catch (err) {
    console.warn(`[openclawConfigFetcher] ${vmId}:`, (err as Error).message);
    configMap.set(vmId, {
      vmId, hostname: meta.hostname, tailscaleIp: meta.tailscaleIp, role: meta.role,
      fetchedAt: new Date().toISOString(),
      available: false,
      fetchError: (err as Error).message,
      rawJson: '',
      bindMode: null, gatewayPort: null, tailscaleServeTarget: null,
      allowedOrigins: [], agents: [], injectedEnvVarNames: [],
    });
  }
}

async function fetchAll(): Promise<void> {
  await Promise.allSettled(Object.keys(VM_META).map(fetchVMConfig));
}

export function startOpenClawConfigFetcher(): void {
  const cfg = loadConfig();
  if (fetcherIntervalHandle) return;

  fetchAll().catch(e => console.error('[openclawConfigFetcher] initial fetch error:', e));

  fetcherIntervalHandle = setInterval(() => {
    fetchAll().catch(e => console.error('[openclawConfigFetcher] interval error:', e));
  }, cfg.openclawPollInterval * 1000);

  console.log(`[openclawConfigFetcher] Started — polling every ${cfg.openclawPollInterval}s`);
}

export function stopOpenClawConfigFetcher(): void {
  if (fetcherIntervalHandle) {
    clearInterval(fetcherIntervalHandle);
    fetcherIntervalHandle = null;
  }
}

export function getAllOpenClawConfigs(): OpenClawConfig[] {
  return Object.keys(VM_META).map(id => configMap.get(id)).filter(Boolean) as OpenClawConfig[];
}

export function getOpenClawConfig(vmId: string): OpenClawConfig | null {
  return configMap.get(vmId) ?? null;
}

/**
 * Compute a field-level diff between two VMs' openclaw.json configs.
 * Uses a flat key comparison of the parsed JSON structures.
 */
export function diffConfigs(fromVmId: string, toVmId: string): ConfigDiff | null {
  const fromCfg = configMap.get(fromVmId);
  const toCfg   = configMap.get(toVmId);
  if (!fromCfg || !toCfg) return null;

  const fields: ConfigDiffField[] = [];

  let fromParsed: Record<string, unknown> = {};
  let toParsed:   Record<string, unknown> = {};

  try { fromParsed = JSON.parse(fromCfg.rawJson); } catch { /* ignored */ }
  try { toParsed   = JSON.parse(toCfg.rawJson);   } catch { /* ignored */ }

  flatDiff(fromParsed, toParsed, '', fields);

  const SIGNIFICANT_PATHS = ['gateway.port', 'gateway.bind', 'gateway.bindMode', 'serve.target'];

  return {
    fromVmId, toVmId,
    fromHostname: fromCfg.hostname,
    toHostname:   toCfg.hostname,
    generatedAt:  new Date().toISOString(),
    diffCount:    fields.length,
    hasSignificantDiffs: fields.some(f => SIGNIFICANT_PATHS.some(p => f.path.startsWith(p))),
    fields,
  };
}

function flatDiff(
  obj1: Record<string, unknown>,
  obj2: Record<string, unknown>,
  prefix: string,
  result: ConfigDiffField[]
): void {
  const keys = new Set([...Object.keys(obj1), ...Object.keys(obj2)]);
  for (const key of keys) {
    const path = prefix ? `${prefix}.${key}` : key;
    const v1 = obj1[key], v2 = obj2[key];

    if (typeof v1 === 'object' && typeof v2 === 'object' &&
        v1 !== null && v2 !== null && !Array.isArray(v1) && !Array.isArray(v2)) {
      flatDiff(
        v1 as Record<string, unknown>,
        v2 as Record<string, unknown>,
        path, result
      );
    } else if (JSON.stringify(v1) !== JSON.stringify(v2)) {
      const SIGNIFICANT_PATHS = ['gateway.port', 'gateway.bind', 'serve.target'];
      result.push({
        path, fromValue: v1, toValue: v2,
        significant: SIGNIFICANT_PATHS.some(p => path.startsWith(p)),
      });
    }
  }
}

/** Validate a single VM's openclaw.json against expected settings. */
export function validateConfig(vmId: string): ValidationResult | null {
  const config = configMap.get(vmId);
  if (!config) return null;

  const allVMOrigins = Object.values(VM_META)
    .map(m => `https://${m.hostname}.sailfish-bass.ts.net`);

  const checks: ConfigValidationCheck[] = [];

  // Check 1: Bind mode must be loopback/127.0.0.1
  const bindOk = config.bindMode === 'loopback' || config.bindMode === '127.0.0.1';
  checks.push({
    id: 'bind-mode-loopback',
    name: 'Bind mode is loopback',
    status: bindOk ? 'pass' : 'fail',
    detail: bindOk
      ? `Bind mode: ${config.bindMode} ✓`
      : `Bind mode is '${config.bindMode}' — expected 'loopback' or '127.0.0.1'`,
  });

  // Check 2: Gateway port must be 18789
  const portOk = config.gatewayPort === 18789;
  checks.push({
    id: 'port-18789',
    name: 'Gateway port 18789',
    status: portOk ? 'pass' : 'fail',
    detail: portOk
      ? 'Gateway port: 18789 ✓'
      : `Gateway port is ${config.gatewayPort} — expected 18789`,
  });

  // Check 3: All 5 VM origins present in allowedOrigins
  const missingOrigins = allVMOrigins.filter(o => !config.allowedOrigins.includes(o));
  checks.push({
    id: 'all-origins-present',
    name: 'All 5 VM domains in allowedOrigins',
    status: missingOrigins.length === 0 ? 'pass' : 'warn',
    detail: missingOrigins.length === 0
      ? 'All 5 VM Tailscale domains present in allowedOrigins ✓'
      : `Missing from allowedOrigins: ${missingOrigins.join(', ')}`,
  });

  // Check 4: Tailscale Serve target matches expected FQDN and port
  const expectedServeTarget = `https://${VM_META[vmId]?.hostname}.sailfish-bass.ts.net:18789`;
  const serveOk = config.tailscaleServeTarget === expectedServeTarget;
  checks.push({
    id: 'tailscale-serve-target',
    name: 'Tailscale Serve target matches FQDN:18789',
    status: config.tailscaleServeTarget ? (serveOk ? 'pass' : 'warn') : 'warn',
    detail: config.tailscaleServeTarget
      ? (serveOk ? `Serve target: ${config.tailscaleServeTarget} ✓`
                 : `Serve target mismatch: got '${config.tailscaleServeTarget}', expected '${expectedServeTarget}'`)
      : 'Tailscale Serve target not configured',
  });

  // Check 5: No agent references an env var not in injectedEnvVarNames
  const allAgentEnvVars = config.agents.flatMap(a => a.envVarNames);
  const undeclaredVars = allAgentEnvVars.filter(v => !config.injectedEnvVarNames.includes(v));
  checks.push({
    id: 'no-undeclared-env-vars',
    name: 'All agent env vars declared',
    status: undeclaredVars.length === 0 ? 'pass' : 'warn',
    detail: undeclaredVars.length === 0
      ? 'All agent env var references are declared ✓'
      : `Undeclared agent env var references: ${undeclaredVars.join(', ')}`,
  });

  return {
    vmId,
    hostname: config.hostname,
    valid: checks.every(c => c.status === 'pass'),
    checks,
  };
}

/** Validate all VMs and return results. */
export function validateAllConfigs(): ValidationResult[] {
  return Object.keys(VM_META)
    .map(validateConfig)
    .filter(Boolean) as ValidationResult[];
}
```

---

#### `backend/src/routes/openclaw-config.ts`

```typescript
import { Router, Request, Response } from 'express';
import { requireAuth } from '../middleware/auth';
import {
  getAllOpenClawConfigs,
  getOpenClawConfig,
  diffConfigs,
  validateConfig,
  validateAllConfigs,
} from '../services/openclawConfigFetcher';

const router = Router();
router.use(requireAuth);

/**
 * GET /api/openclaw-config/all
 * Returns openclaw.json configs for all 5 VMs.
 */
router.get('/all', (_req: Request, res: Response) => {
  const configs = getAllOpenClawConfigs();
  res.json({ ok: true, data: configs });
});

/**
 * GET /api/openclaw-config/:vmId
 * Returns the openclaw.json config for a single VM.
 */
router.get('/:vmId', (req: Request, res: Response) => {
  const config = getOpenClawConfig(req.params.vmId);
  if (!config) {
    res.status(404).json({ ok: false, error: `No config data for ${req.params.vmId}` });
    return;
  }
  res.json({ ok: true, data: config });
});

/**
 * GET /api/openclaw-config/diff?from=vm-1&to=vm-3
 * Returns a field-level diff between two VMs' openclaw.json configs.
 */
router.get('/diff', (req: Request, res: Response) => {
  const fromVmId = req.query.from as string;
  const toVmId   = req.query.to   as string;

  if (!fromVmId || !toVmId) {
    res.status(400).json({ ok: false, error: 'Query params `from` and `to` are required' });
    return;
  }
  if (fromVmId === toVmId) {
    res.status(400).json({ ok: false, error: '`from` and `to` must be different VMs' });
    return;
  }

  const diff = diffConfigs(fromVmId, toVmId);
  if (!diff) {
    res.status(404).json({ ok: false, error: `Config data not available for ${fromVmId} or ${toVmId}` });
    return;
  }
  res.json({ ok: true, data: diff });
});

/**
 * GET /api/openclaw-config/validation/all
 * Returns validation results for all VMs.
 */
router.get('/validation/all', (_req: Request, res: Response) => {
  const results = validateAllConfigs();
  res.json({ ok: true, data: results });
});

/**
 * GET /api/openclaw-config/validation/:vmId
 * Returns validation results for a single VM.
 */
router.get('/validation/:vmId', (req: Request, res: Response) => {
  const result = validateConfig(req.params.vmId);
  if (!result) {
    res.status(404).json({ ok: false, error: `No config data for ${req.params.vmId}` });
    return;
  }
  res.json({ ok: true, data: result });
});

export default router;
```

---

### 4.7 Updated `index.ts` Route Registration

Add the following to `backend/src/index.ts` after the v2.5 routes block:

```typescript
// ─── v3.0 Routes — Category G: Infrastructure & Connectivity ─────────────────
import networkRouter           from './routes/network';
import notificationsDeliveryRouter from './routes/notifications-delivery';
import setupStatusRouter       from './routes/setup-status';
import testsRouter             from './routes/tests';
import secretsRouter           from './routes/secrets';
import openclawConfigRouter    from './routes/openclaw-config';

app.use('/api/network',                  networkRouter);
app.use('/api/notifications-delivery',   notificationsDeliveryRouter);
app.use('/api/setup-status',             setupStatusRouter);
app.use('/api/tests',                    testsRouter);
app.use('/api/secrets',                  secretsRouter);
app.use('/api/openclaw-config',          openclawConfigRouter);

// In the startup block, add after startPoller():
import { startNetworkProbe }           from './services/networkProbe';
import { startNotificationMonitor }    from './services/notificationMonitor';
import { startSetupValidator }         from './services/setupValidator';
import { startTestRunParser }          from './services/testRunParser';
import { startSecretsInventory }       from './services/secretsInventory';
import { startOpenClawConfigFetcher }  from './services/openclawConfigFetcher';

// Add to app.listen callback:
startNetworkProbe();
startNotificationMonitor();
startSetupValidator();
startTestRunParser();
startSecretsInventory();
startOpenClawConfigFetcher();
console.log('[infra] Category G background services started');
```

---

## 5. Frontend Implementation

### 5.1 G1 — Network Topology & Health Monitor

#### `frontend/src/hooks/useNetworkTopology.ts`

```typescript
'use client';
import { useQuery } from '@tanstack/react-query';
import { api } from '@/lib/api';
import { NetworkTopology, VMHealth, LatencyPoint } from '@/types/infrastructure';

const REFETCH_INTERVAL = 30_000;  // Match backend probe interval

export function useNetworkTopology() {
  return useQuery<NetworkTopology>({
    queryKey: ['network', 'topology'],
    queryFn: async () => {
      const res = await api.get<NetworkTopology>('/api/network/topology');
      return res.data;
    },
    refetchInterval: REFETCH_INTERVAL,
    staleTime: 15_000,
  });
}

export function useVMHealth(vmId: string) {
  return useQuery<VMHealth>({
    queryKey: ['network', 'vm-status', vmId],
    queryFn: async () => {
      const res = await api.get<VMHealth>(`/api/network/vm-status/${vmId}`);
      return res.data;
    },
    refetchInterval: REFETCH_INTERVAL,
    staleTime: 15_000,
    enabled: !!vmId,
  });
}

export function useLatencyHistory(vmId: string, last = 60) {
  return useQuery<LatencyPoint[]>({
    queryKey: ['network', 'latency-history', vmId, last],
    queryFn: async () => {
      const res = await api.get<LatencyPoint[]>(`/api/network/latency-history/${vmId}?last=${last}`);
      return res.data;
    },
    refetchInterval: REFETCH_INTERVAL,
    staleTime: 15_000,
    enabled: !!vmId,
  });
}
```

---

#### `frontend/src/components/infrastructure/network/VMHealthCard.tsx`

```typescript
'use client';
import { VMHealth, VMHealthStatus } from '@/types/infrastructure';
import { cn } from '@/lib/utils';

interface VMHealthCardProps {
  vm: VMHealth;
  selected?: boolean;
  onClick?: (vmId: string) => void;
}

const STATUS_CONFIG: Record<VMHealthStatus, {
  bg: string; border: string; dot: string; label: string; animation: string;
}> = {
  healthy:     { bg: 'bg-[#052e16]/60', border: 'border-[#16a34a]', dot: 'bg-[#22c55e]', label: 'HEALTHY',     animation: 'animate-ping'      },
  degraded:    { bg: 'bg-[#431407]/60', border: 'border-[#f97316]', dot: 'bg-[#f97316]', label: 'DEGRADED',    animation: 'animate-slow-blink' },
  unreachable: { bg: 'bg-[#450a0a]/60', border: 'border-[#ef4444]', dot: 'bg-[#ef4444]', label: 'UNREACHABLE', animation: 'animate-fast-blink' },
  unknown:     { bg: 'bg-slate-900/60', border: 'border-slate-600', dot: 'bg-slate-500', label: 'UNKNOWN',     animation: ''                  },
};

export function VMHealthCard({ vm, selected, onClick }: VMHealthCardProps) {
  const cfg = STATUS_CONFIG[vm.status];

  return (
    <div
      role={onClick ? 'button' : undefined}
      tabIndex={onClick ? 0 : undefined}
      onClick={() => onClick?.(vm.vmId)}
      onKeyDown={(e) => e.key === 'Enter' && onClick?.(vm.vmId)}
      className={cn(
        'relative rounded-xl border p-4 transition-all cursor-pointer',
        cfg.bg, cfg.border,
        selected && 'ring-2 ring-[#06B6D4]/60',
        'hover:brightness-110'
      )}
    >
      {/* Status dot */}
      <span className="absolute top-3 right-3 inline-flex h-2.5 w-2.5 rounded-full">
        {vm.status === 'healthy' && (
          <span className={cn('animate-ping absolute inline-flex h-full w-full rounded-full opacity-75', cfg.dot)} />
        )}
        <span className={cn('relative inline-flex rounded-full h-2.5 w-2.5', cfg.dot,
          vm.status !== 'healthy' ? cfg.animation : ''
        )} />
      </span>

      {/* VM identifier */}
      <div className="font-mono text-xs text-slate-400 mb-0.5">{vm.vmId.toUpperCase()}</div>
      <div className="font-semibold text-white text-sm truncate">{vm.hostname}</div>
      <div className="text-[10px] text-slate-400 font-mono mb-2">{vm.tailscaleIp}</div>

      {/* Role */}
      <div className="text-xs text-slate-300 mb-3 truncate">{vm.role}</div>

      {/* Status badge */}
      <div className={cn(
        'inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-mono font-bold',
        vm.status === 'healthy'     && 'bg-[#16a34a]/20 text-[#22c55e]',
        vm.status === 'degraded'    && 'bg-[#ea580c]/20 text-[#f97316]',
        vm.status === 'unreachable' && 'bg-[#dc2626]/20 text-[#ef4444]',
        vm.status === 'unknown'     && 'bg-slate-700/40 text-slate-400',
      )}>
        {cfg.label}
      </div>

      {/* Latency */}
      <div className="mt-2 text-xs text-slate-400">
        {vm.latencyMs !== null
          ? <span className={vm.latencyMs > 500 ? 'text-[#f97316]' : 'text-[#22c55e]'}>
              {vm.latencyMs}ms
            </span>
          : <span className="text-slate-500">—</span>
        }
        <span className="ml-1 text-slate-600">latency</span>
      </div>

      {/* Consecutive failures badge */}
      {vm.consecutiveFailures > 0 && (
        <div className="mt-1 text-[10px] text-[#ef4444] font-mono">
          {vm.consecutiveFailures} consecutive failure{vm.consecutiveFailures !== 1 ? 's' : ''}
        </div>
      )}
    </div>
  );
}
```

---

#### `frontend/src/components/infrastructure/network/LatencyChart.tsx`

```typescript
'use client';
import { LatencyPoint } from '@/types/infrastructure';
import {
  LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, ReferenceLine,
} from 'recharts';
import { format } from 'date-fns';

interface LatencyChartProps {
  data: LatencyPoint[];
  vmHostname: string;
}

export function LatencyChart({ data, vmHostname }: LatencyChartProps) {
  const chartData = data.map(p => ({
    time: format(new Date(p.timestamp), 'HH:mm:ss'),
    latency: p.ok ? p.latencyMs : null,
    timeout: p.ok ? null : 0,
  }));

  return (
    <div className="rounded-xl border border-slate-700/50 bg-slate-900/60 p-4">
      <div className="text-sm font-semibold text-slate-300 mb-1">
        Latency — <span className="font-mono text-[#06B6D4]">{vmHostname}</span>
      </div>
      <div className="text-xs text-slate-500 mb-4">Last {data.length} probes (30s interval)</div>

      <ResponsiveContainer width="100%" height={160}>
        <LineChart data={chartData} margin={{ top: 4, right: 8, left: -16, bottom: 0 }}>
          <XAxis
            dataKey="time"
            tick={{ fill: '#475569', fontSize: 10 }}
            tickLine={false}
            interval="preserveStartEnd"
          />
          <YAxis
            tick={{ fill: '#475569', fontSize: 10 }}
            tickLine={false}
            unit="ms"
          />
          <Tooltip
            contentStyle={{
              background: '#0F172A',
              border: '1px solid #334155',
              borderRadius: '8px',
              fontSize: '12px',
            }}
            labelStyle={{ color: '#94a3b8' }}
            formatter={(value: number) => [`${value}ms`, 'Latency']}
          />
          <ReferenceLine y={500} stroke="#f97316" strokeDasharray="4 2" strokeOpacity={0.5} />
          <Line
            type="monotone"
            dataKey="latency"
            stroke="#06B6D4"
            strokeWidth={1.5}
            dot={false}
            activeDot={{ r: 3, fill: '#06B6D4' }}
            connectNulls={false}
          />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}
```

---

#### `frontend/src/components/infrastructure/network/NetworkTopologyDiagram.tsx`

```typescript
'use client';
import { NetworkTopology } from '@/types/infrastructure';
import { cn } from '@/lib/utils';

interface NetworkTopologyDiagramProps {
  topology: NetworkTopology;
  selectedVmId: string | null;
  onSelectVM: (vmId: string) => void;
}

/** Static SVG positions for 5 VMs in a hub-and-spoke layout */
const VM_POSITIONS: Record<string, { cx: number; cy: number }> = {
  'vm-1': { cx: 300, cy: 160 },  // Hub (centre-top)
  'vm-2': { cx: 120, cy: 280 },  // Designer (left)
  'vm-3': { cx: 220, cy: 380 },  // Developer (lower-left)
  'vm-4': { cx: 380, cy: 380 },  // QC (lower-right)
  'vm-5': { cx: 480, cy: 280 },  // Operator (right)
};

const STATUS_COLORS: Record<string, string> = {
  healthy: '#22c55e', degraded: '#f97316', unreachable: '#ef4444', unknown: '#6b7280',
};

export function NetworkTopologyDiagram({
  topology, selectedVmId, onSelectVM,
}: NetworkTopologyDiagramProps) {
  const vmMap = Object.fromEntries(topology.vms.map(v => [v.vmId, v]));

  return (
    <div className="rounded-xl border border-slate-700/50 bg-slate-900/60 p-4">
      <div className="text-sm font-semibold text-slate-300 mb-1">Network Topology</div>
      <div className="text-xs text-slate-500 mb-3">
        Tailscale VPN — sailfish-bass.ts.net
      </div>

      <svg
        viewBox="0 0 600 460"
        className="w-full"
        style={{ maxHeight: 280 }}
      >
        {/* Draw edges from hub (vm-1) to all spokes */}
        {(['vm-2', 'vm-3', 'vm-4', 'vm-5'] as const).map(vmId => {
          const hub = VM_POSITIONS['vm-1'];
          const spoke = VM_POSITIONS[vmId];
          const vm = vmMap[vmId];
          const color = STATUS_COLORS[vm?.status ?? 'unknown'];
          return (
            <line
              key={vmId}
              x1={hub.cx} y1={hub.cy}
              x2={spoke.cx} y2={spoke.cy}
              stroke={color}
              strokeWidth={vm?.status === 'healthy' ? 1.5 : 1}
              strokeOpacity={vm?.status === 'healthy' ? 0.6 : 0.3}
              strokeDasharray={vm?.status !== 'healthy' ? '6 3' : undefined}
            />
          );
        })}

        {/* Draw VM nodes */}
        {topology.vms.map(vm => {
          const pos = VM_POSITIONS[vm.vmId];
          if (!pos) return null;
          const color = STATUS_COLORS[vm.status];
          const isSelected = vm.vmId === selectedVmId;
          const isHub = vm.vmId === 'vm-1';

          return (
            <g
              key={vm.vmId}
              transform={`translate(${pos.cx}, ${pos.cy})`}
              style={{ cursor: 'pointer' }}
              onClick={() => onSelectVM(vm.vmId)}
              role="button"
              aria-label={`${vm.hostname}: ${vm.status}`}
            >
              {/* Selection ring */}
              {isSelected && (
                <circle r={isHub ? 36 : 30} fill="none" stroke="#06B6D4" strokeWidth={2} strokeOpacity={0.8} />
              )}
              {/* Hub ring */}
              {isHub && (
                <circle r={32} fill="none" stroke={color} strokeWidth={1.5} strokeOpacity={0.4} strokeDasharray="4 2" />
              )}
              {/* Node circle */}
              <circle
                r={isHub ? 28 : 22}
                fill={`${color}18`}
                stroke={color}
                strokeWidth={isHub ? 2 : 1.5}
              />
              {/* VM label */}
              <text
                textAnchor="middle" dominantBaseline="middle"
                fill={color} fontSize={isHub ? 11 : 10}
                fontWeight="bold" fontFamily="monospace"
              >
                {vm.vmId.toUpperCase()}
              </text>
              {/* Hostname below */}
              <text
                y={isHub ? 38 : 32}
                textAnchor="middle"
                fill="#94a3b8" fontSize={9}
                fontFamily="monospace"
              >
                {vm.hostname}
              </text>
              {/* Latency below hostname */}
              {vm.latencyMs !== null && (
                <text
                  y={isHub ? 50 : 43}
                  textAnchor="middle"
                  fill={vm.latencyMs > 500 ? '#f97316' : '#22c55e'}
                  fontSize={8} fontFamily="monospace"
                >
                  {vm.latencyMs}ms
                </text>
              )}
            </g>
          );
        })}
      </svg>
    </div>
  );
}
```

---

#### `frontend/src/app/(portal)/infrastructure/network/page.tsx`

```typescript
'use client';
import { useState } from 'react';
import { useNetworkTopology, useLatencyHistory } from '@/hooks/useNetworkTopology';
import { NetworkTopologyDiagram } from '@/components/infrastructure/network/NetworkTopologyDiagram';
import { VMHealthCard } from '@/components/infrastructure/network/VMHealthCard';
import { LatencyChart } from '@/components/infrastructure/network/LatencyChart';
import { cn } from '@/lib/utils';

const FLEET_STATUS_CONFIG = {
  'all-healthy': { color: 'text-[#22c55e]', bg: 'bg-[#052e16]/40', label: 'All Healthy' },
  'degraded':    { color: 'text-[#f97316]', bg: 'bg-[#431407]/40', label: 'Degraded'    },
  'partial':     { color: 'text-[#ca8a04]', bg: 'bg-[#422006]/40', label: 'Partial'     },
  'down':        { color: 'text-[#ef4444]', bg: 'bg-[#450a0a]/40', label: 'Down'        },
};

export default function NetworkTopologyPage() {
  const { data: topology, isLoading, error } = useNetworkTopology();
  const [selectedVmId, setSelectedVmId] = useState<string | null>('vm-1');
  const selectedVm = topology?.vms.find(v => v.vmId === selectedVmId);

  const { data: latencyHistory } = useLatencyHistory(selectedVmId ?? 'vm-1', 60);

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64 text-slate-400 text-sm">
        Loading network topology…
      </div>
    );
  }

  if (error || !topology) {
    return (
      <div className="flex items-center justify-center h-64 text-[#ef4444] text-sm">
        Failed to load network topology. Check backend connectivity.
      </div>
    );
  }

  const fleetCfg = FLEET_STATUS_CONFIG[topology.fleetStatus];

  return (
    <div className="space-y-6">
      {/* Page header */}
      <div className="flex items-start justify-between">
        <div>
          <h1 className="text-xl font-bold text-white">Network Topology</h1>
          <p className="text-sm text-slate-400 mt-0.5">
            Tailscale VPN — sailfish-bass.ts.net — 5 VMs
          </p>
        </div>
        <div className={cn('px-3 py-1.5 rounded-full text-xs font-bold font-mono', fleetCfg.bg, fleetCfg.color)}>
          {fleetCfg.label}
          {topology.avgLatencyMs !== null && (
            <span className="ml-2 opacity-70">avg {Math.round(topology.avgLatencyMs)}ms</span>
          )}
        </div>
      </div>

      {/* Unreachable alert banner */}
      {topology.unreachableVmIds.length > 0 && (
        <div className="rounded-xl border border-[#dc2626]/50 bg-[#450a0a]/40 px-4 py-3 text-sm text-[#ef4444]">
          ⚠ Unreachable: {topology.unreachableVmIds.join(', ')} — check Tailscale VPN and OpenClaw service status
        </div>
      )}

      {/* Main layout: topology diagram + VM cards */}
      <div className="grid grid-cols-1 xl:grid-cols-3 gap-4">
        {/* Topology diagram */}
        <div className="xl:col-span-1">
          <NetworkTopologyDiagram
            topology={topology}
            selectedVmId={selectedVmId}
            onSelectVM={setSelectedVmId}
          />
        </div>

        {/* VM health cards */}
        <div className="xl:col-span-2 grid grid-cols-2 md:grid-cols-3 xl:grid-cols-3 gap-3">
          {topology.vms.map(vm => (
            <VMHealthCard
              key={vm.vmId}
              vm={vm}
              selected={vm.vmId === selectedVmId}
              onClick={setSelectedVmId}
            />
          ))}
        </div>
      </div>

      {/* Selected VM latency chart */}
      {selectedVm && latencyHistory && (
        <LatencyChart
          data={latencyHistory}
          vmHostname={selectedVm.fqdn}
        />
      )}

      {/* Selected VM detail */}
      {selectedVm && (
        <div className="rounded-xl border border-slate-700/50 bg-slate-900/60 p-4">
          <div className="text-sm font-semibold text-slate-300 mb-3">
            VM Detail — <span className="font-mono text-[#06B6D4]">{selectedVm.hostname}</span>
          </div>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-xs">
            {[
              { label: 'Tailscale IP',    value: selectedVm.tailscaleIp },
              { label: 'FQDN',            value: selectedVm.fqdn },
              { label: 'Role',            value: selectedVm.role },
              { label: 'Gateway Version', value: selectedVm.gatewayVersion ?? '—' },
              { label: 'Last Probe',      value: new Date(selectedVm.lastProbeAt).toLocaleTimeString() },
              { label: 'Last Seen',       value: selectedVm.lastSeenAt ? new Date(selectedVm.lastSeenAt).toLocaleTimeString() : '—' },
              { label: 'Latency',         value: selectedVm.latencyMs !== null ? `${selectedVm.latencyMs}ms` : '—' },
              { label: 'Failures',        value: String(selectedVm.consecutiveFailures) },
            ].map(({ label, value }) => (
              <div key={label}>
                <div className="text-slate-500 mb-0.5">{label}</div>
                <div className="text-slate-200 font-mono truncate">{value}</div>
              </div>
            ))}
          </div>
        </div>
      )}

      <div className="text-xs text-slate-600 text-right">
        Auto-refreshes every 30s · Last snapshot: {new Date(topology.capturedAt).toLocaleTimeString()}
      </div>
    </div>
  );
}
```

---

### 5.2 G2 — Notification Delivery Tracker

#### `frontend/src/hooks/useNotificationDelivery.ts`

```typescript
'use client';
import { useQuery } from '@tanstack/react-query';
import { api } from '@/lib/api';
import {
  NotificationEvent,
  NotificationDeliveryStats,
  DeadLetterEntry,
  TrailerCompliance,
} from '@/types/infrastructure';

const REFETCH_INTERVAL = 15_000;

export function useNotificationLog(opts?: {
  limit?: number;
  vmId?: string;
  priority?: string;
  status?: string;
}) {
  const params = new URLSearchParams();
  if (opts?.limit)    params.set('limit',    String(opts.limit));
  if (opts?.vmId)     params.set('vmId',     opts.vmId);
  if (opts?.priority) params.set('priority', opts.priority);
  if (opts?.status)   params.set('status',   opts.status);

  return useQuery<NotificationEvent[]>({
    queryKey: ['notifications-delivery', 'log', opts],
    queryFn: async () => {
      const res = await api.get<NotificationEvent[]>(
        `/api/notifications-delivery/log?${params.toString()}`
      );
      return res.data;
    },
    refetchInterval: REFETCH_INTERVAL,
  });
}

export function useDeliveryStats(period: NotificationDeliveryStats['period'] = '24h') {
  return useQuery<NotificationDeliveryStats>({
    queryKey: ['notifications-delivery', 'stats', period],
    queryFn: async () => {
      const res = await api.get<NotificationDeliveryStats>(
        `/api/notifications-delivery/stats?period=${period}`
      );
      return res.data;
    },
    refetchInterval: REFETCH_INTERVAL,
  });
}

export function useDeadLetters(limit = 50) {
  return useQuery<DeadLetterEntry[]>({
    queryKey: ['notifications-delivery', 'dead-letters', limit],
    queryFn: async () => {
      const res = await api.get<DeadLetterEntry[]>(
        `/api/notifications-delivery/dead-letters?limit=${limit}`
      );
      return res.data;
    },
    refetchInterval: REFETCH_INTERVAL,
  });
}

export function useTrailerCompliance() {
  return useQuery<TrailerCompliance[]>({
    queryKey: ['notifications-delivery', 'trailer-compliance'],
    queryFn: async () => {
      const res = await api.get<TrailerCompliance[]>(
        '/api/notifications-delivery/trailer-compliance'
      );
      return res.data;
    },
    refetchInterval: 60_000,
  });
}
```

---

#### `frontend/src/components/infrastructure/notify/TrailerComplianceBadge.tsx`

```typescript
'use client';
import { TrailerCompliance } from '@/types/infrastructure';
import { cn } from '@/lib/utils';

interface TrailerComplianceBadgeProps {
  compliance: TrailerCompliance;
  showBreakdown?: boolean;
}

export function TrailerComplianceBadge({ compliance, showBreakdown }: TrailerComplianceBadgeProps) {
  const pct = Math.round(compliance.complianceRate * 100);
  const color =
    pct >= 95 ? '#22c55e' :
    pct >= 80 ? '#ca8a04' : '#ef4444';

  return (
    <div className="rounded-lg border border-slate-700/50 bg-slate-800/60 p-3">
      <div className="flex items-center justify-between mb-1">
        <span className="text-xs font-mono text-slate-400">{compliance.hostname}</span>
        <span className="text-xs font-mono font-bold" style={{ color }}>{pct}%</span>
      </div>

      {/* Progress bar */}
      <div className="h-1.5 rounded-full bg-slate-700/60 overflow-hidden mb-2">
        <div
          className="h-full rounded-full transition-all duration-500"
          style={{ width: `${pct}%`, backgroundColor: color }}
        />
      </div>

      <div className="text-[10px] text-slate-500">
        {compliance.compliantCommits}/{compliance.totalCommits} commits complete
      </div>

      {/* Missing trailer breakdown */}
      {showBreakdown && Object.keys(compliance.missingTrailerBreakdown).length > 0 && (
        <div className="mt-2 space-y-0.5">
          {Object.entries(compliance.missingTrailerBreakdown).map(([trailer, count]) => (
            <div key={trailer} className="flex justify-between text-[10px]">
              <span className="text-slate-400 font-mono truncate">{trailer}</span>
              <span className="text-[#f97316] font-mono ml-2">{count}×</span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
```

---

#### `frontend/src/components/infrastructure/notify/NotificationTimeline.tsx`

```typescript
'use client';
import { NotificationEvent } from '@/types/infrastructure';
import { cn } from '@/lib/utils';

interface NotificationTimelineProps {
  events: NotificationEvent[];
}

const PRIORITY_COLORS: Record<string, { dot: string; text: string; bg: string }> = {
  CRITICAL:  { dot: 'bg-[#dc2626]', text: 'text-[#ef4444]', bg: 'bg-[#450a0a]/40' },
  BLOCKED:   { dot: 'bg-[#ea580c]', text: 'text-[#f97316]', bg: 'bg-[#431407]/40' },
  DISPUTE:   { dot: 'bg-[#ca8a04]', text: 'text-[#eab308]', bg: 'bg-[#422006]/40' },
  COMPLETED: { dot: 'bg-[#16a34a]', text: 'text-[#22c55e]', bg: 'bg-[#052e16]/40' },
  INFO:      { dot: 'bg-[#6b7280]', text: 'text-[#94a3b8]', bg: 'bg-slate-800/40' },
};

const STATUS_BADGE: Record<string, string> = {
  delivered:   'text-[#22c55e] bg-[#16a34a]/10',
  failed:      'text-[#ef4444] bg-[#dc2626]/10',
  retrying:    'text-[#f97316] bg-[#ea580c]/10',
  'dead-letter': 'text-[#dc2626] bg-[#991b1b]/10 font-bold',
};

export function NotificationTimeline({ events }: NotificationTimelineProps) {
  if (events.length === 0) {
    return (
      <div className="text-center text-slate-500 text-sm py-8">
        No notification events recorded yet.
      </div>
    );
  }

  return (
    <div className="space-y-1">
      {events.map((evt) => {
        const pc = PRIORITY_COLORS[evt.priority] ?? PRIORITY_COLORS.INFO;
        return (
          <div
            key={evt.id}
            className={cn(
              'flex items-start gap-3 px-3 py-2.5 rounded-lg border border-transparent',
              'hover:border-slate-700/50 transition-colors',
              pc.bg
            )}
          >
            {/* Priority dot */}
            <span className={cn('mt-1 flex-shrink-0 w-2 h-2 rounded-full', pc.dot)} />

            {/* Content */}
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2 flex-wrap">
                <span className={cn('text-xs font-mono font-bold', pc.text)}>
                  {evt.priority}
                </span>
                <span className="text-xs text-slate-400 font-mono">{evt.taskId}</span>
                <span className="text-[10px] text-slate-500">{evt.sourceRole}@{evt.sourceVmId}</span>
                {!evt.trailersComplete && (
                  <span className="text-[10px] text-[#f97316] bg-[#431407]/50 px-1.5 py-0.5 rounded font-mono">
                    TRAILERS INCOMPLETE
                  </span>
                )}
              </div>
              <div className="text-xs text-slate-300 mt-0.5 truncate">{evt.summary}</div>
            </div>

            {/* Right side: status + latency + time */}
            <div className="flex-shrink-0 text-right">
              <div className={cn('inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-mono', STATUS_BADGE[evt.deliveryStatus] ?? '')}>
                {evt.deliveryStatus.toUpperCase().replace('-', '‑')}
              </div>
              <div className="text-[10px] text-slate-500 mt-0.5">
                {evt.deliveryLatencyMs !== null ? `${evt.deliveryLatencyMs}ms` : '—'}
              </div>
              <div className="text-[10px] text-slate-600">
                {new Date(evt.timestamp).toLocaleTimeString()}
              </div>
            </div>
          </div>
        );
      })}
    </div>
  );
}
```

---

#### `frontend/src/components/infrastructure/notify/DeadLetterQueueTable.tsx`

```typescript
'use client';
import { DeadLetterEntry } from '@/types/infrastructure';

interface DeadLetterQueueTableProps {
  entries: DeadLetterEntry[];
}

export function DeadLetterQueueTable({ entries }: DeadLetterQueueTableProps) {
  if (entries.length === 0) {
    return (
      <div className="text-center text-[#22c55e] text-sm py-6">
        ✓ Dead-letter queue is empty.
      </div>
    );
  }

  return (
    <div className="overflow-x-auto">
      <table className="w-full text-xs">
        <thead>
          <tr className="border-b border-slate-700/50">
            {['Timestamp', 'Source VM', 'Task ID', 'Priority', 'Attempts', 'Last Status', 'Error'].map(h => (
              <th key={h} className="text-left py-2 px-3 text-slate-500 font-medium">{h}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {entries.map((entry) => (
            <tr
              key={entry.id}
              className="border-b border-slate-800/50 hover:bg-slate-800/30 transition-colors"
            >
              <td className="py-2 px-3 text-slate-400 font-mono whitespace-nowrap">
                {new Date(entry.timestamp).toLocaleString()}
              </td>
              <td className="py-2 px-3 text-slate-300 font-mono">{entry.sourceVmId}</td>
              <td className="py-2 px-3 text-[#06B6D4] font-mono">{entry.taskId}</td>
              <td className="py-2 px-3">
                <span className={`font-mono font-bold ${
                  entry.priority === 'CRITICAL' ? 'text-[#ef4444]' :
                  entry.priority === 'BLOCKED'  ? 'text-[#f97316]' : 'text-[#ca8a04]'
                }`}>{entry.priority}</span>
              </td>
              <td className="py-2 px-3 text-[#f97316] font-mono">{entry.attemptCount}</td>
              <td className="py-2 px-3 text-slate-400 font-mono">
                HTTP {entry.lastHttpStatus ?? '—'}
              </td>
              <td className="py-2 px-3 text-[#ef4444] max-w-[240px] truncate">
                {entry.lastError}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
```

---

#### `frontend/src/app/(portal)/infrastructure/notifications/page.tsx`

```typescript
'use client';
import { useState } from 'react';
import { useNotificationLog, useDeliveryStats, useDeadLetters, useTrailerCompliance } from '@/hooks/useNotificationDelivery';
import { NotificationTimeline } from '@/components/infrastructure/notify/NotificationTimeline';
import { DeadLetterQueueTable } from '@/components/infrastructure/notify/DeadLetterQueueTable';
import { TrailerComplianceBadge } from '@/components/infrastructure/notify/TrailerComplianceBadge';

type Period = '1h' | '6h' | '24h' | '7d';

export default function NotificationDeliveryPage() {
  const [period, setPeriod] = useState<Period>('24h');
  const [activeTab, setActiveTab] = useState<'timeline' | 'dead-letters' | 'compliance'>('timeline');

  const { data: events = [], isLoading: eventsLoading } = useNotificationLog({ limit: 200 });
  const { data: stats } = useDeliveryStats(period);
  const { data: deadLetters = [] } = useDeadLetters();
  const { data: compliance = [] } = useTrailerCompliance();

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-start justify-between">
        <div>
          <h1 className="text-xl font-bold text-white">Notification Delivery Tracker</h1>
          <p className="text-sm text-slate-400 mt-0.5">
            gf-notify-architect.service — host-side HMAC relay
          </p>
        </div>
        <div className="flex gap-1.5 rounded-lg border border-slate-700/50 bg-slate-800/60 p-1">
          {(['1h', '6h', '24h', '7d'] as Period[]).map(p => (
            <button
              key={p}
              onClick={() => setPeriod(p)}
              className={`px-2.5 py-1 rounded text-xs font-mono transition-colors ${
                period === p
                  ? 'bg-[#06B6D4]/20 text-[#06B6D4]'
                  : 'text-slate-400 hover:text-slate-200'
              }`}
            >
              {p}
            </button>
          ))}
        </div>
      </div>

      {/* Stats cards */}
      {stats && (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          {[
            { label: 'Total Events',       value: stats.totalEvents,           color: 'text-white'       },
            { label: 'Delivered',          value: stats.deliveredCount,        color: 'text-[#22c55e]'   },
            { label: 'Failed',             value: stats.failedCount,           color: 'text-[#ef4444]'   },
            { label: 'Dead Letters',       value: stats.deadLetterCount,       color: 'text-[#dc2626]'   },
            { label: 'Success Rate',       value: `${Math.round(stats.successRate * 100)}%`, color: stats.successRate >= 0.95 ? 'text-[#22c55e]' : 'text-[#f97316]' },
            { label: 'Avg Latency',        value: stats.avgDeliveryLatencyMs !== null ? `${Math.round(stats.avgDeliveryLatencyMs)}ms` : '—', color: 'text-slate-300' },
            { label: 'Trailer Compliance', value: `${Math.round(stats.trailerComplianceRate * 100)}%`, color: stats.trailerComplianceRate >= 0.9 ? 'text-[#22c55e]' : 'text-[#f97316]' },
            { label: 'Period',             value: period,                       color: 'text-[#06B6D4]'   },
          ].map(({ label, value, color }) => (
            <div key={label} className="rounded-xl border border-slate-700/50 bg-slate-900/60 p-3">
              <div className="text-xs text-slate-500 mb-1">{label}</div>
              <div className={`text-lg font-bold font-mono ${color}`}>{value}</div>
            </div>
          ))}
        </div>
      )}

      {/* Dead-letter alert if any */}
      {deadLetters.length > 0 && (
        <div className="rounded-xl border border-[#dc2626]/50 bg-[#450a0a]/40 px-4 py-3 text-sm text-[#ef4444]">
          ⚠ {deadLetters.length} dead-letter{deadLetters.length !== 1 ? 's' : ''} in queue.
          Switch to the Dead Letters tab to inspect.
        </div>
      )}

      {/* Tabs */}
      <div className="flex gap-1 border-b border-slate-700/50">
        {([
          { id: 'timeline',     label: 'Timeline' },
          { id: 'dead-letters', label: `Dead Letters ${deadLetters.length > 0 ? `(${deadLetters.length})` : ''}` },
          { id: 'compliance',   label: 'Trailer Compliance' },
        ] as const).map(tab => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id)}
            className={`px-4 py-2 text-sm transition-colors border-b-2 -mb-px ${
              activeTab === tab.id
                ? 'border-[#06B6D4] text-[#06B6D4]'
                : 'border-transparent text-slate-400 hover:text-slate-200'
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* Tab content */}
      <div className="rounded-xl border border-slate-700/50 bg-slate-900/60 p-4">
        {activeTab === 'timeline' && (
          eventsLoading
            ? <div className="text-center text-slate-400 py-8 text-sm">Loading events…</div>
            : <NotificationTimeline events={events} />
        )}
        {activeTab === 'dead-letters' && (
          <DeadLetterQueueTable entries={deadLetters} />
        )}
        {activeTab === 'compliance' && (
          <div>
            <div className="text-sm text-slate-400 mb-4">
              Measures how consistently each VM's agents include all 5 required
              GateForge commit trailers in their notifications.
            </div>
            <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-3">
              {compliance.map(c => (
                <TrailerComplianceBadge key={c.vmId} compliance={c} showBreakdown />
              ))}
            </div>
            <div className="mt-4 text-xs text-slate-500 space-y-0.5">
              <div className="font-semibold text-slate-400">Required trailers:</div>
              {[
                'GateForge-Task-Id', 'GateForge-Priority', 'GateForge-Source-VM',
                'GateForge-Source-Role', 'GateForge-Summary',
              ].map(t => (
                <div key={t} className="font-mono">{t}</div>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
```

---

### 5.3 G3 — Installation & Setup Dashboard

#### `frontend/src/hooks/useSetupStatus.ts`

```typescript
'use client';
import { useQuery } from '@tanstack/react-query';
import { api } from '@/lib/api';
import { VMSetupStatus, ConfigDrift, SetupHistoryEntry } from '@/types/infrastructure';

export function useSetupStatus() {
  return useQuery<VMSetupStatus[]>({
    queryKey: ['setup-status', 'all'],
    queryFn: async () => {
      const res = await api.get<VMSetupStatus[]>('/api/setup-status/vm-setup-status');
      return res.data;
    },
    refetchInterval: 300_000,  // Match backend check interval
    staleTime: 120_000,
  });
}

export function useConfigDrifts(vmId?: string) {
  return useQuery<ConfigDrift[]>({
    queryKey: ['setup-status', 'drift', vmId],
    queryFn: async () => {
      const url = vmId
        ? `/api/setup-status/drift-detection?vmId=${vmId}`
        : '/api/setup-status/drift-detection';
      const res = await api.get<ConfigDrift[]>(url);
      return res.data;
    },
    refetchInterval: 300_000,
  });
}

export function useSetupHistory(vmId?: string, limit = 20) {
  return useQuery<SetupHistoryEntry[]>({
    queryKey: ['setup-status', 'history', vmId, limit],
    queryFn: async () => {
      const params = new URLSearchParams({ limit: String(limit) });
      if (vmId) params.set('vmId', vmId);
      const res = await api.get<SetupHistoryEntry[]>(`/api/setup-status/history?${params}`);
      return res.data;
    },
    refetchInterval: 300_000,
  });
}
```

---

#### `frontend/src/components/infrastructure/setup/SetupChecklist.tsx`

```typescript
'use client';
import { VMSetupStatus, SetupCheck } from '@/types/infrastructure';
import { cn } from '@/lib/utils';

interface SetupChecklistProps {
  vmStatus: VMSetupStatus;
}

const CHECK_STATUS_CONFIG = {
  pass:    { icon: '✓', color: 'text-[#22c55e]', bg: 'bg-[#052e16]/30' },
  fail:    { icon: '✗', color: 'text-[#ef4444]', bg: 'bg-[#450a0a]/30' },
  warn:    { icon: '⚠', color: 'text-[#f97316]', bg: 'bg-[#431407]/30' },
  unknown: { icon: '?', color: 'text-slate-400',  bg: 'bg-slate-800/30' },
};

function CheckRow({ check }: { check: SetupCheck }) {
  const cfg = CHECK_STATUS_CONFIG[check.status];
  return (
    <div className={cn('flex items-start gap-3 px-3 py-2.5 rounded-lg', cfg.bg)}>
      <span className={cn('text-sm font-bold flex-shrink-0 w-4 text-center mt-0.5', cfg.color)}>
        {cfg.icon}
      </span>
      <div className="flex-1 min-w-0">
        <div className="text-sm text-slate-200 font-medium">{check.name}</div>
        <div className="text-xs text-slate-400 mt-0.5">{check.detail}</div>
      </div>
    </div>
  );
}

export function SetupChecklist({ vmStatus }: SetupChecklistProps) {
  const passRate = Math.round(vmStatus.checkPassRate * 100);

  return (
    <div className="rounded-xl border border-slate-700/50 bg-slate-900/60 p-4">
      {/* Header */}
      <div className="flex items-center justify-between mb-3">
        <div>
          <div className="font-semibold text-white">
            <span className="font-mono text-[#06B6D4]">{vmStatus.hostname}</span>
          </div>
          <div className="text-xs text-slate-500 font-mono">{vmStatus.tailscaleIp} — {vmStatus.role}</div>
        </div>
        <div className={cn(
          'text-sm font-bold font-mono px-2 py-1 rounded',
          passRate === 100 ? 'text-[#22c55e] bg-[#052e16]/40' :
          passRate >= 50   ? 'text-[#f97316] bg-[#431407]/40' :
                             'text-[#ef4444] bg-[#450a0a]/40'
        )}>
          {passRate}%
        </div>
      </div>

      {/* Install status */}
      <div className="flex items-center gap-4 mb-3 text-xs">
        <div>
          <span className="text-slate-500">Install complete: </span>
          <span className={vmStatus.installComplete ? 'text-[#22c55e]' : 'text-[#ef4444]'}>
            {vmStatus.installComplete ? '✓ Yes' : '✗ No'}
          </span>
        </div>
        {vmStatus.installedAt && (
          <div>
            <span className="text-slate-500">Installed: </span>
            <span className="text-slate-300">{new Date(vmStatus.installedAt).toLocaleDateString()}</span>
          </div>
        )}
        {!vmStatus.sshReachable && (
          <span className="text-[#ef4444] font-mono text-[10px] bg-[#450a0a]/40 px-1.5 py-0.5 rounded">
            SSH UNREACHABLE
          </span>
        )}
      </div>

      {/* Checks */}
      <div className="space-y-1.5">
        {vmStatus.checks.map(check => (
          <CheckRow key={check.id} check={check} />
        ))}
      </div>

      {/* Drift indicator */}
      {vmStatus.hasDrift && (
        <div className="mt-3 text-xs text-[#f97316] bg-[#431407]/40 rounded-lg px-3 py-2">
          ⚠ Configuration drift detected — see Drift Detection tab
        </div>
      )}
    </div>
  );
}
```

---

#### `frontend/src/components/infrastructure/setup/ConfigDriftBanner.tsx`

```typescript
'use client';
import { ConfigDrift } from '@/types/infrastructure';

interface ConfigDriftBannerProps {
  drifts: ConfigDrift[];
}

const DRIFT_TYPE_LABELS: Record<string, string> = {
  'missing':               'Missing file',
  'permissions-mismatch':  'Wrong permissions',
  'content-hash-changed':  'Content changed',
  'unexpected-file':       'Unexpected file',
};

export function ConfigDriftBanner({ drifts }: ConfigDriftBannerProps) {
  if (drifts.length === 0) {
    return (
      <div className="rounded-xl border border-[#16a34a]/40 bg-[#052e16]/30 px-4 py-3 text-sm text-[#22c55e]">
        ✓ No configuration drift detected across all VMs.
      </div>
    );
  }

  return (
    <div className="rounded-xl border border-[#f97316]/40 bg-[#431407]/30 p-4 space-y-3">
      <div className="text-sm font-semibold text-[#f97316]">
        ⚠ {drifts.length} drift item{drifts.length !== 1 ? 's' : ''} detected
      </div>

      {drifts.map((drift, i) => (
        <div key={i} className="border-t border-[#f97316]/20 pt-3 text-xs">
          <div className="flex items-center gap-2 mb-1">
            <span className="font-mono text-[#06B6D4]">{drift.hostname}</span>
            <span className="text-[#f97316] font-bold">
              {DRIFT_TYPE_LABELS[drift.driftType] ?? drift.driftType}
            </span>
          </div>
          <div className="font-mono text-slate-400 mb-1">{drift.filePath}</div>
          <div className="text-slate-500">{drift.description}</div>
          <div className="mt-1 flex gap-4">
            <span><span className="text-slate-600">Expected: </span><span className="text-slate-300">{drift.expected}</span></span>
            <span><span className="text-slate-600">Actual: </span><span className="text-[#ef4444]">{drift.actual}</span></span>
          </div>
        </div>
      ))}
    </div>
  );
}
```

---

#### `frontend/src/app/(portal)/infrastructure/setup/page.tsx`

```typescript
'use client';
import { useState } from 'react';
import { useSetupStatus, useConfigDrifts, useSetupHistory } from '@/hooks/useSetupStatus';
import { SetupChecklist } from '@/components/infrastructure/setup/SetupChecklist';
import { ConfigDriftBanner } from '@/components/infrastructure/setup/ConfigDriftBanner';
import { SetupHistoryTable } from '@/components/infrastructure/setup/SetupHistoryTable';

type Tab = 'checklists' | 'drift' | 'history';

export default function SetupStatusPage() {
  const [activeTab, setActiveTab] = useState<Tab>('checklists');
  const [selectedVm, setSelectedVm] = useState<string | undefined>();

  const { data: statuses = [], isLoading } = useSetupStatus();
  const { data: drifts = [] } = useConfigDrifts(selectedVm);
  const { data: history = [] } = useSetupHistory(selectedVm, 30);

  const totalDrift = drifts.length;
  const allHealthy = statuses.every(s => s.checkPassRate === 1 && !s.hasDrift);

  if (isLoading) {
    return <div className="text-center text-slate-400 text-sm py-16">Loading setup status…</div>;
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-start justify-between">
        <div>
          <h1 className="text-xl font-bold text-white">Installation & Setup Dashboard</h1>
          <p className="text-sm text-slate-400 mt-0.5">
            Per-VM install validation and configuration drift detection
          </p>
        </div>
        <div className={`px-3 py-1.5 rounded-full text-xs font-bold font-mono ${
          allHealthy
            ? 'bg-[#052e16]/40 text-[#22c55e]'
            : 'bg-[#431407]/40 text-[#f97316]'
        }`}>
          {allHealthy ? '✓ All VMs compliant' : `⚠ ${totalDrift} drift item${totalDrift !== 1 ? 's' : ''}`}
        </div>
      </div>

      {/* Summary row */}
      <div className="grid grid-cols-3 md:grid-cols-5 gap-3">
        {statuses.map(s => (
          <button
            key={s.vmId}
            onClick={() => setSelectedVm(selectedVm === s.vmId ? undefined : s.vmId)}
            className={`rounded-xl border p-3 text-left transition-all ${
              selectedVm === s.vmId
                ? 'border-[#06B6D4] bg-[#06B6D4]/10'
                : s.checkPassRate === 1
                  ? 'border-[#16a34a]/40 bg-[#052e16]/20 hover:border-[#16a34a]/70'
                  : 'border-[#f97316]/40 bg-[#431407]/20 hover:border-[#f97316]/70'
            }`}
          >
            <div className="text-xs font-mono text-slate-400">{s.vmId.toUpperCase()}</div>
            <div className="text-sm font-semibold text-white truncate">{s.hostname}</div>
            <div className={`text-xs font-mono font-bold ${
              s.checkPassRate === 1 ? 'text-[#22c55e]' : 'text-[#f97316]'
            }`}>{Math.round(s.checkPassRate * 100)}%</div>
          </button>
        ))}
      </div>

      {/* Tabs */}
      <div className="flex gap-1 border-b border-slate-700/50">
        {([
          { id: 'checklists', label: 'Setup Checklists' },
          { id: 'drift',      label: `Drift Detection ${totalDrift > 0 ? `(${totalDrift})` : ''}` },
          { id: 'history',    label: 'History' },
        ] as const).map(tab => (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id)}
            className={`px-4 py-2 text-sm transition-colors border-b-2 -mb-px ${
              activeTab === tab.id
                ? 'border-[#06B6D4] text-[#06B6D4]'
                : 'border-transparent text-slate-400 hover:text-slate-200'
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      {/* Tab content */}
      {activeTab === 'checklists' && (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
          {statuses
            .filter(s => !selectedVm || s.vmId === selectedVm)
            .map(s => <SetupChecklist key={s.vmId} vmStatus={s} />)
          }
        </div>
      )}

      {activeTab === 'drift' && (
        <ConfigDriftBanner drifts={drifts} />
      )}

      {activeTab === 'history' && (
        <SetupHistoryTable entries={history} />
      )}
    </div>
  );
}
```

---

#### `frontend/src/components/infrastructure/setup/SetupHistoryTable.tsx`

```typescript
'use client';
import { SetupHistoryEntry } from '@/types/infrastructure';
import { cn } from '@/lib/utils';

interface SetupHistoryTableProps {
  entries: SetupHistoryEntry[];
}

export function SetupHistoryTable({ entries }: SetupHistoryTableProps) {
  if (entries.length === 0) {
    return <div className="text-center text-slate-500 text-sm py-8">No history recorded yet.</div>;
  }

  return (
    <div className="overflow-x-auto rounded-xl border border-slate-700/50">
      <table className="w-full text-xs">
        <thead className="bg-slate-800/40">
          <tr className="border-b border-slate-700/50">
            {['VM', 'Ran At', 'Passed', 'Failed', 'Drift Items', 'Status'].map(h => (
              <th key={h} className="text-left py-2.5 px-4 text-slate-500 font-medium">{h}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {entries.map((entry) => (
            <tr key={entry.id} className="border-b border-slate-800/50 hover:bg-slate-800/20">
              <td className="py-2.5 px-4 font-mono text-[#06B6D4]">{entry.hostname}</td>
              <td className="py-2.5 px-4 text-slate-400 font-mono whitespace-nowrap">
                {new Date(entry.ranAt).toLocaleString()}
              </td>
              <td className="py-2.5 px-4 text-[#22c55e] font-mono">{entry.checksPassed}</td>
              <td className="py-2.5 px-4 text-[#ef4444] font-mono">{entry.checksFailed}</td>
              <td className="py-2.5 px-4 text-[#f97316] font-mono">{entry.driftItemsFound}</td>
              <td className="py-2.5 px-4">
                <span className={cn(
                  'px-2 py-0.5 rounded-full font-mono font-bold',
                  entry.overallStatus === 'pass'    && 'bg-[#052e16]/40 text-[#22c55e]',
                  entry.overallStatus === 'warn'    && 'bg-[#431407]/40 text-[#f97316]',
                  entry.overallStatus === 'fail'    && 'bg-[#450a0a]/40 text-[#ef4444]',
                  entry.overallStatus === 'unknown' && 'bg-slate-800/40 text-slate-400',
                )}>
                  {entry.overallStatus.toUpperCase()}
                </span>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
```

---

### 5.4 G4 — Communication Test Results Viewer

#### `frontend/src/hooks/useTestResults.ts`

```typescript
'use client';
import { useQuery } from '@tanstack/react-query';
import { api } from '@/lib/api';
import { TestRun, AgentTestResult } from '@/types/infrastructure';

export function useLatestTestRun() {
  return useQuery<TestRun | null>({
    queryKey: ['tests', 'latest'],
    queryFn: async () => {
      try {
        const res = await api.get<TestRun>('/api/tests/latest-run');
        return res.data;
      } catch {
        return null;
      }
    },
    refetchInterval: 120_000,
  });
}

export function useTestHistory(limit = 20) {
  return useQuery<TestRun[]>({
    queryKey: ['tests', 'history', limit],
    queryFn: async () => {
      const res = await api.get<TestRun[]>(`/api/tests/history?limit=${limit}`);
      return res.data;
    },
    refetchInterval: 120_000,
  });
}

export function useAgentTestResults(agentId: string, limit = 10) {
  return useQuery<AgentTestResult[]>({
    queryKey: ['tests', 'agent', agentId, limit],
    queryFn: async () => {
      const res = await api.get<AgentTestResult[]>(
        `/api/tests/agent-results/${agentId}?limit=${limit}`
      );
      return res.data;
    },
    enabled: !!agentId,
    refetchInterval: 120_000,
  });
}
```

---

#### `frontend/src/components/infrastructure/tests/TestGateMatrix.tsx`

```typescript
'use client';
import { TestRun, TestGateName, TestGateStatus } from '@/types/infrastructure';
import { cn } from '@/lib/utils';

interface TestGateMatrixProps {
  run: TestRun;
}

const GATE_STATUS_CONFIG: Record<TestGateStatus, { icon: string; color: string; bg: string }> = {
  pass:    { icon: '✓', color: 'text-[#22c55e]', bg: 'bg-[#052e16]/40'  },
  fail:    { icon: '✗', color: 'text-[#ef4444]', bg: 'bg-[#450a0a]/40'  },
  skip:    { icon: '—', color: 'text-slate-500',  bg: 'bg-slate-800/40'  },
  timeout: { icon: '⏱', color: 'text-[#f97316]', bg: 'bg-[#431407]/40'  },
  pending: { icon: '…', color: 'text-[#06B6D4]',  bg: 'bg-[#06B6D4]/10' },
};

const GATE_LABELS: Record<TestGateName, string> = {
  A: 'Dispatch',
  B: 'Commit',
  C: 'Callback',
  D: 'Readable',
};

function GateCell({ status, gate, detail }: { status: TestGateStatus; gate: TestGateName; detail: string }) {
  const cfg = GATE_STATUS_CONFIG[status];
  return (
    <div className={cn('flex flex-col items-center gap-1 p-2 rounded-lg border border-slate-700/50', cfg.bg)}>
      <span className="text-xs font-mono text-slate-400">Gate {gate}</span>
      <span className="text-xs text-slate-500">{GATE_LABELS[gate]}</span>
      <span className={cn('text-lg font-bold', cfg.color)}>{cfg.icon}</span>
      <span className={cn('text-[10px] font-semibold uppercase tracking-wide', cfg.color)}>
        {status.toUpperCase()}
      </span>
      {detail && (
        <span className="text-[10px] text-slate-500 text-center leading-tight max-w-[80px]">
          {detail}
        </span>
      )}
    </div>
  );
}

export function TestGateMatrix({ run }: TestGateMatrixProps) {
  return (
    <div className="space-y-3">
      {run.agentResults.map((agent) => (
        <div key={agent.agentId} className="bg-slate-800/50 rounded-xl border border-slate-700 p-4">
          <div className="flex items-center justify-between mb-3">
            <div>
              <span className="font-mono text-sm text-[#06B6D4]">{agent.agentId}</span>
              <span className="text-slate-400 text-xs ml-2">@{agent.vmId}</span>
            </div>
            <div className="flex items-center gap-2">
              {agent.trailerCompliant ? (
                <span className="text-[10px] bg-[#052e16] text-[#22c55e] px-2 py-0.5 rounded font-semibold">TRAILERS OK</span>
              ) : (
                <span className="text-[10px] bg-[#450a0a] text-[#ef4444] px-2 py-0.5 rounded font-semibold">MISSING TRAILERS</span>
              )}
              {agent.durationMs !== undefined && (
                <span className="text-xs text-slate-500">{(agent.durationMs / 1000).toFixed(1)}s</span>
              )}
            </div>
          </div>
          <div className="grid grid-cols-4 gap-2">
            {(['A', 'B', 'C', 'D'] as TestGateName[]).map((gate) => {
              const gateResult = agent.gates.find(g => g.gate === gate);
              return (
                <GateCell
                  key={gate}
                  gate={gate}
                  status={gateResult?.status ?? 'skip'}
                  detail={gateResult?.detail ?? ''}
                />
              );
            })}
          </div>
          {agent.rawOutput && (
            <details className="mt-2">
              <summary className="text-xs text-slate-500 cursor-pointer hover:text-slate-300">
                Raw output
              </summary>
              <pre className="text-[10px] text-slate-400 bg-slate-900 rounded p-2 mt-1 max-h-32 overflow-auto font-mono whitespace-pre-wrap">
                {agent.rawOutput}
              </pre>
            </details>
          )}
        </div>
      ))}
    </div>
  );
}
```

---

#### `frontend/src/components/infrastructure/tests/FlakyAgentBanner.tsx`

```typescript
'use client';
import { FlakyAgent } from '@/types/infrastructure';

interface FlakyAgentBannerProps {
  flakyAgents: FlakyAgent[];
}

export function FlakyAgentBanner({ flakyAgents }: FlakyAgentBannerProps) {
  if (flakyAgents.length === 0) return null;

  return (
    <div className="rounded-xl border border-[#f97316]/40 bg-[#431407]/30 p-4">
      <div className="flex items-start gap-3">
        <span className="text-[#f97316] text-lg mt-0.5">⚠</span>
        <div className="flex-1">
          <p className="text-sm font-semibold text-[#f97316]">
            {flakyAgents.length} Flaky Agent{flakyAgents.length > 1 ? 's' : ''} Detected
          </p>
          <p className="text-xs text-slate-400 mt-1">
            These agents have inconsistent test pass rates across the last 5 runs. Investigate before the next iteration.
          </p>
          <div className="mt-3 space-y-2">
            {flakyAgents.map((agent) => (
              <div key={agent.agentId} className="flex items-center justify-between bg-slate-800/50 rounded-lg px-3 py-2">
                <span className="font-mono text-sm text-[#06B6D4]">{agent.agentId}</span>
                <div className="flex items-center gap-4 text-xs">
                  <span className="text-slate-400">
                    Pass rate: <span className="text-[#f97316] font-semibold">{(agent.passRate * 100).toFixed(0)}%</span>
                  </span>
                  <span className="text-slate-400">
                    Runs: <span className="text-slate-200">{agent.totalRuns}</span>
                  </span>
                  <span className="text-slate-500 text-[10px] font-mono">{agent.mostFailedGate}</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
```

---

#### `frontend/src/hooks/useTestResults.ts`

```typescript
'use client';
import { useQuery } from '@tanstack/react-query';
import { api } from '@/lib/api';
import { TestRun, FlakyAgent } from '@/types/infrastructure';

/** Latest test run results */
export function useLatestTestRun() {
  return useQuery({
    queryKey: ['infra', 'tests', 'latest'],
    queryFn: async () => {
      const res = await api.get<TestRun>('/api/infra/tests/latest-run');
      return res.data;
    },
    refetchInterval: 300_000,
  });
}

/** Paginated test run history */
export function useTestRunHistory(page = 1, pageSize = 20) {
  return useQuery({
    queryKey: ['infra', 'tests', 'history', page, pageSize],
    queryFn: async () => {
      const res = await api.get<{
        runs: TestRun[];
        total: number;
        page: number;
        pageSize: number;
        hasMore: boolean;
      }>(`/api/infra/tests/history?page=${page}&pageSize=${pageSize}`);
      return res.data;
    },
  });
}

/** Flaky agent analysis across last N runs */
export function useFlakyAgents() {
  return useQuery({
    queryKey: ['infra', 'tests', 'flaky'],
    queryFn: async () => {
      const res = await api.get<FlakyAgent[]>('/api/infra/tests/agent-results/flaky');
      return res.data;
    },
    refetchInterval: 600_000,
  });
}
```

---

### 5.5 G5 — Secrets & Token Inventory

#### `frontend/src/app/(portal)/infrastructure/secrets/page.tsx`

```typescript
'use client';
import { useSecretsInventory } from '@/hooks/useSecretsInventory';
import { SecretsComplianceMatrix } from '@/components/infrastructure/secrets/SecretsComplianceMatrix';
import { SecretsAlertList } from '@/components/infrastructure/secrets/SecretsAlertList';
import { TokenRotationReminder } from '@/components/infrastructure/secrets/TokenRotationReminder';
import { ShieldIcon } from 'lucide-react';

export default function SecretsInventoryPage() {
  const { data: inventory, isLoading, error, dataUpdatedAt } = useSecretsInventory();

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="p-2 rounded-lg bg-[#7c3aed]/10 border border-[#7c3aed]/30">
            <ShieldIcon className="w-5 h-5 text-[#7c3aed]" />
          </div>
          <div>
            <h1 className="text-2xl font-bold text-slate-100">Secrets &amp; Token Inventory</h1>
            <p className="text-sm text-slate-400">
              File-level metadata only — no secret values are ever transmitted or displayed
            </p>
          </div>
        </div>
        {dataUpdatedAt > 0 && (
          <span className="text-xs text-slate-500">
            Updated {new Date(dataUpdatedAt).toLocaleTimeString()}
          </span>
        )}
      </div>

      {/* Security notice */}
      <div className="bg-[#052e16]/30 border border-[#22c55e]/20 rounded-xl p-4 text-sm text-[#22c55e]/80">
        <span className="font-semibold">Security guarantee:</span> This page reads only file metadata
        (name, size, mode, owner, mtime) via SSH stat commands. No file contents are read, parsed,
        or stored. Actual token values remain exclusively on each VM.
      </div>

      {isLoading && (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
          {Array.from({ length: 5 }).map((_, i) => (
            <div key={i} className="h-64 rounded-xl bg-slate-800/40 animate-pulse border border-slate-700/50" />
          ))}
        </div>
      )}

      {error && (
        <div className="rounded-xl border border-red-500/40 bg-red-500/10 p-4 text-sm text-red-400">
          Failed to load secrets inventory: {(error as Error).message}
        </div>
      )}

      {inventory && (
        <>
          {inventory.alerts.length > 0 && (
            <SecretsAlertList alerts={inventory.alerts} />
          )}
          {inventory.rotationReminders.length > 0 && (
            <TokenRotationReminder reminders={inventory.rotationReminders} />
          )}
          <SecretsComplianceMatrix inventory={inventory} />
        </>
      )}
    </div>
  );
}
```

---

#### `frontend/src/components/infrastructure/secrets/SecretsComplianceMatrix.tsx`

```typescript
'use client';
import { SecretsInventory, VMSecretsStatus, SecretFile, TokenTier } from '@/types/infrastructure';
import { cn } from '@/lib/utils';

interface SecretsComplianceMatrixProps {
  inventory: SecretsInventory;
}

const TIER_CONFIG: Record<TokenTier, { label: string; color: string; bg: string }> = {
  platform: { label: 'Platform', color: 'text-[#dc2626]', bg: 'bg-[#450a0a]/40' },
  github:   { label: 'GitHub',   color: 'text-[#3b82f6]', bg: 'bg-[#1e3a5f]/40' },
  app:      { label: 'App',      color: 'text-[#7c3aed]', bg: 'bg-[#2e1065]/40' },
};

function FileStatusRow({ file }: { file: SecretFile }) {
  const statusCfg =
    file.complianceStatus === 'ok'          ? { icon: '✓', color: 'text-[#22c55e]' } :
    file.complianceStatus === 'missing'     ? { icon: '✗', color: 'text-[#ef4444]' } :
    file.complianceStatus === 'wrong-perms' ? { icon: '⚠', color: 'text-[#f97316]' } :
                                              { icon: '?', color: 'text-[#f97316]' };
  return (
    <div className="flex items-start gap-3 py-2 border-b border-slate-700/30 last:border-0">
      <span className={cn('mt-0.5 font-bold text-sm', statusCfg.color)}>{statusCfg.icon}</span>
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2 flex-wrap">
          <span className="font-mono text-xs text-slate-200 truncate">{file.path}</span>
          <span className={cn('text-[10px] px-1.5 py-0.5 rounded font-semibold',
            TIER_CONFIG[file.tier].color, TIER_CONFIG[file.tier].bg)}>
            {TIER_CONFIG[file.tier].label}
          </span>
        </div>
        <div className="flex flex-wrap gap-3 mt-1 text-[10px] text-slate-500">
          {file.exists ? (
            <>
              <span>Mode: <span className="font-mono text-slate-300">{file.mode ?? '—'}</span></span>
              <span>Owner: <span className="font-mono text-slate-300">{file.owner ?? '—'}</span></span>
              <span>Size: <span className="font-mono text-slate-300">{file.sizeBytes != null ? `${file.sizeBytes}B` : '—'}</span></span>
              {file.mtimeIso && (
                <span>Modified: <span className="text-slate-300">{new Date(file.mtimeIso).toLocaleDateString()}</span></span>
              )}
              {file.tokenCount != null && (
                <span>
                  Tokens: <span className="text-slate-300">{file.tokenCount}</span>
                  {file.expectedTokenCount != null && file.tokenCount < file.expectedTokenCount && (
                    <span className="text-[#f97316] ml-1">(expected {file.expectedTokenCount})</span>
                  )}
                </span>
              )}
            </>
          ) : (
            <span className="text-[#ef4444]">File not found on VM</span>
          )}
        </div>
        {file.complianceNote && (
          <p className="text-[10px] text-[#f97316] mt-1">{file.complianceNote}</p>
        )}
      </div>
    </div>
  );
}

function VMSecretsCard({ vmStatus }: { vmStatus: VMSecretsStatus }) {
  return (
    <div className={cn(
      'rounded-xl border p-4 bg-[#0F172A]/60',
      vmStatus.overallCompliant ? 'border-[#22c55e]/30' : 'border-[#f97316]/40'
    )}>
      <div className="flex items-center justify-between mb-3">
        <div>
          <span className="font-semibold text-slate-100">{vmStatus.vmId.toUpperCase()}</span>
          <span className="text-xs text-slate-400 ml-2">{vmStatus.hostname}</span>
        </div>
        <span className={cn('text-[10px] font-bold px-2 py-1 rounded',
          vmStatus.overallCompliant ? 'bg-[#052e16] text-[#22c55e]' : 'bg-[#431407] text-[#f97316]')}>
          {vmStatus.overallCompliant ? '✓ COMPLIANT' : '⚠ ISSUES'}
        </span>
      </div>
      <div className="grid grid-cols-3 gap-2 mb-3 text-center text-xs">
        <div className="bg-slate-800/60 rounded-lg p-2">
          <div className="text-lg font-bold text-[#22c55e]">{vmStatus.presentCount}</div>
          <div className="text-slate-500">Present</div>
        </div>
        <div className="bg-slate-800/60 rounded-lg p-2">
          <div className="text-lg font-bold text-[#ef4444]">{vmStatus.missingCount}</div>
          <div className="text-slate-500">Missing</div>
        </div>
        <div className="bg-slate-800/60 rounded-lg p-2">
          <div className="text-lg font-bold text-[#f97316]">{vmStatus.wrongPermsCount}</div>
          <div className="text-slate-500">Wrong Perms</div>
        </div>
      </div>
      <div>
        {vmStatus.files.map((file) => <FileStatusRow key={file.path} file={file} />)}
      </div>
      {vmStatus.sshError && (
        <p className="text-xs text-[#ef4444] mt-2 font-mono">{vmStatus.sshError}</p>
      )}
    </div>
  );
}

export function SecretsComplianceMatrix({ inventory }: SecretsComplianceMatrixProps) {
  return (
    <div className="space-y-4">
      <h2 className="text-lg font-semibold text-slate-100">Per-VM Compliance Status</h2>
      <div className="grid grid-cols-1 lg:grid-cols-2 xl:grid-cols-3 gap-4">
        {inventory.vms.map((vmStatus) => (
          <VMSecretsCard key={vmStatus.vmId} vmStatus={vmStatus} />
        ))}
      </div>
    </div>
  );
}
```

---

#### `frontend/src/components/infrastructure/secrets/SecretsAlertList.tsx`

```typescript
'use client';
import { SecretsAlert } from '@/types/infrastructure';
import { cn } from '@/lib/utils';

interface SecretsAlertListProps {
  alerts: SecretsAlert[];
}

const SEVERITY_CONFIG = {
  critical: { border: 'border-[#dc2626]/50', bg: 'bg-[#450a0a]/30', text: 'text-[#ef4444]', label: 'CRITICAL' },
  warning:  { border: 'border-[#f97316]/40', bg: 'bg-[#431407]/30', text: 'text-[#f97316]', label: 'WARNING'  },
  info:     { border: 'border-slate-600',     bg: 'bg-slate-800/40', text: 'text-slate-300',  label: 'INFO'     },
} as const;

export function SecretsAlertList({ alerts }: SecretsAlertListProps) {
  return (
    <div className="space-y-2">
      <h2 className="text-sm font-semibold text-slate-300 uppercase tracking-wide">
        Active Alerts ({alerts.length})
      </h2>
      {alerts.map((alert, i) => {
        const cfg = SEVERITY_CONFIG[alert.severity];
        return (
          <div key={i} className={cn('rounded-lg border p-3 flex items-start gap-3', cfg.border, cfg.bg)}>
            <span className={cn('font-bold text-xs mt-0.5', cfg.text)}>{cfg.label}</span>
            <div className="flex-1">
              <p className="text-sm text-slate-200">{alert.message}</p>
              <div className="flex items-center gap-3 mt-1 text-xs text-slate-500">
                <span className="font-mono">{alert.vmId}</span>
                <span className="font-mono">{alert.filePath}</span>
                {alert.detectedAt && <span>{new Date(alert.detectedAt).toLocaleString()}</span>}
              </div>
            </div>
          </div>
        );
      })}
    </div>
  );
}
```

---

#### `frontend/src/components/infrastructure/secrets/TokenRotationReminder.tsx`

```typescript
'use client';
import { RotationReminder } from '@/types/infrastructure';
import { cn } from '@/lib/utils';

interface TokenRotationReminderProps {
  reminders: RotationReminder[];
}

export function TokenRotationReminder({ reminders }: TokenRotationReminderProps) {
  if (reminders.length === 0) return null;

  return (
    <div className="rounded-xl border border-[#06B6D4]/30 bg-[#06B6D4]/5 p-4">
      <h3 className="text-sm font-semibold text-[#06B6D4] mb-3">
        Token Rotation Reminders ({reminders.length})
      </h3>
      <div className="space-y-2">
        {reminders.map((r, i) => {
          const daysAgo = Math.round(
            (Date.now() - new Date(r.lastModifiedIso).getTime()) / 86_400_000
          );
          const urgency =
            daysAgo >= r.thresholdDays * 1.5 ? 'critical' :
            daysAgo >= r.thresholdDays        ? 'warning'  : 'info';

          return (
            <div key={i} className={cn(
              'flex items-center justify-between rounded-lg px-3 py-2',
              urgency === 'critical' ? 'bg-[#450a0a]/50' :
              urgency === 'warning'  ? 'bg-[#431407]/50' : 'bg-slate-800/50'
            )}>
              <div>
                <span className="font-mono text-sm text-slate-200">{r.vmId}</span>
                <span className="text-slate-400 text-xs ml-2 font-mono">{r.filePath}</span>
              </div>
              <div className="text-right">
                <span className={cn('text-xs font-semibold',
                  urgency === 'critical' ? 'text-[#ef4444]' :
                  urgency === 'warning'  ? 'text-[#f97316]' : 'text-slate-400')}>
                  {daysAgo}d ago
                </span>
                <div className="text-[10px] text-slate-500">threshold: {r.thresholdDays}d</div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
```

---

#### `frontend/src/hooks/useSecretsInventory.ts`

```typescript
'use client';
import { useQuery } from '@tanstack/react-query';
import { api } from '@/lib/api';
import { SecretsInventory, SecretsComplianceSummary } from '@/types/infrastructure';

/** Full secrets inventory across all VMs */
export function useSecretsInventory() {
  return useQuery({
    queryKey: ['infra', 'secrets', 'inventory'],
    queryFn: async () => {
      const res = await api.get<SecretsInventory>('/api/infra/secrets/inventory');
      return res.data;
    },
    refetchInterval: 300_000,
    staleTime: 120_000,
  });
}

/** Lightweight compliance summary (for header badge) */
export function useSecretsComplianceSummary() {
  return useQuery({
    queryKey: ['infra', 'secrets', 'compliance-summary'],
    queryFn: async () => {
      const res = await api.get<SecretsComplianceSummary>('/api/infra/secrets/compliance');
      return res.data;
    },
    refetchInterval: 300_000,
  });
}
```

---

### 5.6 G6 — OpenClaw Configuration Viewer

#### `frontend/src/app/(portal)/infrastructure/configs/page.tsx`

```typescript
'use client';
import { useState } from 'react';
import { useOpenClawConfigs } from '@/hooks/useOpenClawConfigs';
import { OpenClawConfigViewer } from '@/components/infrastructure/configs/OpenClawConfigViewer';
import { ConfigDiffPanel } from '@/components/infrastructure/configs/ConfigDiffPanel';
import { ConfigValidationBadge } from '@/components/infrastructure/configs/ConfigValidationBadge';
import { Code2, GitCompare, ShieldCheck } from 'lucide-react';
import { cn } from '@/lib/utils';

type ViewMode = 'per-vm' | 'diff' | 'validation';
const VM_IDS = ['vm-1', 'vm-2', 'vm-3', 'vm-4', 'vm-5'];

export default function OpenClawConfigPage() {
  const [viewMode, setViewMode] = useState<ViewMode>('per-vm');
  const [selectedVm, setSelectedVm] = useState<string>('vm-1');
  const [diffLeft, setDiffLeft]   = useState<string>('vm-1');
  const [diffRight, setDiffRight] = useState<string>('vm-2');

  const { data: configs, isLoading, error, dataUpdatedAt } = useOpenClawConfigs();

  const tabs: Array<{ id: ViewMode; label: string; icon: React.ReactNode }> = [
    { id: 'per-vm',     label: 'Per-VM View',  icon: <Code2 className="w-4 h-4" />        },
    { id: 'diff',       label: 'Cross-VM Diff', icon: <GitCompare className="w-4 h-4" />  },
    { id: 'validation', label: 'Validation',    icon: <ShieldCheck className="w-4 h-4" /> },
  ];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="p-2 rounded-lg bg-[#06B6D4]/10 border border-[#06B6D4]/30">
            <Code2 className="w-5 h-5 text-[#06B6D4]" />
          </div>
          <div>
            <h1 className="text-2xl font-bold text-slate-100">OpenClaw Configuration Viewer</h1>
            <p className="text-sm text-slate-400">
              Read-only view of <span className="font-mono text-slate-300">openclaw.json</span> across all 5 VMs
            </p>
          </div>
        </div>
        {dataUpdatedAt > 0 && (
          <span className="text-xs text-slate-500">Updated {new Date(dataUpdatedAt).toLocaleTimeString()}</span>
        )}
      </div>

      {/* Tab switcher */}
      <div className="flex gap-1 bg-slate-800/60 rounded-xl p-1 w-fit">
        {tabs.map((tab) => (
          <button
            key={tab.id}
            onClick={() => setViewMode(tab.id)}
            className={cn(
              'flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium transition-all',
              viewMode === tab.id
                ? 'bg-[#06B6D4] text-slate-900'
                : 'text-slate-400 hover:text-slate-200 hover:bg-slate-700/50'
            )}
          >
            {tab.icon}
            {tab.label}
          </button>
        ))}
      </div>

      {isLoading && (
        <div className="space-y-3">
          {Array.from({ length: 3 }).map((_, i) => (
            <div key={i} className="h-48 rounded-xl bg-slate-800/40 animate-pulse border border-slate-700/50" />
          ))}
        </div>
      )}

      {error && (
        <div className="rounded-xl border border-red-500/40 bg-red-500/10 p-4 text-sm text-red-400">
          Failed to load OpenClaw configs: {(error as Error).message}
        </div>
      )}

      {/* Per-VM View */}
      {viewMode === 'per-vm' && configs && (
        <div className="space-y-4">
          <div className="flex gap-2 flex-wrap">
            {VM_IDS.map((vmId) => {
              const cfg = configs.find(c => c.vmId === vmId);
              return (
                <button
                  key={vmId}
                  onClick={() => setSelectedVm(vmId)}
                  className={cn(
                    'px-3 py-1.5 rounded-lg text-xs font-mono font-semibold transition-all border',
                    selectedVm === vmId
                      ? 'bg-[#06B6D4] text-slate-900 border-[#06B6D4]'
                      : cfg?.fetchError
                        ? 'bg-red-500/10 text-red-400 border-red-500/40'
                        : 'bg-slate-800/60 text-slate-300 border-slate-700 hover:border-[#06B6D4]/50'
                  )}
                >
                  {vmId.toUpperCase()}
                  {cfg?.fetchError && <span className="ml-1">✗</span>}
                </button>
              );
            })}
          </div>
          {(() => {
            const cfg = configs.find(c => c.vmId === selectedVm);
            return cfg ? <OpenClawConfigViewer config={cfg} /> : null;
          })()}
        </div>
      )}

      {/* Cross-VM Diff */}
      {viewMode === 'diff' && (
        <div className="space-y-4">
          <div className="flex items-center gap-4 flex-wrap">
            <div className="flex items-center gap-2">
              <label className="text-xs text-slate-400">Left VM:</label>
              <select
                value={diffLeft}
                onChange={e => setDiffLeft(e.target.value)}
                className="bg-slate-800 border border-slate-600 rounded-lg px-3 py-1.5 text-sm text-slate-200 font-mono"
              >
                {VM_IDS.map(id => <option key={id} value={id}>{id.toUpperCase()}</option>)}
              </select>
            </div>
            <span className="text-slate-500">vs</span>
            <div className="flex items-center gap-2">
              <label className="text-xs text-slate-400">Right VM:</label>
              <select
                value={diffRight}
                onChange={e => setDiffRight(e.target.value)}
                className="bg-slate-800 border border-slate-600 rounded-lg px-3 py-1.5 text-sm text-slate-200 font-mono"
              >
                {VM_IDS.map(id => <option key={id} value={id}>{id.toUpperCase()}</option>)}
              </select>
            </div>
          </div>
          {configs && (
            <ConfigDiffPanel leftVmId={diffLeft} rightVmId={diffRight} configs={configs} />
          )}
        </div>
      )}

      {/* Validation */}
      {viewMode === 'validation' && configs && (
        <ConfigValidationBadge configs={configs} />
      )}
    </div>
  );
}
```

---

#### `frontend/src/components/infrastructure/configs/OpenClawConfigViewer.tsx`

```typescript
'use client';
import { OpenClawConfig } from '@/types/infrastructure';
import { cn } from '@/lib/utils';

interface OpenClawConfigViewerProps {
  config: OpenClawConfig;
}

function JsonValue({ value, depth = 0 }: { value: unknown; depth?: number }) {
  if (value === null) return <span className="text-slate-500">null</span>;
  if (typeof value === 'boolean') return <span className="text-[#7c3aed]">{String(value)}</span>;
  if (typeof value === 'number')  return <span className="text-[#06B6D4]">{value}</span>;
  if (typeof value === 'string')  return <span className="text-[#22c55e]">"{value}"</span>;

  if (Array.isArray(value)) {
    if (value.length === 0) return <span className="text-slate-500">[]</span>;
    return (
      <span>
        {'['}
        <div className="pl-4">
          {value.map((item, i) => (
            <div key={i}>
              <JsonValue value={item} depth={depth + 1} />
              {i < value.length - 1 && <span className="text-slate-600">,</span>}
            </div>
          ))}
        </div>
        {']'}
      </span>
    );
  }

  if (typeof value === 'object') {
    const entries = Object.entries(value as Record<string, unknown>);
    if (entries.length === 0) return <span className="text-slate-500">{'{}'}</span>;
    return (
      <span>
        {'{'}
        <div className={cn('pl-4', depth < 3 ? 'border-l border-slate-700/50 ml-1' : '')}>
          {entries.map(([k, v], i) => (
            <div key={k}>
              <span className="text-[#f97316]">"{k}"</span>
              <span className="text-slate-500">: </span>
              <JsonValue value={v} depth={depth + 1} />
              {i < entries.length - 1 && <span className="text-slate-600">,</span>}
            </div>
          ))}
        </div>
        {'}'}
      </span>
    );
  }
  return <span>{String(value)}</span>;
}

export function OpenClawConfigViewer({ config }: OpenClawConfigViewerProps) {
  if (config.fetchError) {
    return (
      <div className="rounded-xl border border-red-500/40 bg-[#450a0a]/30 p-6">
        <p className="text-sm font-semibold text-red-400">Failed to fetch config from {config.vmId}</p>
        <p className="text-xs text-slate-500 mt-1 font-mono">{config.fetchError}</p>
      </div>
    );
  }

  return (
    <div className="rounded-xl border border-slate-700 bg-[#0d1117] overflow-hidden">
      {/* Config header */}
      <div className="flex items-center justify-between px-4 py-3 border-b border-slate-700 bg-slate-800/60">
        <div className="flex items-center gap-3">
          <span className="font-mono text-sm font-semibold text-[#06B6D4]">{config.vmId.toUpperCase()}</span>
          <span className="text-xs text-slate-400">— {config.hostname}</span>
          <span className="text-[10px] font-mono text-slate-500">{config.configPath}</span>
        </div>
        {config.fetchedAt && (
          <span className="text-[10px] text-slate-500">
            Fetched {new Date(config.fetchedAt).toLocaleTimeString()}
          </span>
        )}
      </div>

      {/* Summary cards */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 p-4 border-b border-slate-700/50">
        <div className="bg-slate-800/50 rounded-lg p-3 text-center">
          <div className="text-sm font-semibold text-slate-200">{config.gateway.bindMode}</div>
          <div className="text-[10px] text-slate-500">Bind Mode</div>
          {config.gateway.bindMode !== 'loopback' && (
            <div className="text-[10px] text-[#f97316] mt-1">⚠ Expected loopback</div>
          )}
        </div>
        <div className="bg-slate-800/50 rounded-lg p-3 text-center">
          <div className="text-sm font-semibold text-slate-200">{config.gateway.port}</div>
          <div className="text-[10px] text-slate-500">Port</div>
          {config.gateway.port !== 18789 && (
            <div className="text-[10px] text-[#f97316] mt-1">⚠ Expected 18789</div>
          )}
        </div>
        <div className="bg-slate-800/50 rounded-lg p-3 text-center">
          <div className="text-sm font-semibold text-slate-200">{config.agents.length}</div>
          <div className="text-[10px] text-slate-500">Agents</div>
        </div>
        <div className="bg-slate-800/50 rounded-lg p-3 text-center">
          <div className="text-sm font-semibold text-slate-200">{config.allowedOrigins.length}</div>
          <div className="text-[10px] text-slate-500">Allowed Origins</div>
        </div>
      </div>

      {/* Agents list */}
      {config.agents.length > 0 && (
        <div className="px-4 py-3 border-b border-slate-700/50">
          <p className="text-xs text-slate-400 font-semibold uppercase tracking-wide mb-2">Configured Agents</p>
          <div className="space-y-1">
            {config.agents.map((agent) => (
              <div key={agent.agentId} className="flex items-center gap-3 text-xs bg-slate-800/40 rounded px-3 py-1.5">
                <span className="font-mono text-[#06B6D4]">{agent.agentId}</span>
                <span className="text-slate-500">model: <span className="text-slate-300">{agent.model}</span></span>
                {agent.envVars.length > 0 && (
                  <span className="text-slate-500">
                    env: <span className="text-slate-300 font-mono">{agent.envVars.join(', ')}</span>
                  </span>
                )}
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Raw JSON viewer */}
      <div className="p-4">
        <p className="text-xs text-slate-400 font-semibold uppercase tracking-wide mb-2">Full Configuration</p>
        <div className="font-mono text-xs leading-relaxed overflow-auto max-h-96">
          <JsonValue value={config.rawConfig} />
        </div>
      </div>
    </div>
  );
}
```

---

#### `frontend/src/components/infrastructure/configs/ConfigDiffPanel.tsx`

```typescript
'use client';
import { OpenClawConfig, ConfigDiff } from '@/types/infrastructure';
import { cn } from '@/lib/utils';

interface ConfigDiffPanelProps {
  leftVmId: string;
  rightVmId: string;
  configs: OpenClawConfig[];
}

function computeFlatDiff(
  left: Record<string, unknown>,
  right: Record<string, unknown>
): ConfigDiff[] {
  const diffs: ConfigDiff[] = [];
  const allKeys = new Set([...Object.keys(left), ...Object.keys(right)]);

  allKeys.forEach((key) => {
    const leftStr = JSON.stringify(left[key], null, 2);
    const rightStr = JSON.stringify(right[key], null, 2);
    if (leftStr !== rightStr) {
      diffs.push({
        field: key,
        leftValue: leftStr,
        rightValue: rightStr,
        diffType:
          left[key] === undefined  ? 'added'   :
          right[key] === undefined ? 'removed'  : 'changed',
      });
    }
  });

  return diffs;
}

export function ConfigDiffPanel({ leftVmId, rightVmId, configs }: ConfigDiffPanelProps) {
  const leftCfg  = configs.find(c => c.vmId === leftVmId);
  const rightCfg = configs.find(c => c.vmId === rightVmId);

  if (!leftCfg || !rightCfg) {
    return <div className="text-sm text-slate-400 p-4">Select two VMs to compare.</div>;
  }

  const diffs = computeFlatDiff(
    leftCfg.rawConfig as Record<string, unknown>,
    rightCfg.rawConfig as Record<string, unknown>
  );

  if (diffs.length === 0) {
    return (
      <div className="rounded-xl border border-[#22c55e]/30 bg-[#052e16]/30 p-6 text-center">
        <p className="text-[#22c55e] font-semibold">✓ Configurations are identical</p>
        <p className="text-sm text-slate-400 mt-1">
          {leftVmId.toUpperCase()} and {rightVmId.toUpperCase()} openclaw.json files match exactly.
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-3">
      <p className="text-sm text-slate-300">
        <span className="font-semibold text-[#f97316]">{diffs.length} difference{diffs.length > 1 ? 's' : ''}</span>
        {' '}found between {leftVmId.toUpperCase()} and {rightVmId.toUpperCase()}
      </p>

      <div className="rounded-xl overflow-hidden border border-slate-700">
        <div className="grid grid-cols-[1fr_1fr_1fr] bg-slate-800">
          <div className="px-4 py-2 text-xs font-semibold text-slate-300 border-r border-slate-700">Field</div>
          <div className="px-4 py-2 text-xs font-semibold text-[#06B6D4]  border-r border-slate-700">{leftVmId.toUpperCase()}</div>
          <div className="px-4 py-2 text-xs font-semibold text-[#7c3aed]">{rightVmId.toUpperCase()}</div>
        </div>

        {diffs.map((diff, i) => (
          <div
            key={diff.field}
            className={cn(
              'grid grid-cols-[1fr_1fr_1fr] border-b border-slate-700/50 last:border-0',
              i % 2 === 0 ? 'bg-slate-800/30' : 'bg-slate-900/30'
            )}
          >
            <div className="px-4 py-3 border-r border-slate-700/50">
              <span className="font-mono text-xs text-slate-200">{diff.field}</span>
              <span className={cn(
                'ml-2 text-[10px] px-1.5 py-0.5 rounded font-semibold',
                diff.diffType === 'changed' ? 'bg-[#431407] text-[#f97316]' :
                diff.diffType === 'added'   ? 'bg-[#052e16] text-[#22c55e]' :
                                              'bg-[#450a0a] text-[#ef4444]'
              )}>
                {diff.diffType.toUpperCase()}
              </span>
            </div>
            <div className="px-4 py-3 border-r border-slate-700/50">
              <pre className="font-mono text-[10px] text-[#06B6D4] whitespace-pre-wrap break-all max-h-24 overflow-auto">
                {diff.leftValue ?? '(missing)'}
              </pre>
            </div>
            <div className="px-4 py-3">
              <pre className="font-mono text-[10px] text-[#7c3aed] whitespace-pre-wrap break-all max-h-24 overflow-auto">
                {diff.rightValue ?? '(missing)'}
              </pre>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
```

---

#### `frontend/src/components/infrastructure/configs/ConfigValidationBadge.tsx`

```typescript
'use client';
import { OpenClawConfig, ValidationResult } from '@/types/infrastructure';
import { cn } from '@/lib/utils';

interface ConfigValidationBadgeProps {
  configs: OpenClawConfig[];
}

const EXPECTED_ORIGINS = [
  'https://tonic-architect.sailfish-bass.ts.net',
  'https://tonic-designer.sailfish-bass.ts.net',
  'https://tonic-developer.sailfish-bass.ts.net',
  'https://tonic-qc.sailfish-bass.ts.net',
  'https://tonic-operator.sailfish-bass.ts.net',
];

function validateConfig(config: OpenClawConfig): ValidationResult[] {
  const results: ValidationResult[] = [];

  results.push({
    ruleId: 'bind-mode',
    description: 'Gateway bind mode must be loopback',
    status: config.gateway.bindMode === 'loopback' ? 'pass' : 'fail',
    actualValue: config.gateway.bindMode,
    expectedValue: 'loopback',
  });

  results.push({
    ruleId: 'gateway-port',
    description: 'Gateway port must be 18789',
    status: config.gateway.port === 18789 ? 'pass' : 'fail',
    actualValue: String(config.gateway.port),
    expectedValue: '18789',
  });

  const missingOrigins = EXPECTED_ORIGINS.filter(o => !config.allowedOrigins.includes(o));
  results.push({
    ruleId: 'allowed-origins',
    description: 'All 5 VM domains present in allowedOrigins',
    status: missingOrigins.length === 0 ? 'pass' : 'fail',
    actualValue: `${config.allowedOrigins.length} origins present`,
    expectedValue: missingOrigins.length > 0
      ? `Missing: ${missingOrigins.map(o => o.replace('https://', '')).join(', ')}`
      : `${EXPECTED_ORIGINS.length} origins`,
  });

  results.push({
    ruleId: 'tailscale-serve',
    description: 'Tailscale Serve configured for gateway port',
    status: config.gateway.tailscaleServeEnabled ? 'pass' : 'warn',
    actualValue: config.gateway.tailscaleServeEnabled ? 'enabled' : 'not detected',
    expectedValue: 'enabled',
  });

  return results;
}

export function ConfigValidationBadge({ configs }: ConfigValidationBadgeProps) {
  const validationsByVm = configs.map(cfg => ({
    vmId:       cfg.vmId,
    hostname:   cfg.hostname,
    results:    cfg.fetchError ? [] : validateConfig(cfg),
    fetchError: cfg.fetchError,
  }));

  const totalFails = validationsByVm.reduce(
    (sum, v) => sum + v.results.filter(r => r.status === 'fail').length, 0
  );
  const totalWarns = validationsByVm.reduce(
    (sum, v) => sum + v.results.filter(r => r.status === 'warn').length, 0
  );

  return (
    <div className="space-y-4">
      {/* Overall summary */}
      <div className={cn(
        'rounded-xl border p-4 flex items-center gap-4',
        totalFails > 0 ? 'border-[#dc2626]/40 bg-[#450a0a]/20' :
        totalWarns > 0 ? 'border-[#f97316]/40 bg-[#431407]/20' :
                         'border-[#22c55e]/30 bg-[#052e16]/20'
      )}>
        <span className={cn('text-3xl font-bold',
          totalFails > 0 ? 'text-[#ef4444]' : totalWarns > 0 ? 'text-[#f97316]' : 'text-[#22c55e]')}>
          {totalFails > 0 ? totalFails : totalWarns > 0 ? totalWarns : '✓'}
        </span>
        <div>
          <p className="font-semibold text-slate-100">
            {totalFails > 0
              ? `${totalFails} validation failure${totalFails > 1 ? 's' : ''} across all VMs`
              : totalWarns > 0
                ? `${totalWarns} warning${totalWarns > 1 ? 's' : ''} — review recommended`
                : 'All validation checks passed'}
          </p>
          <p className="text-xs text-slate-400">{configs.length} VMs checked • 4 rules per VM</p>
        </div>
      </div>

      {/* Per-VM details */}
      <div className="space-y-3">
        {validationsByVm.map(({ vmId, hostname, results, fetchError }) => (
          <div key={vmId} className="rounded-xl border border-slate-700 overflow-hidden">
            <div className="px-4 py-2 bg-slate-800/60 flex items-center justify-between">
              <div className="flex items-center gap-2">
                <span className="font-mono text-sm font-semibold text-slate-200">{vmId.toUpperCase()}</span>
                <span className="text-xs text-slate-500">{hostname}</span>
              </div>
              {fetchError ? (
                <span className="text-[10px] bg-red-500/20 text-red-400 px-2 py-0.5 rounded">FETCH ERROR</span>
              ) : (
                <span className={cn('text-[10px] px-2 py-0.5 rounded font-semibold',
                  results.some(r => r.status === 'fail') ? 'bg-[#450a0a] text-[#ef4444]' :
                  results.some(r => r.status === 'warn') ? 'bg-[#431407] text-[#f97316]' :
                                                            'bg-[#052e16] text-[#22c55e]')}>
                  {results.some(r => r.status === 'fail')
                    ? `${results.filter(r => r.status === 'fail').length} FAIL`
                    : results.some(r => r.status === 'warn')
                      ? `${results.filter(r => r.status === 'warn').length} WARN`
                      : '✓ PASS'}
                </span>
              )}
            </div>

            {fetchError ? (
              <div className="px-4 py-3 text-xs text-red-400 font-mono">{fetchError}</div>
            ) : (
              <div className="divide-y divide-slate-700/50">
                {results.map((result) => (
                  <div key={result.ruleId}
                    className="px-4 py-3 grid grid-cols-[auto_1fr_1fr] gap-4 items-start">
                    <span className={cn('mt-0.5 font-bold text-sm',
                      result.status === 'pass' ? 'text-[#22c55e]' :
                      result.status === 'fail' ? 'text-[#ef4444]' : 'text-[#f97316]')}>
                      {result.status === 'pass' ? '✓' : result.status === 'fail' ? '✗' : '⚠'}
                    </span>
                    <div>
                      <p className="text-xs font-medium text-slate-200">{result.description}</p>
                      <p className="text-[10px] text-slate-500 font-mono mt-0.5">rule: {result.ruleId}</p>
                    </div>
                    <div className="text-[10px] font-mono">
                      <div className="text-slate-400">
                        actual: <span className={
                          result.status === 'fail' ? 'text-[#ef4444]' :
                          result.status === 'warn' ? 'text-[#f97316]' : 'text-[#22c55e]'
                        }>{result.actualValue}</span>
                      </div>
                      {result.status !== 'pass' && (
                        <div className="text-slate-500 mt-0.5">expected: {result.expectedValue}</div>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}
```

---

#### `frontend/src/hooks/useOpenClawConfigs.ts`

```typescript
'use client';
import { useQuery } from '@tanstack/react-query';
import { api } from '@/lib/api';
import { OpenClawConfig, ConfigDiff } from '@/types/infrastructure';

/** Fetch all 5 VM openclaw.json configs */
export function useOpenClawConfigs() {
  return useQuery({
    queryKey: ['infra', 'openclaw', 'configs'],
    queryFn: async () => {
      const res = await api.get<OpenClawConfig[]>('/api/infra/openclaw/config-per-vm');
      return res.data;
    },
    refetchInterval: 300_000,
    staleTime: 120_000,
  });
}

/** Server-computed diff between two VMs */
export function useOpenClawDiff(leftVmId: string, rightVmId: string) {
  return useQuery({
    queryKey: ['infra', 'openclaw', 'diff', leftVmId, rightVmId],
    queryFn: async () => {
      const res = await api.get<{ diffs: ConfigDiff[] }>(
        `/api/infra/openclaw/diff?left=${leftVmId}&right=${rightVmId}`
      );
      return res.data;
    },
    enabled: !!leftVmId && !!rightVmId && leftVmId !== rightVmId,
    staleTime: 120_000,
  });
}
```

---

## 6. Task Breakdown

### Phase 3.0: Infrastructure & Connectivity (Weeks 33–37) — Category G Features

**Objective:** Implement all 6 Category G infrastructure monitoring features (G1–G6) as read-only observability tools. No write or control actions are introduced.

| Task ID | Title | Assigned VM | Dependencies | Acceptance Criteria | Points |
|---------|-------|-------------|--------------|---------------------|--------|
| TASK-PORTAL-122 | Backend: `services/networkProbe.ts` — Tailscale health prober | VM-3 dev-01 | TASK-PORTAL-002 | Probes all 5 VMs at `https://<hostname>.sailfish-bass.ts.net:18789/health` every 30s; stores last 200 latency points per VM; emits `vm.health` event on status change; timeout 5s; marks `slow` if 100–500ms, `error` if >500ms or unreachable | 8 |
| TASK-PORTAL-123 | Backend: `routes/network.ts` — topology, vm-status, latency-history | VM-3 dev-01 | TASK-PORTAL-122 | `GET /api/infra/network/topology` returns full NetworkTopology; `GET /api/infra/network/vm-status` returns VMHealth[]; `GET /api/infra/network/latency-history?vmId=&points=` returns LatencyPoint[] with timestamps; all behind `requireAuth` | 5 |
| TASK-PORTAL-124 | Frontend: Network Topology page — `NetworkTopologyDiagram`, `VMHealthCard` | VM-3 dev-02 | TASK-PORTAL-123 | 5 VM cards in hub-and-spoke layout (VM-1 centered); status dot color matches ok/slow/error/offline; Tailscale IPs and MagicDNS hostnames shown; click VM card opens latency chart panel; live-updates every 30s | 8 |
| TASK-PORTAL-125 | Frontend: `LatencyChart` component (Recharts AreaChart) | VM-3 dev-02 | TASK-PORTAL-124 | Up to 200-point history rendered; color zones green/amber/red by latency threshold; hover tooltip with timestamp + latency; min/avg/max summary strip below chart | 5 |
| TASK-PORTAL-126 | Frontend: `useNetworkTopology` hook | VM-3 dev-02 | TASK-PORTAL-125 | Fetches topology on mount; refetches every 30s; exposes `isAnyVmOffline`, `isAnyVmSlow`, `allHealthy` computed flags; `dataUpdatedAt` timestamp exposed | 3 |
| TASK-PORTAL-127 | Backend: `services/notificationMonitor.ts` — gf-notify journal parser | VM-3 dev-01 | TASK-PORTAL-002 | Reads `journalctl -u gf-notify-architect` from VM-1 via SSH; parses HMAC hook event lines: timestamp, status (delivered/failed/retried), taskId, priority, sourceVm; computes delivery stats; identifies dead-letter entries (retry_count > 0 and final status = failed) | 8 |
| TASK-PORTAL-128 | Backend: `routes/notifications-delivery.ts` — log, stats, dead-letters | VM-3 dev-01 | TASK-PORTAL-127 | `GET /api/infra/notifications/log?page=&pageSize=` returns NotificationEvent[] paginated; `GET /api/infra/notifications/stats` returns DeliveryStatus summary; `GET /api/infra/notifications/dead-letters` returns dead-letter events; READ-ONLY — no replay trigger endpoint | 5 |
| TASK-PORTAL-129 | Frontend: Notification Delivery Tracker page — `NotificationTimeline`, `DeadLetterQueueTable` | VM-3 dev-02 | TASK-PORTAL-128 | Timeline shows last 50 delivery events with priority color (CRITICAL=red, BLOCKED=orange, COMPLETED=green, INFO=grey); dead-letter table shows failed events with retry count and last error; stats row above timeline | 8 |
| TASK-PORTAL-130 | Frontend: `TrailerComplianceBadge` component | VM-3 dev-02 | TASK-PORTAL-129 | Shows 5 required trailer slots (GateForge-Task-Id, -Priority, -Source-VM, -Source-Role, -Summary); each slot green=present / red=missing; tooltip shows example values; BLOCKED auto-send rule documented in UI | 3 |
| TASK-PORTAL-131 | Frontend: `useNotificationDelivery` hook | VM-3 dev-02 | TASK-PORTAL-130 | Fetches log, stats, dead-letters in parallel on mount; log auto-refreshes every 60s; stats every 120s; `deadLetterCount` computed flag | 3 |
| TASK-PORTAL-132 | Backend: `services/setupValidator.ts` — per-VM install script validator | VM-3 dev-01 | TASK-PORTAL-002 | SSH into each VM; checks presence of: `install-common.sh`, per-VM setup script, `openclaw.json`, `SOUL.md`, `TOOLS.md`, `USER.md`, `AGENTS.md`; reads `/var/log/gateforge-setup-status.json` for last exit code; computes config drift by comparing SHA-256 checksums of config files vs baseline | 8 |
| TASK-PORTAL-133 | Backend: `routes/setup-status.ts` — vm-setup-status, drift-detection, history | VM-3 dev-01 | TASK-PORTAL-132 | `GET /api/infra/setup/vm-setup-status` returns VMSetupStatus[] for all 5 VMs; `GET /api/infra/setup/drift-detection` returns ConfigDrift[] for checksum mismatches; `GET /api/infra/setup/history` returns last 10 setup run records per VM | 5 |
| TASK-PORTAL-134 | Frontend: Installation & Setup Dashboard page — `SetupChecklist`, `ConfigDriftBanner` | VM-3 dev-02 | TASK-PORTAL-133 | Per-VM checklist shows all required files with present/missing/stale status; last install run timestamp + exit code; ConfigDriftBanner appears as dismissible warning when checksums diverged | 8 |
| TASK-PORTAL-135 | Frontend: `SetupHistoryTable` component | VM-3 dev-02 | TASK-PORTAL-134 | Table of last 10 setup runs per VM; columns: Date, Exit Code (color-coded 0=green, non-zero=red), Duration; most recent successful run highlighted | 3 |
| TASK-PORTAL-136 | Frontend: `useSetupStatus` hook | VM-3 dev-02 | TASK-PORTAL-135 | Fetches vm-setup-status, drift-detection, and history in parallel; auto-refreshes every 5 min; `hasAnyDrift`, `hasAnyFailed` computed flags | 3 |
| TASK-PORTAL-137 | Backend: `services/testRunParser.ts` — test-communication.sh log reader | VM-3 dev-01 | TASK-PORTAL-002 | Reads test output logs from `/data/test-logs/` volume; parses Gate A/B/C/D result lines per agent; parses trailer validation results (5 required trailers); classifies flaky agents (pass rate < 80% over last 5 runs); computes per-run duration | 8 |
| TASK-PORTAL-138 | Backend: `routes/tests.ts` — latest-run, history, agent-results | VM-3 dev-01 | TASK-PORTAL-137 | `GET /api/infra/tests/latest-run` returns most recent TestRun with full agent gate matrix; `GET /api/infra/tests/history` paginated; `GET /api/infra/tests/agent-results/flaky` returns FlakyAgent[] with pass rates; all READ-ONLY | 5 |
| TASK-PORTAL-139 | Frontend: Communication Test Results Viewer page — `TestGateMatrix`, `AgentTestHistoryChart` | VM-3 dev-02 | TASK-PORTAL-138 | Gate matrix renders A/B/C/D cells per agent with color icons (✓/✗/⏱/—); trailer compliance badge per row; history chart shows 10-run trend per agent | 8 |
| TASK-PORTAL-140 | Frontend: `FlakyAgentBanner` component | VM-3 dev-02 | TASK-PORTAL-139 | Banner appears only when flaky agents present; shows agent ID, pass rate, most-failed gate; styled orange warning; dismissible per session | 3 |
| TASK-PORTAL-141 | Frontend: `useTestResults` hook | VM-3 dev-02 | TASK-PORTAL-140 | `useLatestTestRun` — fetches on mount + 5-min refresh; `useTestRunHistory` — paginated; `useFlakyAgents` — separate query; all properly typed | 3 |
| TASK-PORTAL-142 | Backend: `services/secretsInventory.ts` — SSH stat-only file checker | VM-3 dev-01 | TASK-PORTAL-002 | SSH into each VM; runs `stat` on each expected secrets file path only; collects path, exists, mode (octal), owner, group, sizeBytes, mtime ONLY — NO file contents; detects 3-tier structure; detects stale files (>90 days); generates alerts for missing/wrong-perms/stale | 8 |
| TASK-PORTAL-143 | Backend: `routes/secrets.ts` — inventory, compliance, alerts | VM-3 dev-01 | TASK-PORTAL-142 | `GET /api/infra/secrets/inventory` returns SecretsInventory; `GET /api/infra/secrets/compliance` returns SecretsComplianceSummary; `GET /api/infra/secrets/alerts` returns SecretsAlert[]; response bodies contain zero file content fields | 5 |
| TASK-PORTAL-144 | Frontend: Secrets & Token Inventory page — `SecretsComplianceMatrix`, `SecretsAlertList` | VM-3 dev-02 | TASK-PORTAL-143 | Per-VM compliance matrix shows present/missing/wrong-perms per expected file with mode + owner; alert list by severity; prominent security guarantee notice explaining metadata-only policy | 8 |
| TASK-PORTAL-145 | Frontend: `TokenRotationReminder` component | VM-3 dev-02 | TASK-PORTAL-144 | Lists files exceeding rotation threshold; days-since-mtime shown; urgency color escalates at 1× threshold (orange) and 1.5× threshold (red); default threshold 90 days | 3 |
| TASK-PORTAL-146 | Frontend: `useSecretsInventory` hook | VM-3 dev-02 | TASK-PORTAL-145 | Fetches inventory and compliance summary in parallel; auto-refreshes every 5 min; `totalAlerts` computed from inventory data | 2 |
| TASK-PORTAL-147 | Backend: `services/openclawConfigFetcher.ts` — openclaw.json reader | VM-3 dev-01 | TASK-PORTAL-002 | SSH into each VM; reads openclaw.json from configured path; parses JSON; extracts gateway settings, allowedOrigins, agent IDs + models + envVar names (never values); redacts any field whose key contains "token"/"secret"/"password"/"key"/"api"; caches 2 min | 8 |
| TASK-PORTAL-148 | Backend: `routes/openclaw-config.ts` — config-per-vm, diff, validation | VM-3 dev-01 | TASK-PORTAL-147 | `GET /api/infra/openclaw/config-per-vm` returns OpenClawConfig[] for all VMs; `GET /api/infra/openclaw/diff?left=&right=` returns ConfigDiff[]; `GET /api/infra/openclaw/validation` returns ValidationResult[] per VM; no mutation endpoints | 5 |
| TASK-PORTAL-149 | Frontend: OpenClaw Config Viewer page — `OpenClawConfigViewer`, `ConfigDiffPanel`, `ConfigValidationBadge` | VM-3 dev-02 | TASK-PORTAL-148 | Per-VM tab with syntax-highlighted JSON viewer; bind-mode/port warnings if non-default; cross-VM diff panel with field-level highlighting; validation panel shows 4 rules per VM | 8 |
| TASK-PORTAL-150 | Frontend: `useOpenClawConfigs` hook | VM-3 dev-02 | TASK-PORTAL-149 | `useOpenClawConfigs` fetches all VM configs; `useOpenClawDiff` accepts leftVmId/rightVmId; auto-refresh every 5 min; both hooks correctly typed | 2 |
| TASK-PORTAL-151 | Backend: Update `index.ts` — register all Category G routes | VM-3 dev-01 | TASK-PORTAL-123, 128, 133, 138, 143, 148 | All 6 Category G route namespaces registered under `/api/infra/*`; all protected by `requireAuth`; all return `{ ok: true, data: ... }` or `{ ok: false, error: ... }`; SSE route remains last | 3 |
| TASK-PORTAL-152 | Frontend: Update Sidebar — add Infrastructure nav group with 6 children | VM-3 dev-02 | TASK-PORTAL-124, 129, 134, 139, 144, 149 | Infrastructure group with `Network Topology`, `Notification Relay`, `Setup Status`, `Test Results`, `Secrets Inventory`, `OpenClaw Config`; keyboard shortcut `g+i`; collapsible; active route highlighted | 3 |
| TASK-PORTAL-153 | QA: Phase 3.0 full test pass (unit + integration + E2E) | VM-4 qc-01 | TASK-PORTAL-122 through 152 | All 6 G features pass QA gate: backend ≥ 90% coverage, frontend ≥ 85%; E2E covers topology render, secrets matrix, openclaw diff, test gate matrix; read-only enforcement test passes (no POST/PUT/DELETE to VMs); no secret content in any response body | 13 |
| TASK-PORTAL-154 | Documentation: Update README + .env.example for Category G vars | VM-3 dev-01 | TASK-PORTAL-153 | All new env vars documented (INFRA_SSH_KEY_PATH, INFRA_SSH_USER, NETWORK_PROBE_INTERVAL, TEST_LOGS_PATH, SECRETS_ROTATION_THRESHOLD_DAYS, OPENCLAW_CONFIG_PATH, INFRA_MOCK_MODE); Category G section in README; CONTRIBUTING updated | 5 |

**Phase 3.0 Total: ~155 story points across 33 tasks**

---

### Updated Grand Total

| Version | Phase | Story Points | Tasks |
|---------|-------|--------------|-------|
| v1.0 | Phases 1–4 | 248 | 54 |
| v1.5 | Phase 1.5 | 149 | 24 |
| v2.0 | Phase 2.0 | 205 | 29 |
| v2.5 | Phase 2.5 | 118 | 14 |
| **v3.0** | **Phase 3.0 (Category G)** | **155** | **33** |
| **Total** | | **875** | **154** |

> Grand total grows from 775 story points / 121 tasks to **875 story points / 154 tasks** after adding all Category G infrastructure features.

---

## 7. Integration Notes

### 7.1 Auth Integration

All Category G routes apply the existing `requireAuth` middleware from `backend/src/middleware/auth.ts`:

```typescript
// Pattern used in every Category G route file
import { requireAuth } from '../middleware/auth';
const router = Router();
router.use(requireAuth);
// ... all route handlers run only after auth passes
export default router;
```

No new authentication mechanism is introduced. The existing JWT cookie + Bearer token extraction logic is unchanged.

### 7.2 Config Integration

The `AppConfig` interface in `backend/src/config.ts` is extended with Category G fields (all optional with safe defaults):

```typescript
// Additions to AppConfig interface in backend/src/config.ts
export interface AppConfig {
  // ... existing fields unchanged ...

  // ─── Category G: Infrastructure & Connectivity ────────────────────────────
  /** Path to SSH private key for stat-only infrastructure checks */
  infraSshKeyPath: string;
  /** SSH user for infrastructure checks (e.g. 'gateforge', 'architect') */
  infraSshUser: string;
  /** How often to probe VM health endpoints (seconds). Default: 30 */
  networkProbeIntervalSec: number;
  /** Host path to test output log files (shared Docker volume). Default: '/data/test-logs' */
  testLogsPath: string;
  /** Days before a secrets file is flagged as stale. Default: 90 */
  secretsRotationThresholdDays: number;
  /** Path to openclaw.json on each VM. Default: '/opt/openclaw/openclaw.json' */
  openclawConfigPath: string;
  /** When true, return mock data instead of real SSH probes (for CI). Default: false */
  infraMockMode: boolean;
}

// Additions to loadConfig() _cfg initialiser:
_cfg = {
  // ...existing fields...
  infraSshKeyPath:               process.env.INFRA_SSH_KEY_PATH || '/data/ssh-keys/infra_rsa',
  infraSshUser:                  process.env.INFRA_SSH_USER || 'gateforge',
  networkProbeIntervalSec:       parseInt(process.env.NETWORK_PROBE_INTERVAL || '30', 10),
  testLogsPath:                  process.env.TEST_LOGS_PATH || '/data/test-logs',
  secretsRotationThresholdDays:  parseInt(process.env.SECRETS_ROTATION_THRESHOLD_DAYS || '90', 10),
  openclawConfigPath:            process.env.OPENCLAW_CONFIG_PATH || '/opt/openclaw/openclaw.json',
  infraMockMode:                 process.env.INFRA_MOCK_MODE === 'true',
};
```

### 7.3 Route Registration (`index.ts` update)

Add after the v2.5 routes block, before the SSE events route:

```typescript
// ─── v3.0 Routes — Category G: Infrastructure & Connectivity ─────────────────
import networkRouter        from './routes/network';
import notifDeliveryRouter  from './routes/notifications-delivery';
import setupStatusRouter    from './routes/setup-status';
import testsRouter          from './routes/tests';
import secretsRouter        from './routes/secrets';
import openclawConfigRouter from './routes/openclaw-config';

app.use('/api/infra/network',       networkRouter);
app.use('/api/infra/notifications', notifDeliveryRouter);
app.use('/api/infra/setup',         setupStatusRouter);
app.use('/api/infra/tests',         testsRouter);
app.use('/api/infra/secrets',       secretsRouter);
app.use('/api/infra/openclaw',      openclawConfigRouter);

// ─── SSE — must remain last ────────────────────────────────────────────────────
app.use('/api/events', eventsRouter);
```

### 7.4 Sidebar Navigation Update

Add the following group to `NAV_GROUPS` in `src/components/layout/Sidebar.tsx` (insert before `STANDALONE_ITEMS`):

```typescript
import { Network, BellRing, Wrench, FlaskConical, Shield, Code2 } from 'lucide-react';

{
  label: 'Infrastructure',
  icon: Network,
  shortcut: 'g+i',
  href: '/infrastructure/network',
  children: [
    { href: '/infrastructure/network',       label: 'Network Topology',  icon: Network      },  // ◆ G1
    { href: '/infrastructure/notifications', label: 'Notification Relay',icon: BellRing     },  // ◆ G2
    { href: '/infrastructure/setup',         label: 'Setup Status',      icon: Wrench       },  // ◆ G3
    { href: '/infrastructure/tests',         label: 'Test Results',      icon: FlaskConical },  // ◆ G4
    { href: '/infrastructure/secrets',       label: 'Secrets Inventory', icon: Shield       },  // ◆ G5
    { href: '/infrastructure/configs',       label: 'OpenClaw Config',   icon: Code2        },  // ◆ G6
  ],
},
```

Add to `NAV_SHORTCUTS` in `src/lib/constants.ts`:

```typescript
'/infrastructure/network': 'g+i',
```

### 7.5 App Router Directory Structure

```
src/app/(portal)/infrastructure/
├── network/page.tsx        # G1: NetworkTopologyPage
├── notifications/page.tsx  # G2: NotificationDeliveryPage
├── setup/page.tsx          # G3: SetupDashboardPage
├── tests/page.tsx          # G4: TestResultsPage
├── secrets/page.tsx        # G5: SecretsInventoryPage
└── configs/page.tsx        # G6: OpenClawConfigPage

src/components/infrastructure/
├── network/      { NetworkTopologyDiagram, VMHealthCard, LatencyChart }
├── notifications/{ NotificationTimeline, DeadLetterQueueTable, TrailerComplianceBadge }
├── setup/        { SetupChecklist, ConfigDriftBanner, SetupHistoryTable }
├── tests/        { TestGateMatrix, AgentTestHistoryChart, FlakyAgentBanner }
├── secrets/      { SecretsComplianceMatrix, SecretsAlertList, TokenRotationReminder }
└── configs/      { OpenClawConfigViewer, ConfigDiffPanel, ConfigValidationBadge }

src/hooks/
├── useNetworkTopology.ts
├── useNotificationDelivery.ts
├── useSetupStatus.ts
├── useTestResults.ts
├── useSecretsInventory.ts
└── useOpenClawConfigs.ts

backend/src/services/
├── networkProbe.ts
├── notificationMonitor.ts
├── setupValidator.ts
├── testRunParser.ts
├── secretsInventory.ts
└── openclawConfigFetcher.ts

backend/src/routes/
├── network.ts
├── notifications-delivery.ts
├── setup-status.ts
├── tests.ts
├── secrets.ts
└── openclaw-config.ts

backend/src/types/
└── infrastructure.ts   # All Category G TypeScript types
```

### 7.6 Header Infrastructure Alert Indicator

The existing `Header.tsx` can surface a top-level infrastructure alert when any probe returns an error or any compliance check fails:

```typescript
// Header.tsx — add alongside existing HealthScoreBadge
import { useNetworkTopology } from '@/hooks/useNetworkTopology';
import { useSecretsComplianceSummary } from '@/hooks/useSecretsInventory';
import Link from 'next/link';

// Inside the Header component:
const { data: topology }         = useNetworkTopology();
const { data: secretsCompliance } = useSecretsComplianceSummary();

const hasInfraAlert =
  topology?.vms.some(v => v.status === 'error' || v.status === 'offline') ||
  (secretsCompliance?.totalFailCount ?? 0) > 0;

// In the JSX:
{hasInfraAlert && (
  <Link
    href="/infrastructure/network"
    className="flex items-center gap-1.5 px-2 py-1 rounded-lg bg-[#431407] border border-[#f97316]/40 text-[10px] font-semibold text-[#f97316] hover:bg-[#431407]/80 transition-colors"
  >
    <span className="animate-pulse">⚠</span>
    INFRA ALERT
  </Link>
)}
```

### 7.7 Read-Only Enforcement

All Category G endpoints are strictly GET-only. Each new service file includes the guard comment:

```typescript
// READ-ONLY ENFORCEMENT: This service issues no write operations to any VM.
// Allowed operations: SSH exec of read-only commands (stat, cat, journalctl --no-pager, ls -la).
// Prohibited: SSH exec of write commands, gateway POST/PUT/DELETE, file modification.
```

The `networkProbe.ts` service uses Tailscale HTTPS (not the existing direct IP gateway client) because it targets the public Tailscale hostnames. It does not use `gatewayClient.ts` — it uses its own dedicated fetch wrapper with the same read-only constraint.

Docker volume additions to `docker-compose.yml` for Category G:

```yaml
# Add to backend service volumes:
- ssh-keys:/data/ssh-keys:ro          # Existing volume — reused
- test-logs:/data/test-logs:ro        # New read-only test log volume

# Add new named volume:
volumes:
  blueprint-clone:
  ssh-keys:
  config:
  test-logs:          # ← New
```

---

## 8. Testing Strategy

### 8.1 Unit Tests — Backend Services

Target: ≥ 90% statement coverage per service file.

**`networkProbe.test.ts`:**

```typescript
import { jest } from '@jest/globals';
jest.mock('node-fetch');
import fetch from 'node-fetch';
const mockFetch = fetch as jest.MockedFunction<typeof fetch>;

import { probeVM, getLatencyHistory } from '../networkProbe';
import { VMConfig } from '../../types';

const mockVM: VMConfig = {
  id: 'vm-1', role: 'System Architect', ip: '100.73.38.28',
  port: 18789, model: 'claude-opus-4.6',
  hookToken: 'tok', agentSecret: 'sec',
  agents: ['architect'], isHub: true,
};

describe('networkProbe', () => {
  beforeEach(() => jest.clearAllMocks());

  it('classifies response time < 100ms as ok', async () => {
    mockFetch.mockResolvedValueOnce({ ok: true, json: async () => ({ status: 'ok' }) } as never);
    const result = await probeVM(mockVM);
    expect(result.status).toBe('ok');
  });

  it('marks VM as error when fetch throws', async () => {
    mockFetch.mockRejectedValueOnce(new Error('ECONNREFUSED'));
    const result = await probeVM(mockVM);
    expect(result.status).toBe('error');
    expect(result.errorMessage).toContain('ECONNREFUSED');
  });

  it('returns empty array for unknown vmId history', () => {
    expect(getLatencyHistory('vm-unknown', 50)).toEqual([]);
  });
});
```

---

**`secretsInventory.test.ts`:**

```typescript
import { parseStatOutput, assessCompliance } from '../secretsInventory';

describe('parseStatOutput', () => {
  it('parses Linux stat output for an existing file', () => {
    const statOutput = [
      '  File: /opt/secrets/gateforge.env',
      '  Size: 248',
      'Access: (0600/-rw-------)  Uid: (    0/    root)   Gid: (    0/    root)',
      'Modify: 2026-03-12 14:22:11.000000000 +0000',
    ].join('\n');

    const result = parseStatOutput('/opt/secrets/gateforge.env', statOutput, 'platform');
    expect(result.exists).toBe(true);
    expect(result.mode).toBe('0600');
    expect(result.owner).toBe('root');
    expect(result.sizeBytes).toBe(248);
  });

  it('returns missing status on empty output', () => {
    const result = parseStatOutput('/opt/secrets/gateforge.env', '', 'platform');
    expect(result.exists).toBe(false);
    expect(result.complianceStatus).toBe('missing');
  });
});

describe('assessCompliance', () => {
  it('flags wrong-perms when mode is 0644 instead of 0600', () => {
    const file = {
      path: '/opt/secrets/gateforge.env', tier: 'platform' as const,
      exists: true, mode: '0644', owner: 'root', group: 'root',
      sizeBytes: 248, mtimeIso: new Date().toISOString(),
      complianceStatus: 'ok' as const,
    };
    const result = assessCompliance(file, { expectedMode: '0600', expectedOwner: 'root' });
    expect(result.complianceStatus).toBe('wrong-perms');
    expect(result.complianceNote).toMatch(/0644/);
  });
});
```

---

**`testRunParser.test.ts`:**

```typescript
import { parseGateResult, classifyFlakyAgents } from '../testRunParser';
import { TestRun } from '../../types/infrastructure';

describe('parseGateResult', () => {
  it('parses Gate A pass line', () => {
    const line = '[GATE-A] dev-01@vm-3 → dispatch accepted: HTTP 200, runId=run-abc123';
    const result = parseGateResult(line, 'dev-01', 'A');
    expect(result.status).toBe('pass');
    expect(result.detail).toContain('runId=run-abc123');
  });

  it('parses Gate C timeout line', () => {
    const line = '[GATE-C] qc-01@vm-4 → HMAC callback NOT received within 90s';
    const result = parseGateResult(line, 'qc-01', 'C');
    expect(result.status).toBe('timeout');
  });
});

describe('classifyFlakyAgents', () => {
  function makeRun(id: string, pass: boolean): TestRun {
    return {
      runId: id, executedAt: new Date().toISOString(), durationMs: 60_000,
      overallStatus: pass ? 'pass' : 'fail', totalAgents: 1,
      passCount: pass ? 1 : 0, failCount: pass ? 0 : 1,
      agentResults: [{
        agentId: 'dev-01', vmId: 'vm-3', trailerCompliant: true,
        gates: (['A', 'B', 'C', 'D'] as const).map(gate => ({
          gate, status: pass ? 'pass' : 'fail' as const, detail: '',
        })),
      }],
    };
  }

  it('identifies agent with 40% pass rate as flaky', () => {
    const runs = [makeRun('1', true), makeRun('2', false), makeRun('3', false), makeRun('4', false), makeRun('5', true)];
    const flaky = classifyFlakyAgents(runs);
    expect(flaky).toHaveLength(1);
    expect(flaky[0].passRate).toBe(0.4);
  });

  it('returns empty when all agents pass ≥ 80%', () => {
    const runs = [makeRun('1', true), makeRun('2', true), makeRun('3', true), makeRun('4', true), makeRun('5', true)];
    expect(classifyFlakyAgents(runs)).toHaveLength(0);
  });
});
```

---

### 8.2 Unit Tests — Frontend Components

Target: ≥ 85% statement coverage. Tests use Jest + React Testing Library.

**`VMHealthCard.test.tsx`:**

```typescript
import { render, screen } from '@testing-library/react';
import { VMHealthCard } from '../VMHealthCard';
import { VMHealth } from '@/types/infrastructure';

const mockHealth: VMHealth = {
  vmId: 'vm-1', role: 'System Architect', hostname: 'tonic-architect',
  tailscaleIp: '100.73.38.28', port: 18789, status: 'ok',
  latencyMs: 42, lastProbed: '2026-04-07T14:00:00Z',
  isHub: true, agents: ['architect'],
};

describe('VMHealthCard', () => {
  it('renders hostname and Tailscale IP', () => {
    render(<VMHealthCard health={mockHealth} selected={false} onSelect={jest.fn()} />);
    expect(screen.getByText('tonic-architect')).toBeInTheDocument();
    expect(screen.getByText('100.73.38.28')).toBeInTheDocument();
  });

  it('shows HUB badge for hub VM', () => {
    render(<VMHealthCard health={mockHealth} selected={false} onSelect={jest.fn()} />);
    expect(screen.getByText('HUB')).toBeInTheDocument();
  });

  it('displays latency', () => {
    render(<VMHealthCard health={mockHealth} selected={false} onSelect={jest.fn()} />);
    expect(screen.getByText('42ms')).toBeInTheDocument();
  });

  it('calls onSelect when clicked', () => {
    const onSelect = jest.fn();
    render(<VMHealthCard health={mockHealth} selected={false} onSelect={onSelect} />);
    screen.getByRole('button').click();
    expect(onSelect).toHaveBeenCalledWith('vm-1');
  });
});
```

---

**`TestGateMatrix.test.tsx`:**

```typescript
import { render, screen } from '@testing-library/react';
import { TestGateMatrix } from '../TestGateMatrix';
import { TestRun } from '@/types/infrastructure';

const mockRun: TestRun = {
  runId: 'run-001', executedAt: '2026-04-07T10:00:00Z',
  durationMs: 120_000, overallStatus: 'pass', totalAgents: 1, passCount: 1, failCount: 0,
  agentResults: [{
    agentId: 'dev-01', vmId: 'vm-3', trailerCompliant: true,
    gates: [
      { gate: 'A', status: 'pass',    detail: 'HTTP 200' },
      { gate: 'B', status: 'pass',    detail: 'commit pushed' },
      { gate: 'C', status: 'pass',    detail: 'callback 45s' },
      { gate: 'D', status: 'pass',    detail: 'readable' },
    ],
  }],
};

describe('TestGateMatrix', () => {
  it('renders all 4 gate labels', () => {
    render(<TestGateMatrix run={mockRun} />);
    ['Dispatch', 'Commit', 'Callback', 'Readable'].forEach(label =>
      expect(screen.getByText(label)).toBeInTheDocument()
    );
  });

  it('shows TRAILERS OK when trailerCompliant is true', () => {
    render(<TestGateMatrix run={mockRun} />);
    expect(screen.getByText('TRAILERS OK')).toBeInTheDocument();
  });

  it('shows MISSING TRAILERS when trailerCompliant is false', () => {
    const failRun = {
      ...mockRun,
      agentResults: [{ ...mockRun.agentResults[0], trailerCompliant: false }],
    };
    render(<TestGateMatrix run={failRun} />);
    expect(screen.getByText('MISSING TRAILERS')).toBeInTheDocument();
  });
});
```

---

### 8.3 Integration Tests — Backend Routes

Route tests use `supertest` with service layer mocked. Pattern identical to existing routes in the main guide.

**`network.test.ts` (excerpt):**

```typescript
import request from 'supertest';
import app from '../../index';
import * as networkProbe from '../../services/networkProbe';

jest.mock('../../services/networkProbe');
const mockProbe = networkProbe as jest.Mocked<typeof networkProbe>;

let authCookie: string;
beforeAll(async () => {
  process.env.ADMIN_USERNAME = 'admin';
  process.env.ADMIN_PASSWORD = 'testpassword';
  process.env.JWT_SECRET = 'test-jwt-secret-32-chars!!!!!!!!';
  const res = await request(app).post('/api/auth/login').send({ username: 'admin', password: 'testpassword' });
  authCookie = res.headers['set-cookie']?.[0] ?? '';
});

describe('GET /api/infra/network/topology', () => {
  it('returns 401 without auth', async () => {
    const res = await request(app).get('/api/infra/network/topology');
    expect(res.status).toBe(401);
    expect(res.body.ok).toBe(false);
  });

  it('returns topology with valid auth', async () => {
    mockProbe.getNetworkTopology.mockResolvedValueOnce({
      vms: [{ vmId: 'vm-1', status: 'ok', latencyMs: 45, isHub: true, agents: ['architect'],
               hostname: 'tonic-architect', tailscaleIp: '100.73.38.28', port: 18789,
               lastProbed: new Date().toISOString(), role: 'System Architect' }],
      capturedAt: new Date().toISOString(), allHealthy: true, unhealthyCount: 0,
    } as never);

    const res = await request(app).get('/api/infra/network/topology').set('Cookie', authCookie);
    expect(res.status).toBe(200);
    expect(res.body.ok).toBe(true);
    expect(res.body.data.vms[0].vmId).toBe('vm-1');
  });

  it('returns 400 for missing vmId on latency-history', async () => {
    const res = await request(app).get('/api/infra/network/latency-history').set('Cookie', authCookie);
    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/vmId/i);
  });
});
```

---

**`secrets.test.ts` (security-critical assertions):**

```typescript
import request from 'supertest';
import app from '../../index';
import * as secretsInventory from '../../services/secretsInventory';

jest.mock('../../services/secretsInventory');
const mockSecrets = secretsInventory as jest.Mocked<typeof secretsInventory>;

let authCookie: string;
beforeAll(async () => {
  process.env.ADMIN_USERNAME = 'admin';
  process.env.ADMIN_PASSWORD = 'testpassword';
  process.env.JWT_SECRET = 'test-jwt-secret-32-chars!!!!!!!!';
  const res = await request(app).post('/api/auth/login').send({ username: 'admin', password: 'testpassword' });
  authCookie = res.headers['set-cookie']?.[0] ?? '';
});

describe('Secrets route — security assertions', () => {
  it('never includes file content or token values in response', async () => {
    mockSecrets.getSecretsInventory.mockResolvedValueOnce({
      vms: [{
        vmId: 'vm-1', hostname: 'tonic-architect', overallCompliant: true,
        presentCount: 1, missingCount: 0, wrongPermsCount: 0,
        files: [{
          path: '/opt/secrets/gateforge.env', tier: 'platform',
          exists: true, mode: '0600', owner: 'root', group: 'root',
          sizeBytes: 248, mtimeIso: new Date().toISOString(), complianceStatus: 'ok',
        }],
      }],
      alerts: [], rotationReminders: [], capturedAt: new Date().toISOString(),
    } as never);

    const res = await request(app).get('/api/infra/secrets/inventory').set('Cookie', authCookie);
    expect(res.status).toBe(200);

    const bodyStr = JSON.stringify(res.body);
    // No token value patterns
    expect(bodyStr).not.toMatch(/HMAC_SECRET|AGENT_SECRET|ARCHITECT_HOOK|[0-9a-f]{64}/i);
    // No content/value fields
    expect(res.body.data.vms[0].files[0]).not.toHaveProperty('content');
    expect(res.body.data.vms[0].files[0]).not.toHaveProperty('value');
  });

  it('rejects POST requests (read-only enforcement)', async () => {
    const res = await request(app).post('/api/infra/secrets/inventory').set('Cookie', authCookie);
    expect(res.status).toBe(404); // No POST handler registered — 404 from catch-all
  });
});
```

---

### 8.4 E2E Tests — Playwright

**`network-topology.spec.ts`:**

```typescript
import { test, expect } from '@playwright/test';

test.describe('Network Topology Page', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/login');
    await page.fill('[data-testid="username"]', 'admin');
    await page.fill('[data-testid="password"]', process.env.TEST_ADMIN_PASSWORD || 'testpassword');
    await page.click('[data-testid="login-btn"]');
    await page.waitForURL('/');
  });

  test('renders 5 VM health cards', async ({ page }) => {
    await page.goto('/infrastructure/network');
    await expect(page.locator('[data-testid="vm-health-card"]')).toHaveCount(5);
  });

  test('shows HUB label on VM-1', async ({ page }) => {
    await page.goto('/infrastructure/network');
    const hub = page.locator('[data-testid="vm-health-card"][data-vm="vm-1"]');
    await expect(hub.locator('[data-testid="hub-badge"]')).toHaveText('HUB');
  });

  test('displays Tailscale IPs for all VMs', async ({ page }) => {
    await page.goto('/infrastructure/network');
    const ips = ['100.73.38.28', '100.95.30.11', '100.81.114.55', '100.106.117.104', '100.95.248.68'];
    for (const ip of ips) {
      await expect(page.locator(`text=${ip}`)).toBeVisible();
    }
  });

  test('clicking VM card reveals latency chart', async ({ page }) => {
    await page.goto('/infrastructure/network');
    await page.click('[data-testid="vm-health-card"][data-vm="vm-1"]');
    await expect(page.locator('[data-testid="latency-chart"]')).toBeVisible();
  });
});
```

---

**`secrets-inventory.spec.ts`:**

```typescript
import { test, expect } from '@playwright/test';

test.describe('Secrets Inventory Page', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/login');
    await page.fill('[data-testid="username"]', 'admin');
    await page.fill('[data-testid="password"]', process.env.TEST_ADMIN_PASSWORD || 'testpassword');
    await page.click('[data-testid="login-btn"]');
    await page.waitForURL('/');
  });

  test('displays security guarantee notice', async ({ page }) => {
    await page.goto('/infrastructure/secrets');
    await expect(page.locator('text=Security guarantee')).toBeVisible();
  });

  test('renders compliance matrix for all 5 VMs', async ({ page }) => {
    await page.goto('/infrastructure/secrets');
    await expect(page.locator('[data-testid="vm-secrets-card"]')).toHaveCount(5);
  });

  test('page HTML does not contain any 64-char hex token pattern', async ({ page }) => {
    await page.goto('/infrastructure/secrets');
    const content = await page.content();
    expect(content).not.toMatch(/[0-9a-f]{64}/i);
    expect(content).not.toMatch(/Bearer [A-Za-z0-9_.-]{20,}/);
  });
});
```

---

**`openclaw-config.spec.ts`:**

```typescript
import { test, expect } from '@playwright/test';

test.describe('OpenClaw Config Viewer', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/login');
    await page.fill('[data-testid="username"]', 'admin');
    await page.fill('[data-testid="password"]', process.env.TEST_ADMIN_PASSWORD || 'testpassword');
    await page.click('[data-testid="login-btn"]');
    await page.waitForURL('/');
  });

  test('shows per-VM tabs for all 5 VMs', async ({ page }) => {
    await page.goto('/infrastructure/configs');
    for (const vmId of ['VM-1', 'VM-2', 'VM-3', 'VM-4', 'VM-5']) {
      await expect(page.locator(`button:has-text("${vmId}")`)).toBeVisible();
    }
  });

  test('switching to diff view shows VM selectors', async ({ page }) => {
    await page.goto('/infrastructure/configs');
    await page.click('button:has-text("Cross-VM Diff")');
    await expect(page.locator('select')).toHaveCount(2);
  });

  test('switching to validation view shows rule results', async ({ page }) => {
    await page.goto('/infrastructure/configs');
    await page.click('button:has-text("Validation")');
    // At least one VM validation row should be visible
    await expect(page.locator('[data-testid="vm-validation-row"]').first()).toBeVisible();
  });
});
```

---

### 8.5 Mock Mode for CI

All Category G services check `loadConfig().infraMockMode` on startup. When `INFRA_MOCK_MODE=true`, no SSH connections or Tailscale probes are attempted. Mock responses use the exact 5-VM structure with realistic data:

```typescript
// Shared mock constants — backend/src/services/__mocks__/infraMockData.ts
export const MOCK_VM_HOSTNAMES: Record<string, string> = {
  'vm-1': 'tonic-architect',
  'vm-2': 'tonic-designer',
  'vm-3': 'tonic-developer',
  'vm-4': 'tonic-qc',
  'vm-5': 'tonic-operator',
};

export const MOCK_TAILSCALE_IPS: Record<string, string> = {
  'vm-1': '100.73.38.28',
  'vm-2': '100.95.30.11',
  'vm-3': '100.81.114.55',
  'vm-4': '100.106.117.104',
  'vm-5': '100.95.248.68',
};

// Example mock gf-notify delivery event
export const MOCK_DELIVERY_EVENT = {
  eventId: 'evt-mock-001',
  timestamp: '2026-04-07T14:23:37Z',
  status: 'delivered' as const,
  priority: 'COMPLETED' as const,
  taskId: 'TASK-PORTAL-038',
  sourceVm: 'vm-3',
  sourceRole: 'developer',
  summary: 'Implemented DefectSummary component',
  hmacValid: true,
  retryCount: 0,
  deliveryLatencyMs: 312,
};

// Example mock commit trailer block
export const MOCK_COMMIT_TRAILERS = `
GateForge-Task-Id: TASK-PORTAL-038
GateForge-Priority: COMPLETED
GateForge-Source-VM: vm-3
GateForge-Source-Role: developer
GateForge-Summary: Implemented DefectSummary component with 30-day trend chart
`.trim();
```

The `.env.example` addition for CI:

```bash
# ─── Infrastructure Monitoring (Category G) ───────────────────────────────────
# SSH key path for read-only VM stat checks (mounted at /data/ssh-keys/)
INFRA_SSH_KEY_PATH=/data/ssh-keys/infra_rsa
# SSH user on target VMs for infrastructure checks
INFRA_SSH_USER=gateforge
# Tailscale health probe interval in seconds (default: 30)
NETWORK_PROBE_INTERVAL=30
# Path to test output logs volume
TEST_LOGS_PATH=/data/test-logs
# Days before a secrets file triggers a rotation reminder (default: 90)
SECRETS_ROTATION_THRESHOLD_DAYS=90
# Path to openclaw.json on each VM
OPENCLAW_CONFIG_PATH=/opt/openclaw/openclaw.json
# Set to 'true' in CI to use mock VM responses (no real SSH connections)
INFRA_MOCK_MODE=false
```

### 8.6 Security Test Checklist (Mandatory for TASK-PORTAL-153)

The following scenarios must pass before QA sign-off:

| # | Test | Pass Criteria |
|---|------|---------------|
| 1 | Secrets read-only enforcement | `POST /api/infra/secrets/*` returns 404 (no handler registered) |
| 2 | No content leakage | `GET /api/infra/secrets/inventory` response body matches `/[0-9a-f]{64}/i` → false |
| 3 | SSH command whitelist | `secretsInventory.ts` only executes `stat`, `wc -l`, `ls -la` via SSH — verified by mock assertion |
| 4 | Network probe method | `probeVM()` only calls fetch with method GET — verified by mock assertion on `node-fetch` |
| 5 | OpenClaw token redaction | Config containing `{ "gateway": { "apiKey": "secret123" } }` has that field replaced with `"[REDACTED]"` in returned `rawConfig` |
| 6 | No mutation routes | All Category G route files contain zero `router.post`, `router.put`, `router.patch`, `router.delete` calls |

---

*GateForge Admin Portal — Extended Implementation Guide (Category G) — April 2026*

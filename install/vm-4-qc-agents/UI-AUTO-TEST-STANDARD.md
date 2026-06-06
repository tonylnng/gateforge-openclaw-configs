# UI Auto-Test Standard — GateForge QC

> **Version:** 1.0.0
> **Owner:** QC Agents (VM-4, MiniMax 2.7)
> **Reviewer:** System Architect (VM-1)
> **Status:** MANDATORY for every GateForge project, every iteration
> **Last Updated:** 2026-04-30
> **Companion to:** `QA-FRAMEWORK.md`, `SOUL.md`, `AGENTS.md`

---

## 0. Why this document exists

Every project produced by GateForge — whether AI-developed (the GateForge agents writing code) or traditional human-developed — must ship with the **same** UI auto-test approach. This document is the single, project-agnostic standard that every QC agent applies on every iteration.

If you are a QC agent reading this for the first time on a project: **this file is non-optional**. Every project's `qa/` directory in the Blueprint repo must implement the standard described here. The Architect rejects any release where the QC report cannot point to evidence of compliance with each section below.

---

## 1. Scope

| Applies to | Does NOT apply to |
|---|---|
| Web UIs (React, Vue, Angular, Next.js, plain HTML) | Native mobile apps (use Appium overlay separately) |
| Browser-rendered admin portals, dashboards, public sites | CLI tools (covered by unit + integration tests) |
| AI-generated UIs produced by Developer agents | Pure backend microservices (covered by API contract tests) |
| Human-developed legacy UIs migrated into GateForge oversight | Internal pipeline tooling |

For native mobile, treat this document as the parent spec and add an Appendix in the project's `qa/test-plan.md`. The two-lane model (Section 3) still applies, with `chrome-headful` replaced by `appium-server`.

---

## 2. Principles

| # | Principle | Why it matters in GateForge |
|---|---|---|
| P1 | One pipeline, two systems | AI-built and human-built systems share the same QA gates. Differences live in the test layer, not the framework. |
| P2 | Gateway-first execution | All browser tools route through the OpenClaw `Browser` tool. Credentials, profiles, retries, and observability stay centralised — same principle as the rest of GateForge. |
| P3 | Deterministic core + AI explorer | Playwright/MCP scripts give pass/fail certainty; AI agents (MiniMax / Claude) handle exploratory coverage and self-healing selectors. |
| P4 | Page-Object + Gherkin | BDD `Given/When/Then` keeps tests readable for the end user (Tony) over Telegram; Page Objects keep them maintainable. |
| P5 | Single source of truth | Test config, env vars, selectors live in the project Blueprint repo under `qa/` — no out-of-band test plans. |
| P6 | Visual + structural + behavioural assertions | DOM snapshots, screenshot diffs, accessibility audits, and AI semantic checks run in parallel. |
| P7 | Self-healing, not selector-fragile | When DOM drifts, the AI explorer re-derives selectors from a stored intent; the deterministic suite is updated only via a Developer-agent commit reviewed by the Architect. |
| P8 | Headless Ubuntu by default | All QC runners are Ubuntu Server 22.04+ LTS, no desktop. Section 9 is the operational source of truth. |

---

## 3. Two-lane execution model

```
┌─────────────────────────────────────────────────────────────────┐
│                  OpenClaw Gateway (VM-4)                        │
│                                                                 │
│  ┌──────────────────────┐     ┌──────────────────────────────┐  │
│  │ Lane A — Deterministic│     │ Lane B — AI Exploratory      │  │
│  │ profile = openclaw    │     │ profile = user (CDP)         │  │
│  │ Playwright MCP        │     │ Chrome DevTools MCP          │  │
│  │ runs every PR         │     │ runs nightly + on-demand     │  │
│  └──────────────────────┘     └──────────────────────────────┘  │
│           │                              │                      │
│           ▼                              ▼                      │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ System Under Test (SUT) over Tailscale MagicDNS           │   │
│  │  • Web app produced by VM-3 Developers                    │   │
│  │  • or external/legacy human-built app under audit         │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

**Lane A — Deterministic Regression** (`profile=openclaw`, isolated headless Chrome)
Used in CI on every Developer push. Fails the gate verdict on any regression. No LLM cost per step.

**Lane B — AI Exploratory** (`profile=user` attached via Chrome DevTools MCP to a containerised headful Chrome)
Runs nightly or on-demand from VM-4. Drives signed-in flows, generates *new* test cases from `qa/intents.md`, and proposes additions to Lane A via defect/info notifications back to the Architect.

Both lanes execute on the same VM-4 QC runner. Lane A runs the bare Playwright process; Lane B runs Chrome inside a Docker container with a virtual display, exposed via CDP.

---

## 4. Test pyramid (mandatory weights per project)

| Layer | Tooling | Default % of suite | Owner | Runs on |
|---|---|---|---|---|
| **L1 — Unit** | Jest / Vitest / pytest / JUnit | 60% | Developer (VM-3) | Every commit |
| **L2 — API/Integration** | Supertest / RestAssured + Newman | 20% | Developer (VM-3) + QC | Every PR |
| **L3 — UI E2E (deterministic)** | OpenClaw + Playwright MCP, Page Objects, Gherkin | 12% | QC (VM-4) | Every PR + nightly |
| **L4 — UI Exploratory (AI-driven)** | OpenClaw Agent (MiniMax / Claude) via Chrome DevTools MCP | 5% | QC (VM-4) | Nightly + pre-release |
| **L5 — Visual Regression** | Playwright screenshots + pixelmatch | 2% | QC (VM-4) | Nightly |
| **L6 — Accessibility & Performance** | axe-core + Lighthouse CI | 1% | QC (VM-4) | Nightly |

**For AI-developed UIs**, L4 weight rises to **15–20%** — the QC agent records the rationale in `qa/test-plan.md` § 8.3 and the Architect approves.

---

## 5. Standard project layout (under the Blueprint repo)

This layout is **mandatory** in every GateForge Blueprint repo. The QC agent is the owner; the Architect reviews.

```
<blueprint-repo>/
└── qa/
    ├── README.md                     ← present in template (do not change ownership rules)
    ├── test-plan.md                  ← IEEE 829 master test plan (existing template)
    ├── ui-auto-test-plan.md          ← THIS standard, instantiated for the project
    ├── intents.md                    ← AI-explorer intents (plain English, one block per critical journey)
    ├── playwright.config.ts          ← Lane A configuration (committed, not generated)
    ├── openclaw.qa.yaml              ← OpenClaw profile + agent config for QC
    ├── docker-compose.qa.yml         ← Lane B headful Chrome + OpenClaw QA gateway (Section 9.4)
    ├── features/                     ← Gherkin .feature files
    │   ├── auth/
    │   ├── core-flows/
    │   └── ai-agents/                ← For projects that ship agentic UIs
    ├── steps/                        ← step definitions
    ├── pages/                        ← Page Object Model classes
    ├── fixtures/                     ← seed scripts, test data
    ├── visual-baselines/             ← PNG baselines (committed)
    ├── ai-explorer/
    │   ├── prompts/                  ← prompt templates per intent class
    │   └── generated/                ← AI-proposed tests (PR-reviewed before promotion)
    ├── reports/                      ← run output: HTML + JUnit + Allure
    ├── test-cases/                   ← existing IEEE 829 test cases
    ├── defects/                      ← existing defect reports
    └── metrics.md                    ← existing QA dashboard (extended for UI auto-test KPIs)
```

The QC agent creates this structure on first project entry by following the `qa/README.md` and the bootstrap script in `roles/qc/` (or VM-4 in the multi-agent variant). Missing files are a release-blocking issue and trigger a `BLOCKED` notification.

---

## 6. Quality gates (UI auto-test additions to QA-FRAMEWORK.md gates)

These are **additive** to the gates in `QA-FRAMEWORK.md` § 5. Every release must pass both sets.

| Gate | Threshold | Block release? |
|---|---|---|
| **G-UI-1 — Lane A pass rate** | 100% on 3 retries; zero P0/P1 defects | Yes |
| **G-UI-2 — Visual regression** | < 0.1% pixel diff on critical pages | Warn → Yes after Architect sign-off |
| **G-UI-3 — Accessibility (axe)** | 0 critical, 0 serious | Yes |
| **G-UI-4 — Lighthouse perf** | Performance ≥ 80, LCP < 2.5s | Warn |
| **G-UI-5 — Lane B nightly** | No new P0/P1 vs previous baseline | Block release, not merge |
| **G-UI-6 — Intent coverage** | 100% of intents in `qa/intents.md` have a passing AI run | Yes (release gate) |
| **G-UI-7 — Headless compliance** | Section 9 checklist signed in `metrics.md` | Yes |

The QC agent's `qaFramework` JSON output (per `SOUL.md` § "QA Framework Output") **must** add these fields:

```json
{
  "uiAutoTest": {
    "laneA": { "total": 0, "passed": 0, "failed": 0, "passRate": "0%" },
    "laneB": { "intentsTotal": 0, "intentsPassed": 0, "newDefects": [] },
    "visualDrift": "0.00%",
    "a11yCritical": 0,
    "a11ySerious": 0,
    "lighthousePerf": 0,
    "headlessComplianceSigned": false
  }
}
```

A missing or zero-only `uiAutoTest` block on a release-tagged commit is a `BLOCKED` notification.

---

## 7. Strategy differences — AI-built vs human-built systems

| Dimension | Human-built | AI-built (GateForge Developer agents) |
|---|---|---|
| Failure modes | Logic bugs, regression, integration | Hallucinated UI, prompt drift, non-determinism, model deprecation |
| Selector strategy | `data-testid` enforced in code review by Architect | AI re-derives from semantic snapshot each run |
| Assertion style | Exact string / DOM matchers | Semantic matchers + LLM-as-judge for fuzzy text |
| Flake tolerance | 0 — fix the test | Built-in retries + temperature pinning + golden-set comparison |
| Test generation | Human writes Gherkin | QC's Lane B generates Gherkin from `intents.md`, Architect promotes via PR |
| Regression baseline | Frozen selectors + screenshots | Frozen *intents* + screenshots; selectors re-derived |
| Coverage tracking | LCOV / Cobertura | Intent-coverage matrix (Section 6, G-UI-6) |
| CI cost driver | Compute minutes | LLM token spend — pin model, cache snapshots, sample don't exhaust |

**Cost control for Lane B (mandatory):** hard token budget per project, prefer DOM snapshot over screenshot when possible, run Lane B only on intent files that changed since the last successful run.

---

## 8. Standard test anatomy (use as templates)

### 8.1 Gherkin feature

```gherkin
@critical @smoke
Feature: User login
  As a registered user
  I want to log in
  So I can access my dashboard

  Background:
    Given the test database is seeded with user "qa@gateforge.local"

  Scenario: Successful login with valid credentials
    Given I am on the login page
    When I enter username "qa@gateforge.local" and password "***"
    And I click the login button
    Then I should be redirected to "/home"
    And the page should be accessible (axe: 0 critical)
    And the visual baseline "post-login" should match within 0.1%
```

### 8.2 Page Object (TypeScript)

```typescript
// qa/pages/LoginPage.ts
import { Page, expect } from '@playwright/test';

export class LoginPage {
  constructor(private page: Page) {}
  readonly username = () => this.page.getByTestId('login-username');
  readonly password = () => this.page.getByTestId('login-password');
  readonly submit   = () => this.page.getByTestId('login-submit');

  async goto()  { await this.page.goto('/login'); }
  async login(u: string, p: string) {
    await this.username().fill(u);
    await this.password().fill(p);
    await this.submit().click();
    await expect(this.page).toHaveURL(/\/home/);
  }
}
```

### 8.3 OpenClaw QA config (`qa/openclaw.qa.yaml`)

```yaml
profiles:
  ci-deterministic:
    profile: openclaw          # isolated, no shared cookies
    headless: true
    retries: 2
    trace: on-first-retry
  ai-explorer:
    profile: user              # attaches Chrome DevTools MCP
    cdpUrl: "ws://chrome-headful:3000"
    timeoutMs: 60000

agents:
  qc-deterministic:
    role: QC
    model: minimax/minimax-2.7
    tools: [playwright-mcp]
    profile: ci-deterministic
  qc-explorer:
    role: QC
    model: minimax/minimax-2.7   # bump to claude-sonnet-4-6 if intent semantics demand it
    tools: [chrome-devtools-mcp, playwright-mcp]
    profile: ai-explorer
    intentFile: qa/intents.md

reporting:
  formats: [junit, html, allure]
  artifactsDir: qa/reports
  uploadTo: s3://gateforge-qa-artifacts/${PROJECT}/
```

### 8.4 AI exploratory intent file (`qa/intents.md`)

```markdown
## Intent: New-user onboarding survives chaos
- A first-time visitor lands on /signup
- They submit invalid email → see inline error
- They submit valid email + weak password → see strength warning
- They complete signup → land on /welcome with their display name
- Refresh /welcome → still authenticated
- Log out → /login is visible

## Intent: Admin Portal self-healing
- Open /agents
- An offline agent must show red status within 30s of disconnect
- Reconnect → status flips to green within 30s
- A 500 error from /api/agents must surface a toast, not crash the page
```

The QC-Explorer agent reads these intents and **generates** Playwright tests + Gherkin into `qa/ai-explorer/generated/`. The Architect reviews and a Developer agent (VM-3 in the multi-agent variant, the same agent in the single-agent variant) promotes them to `qa/features/` via PR — this is the AI-augmented test authoring loop.

---

## 9. Headless Ubuntu Operations (mandatory operational baseline)

> **Standard target environment for all QC runners: Ubuntu Server 22.04+ LTS, no desktop, Tailscale-attached.** Every QC runner in the GateForge fleet must follow this section. This is the operational source of truth.

### 9.1 Why headless is the default

- Every cloud CI provider (GitHub Actions, GitLab, CircleCI) runs Playwright on headless Ubuntu — most-tested deployment surface.
- Lower attack surface (no X server, no display manager, no desktop apps).
- Lower memory footprint — fits 3–5 concurrent browser sessions in 8 GB RAM.
- Reproducible — no human desktop state can leak into tests.
- Aligns with the GateForge VM topology (Tailscale mesh, no GUI on any node).

The only capability lost is *attaching to a human's live signed-in Chrome* — irrelevant on a server. Logged-in flows are handled via persistent profile directories or token-based auth (Section 9.5).

### 9.2 Two-lane execution on headless Ubuntu

| Lane | Mode | Display required? | Use case |
|---|---|---|---|
| **Lane A — Deterministic** | `chromium --headless=new` | None | CI regression, every PR |
| **Lane B — AI Exploratory** | Containerised Chrome + Xvfb, exposed via CDP | Virtual only (inside container) | Nightly AI agent runs |
| **Lane B fallback** | `xvfb-run` wrapper on host | Virtual on host | Tests that fail in pure headless (rare) |

### 9.3 Bootstrap script — fresh Ubuntu Server VM

Drop this into `qa/scripts/bootstrap-qa-runner.sh` in every project. Idempotent.

```bash
#!/usr/bin/env bash
# qa/scripts/bootstrap-qa-runner.sh
# Prepare a fresh Ubuntu 22.04+ Server VM as a GateForge QC runner.
set -euo pipefail

echo "==> System update"
sudo apt-get update -y && sudo apt-get upgrade -y

echo "==> Core deps (headless Chromium runtime libs)"
sudo apt-get install -y \
  ca-certificates curl gnupg lsb-release git jq unzip \
  fonts-liberation fonts-noto-cjk \
  libnss3 libatk-bridge2.0-0 libgbm1 libasound2 \
  libxkbcommon0 libxcomposite1 libxdamage1 libxfixes3 \
  libxrandr2 libgtk-3-0 libpango-1.0-0 libcairo2 \
  xvfb x11-utils

echo "==> Node 20 LTS"
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
sudo npm install -g pnpm@latest

echo "==> Docker + Compose plugin"
if ! command -v docker >/dev/null; then
  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker "$USER"
fi

echo "==> Playwright + browsers (with system deps)"
npx --yes playwright install --with-deps chromium

echo "==> OpenClaw gateway (must already be installed by setup-vm4-qc.sh)"
command -v openclaw >/dev/null || { echo "OpenClaw missing — run install/setup-vm4-qc.sh first"; exit 1; }

echo "==> Tailscale check"
command -v tailscale >/dev/null || echo "WARN: Tailscale not installed; QC runner must join the tailnet"

echo "==> Health check"
node -v ; docker --version ; openclaw --version || true ; npx playwright --version
echo "==> Bootstrap complete. Reboot or re-login for docker group to take effect."
```

### 9.4 Standard `qa/docker-compose.qa.yml`

```yaml
services:
  # Lane A is launched directly by Playwright per worker — no service needed.

  # Lane B — long-running headful Chrome with virtual display, exposed via CDP.
  chrome-headful:
    image: browserless/chrome:latest
    container_name: qa-chrome-headful
    restart: unless-stopped
    ports:
      - "127.0.0.1:9222:3000"        # CDP only on localhost; Tailscale-only access
    environment:
      - CONNECTION_TIMEOUT=600000
      - MAX_CONCURRENT_SESSIONS=5
      - DEFAULT_BLOCK_ADS=false
      - ENABLE_DEBUGGER=false
      - ENABLE_API_GET=false
      - WORKSPACE_DELETE_EXPIRED=true
    shm_size: "2gb"
    volumes:
      - ./chrome-profiles/qa-bot:/profile
      - ./reports/downloads:/downloads
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/json/version"]
      interval: 30s
      timeout: 5s
      retries: 3

  # OpenClaw QA gateway — orchestrates Playwright MCP + Chrome DevTools MCP
  openclaw-qa:
    image: openclaw/gateway:latest
    container_name: qa-openclaw
    restart: unless-stopped
    depends_on:
      chrome-headful:
        condition: service_healthy
    environment:
      - OPENCLAW_BROWSER_CDP_URL=ws://chrome-headful:3000
      - OPENCLAW_PROFILE_DEFAULT=ci-deterministic
      - OPENCLAW_REPORTS_DIR=/reports
    volumes:
      - ./openclaw.qa.yaml:/etc/openclaw/qa.yaml:ro
      - ./reports:/reports
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks: [default]
```

### 9.5 Logged-in state without a human

| Pattern | When to use | How |
|---|---|---|
| **Token / API key auth** | Internal apps, GateForge, anything you control | Inject bearer token via `localStorage.setItem` or cookie before navigation. Tokens rotate via the GateForge secrets layout (`~/.config/gateforge/<app>.env`). |
| **Persistent `userDataDir`** | SSO portals, hospital systems, third-party apps | Seed profile once on a workstation → tar → copy to VM `qa/chrome-profiles/qa-bot/` → mount into container. Refresh quarterly. |
| **Storage state JSON** | Playwright-native flows | `await context.storageState({ path: 'auth.json' })` once, then `storageState: 'auth.json'` in `playwright.config.ts`. |
| **Programmatic login fixture** | Short-lived credentials | Playwright `globalSetup` logs in via API, writes `storageState`, reused by all workers. |

**Never** commit profile directories or `auth.json` to git. Keep them in `/var/lib/openclaw/secrets/`, an S3 bucket reachable only via Tailscale, or sealed via SOPS / age in the repo.

### 9.6 Required Chromium flags for headless Linux

```typescript
// qa/playwright.config.ts
export default defineConfig({
  use: {
    launchOptions: {
      args: [
        '--no-sandbox',
        '--disable-dev-shm-usage',
        '--disable-gpu',
        '--headless=new',
        '--disable-blink-features=AutomationControlled',
      ],
    },
  },
});
```

For Lane B (containerised headful) inside the `browserless/chrome` image:

```bash
chromium \
  --headless=new \
  --remote-debugging-address=0.0.0.0 \
  --remote-debugging-port=3000 \
  --user-data-dir=/profile \
  --no-sandbox --disable-dev-shm-usage --disable-gpu
```

### 9.7 Xvfb fallback (rare)

```bash
# One-shot
xvfb-run -a --server-args="-screen 0 1920x1080x24" pnpm playwright test

# Persistent systemd service
sudo tee /etc/systemd/system/xvfb.service > /dev/null <<'EOF'
[Unit]
Description=Xvfb virtual framebuffer
After=network.target
[Service]
ExecStart=/usr/bin/Xvfb :99 -screen 0 1920x1080x24 -nolisten tcp
Restart=always
User=qa
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl enable --now xvfb
```

### 9.8 Resource sizing per QC VM

| Concurrent browser workers | vCPU | RAM | `shm_size` | Notes |
|---|---|---|---|---|
| 1 (smoke) | 2 | 4 GB | 1 GB | Minimum |
| 3 (per-PR CI) | 4 | 8 GB | 2 GB | **Standard** for VM-4 |
| 5 (heavy regression + Lane B) | 8 | 16 GB | 4 GB | Nightly suite |
| 10+ (parallel matrix) | 16 | 32 GB | 8 GB | Dedicated runner pool |

### 9.9 Networking on Tailscale-only QC VMs

- No public ports. Inbound on `tailscale0` only.
- CDP endpoint (`9222` / `3000`) bound to `127.0.0.1` — never `0.0.0.0`.
- Reports artefact upload outbound to S3 / MinIO via Tailscale exit node.
- SUT reachable via Tailscale MagicDNS (e.g. `gateforge-staging.<tailnet>.ts.net`).
- Outbound LLM API calls routed through the OpenClaw gateway VM, not directly from the QC runner — keeps API keys centralised.

```jsonc
// tailscale ACL — QC runners can reach SUT, not vice versa
{
  "acls": [
    { "action": "accept",
      "src":  ["tag:qa-runner"],
      "dst":  ["tag:sut-staging:*", "tag:openclaw-gateway:443"] }
  ]
}
```

### 9.10 Operational runbook

```bash
# Health check the QA stack
docker compose -f qa/docker-compose.qa.yml ps
curl -fsS http://127.0.0.1:9222/json/version | jq .
openclaw status

# Run Lane A (deterministic) on demand
cd qa && pnpm playwright test --reporter=html

# Run Lane B (AI exploratory) on a single intent
openclaw run agent qc-explorer \
  --intent qa/intents.md#new-user-onboarding \
  --report qa/reports/explorer-$(date +%F).html

# Tail logs
docker compose -f qa/docker-compose.qa.yml logs -f --tail=200

# Refresh logged-in profile (quarterly or on session expiry)
./qa/scripts/refresh-qa-profile.sh

# Rotate LLM tokens used by Lane B
openclaw secrets rotate --role qc-explorer

# Clean up reports older than 30 days
find qa/reports -type d -mtime +30 -exec rm -rf {} +
```

### 9.11 Troubleshooting matrix

| Symptom | Likely cause | Fix |
|---|---|---|
| `Failed to launch chrome — running as root without --no-sandbox` | Container default user is root | Add `--no-sandbox` to launch args (already in standard config) |
| `Target page, context or browser has been closed` mid-test | `/dev/shm` exhaustion | Increase `shm_size: "2gb"` or add `--disable-dev-shm-usage` |
| Tests pass locally, fail on VM with timeout | Slower VM CPU + animations | Set `actionTimeout: 15000` and disable CSS animations via `prefers-reduced-motion` injection |
| Fonts rendering as boxes / CJK missing | Missing font packages | `apt install fonts-noto-cjk fonts-liberation` (already in bootstrap) |
| Lane B agent can't reach Chrome | CDP bound to wrong interface | Confirm `--remote-debugging-address=0.0.0.0` in container, `127.0.0.1:9222` mapped on host |
| Visual diffs flaky on headless | Sub-pixel font rendering differs from dev | Pin baselines to headless runs only |
| Chrome zombie processes accumulate | Crashed sessions not cleaned | Browserless image handles this; otherwise add `dumb-init` as PID 1 |
| OpenClaw can't see CDP endpoint | Service order race | `depends_on.condition: service_healthy` (already in standard compose) |
| Out-of-memory during nightly suite | Too many parallel workers | Reduce `workers: 3` in `playwright.config.ts` or upsize VM |

### 9.12 Headless Ubuntu compliance checklist (paste into `qa/metrics.md`)

- [ ] VM is Ubuntu Server 22.04+ LTS, no desktop installed
- [ ] `qa/scripts/bootstrap-qa-runner.sh` executed and idempotent
- [ ] `docker compose -f qa/docker-compose.qa.yml up -d` runs cleanly
- [ ] CDP endpoint accessible only on `127.0.0.1` and Tailscale interface
- [ ] Playwright launch args include `--no-sandbox --disable-dev-shm-usage --headless=new`
- [ ] Logged-in profile or `storageState` stored outside git, mounted read-only
- [ ] Xvfb installed as fallback even if not actively used
- [ ] CJK + Liberation fonts installed (Hong Kong / mainland clients)
- [ ] Lane A runs in CI without external display
- [ ] Lane B containerised; never depends on host display
- [ ] Reports directory persisted to S3 / MinIO via Tailscale
- [ ] Resource tier (vCPU / RAM / shm) matches Section 9.8 for expected workload
- [ ] Operator can execute every command in Section 9.10 from memory

The QC agent commits this checklist with all boxes ticked as part of every release. An unticked box is a `BLOCKED` notification.

---

## 10. CI/CD integration

### 10.1 Per-PR (GitHub Actions, deterministic only)

```yaml
# .github/workflows/qa-ui.yml
name: QA UI Auto-Test
on: [pull_request, push]

jobs:
  e2e-deterministic:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: bash qa/scripts/bootstrap-qa-runner.sh
      - run: docker compose -f qa/docker-compose.qa.yml up -d chrome-headful
      - run: cd qa && pnpm playwright test --reporter=junit,html
      - uses: actions/upload-artifact@v4
        with: { name: e2e-report, path: qa/reports/ }
```

### 10.2 Nightly Lane B (n8n on VM-4)

```
[Cron 02:00 HKT]
  → [HTTP: GET /api/changed-intents]
  → [OpenClaw: spawn qc-explorer agent on each changed intent]
  → [Parse results → JUnit]
  → [If new P0/P1 → BLOCKED notification to Architect via host-side notifier]
  → [Else → archive to S3 + update Grafana dashboard]
```

The Lane B nightly run reports through the same `gf-notify-architect` service used for every other VM-4 commit; no direct HTTP calls from the agent.

---

## 11. Governance and metrics

The QC agent must update these KPIs in `qa/metrics.md` after every test run:

1. **Test Reliability Rate** — % of runs without flake. Target ≥ 99%.
2. **Defect Escape Rate** — bugs found in prod / total bugs found. Target < 5%.
3. **Mean Time to Detect (MTTD)** — commit → failing test alert. Target < 15 min.
4. **Lane B Token Cost / week** — keep under per-project budget cap.
5. **Intent Coverage** — # intents with passing AI run / total intents. Target 100%.
6. **Visual Drift Index** — average pixel diff across baselines. Track trend.
7. **A11y Critical Issues** — must be 0 on `main`.
8. **Test Authoring Lead Time** — task open → test merged. Target < 1 day.

Defects link to `qa/defects/DEF-NNN.md`. Recurring patterns feed back into `qa/intents.md` so the AI explorer never misses the same pattern twice.

---

## 12. Per-project rollout (mandatory)

Every project enters a 5-step rollout — the QC agent records progress in `project/status.md`:

| Step | Goal | Exit criteria |
|---|---|---|
| 1. Scaffold | Create `qa/ui-auto-test-plan.md`, `intents.md`, `playwright.config.ts`, `openclaw.qa.yaml`, `docker-compose.qa.yml`, `scripts/bootstrap-qa-runner.sh` from this standard | All files committed; CI workflow created |
| 2. Seed | Author 1 Gherkin feature per critical user journey; populate `intents.md` with 5–10 entries | `qa/features/` non-empty; `intents.md` reviewed by Architect |
| 3. Bootstrap VM | Run `bootstrap-qa-runner.sh` on the QC runner VM; bring up `docker-compose.qa.yml` | `openclaw status` clean; CDP healthy |
| 4. First green build | Lane A passes 100% on a smoke PR | Green CI badge; Architect approval |
| 5. Sign compliance | Tick all boxes in Section 9.12; record in `metrics.md` | Architect signs off; release gate eligible |

Skipping any step is a `BLOCKED` notification.

---

## 13. References

- `QA-FRAMEWORK.md` (this directory) — governing QA methodology and gate decision model
- `SOUL.md` (this directory) — QC agent persona, output JSON, notification protocol
- `AGENTS.md` (this directory) — agent registry and inter-VM communication
- `../vm-1-architect/SOUL.md` — Architect's gate enforcement responsibilities
- `../vm-3-developers/DEVELOPMENT-GUIDE.md` — Developer testability requirements (`data-testid`, accessible labels)
- `_SHARED_NOTIFICATION_PROTOCOL.md` (parent install dir) — host-side notifier behaviour
- Blueprint template: `qa/ui-auto-test-plan.md` — per-project instantiation template

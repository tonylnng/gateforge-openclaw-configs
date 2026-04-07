# GateForge Admin Portal — Implementation Guide

**Document Status:** Implementation-Ready  
**Version:** 1.0  
**Author:** GateForge Agent Team  
**Created:** 2026-04-07  
**References:**
- Feature Specification: `GATEFORGE-ADMIN-PORTAL.md`
- Architecture Context: `README.md`
- Reference Project: ClawDeck (`clawdeck/`)

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Project Setup & Scaffolding](#2-project-setup--scaffolding)
3. [Type Definitions & Data Models](#3-type-definitions--data-models)
4. [Backend Implementation](#4-backend-implementation)
5. [Frontend Implementation](#5-frontend-implementation)
6. [Implementation Phases & Task Breakdown](#6-implementation-phases--task-breakdown)
7. [Testing Strategy](#7-testing-strategy)
8. [Security Considerations](#8-security-considerations)
9. [Performance Requirements](#9-performance-requirements)
10. [Integration Points with GateForge](#10-integration-points-with-gateforge)
11. [Appendix: Status Color Constants](#11-appendix-status-color-constants)
12. [Appendix: Mock Data](#12-appendix-mock-data)

---

## 1. Project Overview

### Purpose of This Document

This is a developer-ready implementation document for the GateForge Admin Portal. It translates the feature specification (`GATEFORGE-ADMIN-PORTAL.md`) into concrete implementation instructions. A Developer agent can pick up any module described here and implement it without needing to reference the feature spec.

This document contains actual TypeScript type definitions, JSON configs, file paths, component props, route specifications, and task breakdowns with acceptance criteria. It is not a summary or a design document — it is a build guide.

### Relationship to the Feature Specification

The Feature Specification (`GATEFORGE-ADMIN-PORTAL.md`) defines *what* the portal does and *why*. This Implementation Guide defines *how* to build it. When the two documents appear to conflict, the Feature Specification is authoritative on functional behaviour; this guide is authoritative on technical implementation choices.

### Target Audience

This document is written for the GateForge multi-agent development team:
- **VM-2 (System Designer):** Use Section 2 (scaffolding), Section 4.1–4.3 (backend architecture), and Section 10 (integration points) for infrastructure design tasks.
- **VM-3 (Developers):** Use Sections 3–5 as the primary implementation reference. Each section maps directly to buildable modules.
- **VM-4 (QC Agents):** Use Sections 7 and 12 (mock data) for test scaffolding. Coverage targets are specified in Section 7.
- **VM-5 (Operator):** Use Section 2 (Dockerfiles, docker-compose) and Section 9 (performance requirements) for deployment configuration.

### Naming Convention

- Repository name: `gateforge-admin-portal`
- Docker container names: `gateforge-portal-frontend`, `gateforge-portal-backend`
- npm package names: `gateforge-portal-frontend`, `gateforge-portal-backend`
- Commit prefix: `portal:` (e.g., `portal: add AgentCard component`)
- Branch convention: `feature/TASK-PORTAL-NNN-short-description`
- Environment prefix for env vars: `GATEFORGE_` for portal-specific vars, retained names from ClawDeck pattern for shared vars (JWT, ADMIN, etc.)

---

## 2. Project Setup & Scaffolding

### 2.1 Repository Structure

```
gateforge-admin-portal/
├── frontend/
│   ├── src/
│   │   ├── app/
│   │   │   ├── (auth)/
│   │   │   │   └── login/
│   │   │   │       └── page.tsx
│   │   │   ├── (portal)/
│   │   │   │   ├── layout.tsx
│   │   │   │   ├── page.tsx                    # Agent Dashboard
│   │   │   │   ├── pipeline/page.tsx
│   │   │   │   ├── blueprint/
│   │   │   │   │   ├── page.tsx
│   │   │   │   │   └── [path]/page.tsx
│   │   │   │   ├── project/page.tsx
│   │   │   │   ├── qa/page.tsx
│   │   │   │   ├── operations/page.tsx
│   │   │   │   ├── notifications/page.tsx
│   │   │   │   ├── setup/page.tsx
│   │   │   │   └── agents/[vmId]/[agentId]/page.tsx
│   │   │   ├── globals.css
│   │   │   └── layout.tsx
│   │   ├── components/
│   │   │   ├── agents/
│   │   │   │   ├── AgentCard.tsx
│   │   │   │   ├── AgentDetailModal.tsx
│   │   │   │   ├── AgentGrid.tsx
│   │   │   │   ├── NotificationBadge.tsx
│   │   │   │   └── StatusDot.tsx
│   │   │   ├── blueprint/
│   │   │   │   ├── CommitLog.tsx
│   │   │   │   ├── DocumentViewer.tsx
│   │   │   │   ├── FileTree.tsx
│   │   │   │   └── StatusBadge.tsx
│   │   │   ├── layout/
│   │   │   │   ├── Header.tsx
│   │   │   │   ├── Sidebar.tsx
│   │   │   │   ├── ThemeProvider.tsx
│   │   │   │   └── ThemeToggle.tsx
│   │   │   ├── notifications/
│   │   │   │   ├── FilterBar.tsx
│   │   │   │   ├── NotificationEntry.tsx
│   │   │   │   └── NotificationFeed.tsx
│   │   │   ├── operations/
│   │   │   │   ├── BurnRateCard.tsx
│   │   │   │   ├── DeploymentLog.tsx
│   │   │   │   ├── EnvironmentCard.tsx
│   │   │   │   ├── IncidentTimeline.tsx
│   │   │   │   └── SLOGauge.tsx
│   │   │   ├── pipeline/
│   │   │   │   ├── LobsterYAMLPreview.tsx
│   │   │   │   ├── PhaseDetailPanel.tsx
│   │   │   │   ├── PhaseNode.tsx
│   │   │   │   ├── PipelineCanvas.tsx
│   │   │   │   ├── QualityGatePanel.tsx
│   │   │   │   └── TaskList.tsx
│   │   │   ├── project/
│   │   │   │   ├── BlockersList.tsx
│   │   │   │   ├── BurndownChart.tsx
│   │   │   │   ├── HealthCard.tsx
│   │   │   │   └── TaskTable.tsx
│   │   │   ├── qa/
│   │   │   │   ├── CoverageGauge.tsx
│   │   │   │   ├── DefectSummary.tsx
│   │   │   │   ├── GateDecisionCard.tsx
│   │   │   │   └── SecurityPanel.tsx
│   │   │   ├── setup/
│   │   │   │   ├── HealthCheckDashboard.tsx
│   │   │   │   ├── SetupWizard.tsx
│   │   │   │   ├── VMRegistrationCard.tsx
│   │   │   │   └── steps/
│   │   │   │       ├── Step1Admin.tsx
│   │   │   │       ├── Step2VMs.tsx
│   │   │   │       ├── Step3AIKeys.tsx
│   │   │   │       ├── Step4Telegram.tsx
│   │   │   │       ├── Step5Blueprint.tsx
│   │   │   │       ├── Step6Deploy.tsx
│   │   │   │       └── Step7Review.tsx
│   │   │   └── ui/                             # shadcn/ui primitives
│   │   ├── hooks/
│   │   │   ├── useAgents.ts
│   │   │   ├── useNotifications.ts
│   │   │   ├── usePipeline.ts
│   │   │   └── useSSE.ts
│   │   └── lib/
│   │       ├── api.ts
│   │       ├── constants.ts
│   │       └── utils.ts
│   ├── Dockerfile
│   ├── next.config.js
│   ├── package.json
│   ├── postcss.config.js
│   ├── tailwind.config.ts
│   └── tsconfig.json
├── backend/
│   ├── src/
│   │   ├── config.ts
│   │   ├── index.ts
│   │   ├── middleware/
│   │   │   ├── auth.ts
│   │   │   └── rateLimiter.ts
│   │   ├── routes/
│   │   │   ├── agents.ts
│   │   │   ├── auth.ts
│   │   │   ├── blueprint.ts
│   │   │   ├── events.ts
│   │   │   ├── notifications.ts
│   │   │   ├── operations.ts
│   │   │   ├── pipeline.ts
│   │   │   ├── project.ts
│   │   │   ├── qa.ts
│   │   │   └── setup.ts
│   │   └── services/
│   │       ├── blueprintGit.ts
│   │       ├── gatewayClient.ts
│   │       ├── notificationBus.ts
│   │       ├── poller.ts
│   │       ├── stateCache.ts
│   │       ├── telegramMonitor.ts
│   │       └── usvmProbe.ts
│   ├── Dockerfile
│   ├── package.json
│   └── tsconfig.json
├── docker-compose.yml
├── .env.example
├── install.sh
└── README.md
```

### 2.2 Frontend `package.json`

```json
{
  "name": "gateforge-portal-frontend",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "type-check": "tsc --noEmit",
    "test": "jest --passWithNoTests",
    "test:e2e": "playwright test"
  },
  "dependencies": {
    "@radix-ui/react-avatar": "^1.0.4",
    "@radix-ui/react-dialog": "^1.0.5",
    "@radix-ui/react-dropdown-menu": "^2.0.6",
    "@radix-ui/react-label": "^2.0.2",
    "@radix-ui/react-scroll-area": "^1.0.5",
    "@radix-ui/react-select": "^2.0.0",
    "@radix-ui/react-separator": "^1.0.3",
    "@radix-ui/react-slot": "^1.0.2",
    "@radix-ui/react-tabs": "^1.0.4",
    "@radix-ui/react-toast": "^1.1.5",
    "@radix-ui/react-tooltip": "^1.0.7",
    "@radix-ui/react-progress": "^1.0.3",
    "@xyflow/react": "^12.0.0",
    "class-variance-authority": "^0.7.0",
    "clsx": "^2.0.0",
    "lucide-react": "^0.303.0",
    "next": "14.0.4",
    "next-themes": "^0.2.1",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-markdown": "^9.0.1",
    "react-syntax-highlighter": "^15.5.0",
    "react-virtualized-auto-sizer": "^1.0.20",
    "react-window": "^1.8.10",
    "recharts": "^3.8.0",
    "remark-gfm": "^4.0.0",
    "tailwind-merge": "^2.2.0",
    "tailwindcss-animate": "^1.0.7"
  },
  "devDependencies": {
    "@playwright/test": "^1.40.0",
    "@testing-library/jest-dom": "^6.1.5",
    "@testing-library/react": "^14.1.2",
    "@testing-library/user-event": "^14.5.1",
    "@types/node": "^20.10.0",
    "@types/react": "^18.2.45",
    "@types/react-dom": "^18.2.18",
    "@types/react-syntax-highlighter": "^15.5.11",
    "@types/react-virtualized-auto-sizer": "^1.0.4",
    "@types/react-window": "^1.8.8",
    "autoprefixer": "^10.4.16",
    "jest": "^29.7.0",
    "jest-environment-jsdom": "^29.7.0",
    "postcss": "^8.4.32",
    "tailwindcss": "^3.4.0",
    "typescript": "^5.3.2"
  }
}
```

### 2.3 Backend `package.json`

```json
{
  "name": "gateforge-portal-backend",
  "version": "1.0.0",
  "description": "GateForge Admin Portal Backend",
  "main": "dist/index.js",
  "scripts": {
    "build": "tsc",
    "start": "node dist/index.js",
    "dev": "ts-node src/index.ts",
    "test": "jest --passWithNoTests",
    "type-check": "tsc --noEmit"
  },
  "dependencies": {
    "bcryptjs": "^2.4.3",
    "cookie-parser": "^1.4.6",
    "cors": "^2.8.5",
    "dotenv": "^16.3.1",
    "express": "^4.18.2",
    "express-rate-limit": "^7.1.5",
    "helmet": "^7.1.0",
    "jsonwebtoken": "^9.0.2",
    "node-fetch": "^2.7.0",
    "simple-git": "^3.21.0"
  },
  "devDependencies": {
    "@types/bcryptjs": "^2.4.6",
    "@types/cookie-parser": "^1.4.7",
    "@types/cors": "^2.8.17",
    "@types/express": "^4.17.21",
    "@types/jest": "^29.5.8",
    "@types/jsonwebtoken": "^9.0.5",
    "@types/node": "^20.10.0",
    "@types/node-fetch": "^2.6.9",
    "jest": "^29.7.0",
    "ts-jest": "^29.1.1",
    "ts-node": "^10.9.1",
    "typescript": "^5.3.2"
  }
}
```

### 2.4 Backend `Dockerfile`

```dockerfile
# Stage 1: Build
FROM node:20-alpine AS builder

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm install --frozen-lockfile

COPY tsconfig.json ./
COPY src ./src

RUN npm run build

# Stage 2: Production
FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production

COPY package.json package-lock.json ./
RUN npm install --production --frozen-lockfile

COPY --from=builder /app/dist ./dist

# Create volume mount points
RUN mkdir -p /data/blueprint-clone /data/ssh-keys /data/config

EXPOSE 3001

CMD ["node", "dist/index.js"]
```

### 2.5 Frontend `Dockerfile`

```dockerfile
# Stage 1: Dependencies
FROM node:20-alpine AS deps

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm install --frozen-lockfile

# Stage 2: Builder
FROM node:20-alpine AS builder

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .

ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_ENV=production

ARG NEXT_PUBLIC_BACKEND_URL=http://localhost:3001
ENV NEXT_PUBLIC_BACKEND_URL=${NEXT_PUBLIC_BACKEND_URL}

RUN npm run build

# Stage 3: Runner
FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

CMD ["node", "server.js"]
```

### 2.6 `docker-compose.yml`

```yaml
# GateForge Admin Portal — docker-compose.yml
# Generated by install.sh

version: "3.9"

services:
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: gateforge-portal-backend
    restart: unless-stopped
    # On Linux host with route to 192.168.72.0/24:
    network_mode: host
    # On macOS: remove network_mode: host, uncomment below:
    # networks:
    #   - gateforge-portal
    # extra_hosts:
    #   - "host.docker.internal:host-gateway"
    # ports:
    #   - "${BACKEND_PORT:-3001}:3001"
    volumes:
      - blueprint-clone:/data/blueprint-clone
      - ssh-keys:/data/ssh-keys:ro
      - config:/data/config
    env_file:
      - .env
    environment:
      - NODE_ENV=${NODE_ENV:-production}
      - BACKEND_PORT=${BACKEND_PORT:-3001}
      - FRONTEND_URL=${FRONTEND_URL:-http://localhost:3000}
      - ADMIN_USERNAME=${ADMIN_USERNAME}
      - ADMIN_PASSWORD_HASH=${ADMIN_PASSWORD_HASH}
      - ADMIN_PASSWORD=${ADMIN_PASSWORD}
      - JWT_SECRET=${JWT_SECRET}
      - JWT_EXPIRES_IN=${JWT_EXPIRES_IN:-24h}
      - GATEFORGE_VMS=${GATEFORGE_VMS}
      - BLUEPRINT_REPO_URL=${BLUEPRINT_REPO_URL}
      - BLUEPRINT_BRANCH=${BLUEPRINT_BRANCH:-main}
      - BLUEPRINT_PULL_INTERVAL=${BLUEPRINT_PULL_INTERVAL:-60}
      - BLUEPRINT_SSH_KEY_PATH=${BLUEPRINT_SSH_KEY_PATH:-/data/ssh-keys/blueprint_rsa}
      - BLUEPRINT_PAT_TOKEN=${BLUEPRINT_PAT_TOKEN}
      - TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}
      - TELEGRAM_CHAT_ID=${TELEGRAM_CHAT_ID}
      - USVAM_TAILSCALE_ADDR=${USVAM_TAILSCALE_ADDR}
      - USVAM_SSH_USER=${USVAM_SSH_USER:-ubuntu}
      - USVAM_SSH_KEY_PATH=${USVAM_SSH_KEY_PATH:-/data/ssh-keys/usvam_rsa}
      - AGENT_POLL_INTERVAL=${AGENT_POLL_INTERVAL:-10}
    healthcheck:
      test: ["CMD", "node", "-e", "require('http').get('http://localhost:3001/health', r => process.exit(r.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 15s

  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
      args:
        - NEXT_PUBLIC_BACKEND_URL=${NEXT_PUBLIC_BACKEND_URL:-http://localhost:3001}
    container_name: gateforge-portal-frontend
    restart: unless-stopped
    network_mode: host
    # On macOS: remove network_mode: host, uncomment below:
    # networks:
    #   - gateforge-portal
    # ports:
    #   - "${FRONTEND_PORT:-3000}:3000"
    env_file:
      - .env
    environment:
      - NODE_ENV=${NODE_ENV:-production}
      - BACKEND_INTERNAL_URL=http://localhost:3001
      - NEXT_PUBLIC_BACKEND_URL=${NEXT_PUBLIC_BACKEND_URL:-http://localhost:3001}
    depends_on:
      backend:
        condition: service_healthy

# networks:
#   gateforge-portal:
#     driver: bridge

volumes:
  blueprint-clone:
  ssh-keys:
  config:
```

### 2.7 `.env.example`

```bash
# GateForge Admin Portal — Environment Variables
# Copy to .env and fill in all required values.
# NEVER commit .env to Git.

# ─── Admin Credentials ────────────────────────────────────────────────────────
ADMIN_USERNAME=admin
# bcrypt hash of your password (generate: node -e "const b=require('bcryptjs'); b.hash('yourpass',10).then(console.log)")
ADMIN_PASSWORD_HASH=
# Plain fallback — DEV ONLY. Leave empty in production.
ADMIN_PASSWORD=

# ─── JWT ──────────────────────────────────────────────────────────────────────
# Min 32 hex chars (generate: openssl rand -hex 32)
JWT_SECRET=
JWT_EXPIRES_IN=24h

# ─── Ports ────────────────────────────────────────────────────────────────────
BACKEND_PORT=3001
FRONTEND_PORT=3000
FRONTEND_URL=http://localhost:3000
# Browser-accessible backend URL (must be reachable from browser)
NEXT_PUBLIC_BACKEND_URL=http://localhost:3001

# ─── Environment ──────────────────────────────────────────────────────────────
NODE_ENV=production

# ─── GateForge VMs ────────────────────────────────────────────────────────────
# JSON array — see schema below. Store as a single-line JSON string.
# Schema: [{ id, role, ip, port, model, hookToken, agentSecret, agents[], isHub? }]
GATEFORGE_VMS=[{"id":"vm-1","role":"System Architect","ip":"192.168.72.10","port":18789,"model":"claude-opus-4.6","hookToken":"","agentSecret":"","agents":["architect"],"isHub":true},{"id":"vm-2","role":"System Designer","ip":"192.168.72.11","port":18789,"model":"claude-sonnet-4.6","hookToken":"","agentSecret":"","agents":["designer"]},{"id":"vm-3","role":"Developers","ip":"192.168.72.12","port":18789,"model":"claude-sonnet-4.6","hookToken":"","agentSecret":"","agents":["dev-01","dev-02"]},{"id":"vm-4","role":"QC Agents","ip":"192.168.72.13","port":18789,"model":"minimax-2.7","hookToken":"","agentSecret":"","agents":["qc-01","qc-02"]},{"id":"vm-5","role":"Operator","ip":"192.168.72.14","port":18789,"model":"minimax-2.7","hookToken":"","agentSecret":"","agents":["operator"]}]

# ─── Blueprint Git Repository ─────────────────────────────────────────────────
# SSH URL example: git@github.com:tonylnng/blueprint.git
# HTTPS URL example: https://github.com/tonylnng/blueprint.git
BLUEPRINT_REPO_URL=
BLUEPRINT_BRANCH=main
# Auto-pull interval in seconds (30 / 60 / 300 / 0 for manual only)
BLUEPRINT_PULL_INTERVAL=60
# Path to SSH private key for Git authentication
BLUEPRINT_SSH_KEY_PATH=/data/ssh-keys/blueprint_rsa
# Alternative: Personal Access Token (used if SSH key not present)
BLUEPRINT_PAT_TOKEN=

# ─── Telegram ─────────────────────────────────────────────────────────────────
# Read-only monitoring of Tony ↔ Architect messages
TELEGRAM_BOT_TOKEN=
TELEGRAM_CHAT_ID=

# ─── US VM (Deployment Target) ────────────────────────────────────────────────
# Tailscale address: 100.x.x.x or hostname.tailscale.net
USVAM_TAILSCALE_ADDR=
USVAM_SSH_USER=ubuntu
USVAM_SSH_KEY_PATH=/data/ssh-keys/usvam_rsa
# Health check endpoints per environment
USVAM_DEV_HEALTH_URL=http://localhost:8080/health
USVAM_UAT_HEALTH_URL=http://localhost:8081/health
USVAM_PROD_HEALTH_URL=http://localhost:8082/health

# ─── Polling ──────────────────────────────────────────────────────────────────
# Agent state poll interval in seconds (5 / 10 / 30 / 60)
AGENT_POLL_INTERVAL=10
```

### 2.8 `install.sh`

```bash
#!/usr/bin/env bash
# GateForge Admin Portal — One-Command Installer
# Usage: bash install.sh

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BOLD}${CYAN}"
echo "  ╔═══════════════════════════════════════╗"
echo "  ║   GateForge Admin Portal Installer    ║"
echo "  ╚═══════════════════════════════════════╝"
echo -e "${NC}"

prompt()        { local v="$1" m="$2" d="$3"; read -rp "$(echo -e "${CYAN}${m}${NC} [${d}]: ")" val; eval "$v=\"${val:-$d}\""; }
prompt_secret() { local v="$1" m="$2"; read -rsp "$(echo -e "${CYAN}${m}${NC}: ")" val; echo; eval "$v=\"$val\""; }
prompt_opt()    { local v="$1" m="$2"; read -rp "$(echo -e "${CYAN}${m}${NC} (Enter to skip): ")" val; eval "$v=\"$val\""; }
info()          { echo -e "${GREEN}✓${NC} $1"; }
warn()          { echo -e "${YELLOW}⚠${NC}  $1"; }
section()       { echo -e "\n${BOLD}── $1 ──${NC}"; }
gen_secret()    { openssl rand -hex 32 2>/dev/null || echo "change-me-$(date +%s)-$(head -c 16 /dev/urandom | od -A n -t x1 | tr -d ' \n')"; }

check_command() {
  if ! command -v "$1" &>/dev/null; then
    echo -e "${RED}✗ Required command not found: $1${NC}"
    exit 1
  fi
  info "$1 found"
}

section "Preflight checks"
check_command docker
check_command git
check_command node

section "Admin credentials"
prompt ADMIN_USERNAME "Admin username" "admin"
while true; do
  prompt_secret ADMIN_PASSWORD "Admin password (min 12 chars)"
  prompt_secret ADMIN_PASSWORD2 "Confirm password"
  [[ "$ADMIN_PASSWORD" == "$ADMIN_PASSWORD2" ]] && break
  warn "Passwords don't match. Try again."
done
ADMIN_PASSWORD_HASH=$(node -e "const b=require('bcryptjs'); b.hash(process.argv[1],10).then(h=>console.log(h))" "$ADMIN_PASSWORD" 2>/dev/null || echo "")
[[ -z "$ADMIN_PASSWORD_HASH" ]] && warn "Could not hash password — storing plain (dev only)"

section "JWT configuration"
JWT_SECRET=$(gen_secret)
info "JWT secret generated"
prompt JWT_EXPIRES_IN "JWT expiry" "24h"

section "Network ports"
prompt FRONTEND_PORT "Frontend port" "3000"
prompt BACKEND_PORT "Backend port" "3001"
prompt PUBLIC_URL "Public backend URL (browser-accessible)" "http://localhost:${BACKEND_PORT}"

section "VM configuration (enter credentials for each VM)"
declare -a VM_CONFIGS=()
VM_ROLES=("System Architect" "System Designer" "Developers" "QC Agents" "Operator")
VM_IPS=("192.168.72.10" "192.168.72.11" "192.168.72.12" "192.168.72.13" "192.168.72.14")
VM_MODELS=("claude-opus-4.6" "claude-sonnet-4.6" "claude-sonnet-4.6" "minimax-2.7" "minimax-2.7")
VM_AGENTS=('["architect"]' '["designer"]' '["dev-01","dev-02"]' '["qc-01","qc-02"]' '["operator"]')

for i in 1 2 3 4 5; do
  idx=$((i - 1))
  echo -e "\n  ${BOLD}VM-${i}: ${VM_ROLES[$idx]}${NC}"
  prompt "VM${i}_IP" "  IP address" "${VM_IPS[$idx]}"
  prompt "VM${i}_PORT" "  Gateway port" "18789"
  prompt_secret "VM${i}_HOOK_TOKEN" "  Hook token"
  prompt_secret "VM${i}_AGENT_SECRET" "  Agent secret"
done

# Build GATEFORGE_VMS JSON
GATEFORGE_VMS="["
for i in 1 2 3 4 5; do
  idx=$((i - 1))
  HUB_FLAG=""
  [[ $i -eq 1 ]] && HUB_FLAG=',"isHub":true'
  eval "IP=\$VM${i}_IP; PORT=\$VM${i}_PORT; HT=\$VM${i}_HOOK_TOKEN; AS=\$VM${i}_AGENT_SECRET"
  GATEFORGE_VMS+="{\"id\":\"vm-${i}\",\"role\":\"${VM_ROLES[$idx]}\",\"ip\":\"${IP}\",\"port\":${PORT},\"model\":\"${VM_MODELS[$idx]}\",\"hookToken\":\"${HT}\",\"agentSecret\":\"${AS}\",\"agents\":${VM_AGENTS[$idx]}${HUB_FLAG}}"
  [[ $i -lt 5 ]] && GATEFORGE_VMS+=","
done
GATEFORGE_VMS+="]"

section "Optional integrations"
prompt_opt BLUEPRINT_REPO_URL "Blueprint Git repo URL"
prompt_opt TELEGRAM_BOT_TOKEN "Telegram bot token"
prompt_opt USVAM_TAILSCALE_ADDR "US VM Tailscale address"

section "Generating .env"
cat > .env << ENVEOF
# GateForge Admin Portal Configuration
# Generated by install.sh on $(date)

ADMIN_USERNAME=${ADMIN_USERNAME}
ADMIN_PASSWORD=${ADMIN_PASSWORD}
ADMIN_PASSWORD_HASH=${ADMIN_PASSWORD_HASH}

JWT_SECRET=${JWT_SECRET}
JWT_EXPIRES_IN=${JWT_EXPIRES_IN}

BACKEND_PORT=${BACKEND_PORT}
FRONTEND_PORT=${FRONTEND_PORT}
FRONTEND_URL=http://localhost:${FRONTEND_PORT}
NEXT_PUBLIC_BACKEND_URL=${PUBLIC_URL}
NODE_ENV=production

GATEFORGE_VMS=${GATEFORGE_VMS}

BLUEPRINT_REPO_URL=${BLUEPRINT_REPO_URL}
BLUEPRINT_BRANCH=main
BLUEPRINT_PULL_INTERVAL=60
BLUEPRINT_SSH_KEY_PATH=/data/ssh-keys/blueprint_rsa

TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}
TELEGRAM_CHAT_ID=

USVAM_TAILSCALE_ADDR=${USVAM_TAILSCALE_ADDR}
USVAM_SSH_USER=ubuntu
USVAM_SSH_KEY_PATH=/data/ssh-keys/usvam_rsa

AGENT_POLL_INTERVAL=10
ENVEOF
info ".env generated"

section "Build and launch"
prompt LAUNCH "Build and start the portal now? (y/n)" "y"
if [[ "$LAUNCH" =~ ^[Yy] ]]; then
  docker compose up -d --build
  echo ""
  info "GateForge Admin Portal is running!"
  echo -e "   Frontend: ${CYAN}http://localhost:${FRONTEND_PORT}${NC}"
  echo -e "   Login:    ${ADMIN_USERNAME} / (your password)"
else
  info "Run manually: docker compose up -d --build"
fi

echo ""
warn ".env contains secrets — never commit it to Git."
echo -e "${BOLD}Done!${NC}"
```

### 2.9 Backend `tsconfig.json`

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "lib": ["ES2020"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
```

### 2.10 Frontend `tsconfig.json`

```json
{
  "compilerOptions": {
    "target": "ES2017",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
```

### 2.11 Tailwind Config (`frontend/tailwind.config.ts`)

```typescript
import type { Config } from 'tailwindcss';

const config: Config = {
  darkMode: ['class'],
  content: [
    './src/pages/**/*.{js,ts,jsx,tsx,mdx}',
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
    './src/app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    container: {
      center: true,
      padding: '2rem',
      screens: { '2xl': '1400px' },
    },
    extend: {
      colors: {
        border: 'hsl(var(--border))',
        input: 'hsl(var(--input))',
        ring: 'hsl(var(--ring))',
        background: 'hsl(var(--background))',
        foreground: 'hsl(var(--foreground))',
        primary: {
          DEFAULT: 'hsl(var(--primary))',
          foreground: 'hsl(var(--primary-foreground))',
        },
        secondary: {
          DEFAULT: 'hsl(var(--secondary))',
          foreground: 'hsl(var(--secondary-foreground))',
        },
        destructive: {
          DEFAULT: 'hsl(var(--destructive))',
          foreground: 'hsl(var(--destructive-foreground))',
        },
        muted: {
          DEFAULT: 'hsl(var(--muted))',
          foreground: 'hsl(var(--muted-foreground))',
        },
        accent: {
          DEFAULT: 'hsl(var(--accent))',
          foreground: 'hsl(var(--accent-foreground))',
        },
      },
      borderRadius: {
        lg: 'var(--radius)',
        md: 'calc(var(--radius) - 2px)',
        sm: 'calc(var(--radius) - 4px)',
      },
      keyframes: {
        'accordion-down': {
          from: { height: '0' },
          to: { height: 'var(--radix-accordion-content-height)' },
        },
        'accordion-up': {
          from: { height: 'var(--radix-accordion-content-height)' },
          to: { height: '0' },
        },
        'phase-glow': {
          '0%, 100%': { boxShadow: '0 0 8px 2px rgba(99,102,241,0.4)' },
          '50%': { boxShadow: '0 0 20px 6px rgba(99,102,241,0.8)' },
        },
        'slow-blink': {
          '0%, 100%': { opacity: '1' },
          '50%': { opacity: '0.3' },
        },
        'fast-blink': {
          '0%, 100%': { opacity: '1' },
          '50%': { opacity: '0.2' },
        },
      },
      animation: {
        'accordion-down': 'accordion-down 0.2s ease-out',
        'accordion-up': 'accordion-up 0.2s ease-out',
        'phase-glow': 'phase-glow 2s ease-in-out infinite',
        'slow-blink': 'slow-blink 1s ease-in-out infinite',
        'fast-blink': 'fast-blink 0.5s ease-in-out infinite',
      },
    },
  },
  plugins: [require('tailwindcss-animate')],
};

export default config;
```

### 2.12 shadcn/ui Setup

Run once after `npm install` to initialize shadcn/ui:

```bash
npx shadcn-ui@latest init
# Choose: TypeScript, App Router, Tailwind, src/ directory, @/* aliases
```

Install required shadcn components:

```bash
npx shadcn-ui@latest add badge button card dialog dropdown-menu \
  input label progress scroll-area select separator sheet \
  switch tabs toast tooltip
```

### 2.13 ESLint + Prettier Config

**`.eslintrc.json`** (frontend):
```json
{
  "extends": ["next/core-web-vitals", "plugin:@typescript-eslint/recommended"],
  "rules": {
    "@typescript-eslint/no-explicit-any": "error",
    "@typescript-eslint/no-unused-vars": ["error", { "argsIgnorePattern": "^_" }],
    "no-console": ["warn", { "allow": ["warn", "error"] }]
  }
}
```

**`.prettierrc`** (both):
```json
{
  "semi": true,
  "singleQuote": true,
  "tabWidth": 2,
  "trailingComma": "es5",
  "printWidth": 100
}
```

---

## 3. Type Definitions & Data Models

All types live in `backend/src/types/index.ts` (backend) and `frontend/src/types/index.ts` (frontend — identical file, shared). Keep these two files in sync.

```typescript
// ─── VM & Agent ───────────────────────────────────────────────────────────────

export type AgentStatus = 'active' | 'idle' | 'blocked' | 'error' | 'offline';

export interface VMConfig {
  id: string;             // 'vm-1' through 'vm-5'
  role: string;           // 'System Architect', 'System Designer', etc.
  ip: string;             // '192.168.72.10'
  port: number;           // 18789
  model: string;          // 'claude-opus-4.6'
  hookToken: string;      // X-Hook-Token header value
  agentSecret: string;    // X-Agent-Secret header value
  agents: string[];       // ['architect'] | ['dev-01', 'dev-02', ...]
  isHub?: boolean;        // true only for VM-1
}

export interface VM {
  id: string;
  role: string;
  ip: string;
  port: number;
  model: string;
  isHub: boolean;
  agents: Agent[];
  gatewayStatus: 'ok' | 'slow' | 'error' | 'unknown';
  gatewayLatencyMs?: number;
  lastProbed: string;     // ISO 8601
}

export interface Agent {
  vmId: string;           // 'vm-1'
  agentId: string;        // 'architect', 'dev-01'
  displayId: string;      // 'architect@VM-1', 'dev-01@VM-3'
  role: string;
  model: string;
  status: AgentStatus;
  currentTaskId?: string;
  currentTaskTitle?: string;
  latestOutputSnippet?: string;  // Last 280 chars of latest AI response
  lastActivityAt: string;        // ISO 8601
  activeNotificationPriority?: NotificationPriority;
  isHub: boolean;
}

export interface AgentDetail extends Agent {
  tools: AgentTool[];
  metrics: AgentMetrics;
}

export interface AgentTool {
  name: string;
  description: string;
  enabled: boolean;
}

export interface AgentMetrics {
  avgResponseTimeMs: { h24: number; d7: number; d30: number };
  totalTokensIn: number;
  totalTokensOut: number;
  tokensPerHour: TimeSeriesPoint[];
  errorRate: number;           // 0.0 – 1.0
  gatewayUptimePct: number;   // 0.0 – 100.0
}

export interface TimeSeriesPoint {
  timestamp: string;
  value: number;
}

// ─── Notifications ─────────────────────────────────────────────────────────────

export type NotificationPriority = 'CRITICAL' | 'BLOCKED' | 'DISPUTE' | 'COMPLETED' | 'INFO';

export interface Notification {
  id: string;
  priority: NotificationPriority;
  vmId: string;
  agentId: string;
  message: string;
  taskId?: string;
  gitRef?: string;
  phase?: PipelinePhaseName;
  timestamp: string;      // ISO 8601
  metadata?: Record<string, unknown>;
  acknowledged: boolean;
}

export interface NotificationStats {
  total24h: number;
  total7d: number;
  total30d: number;
  byPriority: Record<NotificationPriority, number>;
  byVm: Record<string, number>;
  hourlyHeatmap: number[];   // 24 values, one per hour of day
}

// ─── Tasks ────────────────────────────────────────────────────────────────────

export type TaskStatus = 'backlog' | 'ready' | 'in-progress' | 'in-review' | 'done' | 'blocked';
export type TaskPriority = 'P0' | 'P1' | 'P2' | 'P3';
export type MoSCoW = 'Must' | 'Should' | 'Could' | "Won't";

export interface Task {
  id: string;               // 'TASK-PORTAL-001', 'FEAT-042', 'BUG-007'
  title: string;
  status: TaskStatus;
  priority: TaskPriority;
  moscow: MoSCoW;
  assignedVmId?: string;
  assignedAgentId?: string;
  phase?: PipelinePhaseName;
  module?: string;
  startedAt?: string;
  completedAt?: string;
  blockedReason?: string;
  blueprintRef?: string;
  dependencies: string[];   // Task IDs
  storyPoints?: number;
}

// ─── Pipeline ────────────────────────────────────────────────────────────────

export type PipelinePhaseName =
  | 'Requirements'
  | 'Architecture'
  | 'Development'
  | 'QA'
  | 'Deployment'
  | 'Iteration';

export type PhaseStatus = 'not-started' | 'in-progress' | 'completed' | 'blocked';

export interface PipelinePhase {
  id: number;               // 1–6
  name: PipelinePhaseName;
  status: PhaseStatus;
  taskCounts: {
    passed: number;
    working: number;
    pending: number;
    blocked: number;
    total: number;
  };
  qualityGates: QualityGate[];
  tasks: Task[];
  startedAt?: string;
  completedAt?: string;
}

export interface PipelineIteration {
  id: string;               // 'iter-001', 'iter-002'
  label: string;            // 'Iteration 3'
  phases: PipelinePhase[];
  currentPhaseId: number;
  startedAt: string;
  completedAt?: string;
  activeLobsterWorkflow?: LobsterWorkflow;
}

export interface LobsterWorkflow {
  name: string;
  currentStep: number;
  totalSteps: number;
  currentAction: string;
  assignedAgent: string;
  retryCount: number;
  maxRetries: number;
  resumeToken: string;
  onFailBranch?: string;
}

// ─── Quality Gates ───────────────────────────────────────────────────────────

export type GateDecision = 'PROMOTE' | 'HOLD' | 'ROLLBACK';
export type GateType = 'design' | 'code' | 'qa' | 'release';

export interface QualityGate {
  id: string;
  type: GateType;
  module: string;
  decision?: GateDecision;
  decidedAt?: string;
  criteria: GateCriterion[];
}

export interface GateCriterion {
  label: string;
  threshold?: number;       // e.g. 95 (percent)
  actual?: number;
  passed: boolean;
}

// ─── Blueprint ───────────────────────────────────────────────────────────────

export type DocumentStatus = 'draft' | 'in-review' | 'approved' | 'deprecated';

export interface BlueprintFile {
  path: string;             // 'architecture/database-design.md'
  name: string;             // 'database-design.md'
  type: 'file' | 'directory';
  status?: DocumentStatus;  // Parsed from YAML frontmatter
  children?: BlueprintFile[];
  size?: number;
  lastModified?: string;
}

export interface BlueprintCommit {
  sha: string;
  shortSha: string;         // First 7 chars
  message: string;
  author: string;
  authorEmail: string;
  timestamp: string;
  filesChanged: string[];
}

export interface Blueprint {
  tree: BlueprintFile[];
  recentCommits: BlueprintCommit[];
  lastPulledAt: string;
  branch: string;
  remoteUrl: string;
}

// ─── Project Health ──────────────────────────────────────────────────────────

export type HealthStatus = 'green' | 'yellow' | 'red';

export interface HealthDimension {
  name: 'Phase' | 'Status' | 'Schedule' | 'Budget' | 'Quality' | 'Team';
  status: HealthStatus;
  summary: string;
  detail?: string;
}

export interface ProjectHealth {
  overall: HealthStatus;
  dimensions: HealthDimension[];
  lastUpdatedAt: string;
  currentIteration: string;
  blockedTaskCount: number;
}

export interface BurndownDataPoint {
  date: string;             // 'YYYY-MM-DD'
  ideal: number;
  actual: number;
  scope?: number;
}

// ─── QA Metrics ──────────────────────────────────────────────────────────────

export interface CoverageMetric {
  module: string;
  unit: number;             // Percent 0–100
  integration: number;
  e2e: number;
  unitThreshold: number;    // 95
  integrationThreshold: number; // 90
  e2eThreshold: number;     // 85
}

export type DefectSeverity = 'Critical' | 'Major' | 'Minor' | 'Cosmetic';

export interface Defect {
  id: string;               // 'DEF-008'
  title: string;
  severity: DefectSeverity;
  module: string;
  status: 'open' | 'in-review' | 'resolved' | 'closed' | 'not-a-bug';
  reportedAt: string;
  resolvedAt?: string;
  taskId?: string;
  escapeStage?: 'Dev/QA' | 'UAT' | 'Production';
}

export interface QASnapshot {
  coverage: CoverageMetric[];
  gates: QualityGate[];
  openDefects: Defect[];
  defectTrend: TimeSeriesPoint[];
  automationPct: number;
  p95LatencyMs?: number;
  owaspCoverage: OwaspItem[];
}

export interface OwaspItem {
  id: string;               // 'A01:2021'
  name: string;
  covered: boolean;
  notes?: string;
}

// ─── Operations ──────────────────────────────────────────────────────────────

export type DeploymentEnvironment = 'dev' | 'uat' | 'production';
export type DeploymentStatus = 'healthy' | 'degraded' | 'down' | 'deploying' | 'unknown';

export interface Deployment {
  id: string;
  environment: DeploymentEnvironment;
  version: string;
  status: DeploymentStatus;
  deployedAt: string;
  deployedBy: string;       // 'operator@VM-5'
  commitSha: string;
  healthUrl?: string;
  latencyMs?: number;
}

export type SLOBudgetStatus = 'healthy' | 'warning' | 'critical' | 'exhausted';

export interface SLO {
  id: string;               // 'availability', 'latency-p95', 'error-rate'
  name: string;
  target: number;           // e.g. 99.9 (percent) or 200 (ms)
  current: number;
  unit: '%' | 'ms' | 'req/s';
  errorBudgetPct: number;   // 0–100
  budgetStatus: SLOBudgetStatus;
  burnRate1h: number;
  burnRate6h: number;
  burnRate24h: number;
  burnRate72h: number;
}

export interface Incident {
  id: string;               // 'INC-001'
  severity: DefectSeverity;
  title: string;
  startedAt: string;
  resolvedAt?: string;
  status: 'open' | 'resolved';
  mttrMinutes?: number;
  markdownReport?: string;
}

// ─── Setup & Configuration ────────────────────────────────────────────────────

export interface SetupConfig {
  adminUsername: string;
  jwtExpiresIn: '1h' | '8h' | '24h' | '7d';
  vms: VMConfig[];
  blueprintRepoUrl: string;
  blueprintBranch: string;
  blueprintPullInterval: number;
  blueprintAuthMethod: 'ssh' | 'pat';
  telegramBotToken?: string;
  telegramChatId?: string;
  usvmTailscaleAddr?: string;
  usvmSshUser?: string;
  usvmEnvironments: DeploymentEnvironment[];
  agentPollInterval: number;
}

export interface SetupHealthResult {
  component: string;
  status: 'ok' | 'warning' | 'error' | 'unknown';
  detail?: string;
  latencyMs?: number;
  checkedAt: string;
}

// ─── SSE Event Payloads ───────────────────────────────────────────────────────

export interface SSEEventBase {
  type: string;
  timestamp: string;
}

export interface AgentStatusEvent extends SSEEventBase {
  type: 'agent.status';
  vmId: string;
  agentId: string;
  status: AgentStatus;
  lastActivity: string;
}

export interface AgentOutputEvent extends SSEEventBase {
  type: 'agent.output';
  vmId: string;
  agentId: string;
  snippet: string;
}

export interface NotificationNewEvent extends SSEEventBase {
  type: 'notification.new';
  notification: Notification;
}

export interface PipelineUpdateEvent extends SSEEventBase {
  type: 'pipeline.update';
  iterationId: string;
  phaseId: number;
  phaseStatus: PhaseStatus;
  taskCounts: PipelinePhase['taskCounts'];
}

export interface QAGateUpdateEvent extends SSEEventBase {
  type: 'qa.gateUpdate';
  module: string;
  gate: GateType;
  decision: GateDecision;
}

export interface OpsDeployUpdateEvent extends SSEEventBase {
  type: 'ops.deployUpdate';
  environment: DeploymentEnvironment;
  status: DeploymentStatus;
  version: string;
}

export interface OpsSLOAlertEvent extends SSEEventBase {
  type: 'ops.sloAlert';
  sloId: string;
  burnRate: number;
  budgetRemaining: number;
  alertLevel: SLOBudgetStatus;
}

export interface BlueprintCommitEvent extends SSEEventBase {
  type: 'blueprint.commit';
  sha: string;
  message: string;
  author: string;
  files: string[];
}

export interface SystemHealthEvent extends SSEEventBase {
  type: 'system.health';
  vmId: string;
  status: 'ok' | 'slow' | 'error';
  latencyMs: number;
}

export type SSEEvent =
  | AgentStatusEvent
  | AgentOutputEvent
  | NotificationNewEvent
  | PipelineUpdateEvent
  | QAGateUpdateEvent
  | OpsDeployUpdateEvent
  | OpsSLOAlertEvent
  | BlueprintCommitEvent
  | SystemHealthEvent;

// ─── API Response Wrappers ───────────────────────────────────────────────────

export interface ApiSuccess<T> {
  ok: true;
  data: T;
}

export interface ApiError {
  ok: false;
  error: string;
  code?: string;
}

export type ApiResponse<T> = ApiSuccess<T> | ApiError;

export interface PaginatedResponse<T> {
  ok: true;
  data: T[];
  total: number;
  page: number;
  pageSize: number;
  hasMore: boolean;
}

export interface FilterParams {
  status?: TaskStatus;
  priority?: TaskPriority;
  vmId?: string;
  agentId?: string;
  module?: string;
  phase?: PipelinePhaseName;
  page?: number;
  pageSize?: number;
}
```

---

## 4. Backend Implementation

### 4.1 Express App Setup (`backend/src/index.ts`)

```typescript
import express from 'express';
import cookieParser from 'cookie-parser';
import cors from 'cors';
import helmet from 'helmet';
import dotenv from 'dotenv';

import { loadConfig } from './config';
import authRouter from './routes/auth';
import agentsRouter from './routes/agents';
import pipelineRouter from './routes/pipeline';
import blueprintRouter from './routes/blueprint';
import projectRouter from './routes/project';
import qaRouter from './routes/qa';
import operationsRouter from './routes/operations';
import notificationsRouter from './routes/notifications';
import setupRouter from './routes/setup';
import eventsRouter from './routes/events';
import { startPoller } from './services/poller';
import { initBlueprintGit } from './services/blueprintGit';

dotenv.config();

const cfg = loadConfig();
const app = express();
const PORT = cfg.backendPort;

// ─── Security headers ─────────────────────────────────────────────────────────
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", 'data:'],
      connectSrc: ["'self'"],
    },
  },
}));

// ─── CORS ────────────────────────────────────────────────────────────────────
const allowedOrigins = [
  cfg.frontendUrl,
  'http://localhost:3000',
  'http://127.0.0.1:3000',
];
app.use(cors({
  origin: (origin, callback) => {
    if (!origin || allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error(`CORS: origin ${origin} not allowed`));
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

// ─── Body + cookie parsing ─────────────────────────────────────────────────
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(cookieParser());

// ─── Routes ───────────────────────────────────────────────────────────────
app.use('/api/auth', authRouter);
app.use('/api/agents', agentsRouter);
app.use('/api/pipeline', pipelineRouter);
app.use('/api/blueprint', blueprintRouter);
app.use('/api/project', projectRouter);
app.use('/api/qa', qaRouter);
app.use('/api/ops', operationsRouter);
app.use('/api/notifications', notificationsRouter);
app.use('/api/setup', setupRouter);
app.use('/api/events', eventsRouter);  // SSE — must be LAST (no body middleware)

// ─── Health ───────────────────────────────────────────────────────────────
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString(), version: '1.0.0' });
});

// ─── 404 / Error ─────────────────────────────────────────────────────────
app.use((_req, res) => res.status(404).json({ ok: false, error: 'Not found' }));
app.use((err: Error, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error('[error]', err.message);
  res.status(500).json({ ok: false, error: 'Internal server error' });
});

// ─── Startup ─────────────────────────────────────────────────────────────
app.listen(PORT, '0.0.0.0', async () => {
  console.log(`[portal-backend] Listening on :${PORT}`);

  // Initialize Blueprint Git clone
  if (cfg.blueprintRepoUrl) {
    await initBlueprintGit().catch(e => console.warn('[blueprint]', e.message));
  }

  // Start background poller
  startPoller();
  console.log(`[poller] Agent polling every ${cfg.agentPollInterval}s`);
});

export default app;
```

**`backend/src/config.ts`:**

```typescript
import { VMConfig } from './types';

export interface AppConfig {
  backendPort: number;
  frontendUrl: string;
  adminUsername: string;
  adminPasswordHash: string;
  adminPasswordPlain: string;
  jwtSecret: string;
  jwtExpiresIn: string;
  vms: VMConfig[];
  blueprintRepoUrl: string;
  blueprintBranch: string;
  blueprintPullInterval: number;
  blueprintSshKeyPath: string;
  blueprintPatToken: string;
  blueprintClonePath: string;
  telegramBotToken: string;
  telegramChatId: string;
  usvmTailscaleAddr: string;
  usvmSshUser: string;
  usvmSshKeyPath: string;
  agentPollInterval: number;
}

let _cfg: AppConfig | null = null;

export function loadConfig(): AppConfig {
  if (_cfg) return _cfg;

  let vms: VMConfig[] = [];
  try {
    vms = JSON.parse(process.env.GATEFORGE_VMS || '[]');
  } catch (e) {
    console.warn('[config] GATEFORGE_VMS parse error — using empty array');
  }

  _cfg = {
    backendPort: parseInt(process.env.BACKEND_PORT || '3001', 10),
    frontendUrl: process.env.FRONTEND_URL || 'http://localhost:3000',
    adminUsername: process.env.ADMIN_USERNAME || 'admin',
    adminPasswordHash: process.env.ADMIN_PASSWORD_HASH || '',
    adminPasswordPlain: process.env.ADMIN_PASSWORD || '',
    jwtSecret: process.env.JWT_SECRET || 'dev-secret-change-me-32-chars!!!',
    jwtExpiresIn: process.env.JWT_EXPIRES_IN || '24h',
    vms,
    blueprintRepoUrl: process.env.BLUEPRINT_REPO_URL || '',
    blueprintBranch: process.env.BLUEPRINT_BRANCH || 'main',
    blueprintPullInterval: parseInt(process.env.BLUEPRINT_PULL_INTERVAL || '60', 10),
    blueprintSshKeyPath: process.env.BLUEPRINT_SSH_KEY_PATH || '/data/ssh-keys/blueprint_rsa',
    blueprintPatToken: process.env.BLUEPRINT_PAT_TOKEN || '',
    blueprintClonePath: process.env.BLUEPRINT_CLONE_PATH || '/data/blueprint-clone',
    telegramBotToken: process.env.TELEGRAM_BOT_TOKEN || '',
    telegramChatId: process.env.TELEGRAM_CHAT_ID || '',
    usvmTailscaleAddr: process.env.USVAM_TAILSCALE_ADDR || '',
    usvmSshUser: process.env.USVAM_SSH_USER || 'ubuntu',
    usvmSshKeyPath: process.env.USVAM_SSH_KEY_PATH || '/data/ssh-keys/usvam_rsa',
    agentPollInterval: parseInt(process.env.AGENT_POLL_INTERVAL || '10', 10),
  };

  return _cfg;
}
```

### 4.2 Authentication Module

**`backend/src/middleware/auth.ts`** — identical to ClawDeck pattern:

```typescript
import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { loadConfig } from '../config';

export interface AuthPayload {
  username: string;
  iat: number;
  exp: number;
}

export function requireAuth(req: Request, res: Response, next: NextFunction): void {
  const token = req.cookies?.auth_token || extractBearerToken(req) || extractQueryToken(req);
  if (!token) {
    res.status(401).json({ ok: false, error: 'Unauthorized' });
    return;
  }
  try {
    const { jwtSecret } = loadConfig();
    const payload = jwt.verify(token, jwtSecret) as AuthPayload;
    (req as Request & { user: AuthPayload }).user = payload;
    next();
  } catch {
    res.status(401).json({ ok: false, error: 'Invalid or expired token' });
  }
}

function extractBearerToken(req: Request): string | null {
  const h = req.headers.authorization;
  return h?.startsWith('Bearer ') ? h.slice(7) : null;
}

// SSE clients pass token as query param ?token= because EventSource cannot set headers
function extractQueryToken(req: Request): string | null {
  return (req.query.token as string) || null;
}
```

**`backend/src/middleware/rateLimiter.ts`:**

```typescript
import rateLimit from 'express-rate-limit';

export const loginRateLimiter = rateLimit({
  windowMs: 60 * 1000,    // 1 minute
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  message: { ok: false, error: 'Too many login attempts. Try again in 1 minute.' },
  skipSuccessfulRequests: true,
});
```

**`backend/src/routes/auth.ts`** — adapted from ClawDeck:

```typescript
import { Router, Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { requireAuth, AuthPayload } from '../middleware/auth';
import { loginRateLimiter } from '../middleware/rateLimiter';
import { loadConfig } from '../config';

const router = Router();

router.post('/login', loginRateLimiter, async (req: Request, res: Response) => {
  const { username, password } = req.body as { username?: string; password?: string };
  if (!username || !password) {
    res.status(400).json({ ok: false, error: 'Username and password required' });
    return;
  }

  const cfg = loadConfig();
  if (username !== cfg.adminUsername) {
    res.status(401).json({ ok: false, error: 'Invalid credentials' });
    return;
  }

  let valid = false;
  if (cfg.adminPasswordHash) {
    valid = await bcrypt.compare(password, cfg.adminPasswordHash);
  } else if (cfg.adminPasswordPlain) {
    valid = password === cfg.adminPasswordPlain;
  }

  if (!valid) {
    res.status(401).json({ ok: false, error: 'Invalid credentials' });
    return;
  }

  const token = jwt.sign({ username }, cfg.jwtSecret, { expiresIn: cfg.jwtExpiresIn } as jwt.SignOptions);
  const isHttps = req.secure || req.headers['x-forwarded-proto'] === 'https';

  res.cookie('auth_token', token, {
    httpOnly: true,
    secure: isHttps,
    sameSite: isHttps ? 'strict' : 'lax',
    maxAge: 24 * 60 * 60 * 1000,
    path: '/',
  });

  res.json({ ok: true, username });
});

router.post('/logout', (_req, res: Response) => {
  res.clearCookie('auth_token', { path: '/' });
  res.json({ ok: true });
});

router.get('/me', requireAuth, (req: Request, res: Response) => {
  const user = (req as Request & { user: AuthPayload }).user;
  res.json({ ok: true, data: { username: user.username } });
});

export default router;
```

### 4.3 Gateway Client Service (`backend/src/services/gatewayClient.ts`)

```typescript
import fetch from 'node-fetch';
import { VMConfig } from '../types';

const GATEWAY_TIMEOUT_MS = 5000;

// READ-ONLY ENFORCEMENT: This client only issues GET requests.
// Adding any POST/PUT/DELETE method here is a design violation.

async function gatewayGet<T>(
  vm: VMConfig,
  path: string
): Promise<T> {
  const url = `http://${vm.ip}:${vm.port}${path}`;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), GATEWAY_TIMEOUT_MS);

  try {
    const res = await fetch(url, {
      method: 'GET',
      headers: {
        'X-Hook-Token': vm.hookToken,
        'X-Agent-Secret': vm.agentSecret,
        'Accept': 'application/json',
      },
      signal: controller.signal,
    });

    if (!res.ok) {
      throw new Error(`Gateway ${vm.id} returned ${res.status} for ${path}`);
    }

    return res.json() as Promise<T>;
  } finally {
    clearTimeout(timeout);
  }
}

export async function fetchVMHealth(vm: VMConfig): Promise<{ status: string; version?: string }> {
  return gatewayGet(vm, '/health');
}

export async function fetchAgentList(vm: VMConfig): Promise<unknown[]> {
  return gatewayGet(vm, '/v1/agents');
}

export async function fetchAgentStatus(vm: VMConfig, agentId: string): Promise<unknown> {
  return gatewayGet(vm, `/v1/agents/${agentId}/status`);
}

export async function fetchAgentSessions(vm: VMConfig, agentId: string): Promise<unknown[]> {
  return gatewayGet(vm, `/v1/agents/${agentId}/sessions`);
}

export async function fetchAgentSession(
  vm: VMConfig,
  agentId: string,
  sessionId: string
): Promise<unknown> {
  return gatewayGet(vm, `/v1/agents/${agentId}/sessions/${sessionId}`);
}

export async function fetchAgentTools(vm: VMConfig, agentId: string): Promise<unknown[]> {
  return gatewayGet(vm, `/v1/agents/${agentId}/tools`);
}

export async function fetchVMLogs(vm: VMConfig): Promise<unknown[]> {
  return gatewayGet(vm, '/v1/logs');
}

export async function fetchAgentLogs(vm: VMConfig, agentId: string): Promise<unknown[]> {
  return gatewayGet(vm, `/v1/logs/${agentId}`);
}
```

### 4.4 State Cache & Poller

**`backend/src/services/stateCache.ts`:**

```typescript
import { Agent, VM } from '../types';

// In-memory cache keyed by vmId → Map<agentId, Agent>
const agentCache = new Map<string, Map<string, Agent>>();
// VM-level connection status
const vmCache = new Map<string, Omit<VM, 'agents'>>();

export function cacheAgentState(vmId: string, agentId: string, state: Agent): void {
  if (!agentCache.has(vmId)) agentCache.set(vmId, new Map());
  agentCache.get(vmId)!.set(agentId, state);
}

export function getCachedAgent(vmId: string, agentId: string): Agent | undefined {
  return agentCache.get(vmId)?.get(agentId);
}

export function getAllCachedAgents(): Agent[] {
  const agents: Agent[] = [];
  for (const vmAgents of agentCache.values()) {
    for (const agent of vmAgents.values()) {
      agents.push(agent);
    }
  }
  return agents;
}

export function cacheVMStatus(vmId: string, status: Omit<VM, 'agents'>): void {
  vmCache.set(vmId, status);
}

export function getCachedVM(vmId: string): Omit<VM, 'agents'> | undefined {
  return vmCache.get(vmId);
}

export function getAllCachedVMs(): Array<Omit<VM, 'agents'>> {
  return Array.from(vmCache.values());
}

// Delta detection: returns true if state has meaningfully changed
export function hasAgentChanged(vmId: string, agentId: string, newState: Agent): boolean {
  const old = getCachedAgent(vmId, agentId);
  if (!old) return true;
  return (
    old.status !== newState.status ||
    old.currentTaskId !== newState.currentTaskId ||
    old.latestOutputSnippet !== newState.latestOutputSnippet
  );
}
```

**`backend/src/services/poller.ts`:**

```typescript
import { loadConfig } from '../config';
import { fetchVMHealth, fetchAgentList, fetchAgentStatus } from './gatewayClient';
import { cacheAgentState, cacheVMStatus, hasAgentChanged } from './stateCache';
import { emitEvent } from './notificationBus';
import { Agent, AgentStatus } from '../types';

let pollerTimer: ReturnType<typeof setInterval> | null = null;

export function startPoller(): void {
  const cfg = loadConfig();
  const intervalMs = cfg.agentPollInterval * 1000;

  if (pollerTimer) clearInterval(pollerTimer);

  // Immediate first poll
  pollAll().catch(e => console.warn('[poller] Initial poll error:', e.message));

  pollerTimer = setInterval(() => {
    pollAll().catch(e => console.warn('[poller] Poll error:', e.message));
  }, intervalMs);

  console.log(`[poller] Started. Interval: ${cfg.agentPollInterval}s`);
}

export function stopPoller(): void {
  if (pollerTimer) {
    clearInterval(pollerTimer);
    pollerTimer = null;
  }
}

async function pollAll(): Promise<void> {
  const cfg = loadConfig();
  // Poll all VMs in parallel — one VM failure does not block others
  await Promise.allSettled(cfg.vms.map(vm => pollVM(vm)));
}

async function pollVM(vm: import('../types').VMConfig): Promise<void> {
  const now = new Date().toISOString();

  try {
    const start = Date.now();
    await fetchVMHealth(vm);
    const latencyMs = Date.now() - start;

    const vmStatus = {
      id: vm.id,
      role: vm.role,
      ip: vm.ip,
      port: vm.port,
      model: vm.model,
      isHub: !!vm.isHub,
      gatewayStatus: latencyMs < 50 ? 'ok' as const : latencyMs < 200 ? 'slow' as const : 'ok' as const,
      gatewayLatencyMs: latencyMs,
      lastProbed: now,
    };

    cacheVMStatus(vm.id, vmStatus);

    // Emit system health event
    emitEvent({
      type: 'system.health',
      timestamp: now,
      vmId: vm.id,
      status: vmStatus.gatewayStatus,
      latencyMs,
    });

    // Poll each configured agent on this VM
    await Promise.allSettled(vm.agents.map(agentId => pollAgent(vm, agentId)));
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    console.warn(`[poller] VM ${vm.id} unreachable: ${msg}`);

    const vmStatus = {
      id: vm.id,
      role: vm.role,
      ip: vm.ip,
      port: vm.port,
      model: vm.model,
      isHub: !!vm.isHub,
      gatewayStatus: 'error' as const,
      lastProbed: now,
    };
    cacheVMStatus(vm.id, vmStatus);

    emitEvent({ type: 'system.health', timestamp: now, vmId: vm.id, status: 'error', latencyMs: 0 });

    // Mark all agents on this VM as offline
    for (const agentId of vm.agents) {
      const offlineAgent: Agent = {
        vmId: vm.id,
        agentId,
        displayId: `${agentId}@${vm.id.toUpperCase()}`,
        role: vm.role,
        model: vm.model,
        status: 'offline',
        lastActivityAt: now,
        isHub: !!vm.isHub,
      };
      if (hasAgentChanged(vm.id, agentId, offlineAgent)) {
        cacheAgentState(vm.id, agentId, offlineAgent);
        emitEvent({ type: 'agent.status', timestamp: now, vmId: vm.id, agentId, status: 'offline', lastActivity: now });
      }
    }
  }
}

async function pollAgent(
  vm: import('../types').VMConfig,
  agentId: string
): Promise<void> {
  const now = new Date().toISOString();
  try {
    const raw = await fetchAgentStatus(vm, agentId) as Record<string, unknown>;

    // Map gateway response to internal Agent type
    const agent: Agent = {
      vmId: vm.id,
      agentId,
      displayId: `${agentId}@${vm.id.toUpperCase()}`,
      role: vm.role,
      model: vm.model,
      status: mapGatewayStatus(raw.status as string),
      currentTaskId: (raw.currentTask as Record<string, unknown>)?.id as string | undefined,
      currentTaskTitle: (raw.currentTask as Record<string, unknown>)?.title as string | undefined,
      latestOutputSnippet: truncate((raw.lastOutput as string) || '', 280),
      lastActivityAt: (raw.lastActivity as string) || now,
      isHub: !!vm.isHub,
    };

    if (hasAgentChanged(vm.id, agentId, agent)) {
      cacheAgentState(vm.id, agentId, agent);
      emitEvent({ type: 'agent.status', timestamp: now, vmId: vm.id, agentId, status: agent.status, lastActivity: agent.lastActivityAt });
      if (agent.latestOutputSnippet) {
        emitEvent({ type: 'agent.output', timestamp: now, vmId: vm.id, agentId, snippet: agent.latestOutputSnippet });
      }
    }
  } catch (err: unknown) {
    console.warn(`[poller] Agent ${agentId}@${vm.id} error:`, (err as Error).message);
  }
}

function mapGatewayStatus(raw: string): AgentStatus {
  const s = (raw || '').toLowerCase();
  if (s === 'active' || s === 'working' || s === 'running') return 'active';
  if (s === 'idle' || s === 'waiting') return 'idle';
  if (s === 'blocked') return 'blocked';
  if (s === 'error' || s === 'failed') return 'error';
  return 'offline';
}

function truncate(str: string, max: number): string {
  return str.length > max ? str.slice(0, max) + '…' : str;
}
```

### 4.5 SSE Event Bus

**`backend/src/services/notificationBus.ts`:**

```typescript
import { EventEmitter } from 'events';
import { Response } from 'express';
import { SSEEvent } from '../types';

const bus = new EventEmitter();
bus.setMaxListeners(200);  // Allow many SSE clients

// Client registry: Map<clientId, Response>
const clients = new Map<string, Response>();
let clientCounter = 0;

export function addSSEClient(res: Response): string {
  const clientId = `sse-${++clientCounter}`;
  clients.set(clientId, res);
  console.log(`[sse] Client connected: ${clientId} (total: ${clients.size})`);
  return clientId;
}

export function removeSSEClient(clientId: string): void {
  clients.delete(clientId);
  console.log(`[sse] Client disconnected: ${clientId} (total: ${clients.size})`);
}

export function emitEvent(event: SSEEvent): void {
  const payload = `event: ${event.type}\ndata: ${JSON.stringify(event)}\n\n`;
  for (const [id, res] of clients) {
    try {
      res.write(payload);
    } catch {
      clients.delete(id);
    }
  }
  // Also emit on local bus for testing
  bus.emit(event.type, event);
}

export function onEvent(eventType: string, handler: (event: SSEEvent) => void): void {
  bus.on(eventType, handler);
}

// Heartbeat: prevents proxy timeout and detects dead connections
let heartbeatTimer: ReturnType<typeof setInterval> | null = null;
export function startHeartbeat(): void {
  if (heartbeatTimer) return;
  heartbeatTimer = setInterval(() => {
    const ping = `: ping\n\n`;
    for (const [id, res] of clients) {
      try {
        res.write(ping);
      } catch {
        clients.delete(id);
      }
    }
  }, 30_000);
}
startHeartbeat();
```

**`backend/src/routes/events.ts`:**

```typescript
import { Router, Request, Response } from 'express';
import { requireAuth } from '../middleware/auth';
import { addSSEClient, removeSSEClient, emitEvent } from '../services/notificationBus';
import { getAllCachedAgents, getAllCachedVMs } from '../services/stateCache';

const router = Router();

// GET /api/events — SSE stream
// Auth: JWT via cookie or ?token= query param (EventSource cannot set headers)
router.get('/', requireAuth, (req: Request, res: Response) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.setHeader('X-Accel-Buffering', 'no');  // Disable nginx buffering
  res.flushHeaders();

  // Send current state snapshot on connect
  const snapshot = {
    type: 'snapshot',
    agents: getAllCachedAgents(),
    vms: getAllCachedVMs(),
    timestamp: new Date().toISOString(),
  };
  res.write(`event: snapshot\ndata: ${JSON.stringify(snapshot)}\n\n`);

  const clientId = addSSEClient(res);

  req.on('close', () => removeSSEClient(clientId));
  req.on('error', () => removeSSEClient(clientId));
});

export default router;
```

### 4.6 Blueprint Git Service (`backend/src/services/blueprintGit.ts`)

```typescript
import simpleGit, { SimpleGit } from 'simple-git';
import * as fs from 'fs/promises';
import * as path from 'path';
import { loadConfig } from '../config';
import { BlueprintFile, BlueprintCommit } from '../types';

let git: SimpleGit | null = null;
let pullTimer: ReturnType<typeof setInterval> | null = null;

export async function initBlueprintGit(): Promise<void> {
  const cfg = loadConfig();
  if (!cfg.blueprintRepoUrl) return;

  const clonePath = cfg.blueprintClonePath;

  try {
    await fs.access(path.join(clonePath, '.git'));
    // Repo already cloned — just set up git instance
    git = simpleGit(clonePath);
    await git.pull();
    console.log('[blueprint] Git repo updated');
  } catch {
    // Clone fresh
    console.log('[blueprint] Cloning Blueprint repo...');
    const gitOptions = buildGitOptions(cfg);
    await simpleGit(gitOptions).clone(cfg.blueprintRepoUrl, clonePath, [
      '--depth', '1',
      '--single-branch',
      '--branch', cfg.blueprintBranch,
    ]);
    git = simpleGit(clonePath);
    console.log('[blueprint] Clone complete');
  }

  if (cfg.blueprintPullInterval > 0) {
    if (pullTimer) clearInterval(pullTimer);
    pullTimer = setInterval(async () => {
      try {
        await git?.pull();
        console.log('[blueprint] Auto-pull complete');
      } catch (e) {
        console.warn('[blueprint] Auto-pull failed:', (e as Error).message);
      }
    }, cfg.blueprintPullInterval * 1000);
  }
}

function buildGitOptions(cfg: ReturnType<typeof loadConfig>): Record<string, string> {
  if (cfg.blueprintSshKeyPath) {
    return { GIT_SSH_COMMAND: `ssh -i ${cfg.blueprintSshKeyPath} -o StrictHostKeyChecking=no` };
  }
  return {};
}

export async function getBlueprintTree(): Promise<BlueprintFile[]> {
  const cfg = loadConfig();
  return buildFileTree(cfg.blueprintClonePath, cfg.blueprintClonePath);
}

async function buildFileTree(rootPath: string, itemPath: string): Promise<BlueprintFile[]> {
  const entries = await fs.readdir(itemPath, { withFileTypes: true });
  const result: BlueprintFile[] = [];

  for (const entry of entries) {
    if (entry.name === '.git') continue;
    const fullPath = path.join(itemPath, entry.name);
    const relativePath = path.relative(rootPath, fullPath);

    if (entry.isDirectory()) {
      result.push({
        path: relativePath,
        name: entry.name,
        type: 'directory',
        children: await buildFileTree(rootPath, fullPath),
      });
    } else {
      result.push({
        path: relativePath,
        name: entry.name,
        type: 'file',
        status: await parseDocumentStatus(fullPath),
      });
    }
  }
  return result.sort((a, b) => {
    if (a.type !== b.type) return a.type === 'directory' ? -1 : 1;
    return a.name.localeCompare(b.name);
  });
}

async function parseDocumentStatus(filePath: string): Promise<import('../types').DocumentStatus | undefined> {
  if (!filePath.endsWith('.md')) return undefined;
  try {
    const content = await fs.readFile(filePath, 'utf-8');
    const match = content.match(/^---\n([\s\S]*?)\n---/);
    if (!match) return 'draft';
    const fm = match[1];
    const statusMatch = fm.match(/status:\s*(\S+)/i);
    const raw = statusMatch?.[1]?.toLowerCase() || 'draft';
    const valid = ['draft', 'in-review', 'approved', 'deprecated'] as const;
    return valid.includes(raw as typeof valid[number]) ? raw as import('../types').DocumentStatus : 'draft';
  } catch {
    return undefined;
  }
}

export async function getBlueprintFile(filePath: string): Promise<string> {
  const cfg = loadConfig();
  const safePath = path.join(cfg.blueprintClonePath, path.normalize(filePath).replace(/^(\.\.[/\\])+/, ''));
  return fs.readFile(safePath, 'utf-8');
}

export async function getBlueprintCommits(limit = 50): Promise<BlueprintCommit[]> {
  if (!git) return [];
  const log = await git.log([`-${limit}`, '--format=%H|%s|%an|%ae|%ai|%n']);
  return (log.all || []).map(c => ({
    sha: c.hash,
    shortSha: c.hash.slice(0, 7),
    message: c.message,
    author: c.author_name,
    authorEmail: c.author_email,
    timestamp: c.date,
    filesChanged: [],
  }));
}

export async function searchBlueprint(query: string): Promise<Array<{ path: string; snippet: string }>> {
  if (!git) return [];
  const cfg = loadConfig();
  const { exec } = await import('child_process');
  const { promisify } = await import('util');
  const execAsync = promisify(exec);

  try {
    const { stdout } = await execAsync(
      `grep -rl "${query.replace(/"/g, '\\"')}" --include="*.md" .`,
      { cwd: cfg.blueprintClonePath }
    );
    const files = stdout.trim().split('\n').filter(Boolean).slice(0, 20);
    const results: Array<{ path: string; snippet: string }> = [];
    for (const file of files) {
      const content = await getBlueprintFile(file.slice(2)); // Remove './'
      const idx = content.toLowerCase().indexOf(query.toLowerCase());
      if (idx >= 0) {
        results.push({
          path: file.slice(2),
          snippet: content.slice(Math.max(0, idx - 100), idx + 200),
        });
      }
    }
    return results;
  } catch {
    return [];
  }
}
```

### 4.7 Route Implementations

#### `backend/src/routes/agents.ts`

```typescript
import { Router, Request, Response } from 'express';
import { requireAuth } from '../middleware/auth';
import { loadConfig } from '../config';
import { getAllCachedAgents, getCachedAgent, getAllCachedVMs, getCachedVM } from '../services/stateCache';
import { fetchAgentSessions, fetchAgentSession, fetchAgentTools, fetchAgentLogs } from '../services/gatewayClient';

const router = Router();
router.use(requireAuth);

// GET /api/agents — All agents with current status
router.get('/', (_req, res: Response) => {
  const agents = getAllCachedAgents();
  res.json({ ok: true, data: agents });
});

// GET /api/vms — All VMs with connection status
router.get('/vms', (_req, res: Response) => {
  const cfg = loadConfig();
  const vms = cfg.vms.map(vm => ({
    ...getCachedVM(vm.id),
    agents: getAllCachedAgents().filter(a => a.vmId === vm.id),
  }));
  res.json({ ok: true, data: vms });
});

// GET /api/agents/:vmId/health — VM gateway health probe
router.get('/vms/:vmId/health', async (req: Request, res: Response) => {
  const { vmId } = req.params;
  const cfg = loadConfig();
  const vm = cfg.vms.find(v => v.id === vmId);
  if (!vm) { res.status(404).json({ ok: false, error: 'VM not found' }); return; }
  const cached = getCachedVM(vmId);
  res.json({ ok: true, data: cached || { id: vmId, gatewayStatus: 'unknown' } });
});

// GET /api/agents/:vmId/:agentId — Single agent detail
router.get('/:vmId/:agentId', (req: Request, res: Response) => {
  const { vmId, agentId } = req.params;
  const agent = getCachedAgent(vmId, agentId);
  if (!agent) { res.status(404).json({ ok: false, error: 'Agent not found' }); return; }
  res.json({ ok: true, data: agent });
});

// GET /api/agents/:vmId/:agentId/history — Conversation history (paginated)
router.get('/:vmId/:agentId/history', async (req: Request, res: Response) => {
  const { vmId, agentId } = req.params;
  const page = parseInt(req.query.page as string || '1', 10);
  const pageSize = parseInt(req.query.pageSize as string || '50', 10);
  const cfg = loadConfig();
  const vm = cfg.vms.find(v => v.id === vmId);
  if (!vm) { res.status(404).json({ ok: false, error: 'VM not found' }); return; }

  try {
    const sessions = await fetchAgentSessions(vm, agentId) as Array<{ id: string }>;
    // Return paginated session list; full session content on demand
    const start = (page - 1) * pageSize;
    const paged = sessions.slice(start, start + pageSize);
    res.json({ ok: true, data: paged, total: sessions.length, page, pageSize, hasMore: start + pageSize < sessions.length });
  } catch (e) {
    res.status(502).json({ ok: false, error: `Gateway error: ${(e as Error).message}` });
  }
});

// GET /api/agents/:vmId/:agentId/tools — Agent tool list
router.get('/:vmId/:agentId/tools', async (req: Request, res: Response) => {
  const { vmId, agentId } = req.params;
  const cfg = loadConfig();
  const vm = cfg.vms.find(v => v.id === vmId);
  if (!vm) { res.status(404).json({ ok: false, error: 'VM not found' }); return; }
  try {
    const tools = await fetchAgentTools(vm, agentId);
    res.json({ ok: true, data: tools });
  } catch (e) {
    res.status(502).json({ ok: false, error: `Gateway error: ${(e as Error).message}` });
  }
});

// GET /api/agents/:vmId/:agentId/metrics — Performance metrics (from cached gateway logs)
router.get('/:vmId/:agentId/metrics', async (req: Request, res: Response) => {
  const { vmId, agentId } = req.params;
  const cfg = loadConfig();
  const vm = cfg.vms.find(v => v.id === vmId);
  if (!vm) { res.status(404).json({ ok: false, error: 'VM not found' }); return; }
  try {
    const logs = await fetchAgentLogs(vm, agentId) as unknown[];
    // Derive metrics from raw logs (token counts, response times)
    const metrics = deriveMetricsFromLogs(logs);
    res.json({ ok: true, data: metrics });
  } catch (e) {
    res.status(502).json({ ok: false, error: `Gateway error: ${(e as Error).message}` });
  }
});

function deriveMetricsFromLogs(logs: unknown[]): import('../types').AgentMetrics {
  // Implementation: parse gateway log entries for response times and token counts
  // This is a stub — implement based on actual gateway log schema
  return {
    avgResponseTimeMs: { h24: 0, d7: 0, d30: 0 },
    totalTokensIn: 0,
    totalTokensOut: 0,
    tokensPerHour: [],
    errorRate: 0,
    gatewayUptimePct: 100,
  };
}

export default router;
```

#### Route summary for remaining routes

All remaining routes follow the same structure: `router.use(requireAuth)`, then GET-only handlers reading from cached state or services.

**`backend/src/routes/pipeline.ts`** endpoints:
- `GET /api/pipeline/current` — Returns current `PipelineIteration` (parsed from Blueprint `status.md`)
- `GET /api/pipeline/:iterationId` — Historical iteration state
- `GET /api/pipeline/:iterationId/phase/:phaseId` — Phase detail with tasks and gate criteria
- `GET /api/pipeline/iterations` — List all iteration IDs from Git tags/log
- `GET /api/pipeline/lobster/current` — Current Lobster workflow state from agent cache

**`backend/src/routes/blueprint.ts`** endpoints:
- `GET /api/blueprint/tree` — Returns `BlueprintFile[]` from `getBlueprintTree()`
- `GET /api/blueprint/file?path=` — Returns raw file content from `getBlueprintFile(path)`
- `GET /api/blueprint/commits?limit=50` — Returns `BlueprintCommit[]`
- `GET /api/blueprint/decisions` — Parses `decision-log.md` and returns structured entries
- `GET /api/blueprint/search?q=` — Returns grep results via `searchBlueprint(q)`

**`backend/src/routes/project.ts`** endpoints:
- `GET /api/project/health` — Returns `ProjectHealth` parsed from Blueprint `status.md`
- `GET /api/project/tasks?status=&priority=&vmId=` — Filtered task list from `status.md`
- `GET /api/project/backlog` — Backlog with MoSCoW breakdown
- `GET /api/project/iterations/current` — Current iteration + burndown data
- `GET /api/project/blockers` — All blocked tasks

**`backend/src/routes/qa.ts`** endpoints:
- `GET /api/qa/coverage` — `CoverageMetric[]` from Blueprint `qa/` directory
- `GET /api/qa/gates` — `QualityGate[]` from `qa/` reports
- `GET /api/qa/defects?status=open` — `Defect[]` from `qa/defects/`
- `GET /api/qa/defects/trend` — 30-day defect density time series
- `GET /api/qa/security` — OWASP coverage from security audit docs

**`backend/src/routes/operations.ts`** endpoints:
- `GET /api/ops/deployments` — Current `Deployment[]` per environment
- `GET /api/ops/deployments/history` — Recent deployment log
- `GET /api/ops/slo` — Current `SLO[]` from Operator VM cache or Blueprint
- `GET /api/ops/slo/:sloId/budget` — Error budget detail
- `GET /api/ops/incidents` — `Incident[]` from Blueprint `operations/incident-reports/`
- `GET /api/ops/usvmHealth` — Result from `usvmProbe.ts`

**`backend/src/routes/notifications.ts`** endpoints:
- `GET /api/notifications?priority=&vmId=&page=1` — Paginated `Notification[]`
- `GET /api/notifications/:id` — Single notification detail
- `GET /api/notifications/stats` — `NotificationStats`

**`backend/src/routes/setup.ts`** endpoints:
- `GET /api/setup/status` — Runs all health checks, returns `SetupHealthResult[]`
- `POST /api/setup/vm/test` — Body: `{ ip, port, hookToken, agentSecret }` → test connection
- `POST /api/setup/blueprint/test` — Body: `{ repoUrl, branch, patToken? }` → `git ls-remote`
- `POST /api/setup/telegram/test` — Body: `{ botToken }` → Telegram Bot API getMe
- `POST /api/setup/usvmTest` — Body: `{ tailscaleAddr, sshUser, sshKeyPath }` → SSH test
- `GET /api/setup/scan` — Scans `192.168.72.10`–`192.168.72.19` on port 18789
- `POST /api/config/save` — Writes validated config to disk (requires auth)
- `GET /api/config/export` — Returns config JSON without secrets
- `POST /api/config/import` — Imports non-secret config fields

### 4.8 US VM Probe (`backend/src/services/usvmProbe.ts`)

```typescript
import { exec } from 'child_process';
import { promisify } from 'util';
import fetch from 'node-fetch';
import { loadConfig } from '../config';

const execAsync = promisify(exec);

export interface USVMProbeResult {
  sshConnected: boolean;
  sshLatencyMs?: number;
  environments: Array<{
    name: 'dev' | 'uat' | 'production';
    status: 'healthy' | 'degraded' | 'down' | 'unknown';
    latencyMs?: number;
    checkedAt: string;
  }>;
}

export async function probeUSVM(): Promise<USVMProbeResult> {
  const cfg = loadConfig();
  const now = new Date().toISOString();

  if (!cfg.usvmTailscaleAddr) {
    return { sshConnected: false, environments: [] };
  }

  // SSH health check (lightweight: run `echo ok`)
  let sshConnected = false;
  let sshLatencyMs: number | undefined;
  try {
    const start = Date.now();
    await execAsync(
      `ssh -i ${cfg.usvmSshKeyPath} -o ConnectTimeout=5 -o StrictHostKeyChecking=no ` +
      `${cfg.usvmSshUser}@${cfg.usvmTailscaleAddr} "echo ok"`,
      { timeout: 8000 }
    );
    sshLatencyMs = Date.now() - start;
    sshConnected = true;
  } catch {
    sshConnected = false;
  }

  // HTTP health check per environment
  const envUrls: Record<string, string> = {
    dev: process.env.USVAM_DEV_HEALTH_URL || '',
    uat: process.env.USVAM_UAT_HEALTH_URL || '',
    production: process.env.USVAM_PROD_HEALTH_URL || '',
  };

  const environments = await Promise.all(
    (['dev', 'uat', 'production'] as const).map(async (env) => {
      const url = envUrls[env];
      if (!url) return { name: env, status: 'unknown' as const, checkedAt: now };
      try {
        const start = Date.now();
        const res = await fetch(url, { signal: AbortSignal.timeout(5000) });
        const latencyMs = Date.now() - start;
        return {
          name: env,
          status: res.ok ? (latencyMs < 300 ? 'healthy' as const : 'degraded' as const) : 'down' as const,
          latencyMs,
          checkedAt: new Date().toISOString(),
        };
      } catch {
        return { name: env, status: 'down' as const, checkedAt: new Date().toISOString() };
      }
    })
  );

  return { sshConnected, sshLatencyMs, environments };
}
```

---

## 5. Frontend Implementation

### 5.1 App Router Structure

```
src/app/
├── layout.tsx                          # Root layout: ThemeProvider, font, globals.css
├── (auth)/
│   └── login/
│       └── page.tsx                    # Login form — no sidebar
└── (portal)/
    ├── layout.tsx                      # Sidebar + Header shell; redirects to /login if no auth
    ├── page.tsx                        # Agent Dashboard (/)
    ├── pipeline/
    │   └── page.tsx
    ├── blueprint/
    │   ├── page.tsx                    # Blueprint Explorer root
    │   └── [...path]/
    │       └── page.tsx                # Dynamic file viewer
    ├── project/
    │   └── page.tsx
    ├── qa/
    │   └── page.tsx
    ├── operations/
    │   └── page.tsx
    ├── notifications/
    │   └── page.tsx
    ├── setup/
    │   └── page.tsx
    └── agents/
        └── [vmId]/
            └── [agentId]/
                └── page.tsx            # Agent detail page (mobile) / modal source (desktop)
```

**Root `app/layout.tsx`:**

```typescript
import type { Metadata } from 'next';
import { Inter } from 'next/font/google';
import { ThemeProvider } from '@/components/layout/ThemeProvider';
import './globals.css';

const inter = Inter({ subsets: ['latin'] });

export const metadata: Metadata = {
  title: 'GateForge Admin Portal',
  description: 'Observability dashboard for the GateForge multi-agent SDLC pipeline',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className={inter.className}>
        <ThemeProvider attribute="class" defaultTheme="system" enableSystem>
          {children}
        </ThemeProvider>
      </body>
    </html>
  );
}
```

### 5.2 Layout Components

**`src/components/layout/ThemeProvider.tsx`** — identical to ClawDeck:

```typescript
'use client';
import { ThemeProvider as NextThemesProvider } from 'next-themes';
import type { ThemeProviderProps } from 'next-themes/dist/types';
export function ThemeProvider({ children, ...props }: ThemeProviderProps) {
  return <NextThemesProvider {...props}>{children}</NextThemesProvider>;
}
```

**`src/app/(portal)/layout.tsx`:**

```typescript
'use client';
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Sidebar } from '@/components/layout/Sidebar';
import { Header } from '@/components/layout/Header';
import { api } from '@/lib/api';

export default function PortalLayout({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const [checked, setChecked] = useState(false);

  useEffect(() => {
    api.get<{ username: string }>('/api/auth/me')
      .then(() => setChecked(true))
      .catch(() => router.push('/login'));
  }, [router]);

  if (!checked) {
    return (
      <div className="flex h-screen items-center justify-center">
        <div className="text-muted-foreground text-sm">Loading…</div>
      </div>
    );
  }

  return (
    <div className="flex h-screen overflow-hidden bg-background">
      <Sidebar />
      <div className="flex flex-1 flex-col overflow-hidden">
        <Header />
        <main className="flex-1 overflow-auto p-4 md:p-6">
          {children}
        </main>
      </div>
    </div>
  );
}
```

**Sidebar nav items** (`src/components/layout/Sidebar.tsx`):

```typescript
const NAV_ITEMS = [
  { href: '/',              label: 'Agents',      icon: CircleDot,    shortcut: 'g+a' },
  { href: '/pipeline',      label: 'Pipeline',    icon: GitBranch,    shortcut: 'g+p' },
  { href: '/blueprint',     label: 'Blueprint',   icon: FolderOpen,   shortcut: 'g+b' },
  { href: '/project',       label: 'Project',     icon: BarChart2,    shortcut: 'g+r' },
  { href: '/qa',            label: 'QA Metrics',  icon: FlaskConical, shortcut: 'g+q' },
  { href: '/operations',    label: 'Operations',  icon: Rocket,       shortcut: 'g+o' },
  { href: '/notifications', label: 'Alerts',      icon: Bell,         shortcut: 'g+n', badge: true },
];

const BOTTOM_ITEMS = [
  { href: '/setup', label: 'Setup', icon: Settings, shortcut: 'g+s' },
];
```

### 5.3 Agent Dashboard Page

**`src/components/agents/StatusDot.tsx`:**

```typescript
import { AgentStatus } from '@/types';
import { cn } from '@/lib/utils';

interface StatusDotProps {
  status: AgentStatus;
  size?: 'sm' | 'md';
}

const STATUS_CONFIG: Record<AgentStatus, { color: string; ring: string; animation: string; label: string }> = {
  active:  { color: 'bg-[#22c55e]', ring: 'bg-[#22c55e]', animation: 'animate-ping', label: 'WORKING' },
  idle:    { color: 'bg-[#94a3b8]', ring: '',              animation: '',             label: 'IDLE'    },
  blocked: { color: 'bg-[#f97316]', ring: '',              animation: 'animate-slow-blink', label: 'BLOCKED' },
  error:   { color: 'bg-[#ef4444]', ring: '',              animation: 'animate-fast-blink', label: 'ERROR'   },
  offline: { color: 'bg-[#6b7280] border-2 border-current', ring: '', animation: '', label: 'OFFLINE' },
};

export function StatusDot({ status, size = 'md' }: StatusDotProps) {
  const cfg = STATUS_CONFIG[status];
  const dotSize = size === 'sm' ? 'w-2.5 h-2.5' : 'w-3 h-3';

  return (
    <span className="relative inline-flex items-center gap-1.5">
      <span className={cn('relative inline-flex rounded-full', dotSize)}>
        {status === 'active' && (
          <span className={cn('animate-ping absolute inline-flex h-full w-full rounded-full opacity-75', cfg.color)} />
        )}
        <span className={cn('relative inline-flex rounded-full', dotSize, cfg.color,
          status !== 'active' ? cfg.animation : ''
        )} />
      </span>
      <span className="text-xs font-mono font-semibold" style={{
        color: STATUS_CONFIG[status].color.replace('bg-[', '').replace(']', ''),
      }}>
        {cfg.label}
      </span>
    </span>
  );
}
```

**`src/components/agents/AgentCard.tsx`:**

```typescript
'use client';
import { Agent } from '@/types';
import { StatusDot } from './StatusDot';
import { NotificationBadge } from './NotificationBadge';
import { Card, CardContent, CardHeader } from '@/components/ui/card';
import { formatDistanceToNow } from '@/lib/utils';
import { cn } from '@/lib/utils';

interface AgentCardProps {
  agent: Agent;
  onClick: (agent: Agent) => void;
}

export function AgentCard({ agent, onClick }: AgentCardProps) {
  return (
    <Card
      className={cn(
        'relative cursor-pointer transition-all hover:shadow-md hover:border-primary/50',
        agent.isHub && 'border-2 border-blue-500/60',
        'min-h-[180px]'
      )}
      onClick={() => onClick(agent)}
      role="button"
      tabIndex={0}
      aria-label={`Agent ${agent.displayId}: ${agent.status}`}
      onKeyDown={(e) => e.key === 'Enter' && onClick(agent)}
    >
      {/* Hub badge */}
      {agent.isHub && (
        <span className="absolute top-2 left-2 text-[10px] font-bold bg-blue-500 text-white px-1.5 py-0.5 rounded">
          HUB
        </span>
      )}

      {/* Notification badge (top-right) */}
      {agent.activeNotificationPriority && (
        <NotificationBadge priority={agent.activeNotificationPriority} className="absolute top-2 right-2" />
      )}

      <CardHeader className={cn('pb-2', agent.isHub ? 'pt-7' : 'pt-4')}>
        <div className="flex items-start justify-between gap-2">
          <div>
            <div className="text-xs text-muted-foreground font-mono">{agent.vmId.toUpperCase()}</div>
            <div className="font-semibold text-sm leading-tight">{agent.role}</div>
            <div className="text-xs text-muted-foreground">{agent.model}</div>
          </div>
          <StatusDot status={agent.status} />
        </div>
      </CardHeader>

      <CardContent className="pt-0 space-y-2">
        {agent.currentTaskId && (
          <div className="text-xs">
            <span className="text-muted-foreground">Task: </span>
            <span className="font-mono font-medium">{agent.currentTaskId}</span>
            {agent.currentTaskTitle && (
              <span className="text-muted-foreground"> · {agent.currentTaskTitle}</span>
            )}
          </div>
        )}

        {agent.latestOutputSnippet && (
          <div className="text-xs text-muted-foreground line-clamp-3 italic border-l-2 border-muted pl-2">
            "{agent.latestOutputSnippet}"
          </div>
        )}

        <div className="flex items-center justify-between text-xs text-muted-foreground pt-1">
          <span>{formatDistanceToNow(agent.lastActivityAt)}</span>
          <span className="text-primary hover:underline">Details →</span>
        </div>
      </CardContent>
    </Card>
  );
}
```

**`src/hooks/useAgents.ts`:**

```typescript
'use client';
import { useState, useEffect, useCallback } from 'react';
import { Agent } from '@/types';
import { api } from '@/lib/api';
import { useSSE } from './useSSE';

export function useAgents() {
  const [agents, setAgents] = useState<Agent[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null);

  const refresh = useCallback(async () => {
    try {
      const res = await api.get<Agent[]>('/api/agents');
      setAgents(res);
      setLastUpdated(new Date());
      setError(null);
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { refresh(); }, [refresh]);

  // SSE live updates
  useSSE({
    onEvent: (event) => {
      if (event.type === 'agent.status') {
        setAgents(prev => prev.map(a =>
          a.vmId === event.vmId && a.agentId === event.agentId
            ? { ...a, status: event.status, lastActivityAt: event.lastActivity }
            : a
        ));
        setLastUpdated(new Date());
      }
      if (event.type === 'agent.output') {
        setAgents(prev => prev.map(a =>
          a.vmId === event.vmId && a.agentId === event.agentId
            ? { ...a, latestOutputSnippet: event.snippet }
            : a
        ));
      }
      if (event.type === 'snapshot') {
        setAgents((event as { agents: Agent[] }).agents || []);
        setLastUpdated(new Date());
      }
    },
  });

  return { agents, loading, error, lastUpdated, refresh };
}
```

**`src/hooks/useSSE.ts`:**

```typescript
'use client';
import { useEffect, useRef } from 'react';
import { SSEEvent } from '@/types';

interface UseSSEOptions {
  onEvent: (event: SSEEvent | Record<string, unknown>) => void;
  enabled?: boolean;
}

export function useSSE({ onEvent, enabled = true }: UseSSEOptions) {
  const esRef = useRef<EventSource | null>(null);
  const onEventRef = useRef(onEvent);
  onEventRef.current = onEvent;

  useEffect(() => {
    if (!enabled) return;

    let reconnectTimer: ReturnType<typeof setTimeout>;
    let retryDelay = 1000;

    function connect() {
      const backendUrl = process.env.NEXT_PUBLIC_BACKEND_URL || 'http://localhost:3001';
      // Pass JWT token as query param since EventSource cannot set headers
      const token = document.cookie.match(/auth_token=([^;]+)/)?.[1] || '';
      const url = `${backendUrl}/api/events${token ? `?token=${token}` : ''}`;

      const es = new EventSource(url, { withCredentials: true });
      esRef.current = es;

      es.addEventListener('message', (e) => {
        try { onEventRef.current(JSON.parse(e.data)); } catch {}
      });

      // Named event listeners for all SSE event types
      const eventTypes = [
        'snapshot', 'agent.status', 'agent.output', 'notification.new',
        'pipeline.update', 'qa.gateUpdate', 'ops.deployUpdate',
        'ops.sloAlert', 'blueprint.commit', 'system.health',
      ];
      for (const type of eventTypes) {
        es.addEventListener(type, (e: MessageEvent) => {
          try { onEventRef.current(JSON.parse(e.data)); } catch {}
        });
      }

      es.onerror = () => {
        es.close();
        retryDelay = Math.min(retryDelay * 2, 30_000);
        reconnectTimer = setTimeout(connect, retryDelay);
      };

      es.onopen = () => { retryDelay = 1000; };
    }

    connect();

    return () => {
      clearTimeout(reconnectTimer);
      esRef.current?.close();
    };
  }, [enabled]);
}
```

### 5.4 Lobster Pipeline Page

**`src/components/pipeline/PipelineCanvas.tsx`:**

```typescript
'use client';
import { useMemo } from 'react';
import ReactFlow, {
  Background,
  Controls,
  Edge,
  Node,
  NodeTypes,
} from '@xyflow/react';
import '@xyflow/react/dist/style.css';
import { PipelinePhase } from '@/types';
import { PhaseNode } from './PhaseNode';
import { PHASE_COLORS } from '@/lib/constants';

const nodeTypes: NodeTypes = { phaseNode: PhaseNode };

interface PipelineCanvasProps {
  phases: PipelinePhase[];
  onPhaseClick: (phase: PipelinePhase) => void;
}

export function PipelineCanvas({ phases, onPhaseClick }: PipelineCanvasProps) {
  const nodes: Node[] = useMemo(() =>
    phases.map((phase, i) => ({
      id: String(phase.id),
      type: 'phaseNode',
      position: { x: i * 200, y: 100 },
      data: { phase, onClick: onPhaseClick },
      selectable: false,
      draggable: false,
    })),
    [phases, onPhaseClick]
  );

  const edges: Edge[] = useMemo(() =>
    phases.slice(0, -1).map((phase, i) => ({
      id: `e${phase.id}-${phases[i + 1].id}`,
      source: String(phase.id),
      target: String(phases[i + 1].id),
      type: 'smoothstep',
      style: {
        stroke: phase.status === 'completed' ? '#16a34a' : '#6b7280',
        strokeWidth: 2,
      },
      animated: phases[i + 1].status === 'in-progress',
    })),
    [phases]
  );

  return (
    <div className="h-[320px] w-full rounded-lg border overflow-hidden">
      <ReactFlow
        nodes={nodes}
        edges={edges}
        nodeTypes={nodeTypes}
        fitView
        nodesDraggable={false}
        nodesConnectable={false}
        elementsSelectable={false}
        zoomOnScroll={false}
        panOnScroll={false}
        panOnDrag={false}
        proOptions={{ hideAttribution: true }}
      >
        <Background />
        <Controls showInteractive={false} />
      </ReactFlow>
    </div>
  );
}
```

**`src/components/pipeline/PhaseNode.tsx`** — Custom React Flow node:

```typescript
'use client';
import { Handle, Position, NodeProps } from '@xyflow/react';
import { PipelinePhase } from '@/types';
import { cn } from '@/lib/utils';
import { PHASE_COLORS, PHASE_STATUS_LABELS } from '@/lib/constants';

export function PhaseNode({ data }: NodeProps) {
  const { phase, onClick } = data as { phase: PipelinePhase; onClick: (p: PipelinePhase) => void };
  const color = PHASE_COLORS[phase.name];

  return (
    <>
      <Handle type="target" position={Position.Left} />
      <div
        className={cn(
          'w-[160px] rounded-lg border-2 p-3 cursor-pointer transition-shadow',
          'bg-card text-card-foreground',
          phase.status === 'in-progress' ? 'animate-phase-glow' : '',
          phase.status === 'completed' ? 'border-[#16a34a]' : '',
          phase.status === 'blocked' ? 'border-[#dc2626]' : '',
          phase.status === 'not-started' ? 'border-muted opacity-60' : '',
          phase.status === 'in-progress' ? `border-[${color}]` : '',
        )}
        style={phase.status === 'in-progress' ? { borderColor: color } : {}}
        onClick={() => onClick(phase)}
        role="button"
        tabIndex={0}
      >
        {/* Phase number watermark */}
        <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
          <span className="text-6xl font-black opacity-5 select-none">{phase.id}</span>
        </div>

        <div className="relative">
          <div className="text-xs text-muted-foreground font-mono">Phase {phase.id}</div>
          <div className="font-bold text-sm">{phase.name}</div>
          <div className="mt-1">
            <span className="text-xs px-1.5 py-0.5 rounded-full font-medium"
              style={{ background: color + '20', color }}>
              {PHASE_STATUS_LABELS[phase.status]}
            </span>
          </div>
          <div className="mt-2 text-xs space-y-0.5 font-mono">
            <div className="text-[#16a34a]">✓ {phase.taskCounts.passed}</div>
            <div className="text-[#3b82f6]">⟳ {phase.taskCounts.working}</div>
            <div className="text-muted-foreground">○ {phase.taskCounts.pending}</div>
            {phase.taskCounts.blocked > 0 && (
              <div className="text-[#dc2626]">✗ {phase.taskCounts.blocked}</div>
            )}
          </div>
        </div>
      </div>
      <Handle type="source" position={Position.Right} />
    </>
  );
}
```

### 5.5 Blueprint Explorer Page

**`src/components/blueprint/FileTree.tsx`:**

```typescript
'use client';
import { useState } from 'react';
import { BlueprintFile } from '@/types';
import { StatusBadge } from './StatusBadge';
import { ChevronRight, ChevronDown, FileText, Folder } from 'lucide-react';
import { cn } from '@/lib/utils';

interface FileTreeProps {
  files: BlueprintFile[];
  selectedPath?: string;
  onSelect: (file: BlueprintFile) => void;
  depth?: number;
}

export function FileTree({ files, selectedPath, onSelect, depth = 0 }: FileTreeProps) {
  return (
    <ul className="text-sm space-y-0.5">
      {files.map(file => (
        <FileTreeItem
          key={file.path}
          file={file}
          selectedPath={selectedPath}
          onSelect={onSelect}
          depth={depth}
        />
      ))}
    </ul>
  );
}

function FileTreeItem({ file, selectedPath, onSelect, depth }: {
  file: BlueprintFile; selectedPath?: string;
  onSelect: (file: BlueprintFile) => void; depth: number;
}) {
  const [open, setOpen] = useState(depth === 0);
  const isSelected = file.path === selectedPath;

  if (file.type === 'directory') {
    return (
      <li>
        <button
          className={cn('flex w-full items-center gap-1.5 rounded px-2 py-1 text-left hover:bg-muted/50')}
          style={{ paddingLeft: `${depth * 16 + 8}px` }}
          onClick={() => setOpen(!open)}
        >
          {open ? <ChevronDown className="w-3 h-3 shrink-0" /> : <ChevronRight className="w-3 h-3 shrink-0" />}
          <Folder className="w-3.5 h-3.5 shrink-0 text-blue-400" />
          <span className="truncate font-medium">{file.name}</span>
        </button>
        {open && file.children && (
          <FileTree files={file.children} selectedPath={selectedPath} onSelect={onSelect} depth={depth + 1} />
        )}
      </li>
    );
  }

  return (
    <li>
      <button
        className={cn(
          'flex w-full items-center gap-1.5 rounded px-2 py-1 text-left hover:bg-muted/50',
          isSelected && 'bg-primary/10 text-primary font-medium'
        )}
        style={{ paddingLeft: `${depth * 16 + 8}px` }}
        onClick={() => onSelect(file)}
      >
        <FileText className="w-3.5 h-3.5 shrink-0 text-muted-foreground" />
        <span className="truncate flex-1">{file.name}</span>
        {file.status && <StatusBadge status={file.status} />}
      </button>
    </li>
  );
}
```

### 5.6 Project Dashboard Page

Key components with props:

```typescript
// HealthCard.tsx
interface HealthCardProps {
  dimension: HealthDimension;
}

// TaskTable.tsx
interface TaskTableProps {
  tasks: Task[];
  onFilter?: (filters: Partial<FilterParams>) => void;
}

// BurndownChart.tsx — uses Recharts ResponsiveContainer
interface BurndownChartProps {
  data: BurndownDataPoint[];
  iterationLabel: string;
}
// Chart uses: AreaChart + Area for "ideal" (dashed), "actual" (solid), optional "scope"
// ResponsiveContainer wraps the chart; legend at bottom

// BlockersList.tsx
interface BlockersListProps {
  tasks: Task[];  // tasks with status === 'blocked'
}
```

### 5.7 QA Metrics Page

**`src/components/qa/CoverageGauge.tsx`:**

```typescript
'use client';
import { CoverageMetric } from '@/types';
import { RadialBarChart, RadialBar, Tooltip, ResponsiveContainer } from 'recharts';

interface CoverageGaugeProps {
  metric: CoverageMetric;
  type: 'unit' | 'integration' | 'e2e';
}

const THRESHOLD_MAP = {
  unit: 95,
  integration: 90,
  e2e: 85,
};

const COLOR_MAP = {
  unit: '#4f46e5',
  integration: '#7c3aed',
  e2e: '#0d9488',
};

export function CoverageGauge({ metric, type }: CoverageGaugeProps) {
  const value = metric[type];
  const threshold = THRESHOLD_MAP[type];
  const color = value >= threshold ? '#16a34a' : value >= threshold * 0.7 ? '#ca8a04' : '#dc2626';

  return (
    <div className="flex flex-col items-center gap-1">
      <div className="relative w-20 h-20">
        <ResponsiveContainer width="100%" height="100%">
          <RadialBarChart cx="50%" cy="50%" innerRadius="60%" outerRadius="80%"
            startAngle={90} endAngle={-270} data={[{ value }]}>
            <RadialBar dataKey="value" fill={color} background={{ fill: '#e5e7eb' }} cornerRadius={4} />
          </RadialBarChart>
        </ResponsiveContainer>
        <div className="absolute inset-0 flex items-center justify-center">
          <span className="text-sm font-bold" style={{ color }}>{value}%</span>
        </div>
      </div>
      <div className="text-xs text-muted-foreground capitalize">{type}</div>
      <div className="text-xs text-muted-foreground">≥{threshold}%</div>
    </div>
  );
}
```

### 5.8 Operations Page

Components with key props:

```typescript
// SLOGauge.tsx
interface SLOGaugeProps {
  slo: SLO;
}
// Renders a horizontal progress bar with color determined by budgetStatus
// Green: healthy, Yellow: warning, Red: critical, DarkRed + fast-blink: exhausted

// BurnRateCard.tsx
interface BurnRateCardProps {
  slo: SLO;
}
// Shows 4 burn rate tiers: 1h / 6h / 24h / 72h
// Color coding: >2x budget rate = red, >1x = yellow, <1x = green

// EnvironmentCard.tsx
interface EnvironmentCardProps {
  deployment: Deployment;
}

// IncidentTimeline.tsx
interface IncidentTimelineProps {
  incidents: Incident[];
}
// Chronological list with severity color coding, MTTR summary stat
```

### 5.9 Notification Center Page

**`src/hooks/useNotifications.ts`:**

```typescript
'use client';
import { useState, useEffect, useCallback } from 'react';
import { Notification, NotificationPriority } from '@/types';
import { api } from '@/lib/api';
import { useSSE } from './useSSE';

interface NotificationFilters {
  vmId?: string;
  priority?: NotificationPriority;
  page?: number;
  pageSize?: number;
}

export function useNotifications(filters: NotificationFilters = {}) {
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [loading, setLoading] = useState(true);

  const refresh = useCallback(async () => {
    const params = new URLSearchParams();
    if (filters.vmId) params.set('vmId', filters.vmId);
    if (filters.priority) params.set('priority', filters.priority);
    params.set('page', String(filters.page ?? 1));
    params.set('pageSize', String(filters.pageSize ?? 50));
    const res = await api.get<Notification[]>(`/api/notifications?${params}`);
    setNotifications(res);
    setLoading(false);
  }, [filters]);

  useEffect(() => { refresh(); }, [refresh]);

  useSSE({
    onEvent: (event) => {
      if (event.type === 'notification.new') {
        const newNotif = (event as { notification: Notification }).notification;
        setNotifications(prev => [newNotif, ...prev]);
        setUnreadCount(c => c + 1);

        // Browser toast for CRITICAL / BLOCKED
        if (['CRITICAL', 'BLOCKED'].includes(newNotif.priority)) {
          // Use shadcn toast (trigger via custom event or toast hook)
          window.dispatchEvent(new CustomEvent('portal:toast', { detail: newNotif }));
        }
      }
    },
  });

  return { notifications, unreadCount, loading, refresh };
}
```

**`src/components/notifications/NotificationEntry.tsx`:**

```typescript
import { Notification, NotificationPriority } from '@/types';
import { NOTIFICATION_COLORS } from '@/lib/constants';
import { cn } from '@/lib/utils';

interface NotificationEntryProps {
  notification: Notification;
  onViewContext: (notification: Notification) => void;
}

export function NotificationEntry({ notification, onViewContext }: NotificationEntryProps) {
  const cfg = NOTIFICATION_COLORS[notification.priority];

  return (
    <div
      className={cn('rounded-lg border-l-4 p-3 mb-2', 'bg-card')}
      style={{ borderLeftColor: cfg.border, backgroundColor: cfg.bg }}
    >
      <div className="flex items-center justify-between gap-2 text-xs mb-1">
        <div className="flex items-center gap-2">
          <span className="font-bold" style={{ color: cfg.border }}>
            {cfg.icon} {notification.priority}
          </span>
          <span className="text-muted-foreground">
            {notification.agentId}@{notification.vmId.toUpperCase()}
          </span>
        </div>
        <span className="text-muted-foreground font-mono">
          {new Date(notification.timestamp).toLocaleString('en-HK', { timeZone: 'Asia/Hong_Kong' })}
        </span>
      </div>
      <p className="text-sm">{notification.message}</p>
      <div className="flex gap-2 mt-2 text-xs text-muted-foreground">
        {notification.taskId && <span>Task: {notification.taskId}</span>}
        {notification.gitRef && <span>Git: {notification.gitRef.slice(0, 7)}</span>}
        {notification.phase && <span>Phase: {notification.phase}</span>}
      </div>
      <div className="flex gap-2 mt-2">
        <button
          className="text-xs text-primary hover:underline"
          onClick={() => onViewContext(notification)}
        >
          View Full Context
        </button>
      </div>
    </div>
  );
}
```

### 5.10 Setup & Configuration Page

**Setup wizard step configuration:**

```typescript
const WIZARD_STEPS = [
  { id: 1, label: 'Admin',     component: Step1Admin,     icon: User      },
  { id: 2, label: 'VMs',       component: Step2VMs,       icon: Server    },
  { id: 3, label: 'AI Keys',   component: Step3AIKeys,    icon: Key       },
  { id: 4, label: 'Telegram',  component: Step4Telegram,  icon: MessageSquare },
  { id: 5, label: 'Blueprint', component: Step5Blueprint, icon: GitBranch },
  { id: 6, label: 'Deploy',    component: Step6Deploy,    icon: Rocket    },
  { id: 7, label: 'Review',    component: Step7Review,    icon: CheckCircle },
];
```

**`src/components/setup/VMRegistrationCard.tsx`** — key props:

```typescript
interface VMRegistrationCardProps {
  vmId: string;
  role: string;
  defaultIp: string;
  defaultPort: number;
  value: Partial<VMConfig>;
  onChange: (update: Partial<VMConfig>) => void;
  onTestConnection: (config: Partial<VMConfig>) => Promise<void>;
  testResult?: { ok: boolean; message: string; latencyMs?: number };
}
```

### 5.11 Shared Components & Hooks

**`src/lib/api.ts`:**

```typescript
const BASE = process.env.NEXT_PUBLIC_BACKEND_URL || 'http://localhost:3001';

async function request<T>(method: string, path: string, body?: unknown): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    method,
    credentials: 'include',       // Send HttpOnly JWT cookie
    headers: body ? { 'Content-Type': 'application/json' } : {},
    body: body ? JSON.stringify(body) : undefined,
  });

  if (!res.ok) {
    const err = await res.json().catch(() => ({ error: res.statusText }));
    if (res.status === 401) {
      // Redirect to login — but only on client side
      if (typeof window !== 'undefined') window.location.href = '/login';
    }
    throw new Error(err.error || `HTTP ${res.status}`);
  }

  const json = await res.json();
  return (json.data ?? json) as T;
}

export const api = {
  get:  <T>(path: string) => request<T>('GET', path),
  post: <T>(path: string, body: unknown) => request<T>('POST', path, body),
};
```

**`src/lib/constants.ts`** — all status color mappings (see Section 11 for full table).

---

## 6. Implementation Phases & Task Breakdown

### Phase 1: Foundation (Weeks 1–3)

**Objective:** Deployable scaffold with auth, setup wizard, and VM connectivity probe.

| Task ID | Title | Assigned VM | Dependencies | Acceptance Criteria | Points |
|---------|-------|-------------|--------------|---------------------|--------|
| TASK-PORTAL-001 | Repo scaffolding + monorepo structure | VM-3 dev-01 | — | `docker compose up --build` runs; frontend and backend containers start; `/health` returns 200 | 3 |
| TASK-PORTAL-002 | Backend: `config.ts` with GATEFORGE_VMS JSON parsing and env validation | VM-3 dev-01 | TASK-PORTAL-001 | Config loads without error; missing required vars log a clear warning; invalid JSON triggers graceful fallback | 2 |
| TASK-PORTAL-003 | Backend: JWT auth routes (`/api/auth/login`, `/api/auth/logout`, `/api/auth/me`) | VM-3 dev-01 | TASK-PORTAL-002 | Login returns HttpOnly JWT cookie; logout clears cookie; `/me` returns 401 without cookie and 200 with valid cookie | 3 |
| TASK-PORTAL-004 | Backend: Rate limiter middleware (5 req/min on `/api/auth/login`) | VM-3 dev-01 | TASK-PORTAL-003 | 6th login attempt within 60s returns 429; counter resets after window expires | 2 |
| TASK-PORTAL-005 | Frontend: Login page (`/login`) with form validation | VM-3 dev-02 | TASK-PORTAL-001 | Login form validates username/password; submits to backend; redirects to `/` on success; shows error on failure | 3 |
| TASK-PORTAL-006 | Frontend: Portal layout with Sidebar + Header shell | VM-3 dev-02 | TASK-PORTAL-005 | Sidebar renders all 7 nav items with icons; Header shows page title and user menu; responsive (hamburger < 768px) | 5 |
| TASK-PORTAL-007 | Backend: Gateway client service (read-only GET, two-layer auth headers) | VM-3 dev-01 | TASK-PORTAL-002 | `fetchVMHealth` returns health response from mock gateway; request includes `X-Hook-Token` and `X-Agent-Secret` headers; POST to any gateway endpoint is blocked at service layer | 3 |
| TASK-PORTAL-008 | Backend: State cache + poller (parallel VM polling, delta detection) | VM-3 dev-01 | TASK-PORTAL-007 | Poller starts on app launch; polls all 5 VMs every AGENT_POLL_INTERVAL seconds; one VM failure does not stop others; `hasAgentChanged` correctly identifies delta | 5 |
| TASK-PORTAL-009 | Backend: SSE event bus + `/api/events` endpoint | VM-3 dev-01 | TASK-PORTAL-008 | `GET /api/events` returns `text/event-stream`; client receives `snapshot` event on connect; heartbeat ping emitted every 30s; client removed from registry on disconnect | 5 |
| TASK-PORTAL-010 | Frontend: `useSSE` hook with reconnection logic | VM-3 dev-02 | TASK-PORTAL-009 | Hook connects to `/api/events`; reconnects on disconnect with exponential backoff (max 30s); dispatches events to `onEvent` callback | 3 |
| TASK-PORTAL-011 | Frontend: Setup Wizard (Steps 1–7, stepper UI) | VM-3 dev-02 | TASK-PORTAL-006 | All 7 steps render; stepper shows current/completed/pending states; step-level validation prevents advancing with invalid data | 8 |
| TASK-PORTAL-012 | Backend: Setup test endpoints (`/api/setup/vm/test`, `/api/setup/scan`) | VM-3 dev-01 | TASK-PORTAL-007 | `POST /api/setup/vm/test` probes the given IP:port with provided tokens and returns latency or error within 5s; scan returns discovered VMs on 192.168.72.10–19 | 5 |
| TASK-PORTAL-013 | Frontend: Setup wizard VM Registration cards with test connection | VM-3 dev-02 | TASK-PORTAL-011 | Each VM card shows pre-filled IP/port; Test Connection button calls backend and shows ✓/✗ result with latency badge color (green/yellow/red) | 5 |
| TASK-PORTAL-014 | `install.sh` interactive installer | VM-3 dev-01 | TASK-PORTAL-001 | Script runs on macOS and Linux; generates `.env` with hashed password; prompts for all 5 VMs; optionally builds and launches Docker Compose | 3 |

**Phase 1 Total:** 55 story points

### Phase 2: Core Views (Weeks 4–7)

**Objective:** Agent Dashboard, Pipeline View, Notification Center, Blueprint Explorer — all live.

| Task ID | Title | Assigned VM | Dependencies | Acceptance Criteria | Points |
|---------|-------|-------------|--------------|---------------------|--------|
| TASK-PORTAL-015 | Type definitions shared file (`types/index.ts`) | VM-3 dev-01 | TASK-PORTAL-001 | All types from Section 3 defined; compiles without error in both frontend and backend strict mode | 3 |
| TASK-PORTAL-016 | Backend: `/api/agents` routes (list, detail, history, tools, metrics) | VM-3 dev-01 | TASK-PORTAL-008 | All 7 agent endpoints respond with data; history is paginated; metrics returns structured object; 404 on unknown agent | 5 |
| TASK-PORTAL-017 | Frontend: `StatusDot` component (all 5 states, animations) | VM-3 dev-02 | TASK-PORTAL-006 | Active shows `animate-ping` ring; blocked shows `animate-slow-blink`; error shows `animate-fast-blink`; all states have ARIA label; `prefers-reduced-motion` respected | 3 |
| TASK-PORTAL-018 | Frontend: `AgentCard` component | VM-3 dev-02 | TASK-PORTAL-017 | Card renders all fields (VM ID, role, model, status dot, task, output snippet, timestamp); hub badge on VM-1; keyboard accessible; click triggers detail view | 5 |
| TASK-PORTAL-019 | Frontend: `AgentGrid` + Agent Dashboard page | VM-3 dev-02 | TASK-PORTAL-018 | Grid is 1/2/3 columns responsive; VM-3 and VM-4 grouped with section headers and collapse toggle; read-only banner dismissible per session | 5 |
| TASK-PORTAL-020 | Frontend: `useAgents` hook with SSE live update | VM-3 dev-02 | TASK-PORTAL-010 | Agent card status dot updates within 10s of gateway state change without page reload | 3 |
| TASK-PORTAL-021 | Frontend: `AgentDetailModal` with 4 tabs | VM-3 dev-02 | TASK-PORTAL-019 | Modal opens on card click; 4 tabs (Conversation, Tasks, Tools, Performance) render data; no input/send button present | 8 |
| TASK-PORTAL-022 | Backend: Blueprint Git service (clone, auto-pull, tree, file, commits, search) | VM-3 dev-01 | TASK-PORTAL-008 | Shallow clone on startup; auto-pull on configured interval; tree endpoint returns nested `BlueprintFile[]`; file endpoint returns raw Markdown; search returns matching snippets | 8 |
| TASK-PORTAL-023 | Backend: `/api/blueprint` routes | VM-3 dev-01 | TASK-PORTAL-022 | All 5 blueprint endpoints respond correctly; file path traversal attacks blocked (no `../` escapes); non-Markdown file access returns content-type header appropriately | 5 |
| TASK-PORTAL-024 | Frontend: Blueprint Explorer page (FileTree + DocumentViewer) | VM-3 dev-02 | TASK-PORTAL-023 | File tree renders nested structure; click on `.md` file renders Markdown with syntax highlighting; commit log sidebar shows last 10 commits; status badges on files | 8 |
| TASK-PORTAL-025 | Backend: Pipeline routes (reads from Blueprint `status.md`) | VM-3 dev-01 | TASK-PORTAL-022 | `/api/pipeline/current` returns 6-phase `PipelineIteration`; phase task counts computed correctly; gate decisions parsed from QA reports | 5 |
| TASK-PORTAL-026 | Frontend: Pipeline Canvas (React Flow, 6 phase nodes, edges) | VM-3 dev-02 | TASK-PORTAL-025 | Pipeline renders 6 nodes in horizontal layout; active phase has `animate-phase-glow` border; completed edges are green; not-started nodes are gray/dimmed; non-interactive | 8 |
| TASK-PORTAL-027 | Frontend: Phase Detail Panel + Quality Gate Panel | VM-3 dev-02 | TASK-PORTAL-026 | Click on phase node opens slide-in panel; PROMOTE/HOLD/ROLLBACK shown with correct color; gate criteria checklist shows ✓/✗ per criterion | 5 |
| TASK-PORTAL-028 | Backend: Notification routes (feed, stats, detail) | VM-3 dev-01 | TASK-PORTAL-008 | Notifications filterable by vmId, priority, page; stats endpoint returns breakdowns by priority and VM | 5 |
| TASK-PORTAL-029 | Frontend: Notification Center page (feed, filter bar, entry, real-time) | VM-3 dev-02 | TASK-PORTAL-020 | Feed shows priority-colored left borders; new notifications prepend with slide-in animation; CRITICAL/BLOCKED triggers browser toast; filter bar works correctly | 8 |
| TASK-PORTAL-030 | Frontend: `NotificationBadge` + header notification bell | VM-3 dev-02 | TASK-PORTAL-029 | Header bell shows unread count badge; badge increments on new SSE notification; navigating to Notifications page clears count | 3 |

**Phase 2 Total:** 87 story points

### Phase 3: Dashboards (Weeks 8–10)

**Objective:** Project Dashboard, QA Metrics, Operations Dashboard.

| Task ID | Title | Assigned VM | Dependencies | Acceptance Criteria | Points |
|---------|-------|-------------|--------------|---------------------|--------|
| TASK-PORTAL-031 | Backend: Project routes (health, tasks, backlog, burndown, blockers) | VM-3 dev-01 | TASK-PORTAL-022 | All 5 endpoints return typed data parsed from Blueprint; health dimensions return green/yellow/red; task filter params work | 5 |
| TASK-PORTAL-032 | Frontend: `HealthCard` component (6 dimension cards) | VM-3 dev-02 | TASK-PORTAL-031 | 6 cards render: Phase, Status, Schedule, Budget, Quality, Team; each shows status color (left border), summary text, and detail on hover | 3 |
| TASK-PORTAL-033 | Frontend: `TaskTable` with filter + sort | VM-3 dev-02 | TASK-PORTAL-031 | Table shows all task fields; filter chips for status and priority; sortable columns; mobile collapses to card view | 5 |
| TASK-PORTAL-034 | Frontend: `BurndownChart` (Recharts area chart) | VM-3 dev-02 | TASK-PORTAL-031 | Chart renders ideal (dashed), actual (solid), optional scope lines; `ResponsiveContainer`; legend; dark mode compatible | 3 |
| TASK-PORTAL-035 | Backend: QA routes (coverage, gates, defects, security) | VM-3 dev-01 | TASK-PORTAL-022 | All 7 QA endpoints return typed data; coverage thresholds computed correctly; defect trend returns 30 data points | 5 |
| TASK-PORTAL-036 | Frontend: `CoverageGauge` (radial bar per module per type) | VM-3 dev-02 | TASK-PORTAL-035 | Gauge color: green ≥ threshold, yellow ≥ 70% of threshold, red < 70%; threshold marker displayed | 5 |
| TASK-PORTAL-037 | Frontend: `GateDecisionCard` (PROMOTE/HOLD/ROLLBACK) | VM-3 dev-02 | TASK-PORTAL-035 | Card shows decision banner with correct color; criteria checklist with ✓/✗; module name and gate type badge | 3 |
| TASK-PORTAL-038 | Frontend: `DefectSummary` table + trend chart | VM-3 dev-02 | TASK-PORTAL-035 | Severity breakdown table; line chart for 30-day trend; escape stage column with color | 3 |
| TASK-PORTAL-039 | Frontend: `SecurityPanel` (OWASP Top 10 checklist) | VM-3 dev-02 | TASK-PORTAL-035 | All 10 OWASP items listed; covered items checked; notes expandable | 2 |
| TASK-PORTAL-040 | Backend: US VM probe service | VM-3 dev-01 | TASK-PORTAL-002 | SSH probe returns connected/failed; HTTP health checks per environment return status and latency; all within 8s | 5 |
| TASK-PORTAL-041 | Backend: Operations routes (deployments, SLOs, incidents, US VM health) | VM-3 dev-01 | TASK-PORTAL-040 | All 8 ops endpoints respond; SLO budget status computed correctly; deployment history paginated | 5 |
| TASK-PORTAL-042 | Frontend: `EnvironmentCard` (Dev/UAT/Prod status) | VM-3 dev-02 | TASK-PORTAL-041 | 3 environment cards; status badge + version + timestamp; latency displayed; deployment status color | 3 |
| TASK-PORTAL-043 | Frontend: `SLOGauge` (5 SLOs, error budget progress bars) | VM-3 dev-02 | TASK-PORTAL-041 | Each SLO shows target, current, and % error budget remaining; color matches `budgetStatus`; exhausted state blinks | 5 |
| TASK-PORTAL-044 | Frontend: `BurnRateCard` (4 burn rate tiers) | VM-3 dev-02 | TASK-PORTAL-041 | 4 rate indicators (1h/6h/24h/72h); color thresholds correct; exceeding budget rate shows red | 3 |
| TASK-PORTAL-045 | Frontend: `IncidentTimeline` + `DeploymentLog` | VM-3 dev-02 | TASK-PORTAL-041 | Chronological incidents with severity color; MTTR displayed; deployment log shows last 10 deployments | 3 |

**Phase 3 Total:** 59 story points

### Phase 4: Polish (Weeks 11–12)

**Objective:** Dark/light mode, responsive design, full test pass, documentation.

| Task ID | Title | Assigned VM | Dependencies | Acceptance Criteria | Points |
|---------|-------|-------------|--------------|---------------------|--------|
| TASK-PORTAL-046 | Dark mode: all status colors pass WCAG AA in dark mode | VM-3 dev-02 | All UI tasks | Every status color (Section 11) achieves ≥ 4.5:1 contrast ratio in both light and dark mode | 3 |
| TASK-PORTAL-047 | Responsive design audit (mobile < 768px, tablet 768–1279px) | VM-3 dev-02 | All UI tasks | Pipeline scrolls horizontally on mobile; tables collapse to card view; sidebar becomes hamburger; min touch target 44×44px | 5 |
| TASK-PORTAL-048 | `prefers-reduced-motion` support for all animations | VM-3 dev-02 | TASK-PORTAL-017 | All `animate-ping`, `animate-slow-blink`, `animate-fast-blink`, `animate-phase-glow` are disabled when media query is active | 2 |
| TASK-PORTAL-049 | Frontend unit tests (Jest + RTL) — target 85% coverage | VM-4 qc-01 | All UI tasks | All component files have test files; coverage report shows ≥ 85% statements; no `any` types in test files | 8 |
| TASK-PORTAL-050 | Backend unit tests (Jest) — target 90% coverage | VM-4 qc-01 | All backend tasks | All service and route files have tests; mock gateway responses; mock Git operations; ≥ 90% statement coverage | 8 |
| TASK-PORTAL-051 | E2E tests (Playwright) — agent dashboard, notifications, login flow | VM-4 qc-02 | All tasks | Login → see agent cards; receive SSE notification → toast appears; filter notifications; setup test connection works | 8 |
| TASK-PORTAL-052 | Performance audit: page load < 3s, bundle size targets | VM-4 qc-02 | All tasks | Lighthouse performance ≥ 90; initial JS bundle < 300KB gzipped; LCP < 3s on simulated 4G | 5 |
| TASK-PORTAL-053 | Security audit: read-only enforcement, CSP, rate limiter | VM-4 qc-01 | All backend tasks | POST to any gateway endpoint blocked; CSP headers present; login rate limiter verified; JWT cookie is HttpOnly | 5 |
| TASK-PORTAL-054 | README.md + inline JSDoc for all exported functions | VM-3 dev-01 | All tasks | README covers quick-start, env vars, development workflow; all exported functions have JSDoc | 3 |

**Phase 4 Total:** 47 story points

**Grand Total: 248 story points across 54 tasks**

---

## 7. Testing Strategy

### Unit Testing (Jest + React Testing Library)

**Frontend component tests** (`*.test.tsx` co-located with components):

```typescript
// Example: StatusDot.test.tsx
import { render, screen } from '@testing-library/react';
import { StatusDot } from './StatusDot';

describe('StatusDot', () => {
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

  it('applies animate-ping class for active status', () => {
    const { container } = render(<StatusDot status="active" />);
    expect(container.querySelector('.animate-ping')).toBeTruthy();
  });
});
```

**Backend service tests** (`*.test.ts` in `src/services/__tests__/`):

```typescript
// Example: stateCache.test.ts
import { cacheAgentState, getCachedAgent, hasAgentChanged } from '../stateCache';
import { Agent } from '../../types';

const mockAgent: Agent = {
  vmId: 'vm-1', agentId: 'architect', displayId: 'architect@VM-1',
  role: 'System Architect', model: 'claude-opus-4.6',
  status: 'active', lastActivityAt: '2026-04-07T12:00:00Z', isHub: true,
};

describe('stateCache', () => {
  it('caches and retrieves agent state', () => {
    cacheAgentState('vm-1', 'architect', mockAgent);
    expect(getCachedAgent('vm-1', 'architect')).toEqual(mockAgent);
  });

  it('detects status change as delta', () => {
    cacheAgentState('vm-1', 'architect', mockAgent);
    expect(hasAgentChanged('vm-1', 'architect', { ...mockAgent, status: 'idle' })).toBe(true);
  });
});
```

### Integration Testing (Backend API endpoints)

Use `supertest` to test all Express routes with a live Express app and mock services:

```typescript
// agents.test.ts
import request from 'supertest';
import app from '../../index';

describe('GET /api/agents', () => {
  it('returns 401 without auth', async () => {
    const res = await request(app).get('/api/agents');
    expect(res.status).toBe(401);
  });

  it('returns agent list with valid JWT', async () => {
    // Log in first, use returned cookie
    const login = await request(app)
      .post('/api/auth/login')
      .send({ username: 'admin', password: 'testpass' });
    const cookie = login.headers['set-cookie'];

    const res = await request(app)
      .get('/api/agents')
      .set('Cookie', cookie);
    expect(res.status).toBe(200);
    expect(res.body.ok).toBe(true);
    expect(Array.isArray(res.body.data)).toBe(true);
  });
});
```

### E2E Testing (Playwright)

```typescript
// tests/e2e/login.spec.ts
import { test, expect } from '@playwright/test';

test('login → agent dashboard', async ({ page }) => {
  await page.goto('/login');
  await page.fill('input[name="username"]', 'admin');
  await page.fill('input[name="password"]', process.env.TEST_PASSWORD!);
  await page.click('button[type="submit"]');
  await expect(page).toHaveURL('/');
  await expect(page.locator('[data-testid="agent-grid"]')).toBeVisible();
  await expect(page.locator('[data-testid="read-only-banner"]')).toBeVisible();
});

test('SSE: agent status updates live', async ({ page }) => {
  // Navigate to dashboard, wait for live update from mock SSE
  await page.goto('/');
  // Simulate SSE event via backend test endpoint (dev-only)
  // Verify card updates without reload
});
```

**Coverage Targets (aligned with GateForge QA gates):**

| Layer | Target | Gate Decision if Below |
|-------|--------|------------------------|
| Frontend unit | ≥ 85% | HOLD at < 85%; ROLLBACK at < 60% |
| Backend unit | ≥ 90% | HOLD at < 90%; ROLLBACK at < 63% |
| E2E | ≥ 85% critical flows | HOLD at < 85%; ROLLBACK at < 60% |

### Mock Data Strategy

For frontend development before backend is fully connected:

1. All API calls in `src/lib/api.ts` check for `NEXT_PUBLIC_MOCK_API=true` env var.
2. When mocked, `api.get()` returns data from `src/lib/mockData/*.json` files.
3. Mock data JSON files are provided in Section 12 of this document.
4. SSE events are simulated with a `MockSSEProvider` component (dev-only) that emits events on a timer.

---

## 8. Security Considerations

### Read-Only Enforcement Checklist

- [ ] `gatewayClient.ts` exports only functions using `fetch` with `method: 'GET'`. Any PR adding `POST`/`PUT`/`DELETE` to this file must be rejected.
- [ ] Backend has no route that proxies to `/hooks/agent`, `/v1/chat/completions`, or any gateway write endpoint.
- [ ] Gateway auth credentials (`hookToken`, `agentSecret`) are read from `config.ts` (env vars) and never passed to the frontend in any API response.
- [ ] `/api/config/export` explicitly excludes all secret fields (tokens, keys, hashes).
- [ ] Setup test endpoints (`/api/setup/vm/test`) are rate-limited and require authentication.

### JWT Security

- JWT secret: minimum 32 hex characters (64 characters of random hex), validated on startup.
- Token stored as `HttpOnly; Secure; SameSite=Strict` cookie — inaccessible to JavaScript.
- `SameSite=Lax` fallback on non-HTTPS deployments with a console warning.
- No token stored in `localStorage` or `sessionStorage`.
- SSE endpoint accepts token via `?token=` query param only because `EventSource` API cannot set custom headers. This query param is validated the same way as the cookie.

### Secret Storage

- All secrets (hookTokens, agentSecrets, SSH keys, JWT secret, bcrypt hash) live in the backend's `.env` file or Docker volume mounts.
- Secrets are never logged, never included in error responses, and never sent to the frontend.
- Blueprint PAT token and SSH key path are backend-only config; they are redacted in `/api/config/export`.

### CORS Configuration

```typescript
// Production CORS: only allow the configured frontend URL
const allowedOrigins = [cfg.frontendUrl];
// Development: also allow localhost variants
if (cfg.nodeEnv !== 'production') {
  allowedOrigins.push('http://localhost:3000', 'http://127.0.0.1:3000');
}
```

### Rate Limiting

- Login: 5 attempts per minute per IP, 5-minute lockout. Implemented via `express-rate-limit`.
- Setup test endpoints: 10 requests per minute per IP (prevent subnet scanning abuse).
- All other endpoints: 120 requests per minute per IP (general abuse protection).

### Content Security Policy

CSP headers set via `helmet` (see `index.ts` above):
- `defaultSrc: 'self'` — no inline scripts.
- `connectSrc: 'self'` — SSE connection to same origin only.
- `imgSrc: 'self' data:` — avatars, SVGs.
- No `unsafe-eval` or `unsafe-inline` in script directives.

---

## 9. Performance Requirements

### Page Load

- Initial page load (authenticated, cached data): **< 3 seconds** (LCP) on a 10Mbps connection.
- Subsequent navigation (client-side routing): **< 500ms**.
- Lighthouse performance score target: **≥ 90** on desktop.

### SSE Latency

- Agent status change → SSE event received by frontend: **< 2 seconds** (bounded by `AGENT_POLL_INTERVAL`).
- New notification → toast visible: **< 500ms** after SSE event received.

### Bundle Size Targets

| Bundle | Target (gzip) |
|--------|---------------|
| Initial JS (layout + common) | < 150 KB |
| Per-page JS (largest page) | < 100 KB |
| React Flow chunk | < 80 KB |
| Recharts chunk | < 60 KB |
| Total initial load | < 300 KB |

Use `next/dynamic` to lazy-load React Flow (Pipeline page only) and Recharts (QA/Operations pages only):

```typescript
const PipelineCanvas = dynamic(() => import('@/components/pipeline/PipelineCanvas'), { ssr: false });
const BurndownChart = dynamic(() => import('@/components/project/BurndownChart'), { ssr: false });
```

### Gateway Poll Interval Tuning

| Setting | Use case |
|---------|----------|
| 5s | Active debugging / demoing |
| 10s | Normal operation (default) |
| 30s | Low-priority monitoring, many VMs |
| 60s | Minimal load when not actively monitoring |

Configurable in the Setup wizard (Step 1 → Advanced Settings) and via `AGENT_POLL_INTERVAL` env var. UI shows "Last refreshed: Xs ago" counter in the header.

### Caching Strategy

- **Backend in-memory cache** (`stateCache.ts`): Agent state snapshots, TTL determined by poll interval. No external Redis required for v1.0.
- **Blueprint file cache**: Files read from local Git clone on disk — no additional caching layer needed.
- **Frontend**: Next.js default caching applies to static assets. API calls are not cached (always fresh via `credentials: 'include'` fetch).
- **SSE connection**: Delivers delta events; no full-state polling from frontend after initial load.

---

## 10. Integration Points with GateForge

### 10.1 Reading from OpenClaw Gateways (VM-1 through VM-5)

Each VM exposes an OpenClaw gateway at `http://<ip>:18789`. The portal backend polls these using two-layer authentication:

```
Request headers:
  X-Hook-Token: <vm.hookToken>      # Transport auth — verifies request came from a known caller
  X-Agent-Secret: <vm.agentSecret>  # Identity auth — verifies caller is the registered portal
```

**Failure modes:**
- VM unreachable (TCP timeout): mark all agents on that VM as `offline`; emit `system.health` error event.
- HTTP 401/403: log a security warning; mark VM gateway status as `error`; do not retry with different credentials.
- HTTP 5xx: mark gateway as `error`; retry on next poll cycle.
- One VM failure has no effect on others (parallel polling via `Promise.allSettled`).

**Graceful degradation:**
- The frontend renders agent cards with `status: 'offline'` instead of crashing.
- The dashboard shows "Last refreshed: X minutes ago" to indicate staleness.
- Setup page health check immediately shows which VMs are unreachable.

### 10.2 Reading from the Blueprint Git Repository

**Startup:**
1. Check if `/data/blueprint-clone/.git` exists.
2. If yes: `git pull` to get latest.
3. If no: `git clone --depth 1 --branch main <repoUrl> /data/blueprint-clone`.

**Authentication:**
- SSH key: set `GIT_SSH_COMMAND` environment variable pointing to key path.
- PAT token: embed in HTTPS URL: `https://PAT_TOKEN@github.com/owner/repo.git`.

**Auto-pull:**
- `setInterval(() => git.pull(), cfg.blueprintPullInterval * 1000)`.
- Failed pull logged but does not crash the service — portal continues serving last known state.

**On Blueprint commit detected:**
- After pull, compare latest commit SHA to previous SHA.
- If changed, emit `blueprint.commit` SSE event with files changed list.

### 10.3 Monitoring Telegram (Read-Only)

The portal uses the Telegram Bot API in polling mode (no webhook) to read messages in Tony ↔ Architect conversations:

```typescript
// telegramMonitor.ts — simplified polling loop
const BASE = 'https://api.telegram.org';
let updateOffset = 0;

async function pollTelegram() {
  const res = await fetch(`${BASE}/bot${botToken}/getUpdates?offset=${updateOffset}&timeout=10`);
  const data = await res.json();
  for (const update of data.result || []) {
    updateOffset = update.update_id + 1;
    const msg = update.message;
    if (msg && String(msg.chat.id) === cfg.telegramChatId) {
      // Emit as an INFO notification
      emitEvent({ type: 'notification.new', timestamp: new Date().toISOString(), notification: { ... } });
    }
  }
}
```

The portal never sends messages to Telegram. `telegramMonitor.ts` uses only `getUpdates` — no `sendMessage`, `sendDocument`, or any write API.

### 10.4 Probing the US VM

The US VM (Tailscale address) is health-probed via:

1. **SSH probe**: `ssh -i /data/ssh-keys/usvam_rsa ubuntu@<tailscale-addr> "echo ok"` — verifies Tailscale connectivity and SSH access. Timeout: 8 seconds.
2. **HTTP health check per environment**: HTTP GET to each environment's health URL (Dev/UAT/Prod). Returns latency and HTTP status.

The portal never executes any command other than `echo ok` via SSH. The SSH key must be stored as read-only in the Docker volume (`/data/ssh-keys:ro`).

### 10.5 Authentication Flow for Each External System

| System | Auth Method | Where Credentials Live |
|--------|-------------|------------------------|
| OpenClaw Gateways | `X-Hook-Token` + `X-Agent-Secret` headers | `GATEFORGE_VMS` JSON in `.env` (never in frontend) |
| Blueprint Git | SSH private key or PAT token | `/data/ssh-keys/blueprint_rsa` volume mount or `BLUEPRINT_PAT_TOKEN` env var |
| Telegram Bot | Bot token | `TELEGRAM_BOT_TOKEN` env var |
| US VM SSH | SSH private key | `/data/ssh-keys/usvam_rsa` volume mount |
| Portal Admin | bcrypt password → JWT cookie | `ADMIN_PASSWORD_HASH` env var → HttpOnly cookie |

---

## 11. Appendix: Status Color Constants

**`src/lib/constants.ts`** (frontend) — TypeScript constants for all status values:

```typescript
import { AgentStatus, NotificationPriority, TaskStatus, TaskPriority,
         PhaseStatus, GateDecision, GateType, DocumentStatus,
         HealthStatus, DeploymentEnvironment, SLOBudgetStatus,
         DefectSeverity, PipelinePhaseName, MoSCoW } from '@/types';

// ─── Agent Status ─────────────────────────────────────────────────────────────
export const AGENT_STATUS_COLORS: Record<AgentStatus, { hex: string; bg: string; label: string; animation: string }> = {
  active:  { hex: '#22c55e', bg: '#f0fdf4', label: 'WORKING', animation: 'animate-ping'       },
  idle:    { hex: '#94a3b8', bg: '#f8fafc', label: 'IDLE',    animation: ''                    },
  blocked: { hex: '#f97316', bg: '#fff7ed', label: 'BLOCKED', animation: 'animate-slow-blink'  },
  error:   { hex: '#ef4444', bg: '#fef2f2', label: 'ERROR',   animation: 'animate-fast-blink'  },
  offline: { hex: '#6b7280', bg: '#f9fafb', label: 'OFFLINE', animation: ''                    },
};

// Dark mode overrides: same hex values (all pass WCAG AA on dark backgrounds)
export const AGENT_STATUS_COLORS_DARK = AGENT_STATUS_COLORS; // hex values work in both modes

// ─── Notification Priority ────────────────────────────────────────────────────
export const NOTIFICATION_COLORS: Record<NotificationPriority, { border: string; bg: string; bgDark: string; icon: string; label: string }> = {
  CRITICAL:  { border: '#dc2626', bg: '#fef2f2', bgDark: 'rgba(220,38,38,0.08)',   icon: '⚠',  label: 'CRITICAL'  },
  BLOCKED:   { border: '#ea580c', bg: '#fff7ed', bgDark: 'rgba(234,88,12,0.08)',    icon: '⛔', label: 'BLOCKED'   },
  DISPUTE:   { border: '#ca8a04', bg: '#fefce8', bgDark: 'rgba(202,138,4,0.08)',    icon: '⚡', label: 'DISPUTE'   },
  COMPLETED: { border: '#16a34a', bg: '#f0fdf4', bgDark: 'rgba(22,163,74,0.08)',    icon: '✓',  label: 'COMPLETED' },
  INFO:      { border: '#6b7280', bg: '#f9fafb', bgDark: 'rgba(107,114,128,0.08)',  icon: 'ℹ',  label: 'INFO'      },
};

// ─── Task Status ──────────────────────────────────────────────────────────────
export const TASK_STATUS_COLORS: Record<TaskStatus, { hex: string; label: string }> = {
  backlog:     { hex: '#6b7280', label: 'Backlog'     },
  ready:       { hex: '#3b82f6', label: 'Ready'       },
  'in-progress':{ hex: '#2563eb', label: 'In Progress' },
  'in-review': { hex: '#7c3aed', label: 'In Review'   },
  done:        { hex: '#16a34a', label: 'Done'        },
  blocked:     { hex: '#dc2626', label: 'Blocked'     },
};

// ─── Task Priority ────────────────────────────────────────────────────────────
export const TASK_PRIORITY_COLORS: Record<TaskPriority, { hex: string; label: string; icon: string }> = {
  P0: { hex: '#dc2626', label: 'Critical', icon: '‼' },
  P1: { hex: '#ea580c', label: 'High',     icon: '!' },
  P2: { hex: '#ca8a04', label: 'Medium',   icon: '—' },
  P3: { hex: '#6b7280', label: 'Low',      icon: '↓' },
};

// ─── MoSCoW ───────────────────────────────────────────────────────────────────
export const MOSCOW_COLORS: Record<MoSCoW, { hex: string }> = {
  Must:   { hex: '#dc2626' },
  Should: { hex: '#ea580c' },
  Could:  { hex: '#3b82f6' },
  "Won't":{ hex: '#6b7280' },
};

// ─── Pipeline Phase Colors ─────────────────────────────────────────────────────
export const PHASE_COLORS: Record<PipelinePhaseName, string> = {
  Requirements: '#6b7280',
  Architecture: '#3b82f6',
  Development:  '#4f46e5',
  QA:           '#7c3aed',
  Deployment:   '#0d9488',
  Iteration:    '#ca8a04',
};

export const PHASE_STATUS_LABELS: Record<PhaseStatus, string> = {
  'not-started': 'Not Started',
  'in-progress': 'In Progress',
  completed:     'Completed',
  blocked:       'Blocked',
};

// ─── Quality Gate Decision ────────────────────────────────────────────────────
export const GATE_DECISION_COLORS: Record<GateDecision, { hex: string; bg: string; icon: string }> = {
  PROMOTE:  { hex: '#16a34a', bg: '#f0fdf4', icon: '▲' },
  HOLD:     { hex: '#ea580c', bg: '#fff7ed', icon: '⏸' },
  ROLLBACK: { hex: '#dc2626', bg: '#fef2f2', icon: '◀' },
};

export const GATE_TYPE_COLORS: Record<GateType, { hex: string; label: string }> = {
  design:  { hex: '#3b82f6', label: 'Design Gate'  },
  code:    { hex: '#4f46e5', label: 'Code Gate'    },
  qa:      { hex: '#7c3aed', label: 'QA Gate'      },
  release: { hex: '#0d9488', label: 'Release Gate' },
};

// ─── Document Status ──────────────────────────────────────────────────────────
export const DOCUMENT_STATUS_COLORS: Record<DocumentStatus, { hex: string; label: string }> = {
  draft:      { hex: '#6b7280', label: 'Draft'      },
  'in-review':{ hex: '#3b82f6', label: 'In Review'  },
  approved:   { hex: '#16a34a', label: 'Approved'   },
  deprecated: { hex: '#dc2626', label: 'Deprecated' },
};

// ─── Project Health ───────────────────────────────────────────────────────────
export const HEALTH_STATUS_COLORS: Record<HealthStatus, { hex: string; label: string; icon: string }> = {
  green:  { hex: '#16a34a', label: 'On Track', icon: '🟢' },
  yellow: { hex: '#ca8a04', label: 'At Risk',  icon: '🟡' },
  red:    { hex: '#dc2626', label: 'Blocked',  icon: '🔴' },
};

// ─── Deployment Environment ───────────────────────────────────────────────────
export const ENV_COLORS: Record<DeploymentEnvironment, { hex: string; label: string }> = {
  dev:        { hex: '#6b7280', label: 'Dev'        },
  uat:        { hex: '#3b82f6', label: 'UAT'        },
  production: { hex: '#16a34a', label: 'Production' },
};

// ─── SLO Error Budget ─────────────────────────────────────────────────────────
export const SLO_BUDGET_COLORS: Record<SLOBudgetStatus, { hex: string; animation: string }> = {
  healthy:   { hex: '#16a34a', animation: ''                   },
  warning:   { hex: '#ca8a04', animation: ''                   },
  critical:  { hex: '#dc2626', animation: 'animate-pulse'      },
  exhausted: { hex: '#991b1b', animation: 'animate-fast-blink' },
};

// ─── Defect Severity ──────────────────────────────────────────────────────────
export const DEFECT_SEVERITY_COLORS: Record<DefectSeverity, { hex: string; label: string }> = {
  Critical: { hex: '#dc2626', label: 'Critical (P0)' },
  Major:    { hex: '#ea580c', label: 'Major (P1)'    },
  Minor:    { hex: '#ca8a04', label: 'Minor (P2)'    },
  Cosmetic: { hex: '#6b7280', label: 'Cosmetic (P3)' },
};

// ─── Lobster Retry ────────────────────────────────────────────────────────────
export const RETRY_COLORS = {
  1: '#ca8a04',  // Yellow
  2: '#ea580c',  // Orange
  3: '#dc2626',  // Red (escalate)
} as const;

// ─── Sidebar nav keyboard shortcuts ──────────────────────────────────────────
export const NAV_SHORTCUTS: Record<string, string> = {
  '/':              'g+a',
  '/pipeline':      'g+p',
  '/blueprint':     'g+b',
  '/project':       'g+r',
  '/qa':            'g+q',
  '/operations':    'g+o',
  '/notifications': 'g+n',
  '/setup':         'g+s',
};
```

---

## 12. Appendix: Mock Data

Sample JSON payloads for frontend development without a live backend.

### 12.1 Agent List (`GET /api/agents`)

```json
{
  "ok": true,
  "data": [
    {
      "vmId": "vm-1",
      "agentId": "architect",
      "displayId": "architect@VM-1",
      "role": "System Architect",
      "model": "claude-opus-4.6",
      "status": "active",
      "currentTaskId": "FEAT-042",
      "currentTaskTitle": "Resolve module boundary dispute between auth-service and user-service",
      "latestOutputSnippet": "The proposed split between auth-service and user-service introduces a circular dependency. I recommend consolidating the user-token model into auth-service and exposing a read-only user profile endpoint…",
      "lastActivityAt": "2026-04-07T14:23:37Z",
      "activeNotificationPriority": "CRITICAL",
      "isHub": true
    },
    {
      "vmId": "vm-2",
      "agentId": "designer",
      "displayId": "designer@VM-2",
      "role": "System Designer",
      "model": "claude-sonnet-4.6",
      "status": "idle",
      "currentTaskId": "TASK-028",
      "currentTaskTitle": "Design Redis topology for session management",
      "latestOutputSnippet": "Redis Sentinel with 1 primary + 2 replicas recommended. Failover time < 30s. Session TTL: 24h.",
      "lastActivityAt": "2026-04-07T14:18:11Z",
      "isHub": false
    },
    {
      "vmId": "vm-3",
      "agentId": "dev-01",
      "displayId": "dev-01@VM-3",
      "role": "Developers",
      "model": "claude-sonnet-4.6",
      "status": "active",
      "currentTaskId": "FEAT-038",
      "currentTaskTitle": "Implement JWT refresh token rotation",
      "latestOutputSnippet": "Implementing the rotation strategy: new access token (15m) + refresh token (7d). Storing refresh token hash in Redis with user binding…",
      "lastActivityAt": "2026-04-07T14:23:44Z",
      "isHub": false
    },
    {
      "vmId": "vm-3",
      "agentId": "dev-02",
      "displayId": "dev-02@VM-3",
      "role": "Developers",
      "model": "claude-sonnet-4.6",
      "status": "blocked",
      "currentTaskId": "FEAT-041",
      "currentTaskTitle": "Implement payment gateway integration",
      "latestOutputSnippet": "Blocked: FR-055 specifies both Stripe and PayPal but architecture.md only includes Stripe. Query filed in QUERY-009.md.",
      "lastActivityAt": "2026-04-07T13:55:22Z",
      "activeNotificationPriority": "BLOCKED",
      "isHub": false
    },
    {
      "vmId": "vm-4",
      "agentId": "qc-01",
      "displayId": "qc-01@VM-4",
      "role": "QC Agents",
      "model": "minimax-2.7",
      "status": "active",
      "currentTaskId": "QC-TASK-019",
      "currentTaskTitle": "Integration test suite for auth-service module",
      "latestOutputSnippet": "Running 47 integration tests. Auth endpoints: 43 passed, 4 failed. Failures in /api/auth/refresh — token rotation not yet implemented by dev-01.",
      "lastActivityAt": "2026-04-07T14:22:01Z",
      "isHub": false
    },
    {
      "vmId": "vm-4",
      "agentId": "qc-02",
      "displayId": "qc-02@VM-4",
      "role": "QC Agents",
      "model": "minimax-2.7",
      "status": "idle",
      "currentTaskId": null,
      "currentTaskTitle": null,
      "latestOutputSnippet": "Completed E2E test cases for user registration flow. All 12 scenarios documented in qa/test-cases/TC-user-reg-e2e.md.",
      "lastActivityAt": "2026-04-07T13:41:09Z",
      "isHub": false
    },
    {
      "vmId": "vm-5",
      "agentId": "operator",
      "displayId": "operator@VM-5",
      "role": "Operator",
      "model": "minimax-2.7",
      "status": "idle",
      "currentTaskId": "OPS-007",
      "currentTaskTitle": "Prepare Dev environment deployment runbook",
      "latestOutputSnippet": "Runbook drafted. Docker Compose manifest validated. GitHub Actions CI pipeline configured. Awaiting QA gate PROMOTE decision before Dev deploy.",
      "lastActivityAt": "2026-04-07T13:30:55Z",
      "isHub": false
    }
  ]
}
```

### 12.2 Pipeline Current State (`GET /api/pipeline/current`)

```json
{
  "ok": true,
  "data": {
    "iterationId": "iter-003",
    "iterationName": "Iteration 3 — Core Authentication & Session Management",
    "startedAt": "2026-03-28T09:00:00Z",
    "phases": [
      {
        "id": "phase-1",
        "name": "Requirements & Feasibility",
        "number": 1,
        "status": "completed",
        "startedAt": "2026-03-28T09:00:00Z",
        "completedAt": "2026-03-29T15:30:00Z",
        "taskCounts": { "passed": 12, "working": 0, "pending": 0, "blocked": 0 },
        "gateDecision": "PROMOTE",
        "assignedVm": "vm-1"
      },
      {
        "id": "phase-2",
        "name": "Architecture & Infrastructure Design",
        "number": 2,
        "status": "completed",
        "startedAt": "2026-03-29T16:00:00Z",
        "completedAt": "2026-03-31T11:00:00Z",
        "taskCounts": { "passed": 8, "working": 0, "pending": 0, "blocked": 0 },
        "gateDecision": "PROMOTE",
        "assignedVm": "vm-2"
      },
      {
        "id": "phase-3",
        "name": "Development",
        "number": 3,
        "status": "in-progress",
        "startedAt": "2026-04-01T09:00:00Z",
        "completedAt": null,
        "taskCounts": { "passed": 6, "working": 4, "pending": 7, "blocked": 1 },
        "gateDecision": null,
        "assignedVm": "vm-3"
      },
      {
        "id": "phase-4",
        "name": "Quality Assurance",
        "number": 4,
        "status": "not-started",
        "startedAt": null,
        "completedAt": null,
        "taskCounts": { "passed": 0, "working": 0, "pending": 0, "blocked": 0 },
        "gateDecision": null,
        "assignedVm": "vm-4"
      },
      {
        "id": "phase-5",
        "name": "Deployment & Release",
        "number": 5,
        "status": "not-started",
        "startedAt": null,
        "completedAt": null,
        "taskCounts": { "passed": 0, "working": 0, "pending": 0, "blocked": 0 },
        "gateDecision": null,
        "assignedVm": "vm-5"
      },
      {
        "id": "phase-6",
        "name": "Iteration",
        "number": 6,
        "status": "not-started",
        "startedAt": null,
        "completedAt": null,
        "taskCounts": { "passed": 0, "working": 0, "pending": 0, "blocked": 0 },
        "gateDecision": null,
        "assignedVm": "vm-1"
      }
    ]
  }
}
```

### 12.3 Notification Feed (`GET /api/notifications?limit=3`)

```json
{
  "ok": true,
  "data": {
    "total": 47,
    "page": 1,
    "notifications": [
      {
        "id": "notif-089",
        "priority": "BLOCKED",
        "vmId": "vm-3",
        "agentId": "dev-02",
        "displayId": "dev-02@VM-3",
        "message": "[BLOCKED] FEAT-041 — payment gateway integration blocked. FR-055 specifies both Stripe and PayPal but architecture.md only defines Stripe adapter. See QUERY-009.md for options analysis.",
        "taskId": "FEAT-041",
        "gitRef": "abc12d4",
        "phase": "Development",
        "timestamp": "2026-04-07T13:55:22Z",
        "acknowledged": false
      },
      {
        "id": "notif-088",
        "priority": "COMPLETED",
        "vmId": "vm-4",
        "agentId": "qc-02",
        "displayId": "qc-02@VM-4",
        "message": "[COMPLETED] QC-TASK-018 — E2E test cases for user registration flow completed. 12 scenarios in qa/test-cases/TC-user-reg-e2e.md. Ready for test execution when FEAT-039 is done.",
        "taskId": "QC-TASK-018",
        "gitRef": "f3a9b1c",
        "phase": "QA",
        "timestamp": "2026-04-07T13:41:09Z",
        "acknowledged": false
      },
      {
        "id": "notif-087",
        "priority": "INFO",
        "vmId": "vm-3",
        "agentId": "dev-01",
        "displayId": "dev-01@VM-3",
        "message": "[INFO] FEAT-038 — JWT refresh token rotation implementation 60% complete. Access token (15m TTL) and Redis session storage done. Rotation logic and cleanup job remaining.",
        "taskId": "FEAT-038",
        "gitRef": "d2c5e8f",
        "phase": "Development",
        "timestamp": "2026-04-07T13:22:44Z",
        "acknowledged": true
      }
    ]
  }
}
```

### 12.4 QA Coverage (`GET /api/qa/coverage`)

```json
{
  "ok": true,
  "data": {
    "lastUpdated": "2026-04-07T12:00:00Z",
    "thresholds": {
      "unit": 95,
      "integration": 90,
      "e2e": 85,
      "criticalFailure": 70
    },
    "modules": [
      {
        "module": "auth-service",
        "unit": 97.2,
        "integration": 91.5,
        "e2e": 88.0,
        "gateDecision": "PROMOTE"
      },
      {
        "module": "user-service",
        "unit": 93.1,
        "integration": 87.3,
        "e2e": 79.5,
        "gateDecision": "HOLD"
      },
      {
        "module": "notification-service",
        "unit": 61.4,
        "integration": 55.0,
        "e2e": 40.0,
        "gateDecision": "ROLLBACK"
      }
    ]
  }
}
```

### 12.5 Operations Deployments (`GET /api/ops/deployments`)

```json
{
  "ok": true,
  "data": {
    "environments": [
      {
        "env": "dev",
        "label": "Development",
        "status": "healthy",
        "version": "iter-003-build-014",
        "lastDeployedAt": "2026-04-05T10:00:00Z",
        "url": "http://dev.app.internal",
        "healthEndpoint": "http://dev.app.internal/health",
        "latencyMs": 23
      },
      {
        "env": "uat",
        "label": "UAT",
        "status": "degraded",
        "version": "iter-002-build-009",
        "lastDeployedAt": "2026-03-28T16:00:00Z",
        "url": "http://uat.app.internal",
        "healthEndpoint": "http://uat.app.internal/health",
        "latencyMs": 312
      },
      {
        "env": "production",
        "label": "Production",
        "status": "healthy",
        "version": "iter-001-build-004",
        "lastDeployedAt": "2026-03-15T12:00:00Z",
        "url": "https://app.gateforge.io",
        "healthEndpoint": "https://app.gateforge.io/health",
        "latencyMs": 18
      }
    ],
    "slos": [
      {
        "id": "slo-availability",
        "name": "Availability",
        "target": 99.9,
        "current": 99.95,
        "errorBudgetRemaining": 87.3,
        "budgetStatus": "healthy"
      },
      {
        "id": "slo-latency-p95",
        "name": "Latency p95 < 500ms",
        "target": 95.0,
        "current": 96.2,
        "errorBudgetRemaining": 62.1,
        "budgetStatus": "warning"
      },
      {
        "id": "slo-error-rate",
        "name": "Error Rate < 1%",
        "target": 99.0,
        "current": 99.3,
        "errorBudgetRemaining": 43.0,
        "budgetStatus": "warning"
      }
    ]
  }
}
```

### 12.6 SSE Event Examples

These are the raw event lines sent by the backend's `/api/events` SSE stream:

```
event: agent.status
data: {"vmId":"vm-3","agentId":"dev-02","status":"blocked","lastActivity":"2026-04-07T13:55:22Z"}

event: notification.new
data: {"id":"notif-089","priority":"BLOCKED","vmId":"vm-3","agentId":"dev-02","message":"[BLOCKED] FEAT-041 ...","timestamp":"2026-04-07T13:55:22Z"}

event: pipeline.update
data: {"iterationId":"iter-003","phaseId":"phase-3","phaseStatus":"in-progress","taskCounts":{"passed":6,"working":4,"pending":7,"blocked":1}}

event: qa.gateUpdate
data: {"module":"user-service","gate":"QA Gate","decision":"HOLD","timestamp":"2026-04-07T12:00:00Z"}

event: ops.sloAlert
data: {"sloId":"slo-latency-p95","burnRate":2.4,"budgetRemaining":43.0,"alertLevel":"warning"}

event: blueprint.commit
data: {"sha":"f3a9b1c","message":"docs: add QUERY-009 payment gateway options","author":"qc-02","files":["project/queries/QUERY-009.md"],"timestamp":"2026-04-07T13:41:09Z"}

event: system.health
data: {"vmId":"vm-4","status":"warning","latency":187}

event: ping
data: {"ts":"2026-04-07T14:30:00Z"}
```

---

*GateForge Admin Portal — Implementation Guide v1.0*  
*Author: GateForge Agent Team | Generated: 2026-04-07*  
*Status: Implementation-Ready — Approved for development*

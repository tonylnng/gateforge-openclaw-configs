#!/usr/bin/env bash
# =============================================================================
# GateForge — Shared Setup Functions
# =============================================================================
# Sourced by all VM-specific setup scripts.
# Do NOT run this file directly.
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Version & Constants
# ---------------------------------------------------------------------------
GATEFORGE_VERSION="2.0.0"
OPENCLAW_PORT=18789
CONFIG_FILE="/opt/secrets/gateforge.env"
OPENCLAW_CONFIG_DIR="$HOME/.openclaw"

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
TEAL='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ---------------------------------------------------------------------------
# Globals
# ---------------------------------------------------------------------------
DRY_RUN="${DRY_RUN:-false}"
TOTAL_STEPS="${TOTAL_STEPS:-6}"
CURRENT_STEP=0

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------
print_banner() {
  echo ""
  echo -e "${TEAL}${BOLD}"
  cat << 'BANNER'
   ██████╗  █████╗ ████████╗███████╗███████╗ ██████╗ ██████╗  ██████╗ ███████╗
  ██╔════╝ ██╔══██╗╚══██╔══╝██╔════╝██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
  ██║  ███╗███████║   ██║   █████╗  █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
  ██║   ██║██╔══██║   ██║   ██╔══╝  ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
  ╚██████╔╝██║  ██║   ██║   ███████╗██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
   ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
BANNER
  echo -e "${RESET}"
  echo -e "  ${DIM}Multi-Agent SDLC Pipeline — Communication Setup v${GATEFORGE_VERSION}${RESET}"
  echo -e "  ${DIM}Assumes OpenClaw is already installed with API keys configured.${RESET}"
  echo ""
}

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
print_step() {
  CURRENT_STEP=$((CURRENT_STEP + 1))
  echo ""
  echo -e "${TEAL}${BOLD}[${CURRENT_STEP}/${TOTAL_STEPS}] $1${RESET}"
  echo -e "${TEAL}$(printf '%.0s─' {1..60})${RESET}"
}

print_success() { echo -e "  ${GREEN}✓${RESET} $1"; }
print_error()   { echo -e "  ${RED}✗${RESET} $1"; }
print_warn()    { echo -e "  ${YELLOW}!${RESET} $1"; }
print_info()    { echo -e "  ${BLUE}→${RESET} $1"; }

# ---------------------------------------------------------------------------
# Input helpers
# ---------------------------------------------------------------------------
prompt_required() {
  local var_name="$1"
  local prompt_text="$2"
  local default="${3:-}"
  local value=""

  while [[ -z "$value" ]]; do
    if [[ -n "$default" ]]; then
      echo -en "  ${BOLD}${prompt_text}${RESET} [${DIM}${default}${RESET}]: "
      read -r value
      value="${value:-$default}"
    else
      echo -en "  ${BOLD}${prompt_text}${RESET}: "
      read -r value
    fi
    if [[ -z "$value" ]]; then
      print_error "This field is required."
    fi
  done

  eval "$var_name='$value'"
}

prompt_secret() {
  local var_name="$1"
  local prompt_text="$2"
  local default="${3:-}"
  local value=""

  while [[ -z "$value" ]]; do
    if [[ -n "$default" ]]; then
      echo -en "  ${BOLD}${prompt_text}${RESET} [${DIM}press Enter to auto-generate${RESET}]: "
    else
      echo -en "  ${BOLD}${prompt_text}${RESET}: "
    fi
    read -rs value
    echo ""
    if [[ -z "$value" && -n "$default" ]]; then
      value="$default"
      print_info "Auto-generated: ${value:0:8}...${value: -4}"
    elif [[ -z "$value" ]]; then
      print_error "This field is required."
    fi
  done

  eval "$var_name='$value'"
}

prompt_choice() {
  local var_name="$1"
  local prompt_text="$2"
  shift 2
  local options=("$@")
  local value=""

  echo -e "  ${BOLD}${prompt_text}${RESET}"
  for i in "${!options[@]}"; do
    echo -e "    ${TEAL}$((i+1)))${RESET} ${options[$i]}"
  done

  while [[ -z "$value" ]]; do
    echo -en "  ${BOLD}Choose [1-${#options[@]}]${RESET}: "
    read -r choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
      value="${options[$((choice-1))]}"
    else
      print_error "Invalid choice."
    fi
  done

  eval "$var_name='$value'"
}

confirm_continue() {
  echo ""
  echo -en "  ${BOLD}$1${RESET} [Y/n]: "
  read -r answer
  if [[ "${answer,,}" == "n" ]]; then
    echo -e "  ${YELLOW}Aborted.${RESET}"
    exit 0
  fi
}

# ---------------------------------------------------------------------------
# Secret generation
# ---------------------------------------------------------------------------
generate_secret() {
  openssl rand -hex 32
}

# ---------------------------------------------------------------------------
# Config file management
# ---------------------------------------------------------------------------
write_config() {
  local config_content="$1"

  if [[ "$DRY_RUN" == "true" ]]; then
    print_warn "[DRY RUN] Would write to ${CONFIG_FILE}:"
    echo "$config_content" | sed 's/^/    /'
    return
  fi

  sudo mkdir -p "$(dirname "$CONFIG_FILE")"
  echo "$config_content" | sudo tee "$CONFIG_FILE" > /dev/null
  sudo chown root:root "$CONFIG_FILE"
  sudo chmod 600 "$CONFIG_FILE"
  print_success "Config written to ${CONFIG_FILE} (root:root, 600)"

  # Grant read access to the OpenClaw user via ACL
  # The file is root:root 600 so the non-root OpenClaw user can't read it otherwise
  local oc_user="${SUDO_USER:-$(whoami)}"
  if [[ "$oc_user" != "root" ]] && command -v setfacl &>/dev/null; then
    sudo setfacl -m "u:${oc_user}:r" "$CONFIG_FILE"
    print_success "ACL read access granted to user '${oc_user}'"
  elif [[ "$oc_user" != "root" ]]; then
    print_warn "setfacl not found — install acl package: sudo apt-get install acl"
    print_warn "Then run: sudo setfacl -m u:${oc_user}:r ${CONFIG_FILE}"
  fi
}

load_existing_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    print_info "Found existing config at ${CONFIG_FILE}"
    # Source it to pre-fill values (sudo needed)
    eval "$(sudo cat "$CONFIG_FILE" 2>/dev/null | grep -v '^#' | grep '=')" 2>/dev/null || true
    return 0
  fi
  return 1
}

# ---------------------------------------------------------------------------
# Copy config MD files
# ---------------------------------------------------------------------------
copy_config_files() {
  local vm_dir="$1"

  if [[ "$DRY_RUN" == "true" ]]; then
    print_warn "[DRY RUN] Would copy files from ${vm_dir} to ${OPENCLAW_CONFIG_DIR}"
    return
  fi

  mkdir -p "$OPENCLAW_CONFIG_DIR"

  for f in SOUL.md AGENTS.md USER.md TOOLS.md; do
    if [[ -f "${vm_dir}/${f}" ]]; then
      cp "${vm_dir}/${f}" "${OPENCLAW_CONFIG_DIR}/${f}"
      print_success "Copied ${f}"
    fi
  done

  # Copy guideline docs
  for f in BLUEPRINT-GUIDE.md RESILIENCE-SECURITY-GUIDE.md DEVELOPMENT-GUIDE.md QA-FRAMEWORK.md MONITORING-OPERATIONS-GUIDE.md; do
    if [[ -f "${vm_dir}/${f}" ]]; then
      cp "${vm_dir}/${f}" "${OPENCLAW_CONFIG_DIR}/${f}"
      print_success "Copied ${f}"
    fi
  done
}

# ---------------------------------------------------------------------------
# Per-agent SOUL.md generation (for VM-3 and VM-4)
# ---------------------------------------------------------------------------
generate_agent_souls() {
  local vm_dir="$1"
  local prefix="$2"      # "dev" or "qc"
  local count="$3"
  local role_desc="$4"   # "Developer" or "QC Tester"

  if [[ "$DRY_RUN" == "true" ]]; then
    print_warn "[DRY RUN] Would generate ${count} per-agent SOUL.md files"
    return
  fi

  for i in $(seq -f "%02g" 1 "$count"); do
    local agent_id="${prefix}-${i}"
    local agent_dir="${OPENCLAW_CONFIG_DIR}/${agent_id}"
    mkdir -p "$agent_dir"

    # Copy from template if exists, otherwise generate
    if [[ -f "${vm_dir}/${prefix}-01/SOUL.md" ]]; then
      sed "s/${prefix}-01/${agent_id}/g" "${vm_dir}/${prefix}-01/SOUL.md" > "${agent_dir}/SOUL.md"
    else
      cat > "${agent_dir}/SOUL.md" << EOF
# ${role_desc} Agent — ${agent_id}

> GateForge Multi-Agent SDLC Pipeline — ${agent_id} (Port ${OPENCLAW_PORT})

## Identity

- **Agent ID**: ${agent_id}
- **Role**: ${role_desc}
- **Workspace**: ~/.openclaw/workspace-${agent_id}

## Behaviour

Follow the shared SOUL.md for this VM. This file defines your individual identity only.
All guidelines, tools, and communication protocols are inherited from the parent SOUL.md.
EOF
    fi
    print_success "Generated ${agent_id}/SOUL.md"
  done
}

# ---------------------------------------------------------------------------
# Enable webhooks in openclaw.json
# ---------------------------------------------------------------------------
enable_hooks() {
  local token="$1"
  local oc_user="${SUDO_USER:-$(whoami)}"
  local oc_home
  oc_home=$(eval echo "~${oc_user}")
  local oc_config="${oc_home}/.openclaw/openclaw.json"

  print_info "Enabling webhooks in ${oc_config}..."

  if [[ "$DRY_RUN" == "true" ]]; then
    print_warn "[DRY RUN] Would enable hooks in ${oc_config}"
    return
  fi

  if [[ ! -f "$oc_config" ]]; then
    print_error "OpenClaw config not found at ${oc_config}"
    print_info "Make sure OpenClaw is installed and has been started at least once."
    return 1
  fi

  # Use python3 if available (safe JSON manipulation), fall back to jq, then sed
  if command -v python3 &>/dev/null; then
    python3 -c "
import json, sys
try:
    with open('${oc_config}') as f:
        cfg = json.load(f)
    cfg['hooks'] = {
        'enabled': True,
        'token': '${token}',
        'path': '/hooks',
        'allowRequestSessionKey': True
    }
    with open('${oc_config}', 'w') as f:
        json.dump(cfg, f, indent=2)
    print('ok')
except Exception as e:
    print(f'error: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null
    if [[ $? -eq 0 ]]; then
      # Fix ownership back to the OpenClaw user
      sudo chown "${oc_user}:${oc_user}" "$oc_config" 2>/dev/null || true
      print_success "Webhooks enabled in ${oc_config}"
    else
      print_error "Failed to update ${oc_config} — check JSON syntax"
      return 1
    fi
  elif command -v jq &>/dev/null; then
    local tmp_config
    tmp_config=$(mktemp)
    jq --arg token "$token" '.hooks = {enabled: true, token: $token, path: "/hooks", allowRequestSessionKey: true}' "$oc_config" > "$tmp_config" && mv "$tmp_config" "$oc_config"
    sudo chown "${oc_user}:${oc_user}" "$oc_config" 2>/dev/null || true
    print_success "Webhooks enabled in ${oc_config}"
  else
    print_error "Neither python3 nor jq found — cannot update ${oc_config} automatically"
    echo -e "  ${DIM}Manually add to ${oc_config}:${RESET}"
    echo -e "  ${DIM}  \"hooks\": { \"enabled\": true, \"token\": \"<GATEWAY_AUTH_TOKEN>\", \"path\": \"/hooks\", \"allowRequestSessionKey\": true }${RESET}"
    return 1
  fi

  # Restart gateway to pick up new config
  print_info "Restarting OpenClaw gateway to apply hooks config..."
  if sudo -u "$oc_user" openclaw gateway restart &>/dev/null 2>&1; then
    print_success "Gateway restarted"
  elif openclaw gateway restart &>/dev/null 2>&1; then
    print_success "Gateway restarted"
  else
    print_warn "Could not restart gateway automatically. Run: openclaw gateway restart"
  fi
}

# ---------------------------------------------------------------------------
# Verification
# ---------------------------------------------------------------------------
verify_openclaw() {
  print_info "Checking OpenClaw gateway..."
  if command -v openclaw &>/dev/null; then
    print_success "OpenClaw found: $(command -v openclaw)"
  else
    print_warn "'openclaw' not found in PATH (may be installed under a different name or path — skipping check)"
  fi

  # Check gateway bind is not loopback
  local bind_check
  bind_check=$(ss -tlnp 2>/dev/null | grep ":18789" | head -1 || true)
  if echo "$bind_check" | grep -q "127\.0\.0\.1"; then
    print_error "Gateway is bound to 127.0.0.1 (loopback) — other VMs cannot reach it"
    print_info "Fix: openclaw config set gateway.bind tailnet"
    print_info "Then: openclaw gateway restart (as your OpenClaw user)"
    confirm_continue "Continue anyway?"
  elif [[ -n "$bind_check" ]]; then
    print_success "Gateway listening on port 18789 (not loopback)"
  else
    print_warn "Port 18789 not listening — gateway may not be running"
  fi
}

setup_firewall() {
  print_info "Configuring UFW firewall..."

  if ! command -v ufw &>/dev/null; then
    print_warn "UFW not installed — skipping firewall setup"
    return
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    print_warn "[DRY RUN] Would configure UFW rules for GateForge VM IPs"
    return
  fi

  # GateForge VM IPs
  local VM_IPS=("100.73.38.28" "100.95.30.11" "100.81.114.55" "100.106.117.104" "100.95.248.68")

  sudo ufw default deny incoming 2>/dev/null || true
  sudo ufw default allow outgoing 2>/dev/null || true
  sudo ufw allow ssh 2>/dev/null || true

  for ip in "${VM_IPS[@]}"; do
    sudo ufw allow from "$ip" to any port 18789 2>/dev/null || true
  done

  # Enable UFW (non-interactive)
  echo "y" | sudo ufw enable 2>/dev/null || true
  print_success "UFW configured — only GateForge VM IPs allowed on port 18789"
}

verify_connectivity() {
  local target_ip="$1"
  local target_port="$2"
  local label="$3"

  if curl -sf --max-time 3 "http://${target_ip}:${target_port}/health" &>/dev/null 2>&1; then
    print_success "${label}: reachable"
  else
    print_warn "${label}: not reachable (may not be running yet)"
  fi
}

# ---------------------------------------------------------------------------
# Summary display
# ---------------------------------------------------------------------------
print_summary_box() {
  local title="$1"
  shift
  local width=64

  echo ""
  echo -e "  ${TEAL}┌$(printf '─%.0s' $(seq 1 $width))┐${RESET}"
  echo -e "  ${TEAL}│${RESET} ${BOLD}${title}$(printf ' %.0s' $(seq 1 $((width - ${#title} - 1))))${TEAL}│${RESET}"
  echo -e "  ${TEAL}├$(printf '─%.0s' $(seq 1 $width))┤${RESET}"

  while [[ $# -gt 0 ]]; do
    local label="$1"
    local value="$2"
    shift 2
    local line="${label} ${value}"
    local padding=$((width - ${#line} - 1))
    if (( padding < 0 )); then padding=0; fi
    echo -e "  ${TEAL}│${RESET} ${DIM}${label}${RESET} ${value}$(printf ' %.0s' $(seq 1 $padding))${TEAL}│${RESET}"
  done

  echo -e "  ${TEAL}└$(printf '─%.0s' $(seq 1 $width))┘${RESET}"
  echo ""
}

mask_secret() {
  local s="$1"
  if [[ ${#s} -gt 12 ]]; then
    echo "${s:0:6}...${s: -4}"
  else
    echo "****"
  fi
}

# ---------------------------------------------------------------------------
# Flag parsing
# ---------------------------------------------------------------------------
parse_common_flags() {
  for arg in "$@"; do
    case "$arg" in
      --help|-h) return 1 ;;
      --dry-run) DRY_RUN="true"; print_warn "DRY RUN MODE — no changes will be made" ;;
    esac
  done
  return 0
}

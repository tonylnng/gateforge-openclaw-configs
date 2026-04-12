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
# Verification
# ---------------------------------------------------------------------------
verify_openclaw() {
  print_info "Checking OpenClaw gateway..."
  if command -v openclaw &>/dev/null; then
    print_success "OpenClaw found: $(command -v openclaw)"
  else
    print_warn "'openclaw' not found in PATH (may be installed under a different name or path — skipping check)"
  fi
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

#!/usr/bin/env bash
# =============================================================================
# GateForge Communication Setup — VM-5: Operator
# =============================================================================
# Assumes OpenClaw is already installed with MiniMax API key configured.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/install-common.sh"

TOTAL_STEPS=6
VM_NAME="vm5"
VM_ROLE="VM-5: Operator"
VM_DIR="${SCRIPT_DIR}/../vm-5-operator"

show_help() {
  print_banner
  echo -e "  ${BOLD}Usage:${RESET} sudo bash setup-vm5-operator.sh [--help] [--dry-run]"
  echo ""
  echo -e "  ${BOLD}VM-5: Operator${RESET} — Deployment and monitoring spoke (MiniMax 2.7)"
  echo ""
}

main() {
  if ! parse_common_flags "$@"; then
    show_help
    exit 0
  fi

  print_banner
  echo -e "  ${BOLD}Setting up: ${TEAL}${VM_ROLE}${RESET}"
  echo ""

  # --- Step 1: Verify ---
  print_step "Verify OpenClaw Installation"
  verify_openclaw
  if load_existing_config; then
    confirm_continue "Overwrite existing config?"
  fi

  # --- Step 2: Network ---
  print_step "Verify Network & Firewall"
  setup_firewall

  # --- Step 3: Collect config ---
  TOTAL_STEPS=6
  print_step "Configure Communication"

  prompt_required VM5_IP              "This VM's IP/host"          "${GATEFORGE_VM_HOST:-100.95.248.68}"
  prompt_required ARCHITECT_IP        "Architect VM IP/host"       "${ARCHITECT_IP:-100.73.38.28}"
  echo ""
  echo -e "  ${DIM}Paste these from the VM-1 Architect setup output:${RESET}"
  prompt_required GATEWAY_AUTH_TOKEN  "This VM's gateway token"    "${GATEWAY_AUTH_TOKEN:-}"
  prompt_required ARCHITECT_HOOK_TOKEN "Architect hook token"      "${ARCHITECT_HOOK_TOKEN:-}"
  prompt_required AGENT_SECRET        "This VM's HMAC secret"     "${AGENT_SECRET:-}"

  # --- Step 3: Write config ---
  print_step "Write Central Config File"

  local config_content
  config_content=$(cat << EOF
# =============================================================================
# GateForge Central Configuration — VM-5: Operator
# =============================================================================
# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
# Permissions: root:root 600 — do NOT commit to Git.
# =============================================================================

# --- This VM ---
GATEFORGE_ROLE=operator
GATEFORGE_VM_HOST=${VM5_IP}
GATEFORGE_PORT=${OPENCLAW_PORT}
GATEWAY_AUTH_TOKEN=${GATEWAY_AUTH_TOKEN}

# --- Architect Connection ---
ARCHITECT_IP=${ARCHITECT_IP}
ARCHITECT_NOTIFY_URL=http://${ARCHITECT_IP}:${OPENCLAW_PORT}/hooks/agent
ARCHITECT_HOOK_TOKEN=${ARCHITECT_HOOK_TOKEN}

# --- HMAC Signing Secret (never transmitted) ---
AGENT_SECRET=${AGENT_SECRET}
EOF
)

  write_config "$config_content"

  # --- Step 4: Copy config files ---
  print_step "Copy GateForge Config Files"
  copy_config_files "$VM_DIR"

  # --- Step 5: Enable webhooks ---
  print_step "Enable Webhooks in OpenClaw"
  enable_hooks "$GATEWAY_AUTH_TOKEN"

  # --- Step 6: Verify ---
  print_step "Verify & Summary"
  verify_connectivity "$ARCHITECT_IP" "$OPENCLAW_PORT" "Architect (${ARCHITECT_IP})"

  print_summary_box "VM-5 Operator — Configuration" \
    "Role:" "Operator (Spoke)" \
    "IP/Host:" "$VM5_IP" \
    "Config:" "$CONFIG_FILE" \
    "Architect:" "http://${ARCHITECT_IP}:${OPENCLAW_PORT}" \
    "Gateway Token:" "$(mask_secret "$GATEWAY_AUTH_TOKEN")" \
    "HMAC Secret:" "$(mask_secret "$AGENT_SECRET")"

  echo -e "  ${GREEN}${BOLD}VM-5 Operator setup complete.${RESET}"
  echo ""
}

main "$@"

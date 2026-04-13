#!/usr/bin/env bash
# =============================================================================
# GateForge Communication Setup — VM-4: QC Agents
# =============================================================================
# Assumes OpenClaw is already installed with MiniMax API key configured.
# Also asks how many QC agents to create (3, 5, or 10).
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/install-common.sh"

TOTAL_STEPS=6
VM_NAME="vm4"
VM_ROLE="VM-4: QC Agents"
VM_DIR="${SCRIPT_DIR}/../vm-4-qc-agents"

show_help() {
  print_banner
  echo -e "  ${BOLD}Usage:${RESET} sudo bash setup-vm4-qc-agents.sh [--help] [--dry-run]"
  echo ""
  echo -e "  ${BOLD}VM-4: QC Agents${RESET} — Multi-agent spoke (MiniMax 2.7)"
  echo -e "  Sets up communication + generates per-agent SOUL.md files."
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
  TOTAL_STEPS=7
  print_step "Configure Communication"

  prompt_required VM4_IP              "This VM's IP/host"          "${GATEFORGE_VM_HOST:-100.106.117.104}"
  prompt_required ARCHITECT_IP        "Architect VM IP/host"       "${ARCHITECT_IP:-100.73.38.28}"
  echo ""
  echo -e "  ${DIM}Paste these from the VM-1 Architect setup output:${RESET}"
  prompt_required GATEWAY_AUTH_TOKEN  "This VM's gateway token"    "${GATEWAY_AUTH_TOKEN:-}"
  prompt_required ARCHITECT_HOOK_TOKEN "Architect hook token"      "${ARCHITECT_HOOK_TOKEN:-}"
  prompt_required AGENT_SECRET        "This VM's HMAC secret"     "${AGENT_SECRET:-}"

  # --- Step 3: Agent count ---
  print_step "Configure QC Agents"
  prompt_choice AGENT_COUNT "How many QC agents?" "3" "5" "10"
  print_info "Will create ${AGENT_COUNT} QC agents (qc-01 through qc-$(printf '%02d' "$AGENT_COUNT"))"

  # --- Step 4: Write config ---
  print_step "Write Central Config File"

  local config_content
  config_content=$(cat << EOF
# =============================================================================
# GateForge Central Configuration — VM-4: QC Agents
# =============================================================================
# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
# Permissions: root:root 600 — do NOT commit to Git.
# =============================================================================

# --- This VM ---
GATEFORGE_ROLE=qc-agents
GATEFORGE_VM_HOST=${VM4_IP}
GATEFORGE_PORT=${OPENCLAW_PORT}
GATEWAY_AUTH_TOKEN=${GATEWAY_AUTH_TOKEN}
AGENT_COUNT=${AGENT_COUNT}

# --- Architect Connection ---
ARCHITECT_IP=${ARCHITECT_IP}
ARCHITECT_NOTIFY_URL=http://${ARCHITECT_IP}:${OPENCLAW_PORT}/hooks/agent
ARCHITECT_HOOK_TOKEN=${ARCHITECT_HOOK_TOKEN}

# --- HMAC Signing Secret (never transmitted) ---
AGENT_SECRET=${AGENT_SECRET}
EOF
)

  write_config "$config_content"

  # --- Step 5: Copy config files + generate agent SOULs ---
  print_step "Copy Config Files & Generate Agent Identities"
  copy_config_files "$VM_DIR"
  generate_agent_souls "$VM_DIR" "qc" "$AGENT_COUNT" "QC Tester"

  # --- Step 6: Verify ---
  print_step "Verify & Summary"
  verify_connectivity "$ARCHITECT_IP" "$OPENCLAW_PORT" "Architect (${ARCHITECT_IP})"

  print_summary_box "VM-4 QC Agents — Configuration" \
    "Role:" "QC Agents (Spoke)" \
    "IP/Host:" "$VM4_IP" \
    "Agent Count:" "$AGENT_COUNT (qc-01 to qc-$(printf '%02d' "$AGENT_COUNT"))" \
    "Config:" "$CONFIG_FILE" \
    "Architect:" "http://${ARCHITECT_IP}:${OPENCLAW_PORT}" \
    "Gateway Token:" "$(mask_secret "$GATEWAY_AUTH_TOKEN")" \
    "HMAC Secret:" "$(mask_secret "$AGENT_SECRET")"

  echo -e "  ${GREEN}${BOLD}VM-4 QC Agents setup complete.${RESET}"
  echo ""
}

main "$@"

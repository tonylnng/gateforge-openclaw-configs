#!/usr/bin/env bash
# =============================================================================
# GateForge Communication Setup — VM-1: System Architect
# =============================================================================
# Assumes OpenClaw is already installed with API key and Telegram configured.
# This script sets up inter-agent communication tokens, secrets, and IPs.
# Run this FIRST — it generates secrets for all spoke VMs.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/install-common.sh"

TOTAL_STEPS=6
VM_NAME="vm1"
VM_ROLE="VM-1: System Architect"
VM_DIR="${SCRIPT_DIR}/../vm-1-architect"

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
show_help() {
  print_banner
  echo -e "  ${BOLD}Usage:${RESET} sudo bash setup-vm1-architect.sh [--help] [--dry-run]"
  echo ""
  echo -e "  ${BOLD}VM-1: System Architect${RESET} — Hub coordinator"
  echo -e "  Assumes OpenClaw is already installed with API key and Telegram."
  echo ""
  echo -e "  ${BOLD}This script will:${RESET}"
  echo -e "    1. Verify OpenClaw is installed"
  echo -e "    2. Prompt for VM IPs / Tailscale hostnames"
  echo -e "    3. Generate gateway tokens and HMAC secrets for all 5 VMs"
  echo -e "    4. Write central config to ${CONFIG_FILE}"
  echo -e "    5. Copy GateForge config files (SOUL.md, AGENTS.md, etc.)"
  echo -e "    6. Display all secrets for spoke VM setup"
  echo ""
  echo -e "  ${BOLD}Options:${RESET}"
  echo -e "    --help      Show this help message"
  echo -e "    --dry-run   Show what would be done without making changes"
  echo ""
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  if ! parse_common_flags "$@"; then
    show_help
    exit 0
  fi

  print_banner
  echo -e "  ${BOLD}Setting up: ${TEAL}${VM_ROLE}${RESET}"
  echo -e "  ${DIM}This VM is the hub — run this script FIRST.${RESET}"
  echo ""

  # --- Step 1: Verify OpenClaw ---
  print_step "Verify OpenClaw Installation"
  verify_openclaw

  # Load existing config if present
  if load_existing_config; then
    print_info "Pre-filling values from existing config."
    confirm_continue "Overwrite existing config?"
  fi

  # --- Step 2: Collect IPs ---
  print_step "Configure VM Addresses"
  echo -e "  ${DIM}Enter Tailscale hostnames or IP addresses for each VM.${RESET}"
  echo ""

  prompt_required VM1_IP   "VM-1 Architect IP/host"  "${VM1_IP:-100.73.38.28}"
  prompt_required VM2_IP   "VM-2 Designer IP/host"   "${VM2_IP:-100.95.30.11}"
  prompt_required VM3_IP   "VM-3 Developers IP/host" "${VM3_IP:-100.81.114.55}"
  prompt_required VM4_IP   "VM-4 QC Agents IP/host"  "${VM4_IP:-100.106.117.104}"
  prompt_required VM5_IP   "VM-5 Operator IP/host"   "${VM5_IP:-100.95.248.68}"

  # --- Step 3: Generate tokens and secrets ---
  print_step "Generate Tokens & HMAC Secrets"
  echo -e "  ${DIM}Press Enter to auto-generate, or paste an existing value.${RESET}"
  echo ""

  # Gateway token for this VM
  local default_gw_token
  default_gw_token="${GATEWAY_AUTH_TOKEN:-$(generate_secret)}"
  prompt_secret GATEWAY_AUTH_TOKEN "VM-1 Gateway auth token" "$default_gw_token"

  # Hook token for inbound notifications
  local default_hook_token
  default_hook_token="${ARCHITECT_HOOK_TOKEN:-$(generate_secret)}"
  prompt_secret ARCHITECT_HOOK_TOKEN "Architect hook token (spokes use this)" "$default_hook_token"

  # Gateway tokens for spoke VMs (Architect uses these to dispatch tasks)
  echo ""
  print_info "Generating gateway auth tokens for spoke VMs..."
  VM2_GATEWAY_TOKEN="${VM2_GATEWAY_TOKEN:-$(generate_secret)}"
  VM3_GATEWAY_TOKEN="${VM3_GATEWAY_TOKEN:-$(generate_secret)}"
  VM4_GATEWAY_TOKEN="${VM4_GATEWAY_TOKEN:-$(generate_secret)}"
  VM5_GATEWAY_TOKEN="${VM5_GATEWAY_TOKEN:-$(generate_secret)}"
  print_success "4 gateway tokens generated"

  # HMAC signing secrets per spoke VM
  print_info "Generating HMAC signing secrets for spoke VMs..."
  VM2_AGENT_SECRET="${VM2_AGENT_SECRET:-$(generate_secret)}"
  VM3_AGENT_SECRET="${VM3_AGENT_SECRET:-$(generate_secret)}"
  VM4_AGENT_SECRET="${VM4_AGENT_SECRET:-$(generate_secret)}"
  VM5_AGENT_SECRET="${VM5_AGENT_SECRET:-$(generate_secret)}"
  print_success "4 HMAC secrets generated"

  # --- Step 4: Write central config ---
  print_step "Write Central Config File"

  local config_content
  config_content=$(cat << EOF
# =============================================================================
# GateForge Central Configuration — VM-1: System Architect
# =============================================================================
# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
# This file is loaded by the OpenClaw agent for inter-VM communication.
# Permissions: root:root 600 — do NOT commit to Git.
# =============================================================================

# --- This VM ---
GATEFORGE_ROLE=architect
GATEFORGE_VM_HOST=${VM1_IP}
GATEFORGE_PORT=${OPENCLAW_PORT}
GATEWAY_AUTH_TOKEN=${GATEWAY_AUTH_TOKEN}

# --- Architect Hook (inbound notifications from spokes) ---
ARCHITECT_HOOK_TOKEN=${ARCHITECT_HOOK_TOKEN}
ARCHITECT_NOTIFY_URL=http://${VM1_IP}:${OPENCLAW_PORT}/hooks/agent

# --- VM-2: System Designer ---
VM2_IP=${VM2_IP}
VM2_GATEWAY_TOKEN=${VM2_GATEWAY_TOKEN}
VM2_AGENT_SECRET=${VM2_AGENT_SECRET}

# --- VM-3: Developers ---
VM3_IP=${VM3_IP}
VM3_GATEWAY_TOKEN=${VM3_GATEWAY_TOKEN}
VM3_AGENT_SECRET=${VM3_AGENT_SECRET}

# --- VM-4: QC Agents ---
VM4_IP=${VM4_IP}
VM4_GATEWAY_TOKEN=${VM4_GATEWAY_TOKEN}
VM4_AGENT_SECRET=${VM4_AGENT_SECRET}

# --- VM-5: Operator ---
VM5_IP=${VM5_IP}
VM5_GATEWAY_TOKEN=${VM5_GATEWAY_TOKEN}
VM5_AGENT_SECRET=${VM5_AGENT_SECRET}
EOF
)

  write_config "$config_content"

  # --- Step 5: Copy config files ---
  print_step "Copy GateForge Config Files"
  copy_config_files "$VM_DIR"

  # --- Step 6: Summary ---
  print_step "Setup Complete"

  print_summary_box "VM-1 System Architect — Configuration" \
    "Role:" "System Architect (Hub)" \
    "IP/Host:" "$VM1_IP" \
    "Port:" "$OPENCLAW_PORT" \
    "Config:" "$CONFIG_FILE" \
    "Gateway Token:" "$(mask_secret "$GATEWAY_AUTH_TOKEN")" \
    "Hook Token:" "$(mask_secret "$ARCHITECT_HOOK_TOKEN")"

  # Display spoke secrets — the user needs these for spoke VM setup
  echo -e "  ${RED}${BOLD}┌────────────────────────────────────────────────────────────────┐${RESET}"
  echo -e "  ${RED}${BOLD}│  SAVE THESE VALUES — needed when setting up spoke VMs         │${RESET}"
  echo -e "  ${RED}${BOLD}├────────────────────────────────────────────────────────────────┤${RESET}"
  echo -e "  ${RED}${BOLD}│${RESET}                                                                ${RED}${BOLD}│${RESET}"
  echo -e "  ${RED}${BOLD}│${RESET}  ${BOLD}Architect Hook Token (all spokes need this):${RESET}                 ${RED}${BOLD}│${RESET}"
  echo -e "  ${RED}${BOLD}│${RESET}  ${TEAL}${ARCHITECT_HOOK_TOKEN}${RESET}"
  echo -e "  ${RED}${BOLD}│${RESET}                                                                ${RED}${BOLD}│${RESET}"
  echo -e "  ${RED}${BOLD}│${RESET}  ${BOLD}VM-2 Designer:${RESET}                                              ${RED}${BOLD}│${RESET}"
  echo -e "  ${RED}${BOLD}│${RESET}    Gateway Token: ${TEAL}${VM2_GATEWAY_TOKEN}${RESET}"
  echo -e "  ${RED}${BOLD}│${RESET}    HMAC Secret:   ${TEAL}${VM2_AGENT_SECRET}${RESET}"
  echo -e "  ${RED}${BOLD}│${RESET}                                                                ${RED}${BOLD}│${RESET}"
  echo -e "  ${RED}${BOLD}│${RESET}  ${BOLD}VM-3 Developers:${RESET}                                            ${RED}${BOLD}│${RESET}"
  echo -e "  ${RED}${BOLD}│${RESET}    Gateway Token: ${TEAL}${VM3_GATEWAY_TOKEN}${RESET}"
  echo -e "  ${RED}${BOLD}│${RESET}    HMAC Secret:   ${TEAL}${VM3_AGENT_SECRET}${RESET}"
  echo -e "  ${RED}${BOLD}│${RESET}                                                                ${RED}${BOLD}│${RESET}"
  echo -e "  ${RED}${BOLD}│${RESET}  ${BOLD}VM-4 QC Agents:${RESET}                                             ${RED}${BOLD}│${RESET}"
  echo -e "  ${RED}${BOLD}│${RESET}    Gateway Token: ${TEAL}${VM4_GATEWAY_TOKEN}${RESET}"
  echo -e "  ${RED}${BOLD}│${RESET}    HMAC Secret:   ${TEAL}${VM4_AGENT_SECRET}${RESET}"
  echo -e "  ${RED}${BOLD}│${RESET}                                                                ${RED}${BOLD}│${RESET}"
  echo -e "  ${RED}${BOLD}│${RESET}  ${BOLD}VM-5 Operator:${RESET}                                              ${RED}${BOLD}│${RESET}"
  echo -e "  ${RED}${BOLD}│${RESET}    Gateway Token: ${TEAL}${VM5_GATEWAY_TOKEN}${RESET}"
  echo -e "  ${RED}${BOLD}│${RESET}    HMAC Secret:   ${TEAL}${VM5_AGENT_SECRET}${RESET}"
  echo -e "  ${RED}${BOLD}│${RESET}                                                                ${RED}${BOLD}│${RESET}"
  echo -e "  ${RED}${BOLD}└────────────────────────────────────────────────────────────────┘${RESET}"
  echo ""
  echo -e "  ${GREEN}${BOLD}VM-1 Architect setup complete.${RESET}"
  echo -e "  Now run the setup script on each spoke VM and paste the values above."
  echo ""
}

main "$@"

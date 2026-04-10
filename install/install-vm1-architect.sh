#!/usr/bin/env bash
# =============================================================================
# GateForge OpenClaw Installer — VM-1: System Architect
# =============================================================================
# Model: Claude Opus 4.6 (anthropic/claude-opus-4-6)
# Role:  Hub coordinator, Telegram interface, Lobster pipeline
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/install-common.sh"

TOTAL_STEPS=12
VM_NAME="vm1"
VM_ROLE="VM-1: System Architect"
VM_DIR="${SCRIPT_DIR}/../vm-1-architect"

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
show_help() {
  print_common_help "vm1-architect" "VM-1: System Architect (Claude Opus 4.6)"
  echo -e "  ${BOLD}Description:${RESET}"
  echo -e "    Sets up the System Architect — the hub coordinator for the"
  echo -e "    GateForge multi-agent SDLC pipeline. This VM receives tasks"
  echo -e "    via Telegram, orchestrates spoke VMs (2-5), and manages the"
  echo -e "    Blueprint repository."
  echo ""
  echo -e "  ${BOLD}What this script does:${RESET}"
  echo -e "    1.  Check prerequisites (Ubuntu, curl, git, openssl, node)"
  echo -e "    2.  Install OpenClaw"
  echo -e "    3.  Prompt for configuration values"
  echo -e "    4.  Generate spoke VM secrets"
  echo -e "    5.  Configure gateway (bind 0.0.0.0, hooks enabled)"
  echo -e "    6.  Configure model provider (Anthropic, Claude Opus 4.6)"
  echo -e "    7.  Write secrets to /opt/secrets/openclaw-gateforge.env"
  echo -e "    8.  Copy VM-1 config files to ~/.openclaw/"
  echo -e "    9.  Configure Lobster pipeline"
  echo -e "    10. Set up systemd service"
  echo -e "    11. Verify installation"
  echo -e "    12. Display summary and spoke secrets"
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
  echo -e "  ${BOLD}Installing: ${TEAL}${VM_ROLE}${RESET}"
  echo -e "  ${DIM}Model: Claude Opus 4.6 (anthropic/claude-opus-4-6)${RESET}"
  echo ""

  # ── Step 1: Prerequisites ──────────────────────────────────────────────
  check_prerequisites

  # ── Step 2: Install OpenClaw ───────────────────────────────────────────
  install_openclaw

  # ── Step 3: Prompt for inputs ──────────────────────────────────────────
  print_step 3 "Configuration"

  prompt_secret ANTHROPIC_API_KEY "Anthropic API key (for Claude Opus 4.6)"
  validate_api_key "$ANTHROPIC_API_KEY" "anthropic"

  prompt_optional VM1_IP "VM-1 IP address" "192.168.72.10"
  if ! validate_ip "$VM1_IP"; then
    print_error "Invalid IP address: ${VM1_IP}"
    exit 1
  fi

  echo ""
  echo -e "  ${BOLD}Gateway Auth Token${RESET}"
  echo -e "  ${DIM}This token protects the Architect's gateway endpoint.${RESET}"
  prompt_choice TOKEN_ACTION "Generate a new token or enter an existing one?" "Generate new token" "Enter existing token"
  if [[ "$TOKEN_ACTION" == "Generate new token" ]]; then
    GATEWAY_TOKEN=$(generate_secret)
    print_success "Generated gateway token: $(mask_secret "$GATEWAY_TOKEN")"
  else
    prompt_secret GATEWAY_TOKEN "Gateway auth token"
  fi

  echo ""
  echo -e "  ${BOLD}Architect Hook Token${RESET}"
  echo -e "  ${DIM}Token for authenticating inbound hook notifications from spoke VMs.${RESET}"
  prompt_choice HOOK_ACTION "Generate a new hook token or enter an existing one?" "Generate new token" "Enter existing token"
  if [[ "$HOOK_ACTION" == "Generate new token" ]]; then
    ARCHITECT_HOOK_TOKEN=$(generate_secret)
    print_success "Generated hook token: $(mask_secret "$ARCHITECT_HOOK_TOKEN")"
  else
    prompt_secret ARCHITECT_HOOK_TOKEN "Architect hook token"
  fi

  echo ""
  prompt_secret TELEGRAM_BOT_TOKEN "Telegram bot token"

  echo ""
  prompt_optional BLUEPRINT_REPO "Blueprint Git repo URL" "git@github.com:YOUR_ORG/blueprint-repo.git"

  # ── Step 4: Generate spoke secrets ─────────────────────────────────────
  print_step 4 "Generating spoke VM secrets"
  echo -e "  ${DIM}Each spoke VM needs a unique HMAC signing secret and a gateway auth token.${RESET}"

  echo ""
  echo -e "  ${BOLD}Spoke VM IP Addresses${RESET}"
  prompt_optional VM2_IP "VM-2 (Designer) IP" "192.168.72.11"
  prompt_optional VM3_IP "VM-3 (Developers) IP" "192.168.72.12"
  prompt_optional VM4_IP "VM-4 (QC Agents) IP" "192.168.72.13"
  prompt_optional VM5_IP "VM-5 (Operator) IP" "192.168.72.14"

  echo ""
  echo -e "  ${BOLD}Spoke Gateway Tokens${RESET}"
  echo -e "  ${DIM}These tokens authenticate the Architect's requests to each spoke VM.${RESET}"

  prompt_choice SPOKE_TOKEN_ACTION "Generate all spoke tokens or enter them individually?" "Generate all" "Enter individually"

  if [[ "$SPOKE_TOKEN_ACTION" == "Generate all" ]]; then
    DESIGNER_TOKEN=$(generate_secret)
    DEV_TOKEN=$(generate_secret)
    QC_TOKEN=$(generate_secret)
    OPERATOR_TOKEN=$(generate_secret)
    print_success "Generated 4 spoke gateway tokens"
  else
    prompt_secret DESIGNER_TOKEN "VM-2 (Designer) gateway token"
    prompt_secret DEV_TOKEN "VM-3 (Developers) gateway token"
    prompt_secret QC_TOKEN "VM-4 (QC Agents) gateway token"
    prompt_secret OPERATOR_TOKEN "VM-5 (Operator) gateway token"
  fi

  echo ""
  echo -e "  ${BOLD}Spoke HMAC Secrets${RESET}"
  echo -e "  ${DIM}Used by spoke VMs to sign notification payloads (HMAC-SHA256).${RESET}"

  prompt_choice SPOKE_HMAC_ACTION "Generate all HMAC secrets or enter them individually?" "Generate all" "Enter individually"

  if [[ "$SPOKE_HMAC_ACTION" == "Generate all" ]]; then
    VM2_AGENT_SECRET=$(generate_secret)
    VM3_AGENT_SECRET=$(generate_secret)
    VM4_AGENT_SECRET=$(generate_secret)
    VM5_AGENT_SECRET=$(generate_secret)
    print_success "Generated 4 spoke HMAC secrets"
  else
    prompt_secret VM2_AGENT_SECRET "VM-2 (Designer) HMAC secret"
    prompt_secret VM3_AGENT_SECRET "VM-3 (Developers) HMAC secret"
    prompt_secret VM4_AGENT_SECRET "VM-4 (QC Agents) HMAC secret"
    prompt_secret VM5_AGENT_SECRET "VM-5 (Operator) HMAC secret"
  fi

  # ── Confirm ────────────────────────────────────────────────────────────
  echo ""
  echo -e "  ${BOLD}Review:${RESET}"
  echo -e "    VM-1 IP:          ${VM1_IP}"
  echo -e "    Model:            anthropic/claude-opus-4-6"
  echo -e "    API Key:          $(mask_secret "$ANTHROPIC_API_KEY")"
  echo -e "    Gateway Token:    $(mask_secret "$GATEWAY_TOKEN")"
  echo -e "    Hook Token:       $(mask_secret "$ARCHITECT_HOOK_TOKEN")"
  echo -e "    Telegram Token:   $(mask_secret "$TELEGRAM_BOT_TOKEN")"
  echo -e "    Blueprint Repo:   ${BLUEPRINT_REPO}"
  echo -e "    Spoke IPs:        ${VM2_IP}, ${VM3_IP}, ${VM4_IP}, ${VM5_IP}"
  echo ""
  confirm_continue "Proceed with installation?"

  # ── Step 5: Configure gateway ──────────────────────────────────────────
  print_step 5 "Configuring gateway"
  configure_gateway "0.0.0.0" "$GATEWAY_TOKEN" "$ARCHITECT_HOOK_TOKEN" "true"

  # ── Step 6: Configure model provider ───────────────────────────────────
  print_step 6 "Configuring model provider"
  configure_model_provider "anthropic" "claude-opus-4-6"

  # ── Step 7: Write secrets ──────────────────────────────────────────────
  print_step 7 "Writing secrets"
  setup_secrets_file "$VM_NAME"

  local secrets_content="# GateForge — VM-1: System Architect
# Generated: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
# WARNING: This file contains secrets. Do not commit to version control.

# Model Provider
ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}

# Gateway
GATEWAY_AUTH_TOKEN=${GATEWAY_TOKEN}
ARCHITECT_HOOK_TOKEN=${ARCHITECT_HOOK_TOKEN}

# Telegram
TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}

# Blueprint
BLUEPRINT_REPO=${BLUEPRINT_REPO}

# Spoke VM Gateway Tokens (used to authenticate requests TO spoke VMs)
DESIGNER_TOKEN=${DESIGNER_TOKEN}
DEV_TOKEN=${DEV_TOKEN}
QC_TOKEN=${QC_TOKEN}
OPERATOR_TOKEN=${OPERATOR_TOKEN}

# Spoke VM HMAC Secrets (used to verify notifications FROM spoke VMs)
VM2_AGENT_SECRET=${VM2_AGENT_SECRET}
VM3_AGENT_SECRET=${VM3_AGENT_SECRET}
VM4_AGENT_SECRET=${VM4_AGENT_SECRET}
VM5_AGENT_SECRET=${VM5_AGENT_SECRET}

# Spoke VM Addresses
VM2_IP=${VM2_IP}
VM3_IP=${VM3_IP}
VM4_IP=${VM4_IP}
VM5_IP=${VM5_IP}
"

  write_secrets_file "$VM_NAME" "$secrets_content"

  # ── Step 8: Copy config files ──────────────────────────────────────────
  print_step 8 "Copying VM-1 config files"
  copy_config_files "$VM_DIR"

  # ── Step 9: Configure Lobster pipeline ─────────────────────────────────
  print_step 9 "Configuring Lobster pipeline"

  local lobster_dir="${OPENCLAW_CONFIG_DIR}/workflows"
  if [[ "$DRY_RUN" == "true" ]]; then
    print_warn "[DRY RUN] Would create Lobster workflow directory: ${lobster_dir}"
  else
    mkdir -p "$lobster_dir"
    print_success "Lobster workflow directory created: ${lobster_dir}"
  fi
  print_info "Place your .lobster workflow files in: ${lobster_dir}"

  # ── Step 10: Systemd service ───────────────────────────────────────────
  print_step 10 "Setting up systemd service"
  setup_systemd_service "$VM_NAME"

  # ── Step 11: Verify ────────────────────────────────────────────────────
  print_step 11 "Verifying installation"
  verify_installation

  # ── Step 12: Summary ───────────────────────────────────────────────────
  print_step 12 "Installation complete"

  print_summary_header
  print_summary_line "VM:" "VM-1 — System Architect"
  print_summary_line "IP Address:" "$VM1_IP"
  print_summary_line "Port:" "$OPENCLAW_PORT"
  print_summary_line "Model:" "anthropic/claude-opus-4-6"
  print_summary_line "API Key:" "$(mask_secret "$ANTHROPIC_API_KEY")"
  print_summary_line "Gateway Token:" "$(mask_secret "$GATEWAY_TOKEN")"
  print_summary_line "Hook Token:" "$(mask_secret "$ARCHITECT_HOOK_TOKEN")"
  print_summary_line "Telegram Token:" "$(mask_secret "$TELEGRAM_BOT_TOKEN")"
  print_summary_line "Blueprint:" "$BLUEPRINT_REPO"
  print_summary_line "Secrets File:" "/opt/secrets/openclaw-gateforge.env"
  print_summary_line "Systemd Service:" "openclaw-gateforge"
  print_summary_separator
  print_summary_line "SPOKE VMs:" ""
  print_summary_line "  VM-2 (Designer):" "$VM2_IP"
  print_summary_line "  VM-3 (Developers):" "$VM3_IP"
  print_summary_line "  VM-4 (QC Agents):" "$VM4_IP"
  print_summary_line "  VM-5 (Operator):" "$VM5_IP"
  print_summary_footer

  # Print spoke secrets for copying
  echo ""
  echo -e "  ${BOLD}${YELLOW}═══════════════════════════════════════════════════════════════${RESET}"
  echo -e "  ${BOLD}${YELLOW}  SPOKE VM SECRETS — COPY THESE FOR VM-2 THROUGH VM-5 SETUP  ${RESET}"
  echo -e "  ${BOLD}${YELLOW}═══════════════════════════════════════════════════════════════${RESET}"
  echo ""
  echo -e "  ${BOLD}VM-2 (System Designer):${RESET}"
  echo -e "    Gateway Token:  ${GREEN}${DESIGNER_TOKEN}${RESET}"
  echo -e "    HMAC Secret:    ${GREEN}${VM2_AGENT_SECRET}${RESET}"
  echo ""
  echo -e "  ${BOLD}VM-3 (Developers):${RESET}"
  echo -e "    Gateway Token:  ${GREEN}${DEV_TOKEN}${RESET}"
  echo -e "    HMAC Secret:    ${GREEN}${VM3_AGENT_SECRET}${RESET}"
  echo ""
  echo -e "  ${BOLD}VM-4 (QC Agents):${RESET}"
  echo -e "    Gateway Token:  ${GREEN}${QC_TOKEN}${RESET}"
  echo -e "    HMAC Secret:    ${GREEN}${VM4_AGENT_SECRET}${RESET}"
  echo ""
  echo -e "  ${BOLD}VM-5 (Operator):${RESET}"
  echo -e "    Gateway Token:  ${GREEN}${OPERATOR_TOKEN}${RESET}"
  echo -e "    HMAC Secret:    ${GREEN}${VM5_AGENT_SECRET}${RESET}"
  echo ""
  echo -e "  ${BOLD}Architect Hook Token${RESET} (all spoke VMs need this to call back):"
  echo -e "    Hook Token:     ${GREEN}${ARCHITECT_HOOK_TOKEN}${RESET}"
  echo ""
  echo -e "  ${YELLOW}${BOLD}  Save these values! You will need them when setting up each spoke VM.${RESET}"
  echo -e "  ${YELLOW}${BOLD}  They will NOT be shown again.${RESET}"
  echo ""
  echo -e "  ${BOLD}${YELLOW}═══════════════════════════════════════════════════════════════${RESET}"
  echo ""

  echo -e "  ${BOLD}Next steps:${RESET}"
  echo -e "    1. Start the service:  ${TEAL}sudo systemctl start openclaw-gateforge${RESET}"
  echo -e "    2. Check status:       ${TEAL}sudo systemctl status openclaw-gateforge${RESET}"
  echo -e "    3. View logs:          ${TEAL}journalctl -u openclaw-gateforge -f${RESET}"
  echo -e "    4. Install spoke VMs using the secrets above"
  echo ""
  print_success "VM-1 (System Architect) installation complete!"
}

main "$@"

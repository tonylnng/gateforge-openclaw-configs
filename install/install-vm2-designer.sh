#!/usr/bin/env bash
# =============================================================================
# GateForge OpenClaw Installer — VM-2: System Designer
# =============================================================================
# Model: Claude Sonnet 4.6 (anthropic/claude-sonnet-4-6)
# Role:  Infrastructure & application architecture design
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/install-common.sh"

TOTAL_STEPS=9
VM_NAME="vm2"
VM_ROLE="VM-2: System Designer"
VM_DIR="${SCRIPT_DIR}/../vm-2-designer"

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
show_help() {
  print_common_help "vm2-designer" "VM-2: System Designer (Claude Sonnet 4.6)"
  echo -e "  ${BOLD}Description:${RESET}"
  echo -e "    Sets up the System Designer — responsible for infrastructure"
  echo -e "    and application architecture design. Receives tasks from the"
  echo -e "    System Architect (VM-1) and produces design documents."
  echo ""
  echo -e "  ${BOLD}What this script does:${RESET}"
  echo -e "    1. Check prerequisites"
  echo -e "    2. Install OpenClaw"
  echo -e "    3. Prompt for configuration values"
  echo -e "    4. Configure gateway"
  echo -e "    5. Configure model provider (Anthropic, Claude Sonnet 4.6)"
  echo -e "    6. Write secrets to /opt/secrets/openclaw-gateforge.env"
  echo -e "    7. Copy VM-2 config files to ~/.openclaw/"
  echo -e "    8. Set up systemd service"
  echo -e "    9. Verify and display summary"
  echo ""
  echo -e "  ${BOLD}Required from VM-1 setup:${RESET}"
  echo -e "    - VM-2 Gateway Token (DESIGNER_TOKEN from Architect output)"
  echo -e "    - VM-2 HMAC Secret (VM2_AGENT_SECRET from Architect output)"
  echo -e "    - Architect Hook Token (ARCHITECT_HOOK_TOKEN from Architect output)"
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
  echo -e "  ${DIM}Model: Claude Sonnet 4.6 (anthropic/claude-sonnet-4-6)${RESET}"
  echo ""

  # ── Step 1: Prerequisites ──────────────────────────────────────────────
  check_prerequisites

  # ── Step 2: Install OpenClaw ───────────────────────────────────────────
  install_openclaw

  # ── Step 3: Prompt for inputs ──────────────────────────────────────────
  print_step 3 "Configuration"

  prompt_secret ANTHROPIC_API_KEY "Anthropic API key (for Claude Sonnet 4.6)"
  validate_api_key "$ANTHROPIC_API_KEY" "anthropic"

  echo ""
  prompt_optional VM2_IP "VM-2 IP address" "100.95.30.11"
  if ! validate_ip "$VM2_IP"; then
    print_error "Invalid IP address: ${VM2_IP}"
    exit 1
  fi

  echo ""
  echo -e "  ${BOLD}Gateway Auth Token${RESET}"
  echo -e "  ${DIM}This is the DESIGNER_TOKEN from the Architect (VM-1) setup output.${RESET}"
  echo -e "  ${DIM}The Architect uses this token to authenticate requests to this VM.${RESET}"
  prompt_choice TOKEN_ACTION "Generate a new token or paste from Architect setup?" "Generate new token" "Paste from Architect setup"
  if [[ "$TOKEN_ACTION" == "Generate new token" ]]; then
    GATEWAY_TOKEN=$(generate_secret)
    print_success "Generated gateway token: $(mask_secret "$GATEWAY_TOKEN")"
    print_warn "You must configure this same token as DESIGNER_TOKEN on VM-1."
  else
    prompt_secret GATEWAY_TOKEN "Gateway auth token (DESIGNER_TOKEN from VM-1)"
  fi

  echo ""
  echo -e "  ${BOLD}Architect Connection${RESET}"
  prompt_optional ARCHITECT_NOTIFY_URL "Architect notify URL" "http://100.73.38.28:18789/hooks/agent"

  echo ""
  echo -e "  ${DIM}The Architect Hook Token authenticates callbacks to the Architect.${RESET}"
  prompt_secret ARCHITECT_HOOK_TOKEN "Architect hook token (from VM-1 setup output)"

  echo ""
  echo -e "  ${BOLD}HMAC Agent Secret${RESET}"
  echo -e "  ${DIM}This VM's unique signing secret. Used to sign notification payloads.${RESET}"
  echo -e "  ${DIM}This is VM2_AGENT_SECRET from the Architect setup output.${RESET}"
  prompt_choice HMAC_ACTION "Generate a new secret or paste from Architect setup?" "Generate new secret" "Paste from Architect setup"
  if [[ "$HMAC_ACTION" == "Generate new secret" ]]; then
    AGENT_SECRET=$(generate_secret)
    print_success "Generated HMAC secret: $(mask_secret "$AGENT_SECRET")"
    print_warn "You must configure this same secret as VM2_AGENT_SECRET on VM-1."
  else
    prompt_secret AGENT_SECRET "HMAC agent secret (VM2_AGENT_SECRET from VM-1)"
  fi

  echo ""
  prompt_optional BLUEPRINT_REPO "Blueprint Git repo URL" "git@github.com:YOUR_ORG/blueprint-repo.git"

  # ── Confirm ────────────────────────────────────────────────────────────
  echo ""
  echo -e "  ${BOLD}Review:${RESET}"
  echo -e "    VM-2 IP:            ${VM2_IP}"
  echo -e "    Model:              anthropic/claude-sonnet-4-6"
  echo -e "    API Key:            $(mask_secret "$ANTHROPIC_API_KEY")"
  echo -e "    Gateway Token:      $(mask_secret "$GATEWAY_TOKEN")"
  echo -e "    Architect URL:      ${ARCHITECT_NOTIFY_URL}"
  echo -e "    Architect Hook:     $(mask_secret "$ARCHITECT_HOOK_TOKEN")"
  echo -e "    HMAC Secret:        $(mask_secret "$AGENT_SECRET")"
  echo -e "    Blueprint Repo:     ${BLUEPRINT_REPO}"
  echo ""
  confirm_continue "Proceed with installation?"

  # ── Step 4: Configure gateway ──────────────────────────────────────────
  print_step 4 "Configuring gateway"
  configure_gateway "$VM2_IP" "$GATEWAY_TOKEN"

  # ── Step 5: Configure model provider ───────────────────────────────────
  print_step 5 "Configuring model provider"
  configure_model_provider "anthropic" "claude-sonnet-4-6"

  # ── Step 6: Write secrets ──────────────────────────────────────────────
  print_step 6 "Writing secrets"
  setup_secrets_file "$VM_NAME"

  local secrets_content="# GateForge — VM-2: System Designer
# Generated: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
# WARNING: This file contains secrets. Do not commit to version control.

# Model Provider
ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}

# Gateway
GATEWAY_AUTH_TOKEN=${GATEWAY_TOKEN}

# Architect Connection
ARCHITECT_NOTIFY_URL=${ARCHITECT_NOTIFY_URL}
ARCHITECT_HOOK_TOKEN=${ARCHITECT_HOOK_TOKEN}

# HMAC Signing Secret (for notification payloads to Architect)
AGENT_SECRET=${AGENT_SECRET}

# Blueprint
BLUEPRINT_REPO=${BLUEPRINT_REPO}
"

  write_secrets_file "$VM_NAME" "$secrets_content"

  # ── Step 7: Copy config files ──────────────────────────────────────────
  print_step 7 "Copying VM-2 config files"
  copy_config_files "$VM_DIR"

  # ── Step 8: Systemd service ────────────────────────────────────────────
  print_step 8 "Setting up systemd service"
  setup_systemd_service "$VM_NAME"

  # ── Step 9: Verify + Summary ───────────────────────────────────────────
  print_step 9 "Verifying installation"
  verify_installation

  print_summary_header
  print_summary_line "VM:" "VM-2 — System Designer"
  print_summary_line "IP Address:" "$VM2_IP"
  print_summary_line "Port:" "$OPENCLAW_PORT"
  print_summary_line "Model:" "anthropic/claude-sonnet-4-6"
  print_summary_line "API Key:" "$(mask_secret "$ANTHROPIC_API_KEY")"
  print_summary_line "Gateway Token:" "$(mask_secret "$GATEWAY_TOKEN")"
  print_summary_line "Architect URL:" "$ARCHITECT_NOTIFY_URL"
  print_summary_line "Architect Hook:" "$(mask_secret "$ARCHITECT_HOOK_TOKEN")"
  print_summary_line "HMAC Secret:" "$(mask_secret "$AGENT_SECRET")"
  print_summary_line "Blueprint:" "$BLUEPRINT_REPO"
  print_summary_line "Secrets File:" "/opt/secrets/openclaw-gateforge.env"
  print_summary_line "Systemd Service:" "openclaw-gateforge"
  print_summary_footer

  echo -e "  ${BOLD}Next steps:${RESET}"
  echo -e "    1. Start the service:  ${TEAL}sudo systemctl start openclaw-gateforge${RESET}"
  echo -e "    2. Check status:       ${TEAL}sudo systemctl status openclaw-gateforge${RESET}"
  echo -e "    3. View logs:          ${TEAL}journalctl -u openclaw-gateforge -f${RESET}"
  echo ""
  print_success "VM-2 (System Designer) installation complete!"
}

main "$@"

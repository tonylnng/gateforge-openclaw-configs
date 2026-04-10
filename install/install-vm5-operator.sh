#!/usr/bin/env bash
# =============================================================================
# GateForge OpenClaw Installer — VM-5: Operator
# =============================================================================
# Model: MiniMax 2.7 (minimax/minimax-2.7)
# Role:  Deployment, CI/CD, monitoring, Tailscale to US VM
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/install-common.sh"

TOTAL_STEPS=10
VM_NAME="vm5"
VM_ROLE="VM-5: Operator"
VM_DIR="${SCRIPT_DIR}/../vm-5-operator"

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
show_help() {
  print_common_help "vm5-operator" "VM-5: Operator (MiniMax 2.7)"
  echo -e "  ${BOLD}Description:${RESET}"
  echo -e "    Sets up the Operator — responsible for deployment, CI/CD,"
  echo -e "    monitoring, and release management. Uses Tailscale to reach"
  echo -e "    the US VM deployment target."
  echo ""
  echo -e "  ${BOLD}What this script does:${RESET}"
  echo -e "    1.  Check prerequisites"
  echo -e "    2.  Install OpenClaw"
  echo -e "    3.  Prompt for configuration values"
  echo -e "    4.  Configure gateway"
  echo -e "    5.  Configure model provider (MiniMax 2.7)"
  echo -e "    6.  Write secrets to /opt/secrets/openclaw-gateforge.env"
  echo -e "    7.  Copy VM-5 config files to ~/.openclaw/"
  echo -e "    8.  Configure Tailscale"
  echo -e "    9.  Set up systemd service"
  echo -e "    10. Verify and display summary"
  echo ""
  echo -e "  ${BOLD}Required from VM-1 setup:${RESET}"
  echo -e "    - VM-5 Gateway Token (OPERATOR_TOKEN from Architect output)"
  echo -e "    - VM-5 HMAC Secret (VM5_AGENT_SECRET from Architect output)"
  echo -e "    - Architect Hook Token (ARCHITECT_HOOK_TOKEN from Architect output)"
  echo ""
  echo -e "  ${BOLD}Additional requirements:${RESET}"
  echo -e "    - Tailscale auth key (for US VM access)"
  echo -e "    - GitHub token (for CI/CD pipeline triggers)"
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
  echo -e "  ${DIM}Model: MiniMax 2.7 (minimax/minimax-2.7)${RESET}"
  echo ""

  # ── Step 1: Prerequisites ──────────────────────────────────────────────
  check_prerequisites

  # ── Step 2: Install OpenClaw ───────────────────────────────────────────
  install_openclaw

  # ── Step 3: Prompt for inputs ──────────────────────────────────────────
  print_step 3 "Configuration"

  prompt_secret MINIMAX_API_KEY "MiniMax API key (for MiniMax 2.7)"
  validate_api_key "$MINIMAX_API_KEY" "minimax"

  echo ""
  prompt_optional VM5_IP "VM-5 IP address" "192.168.72.14"
  if ! validate_ip "$VM5_IP"; then
    print_error "Invalid IP address: ${VM5_IP}"
    exit 1
  fi

  echo ""
  echo -e "  ${BOLD}Gateway Auth Token${RESET}"
  echo -e "  ${DIM}This is the OPERATOR_TOKEN from the Architect (VM-1) setup output.${RESET}"
  prompt_choice TOKEN_ACTION "Generate a new token or paste from Architect setup?" "Generate new token" "Paste from Architect setup"
  if [[ "$TOKEN_ACTION" == "Generate new token" ]]; then
    GATEWAY_TOKEN=$(generate_secret)
    print_success "Generated gateway token: $(mask_secret "$GATEWAY_TOKEN")"
    print_warn "You must configure this same token as OPERATOR_TOKEN on VM-1."
  else
    prompt_secret GATEWAY_TOKEN "Gateway auth token (OPERATOR_TOKEN from VM-1)"
  fi

  echo ""
  echo -e "  ${BOLD}Architect Connection${RESET}"
  prompt_optional ARCHITECT_NOTIFY_URL "Architect notify URL" "http://192.168.72.10:18789/hooks/agent"

  echo ""
  prompt_secret ARCHITECT_HOOK_TOKEN "Architect hook token (from VM-1 setup output)"

  echo ""
  echo -e "  ${BOLD}HMAC Agent Secret${RESET}"
  echo -e "  ${DIM}This is VM5_AGENT_SECRET from the Architect setup output.${RESET}"
  prompt_choice HMAC_ACTION "Generate a new secret or paste from Architect setup?" "Generate new secret" "Paste from Architect setup"
  if [[ "$HMAC_ACTION" == "Generate new secret" ]]; then
    AGENT_SECRET=$(generate_secret)
    print_success "Generated HMAC secret: $(mask_secret "$AGENT_SECRET")"
    print_warn "You must configure this same secret as VM5_AGENT_SECRET on VM-1."
  else
    prompt_secret AGENT_SECRET "HMAC agent secret (VM5_AGENT_SECRET from VM-1)"
  fi

  echo ""
  prompt_optional BLUEPRINT_REPO "Blueprint Git repo URL" "git@github.com:YOUR_ORG/blueprint-repo.git"

  echo ""
  echo -e "  ${BOLD}Tailscale Configuration${RESET}"
  echo -e "  ${DIM}Tailscale is used to SSH into the US VM deployment target.${RESET}"
  prompt_secret TAILSCALE_AUTH_KEY "Tailscale auth key"

  echo ""
  echo -e "  ${BOLD}US VM Deployment Target${RESET}"
  prompt_optional US_VM_ADDRESS "US VM SSH address" "user@tonic.sailfish-bass.ts.net"

  echo ""
  echo -e "  ${BOLD}GitHub CI/CD${RESET}"
  prompt_secret GITHUB_TOKEN "GitHub token (for CI/CD pipeline triggers)"

  # ── Confirm ────────────────────────────────────────────────────────────
  echo ""
  echo -e "  ${BOLD}Review:${RESET}"
  echo -e "    VM-5 IP:            ${VM5_IP}"
  echo -e "    Model:              minimax/minimax-2.7"
  echo -e "    API Key:            $(mask_secret "$MINIMAX_API_KEY")"
  echo -e "    Gateway Token:      $(mask_secret "$GATEWAY_TOKEN")"
  echo -e "    Architect URL:      ${ARCHITECT_NOTIFY_URL}"
  echo -e "    Architect Hook:     $(mask_secret "$ARCHITECT_HOOK_TOKEN")"
  echo -e "    HMAC Secret:        $(mask_secret "$AGENT_SECRET")"
  echo -e "    Blueprint Repo:     ${BLUEPRINT_REPO}"
  echo -e "    Tailscale Key:      $(mask_secret "$TAILSCALE_AUTH_KEY")"
  echo -e "    US VM:              ${US_VM_ADDRESS}"
  echo -e "    GitHub Token:       $(mask_secret "$GITHUB_TOKEN")"
  echo ""
  confirm_continue "Proceed with installation?"

  # ── Step 4: Configure gateway ──────────────────────────────────────────
  print_step 4 "Configuring gateway"
  configure_gateway "$VM5_IP" "$GATEWAY_TOKEN"

  # ── Step 5: Configure model provider ───────────────────────────────────
  print_step 5 "Configuring model provider"
  configure_model_provider "minimax" "minimax-2.7" "https://api.minimax.chat/v1"

  # ── Step 6: Write secrets ──────────────────────────────────────────────
  print_step 6 "Writing secrets"
  setup_secrets_file "$VM_NAME"

  local secrets_content="# GateForge — VM-5: Operator
# Generated: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
# WARNING: This file contains secrets. Do not commit to version control.

# Model Provider
MINIMAX_API_KEY=${MINIMAX_API_KEY}

# Gateway
GATEWAY_AUTH_TOKEN=${GATEWAY_TOKEN}

# Architect Connection
ARCHITECT_NOTIFY_URL=${ARCHITECT_NOTIFY_URL}
ARCHITECT_HOOK_TOKEN=${ARCHITECT_HOOK_TOKEN}

# HMAC Signing Secret (for notification payloads to Architect)
AGENT_SECRET=${AGENT_SECRET}

# Blueprint
BLUEPRINT_REPO=${BLUEPRINT_REPO}

# Tailscale
TAILSCALE_AUTH_KEY=${TAILSCALE_AUTH_KEY}
US_VM_ADDRESS=${US_VM_ADDRESS}

# GitHub CI/CD
GITHUB_TOKEN=${GITHUB_TOKEN}
"

  write_secrets_file "$VM_NAME" "$secrets_content"

  # ── Step 7: Copy config files ──────────────────────────────────────────
  print_step 7 "Copying VM-5 config files"
  copy_config_files "$VM_DIR"

  # ── Step 8: Configure Tailscale ────────────────────────────────────────
  print_step 8 "Configuring Tailscale"

  if [[ "$DRY_RUN" == "true" ]]; then
    print_warn "[DRY RUN] Would check if Tailscale is installed"
    print_warn "[DRY RUN] Would run: tailscale up --auth-key=****"
    print_warn "[DRY RUN] Would verify SSH access to ${US_VM_ADDRESS}"
  else
    if command -v tailscale &>/dev/null; then
      print_success "Tailscale is installed"
      print_info "Connecting to Tailscale network..."
      if sudo tailscale up --auth-key="$TAILSCALE_AUTH_KEY" 2>/dev/null; then
        print_success "Tailscale connected"
      else
        print_warn "Tailscale connection failed. You may need to run 'tailscale up' manually."
      fi
    else
      print_warn "Tailscale is not installed. Install it with:"
      echo -e "    ${DIM}curl -fsSL https://tailscale.com/install.sh | sh${RESET}"
      echo -e "    ${DIM}sudo tailscale up --auth-key=\${TAILSCALE_AUTH_KEY}${RESET}"
    fi

    # Test SSH connectivity
    print_info "Testing SSH connectivity to ${US_VM_ADDRESS}..."
    if ssh -o ConnectTimeout=5 -o BatchMode=yes "$US_VM_ADDRESS" "echo ok" &>/dev/null; then
      print_success "SSH to US VM is working"
    else
      print_warn "Cannot reach ${US_VM_ADDRESS} via SSH. Verify Tailscale is running."
    fi
  fi

  # ── Step 9: Systemd service ────────────────────────────────────────────
  print_step 9 "Setting up systemd service"
  setup_systemd_service "$VM_NAME"

  # ── Step 10: Verify + Summary ──────────────────────────────────────────
  print_step 10 "Verifying installation"
  verify_installation

  print_summary_header
  print_summary_line "VM:" "VM-5 — Operator"
  print_summary_line "IP Address:" "$VM5_IP"
  print_summary_line "Port:" "$OPENCLAW_PORT"
  print_summary_line "Model:" "minimax/minimax-2.7"
  print_summary_line "API Key:" "$(mask_secret "$MINIMAX_API_KEY")"
  print_summary_line "Gateway Token:" "$(mask_secret "$GATEWAY_TOKEN")"
  print_summary_line "Architect URL:" "$ARCHITECT_NOTIFY_URL"
  print_summary_line "Architect Hook:" "$(mask_secret "$ARCHITECT_HOOK_TOKEN")"
  print_summary_line "HMAC Secret:" "$(mask_secret "$AGENT_SECRET")"
  print_summary_line "Blueprint:" "$BLUEPRINT_REPO"
  print_summary_separator
  print_summary_line "Tailscale Key:" "$(mask_secret "$TAILSCALE_AUTH_KEY")"
  print_summary_line "US VM Target:" "$US_VM_ADDRESS"
  print_summary_line "GitHub Token:" "$(mask_secret "$GITHUB_TOKEN")"
  print_summary_separator
  print_summary_line "Secrets File:" "/opt/secrets/openclaw-gateforge.env"
  print_summary_line "Systemd Service:" "openclaw-gateforge"
  print_summary_footer

  echo -e "  ${BOLD}Next steps:${RESET}"
  echo -e "    1. Start the service:  ${TEAL}sudo systemctl start openclaw-gateforge${RESET}"
  echo -e "    2. Check status:       ${TEAL}sudo systemctl status openclaw-gateforge${RESET}"
  echo -e "    3. View logs:          ${TEAL}journalctl -u openclaw-gateforge -f${RESET}"
  echo -e "    4. Verify Tailscale:   ${TEAL}tailscale status${RESET}"
  echo -e "    5. Test US VM SSH:     ${TEAL}ssh ${US_VM_ADDRESS} 'hostname'${RESET}"
  echo ""
  print_success "VM-5 (Operator) installation complete!"
}

main "$@"

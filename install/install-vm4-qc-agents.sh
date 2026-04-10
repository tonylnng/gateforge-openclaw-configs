#!/usr/bin/env bash
# =============================================================================
# GateForge OpenClaw Installer — VM-4: QC Agents
# =============================================================================
# Model: MiniMax 2.7 (minimax/minimax-2.7)
# Role:  Multi-agent quality assurance team (3, 5, or 10 agents)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/install-common.sh"

TOTAL_STEPS=10
VM_NAME="vm4"
VM_ROLE="VM-4: QC Agents"
VM_DIR="${SCRIPT_DIR}/../vm-4-qc-agents"

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
show_help() {
  print_common_help "vm4-qc-agents" "VM-4: QC Agents (MiniMax 2.7)"
  echo -e "  ${BOLD}Description:${RESET}"
  echo -e "    Sets up the QC Agents — a multi-agent quality assurance team"
  echo -e "    responsible for testing, validation, and quality gates."
  echo -e "    Supports 3, 5, or 10 concurrent QC agents sharing a single VM."
  echo ""
  echo -e "  ${BOLD}What this script does:${RESET}"
  echo -e "    1.  Check prerequisites"
  echo -e "    2.  Install OpenClaw"
  echo -e "    3.  Prompt for configuration values"
  echo -e "    4.  Configure gateway"
  echo -e "    5.  Configure model provider (MiniMax 2.7)"
  echo -e "    6.  Write secrets to /opt/secrets/openclaw-gateforge.env"
  echo -e "    7.  Copy VM-4 config files to ~/.openclaw/"
  echo -e "    8.  Generate per-agent SOUL.md files and workspaces"
  echo -e "    9.  Set up systemd service"
  echo -e "    10. Verify and display summary"
  echo ""
  echo -e "  ${BOLD}Required from VM-1 setup:${RESET}"
  echo -e "    - VM-4 Gateway Token (QC_TOKEN from Architect output)"
  echo -e "    - VM-4 HMAC Secret (VM4_AGENT_SECRET from Architect output)"
  echo -e "    - Architect Hook Token (ARCHITECT_HOOK_TOKEN from Architect output)"
  echo ""
}

# ---------------------------------------------------------------------------
# Generate per-agent SOUL.md for QC agents
# ---------------------------------------------------------------------------
generate_qc_agent_souls() {
  local agent_count="$1"
  local agents_dir="${OPENCLAW_CONFIG_DIR}/agents"

  print_info "Generating SOUL.md for ${agent_count} QC agents..."

  for i in $(seq -w 1 "$agent_count"); do
    local agent_id="qc-${i}"
    local agent_dir="${agents_dir}/${agent_id}/agent"
    local workspace_dir="${OPENCLAW_CONFIG_DIR}/workspace-${agent_id}"

    local seniority="secondary"
    if [[ "$i" == "01" ]]; then
      seniority="primary (default)"
    fi

    local soul_content="# QC Agent — ${agent_id}

> GateForge Multi-Agent SDLC Pipeline — VM-4 (Port 18789)
> Model: MiniMax 2.7 (\`minimax/minimax-2.7\`)
> Agent ID: \`${agent_id}\`

## Role

You are **${agent_id}** — a QC agent responsible for quality assurance. You are a ${seniority} QC agent on VM-4.

## Scope Assignment

Your test scope is determined per task by the System Architect. Typical scopes include:
- **Module-level**: Unit tests + API tests for a specific module
- **Integration-level**: Cross-module integration testing
- **E2E**: Full system end-to-end testing
- **Performance/Security**: Load testing, OWASP scanning

Each task payload includes:
- \`module\` or \`scope\`: What you are testing
- \`blueprintRef\`: The Blueprint section with specifications
- \`acceptanceCriteria\`: What must pass for the task to succeed

## Workspace

- **Agent Directory**: \`~/.openclaw/agents/${agent_id}/agent\`
- **Workspace**: \`~/.openclaw/workspace-${agent_id}\`
- **Blueprint Repo**: \`~/.openclaw/workspace-${agent_id}/blueprint-repo\` (read-only reference)
- **Project Repo**: Pulled via \`exec: git pull\` for code inspection (read-only)

## Collaboration with Other QC Agents

You share VM-4 with other QC agents. You can coordinate via \`sessions_send\` within this VM to avoid test duplication or share test infrastructure.

## Refer to Parent SOUL.md

All shared QC conventions (output format, test types, quality gates, constraints) are defined in the VM-4 shared \`SOUL.md\`. This file only contains ${agent_id}-specific overrides.
"

    if [[ "$DRY_RUN" == "true" ]]; then
      print_warn "[DRY RUN] Would create ${agent_dir}/SOUL.md"
      print_warn "[DRY RUN] Would create workspace: ${workspace_dir}"
    else
      mkdir -p "$agent_dir"
      mkdir -p "$workspace_dir"
      echo "$soul_content" > "${agent_dir}/SOUL.md"
      print_success "Created ${agent_id}: ${agent_dir}/SOUL.md"
    fi
  done
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
  prompt_optional VM4_IP "VM-4 IP address" "192.168.72.13"
  if ! validate_ip "$VM4_IP"; then
    print_error "Invalid IP address: ${VM4_IP}"
    exit 1
  fi

  echo ""
  echo -e "  ${BOLD}Gateway Auth Token${RESET}"
  echo -e "  ${DIM}This is the QC_TOKEN from the Architect (VM-1) setup output.${RESET}"
  prompt_choice TOKEN_ACTION "Generate a new token or paste from Architect setup?" "Generate new token" "Paste from Architect setup"
  if [[ "$TOKEN_ACTION" == "Generate new token" ]]; then
    GATEWAY_TOKEN=$(generate_secret)
    print_success "Generated gateway token: $(mask_secret "$GATEWAY_TOKEN")"
    print_warn "You must configure this same token as QC_TOKEN on VM-1."
  else
    prompt_secret GATEWAY_TOKEN "Gateway auth token (QC_TOKEN from VM-1)"
  fi

  echo ""
  echo -e "  ${BOLD}Architect Connection${RESET}"
  prompt_optional ARCHITECT_NOTIFY_URL "Architect notify URL" "http://192.168.72.10:18789/hooks/agent"

  echo ""
  prompt_secret ARCHITECT_HOOK_TOKEN "Architect hook token (from VM-1 setup output)"

  echo ""
  echo -e "  ${BOLD}HMAC Agent Secret${RESET}"
  echo -e "  ${DIM}This is VM4_AGENT_SECRET from the Architect setup output.${RESET}"
  prompt_choice HMAC_ACTION "Generate a new secret or paste from Architect setup?" "Generate new secret" "Paste from Architect setup"
  if [[ "$HMAC_ACTION" == "Generate new secret" ]]; then
    AGENT_SECRET=$(generate_secret)
    print_success "Generated HMAC secret: $(mask_secret "$AGENT_SECRET")"
    print_warn "You must configure this same secret as VM4_AGENT_SECRET on VM-1."
  else
    prompt_secret AGENT_SECRET "HMAC agent secret (VM4_AGENT_SECRET from VM-1)"
  fi

  echo ""
  prompt_optional BLUEPRINT_REPO "Blueprint Git repo URL" "git@github.com:YOUR_ORG/blueprint-repo.git"

  echo ""
  echo -e "  ${BOLD}QC Agent Count${RESET}"
  prompt_choice AGENT_COUNT "How many QC agents?" "3" "5" "10"
  print_info "Will configure ${AGENT_COUNT} QC agents (qc-01 through qc-$(printf '%02d' "$AGENT_COUNT"))"

  # ── Confirm ────────────────────────────────────────────────────────────
  echo ""
  echo -e "  ${BOLD}Review:${RESET}"
  echo -e "    VM-4 IP:            ${VM4_IP}"
  echo -e "    Model:              minimax/minimax-2.7"
  echo -e "    API Key:            $(mask_secret "$MINIMAX_API_KEY")"
  echo -e "    Gateway Token:      $(mask_secret "$GATEWAY_TOKEN")"
  echo -e "    Architect URL:      ${ARCHITECT_NOTIFY_URL}"
  echo -e "    Architect Hook:     $(mask_secret "$ARCHITECT_HOOK_TOKEN")"
  echo -e "    HMAC Secret:        $(mask_secret "$AGENT_SECRET")"
  echo -e "    Blueprint Repo:     ${BLUEPRINT_REPO}"
  echo -e "    Agent Count:        ${AGENT_COUNT}"
  echo ""
  confirm_continue "Proceed with installation?"

  # ── Step 4: Configure gateway ──────────────────────────────────────────
  print_step 4 "Configuring gateway"
  configure_gateway "$VM4_IP" "$GATEWAY_TOKEN"

  # ── Step 5: Configure model provider ───────────────────────────────────
  print_step 5 "Configuring model provider"
  configure_model_provider "minimax" "minimax-2.7" "https://api.minimax.chat/v1"

  # ── Step 6: Write secrets ──────────────────────────────────────────────
  print_step 6 "Writing secrets"
  setup_secrets_file "$VM_NAME"

  local secrets_content="# GateForge — VM-4: QC Agents (${AGENT_COUNT} agents)
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

# Agent Configuration
AGENT_COUNT=${AGENT_COUNT}
"

  write_secrets_file "$VM_NAME" "$secrets_content"

  # ── Step 7: Copy config files ──────────────────────────────────────────
  print_step 7 "Copying VM-4 config files"
  copy_config_files "$VM_DIR"

  # ── Step 8: Generate per-agent files ───────────────────────────────────
  print_step 8 "Generating per-agent SOUL.md files and workspaces"
  generate_qc_agent_souls "$AGENT_COUNT"

  # ── Step 9: Systemd service ────────────────────────────────────────────
  print_step 9 "Setting up systemd service"
  setup_systemd_service "$VM_NAME"

  # ── Step 10: Verify + Summary ──────────────────────────────────────────
  print_step 10 "Verifying installation"
  verify_installation

  print_summary_header
  print_summary_line "VM:" "VM-4 — QC Agents"
  print_summary_line "IP Address:" "$VM4_IP"
  print_summary_line "Port:" "$OPENCLAW_PORT"
  print_summary_line "Model:" "minimax/minimax-2.7"
  print_summary_line "API Key:" "$(mask_secret "$MINIMAX_API_KEY")"
  print_summary_line "Gateway Token:" "$(mask_secret "$GATEWAY_TOKEN")"
  print_summary_line "Architect URL:" "$ARCHITECT_NOTIFY_URL"
  print_summary_line "Architect Hook:" "$(mask_secret "$ARCHITECT_HOOK_TOKEN")"
  print_summary_line "HMAC Secret:" "$(mask_secret "$AGENT_SECRET")"
  print_summary_line "Blueprint:" "$BLUEPRINT_REPO"
  print_summary_line "Agent Count:" "$AGENT_COUNT"
  print_summary_line "Secrets File:" "/opt/secrets/openclaw-gateforge.env"
  print_summary_line "Systemd Service:" "openclaw-gateforge"
  print_summary_separator
  echo -e "  ${TEAL}${BOLD}║${RESET}  ${BOLD}QC Agents:${RESET}                                                 ${TEAL}${BOLD}║${RESET}"
  for i in $(seq -w 1 "$AGENT_COUNT"); do
    print_summary_line "  qc-${i}:" "~/.openclaw/agents/qc-${i}/agent"
  done
  print_summary_footer

  echo -e "  ${BOLD}Next steps:${RESET}"
  echo -e "    1. Start the service:  ${TEAL}sudo systemctl start openclaw-gateforge${RESET}"
  echo -e "    2. Check status:       ${TEAL}sudo systemctl status openclaw-gateforge${RESET}"
  echo -e "    3. View logs:          ${TEAL}journalctl -u openclaw-gateforge -f${RESET}"
  echo ""
  print_success "VM-4 (QC Agents — ${AGENT_COUNT} agents) installation complete!"
}

main "$@"

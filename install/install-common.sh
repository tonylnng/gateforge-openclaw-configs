#!/usr/bin/env bash
# =============================================================================
# GateForge OpenClaw — Shared Installation Functions
# =============================================================================
# Sourced by all VM-specific installation scripts.
# Do NOT run this file directly.
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Version
# ---------------------------------------------------------------------------
GATEFORGE_VERSION="1.0.0"
OPENCLAW_PORT=18789
OPENCLAW_CONFIG_DIR="$HOME/.openclaw"
SECRETS_DIR="/opt/secrets"

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
# Globals (set by each VM script)
# ---------------------------------------------------------------------------
DRY_RUN="${DRY_RUN:-false}"
TOTAL_STEPS="${TOTAL_STEPS:-10}"
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
  echo -e "  ${DIM}Multi-Agent SDLC Pipeline — OpenClaw Installer v${GATEFORGE_VERSION}${RESET}"
  echo ""
}

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
print_step() {
  local n="$1"; shift
  CURRENT_STEP="$n"
  echo ""
  echo -e "  ${BLUE}${BOLD}[${n}/${TOTAL_STEPS}]${RESET} ${BOLD}$*${RESET}"
  echo -e "  ${DIM}$(printf '%.0s─' {1..60})${RESET}"
}

print_success() {
  echo -e "  ${GREEN}✔${RESET} $*"
}

print_error() {
  echo -e "  ${RED}✖${RESET} $*" >&2
}

print_warn() {
  echo -e "  ${YELLOW}!${RESET} $*"
}

print_info() {
  echo -e "  ${TEAL}→${RESET} $*"
}

# ---------------------------------------------------------------------------
# Interactive prompts
# ---------------------------------------------------------------------------
prompt_required() {
  local var_name="$1"
  local prompt_text="$2"
  local value=""
  while [[ -z "$value" ]]; do
    echo -ne "  ${TEAL}?${RESET} ${prompt_text}: "
    read -r value
    if [[ -z "$value" ]]; then
      print_warn "This field is required. Please enter a value."
    fi
  done
  eval "$var_name=\"\$value\""
}

prompt_optional() {
  local var_name="$1"
  local prompt_text="$2"
  local default="${3:-}"
  local display_default=""
  if [[ -n "$default" ]]; then
    display_default=" ${DIM}[${default}]${RESET}"
  fi
  echo -ne "  ${TEAL}?${RESET} ${prompt_text}${display_default}: "
  local value=""
  read -r value
  if [[ -z "$value" ]]; then
    value="$default"
  fi
  eval "$var_name=\"\$value\""
}

prompt_secret() {
  local var_name="$1"
  local prompt_text="$2"
  local value=""
  while [[ -z "$value" ]]; do
    echo -ne "  ${TEAL}🔑${RESET} ${prompt_text}: "
    read -rs value
    echo ""
    if [[ -z "$value" ]]; then
      print_warn "This field is required. Please enter a value."
    fi
  done
  eval "$var_name=\"\$value\""
}

prompt_choice() {
  local var_name="$1"
  local prompt_text="$2"
  shift 2
  local options=("$@")

  echo -e "  ${TEAL}?${RESET} ${prompt_text}"
  local i=1
  for opt in "${options[@]}"; do
    echo -e "    ${BOLD}${i})${RESET} ${opt}"
    ((i++))
  done

  local choice=""
  while true; do
    echo -ne "  ${TEAL}→${RESET} Enter choice [1-${#options[@]}]: "
    read -r choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
      eval "$var_name=\"\${options[$((choice-1))]}\""
      return 0
    fi
    print_warn "Invalid choice. Please enter a number between 1 and ${#options[@]}."
  done
}

confirm_continue() {
  local text="${1:-Continue?}"
  echo -ne "  ${YELLOW}?${RESET} ${text} ${DIM}[y/N]${RESET}: "
  local answer=""
  read -r answer
  case "$answer" in
    [yY]|[yY][eE][sS]) return 0 ;;
    *) print_error "Aborted by user."; exit 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------------
generate_secret() {
  openssl rand -hex 32
}

mask_secret() {
  local secret="$1"
  if [[ ${#secret} -le 8 ]]; then
    echo "****"
  else
    echo "${secret:0:4}****${secret: -4}"
  fi
}

validate_ip() {
  local ip="$1"
  if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    return 0
  fi
  return 1
}

validate_api_key() {
  local key="$1"
  local provider="${2:-generic}"
  if [[ -z "$key" ]]; then
    return 1
  fi
  case "$provider" in
    anthropic)
      if [[ "$key" =~ ^sk-ant- ]]; then return 0; fi
      print_warn "Anthropic API keys typically start with 'sk-ant-'. Proceeding anyway."
      return 0
      ;;
    minimax)
      if [[ ${#key} -ge 10 ]]; then return 0; fi
      return 1
      ;;
    *)
      if [[ ${#key} -ge 10 ]]; then return 0; fi
      return 1
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Prerequisites
# ---------------------------------------------------------------------------
check_prerequisites() {
  print_step 1 "Checking prerequisites"

  # Check OS
  if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    if [[ "${ID:-}" == "ubuntu" ]]; then
      print_success "Ubuntu detected: ${PRETTY_NAME:-Ubuntu}"
    else
      print_warn "Expected Ubuntu, found: ${PRETTY_NAME:-unknown}. Continuing anyway."
    fi
  else
    print_warn "Cannot detect OS. Proceeding anyway."
  fi

  # Check required tools
  local missing=()
  for cmd in curl git openssl node; do
    if command -v "$cmd" &>/dev/null; then
      print_success "$cmd is installed ($(command -v "$cmd"))"
    else
      missing+=("$cmd")
      print_error "$cmd is NOT installed"
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    print_error "Missing required tools: ${missing[*]}"
    echo ""
    echo -e "  Install missing tools with:"
    echo -e "    ${DIM}sudo apt update && sudo apt install -y ${missing[*]}${RESET}"
    echo ""
    if [[ "$DRY_RUN" == "true" ]]; then
      print_warn "[DRY RUN] Would abort here due to missing prerequisites."
    else
      exit 1
    fi
  fi

  print_success "All prerequisites met"
}

# ---------------------------------------------------------------------------
# OpenClaw Installation
# ---------------------------------------------------------------------------
install_openclaw() {
  print_step 2 "Installing OpenClaw"

  if command -v openclaw &>/dev/null; then
    local version
    version=$(openclaw --version 2>/dev/null || echo "unknown")
    print_success "OpenClaw is already installed (${version})"
    return 0
  fi

  print_info "Installing OpenClaw..."
  if [[ "$DRY_RUN" == "true" ]]; then
    print_warn "[DRY RUN] Would run: curl -fsSL https://openclaw.ai/install.sh | bash"
    print_warn "[DRY RUN] Would run: openclaw onboard --install-daemon"
  else
    curl -fsSL https://openclaw.ai/install.sh | bash
    print_success "OpenClaw binary installed"

    print_info "Running onboarding..."
    openclaw onboard --install-daemon
    print_success "OpenClaw onboarding complete (daemon installed)"
  fi
}

# ---------------------------------------------------------------------------
# Secrets File
# ---------------------------------------------------------------------------
setup_secrets_file() {
  local vm_name="$1"
  local secrets_file="${SECRETS_DIR}/openclaw-${vm_name}.env"

  print_info "Setting up secrets file: ${secrets_file}"

  if [[ "$DRY_RUN" == "true" ]]; then
    print_warn "[DRY RUN] Would create ${secrets_file} with chmod 600, chown root:root"
    return 0
  fi

  sudo mkdir -p "$SECRETS_DIR"
  sudo touch "$secrets_file"
  sudo chmod 600 "$secrets_file"
  sudo chown root:root "$secrets_file"

  print_success "Secrets file created: ${secrets_file}"
}

write_secrets_file() {
  local vm_name="$1"
  local content="$2"
  local secrets_file="${SECRETS_DIR}/openclaw-${vm_name}.env"

  if [[ "$DRY_RUN" == "true" ]]; then
    print_warn "[DRY RUN] Would write secrets to ${secrets_file}"
    echo ""
    echo -e "  ${DIM}--- Secrets file content (preview) ---${RESET}"
    # Show keys but mask values
    while IFS= read -r line; do
      if [[ "$line" =~ ^[A-Z_]+=.+ ]]; then
        local key="${line%%=*}"
        echo -e "  ${DIM}${key}=****${RESET}"
      else
        echo -e "  ${DIM}${line}${RESET}"
      fi
    done <<< "$content"
    echo -e "  ${DIM}--- End of preview ---${RESET}"
    return 0
  fi

  echo "$content" | sudo tee "$secrets_file" > /dev/null
  sudo chmod 600 "$secrets_file"
  sudo chown root:root "$secrets_file"
  print_success "Secrets written to ${secrets_file}"
}

# ---------------------------------------------------------------------------
# Systemd Service
# ---------------------------------------------------------------------------
setup_systemd_service() {
  local vm_name="$1"
  local secrets_file="${SECRETS_DIR}/openclaw-${vm_name}.env"
  local service_name="openclaw-${vm_name}"
  local service_file="/etc/systemd/system/${service_name}.service"

  print_info "Setting up systemd service: ${service_name}"

  local unit_content
  unit_content="[Unit]
Description=OpenClaw Gateway — GateForge ${vm_name}
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$(whoami)
EnvironmentFile=${secrets_file}
ExecStart=$(command -v openclaw 2>/dev/null || echo '/usr/local/bin/openclaw') serve
WorkingDirectory=${OPENCLAW_CONFIG_DIR}
Restart=on-failure
RestartSec=5
LimitNOFILE=65536
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target"

  if [[ "$DRY_RUN" == "true" ]]; then
    print_warn "[DRY RUN] Would create systemd unit: ${service_file}"
    echo ""
    echo -e "  ${DIM}${unit_content}${RESET}"
    echo ""
    return 0
  fi

  echo "$unit_content" | sudo tee "$service_file" > /dev/null
  sudo systemctl daemon-reload
  sudo systemctl enable "$service_name"
  print_success "Systemd service created and enabled: ${service_name}"
  print_info "Start with: sudo systemctl start ${service_name}"
}

# ---------------------------------------------------------------------------
# Gateway Configuration
# ---------------------------------------------------------------------------
configure_gateway() {
  local bind_addr="$1"
  local auth_token="$2"
  local hook_token="${3:-}"
  local enable_hooks="${4:-false}"

  local config_file="${OPENCLAW_CONFIG_DIR}/openclaw.json"

  print_info "Configuring gateway..."

  local hooks_block=""
  if [[ "$enable_hooks" == "true" && -n "$hook_token" ]]; then
    hooks_block=',
  "hooks": {
    "enabled": true,
    "token": "'"${hook_token}"'",
    "path": "/hooks",
    "allowedAgentIds": ["architect"]
  }'
  fi

  local config_content='{
  "gateway": {
    "bind": "'"${bind_addr}"'",
    "port": '"${OPENCLAW_PORT}"',
    "authToken": "'"${auth_token}"'"
  }'"${hooks_block}"'
}'

  if [[ "$DRY_RUN" == "true" ]]; then
    print_warn "[DRY RUN] Would write gateway config to ${config_file}"
    echo ""
    echo -e "  ${DIM}${config_content}${RESET}"
    echo ""
    return 0
  fi

  mkdir -p "$OPENCLAW_CONFIG_DIR"
  echo "$config_content" > "$config_file"
  print_success "Gateway config written to ${config_file}"
}

# ---------------------------------------------------------------------------
# Model Provider Configuration
# ---------------------------------------------------------------------------
configure_model_provider() {
  local provider="$1"    # e.g., "anthropic" or "minimax"
  local model="$2"       # e.g., "claude-opus-4-6" or "minimax-2.7"
  local base_url="${3:-}" # optional base URL

  local provider_file="${OPENCLAW_CONFIG_DIR}/provider.json"

  print_info "Configuring model provider: ${provider}/${model}"

  local config_content
  if [[ -n "$base_url" ]]; then
    config_content='{
  "provider": "'"${provider}/${model}"'",
  "baseUrl": "'"${base_url}"'"
}'
  else
    config_content='{
  "provider": "'"${provider}/${model}"'"
}'
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    print_warn "[DRY RUN] Would write provider config to ${provider_file}"
    echo ""
    echo -e "  ${DIM}${config_content}${RESET}"
    echo ""
    return 0
  fi

  mkdir -p "$OPENCLAW_CONFIG_DIR"
  echo "$config_content" > "$provider_file"
  print_success "Provider config written to ${provider_file}"
}

# ---------------------------------------------------------------------------
# Copy Config Files
# ---------------------------------------------------------------------------
copy_config_files() {
  local vm_dir="$1"
  local target_dir="${OPENCLAW_CONFIG_DIR}"

  print_info "Copying configuration files from ${vm_dir}..."

  if [[ ! -d "$vm_dir" ]]; then
    print_error "Source directory does not exist: ${vm_dir}"
    return 1
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    for f in "$vm_dir"/*.md; do
      if [[ -f "$f" ]]; then
        print_warn "[DRY RUN] Would copy $(basename "$f") → ${target_dir}/"
      fi
    done
    return 0
  fi

  mkdir -p "$target_dir"
  local count=0
  for f in "$vm_dir"/*.md; do
    if [[ -f "$f" ]]; then
      cp "$f" "$target_dir/"
      print_success "Copied $(basename "$f")"
      ((count++))
    fi
  done

  if [[ $count -eq 0 ]]; then
    print_warn "No .md files found in ${vm_dir}"
  else
    print_success "${count} config files copied"
  fi
}

# ---------------------------------------------------------------------------
# Verify Installation
# ---------------------------------------------------------------------------
verify_installation() {
  print_info "Verifying installation..."

  if [[ "$DRY_RUN" == "true" ]]; then
    print_warn "[DRY RUN] Would verify gateway status and run health check"
    return 0
  fi

  # Check if openclaw is installed
  if command -v openclaw &>/dev/null; then
    print_success "OpenClaw binary found"
  else
    print_error "OpenClaw binary not found in PATH"
    return 1
  fi

  # Check config directory
  if [[ -d "$OPENCLAW_CONFIG_DIR" ]]; then
    print_success "Config directory exists: ${OPENCLAW_CONFIG_DIR}"
  else
    print_error "Config directory missing: ${OPENCLAW_CONFIG_DIR}"
    return 1
  fi

  # Check gateway config
  if [[ -f "${OPENCLAW_CONFIG_DIR}/openclaw.json" ]]; then
    print_success "Gateway config exists"
  else
    print_error "Gateway config missing"
    return 1
  fi

  # Check provider config
  if [[ -f "${OPENCLAW_CONFIG_DIR}/provider.json" ]]; then
    print_success "Provider config exists"
  else
    print_warn "Provider config not found (may be configured elsewhere)"
  fi

  # Try a basic health check (non-blocking)
  print_info "Attempting health check on port ${OPENCLAW_PORT}..."
  if curl -sf "http://localhost:${OPENCLAW_PORT}/health" --connect-timeout 3 &>/dev/null; then
    print_success "Gateway is responding on port ${OPENCLAW_PORT}"
  else
    print_warn "Gateway is not running yet. Start with: sudo systemctl start openclaw-<vm>"
  fi
}

# ---------------------------------------------------------------------------
# Summary Box
# ---------------------------------------------------------------------------
print_summary_header() {
  echo ""
  echo -e "  ${TEAL}${BOLD}╔══════════════════════════════════════════════════════════════╗${RESET}"
  echo -e "  ${TEAL}${BOLD}║                    INSTALLATION SUMMARY                     ║${RESET}"
  echo -e "  ${TEAL}${BOLD}╠══════════════════════════════════════════════════════════════╣${RESET}"
}

print_summary_line() {
  local label="$1"
  local value="$2"
  printf "  ${TEAL}${BOLD}║${RESET}  %-22s %-37s ${TEAL}${BOLD}║${RESET}\n" "$label" "$value"
}

print_summary_separator() {
  echo -e "  ${TEAL}${BOLD}╠══════════════════════════════════════════════════════════════╣${RESET}"
}

print_summary_footer() {
  echo -e "  ${TEAL}${BOLD}╚══════════════════════════════════════════════════════════════╝${RESET}"
  echo ""
}

# ---------------------------------------------------------------------------
# Help text helper
# ---------------------------------------------------------------------------
print_common_help() {
  local vm_name="$1"
  local vm_role="$2"
  echo ""
  echo -e "  ${BOLD}GateForge OpenClaw Installer — ${vm_role}${RESET}"
  echo ""
  echo -e "  ${BOLD}Usage:${RESET}"
  echo -e "    ./install-${vm_name}.sh [OPTIONS]"
  echo ""
  echo -e "  ${BOLD}Options:${RESET}"
  echo -e "    --help       Show this help message"
  echo -e "    --dry-run    Show what would be done without making changes"
  echo ""
}

# ---------------------------------------------------------------------------
# Parse common flags
# ---------------------------------------------------------------------------
parse_common_flags() {
  for arg in "$@"; do
    case "$arg" in
      --help|-h)
        return 1  # Signal caller to show help and exit
        ;;
      --dry-run)
        DRY_RUN="true"
        print_warn "DRY RUN mode — no changes will be made"
        echo ""
        ;;
    esac
  done
  return 0
}

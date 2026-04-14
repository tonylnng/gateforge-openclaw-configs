#!/usr/bin/env bash
# =============================================================================
# GateForge — Communication Connectivity Test
# =============================================================================
# Run this on VM-1 (Architect) after ALL VMs have completed setup.
# Tests: network reachability, gateway auth, HMAC notification, round-trip.
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
TEAL='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

PASS=0
FAIL=0
WARN=0

CONFIG_FILE="/opt/secrets/gateforge.env"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
result_pass() { echo -e "  ${GREEN}✓ PASS${RESET}  $1"; PASS=$((PASS + 1)); }
result_fail() { echo -e "  ${RED}✗ FAIL${RESET}  $1"; FAIL=$((FAIL + 1)); }
result_warn() { echo -e "  ${YELLOW}! WARN${RESET}  $1"; WARN=$((WARN + 1)); }

print_header() {
  echo ""
  echo -e "${TEAL}${BOLD}═══ $1 ═══${RESET}"
}

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------
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
echo -e "  ${DIM}Communication Connectivity Test${RESET}"
echo -e "  ${DIM}Run this on VM-1 (Architect) after all VMs are set up.${RESET}"
echo ""

# ---------------------------------------------------------------------------
# Step 0: Load config
# ---------------------------------------------------------------------------
print_header "Loading Configuration"

if [[ ! -f "$CONFIG_FILE" ]]; then
  result_fail "Config file not found: ${CONFIG_FILE}"
  echo -e "\n  Run ${TEAL}sudo bash setup-vm1-architect.sh${RESET} first."
  exit 1
fi

# Need sudo to read the config
eval "$(sudo cat "$CONFIG_FILE" | grep -v '^#' | grep '=')" 2>/dev/null
result_pass "Loaded ${CONFIG_FILE}"

# Validate required variables
REQUIRED_VARS="GATEFORGE_ROLE GATEFORGE_VM_HOST GATEFORGE_PORT ARCHITECT_HOOK_TOKEN VM2_IP VM2_GATEWAY_TOKEN VM2_AGENT_SECRET VM3_IP VM3_GATEWAY_TOKEN VM3_AGENT_SECRET VM4_IP VM4_GATEWAY_TOKEN VM4_AGENT_SECRET VM5_IP VM5_GATEWAY_TOKEN VM5_AGENT_SECRET"

for var in $REQUIRED_VARS; do
  if [[ -z "${!var:-}" ]]; then
    result_fail "Missing variable: ${var}"
  fi
done

if [[ "${GATEFORGE_ROLE}" != "architect" ]]; then
  result_fail "This script must run on VM-1 (Architect). Current role: ${GATEFORGE_ROLE}"
  exit 1
fi

result_pass "Role confirmed: Architect"
echo ""
echo -e "  ${DIM}Architect:  ${GATEFORGE_VM_HOST}:${GATEFORGE_PORT}${RESET}"
echo -e "  ${DIM}VM-2:       ${VM2_IP}${RESET}"
echo -e "  ${DIM}VM-3:       ${VM3_IP}${RESET}"
echo -e "  ${DIM}VM-4:       ${VM4_IP}${RESET}"
echo -e "  ${DIM}VM-5:       ${VM5_IP}${RESET}"

# ---------------------------------------------------------------------------
# SSH Credentials — collect per-VM username and password
# ---------------------------------------------------------------------------
print_header "SSH Credentials for Spoke VMs"

echo -e "  ${DIM}Enter SSH credentials for each spoke VM.${RESET}"
echo -e "  ${DIM}These are used for pre-flight checks and Test 6 (config verification).${RESET}"
echo -e "  ${DIM}Leave password blank to use SSH key auth instead.${RESET}"
echo ""

# Check sshpass availability (needed for password auth)
HAS_SSHPASS=false
if command -v sshpass &>/dev/null; then
  HAS_SSHPASS=true
fi

# Associative arrays for per-VM credentials
declare -A VM_SSH_USER
declare -A VM_SSH_PASS

for vm in 2 3 4 5; do
  eval vm_ip=\$VM${vm}_IP
  role=""
  case $vm in
    2) role="Designer" ;;
    3) role="Developers" ;;
    4) role="QC Agents" ;;
    5) role="Operator" ;;
  esac

  # Read username
  default_user="${SUDO_USER:-$(whoami)}"
  read -rp "  VM-${vm} ${role} (${vm_ip}) — SSH user [${default_user}]: " input_user
  VM_SSH_USER[$vm]="${input_user:-$default_user}"

  # Read password (hidden input)
  read -rsp "  VM-${vm} ${role} (${vm_ip}) — SSH password (blank=key auth): " input_pass
  echo ""  # newline after hidden input
  VM_SSH_PASS[$vm]="${input_pass}"

  if [[ -n "${VM_SSH_PASS[$vm]}" && "$HAS_SSHPASS" != "true" ]]; then
    echo -e "  ${YELLOW}! sshpass not installed — password auth will not work.${RESET}"
    echo -e "  ${DIM}  Install: sudo apt install sshpass${RESET}"
    VM_SSH_PASS[$vm]=""  # fall back to key auth
  fi
done

echo ""
echo -e "  ${DIM}Credentials collected:${RESET}"
for vm in 2 3 4 5; do
  eval vm_ip=\$VM${vm}_IP
  auth_mode="key"
  [[ -n "${VM_SSH_PASS[$vm]}" ]] && auth_mode="password"
  echo -e "  ${DIM}  VM-${vm} (${vm_ip}): user=${VM_SSH_USER[$vm]}, auth=${auth_mode}${RESET}"
done

# ---------------------------------------------------------------------------
# Helper: SSH to a spoke VM using the collected credentials
# ---------------------------------------------------------------------------
ssh_to_vm() {
  local vm_num="$1"
  shift
  local user="${VM_SSH_USER[$vm_num]}"
  local pass="${VM_SSH_PASS[$vm_num]}"
  eval local ip=\$VM${vm_num}_IP

  if [[ -n "$pass" ]]; then
    sshpass -p "$pass" ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "${user}@${ip}" "$@" 2>/dev/null
  else
    ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "${user}@${ip}" "$@" 2>/dev/null
  fi
}

# ---------------------------------------------------------------------------
# Pre-flight: Verify webhooks are enabled in openclaw.json
# ---------------------------------------------------------------------------
print_header "Pre-flight: Webhook Configuration"

# Resolve the OpenClaw user — the user running OpenClaw (not root)
OC_USER="${SUDO_USER:-$(whoami)}"
OC_HOME=$(eval echo "~${OC_USER}")
OC_CONFIG="${OC_HOME}/.openclaw/openclaw.json"

HOOKS_OK_LOCAL=false

# --- Helper function to parse openclaw.json ---
check_hooks_config() {
  local config_file="$1"
  if command -v python3 &>/dev/null; then
    python3 -c "
import json, sys
try:
    with open('${config_file}') as f:
        cfg = json.load(f)
    enabled = cfg.get('hooks', {}).get('enabled', False)
    token = cfg.get('hooks', {}).get('token', '')
    print(f'{enabled}|{len(token) > 0}')
except: print('error|error')
" 2>/dev/null || echo "error|error"
  else
    local e="False" t="False"
    grep -q '"enabled".*true' "$config_file" 2>/dev/null && e="True"
    grep -q '"token"' "$config_file" 2>/dev/null && t="True"
    echo "${e}|${t}"
  fi
}

# Check local VM-1
if [[ -f "$OC_CONFIG" ]]; then
  HOOKS_ENABLED=$(check_hooks_config "$OC_CONFIG")
  H_ENABLED="${HOOKS_ENABLED%%|*}"
  H_HAS_TOKEN="${HOOKS_ENABLED##*|}"

  if [[ "$H_ENABLED" == "True" && "$H_HAS_TOKEN" == "True" ]]; then
    result_pass "VM-1 (local) — webhooks enabled with token in ${OC_CONFIG}"
    HOOKS_OK_LOCAL=true
  elif [[ "$H_ENABLED" == "True" && "$H_HAS_TOKEN" != "True" ]]; then
    result_fail "VM-1 (local) — hooks.enabled=true but hooks.token is missing"
  elif [[ "$H_ENABLED" == "error" ]]; then
    result_warn "VM-1 (local) — could not parse ${OC_CONFIG} (check JSON syntax)"
  else
    result_fail "VM-1 (local) — webhooks NOT enabled in ${OC_CONFIG}"
    echo -e "  ${DIM}Fix: Add to ${OC_CONFIG}:${RESET}"
    echo -e "  ${DIM}  { \"hooks\": { \"enabled\": true, \"token\": \"<GATEWAY_AUTH_TOKEN>\", \"path\": \"/hooks\" } }${RESET}"
    echo -e "  ${DIM}Then: openclaw daemon restart${RESET}"
  fi
else
  result_fail "VM-1 (local) — ${OC_CONFIG} not found"
  echo -e "  ${DIM}Expected OpenClaw config at: ${OC_CONFIG}${RESET}"
  echo -e "  ${DIM}Detected user: ${OC_USER}${RESET}"
fi

# Check spoke VMs remotely via SSH
HOOKS_OK_REMOTE=true

for vm in 2 3 4 5; do
  eval ip=\$VM${vm}_IP
  label="VM-${vm}"

  REMOTE_CHECK=$(ssh_to_vm "$vm" "
    OC_CFG=\"\$(eval echo ~\$(whoami))/.openclaw/openclaw.json\"
    if [ ! -f \"\$OC_CFG\" ]; then echo 'nofile'; exit; fi
    if command -v python3 >/dev/null 2>&1; then
      python3 -c \"import json; cfg=json.load(open('\$OC_CFG')); h=cfg.get('hooks',{}); print(str(h.get('enabled',False))+'|'+str(len(h.get('token',''))>0))\" 2>/dev/null || echo 'error'
    else
      E=\$(grep -c '\"enabled\".*true' \"\$OC_CFG\" 2>/dev/null || echo 0)
      T=\$(grep -c '\"token\"' \"\$OC_CFG\" 2>/dev/null || echo 0)
      [ \"\$E\" -gt 0 ] && e='True' || e='False'
      [ \"\$T\" -gt 0 ] && t='True' || t='False'
      echo \"\$e|\$t\"
    fi
  " || echo "ssh_fail")

  if [[ "$REMOTE_CHECK" == "ssh_fail" ]]; then
    result_warn "${label} (${ip}) — SSH failed (check user/password for ${VM_SSH_USER[$vm]}@${ip})"
  elif [[ "$REMOTE_CHECK" == "nofile" ]]; then
    result_fail "${label} (${ip}) — openclaw.json not found"
    HOOKS_OK_REMOTE=false
  elif [[ "$REMOTE_CHECK" == "True|True" ]]; then
    result_pass "${label} (${ip}) — webhooks enabled with token"
  elif [[ "$REMOTE_CHECK" == "True|False" ]]; then
    result_fail "${label} (${ip}) — hooks.enabled=true but hooks.token is missing"
    HOOKS_OK_REMOTE=false
  elif [[ "$REMOTE_CHECK" == "error" ]]; then
    result_warn "${label} (${ip}) — could not parse openclaw.json"
  else
    result_fail "${label} (${ip}) — webhooks NOT enabled (hooks.enabled is not true)"
    HOOKS_OK_REMOTE=false
  fi
done

if [[ "$HOOKS_OK_LOCAL" != "true" || "$HOOKS_OK_REMOTE" != "true" ]]; then
  echo ""
  echo -e "  ${YELLOW}${BOLD}Webhook tests (3-5) will fail until hooks are enabled on all VMs.${RESET}"
  echo -e "  ${YELLOW}Continuing with remaining tests...${RESET}"
fi

# ---------------------------------------------------------------------------
# Test 1: Network Reachability (ping via Tailscale)
# ---------------------------------------------------------------------------
print_header "Test 1: Network Reachability"

for entry in "VM-2:${VM2_IP}" "VM-3:${VM3_IP}" "VM-4:${VM4_IP}" "VM-5:${VM5_IP}"; do
  label="${entry%%:*}"
  ip="${entry##*:}"
  if ping -c 1 -W 2 "$ip" &>/dev/null; then
    result_pass "${label} (${ip}) — reachable"
  else
    result_fail "${label} (${ip}) — not reachable (check Tailscale)"
  fi
done

# ---------------------------------------------------------------------------
# Test 2: Gateway Port Open (HTTP health check)
# ---------------------------------------------------------------------------
print_header "Test 2: Gateway Port 18789 Responding"

for entry in "VM-1 (self):${GATEFORGE_VM_HOST}" "VM-2:${VM2_IP}" "VM-3:${VM3_IP}" "VM-4:${VM4_IP}" "VM-5:${VM5_IP}"; do
  label="${entry%%:*}"
  ip="${entry##*:}"
  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "http://${ip}:${GATEFORGE_PORT}/health" 2>/dev/null || echo "000")
  if [[ "$code" == "200" ]]; then
    result_pass "${label} (${ip}:${GATEFORGE_PORT}) — HTTP 200"
  elif [[ "$code" == "000" ]]; then
    result_fail "${label} (${ip}:${GATEFORGE_PORT}) — connection refused or timeout"
  else
    result_warn "${label} (${ip}:${GATEFORGE_PORT}) — HTTP ${code} (gateway up but unexpected status)"
  fi
done

# ---------------------------------------------------------------------------
# Test 3: Task Dispatch — Architect → Each Spoke
# ---------------------------------------------------------------------------
print_header "Test 3: Task Dispatch (Architect → Spoke)"

for vm in 2 3 4 5; do
  eval ip=\$VM${vm}_IP
  eval token=\$VM${vm}_GATEWAY_TOKEN

  role=""
  case $vm in
    2) role="designer" ;;
    3) role="developers" ;;
    4) role="qc-agents" ;;
    5) role="operator" ;;
  esac

  RESPONSE=$(curl -s -w "\n%{http_code}" --max-time 5 \
    -X POST "http://${ip}:${GATEFORGE_PORT}/hooks/agent" \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d '{"name":"agent-task","agentId":"'${role}'","message":"[TEST] GateForge connectivity test from Architect. No action required.","sessionKey":"test:connectivity:vm'${vm}'"}' 2>/dev/null || echo -e "\n000")

  BODY=$(echo "$RESPONSE" | head -n -1)
  code=$(echo "$RESPONSE" | tail -1)

  if [[ "$code" == "200" || "$code" == "202" ]]; then
    result_pass "Architect → VM-${vm} ${role} (${ip}) — HTTP ${code}"
  elif [[ "$code" == "401" ]]; then
    result_fail "Architect → VM-${vm} ${role} (${ip}) — HTTP 401 (wrong gateway token)"
  elif [[ "$code" == "404" ]]; then
    result_fail "Architect → VM-${vm} ${role} (${ip}) — HTTP 404 (webhooks not enabled — check hooks.enabled in ~/.openclaw/openclaw.json)"
  elif [[ "$code" == "000" ]]; then
    result_fail "Architect → VM-${vm} ${role} (${ip}) — connection refused"
  else
    result_warn "Architect → VM-${vm} ${role} (${ip}) — HTTP ${code}"
    if [[ -n "$BODY" ]]; then
      echo -e "  ${DIM}Response: ${BODY}${RESET}"
    fi
  fi
done

# ---------------------------------------------------------------------------
# Test 4: HMAC Notification — Simulate Spoke → Architect
# ---------------------------------------------------------------------------
print_header "Test 4: HMAC Notification (Simulated Spoke → Architect)"

ARCHITECT_HOOK_URL="${ARCHITECT_NOTIFY_URL:-http://${GATEFORGE_VM_HOST}:${GATEFORGE_PORT}/hooks/agent}"
echo -e "  ${DIM}Target: ${ARCHITECT_HOOK_URL}${RESET}"

for vm in 2 3 4 5; do
  eval secret=\$VM${vm}_AGENT_SECRET

  role=""
  case $vm in
    2) role="designer" ;;
    3) role="developers" ;;
    4) role="qc-agents" ;;
    5) role="operator" ;;
  esac

  TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  PAYLOAD='{"name":"agent-notify","agentId":"architect","message":"[INFO] Connectivity test from '${role}'","metadata":{"sourceVm":"vm-'${vm}'","sourceRole":"'${role}'","priority":"INFO","taskId":"TEST-'${vm}'","timestamp":"'${TIMESTAMP}'"}}'
  SIGNATURE=$(echo -n "${PAYLOAD}" | openssl dgst -sha256 -hmac "${secret}" | awk '{print $2}')

  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
    -X POST "${ARCHITECT_HOOK_URL}" \
    -H "Authorization: Bearer ${ARCHITECT_HOOK_TOKEN}" \
    -H "X-Agent-Signature: ${SIGNATURE}" \
    -H "X-Source-VM: vm-${vm}" \
    -H "Content-Type: application/json" \
    -d "${PAYLOAD}" 2>/dev/null || echo "000")

  if [[ "$code" == "200" || "$code" == "202" ]]; then
    result_pass "VM-${vm} ${role} → Architect — HTTP ${code} (HMAC valid)"
  elif [[ "$code" == "401" ]]; then
    result_fail "VM-${vm} ${role} → Architect — HTTP 401 (hook token wrong)"
  elif [[ "$code" == "404" ]]; then
    result_fail "VM-${vm} ${role} → Architect — HTTP 404 (webhooks not enabled — see fix below)"
  elif [[ "$code" == "000" ]]; then
    result_fail "VM-${vm} ${role} → Architect — connection refused"
  else
    result_warn "VM-${vm} ${role} → Architect — HTTP ${code}"
  fi
done

# ---------------------------------------------------------------------------
# Test 5: HMAC Rejection — Wrong Secret (Security Verification)
# ---------------------------------------------------------------------------
print_header "Test 5: HMAC Rejection (Wrong Secret — Should Fail)"

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
PAYLOAD='{"name":"agent-notify","agentId":"architect","message":"[INFO] Bad secret test","metadata":{"sourceVm":"vm-2","sourceRole":"designer","priority":"INFO","taskId":"TEST-BAD","timestamp":"'${TIMESTAMP}'"}}'
# Sign with a FAKE secret
FAKE_SIGNATURE=$(echo -n "${PAYLOAD}" | openssl dgst -sha256 -hmac "0000000000000000000000000000000000000000000000000000000000000000" | awk '{print $2}')

code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
  -X POST "${ARCHITECT_HOOK_URL}" \
  -H "Authorization: Bearer ${ARCHITECT_HOOK_TOKEN}" \
  -H "X-Agent-Signature: ${FAKE_SIGNATURE}" \
  -H "X-Source-VM: vm-2" \
  -H "Content-Type: application/json" \
  -d "${PAYLOAD}" 2>/dev/null || echo "000")

if [[ "$code" == "401" || "$code" == "403" ]]; then
  result_pass "Fake HMAC correctly rejected — HTTP ${code}"
elif [[ "$code" == "200" || "$code" == "202" ]]; then
  result_warn "Fake HMAC was ACCEPTED — HTTP ${code} (Architect may not be validating HMAC yet)"
elif [[ "$code" == "404" ]]; then
  result_fail "HTTP 404 — webhooks not enabled (fix Tests 3/4 first — same root cause)"
else
  result_warn "Unexpected response to fake HMAC — HTTP ${code}"
fi

# ---------------------------------------------------------------------------
# Test 6: Config File Presence on Each VM (via SSH)
# ---------------------------------------------------------------------------
print_header "Test 6: Config Files on Spoke VMs (via SSH)"

for vm in 2 3 4 5; do
  eval ip=\$VM${vm}_IP
  label="VM-${vm}"

  # Use sudo on remote to check the root-owned config file
  if ssh_to_vm "$vm" "sudo test -f /opt/secrets/gateforge.env"; then
    result_pass "${label} (${ip}) — /opt/secrets/gateforge.env exists"
  elif ssh_to_vm "$vm" "echo ok" &>/dev/null; then
    result_warn "${label} (${ip}) — SSH works but /opt/secrets/gateforge.env not found (or sudo not available)"
  else
    result_warn "${label} (${ip}) — SSH not available for ${VM_SSH_USER[$vm]}@${ip} (skipped — test manually)"
  fi
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
print_header "Test Summary"

TOTAL=$((PASS + FAIL + WARN))
echo ""
echo -e "  ${GREEN}${BOLD}Passed:${RESET}   ${PASS}/${TOTAL}"
echo -e "  ${RED}${BOLD}Failed:${RESET}   ${FAIL}/${TOTAL}"
echo -e "  ${YELLOW}${BOLD}Warnings:${RESET} ${WARN}/${TOTAL}"
echo ""

if [[ $FAIL -eq 0 ]]; then
  echo -e "  ${GREEN}${BOLD}╔════════════════════════════════════════════════════╗${RESET}"
  echo -e "  ${GREEN}${BOLD}║  ALL TESTS PASSED — GateForge communication OK    ║${RESET}"
  echo -e "  ${GREEN}${BOLD}╚════════════════════════════════════════════════════╝${RESET}"
elif [[ $FAIL -le 2 ]]; then
  echo -e "  ${YELLOW}${BOLD}╔════════════════════════════════════════════════════╗${RESET}"
  echo -e "  ${YELLOW}${BOLD}║  PARTIAL — some tests failed, check details above ║${RESET}"
  echo -e "  ${YELLOW}${BOLD}╚════════════════════════════════════════════════════╝${RESET}"
else
  echo -e "  ${RED}${BOLD}╔════════════════════════════════════════════════════╗${RESET}"
  echo -e "  ${RED}${BOLD}║  MULTIPLE FAILURES — check setup on failed VMs    ║${RESET}"
  echo -e "  ${RED}${BOLD}╚════════════════════════════════════════════════════╝${RESET}"
fi

echo ""
echo -e "  ${DIM}Troubleshooting:${RESET}"
echo -e "  ${DIM}  Network:   tailscale ping <hostname>${RESET}"
echo -e "  ${DIM}  Port:      ssh <vm-ip> 'ss -tlnp | grep 18789'${RESET}"
echo -e "  ${DIM}  Logs:      ssh <vm-ip> 'journalctl -u openclaw-gateforge -n 20'${RESET}"
echo -e "  ${DIM}  Config:    ssh <vm-ip> 'sudo cat /opt/secrets/gateforge.env'${RESET}"
echo ""
echo -e "  ${DIM}If Tests 3-5 return HTTP 404 — webhooks are not enabled in OpenClaw.${RESET}"
echo -e "  ${DIM}Fix: On EACH VM, ensure ~/.openclaw/openclaw.json contains:${RESET}"
echo -e "  ${DIM}  {${RESET}"
echo -e "  ${DIM}    \"hooks\": {${RESET}"
echo -e "  ${DIM}      \"enabled\": true,${RESET}"
echo -e "  ${DIM}      \"token\": \"<GATEWAY_AUTH_TOKEN from gateforge.env>\",${RESET}"
echo -e "  ${DIM}      \"path\": \"/hooks\"${RESET}"
echo -e "  ${DIM}    }${RESET}"
echo -e "  ${DIM}  }${RESET}"
echo -e "  ${DIM}Then restart: openclaw daemon restart${RESET}"
echo ""

exit $FAIL

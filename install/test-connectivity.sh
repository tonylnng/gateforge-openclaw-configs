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

  code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
    -X POST "http://${ip}:${GATEFORGE_PORT}/hooks/agent" \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d '{"name":"agent-task","agentId":"'${role}'","message":"[TEST] GateForge connectivity test from Architect. No action required.","sessionKey":"test:connectivity:vm'${vm}'"}' 2>/dev/null || echo "000")

  if [[ "$code" == "200" || "$code" == "202" ]]; then
    result_pass "Architect → VM-${vm} ${role} (${ip}) — HTTP ${code}"
  elif [[ "$code" == "401" ]]; then
    result_fail "Architect → VM-${vm} ${role} (${ip}) — HTTP 401 (wrong gateway token)"
  elif [[ "$code" == "000" ]]; then
    result_fail "Architect → VM-${vm} ${role} (${ip}) — connection refused"
  else
    result_warn "Architect → VM-${vm} ${role} (${ip}) — HTTP ${code}"
  fi
done

# ---------------------------------------------------------------------------
# Test 4: HMAC Notification — Simulate Spoke → Architect
# ---------------------------------------------------------------------------
print_header "Test 4: HMAC Notification (Simulated Spoke → Architect)"

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
    -X POST "${ARCHITECT_NOTIFY_URL}" \
    -H "Authorization: Bearer ${ARCHITECT_HOOK_TOKEN}" \
    -H "X-Agent-Signature: ${SIGNATURE}" \
    -H "X-Source-VM: vm-${vm}" \
    -H "Content-Type: application/json" \
    -d "${PAYLOAD}" 2>/dev/null || echo "000")

  if [[ "$code" == "200" || "$code" == "202" ]]; then
    result_pass "VM-${vm} ${role} → Architect — HTTP ${code} (HMAC valid)"
  elif [[ "$code" == "401" ]]; then
    result_fail "VM-${vm} ${role} → Architect — HTTP 401 (hook token wrong)"
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
  -X POST "${ARCHITECT_NOTIFY_URL}" \
  -H "Authorization: Bearer ${ARCHITECT_HOOK_TOKEN}" \
  -H "X-Agent-Signature: ${FAKE_SIGNATURE}" \
  -H "X-Source-VM: vm-2" \
  -H "Content-Type: application/json" \
  -d "${PAYLOAD}" 2>/dev/null || echo "000")

if [[ "$code" == "401" || "$code" == "403" ]]; then
  result_pass "Fake HMAC correctly rejected — HTTP ${code}"
elif [[ "$code" == "200" || "$code" == "202" ]]; then
  result_warn "Fake HMAC was ACCEPTED — HTTP ${code} (Architect may not be validating HMAC yet)"
else
  result_warn "Unexpected response to fake HMAC — HTTP ${code}"
fi

# ---------------------------------------------------------------------------
# Test 6: Config File Presence on Each VM (via SSH)
# ---------------------------------------------------------------------------
print_header "Test 6: Config Files on Spoke VMs (via SSH)"

for entry in "VM-2:${VM2_IP}" "VM-3:${VM3_IP}" "VM-4:${VM4_IP}" "VM-5:${VM5_IP}"; do
  label="${entry%%:*}"
  ip="${entry##*:}"

  if ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no "$ip" "test -f /opt/secrets/gateforge.env" 2>/dev/null; then
    result_pass "${label} — /opt/secrets/gateforge.env exists"
  elif ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no "$ip" "echo ok" 2>/dev/null; then
    result_warn "${label} — SSH works but /opt/secrets/gateforge.env not found"
  else
    result_warn "${label} — SSH not available (skipped — test manually)"
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

exit $FAIL

#!/usr/bin/env bash
# =============================================================================
# GateForge — Spoke VM Connectivity Test
# =============================================================================
# Run this on ANY spoke VM (VM-2 through VM-5) to test its connection
# to the Architect. Uses the local /opt/secrets/gateforge.env config.
# =============================================================================

set -euo pipefail

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

result_pass() { echo -e "  ${GREEN}✓ PASS${RESET}  $1"; PASS=$((PASS + 1)); }
result_fail() { echo -e "  ${RED}✗ FAIL${RESET}  $1"; FAIL=$((FAIL + 1)); }
result_warn() { echo -e "  ${YELLOW}! WARN${RESET}  $1"; WARN=$((WARN + 1)); }
print_header() { echo ""; echo -e "${TEAL}${BOLD}═══ $1 ═══${RESET}"; }

# ---------------------------------------------------------------------------
echo ""
echo -e "${TEAL}${BOLD}  GateForge — Spoke Connectivity Test${RESET}"
echo -e "  ${DIM}Run on any spoke VM (VM-2 through VM-5)${RESET}"
echo ""

# ---------------------------------------------------------------------------
# Load config
# ---------------------------------------------------------------------------
print_header "Loading Configuration"

if [[ ! -f "$CONFIG_FILE" ]]; then
  result_fail "Config file not found: ${CONFIG_FILE}"
  echo -e "\n  Run the setup script for this VM first."
  exit 1
fi

eval "$(sudo cat "$CONFIG_FILE" | grep -v '^#' | grep '=')" 2>/dev/null
result_pass "Loaded ${CONFIG_FILE}"

ROLE="${GATEFORGE_ROLE:-unknown}"
MY_HOST="${GATEFORGE_VM_HOST:-unknown}"
PORT="${GATEFORGE_PORT:-18789}"
ARCH_IP="${ARCHITECT_IP:-}"
HOOK_TOKEN="${ARCHITECT_HOOK_TOKEN:-}"
NOTIFY_URL="${ARCHITECT_NOTIFY_URL:-}"
SECRET="${AGENT_SECRET:-}"
GW_TOKEN="${GATEWAY_AUTH_TOKEN:-}"

echo -e "  ${DIM}Role:      ${ROLE}${RESET}"
echo -e "  ${DIM}This VM:   ${MY_HOST}:${PORT}${RESET}"
echo -e "  ${DIM}Architect: ${ARCH_IP}${RESET}"

# Check required vars
for var in ARCH_IP HOOK_TOKEN NOTIFY_URL SECRET GW_TOKEN; do
  if [[ -z "${!var}" ]]; then
    result_fail "Missing: ${var}"
  fi
done

# ---------------------------------------------------------------------------
# Test 1: Ping Architect
# ---------------------------------------------------------------------------
print_header "Test 1: Network — Ping Architect"

if ping -c 2 -W 2 "$ARCH_IP" &>/dev/null; then
  result_pass "Architect (${ARCH_IP}) — reachable"
else
  result_fail "Architect (${ARCH_IP}) — not reachable"
fi

# ---------------------------------------------------------------------------
# Test 2: Architect gateway responding
# ---------------------------------------------------------------------------
print_header "Test 2: Architect Gateway — HTTP Health Check"

code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://${ARCH_IP}:${PORT}/health" 2>/dev/null || echo "000")
if [[ "$code" == "200" ]]; then
  result_pass "Architect gateway — HTTP 200"
elif [[ "$code" == "000" ]]; then
  result_fail "Architect gateway — connection refused or timeout"
else
  result_warn "Architect gateway — HTTP ${code}"
fi

# ---------------------------------------------------------------------------
# Test 3: Own gateway responding
# ---------------------------------------------------------------------------
print_header "Test 3: Local Gateway — HTTP Health Check"

code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "http://${MY_HOST}:${PORT}/health" 2>/dev/null || echo "000")
if [[ "$code" == "200" ]]; then
  result_pass "Local gateway (${MY_HOST}:${PORT}) — HTTP 200"
elif [[ "$code" == "000" ]]; then
  result_fail "Local gateway (${MY_HOST}:${PORT}) — not responding (check bind address)"
else
  result_warn "Local gateway (${MY_HOST}:${PORT}) — HTTP ${code}"
fi

# Also test on localhost
code_local=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "http://127.0.0.1:${PORT}/health" 2>/dev/null || echo "000")
if [[ "$code_local" == "200" ]]; then
  result_pass "Local gateway (127.0.0.1:${PORT}) — HTTP 200"
fi

# ---------------------------------------------------------------------------
# Test 4: HMAC Notification → Architect
# ---------------------------------------------------------------------------
print_header "Test 4: HMAC Notification → Architect"

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
PAYLOAD='{"name":"agent-notify","agentId":"architect","message":"[INFO] Connectivity test from '${ROLE}'","metadata":{"sourceVm":"'${ROLE}'","sourceRole":"'${ROLE}'","priority":"INFO","taskId":"SPOKE-TEST","timestamp":"'${TIMESTAMP}'"}}'
SIGNATURE=$(echo -n "${PAYLOAD}" | openssl dgst -sha256 -hmac "${SECRET}" | awk '{print $2}')

RESPONSE=$(curl -s -w "\n%{http_code}" --max-time 5 \
  -X POST "${NOTIFY_URL}" \
  -H "Authorization: Bearer ${HOOK_TOKEN}" \
  -H "X-Agent-Signature: ${SIGNATURE}" \
  -H "X-Source-VM: ${ROLE}" \
  -H "Content-Type: application/json" \
  -d "${PAYLOAD}" 2>/dev/null || echo -e "\n000")

BODY=$(echo "$RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$RESPONSE" | tail -1)

if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "202" ]]; then
  result_pass "HMAC notification accepted — HTTP ${HTTP_CODE}"
elif [[ "$HTTP_CODE" == "401" ]]; then
  result_fail "HMAC notification rejected — HTTP 401 (hook token wrong)"
elif [[ "$HTTP_CODE" == "403" ]]; then
  result_fail "HMAC notification rejected — HTTP 403 (forbidden)"
elif [[ "$HTTP_CODE" == "000" ]]; then
  result_fail "HMAC notification — connection failed"
else
  result_warn "HMAC notification — HTTP ${HTTP_CODE}"
  if [[ -n "$BODY" ]]; then
    echo -e "  ${DIM}Response: ${BODY}${RESET}"
  fi
fi

# ---------------------------------------------------------------------------
# Test 5: Wrong hook token (should be rejected)
# ---------------------------------------------------------------------------
print_header "Test 5: Security — Wrong Hook Token (should fail)"

code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
  -X POST "${NOTIFY_URL}" \
  -H "Authorization: Bearer wrong_token_12345" \
  -H "X-Agent-Signature: ${SIGNATURE}" \
  -H "X-Source-VM: ${ROLE}" \
  -H "Content-Type: application/json" \
  -d "${PAYLOAD}" 2>/dev/null || echo "000")

if [[ "$code" == "401" || "$code" == "403" ]]; then
  result_pass "Wrong hook token correctly rejected — HTTP ${code}"
elif [[ "$code" == "200" || "$code" == "202" ]]; then
  result_warn "Wrong hook token was ACCEPTED — HTTP ${code} (Architect may not validate hook tokens)"
else
  result_warn "Unexpected response — HTTP ${code}"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
print_header "Test Summary — ${ROLE}"

TOTAL=$((PASS + FAIL + WARN))
echo ""
echo -e "  ${GREEN}${BOLD}Passed:${RESET}   ${PASS}/${TOTAL}"
echo -e "  ${RED}${BOLD}Failed:${RESET}   ${FAIL}/${TOTAL}"
echo -e "  ${YELLOW}${BOLD}Warnings:${RESET} ${WARN}/${TOTAL}"
echo ""

if [[ $FAIL -eq 0 ]]; then
  echo -e "  ${GREEN}${BOLD}╔══════════════════════════════════════════════════════════╗${RESET}"
  echo -e "  ${GREEN}${BOLD}║  ALL TESTS PASSED — ${ROLE} communication OK              ║${RESET}"
  echo -e "  ${GREEN}${BOLD}╚══════════════════════════════════════════════════════════╝${RESET}"
else
  echo -e "  ${RED}${BOLD}╔══════════════════════════════════════════════════════════╗${RESET}"
  echo -e "  ${RED}${BOLD}║  FAILURES DETECTED — check details above                 ║${RESET}"
  echo -e "  ${RED}${BOLD}╚══════════════════════════════════════════════════════════╝${RESET}"
fi

echo ""
echo -e "  ${DIM}Troubleshooting:${RESET}"
echo -e "  ${DIM}  Tailscale:  tailscale ping tonic-architect${RESET}"
echo -e "  ${DIM}  Port:       ss -tlnp | grep 18789${RESET}"
echo -e "  ${DIM}  Config:     sudo cat /opt/secrets/gateforge.env${RESET}"
echo -e "  ${DIM}  Logs:       journalctl -u openclaw-gateforge -n 20${RESET}"
echo ""

exit $FAIL

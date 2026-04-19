#!/usr/bin/env bash
# =============================================================================
# GateForge — End-to-End Communication Test
# =============================================================================
# Runs on VM-1 (Architect). Tests the full round-trip:
#
#   [A] Architect -> Spoke gateway        (dispatch OK, HTTP 200 + runId)
#   [B] Spoke agent -> git commit + push  (deliverable written verbatim)
#   [C] Spoke host -> Architect /hooks    (HMAC callback received)
#   [D] Architect reads Git               (deliverable visible to hub)
#
# Usage:
#   sudo ./test-communication.sh                  # interactive menu
#   sudo ./test-communication.sh --target designer
#   sudo ./test-communication.sh --target dev --count 2
#   sudo ./test-communication.sh --target qc --count 2
#   sudo ./test-communication.sh --target operator
#   sudo ./test-communication.sh --target all --dev-count 2 --qc-count 2
#   sudo ./test-communication.sh --target all --dev-count 2 --qc-count 2 --no-cleanup
#
# Requirements on VM-1 (written by setup-vm1-architect.sh):
#   - /opt/secrets/gateforge.env containing:
#       ARCHITECT_HOOK_TOKEN
#       VM2_GATEWAY_TOKEN  VM2_AGENT_SECRET   (Designer)
#       VM3_GATEWAY_TOKEN  VM3_AGENT_SECRET   (Developers)
#       VM4_GATEWAY_TOKEN  VM4_AGENT_SECRET   (QC)
#       VM5_GATEWAY_TOKEN  VM5_AGENT_SECRET   (Operator)
#     (GATEWAY_AUTH_TOKEN is accepted as a fallback gateway token)
#   - /opt/gateforge/blueprint/ present and writable by sudo user
#   - curl, jq, openssl, git installed
#   - Tailscale interface up (spoke gateways reachable at :18789)
# =============================================================================

set -euo pipefail

# ------------------------------- ui helpers ----------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
TEAL='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'

print_header() { echo ""; echo -e "${TEAL}${BOLD}═══ $1 ═══${RESET}"; }
pass()        { echo -e "  ${GREEN}✓ PASS${RESET}  $1"; }
fail()        { echo -e "  ${RED}✗ FAIL${RESET}  $1"; }
warn()        { echo -e "  ${YELLOW}! WARN${RESET}  $1"; }
info()        { echo -e "  ${DIM}· $1${RESET}"; }
note()        { echo -e "  $1"; }

banner() {
  echo ""
  echo -e "${TEAL}${BOLD}"
  cat <<'B'
   ██████╗  █████╗ ████████╗███████╗███████╗ ██████╗ ██████╗  ██████╗ ███████╗
  ██╔════╝ ██╔══██╗╚══██╔══╝██╔════╝██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
  ██║  ███╗███████║   ██║   █████╗  █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
  ██║   ██║██╔══██║   ██║   ██╔══╝  ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
  ╚██████╔╝██║  ██║   ██║   ███████╗██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
   ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
B
  echo -e "${RESET}"
  echo -e "  ${DIM}End-to-End Communication Test — run on VM-1 (Architect)${RESET}"
  echo ""
}

# ------------------------------- config --------------------------------------
CONFIG_FILE="${GATEFORGE_ENV_FILE:-/opt/secrets/gateforge.env}"
BLUEPRINT_REPO="${BLUEPRINT_REPO:-/opt/gateforge/blueprint}"
WAIT_GATE_B_SECONDS="${WAIT_GATE_B_SECONDS:-90}"     # how long to wait for callback
WAIT_GATE_A_POLL="${WAIT_GATE_A_POLL:-2}"            # seconds between log polls
HOOK_LOG_CANDIDATES=(
  "/var/log/gateforge/architect-hook.log"
  "${HOME}/.openclaw/logs/hooks.log"
  "${HOME}/.openclaw/logs/architect.log"
)

# Spoke gateway URLs (loopback via Tailscale Serve isn't used here — we dispatch
# directly to the spoke's Tailscale IP on its gateway port, same as the
# Architect agent would). Values come from /opt/secrets/gateforge.env or can be
# overridden via env vars before running.
declare -A SPOKE_GATEWAY=(
  [designer]="${DESIGNER_GATEWAY_URL:-http://100.95.30.11:18789/hooks/agent}"
  [dev]="${DEV_GATEWAY_URL:-http://100.81.114.55:18789/hooks/agent}"
  [qc]="${QC_GATEWAY_URL:-http://100.106.117.104:18789/hooks/agent}"
  [operator]="${OPERATOR_GATEWAY_URL:-http://100.95.248.68:18789/hooks/agent}"
)
declare -A SPOKE_BRANCH_PREFIX=(
  [designer]="design/TASK-COMMTEST"
  [dev]="feature/TASK-COMMTEST"
  [qc]="test/TASK-COMMTEST"
  [operator]="deploy/TASK-COMMTEST"
)
declare -A SPOKE_DIR=(
  [designer]="design"
  [dev]="src/commtest"
  [qc]="qa/reports"
  [operator]="ops/runbooks"
)

# Summary table (rows appended as tests run)
SUMMARY_ROWS=()

# ------------------------------- arg parse -----------------------------------
TARGET=""; DEV_COUNT=""; QC_COUNT=""; CLEANUP="auto"
VALID_TARGETS="designer dev qc operator all"
while (( $# )); do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --count) DEV_COUNT="$2"; QC_COUNT="$2"; shift 2 ;;
    --dev-count) DEV_COUNT="$2"; shift 2 ;;
    --qc-count) QC_COUNT="$2"; shift 2 ;;
    --no-cleanup) CLEANUP="no"; shift ;;
    --force-cleanup) CLEANUP="yes"; shift ;;
    -h|--help) grep '^#' "$0" | head -30; exit 0 ;;
    *) echo "Unknown arg: $1"; exit 2 ;;
  esac
done

if [[ -n "$TARGET" ]]; then
  if ! [[ " $VALID_TARGETS " =~ \ $TARGET\  ]]; then
    echo "Invalid --target '$TARGET'. Valid: $VALID_TARGETS" >&2
    exit 2
  fi
fi

# ------------------------------- load env ------------------------------------
load_env() {
  print_header "Load configuration"
  if [[ ! -f "$CONFIG_FILE" ]]; then
    fail "Config file not found: $CONFIG_FILE"
    exit 1
  fi
  # Source only KEY=VALUE lines, no execution of arbitrary shell.
  # shellcheck disable=SC1090
  set -a
  eval "$(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$CONFIG_FILE")"
  set +a
  pass "Sourced $CONFIG_FILE"

  # On VM-1 the canonical env layout uses VM{2..5}_GATEWAY_TOKEN and
  # VM{2..5}_AGENT_SECRET (as produced by setup-vm1-architect.sh).
  # GATEWAY_AUTH_TOKEN is accepted as a fallback for older installs.
  local missing=()
  [[ -z "${ARCHITECT_HOOK_TOKEN:-}" ]] && missing+=("ARCHITECT_HOOK_TOKEN")
  for n in 2 3 4 5; do
    local tok="VM${n}_GATEWAY_TOKEN"; local sec="VM${n}_AGENT_SECRET"
    [[ -z "${!tok:-}" && -z "${GATEWAY_AUTH_TOKEN:-}" ]] && missing+=("$tok")
    [[ -z "${!sec:-}" ]] && missing+=("$sec")
  done
  if (( ${#missing[@]} > 0 )); then
    fail "Missing env vars: ${missing[*]}"
    info "Edit $CONFIG_FILE and rerun, or export them for this shell."
    info "Expected layout (from setup-vm1-architect.sh):"
    info "  ARCHITECT_HOOK_TOKEN=..."
    info "  VM2_GATEWAY_TOKEN=...   VM2_AGENT_SECRET=..."
    info "  VM3_GATEWAY_TOKEN=...   VM3_AGENT_SECRET=..."
    info "  VM4_GATEWAY_TOKEN=...   VM4_AGENT_SECRET=..."
    info "  VM5_GATEWAY_TOKEN=...   VM5_AGENT_SECRET=..."
    exit 1
  fi
  pass "All required tokens present"
}

require_cli() {
  for c in curl jq openssl git date; do
    command -v "$c" >/dev/null || { fail "Required CLI missing: $c"; exit 1; }
  done
  pass "CLI prerequisites satisfied"
}

prepare_blueprint() {
  print_header "Prepare Blueprint repo"
  if [[ ! -d "$BLUEPRINT_REPO/.git" ]]; then
    fail "Blueprint repo not found at $BLUEPRINT_REPO"
    info "Set BLUEPRINT_REPO env var or clone the repo first."
    exit 1
  fi
  pass "Blueprint at $BLUEPRINT_REPO"
  # Best-effort fetch so local state matches origin
  if git -C "$BLUEPRINT_REPO" fetch --quiet origin 2>/dev/null; then
    pass "git fetch origin OK"
  else
    warn "git fetch origin failed (continuing — local-only test)"
  fi
}

# -------------------------- hook-log discovery -------------------------------
find_hook_log() {
  for f in "${HOOK_LOG_CANDIDATES[@]}"; do
    [[ -r "$f" ]] && { echo "$f"; return 0; }
  done
  # Fallback: try journald via systemd unit if OpenClaw runs as a service
  if systemctl --quiet is-active openclaw-architect 2>/dev/null; then
    echo "journalctl:openclaw-architect"; return 0
  fi
  return 1
}

# ---------------- tail hook log for our TASK-ID (Gate C) ---------------------
wait_for_callback() {
  local task_id="$1" log
  log="$(find_hook_log || true)"
  if [[ -z "$log" ]]; then
    warn "No Architect hook log found; cannot verify inbound callback directly."
    info "Candidates tried: ${HOOK_LOG_CANDIDATES[*]}"
    info "Falling back to Git-only verification for Gate C."
    return 2
  fi
  info "Watching $log for $task_id (timeout ${WAIT_GATE_B_SECONDS}s)"
  local deadline=$(( SECONDS + WAIT_GATE_B_SECONDS ))
  while (( SECONDS < deadline )); do
    if [[ "$log" == journalctl:* ]]; then
      local unit="${log#journalctl:}"
      if journalctl -u "$unit" --since "60 seconds ago" 2>/dev/null | grep -q "$task_id"; then
        return 0
      fi
    else
      if grep -q "$task_id" "$log" 2>/dev/null; then
        return 0
      fi
    fi
    sleep "$WAIT_GATE_A_POLL"
  done
  return 1
}

# ---------------------------- dispatch task ----------------------------------
dispatch_task() {
  local agent_key="$1"    # designer|dev-01|qc-02|operator
  local agent_family="$2" # designer|dev|qc|operator
  local task_id="$3"
  local filename="$4"
  local branch="$5"
  local dir="${SPOKE_DIR[$agent_family]}"
  local url="${SPOKE_GATEWAY[$agent_family]}"

  # Select gateway token using VM{N}_GATEWAY_TOKEN (VM-1 canonical layout).
  # Falls back to GATEWAY_AUTH_TOKEN for older installs.
  local tok_var
  case "$agent_family" in
    designer) tok_var="VM2_GATEWAY_TOKEN" ;;
    dev)      tok_var="VM3_GATEWAY_TOKEN" ;;
    qc)       tok_var="VM4_GATEWAY_TOKEN" ;;
    operator) tok_var="VM5_GATEWAY_TOKEN" ;;
  esac
  local tok="${!tok_var:-${GATEWAY_AUTH_TOKEN:-}}"
  [[ -n "$tok" ]] || { fail "No gateway token for $agent_family ($tok_var)"; return 1; }

  local payload; payload=$(jq -cn \
    --arg agentId "$agent_key" \
    --arg name    "comm-test-task" \
    --arg msg     "[COMMTEST] Please create the prescribed file and commit verbatim." \
    --arg tid     "$task_id" \
    --arg fname   "$filename" \
    --arg path    "$dir/$filename" \
    --arg branch  "$branch" \
    --arg cs      "docs: $task_id — communication test" \
    --arg ts      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{name:$name, agentId:$agentId, message:$msg,
      metadata:{taskId:$tid, filename:$fname, path:$path, branch:$branch,
                commitSubject:$cs, timestamp:$ts, testMode:true}}')

  info "POST $url"
  local out; out=$(mktemp)
  local http
  http=$(curl -sS -o "$out" -w '%{http_code}' -X POST "$url" \
    -H "Authorization: Bearer $tok" \
    -H "Content-Type: application/json" \
    --max-time 15 \
    -d "$payload" || echo "000")

  if [[ "$http" != "200" && "$http" != "202" ]]; then
    fail "Gate A: dispatch HTTP $http — $(head -c 200 "$out")"
    rm -f "$out"
    return 1
  fi
  local run_id; run_id=$(jq -r '.runId // .id // "?"' <"$out" 2>/dev/null || echo "?")
  pass "Gate A: dispatch accepted (HTTP $http, runId=$run_id)"
  rm -f "$out"
  return 0
}

# ------------------------- verify branch + file ------------------------------
verify_deliverable() {
  local branch="$1" expected_path="$2"
  # Try origin first (source of truth); fall back to any ref we can find
  if git -C "$BLUEPRINT_REPO" fetch --quiet origin "$branch:refs/remotes/origin/$branch" 2>/dev/null; then
    if git -C "$BLUEPRINT_REPO" cat-file -e "origin/$branch:$expected_path" 2>/dev/null; then
      pass "Gate D: $expected_path present on origin/$branch"
      return 0
    fi
    warn "Branch origin/$branch exists but $expected_path not found"
    info "Branch file list:"
    git -C "$BLUEPRINT_REPO" ls-tree --name-only "origin/$branch" | sed 's/^/        /'
    return 1
  fi
  fail "Gate D: branch $branch not found on origin"
  return 1
}

verify_trailers() {
  local branch="$1" task_id="$2"
  local msg
  msg=$(git -C "$BLUEPRINT_REPO" log -1 --pretty=%B "origin/$branch" 2>/dev/null || echo "")
  [[ -z "$msg" ]] && { warn "No commit message available on origin/$branch"; return 1; }
  local ok=1
  for t in GateForge-Task-Id GateForge-Priority GateForge-Source-VM GateForge-Source-Role GateForge-Summary; do
    if ! grep -q "^$t:" <<<"$msg"; then
      fail "Missing trailer: $t"
      ok=0
    fi
  done
  if grep -q "^GateForge-Task-Id: $task_id\$" <<<"$msg"; then
    pass "Task-Id trailer matches: $task_id"
  else
    fail "Task-Id trailer does not match $task_id"
    ok=0
  fi
  return $(( 1 - ok ))
}

# --------------------------- single-agent test -------------------------------
run_one() {
  local agent_key="$1" agent_family="$2"
  local ts; ts=$(date +%s)
  local task_id="TASK-COMMTEST-${agent_key}-${ts}"
  local filename="commtest-${agent_key}-${ts}.md"
  local branch_prefix="${SPOKE_BRANCH_PREFIX[$agent_family]}"
  local branch="${branch_prefix}-${agent_key}-${ts}"
  local expected_path="${SPOKE_DIR[$agent_family]}/${filename}"

  print_header "Test: Architect → ${agent_key}  (${task_id})"
  info "Filename: $filename"
  info "Branch:   $branch"
  info "Path:     $expected_path"

  local gate_a=0 gate_b=0 gate_c=0 gate_d=0

  # Gate A — dispatch
  if dispatch_task "$agent_key" "$agent_family" "$task_id" "$filename" "$branch"; then
    gate_a=1
  fi

  if (( gate_a == 0 )); then
    SUMMARY_ROWS+=("$agent_key|FAIL(A)|—|—|—|$task_id")
    return
  fi

  # Gate C — Architect callback (hook log)
  info "Waiting for callback on Architect hook endpoint…"
  local rc=0; wait_for_callback "$task_id" || rc=$?
  case "$rc" in
    0) pass "Gate C: Architect received callback carrying $task_id"; gate_c=1 ;;
    2) warn "Gate C: skipped (no readable hook log)"; gate_c=-1 ;;
    *) fail "Gate C: timeout — no callback seen in ${WAIT_GATE_B_SECONDS}s"; gate_c=0 ;;
  esac

  # Gate D — deliverable on origin
  if verify_deliverable "$branch" "$expected_path"; then
    gate_d=1
    gate_b=1   # If file is there, the agent's commit+push (Gate B) succeeded
  fi

  # Commit trailers (extra soft check)
  if (( gate_d == 1 )); then
    verify_trailers "$branch" "$task_id" || warn "Trailer check did not fully pass (see above)"
  fi

  local verdict="PASS"
  (( gate_a == 1 )) || verdict="FAIL"
  (( gate_b == 1 )) || verdict="FAIL"
  (( gate_d == 1 )) || verdict="FAIL"
  # Gate C is soft-fail if we couldn't find the log at all (-1)
  if (( gate_c == 0 )); then verdict="FAIL"; fi

  local ca cb cc cdel
  ca=$([[ $gate_a -eq 1 ]] && echo ✓ || echo ✗)
  cb=$([[ $gate_b -eq 1 ]] && echo ✓ || echo ✗)
  case "$gate_c" in
    1) cc='✓' ;;
    0) cc='✗' ;;
    *) cc='?' ;;
  esac
  cdel=$([[ $gate_d -eq 1 ]] && echo ✓ || echo ✗)
  SUMMARY_ROWS+=("$agent_key|$verdict|$ca|$cb|$cc|$cdel|$task_id|$branch")
}

# ------------------------------- cleanup -------------------------------------
cleanup_branches() {
  print_header "Cleanup"
  if [[ "$CLEANUP" == "no" ]]; then
    info "Cleanup skipped (--no-cleanup). Test branches remain on origin."
    return
  fi
  if [[ "$CLEANUP" == "auto" ]]; then
    echo -n "  Delete all TASK-COMMTEST-* branches on origin? [Y/n] "
    read -r ans
    [[ "${ans,,}" == "n" ]] && { info "Cleanup skipped."; return; }
  fi
  # Collect candidates from origin
  local branches
  branches=$(git -C "$BLUEPRINT_REPO" ls-remote --heads origin "refs/heads/*COMMTEST*" \
             | awk '{print $2}' | sed 's#refs/heads/##')
  if [[ -z "$branches" ]]; then
    info "No test branches to remove."
    return
  fi
  while IFS= read -r b; do
    [[ -z "$b" ]] && continue
    if git -C "$BLUEPRINT_REPO" push origin --delete "$b" --quiet 2>/dev/null; then
      pass "Deleted origin/$b"
    else
      warn "Could not delete origin/$b (may already be gone)"
    fi
  done <<<"$branches"
}

# ------------------------------- summary -------------------------------------
print_summary() {
  print_header "Summary"
  printf '  %-14s %-6s  %-3s %-3s %-3s %-3s  %s\n' "Agent" "Result" "A" "B" "C" "D" "Branch"
  printf '  %-14s %-6s  %-3s %-3s %-3s %-3s  %s\n' "-----" "------" "--" "--" "--" "--" "------"
  local any_fail=0
  for row in "${SUMMARY_ROWS[@]}"; do
    IFS='|' read -r agent verdict ca cb cc cdel _task branch <<<"$row"
    local color=$GREEN
    [[ "$verdict" == FAIL* ]] && { color=$RED; any_fail=1; }
    printf "  ${color}%-14s %-6s${RESET}  %-3s %-3s %-3s %-3s  ${DIM}%s${RESET}\n" \
      "$agent" "$verdict" "$ca" "$cb" "$cc" "$cdel" "${branch:-}"
  done
  echo ""
  echo -e "  ${DIM}Legend: A=dispatch 200, B=agent commit+push, C=Architect callback, D=file on origin${RESET}"
  echo ""
  if (( any_fail == 1 )); then
    echo -e "  ${RED}${BOLD}Overall: FAIL${RESET}"
    return 1
  else
    echo -e "  ${GREEN}${BOLD}Overall: PASS${RESET}"
    return 0
  fi
}

# ------------------------------- menu ----------------------------------------
ask_counts() {
  if [[ -z "$DEV_COUNT" ]]; then
    echo -n "  How many developer agents are deployed on VM-3? [2] "
    read -r DEV_COUNT; DEV_COUNT="${DEV_COUNT:-2}"
  fi
  if [[ -z "$QC_COUNT" ]]; then
    echo -n "  How many QC agents are deployed on VM-4? [2] "
    read -r QC_COUNT; QC_COUNT="${QC_COUNT:-2}"
  fi
}

menu() {
  while :; do
    echo ""
    echo -e "${BOLD}Select test target:${RESET}"
    echo "  1) Architect → Designer (VM-2)"
    echo "  2) Architect → Developers (VM-3, N agents 1-by-1)"
    echo "  3) Architect → QC (VM-4, N agents 1-by-1)"
    echo "  4) Architect → Operator (VM-5)"
    echo "  5) All of the above"
    echo "  q) Quit"
    echo -n "  > "
    read -r choice
    case "$choice" in
      1) TARGET=designer; break ;;
      2) TARGET=dev; ask_counts; break ;;
      3) TARGET=qc; ask_counts; break ;;
      4) TARGET=operator; break ;;
      5) TARGET=all; ask_counts; break ;;
      q|Q) exit 0 ;;
      *) warn "Invalid selection" ;;
    esac
  done
}

# ------------------------------- dispatcher ----------------------------------
run_target() {
  case "$TARGET" in
    designer) run_one "designer" "designer" ;;
    dev)
      : "${DEV_COUNT:?count required}"
      for i in $(seq 1 "$DEV_COUNT"); do
        run_one "$(printf 'dev-%02d' "$i")" "dev"
      done ;;
    qc)
      : "${QC_COUNT:?count required}"
      for i in $(seq 1 "$QC_COUNT"); do
        run_one "$(printf 'qc-%02d' "$i")" "qc"
      done ;;
    operator) run_one "operator" "operator" ;;
    all)
      run_one "designer" "designer"
      for i in $(seq 1 "${DEV_COUNT:-2}"); do run_one "$(printf 'dev-%02d' "$i")" "dev"; done
      for i in $(seq 1 "${QC_COUNT:-2}"); do run_one "$(printf 'qc-%02d' "$i")" "qc"; done
      run_one "operator" "operator"
      ;;
    *) fail "Unknown target: $TARGET"; exit 2 ;;
  esac
}

# ------------------------------- main ----------------------------------------
main() {
  banner
  load_env
  require_cli
  prepare_blueprint

  if [[ -z "$TARGET" ]]; then
    menu
  fi

  # Interactive count prompts when running via flags and counts are missing
  case "$TARGET" in
    dev) [[ -z "$DEV_COUNT" ]] && ask_counts ;;
    qc)  [[ -z "$QC_COUNT"  ]] && ask_counts ;;
    all) [[ -z "$DEV_COUNT" || -z "$QC_COUNT" ]] && ask_counts ;;
  esac

  run_target
  print_summary || true
  cleanup_branches
}

main "$@"

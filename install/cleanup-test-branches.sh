#!/usr/bin/env bash
# =============================================================================
# GateForge — Remove all TASK-COMMTEST-* branches from origin
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
TEAL='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'

BLUEPRINT_REPO="${BLUEPRINT_REPO:-/opt/gateforge/blueprint}"

if [[ ! -d "$BLUEPRINT_REPO/.git" ]]; then
  echo -e "${RED}Blueprint repo not found at $BLUEPRINT_REPO${RESET}"
  exit 1
fi

echo -e "${TEAL}${BOLD}Removing TASK-COMMTEST-* branches from origin${RESET}"
branches=$(git -C "$BLUEPRINT_REPO" ls-remote --heads origin "refs/heads/*COMMTEST*" \
           | awk '{print $2}' | sed 's#refs/heads/##')

if [[ -z "$branches" ]]; then
  echo -e "  ${DIM}No test branches found.${RESET}"; exit 0
fi

echo "$branches" | sed 's/^/  · /'
echo -n "Proceed? [y/N] "; read -r ans
[[ "${ans,,}" == "y" ]] || { echo "Aborted."; exit 0; }

while IFS= read -r b; do
  [[ -z "$b" ]] && continue
  if git -C "$BLUEPRINT_REPO" push origin --delete "$b" --quiet 2>/dev/null; then
    echo -e "  ${GREEN}✓${RESET} deleted origin/$b"
  else
    echo -e "  ${YELLOW}!${RESET} could not delete origin/$b"
  fi
done <<<"$branches"

# Prune local remote-tracking refs
git -C "$BLUEPRINT_REPO" remote prune origin >/dev/null 2>&1 || true
echo "Done."

# GateForge — Test #3 Fixes (repo changeset)

Applied to the repository in this changeset:

## Structural
- Moved all per-VM role directories (`vm-1-architect/` … `vm-5-operator/`) under
  `install/` as the single source of truth. Setup scripts reference siblings directly.
- Moved `openclaw-configs/vm-N-<role>/` under the respective `install/vm-N-<role>/openclaw-config/`.
- Moved `openclaw-configs/OPENCLAW-CONFIG-GUIDE.md` and `configure-openclaw-spoke.sh`
  under `install/openclaw-configs/`.

## Content
- **Fix 1 — Filename compliance (verbatim)**: added `### Filename and Path Compliance (mandatory)`
  under "## Constraints" in every spoke SOUL.md:
  - `install/vm-2-designer/SOUL.md`
  - `install/vm-3-developers/SOUL.md`
  - `install/vm-4-qc-agents/SOUL.md`
  - `install/vm-5-operator/SOUL.md`
- **Fix 2 — Host-side callback**: replaced the old `## Notification Protocol` / HMAC-curl
  section in each spoke SOUL.md with the new trailers-based protocol. No more agent-side
  `curl`; no more `AGENT_SECRET` in the agent environment.
- Added `install/host-side/` with `gf-notify-architect.{sh,path,service}` and
  `gf-replay-deadletter.sh`, plus `install/install-host-notifier.sh`.
- Rewrote the `## Environment Variables` table in every TOOLS.md to reference the
  new token file layout (see below).
- Appended a canonical **Secrets & Token Locations** section to every relevant MD
  (all SOUL.md, TOOLS.md, USER.md across VM-1..VM-5).

## New token file layout

| Secret Class | File | Perms |
|---|---|---|
| GateForge platform tokens (HMAC, gateway, hook, Architect URL, Tailscale) | `/opt/secrets/gateforge.env` | `root:root 0600` |
| GitHub fine-grained PATs | `~/.config/gateforge/github-tokens.env` | `$USER:$USER 0600` |
| All other third-party tokens (one file per app) | `~/.config/gateforge/<app>.env` | `$USER:$USER 0600` |

Examples: `~/.config/gateforge/anthropic.env`, `minimax.env`, `telegram.env`,
`brave.env`, `tailscale.env`.

## Shared source files (DRY, single place to edit)

- `install/_SHARED_FILENAME_COMPLIANCE.md`
- `install/_SHARED_NOTIFICATION_PROTOCOL.md`
- `install/_SHARED_SECRETS_SECTION.md`

These are the canonical sources; if you need to change the wording, edit these and
re-run the idempotent patch scripts (included in the fix bundle).

## Rollout order

1. Land the doc-only changes first (Fix 1 + Secrets sections + TOOLS.md env tables).
   Zero infrastructure risk.
2. Install `install/host-side/` on VM-2 only. Run the smoke test
   (`TASK-SMOKE-001` commit from the host). Confirm Architect receives the callback.
3. Roll `host-side/` to VM-3, VM-4, VM-5.
4. On every spoke, move secrets to the new file layout:
   - Move HMAC/gateway/hook tokens to `/opt/secrets/gateforge.env` (already there — verify).
   - Move GitHub PATs to `~/.config/gateforge/github-tokens.env`.
   - Move LLM / Brave / MiniMax / Telegram / Tailscale tokens to `~/.config/gateforge/<app>.env`.
5. Restart OpenClaw gateway on each VM.

## Preserved / unchanged

- Architect's inbound validation (HMAC verify, timestamp check, source-VM allowlist).
- `openclaw.json` for all 5 VMs — env-var names in `env:` blocks still work; only the
  file they are loaded from changed.
- Blueprint repo structure, branch naming, task payload schema, Lobster pipeline.

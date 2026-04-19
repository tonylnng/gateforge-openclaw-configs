# test-communication.sh

End-to-end regression test for GateForge agent communication. Run on **VM-1 (Architect)**.

## What it tests

For each selected agent, the script walks through four gates:

| Gate | Meaning | How it's verified |
|---|---|---|
| **A** | Architect → spoke gateway dispatch accepted | `curl -X POST` returns HTTP 200/202 with a `runId` |
| **B** | Spoke agent committed + pushed a file | The prescribed file appears on `origin/<branch>` |
| **C** | Architect received HMAC callback | Architect's hook log contains the task's ID within 90s |
| **D** | Deliverable readable by hub | `git cat-file -e origin/<branch>:<path>` succeeds |

Plus a soft check for the five required commit trailers (`GateForge-Task-Id`, `-Priority`, `-Source-VM`, `-Source-Role`, `-Summary`).

## Menu

```
1) Architect → Designer (VM-2)
2) Architect → Developers (VM-3, N agents 1-by-1)
3) Architect → QC (VM-4, N agents 1-by-1)
4) Architect → Operator (VM-5)
5) All of the above
```

When you pick Developers, QC, or All, it asks how many agents are deployed. The script then iterates `dev-01, dev-02, …` / `qc-01, qc-02, …`.

## Usage

```bash
# Interactive:
sudo ./test-communication.sh

# Non-interactive:
sudo ./test-communication.sh --target designer
sudo ./test-communication.sh --target dev --count 2
sudo ./test-communication.sh --target qc  --count 3
sudo ./test-communication.sh --target operator
sudo ./test-communication.sh --target all --dev-count 2 --qc-count 2

# Keep test branches after the run:
sudo ./test-communication.sh --target all --dev-count 2 --qc-count 2 --no-cleanup
```

## Requirements on VM-1

- `/opt/secrets/gateforge.env` with: `ARCHITECT_HOOK_TOKEN`, plus either per-spoke
  `<ROLE>_GATEWAY_TOKEN` or a shared `GATEWAY_AUTH_TOKEN`, plus per-spoke
  `VM{2..5}_AGENT_SECRET` (used only if you enable the HMAC probe extension).
- `/opt/gateforge/blueprint/` cloned and writable by the invoking user.
- Tailscale interface up (spoke gateways reachable on port `18789`).
- `curl`, `jq`, `openssl`, `git` installed.

## Flow per agent

```
Architect (this script)
  └─ POST /hooks/agent to spoke gateway  ──────── Gate A
        Payload carries taskId, filename, branch,
        path, commitSubject (all MUST be used verbatim).

Spoke OpenClaw agent
  ├─ writes file at prescribed path
  ├─ commits with 5 required trailers
  └─ git push origin <branch>  ──────── Gate B

Spoke host (systemd path unit)
  └─ gf-notify-architect.sh
        HMAC-SHA256(payload, AGENT_SECRET)
        POST to Architect /hooks/agent  ──────── Gate C

Architect
  └─ verifies HMAC, logs task ID to hook log
  └─ script reads Git to confirm file   ──────── Gate D
```

## Cleanup

By default the script prompts `Delete all TASK-COMMTEST-* branches on origin? [Y/n]`.
Answer **Y** to tidy up. `--no-cleanup` keeps artefacts for forensic inspection.

A standalone cleaner is also shipped:

```bash
sudo ./cleanup-test-branches.sh
```

## Exit codes

- `0` — all selected tests passed (every gate green, or Gate C "skipped" because
  no readable hook log was found and Gate D is green).
- `1` — at least one test failed a mandatory gate.
- `2` — usage error (bad `--target`, missing required flag).

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| Gate A fails with HTTP 401 | Per-spoke gateway token wrong in `/opt/secrets/gateforge.env` |
| Gate A fails with HTTP 000 | Spoke VM unreachable on Tailscale, or gateway not running |
| Gate B passes but Gate D fails | Agent committed locally but `git push` failed (check spoke's git creds) |
| Gate C always warns "skipped" | No readable Architect hook log; run `journalctl -u openclaw-architect -n 100` manually to check |
| Gate C fails with timeout | Host notifier not installed on spoke, or firewall blocking spoke → Architect :18789 |
| Trailer warnings | Agent's SOUL.md may need re-sync with `install/_SHARED_NOTIFICATION_PROTOCOL.md` |

## Extending

- Raise `WAIT_GATE_B_SECONDS` (default 90s) via env var for slow LLMs:
  `WAIT_GATE_B_SECONDS=180 sudo -E ./test-communication.sh ...`
- Override gateway URLs per run if Tailscale IPs changed:
  `DESIGNER_GATEWAY_URL=http://100.x.x.x:18789/hooks/agent sudo -E ./test-communication.sh --target designer`
- Use `--no-cleanup` to leave branches for manual inspection after a failure.

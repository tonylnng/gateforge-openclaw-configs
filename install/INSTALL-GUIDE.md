# GateForge — Step-by-Step Installation Guide

> For users new to Linux. Follow each step exactly as shown.

---

## Before You Start

You need 5 Ubuntu VMs with OpenClaw already installed and working. Each VM should have:
- OpenClaw running with its API key configured
- Telegram configured on VM-1 (Architect)
- Internet access and `sudo` permission

### Required on ALL 5 VMs Before Running Setup Scripts

#### Step A — Change OpenClaw gateway bind from loopback to tailnet

By default OpenClaw only listens on localhost. Other VMs cannot reach it. Fix this on every VM:

```bash
openclaw config set gateway.bind tailnet
openclaw gateway restart
```

Verify:

```bash
ss -tlnp | grep 18789
# Must NOT show 127.0.0.1 — should show 0.0.0.0 or the Tailscale IP
```

#### Step B — Configure firewall to allow only GateForge VMs

Run this on every VM:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow from 100.73.38.28 to any port 18789
sudo ufw allow from 100.95.30.11 to any port 18789
sudo ufw allow from 100.81.114.55 to any port 18789
sudo ufw allow from 100.106.117.104 to any port 18789
sudo ufw allow from 100.95.248.68 to any port 18789
sudo ufw enable
```

Verify:

```bash
sudo ufw status
```

Only the 5 GateForge VM IPs can access port 18789. This is more secure than allowing the entire Tailscale subnet.

#### Step C — Test connectivity between VMs

From any VM, test that you can reach another VM's gateway:

```bash
curl -s http://100.73.38.28:18789/health
# Should return: {"ok":true,"status":"live"}
```

If this fails, check the bind setting (Step A) and firewall (Step B) on the target VM.

Once all 5 VMs return `{"ok":true,"status":"live"}` from each other, proceed with the setup scripts below.

---

## GitHub Repository Access

GateForge uses multiple private GitHub repositories. Each VM needs authentication to access them.

### GateForge Repositories

| Repository | Purpose | Access |
|-----------|---------|--------|
| `tonylnng/gateforge-openclaw-configs` | Agent configuration (this repo) — SOUL.md, TOOLS.md, install scripts | **Read-only** for all VMs |
| `tonylnng/gateforge-blueprint-template` | Standardised Blueprint document structure — cloned per project, updated over time with improved standards | **Read-only** for all VMs |
| `tonylnng/<project>-blueprint` | Per-project working Blueprint — requirements, architecture, designs, status, backlog | **Read/write** for VM-1 (Architect); read-only for others |
| `tonylnng/<project>-code` | Per-project source code | **Read/write** for VM-3 (Developers) and VM-5 (Operator); read-only for others |

### Authentication: Fine-Grained Personal Access Tokens (PATs)

GateForge uses **GitHub Fine-Grained PATs** (not classic tokens) for per-repository and per-permission scoping. See the [GitHub Token Configuration](../README.md#github-token-configuration) section in the main README for the complete setup guide, including:

- **Token A** — Read-only access to all repos (all VMs)
- **Token B** — Read/write access to the project Blueprint repo (VM-1 Architect only)
- **Token C** — Read/write access to the project code repo (VM-3 Developers)
- **Token D** — Read/write CI/CD access to the project code repo (VM-5 Operator)

#### Quick Setup — Clone This Config Repo

On each VM, use the read-only token (Token A) to clone this repo:

```bash
git clone https://<GITHUB_TOKEN_READONLY>@github.com/tonylnng/gateforge-openclaw-configs.git
```

To avoid entering the token on every `git pull`, configure credential storage:

```bash
# Store credentials securely
git config --global credential.helper store
echo "https://gateforge-bot:${GITHUB_TOKEN_READONLY}@github.com" > ~/.git-credentials
chmod 600 ~/.git-credentials
```

For VMs with read/write access (VM-1, VM-3, VM-5), add a URL override for the specific repo:

```bash
# VM-1: read/write override for the project Blueprint repo
git config --global url."https://gateforge-bot:${GITHUB_TOKEN_RW}@github.com/tonylnng/<project>-blueprint".insteadOf \
  "https://github.com/tonylnng/<project>-blueprint"

# VM-3 / VM-5: read/write override for the project code repo
git config --global url."https://gateforge-bot:${GITHUB_TOKEN_RW}@github.com/tonylnng/<project>-code".insteadOf \
  "https://github.com/tonylnng/<project>-code"
```

All tokens are stored in `/opt/secrets/gateforge.env` (root:root, chmod 600). The setup scripts automatically grant read access to the OpenClaw user via POSIX ACL (`setfacl`). See the main README for the full configuration, rotation, and security guide.

> **Note**: The `acl` package must be installed (`sudo apt-get install acl`). The setup scripts detect this and warn if missing. To verify or manually grant access:
>
> ```bash
> # Grant read access to the OpenClaw user
> sudo setfacl -m u:<openclaw-user>:r /opt/secrets/gateforge.env
>
> # Verify the ACL
> getfacl /opt/secrets/gateforge.env
> ```

---

## VM-1: System Architect (run this FIRST)

### Step 1 — Open a terminal on VM-1

Connect to `tonic-architect` via SSH or open a terminal directly:

```bash
ssh user@tonic-architect
```

### Step 2 — Install prerequisites (if not already installed)

```bash
sudo apt update
sudo apt install -y git openssl curl
```

### Step 3 — Download the GateForge configs

```bash
cd ~
git clone https://github.com/tonylnng/gateforge-openclaw-configs.git
cd gateforge-openclaw-configs/install
```

### Step 4 — Run the Architect setup script

```bash
sudo bash setup-vm1-architect.sh
```

The script will ask you:
1. **VM-1 IP/host** — Press Enter for default (`100.73.38.28`) or type your IP
2. **VM-2 through VM-5 IPs** — Press Enter for defaults or type each IP
3. **Gateway auth token** — Press Enter to auto-generate
4. **Architect hook token** — Press Enter to auto-generate

All tokens and secrets are auto-generated. Just press Enter for each unless you have specific values.

### Step 5 — Save the output

At the end, the script displays a red box with all the tokens and secrets:

```
┌────────────────────────────────────────────────────────────────┐
│  SAVE THESE VALUES — needed when setting up spoke VMs         │
├────────────────────────────────────────────────────────────────┤
│  Architect Hook Token: e7f3b1a2c9d4...                        │
│  VM-2 Gateway Token:  a3f8c901...    HMAC: 7d2e1a4b...        │
│  VM-3 Gateway Token:  b4c9d012...    HMAC: 8e3f2b5c...        │
│  VM-4 Gateway Token:  c5dae123...    HMAC: 9f4c3d6e...        │
│  VM-5 Gateway Token:  d6ebf234...    HMAC: a05d4e7f...        │
└────────────────────────────────────────────────────────────────┘
```

**Copy these values to a safe place** (e.g., a text file on your Mac). You will paste them into each spoke VM setup.

---

## VM-2: System Designer

### Step 1 — Open a terminal on VM-2

```bash
ssh user@tonic-designer
```

### Step 2 — Install prerequisites and download configs

```bash
sudo apt update
sudo apt install -y git openssl curl
cd ~
git clone https://github.com/tonylnng/gateforge-openclaw-configs.git
cd gateforge-openclaw-configs/install
```

### Step 3 — Run the Designer setup script

```bash
sudo bash setup-vm2-designer.sh
```

The script will ask you:
1. **This VM's IP/host** — Press Enter for default (`100.95.30.11`)
2. **Architect VM IP/host** — Press Enter for default (`100.73.38.28`)
3. **This VM's gateway token** — Paste the **VM-2 Gateway Token** from the VM-1 output
4. **Architect hook token** — Paste the **Architect Hook Token** from the VM-1 output
5. **This VM's HMAC secret** — Paste the **VM-2 HMAC Secret** from the VM-1 output

### Step 4 — Done

The script confirms success and shows a summary.

---

## VM-3: Developers

### Step 1 — Open a terminal on VM-3

```bash
ssh user@tonic-developer
```

### Step 2 — Install prerequisites and download configs

```bash
sudo apt update
sudo apt install -y git openssl curl
cd ~
git clone https://github.com/tonylnng/gateforge-openclaw-configs.git
cd gateforge-openclaw-configs/install
```

### Step 3 — Run the Developers setup script

```bash
sudo bash setup-vm3-developers.sh
```

The script asks the same questions as VM-2 (paste VM-3 values from the VM-1 output), plus one extra:

```
How many Developer agents?
  1) 3
  2) 5
  3) 10
Choose [1-3]:
```

Type `1`, `2`, or `3` and press Enter. The script creates per-agent identity files (dev-01, dev-02, etc.).

---

## VM-4: QC Agents

### Step 1 — Open a terminal on VM-4

```bash
ssh user@tonic-qc
```

### Step 2 — Install prerequisites and download configs

```bash
sudo apt update
sudo apt install -y git openssl curl
cd ~
git clone https://github.com/tonylnng/gateforge-openclaw-configs.git
cd gateforge-openclaw-configs/install
```

### Step 3 — Run the QC Agents setup script

```bash
sudo bash setup-vm4-qc-agents.sh
```

Same as VM-3 — paste VM-4 values from VM-1 output, then choose how many QC agents (3, 5, or 10).

---

## VM-5: Operator

### Step 1 — Open a terminal on VM-5

```bash
ssh user@tonic-operator
```

### Step 2 — Install prerequisites and download configs

```bash
sudo apt update
sudo apt install -y git openssl curl
cd ~
git clone https://github.com/tonylnng/gateforge-openclaw-configs.git
cd gateforge-openclaw-configs/install
```

### Step 3 — Run the Operator setup script

```bash
sudo bash setup-vm5-operator.sh
```

Paste VM-5 values from the VM-1 output. Done.

---

## Verify Everything Works

After all 5 VMs are set up, test the notification from any spoke VM.

### On VM-2 (or any spoke), run:

```bash
# Load your config
source <(sudo cat /opt/secrets/gateforge.env)

# Build a test notification
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
PAYLOAD='{"name":"agent-notify","agentId":"architect","message":"[INFO] Test from designer","metadata":{"sourceVm":"vm-2","sourceRole":"designer","priority":"INFO","taskId":"TEST","timestamp":"'${TIMESTAMP}'"}}'

# Sign it
SIGNATURE=$(echo -n "${PAYLOAD}" | openssl dgst -sha256 -hmac "${AGENT_SECRET}" | awk '{print $2}')

# Send it
curl -s -X POST ${ARCHITECT_NOTIFY_URL} \
  -H "Authorization: Bearer ${ARCHITECT_HOOK_TOKEN}" \
  -H "X-Agent-Signature: ${SIGNATURE}" \
  -H "X-Source-VM: vm-2" \
  -H "Content-Type: application/json" \
  -d "${PAYLOAD}"
```

If the Architect is running, you should get a response. If not, you'll see a connection error — that just means the Architect's OpenClaw gateway isn't started yet.

---

## Run Connectivity Tests

After all VMs are set up, run the test scripts to verify everything works.

### Test from VM-1 (Architect) — tests ALL VMs

```bash
cd ~/gateforge-openclaw-configs
sudo bash install/test-connectivity.sh
```

This runs 6 tests from the Architect: ping all spokes, gateway health check on all 5 VMs, task dispatch to each spoke, HMAC notification from each spoke, fake-secret rejection, and config file presence. Only works on VM-1 because the Architect has all spoke tokens.

### Test from any spoke VM (VM-2 through VM-5)

```bash
cd ~/gateforge-openclaw-configs
sudo bash install/test-spoke.sh
```

This runs 5 tests from the spoke: ping Architect, Architect gateway health, local gateway health, HMAC notification to Architect, and wrong-token rejection. Works on any spoke VM — it reads the role and credentials from `/opt/secrets/gateforge.env`.

### Expected Results

All tests should show green `PASS`. Common issues:

| Issue | Cause | Fix |
|-------|-------|-----|
| Ping fails | Tailscale not connected | `tailscale status` on both VMs |
| Gateway HTTP fails | Bound to loopback | `openclaw config set gateway.bind tailnet` + restart |
| Connection refused | Firewall blocking | `sudo ufw allow from <vm-ip> to any port 18789` |
| HTTP 404 on dispatch | Hook endpoint not configured | See next section for OpenClaw webhook setup |

---

## Quick Reference — Common Commands

| What | Command |
|------|---------|
| Check OpenClaw is running | `openclaw gateway status` |
| View your GateForge config | `sudo cat /opt/secrets/gateforge.env` |
| Re-run setup (update config) | `cd ~/gateforge-openclaw-configs/install && sudo bash setup-vmN-role.sh` |
| Update configs from GitHub | `cd ~/gateforge-openclaw-configs && git pull` |
| Restart OpenClaw gateway | `openclaw gateway restart` |

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `openssl: command not found` | `sudo apt install -y openssl` |
| `git: command not found` | `sudo apt install -y git` |
| `Permission denied` on gateforge.env | Run the setup script with `sudo`. If the OpenClaw user still can't read it: `sudo setfacl -m u:<user>:r /opt/secrets/gateforge.env` |
| `setfacl: command not found` | Install the ACL package: `sudo apt-get install acl` |
| Script says "OpenClaw not found" | Install OpenClaw first: `curl -fsSL https://openclaw.ai/install.sh \| bash` |
| "Connection refused" on test notification | The Architect's OpenClaw gateway isn't running — start it first |
| Wrong values pasted | Re-run the setup script — it will overwrite the old config |

---

*GateForge — Multi-Agent SDLC Pipeline | Designed by Tony NG | April 2026*

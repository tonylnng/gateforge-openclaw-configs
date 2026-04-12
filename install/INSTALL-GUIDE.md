# GateForge — Step-by-Step Installation Guide

> For users new to Linux. Follow each step exactly as shown.

---

## Before You Start

You need 5 Ubuntu VMs with OpenClaw already installed and working. Each VM should have:
- OpenClaw running with its API key configured
- Telegram configured on VM-1 (Architect)
- Internet access and `sudo` permission

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

## Quick Reference — Common Commands

| What | Command |
|------|---------|
| Check OpenClaw is running | `openclaw gateway status` |
| View your GateForge config | `sudo cat /opt/secrets/gateforge.env` |
| Re-run setup (update config) | `cd ~/gateforge-openclaw-configs/install && sudo bash setup-vmN-role.sh` |
| Update configs from GitHub | `cd ~/gateforge-openclaw-configs && git pull` |
| Check systemd service | `sudo systemctl status openclaw-gateforge.service` |
| View OpenClaw logs | `journalctl -u openclaw-gateforge -f` |
| Restart OpenClaw | `sudo systemctl restart openclaw-gateforge.service` |

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `openssl: command not found` | `sudo apt install -y openssl` |
| `git: command not found` | `sudo apt install -y git` |
| `Permission denied` on gateforge.env | Run the setup script with `sudo` |
| Script says "OpenClaw not found" | Install OpenClaw first: `curl -fsSL https://openclaw.ai/install.sh \| bash` |
| "Connection refused" on test notification | The Architect's OpenClaw gateway isn't running — start it first |
| Wrong values pasted | Re-run the setup script — it will overwrite the old config |

---

*GateForge — Multi-Agent SDLC Pipeline | Designed by Tony NG | April 2026*

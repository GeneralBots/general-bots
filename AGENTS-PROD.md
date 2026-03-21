# General Bots Cloud — Production Operations Guide

## Infrastructure Overview
- **Host OS:** Ubuntu 24.04 LTS, LXD (snap)
- **SSH:** Key auth only, sudoer user in `lxd` group
- **Container engine:** LXD with ZFS storage pool

## LXC Container Architecture

| Container | Purpose | Exposed Ports |
|---|---|---|
| `<tenant>-proxy` | Caddy reverse proxy | 80, 443 |
| `<tenant>-system` | botserver + botui (privileged!) | internal only |
| `<tenant>-alm` | Forgejo (ALM/Git) | internal only |
| `<tenant>-alm-ci` | Forgejo CI runner | none |
| `<tenant>-email` | Stalwart mail server | 25,465,587,993,995,143,110 |
| `<tenant>-dns` | CoreDNS | 53 |
| `<tenant>-drive` | MinIO S3 | internal only |
| `<tenant>-tables` | PostgreSQL | internal only |
| `<tenant>-table-editor` | NocoDB | internal only |
| `<tenant>-webmail` | Roundcube | internal only |

## Key Rules
- `<tenant>-system` must be **privileged** (`security.privileged: true`) — required for botserver to own `/opt/gbo/` mounts
- All containers use LXD **proxy devices** for port forwarding (network forwards don't work when external IP is on host NIC, not bridge)
- Never remove proxy devices for ports: 80, 443, 25, 465, 587, 993, 995, 143, 110, 4190, 53
- CI runner (`alm-ci`) must NOT have cross-container disk device mounts — deploy via SSH instead

## Firewall (host)
- **ufw** with `DEFAULT_FORWARD_POLICY=ACCEPT` (needed for container internet)
- LXD forward rule must persist via systemd service
- **fail2ban** on host (SSH jail) and in email container (mail jail)

---

## 🔧 Common Production Issues & Fixes

### Issue: Valkey/Redis Connection Timeout

**Symptom:** botserver logs show `Connection timed out (os error 110)` when connecting to cache at `localhost:6379`

**Root Cause:** iptables DROP rule for port 6379 blocks loopback traffic because no ACCEPT rule for `lo` interface exists before the DROP rules.

**Fix:**
```bash
# Insert loopback ACCEPT at top of INPUT chain
lxc exec <tenant>-system -- iptables -I INPUT 1 -i lo -j ACCEPT

# Persist the rule
lxc exec <tenant>-system -- bash -c 'iptables-save > /etc/iptables/rules.v4'

# Verify Valkey responds
lxc exec <tenant>-system -- /opt/gbo/bin/botserver-stack/bin/cache/bin/valkey-cli ping
# Should return: PONG

# Restart botserver to pick up working cache
lxc exec <tenant>-system -- systemctl restart system.service ui.service
```

**Prevention:** Always ensure loopback ACCEPT rule is at the top of iptables INPUT chain before any DROP rules.

### Issue: Suggestions Not Showing in Frontend

**Symptom:** Bot's start.bas has `ADD_SUGGESTION_TOOL` calls but suggestions don't appear in the UI.

**Diagnosis:**
```bash
# Get bot ID
lxc exec <tenant>-system -- /opt/gbo/bin/botserver-stack/bin/tables/bin/psql -h localhost -U gbuser -d botserver -t -c "SELECT id, name FROM bots WHERE name = 'botname';"

# Check if suggestions exist in cache with correct bot_id
lxc exec <tenant>-system -- /opt/gbo/bin/botserver-stack/bin/cache/bin/valkey-cli --scan --pattern "suggestions:<bot_id>:*"

# If no keys found, check logs for wrong bot_id being used
lxc exec <tenant>-system -- grep "Adding suggestion to Redis key" /opt/gbo/logs/error.log | tail -5
```

**Fix:** This was a code bug where suggestions were stored with `user_id` instead of `bot_id`. After deploying the fix:
1. Wait for CI/CD to build and deploy new binary (~10 minutes)
2. Service auto-restarts on binary update
3. Test by opening a new session (old sessions may have stale keys)

### Deployment & Testing Workflow

```bash
# 1. Fix code in dev environment
# 2. Push to ALM (both submodules AND root)
cd botserver && git push alm main
cd .. && git add botserver && git commit -m "Update submodule" && git push alm main

# 3. Wait ~4 minutes for CI/CD build
# Build time: ~3-4 minutes on CI runner

# 4. Verify deployment
ssh root@pragmatismo.com.br "lxc exec pragmatismo-system -- stat /opt/gbo/bin/botserver | grep Modify"

# 5. Test with Playwright
# Use Playwright MCP to open https://chat.pragmatismo.com.br/<botname>
# Verify suggestions appear, TALK executes, no errors in console
```

**Testing with Playwright:**
```bash
# Open bot in browser via Playwright MCP
Navigate to: https://chat.pragmatismo.com.br/<botname>

# Verify:
# - start.bas executes quickly (< 5 seconds)
# - Suggestions appear in UI
# - No errors in browser console
```

---

## ⚠️ Caddy Config — CRITICAL RULES

**NEVER replace the Caddyfile with a minimal/partial config.**
The full config has ~25 vhosts. If you only see 1-2 vhosts, you are looking at a broken/partial config.

**Before ANY change:**
1. Backup: `cp /opt/gbo/conf/config /opt/gbo/conf/config.bak-$(date +%Y%m%d%H%M)`
2. Validate: `caddy validate --config /opt/gbo/conf/config --adapter caddyfile`
3. Reload (not restart): `caddy reload --config /opt/gbo/conf/config --adapter caddyfile`

**Caddy storage must be explicitly set** in the global block, otherwise Caddy uses `~/.local/share/caddy` and loses existing certificates on restart:
```
{
    storage file_system {
        root /opt/gbo/data/caddy
    }
}
```

**Dead domains cause ERR_SSL_PROTOCOL_ERROR** — if a domain in the Caddyfile has no DNS record, Caddy loops trying to get a certificate and pollutes TLS state. Remove dead domains immediately.

**After removing domains from config**, restart Caddy (not just reload) to clear in-memory ACME state from old domains.

---

## botserver / botui

- botserver: `/opt/gbo/bin/botserver` (system.service, port 5858)
- botui: `/opt/gbo/bin/botui` (ui.service, port 5859)
- `BOTSERVER_URL` in `ui.service` must point to **`http://localhost:5858`** (not HTTPS external URL) — using external URL causes WebSocket disconnect before TALK executes
- Valkey/Redis bound to `127.0.0.1:6379` — iptables rules must allow loopback on this port or suggestions/cache won't work
- Vault unseal keys stored in `/opt/gbo/vault-unseal-keys` (production only - never commit to git)

### Caddy in Proxy Container
- Binary: `/usr/bin/caddy` (system container) or `caddy` in PATH
- Config: `/opt/gbo/conf/config`
- Reload: `lxc exec <tenant>-proxy -- caddy reload --config /opt/gbo/conf/config --adapter caddyfile`
- Storage: `/opt/gbo/data/caddy`

### Log Locations

**botserver/botui logs:**
```bash
# Main application logs (in pragmatismo-system container)
/opt/gbo/logs/error.log          # botserver logs
/opt/gbo/logs/botui-error.log   # botui logs
/opt/gbo/logs/output.log         # stdout/stderr output
```

**Component logs (in `/opt/gbo/bin/botserver-stack/logs/`):**
```bash
cache/         # Valkey/Redis logs
directory/     # Zitadel logs  
drive/         # MinIO S3 logs
llm/           # LLM (llama.cpp) logs
tables/        # PostgreSQL logs
vault/         # Vault secrets logs
vector_db/     # Qdrant vector DB logs
```

**Checking component logs:**
```bash
# Valkey
lxc exec pragmatismo-system -- tail -f /opt/gbo/bin/botserver-stack/logs/cache/valkey.log

# PostgreSQL
lxc exec pragmatismo-system -- tail -f /opt/gbo/bin/botserver-stack/logs/tables/postgres.log

# Qdrant
lxc exec pragmatismo-system -- tail -f /opt/gbo/bin/botserver-stack/logs/vector_db/qdrant.log
```

### iptables loopback rule (required)
Internal services (Valkey, MinIO) are protected by DROP rules. Loopback must be explicitly allowed **before** the DROP rules:
```bash
iptables -I INPUT -i lo -j ACCEPT
iptables -A INPUT -p tcp --dport 6379 -j DROP  # external only
```

---

## CoreDNS Hardening

Corefile must include `acl` plugin to prevent DNS amplification attacks:
```
zone.example.com:53 {
    file /opt/gbo/data/zone.example.com.zone
    acl {
        allow type ANY net 10.0.0.0/8 127.0.0.0/8
        allow type A net 0.0.0.0/0
        allow type AAAA net 0.0.0.0/0
        allow type MX net 0.0.0.0/0
        block
    }
    cache
    errors
}
```
Reload with SIGHUP: `pkill -HUP coredns`

---

## fail2ban in Proxy Container

Proxy container needs its own fail2ban for HTTP flood protection:
- Filter: match 4xx errors from Caddy JSON access log
- Jail: `caddy-http-flood` — 100 errors/60s → ban 1h
- Disable default `sshd` jail (no SSH in proxy container) via `jail.d/defaults-debian.conf`

---

## CI/CD (Forgejo Runner)

- Runner container must have **no cross-container disk mounts**
- Deploy via SSH: `scp binary <system-container>:/opt/gbo/bin/botserver`
- SSH key from runner → system container must be pre-authorized
- sccache + cargo registry cache accumulates — daily cleanup cron required
- ZFS snapshots of CI container can be huge if taken while cross-mounts were active — delete stale snapshots after removing mounts

### Forgejo Workflow Location
Each submodule has its own workflow at `.forgejo/workflows/<name>.yaml`.

**botserver workflow:** `botserver/.forgejo/workflows/botserver.yaml`

### Deploy Step — CRITICAL
The deploy step must **kill the running botserver process before `scp`**, otherwise `scp` fails with `dest open: Failure` (binary is locked by running process):

```yaml
- name: Deploy via SSH
  run: |
    ssh pragmatismo-system "pkill -f /opt/gbo/bin/botserver || true; sleep 2"
    scp target/debug/botserver pragmatismo-system:/opt/gbo/bin/botserver
    ssh pragmatismo-system "chmod +x /opt/gbo/bin/botserver && cd /opt/gbo/bin && nohup sudo -u gbuser ./botserver --noconsole >> /opt/gbo/logs/error.log 2>&1 &"
```

**Never use `systemctl stop system.service`** — botserver is not managed by systemd, it runs as a process under `gbuser`.

### Binary Ownership
The binary at `/opt/gbo/bin/botserver` must be owned by `gbuser`, not `root`:
```bash
lxc exec pragmatismo-system -- chown gbuser:gbuser /opt/gbo/bin/botserver
```
If owned by root, `scp` as `gbuser` will fail even after killing the process.

---

## ZFS Disk Space

- Check snapshots: `zfs list -t snapshot -o name,used | sort -k2 -rh`
- Snapshots retain data from device mounts at time of snapshot — removing mounts doesn't free space until snapshot is deleted
- Delete snapshot: `zfs destroy <pool>/containers/<name>@<snapshot>`
- Daily rolling snapshots (7-day retention) via cron

---

## Git Workflow

Push to both remotes after every change:
```bash
cd <submodule>
git push origin main
git push alm main
cd ..
git add <submodule>
git commit -m "Update submodule"
git push alm main
```
Failure to push the root `gb` repo will not trigger CI/CD pipelines.

---

## Useful Commands

```bash
# Check all containers
lxc list

# Check disk device mounts per container
for c in $(lxc list --format csv -c n); do
  devices=$(lxc config device show $c | grep 'type: disk' | grep -v 'pool:' | wc -l)
  [ $devices -gt 0 ] && echo "=== $c ===" && lxc config device show $c | grep -E 'source:|path:' | grep -v pool
done

# Tail Caddy errors
lxc exec <tenant>-proxy -- tail -f /opt/gbo/logs/access.log

# Restart botserver + botui
lxc exec <tenant>-system -- systemctl restart system.service ui.service

# Check iptables in system container
lxc exec <tenant>-system -- iptables -L -n | grep -E 'DROP|ACCEPT.*lo'

# ZFS snapshot usage
zfs list -t snapshot -o name,used | sort -k2 -rh | head -20

# Unseal Vault (use actual unseal key from init.json)
lxc exec <tenant>-system -- bash -c "
  export VAULT_ADDR=https://127.0.0.1:8200 VAULT_SKIP_VERIFY=true
  /opt/gbo/bin/botserver-stack/bin/vault/vault operator unseal \$UNSEAL_KEY
"
```

---

## CI/CD Debugging

### Check CI Runner Container
```bash
# From production host, SSH to CI runner
ssh root@<tenant>-alm-ci

# Check CI workspace for cloned repos
ls /root/workspace/

# Test SSH to system container
ssh -o ConnectTimeout=5 pragmatismo-system 'hostname'
```

### Query CI Runs via Forgejo API
```bash
# List recent workflow runs for a repo
curl -s "http://alm.pragmatismo.com.br/api/v1/repos/GeneralBots/<repo>/actions/runs?limit=5"

# Trigger workflow manually (if token available)
curl -X POST "http://alm.pragmatismo.com.br/api/v1/repos/GeneralBots/<repo>/actions/workflows/<workflow>.yaml/runs"
```

### Check Binary Deployed
```bash
# From production host
lxc exec <tenant>-system -- stat /opt/gbo/bin/<binary> | grep Modify
lxc exec <tenant>-system -- strings /opt/gbo/bin/<binary> | grep '<expected_code_string>'
```

### CI Build Logs Location
```bash
# On CI runner (pragmatismo-alm-ci)
# Logs saved via: sudo cp /tmp/build.log /opt/gbo/logs/

# Access from production host
ssh root@<tenant>-alm-ci -- cat /opt/gbo/logs/*.log 2>/dev/null
```

### Common CI Issues

**SSH Connection Refused:**
- CI runner must have `pragmatismo-system` in `/root/.ssh/config` with IP `10.16.164.33`
- Check: `ssh -o ConnectTimeout=5 pragmatismo-system 'hostname'`

**Binary Not Updated After Deploy:**
- Verify binary modification time matches CI run time
- Check CI build source: Clone on CI runner and verify code
- Ensure `embed-ui` feature includes the file (RustEmbed embeds at compile time)
```bash
# Rebuild with correct features
cargo build --release -p botui --features embed-ui
```

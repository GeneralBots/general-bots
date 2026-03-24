# General Bots Cloud — Production Operations Guide

## Infrastructure Overview
- **Host OS:** Ubuntu 24.04 LTS, Incus
- **SSH:** Key auth only
- **Container engine:** Incus with ZFS storage pool
- **Tenant:** pragmatismo (migrated from LXD 82.29.59.188 to Incus 63.141.255.9)

---

## Container Migration: pragmatismo (COMPLETED)

### Summary
| Item | Detail |
|------|--------|
| Source | LXD 5.21 on Ubuntu 22.04 @ 82.29.59.188 |
| Destination | Incus 6.x on Ubuntu 24.04 @ 63.141.255.9 |
| Migration method | `incus copy --instance-only lxd-source:<name>` |
| Data transfer | rsync via SSH (pull from destination → source:/opt/gbo) |
| Total downtime | ~4 hours |
| Containers migrated | 10 |
| Data transferred | ~44 GB |

### Migrated Containers (destination names)
```
proxy         → proxy           (Caddy reverse proxy)
tables        → tables          (PostgreSQL)
system        → system          (botserver + botui, privileged)
drive         → drive           (MinIO S3)
dns           → dns             (CoreDNS)
email         → email           (Stalwart mail)
webmail       → webmail         (Roundcube)
alm           → alm             (Forgejo ALM)
alm-ci        → alm-ci          (Forgejo CI runner)
table-editor  → table-editor    (NocoDB)
```

### Data Paths
- **Source data:** `root@82.29.59.188:/opt/gbo/` (44 GB, tenant data + binaries)
- **Destination data:** `/home/administrator/gbo/tenants/pragmatismo/` (rsync in progress)
- **Final path:** `/opt/gbo/tenants/pragmatismo/` (symlink or mount)

### Key Decisions Made
1. **No `pragmatismo-` prefix** on destination (unlike source)
2. **iptables NAT** instead of Incus proxy devices (proxy devices conflicted with NAT rules)
3. **Incus proxy devices removed** from all containers after NAT configured
4. **Disk devices removed** from source containers before migration (Incus can't resolve LXD paths)

### Port Forwarding (iptables NAT)
| Port | Service |
|------|---------|
| 80, 443 | Caddy (HTTP/HTTPS) |
| 25, 465, 587 | SMTP |
| 993, 995, 143, 110, 4190 | IMAP/POP/Sieve |
| 53 | DNS |

### Remaining Post-Migration Tasks
- [x] **rsync transfer:** Source /opt/gbo → destination ~/gbo ✓
- [x] **Merge data:** rsync to /opt/gbo/tenants/pragmatismo/ ✓
- [x] **Configure NAT:** iptables PREROUTING rules ✓
- [x] **Update Caddy:** Replace old IPs with new 10.107.115.x IPs ✓
- [x] **Copy data to containers:** tar.gz method for proxy, tables, email, webmail, alm-ci, table-editor ✓
- [x] **Fix directory structure:** system, dns, alm ✓
- [x] **Caddy installed and running** ✓
- [ ] **SSL certificates:** Let's Encrypt rate limited - need to wait or use existing certs
- [ ] **botserver binary missing** in system container
- [ ] **DNS cutover:** Update NS/A records to point to 63.141.255.9
- [ ] **Source cleanup:** Delete /opt/gbo/ on source after verification

### Current Container Status (2026-03-22 17:50 UTC)
| Container | /opt/gbo/ contents | Status |
|-----------|---------------------|--------|
| proxy | conf, data, logs, Caddy running | ✓ OK (SSL pending) |
| tables | conf, data, logs, pgconf, pgdata | ✓ OK |
| email | conf, data, logs | ✓ OK |
| webmail | conf, data, logs | ✓ OK |
| alm-ci | conf, data, logs | ✓ OK |
| table-editor | conf, data, logs | ✓ OK |
| system | bin, botserver-stack, conf, data, logs | ✓ OK |
| drive | data, logs | ✓ OK |
| dns | bin, conf, data, logs | ✓ OK |
| alm | alm/, conf, data, logs | ✓ OK |

### Known Issues
1. **Let's Encrypt rate limiting** - Too many cert requests from old server. Certificates will auto-renew after rate limit clears (~1 hour)
2. **botserver database connection** - PostgreSQL is in tables container (10.107.115.33), need to update DATABASE_URL in system container
3. **SSL certificates** - Caddy will retry obtaining certs after rate limit clears

### Final Status (2026-03-22 18:30 UTC)

#### Container Services Status
| Container | Service | Port | Status |
|-----------|---------|------|--------|
| system | Vault | 8200 | ✓ Running |
| system | Valkey | 6379 | ✓ Running |
| system | MinIO | 9100 | ✓ Running |
| system | Qdrant | 6333 | ✓ Running |
| system | botserver | - | ⚠️ Not listening |
| tables | PostgreSQL | 5432 | ✓ Running |
| proxy | Caddy | 80, 443 | ✓ Running |
| dns | CoreDNS | 53 | ❌ Not running |
| email | Stalwart | 25,143,465,993,995 | ❌ Not running |
| webmail | Roundcube | - | ❌ Not running |
| alm | Forgejo | 3000 | ❌ Not running |
| alm-ci | Forgejo-runner | - | ❌ Not running |
| table-editor | NocoDB | - | ❌ Not running |
| drive | MinIO | - | ❌ (in system container) |

#### Issues Found
1. **botserver not listening** - needs DATABASE_URL pointing to tables container
2. **dns, email, webmail, alm, alm-ci, table-editor** - services not started
3. **SSL certificates** - Let's Encrypt rate limited

### Data Structure

**Host path:** `/opt/gbo/tenants/pragmatismo/<containername>/`  
**Container path:** `/opt/gbo/` (conf, data, logs, bin, etc.)

| Container | Host Path | Container /opt/gbo/ |
|-----------|-----------|---------------------|
| system | `.../system/` | bin, botserver-stack, conf, data, logs |
| proxy | `.../proxy/` | conf, data, logs |
| tables | `.../tables/` | conf, data, logs |
| drive | `.../drive/` | data, logs |
| dns | `.../dns/` | bin, conf, data, logs |
| email | `.../email/` | conf, data, logs |
| webmail | `.../webmail/` | conf, data, logs |
| alm | `.../alm/` | conf, data, logs |
| alm-ci | `.../alm-ci/` | conf, data, logs |
| table-editor | `.../table-editor/` | conf, data, logs |

### Attach Data Devices (after moving data)
```bash
# Move data to final location
ssh administrator@63.141.255.9 "sudo mv /home/administrator/gbo /opt/gbo/tenants/pragmatismo"

# Attach per-container disk device
for container in system proxy tables drive dns email webmail alm alm-ci table-editor; do
  incus config device add $container gbo disk \
    source=/opt/gbo/tenants/pragmatismo/$container \
    path=/opt/gbo
done

# Fix permissions (each container)
for container in system proxy tables drive dns email webmail alm alm-ci table-editor; do
  incus exec $container -- chown -R gbuser:gbuser /opt/gbo/ 2>/dev/null || \
    incus exec $container -- chown -R root:root /opt/gbo/
done
```

### Container IPs (for Caddy configuration)
```
system:       10.107.115.229
proxy:        10.107.115.189
tables:       10.107.115.33
drive:        10.107.115.114
dns:          10.107.115.155
email:        10.107.115.200
webmail:      10.107.115.208
alm:          10.107.115.4
alm-ci:       10.107.115.190
table-editor: (no IP - start container)
```

---

## LXC Container Architecture (destination)

| Container | Purpose | Exposed Ports |
|---|---|---|
| `proxy` | Caddy reverse proxy | 80, 443 |
| `system` | botserver + botui (privileged!) | internal only |
| `alm` | Forgejo (ALM/Git) | internal only |
| `alm-ci` | Forgejo CI runner | none |
| `email` | Stalwart mail server | 25,465,587,993,995,143,110 |
| `dns` | CoreDNS | 53 |
| `drive` | MinIO S3 | internal only |
| `tables` | PostgreSQL | internal only |
| `table-editor` | NocoDB | internal only |
| `webmail` | Roundcube | internal only |

## Key Rules
- `system` must be **privileged** (`security.privileged: true`) — required for botserver to own `/opt/gbo/` mounts
- All containers use **iptables NAT** for port forwarding — NEVER use Incus proxy devices (they conflict with NAT)
- **Data copied into each container** at `/opt/gbo/` — NOT disk devices. Each container has its own copy of data.
- CI runner (`alm-ci`) must NOT have cross-container disk device mounts — deploy via SSH only
- Caddy config must have correct upstream IPs for each backend container

## Container Migration (LXD to Incus) — COMPLETED

### Migration Workflow (for future tenants)

**Best Method:** `incus copy --instance-only` — transfers containers directly between LXD and Incus.

#### Prerequisites
```bash
# 1. Open port 8443 on both servers
ssh root@<source-host> "iptables -I INPUT -p tcp --dport 8443 -j ACCEPT"
ssh administrator@<dest-host> "sudo iptables -I INPUT -p tcp --dport 8443 -j ACCEPT"

# 2. Exchange SSH keys (for rsync data transfer)
ssh administrator@<dest-host> "cat ~/.ssh/id_rsa.pub"
ssh root@<source-host> "echo '<dest-pubkey>' >> /root/.ssh/authorized_keys"

# 3. Add source LXD as Incus remote
ssh administrator@<dest-host> "incus remote add lxd-source <source-ip> --protocol=incus --accept-certificate"

# 4. Add destination cert to source LXD trust
ssh <dest-user>@<dest-host> "cat ~/.config/incus/client.crt"
ssh root@<source-host> "lxc config trust add -"
```

#### Migration Steps
```bash
# 1. On SOURCE: Remove disk devices (Incus won't have source paths)
for c in $(lxc list --format csv -c n); do
  lxc stop $c
  for d in $(lxc config device list $c); do
    lxc config device remove $c $d
  done
done

# 2. On DESTINATION: Copy each container
incus copy --instance-only lxd-source:<source-container> <dest-name>
incus start <dest-name>

# 3. On DESTINATION: Add eth0 network to each container
incus config device add <container> eth0 nic name=eth0 network=incusbr0

# 4. On DESTINATION: Configure iptables NAT (not proxy devices!)
# See iptables NAT Setup above

# 5. On DESTINATION: Pull data via rsync (from destination to source)
ssh administrator@<dest-host> "rsync -avz --progress root@<source-ip>:/opt/gbo/ /home/administrator/gbo/"

# 6. On DESTINATION: Organize data per container
# Data is structured as: /home/administrator/gbo/<containername>/
# Each container gets its own folder with {conf,data,logs,bin}/

# 7. On DESTINATION: Move to final location
ssh administrator@<dest-host> "sudo mkdir -p /opt/gbo/tenants/"
ssh administrator@<dest-host> "sudo mv /home/administrator/gbo /opt/gbo/tenants/<tenant>/"

# 8. On DESTINATION: Copy data into each container
for container in system proxy tables drive dns email webmail alm alm-ci table-editor; do
  incus exec $container -- mkdir -p /opt/gbo
  incus file push --recursive /opt/gbo/tenants/<tenant>/$container/. $container/opt/gbo/
done

# 9. On DESTINATION: Fix permissions
for container in system proxy tables drive dns email webmail alm alm-ci table-editor; do
  incus exec $container -- chown -R gbuser:gbuser /opt/gbo/ 2>/dev/null || \
    incus exec $container -- chown -R root:root /opt/gbo/
done

# 10. On DESTINATION: Update Caddy config with new container IPs
# sed -i 's/10.16.164.x/10.107.115.x/g' /opt/gbo/conf/config
incus file push /tmp/new_caddy_config proxy/opt/gbo/conf/config

# 11. Reload Caddy
incus exec proxy -- /opt/gbo/bin/caddy reload --config /opt/gbo/conf/config --adapter caddyfile
```

#### iptables NAT Setup (on destination host)
```bash
# Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1

# NAT rules — proxy container (ports 80, 443)
sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination 10.107.115.189:80
sudo iptables -t nat -A PREROUTING -p tcp --dport 443 -j DNAT --to-destination 10.107.115.189:443

# NAT rules — email container (SMTP/IMAP)
sudo iptables -t nat -A PREROUTING -p tcp --dport 25 -j DNAT --to-destination 10.107.115.200:25
sudo iptables -t nat -A PREROUTING -p tcp --dport 465 -j DNAT --to-destination 10.107.115.200:465
sudo iptables -t nat -A PREROUTING -p tcp --dport 587 -j DNAT --to-destination 10.107.115.200:587
sudo iptables -t nat -A PREROUTING -p tcp --dport 993 -j DNAT --to-destination 10.107.115.200:993
sudo iptables -t nat -A PREROUTING -p tcp --dport 995 -j DNAT --to-destination 10.107.115.200:995
sudo iptables -t nat -A PREROUTING -p tcp --dport 143 -j DNAT --to-destination 10.107.115.200:143
sudo iptables -t nat -A PREROUTING -p tcp --dport 110 -j DNAT --to-destination 10.107.115.200:110
sudo iptables -t nat -A PREROUTING -p tcp --dport 4190 -j DNAT --to-destination 10.107.115.200:4190

# NAT rules — dns container (DNS)
sudo iptables -t nat -A PREROUTING -p udp --dport 53 -j DNAT --to-destination 10.107.115.155:53
sudo iptables -t nat -A PREROUTING -p tcp --dport 53 -j DNAT --to-destination 10.107.115.155:53

# Masquerade outgoing traffic
sudo iptables -t nat -A POSTROUTING -s 10.107.115.0/24 -j MASQUERADE

# Save rules
sudo netfilter-persistent save
```

#### Remove Incus Proxy Devices (after NAT is working)
```bash
for c in $(incus list --format csv -c n); do
  for d in $(incus config device list $c | grep proxy); do
    incus config device remove $c $d
  done
done
```

#### pragmatismo Migration Notes
- Source server: `root@82.29.59.188` (LXD 5.21, Ubuntu 22.04)
- Destination: `administrator@63.141.255.9` (Incus 6.x, Ubuntu 24.04)
- Container naming: No prefix on destination (`proxy` not `pragmatismo-proxy`)
- Data: rsync pull from destination (not push from source)

## Firewall (host)

### ⚠️ CRITICAL: NEVER Block SSH Port 22
**When installing ANY firewall (UFW, iptables, etc.), ALWAYS allow SSH (port 22) FIRST, before enabling the firewall.**

**Wrong order (will lock you out!):**
```bash
ufw enable  # BLOCKS SSH!
```

**Correct order:**
```bash
ufw allow 22/tcp   # FIRST: Allow SSH
ufw allow 80/tcp    # Allow HTTP
ufw allow 443/tcp   # Allow HTTPS
ufw enable         # THEN enable firewall
```

### Firewall Setup Steps
1. **Always allow SSH before enabling firewall:**
   ```bash
   sudo ufw allow 22/tcp
   ```

2. **Install UFW:**
   ```bash
   sudo apt-get install -y ufw
   ```

3. **Configure UFW with SSH allowed:**
   ```bash
   sudo ufw default forward ACCEPT
   sudo ufw allow 22/tcp
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   sudo ufw enable
   ```

4. **Persist iptables rules for NAT (containers):**
   Create `/etc/systemd/system/iptables-restore.service`:
   ```ini
   [Unit]
   Description=Restore iptables rules on boot
   After=network-pre.target
   Before=network.target
   DefaultDependencies=no

   [Service]
   Type=oneshot
   ExecStart=/bin/bash -c "/sbin/iptables-restore < /etc/iptables/rules.v4"
   RemainAfterExit=yes

   [Install]
   WantedBy=multi-user.target
   ```

   Save rules and enable:
   ```bash
   sudo iptables-save > /etc/iptables/rules.v4
   sudo systemctl enable iptables-restore.service
   ```

5. **Install fail2ban:**
   ```bash
   # Download fail2ban deb from http://ftp.us.debian.org/debian/pool/main/f/fail2ban/
   sudo dpkg -i fail2ban_*.deb
   sudo touch /var/log/auth.log
   sudo systemctl enable fail2ban
   sudo systemctl start fail2ban
   ```

6. **Configure fail2ban SSH jail:**
   ```bash
   sudo fail2ban-client status  # Should show sshd jail
   ```

### Requirements
- **ufw** with `DEFAULT_FORWARD_POLICY=ACCEPT` (needed for container internet)
- **fail2ban** on host (SSH jail) and in email container (mail jail)
- iptables NAT rules must persist via systemd service

---

## 🔧 Common Production Issues & Fixes

### Issue: Valkey/Redis Connection Timeout

**Symptom:** botserver logs show `Connection timed out (os error 110)` when connecting to cache at `localhost:6379`

**Root Cause:** iptables DROP rule for port 6379 blocks loopback traffic because no ACCEPT rule for `lo` interface exists before the DROP rules.

**Fix:**
```bash
# Insert loopback ACCEPT at top of INPUT chain
incus exec system -- iptables -I INPUT 1 -i lo -j ACCEPT

# Persist the rule
incus exec system -- bash -c 'iptables-save > /etc/iptables/rules.v4'

# Verify Valkey responds
incus exec system -- /opt/gbo/bin/botserver-stack/bin/cache/bin/valkey-cli ping
# Should return: PONG

# Restart botserver to pick up working cache
incus exec system -- systemctl restart system.service ui.service
```

**Prevention:** Always ensure loopback ACCEPT rule is at the top of iptables INPUT chain before any DROP rules.

### Issue: Suggestions Not Showing in Frontend

**Symptom:** Bot's start.bas has `ADD_SUGGESTION_TOOL` calls but suggestions don't appear in the UI.

**Diagnosis:**
```bash
# Get bot ID
incus exec system -- /opt/gbo/bin/botserver-stack/bin/tables/bin/psql -h localhost -U gbuser -d botserver -t -c "SELECT id, name FROM bots WHERE name = 'botname';"

# Check if suggestions exist in cache with correct bot_id
incus exec system -- /opt/gbo/bin/botserver-stack/bin/cache/bin/valkey-cli --scan --pattern "suggestions:<bot_id>:*"

# If no keys found, check logs for wrong bot_id being used
incus exec system -- grep "Adding suggestion to Redis key" /opt/gbo/logs/error.log | tail -5
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

**On destination (Incus):**
```bash
# Verify botserver binary
incus exec system -- stat /opt/gbo/bin/botserver | grep Modify

# Restart services
incus exec system -- systemctl restart system.service ui.service
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
- Reload: `incus exec proxy -- caddy reload --config /opt/gbo/conf/config --adapter caddyfile`
- Storage: `/opt/gbo/data/caddy`

**Upstream IPs (after migration):**
| Backend | IP |
|---------|-----|
| system (botserver) | 10.107.115.229:5858 |
| system (botui) | 10.107.115.229:5859 |
| tables (PostgreSQL) | 10.107.115.33:5432 |
| drive (MinIO S3) | 10.107.115.114:9000 |
| webmail | 10.107.115.208 |
| alm | 10.107.115.4 |
| table-editor | 10.107.115.x (assign IP first) |

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
incus exec system -- tail -f /opt/gbo/bin/botserver-stack/logs/cache/valkey.log

# PostgreSQL
incus exec system -- tail -f /opt/gbo/bin/botserver-stack/logs/tables/postgres.log

# Qdrant
incus exec system -- tail -f /opt/gbo/bin/botserver-stack/logs/vector_db/qdrant.log
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

- **ALWAYS use CI for deployment** — NEVER manually scp binaries. CI ensures consistent, auditable deployments.
- Runner container must have **no cross-container disk mounts**
- Deploy via SSH: `scp binary <system-container>:/opt/gbo/bin/botserver` (only from CI, not manually)
- SSH key from runner → system container must be pre-authorized
- sccache + cargo registry cache accumulates — daily cleanup cron required
- ZFS snapshots of CI container can be huge if taken while cross-mounts were active — delete stale snapshots after removing mounts

### Forgejo Workflow Location
Each submodule has its own workflow at `.forgejo/workflows/<name>.yaml`.

**botserver workflow:** `botserver/.forgejo/workflows/botserver.yaml`

### CI Deployment Flow
1. Push code to ALM → triggers CI workflow automatically
2. CI builds binary on `pragmatismo-alm-ci` runner
3. CI deploys to `pragmatismo-system` container via SSH
4. CI verifies botserver process is running after deploy
5. If CI fails → check logs at `/tmp/deploy-*.log` on CI runner

**To trigger CI manually:**
```bash
# Push to ALM
cd botserver && git push alm main

# Or via API
curl -X POST "http://alm.pragmatismo.com.br/api/v1/repos/GeneralBots/BotServer/actions/workflows/botserver.yaml/runs"
```

### SSH Hostname Setup (CI Runner)
The CI runner must resolve `system` hostname. Add to `/etc/hosts` **once** (manual step on host):
```bash
incus exec alm-ci -- bash -c 'echo "10.16.164.33 system" >> /etc/hosts'
```

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
incus exec system -- chown gbuser:gbuser /opt/gbo/bin/botserver
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
# Check all containers (Incus)
incus list

# Check disk device mounts per container
for c in $(incus list --format csv -c n); do
  devices=$(incus config device show $c | grep 'type: disk' | grep -v 'pool:' | wc -l)
  [ $devices -gt 0 ] && echo "=== $c ===" && incus config device show $c | grep -E 'source:|path:' | grep -v pool
done

# Tail Caddy errors
incus exec proxy -- tail -f /opt/gbo/logs/access.log

# Restart botserver + botui
incus exec system -- systemctl restart system.service ui.service

# Check iptables in system container
incus exec system -- iptables -L -n | grep -E 'DROP|ACCEPT.*lo'

# ZFS snapshot usage
zfs list -t snapshot -o name,used | sort -k2 -rh | head -20

# Unseal Vault (use actual unseal key from init.json)
incus exec system -- bash -c "
  export VAULT_ADDR=https://127.0.0.1:8200 VAULT_SKIP_VERIFY=true
  /opt/gbo/bin/botserver-stack/bin/vault/vault operator unseal \$UNSEAL_KEY
"

# Check rsync transfer progress (on destination)
du -sh /home/administrator/gbo
```

---

## CI/CD Debugging

### Check CI Runner Container
```bash
# From production host, SSH to CI runner
ssh root@alm-ci

# Check CI workspace for cloned repos
ls /root/workspace/

# Test SSH to system container
ssh -o ConnectTimeout=5 system 'hostname'
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
incus exec system -- stat /opt/gbo/bin/<binary> | grep Modify
incus exec system -- strings /opt/gbo/bin/<binary> | grep '<expected_code_string>'
```

### CI Build Logs Location
```bash
# On CI runner (alm-ci)
# Logs saved via: sudo cp /tmp/build.log /opt/gbo/logs/

# Access from production host
ssh root@alm-ci -- cat /opt/gbo/logs/*.log 2>/dev/null
```

### Common CI Issues

**SSH Connection Refused:**
- CI runner must have `system` in `/root/.ssh/config` with correct IP
- Check: `ssh -o ConnectTimeout=5 system 'hostname'`

**Binary Not Updated After Deploy:**
- Verify binary modification time matches CI run time
- Check CI build source: Clone on CI runner and verify code
- Ensure `embed-ui` feature includes the file (RustEmbed embeds at compile time)
```bash
# Rebuild with correct features
cargo build --release -p botui --features embed-ui
```

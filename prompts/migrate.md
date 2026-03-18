# Migration Plan: pragmatismo.com.br LXC → 63.141.255.9 Incus

## ✅ Progress Status (last updated 2026-03-17)

| Step | Status | Notes |
|---|---|---|
| Install Incus on dest | ✅ Done | v6.22 via zabbly repo |
| Install SSH key (no password) | ✅ Done | `/tmp/migrate_key` on local machine |
| `sudo incus admin init --minimal` | ✅ Done | dir pool created |
| `incus project create prod` | ⏳ Interrupted | Run manually (see Phase 1 below) |
| Host hardening (SSH) | ⏳ Not done | Run manually (see Phase 1 below) |
| Container migrations | ⏳ Not started | |

## ▶️ Resume From Here

SSH key is at `/tmp/migrate_key` (ephemeral — regenerate if rebooted):
```bash
# If /tmp/migrate_key is gone after reboot:
ssh-keygen -t ed25519 -f /tmp/migrate_key -N ""
ssh-copy-id -i /tmp/migrate_key.pub root@pragmatismo.com.br
# For dest, use paramiko or password once to push key again
```

Connect to destination:
```bash
ssh -i /tmp/migrate_key administrator@63.141.255.9
```



## Goals
- Move all containers from source (LXC + ZFS) to destination (Incus)
- Rename `pragmatismo-*` → `prod-*`
- Eliminate all host-mounted devices — each container owns its data internally under `/opt/gbo/`
- Storage pool uses `dir` backend: portable, zipable, Glacier-friendly
- Use **Incus projects** for tenant isolation and easy teleportation to other servers

---

## Why `dir` Storage Pool

- No ZFS/btrfs kernel modules needed
- Each container lives under `/var/lib/incus/storage-pools/default/containers/<name>/`
- The entire pool is a plain directory tree → `tar czf pool.tar.gz /var/lib/incus/storage-pools/default/` → upload to Glacier
- Incus projects make it trivial to `incus move --target` to another Incus server

---

## Incus Project Structure

```
incus project: prod          ← all production containers (this migration)
incus project: staging       ← future: staging environment
incus project: dev           ← future: dev/test environment
```

Create on destination:
```bash
sudo incus project create prod --config features.images=true --config features.storage.volumes=true
sudo incus project switch prod
```

To teleport a container to another Incus server later:
```bash
# Add remote
incus remote add server2 https://<ip>:8443

# Move live container across servers (same project)
incus move prod-alm server2:prod-alm --project prod
```

---

## Container Rename Map

| Source (LXC) | Destination (Incus, project=prod) |
|---|---|
| pragmatismo-alm | prod-alm |
| pragmatismo-alm-ci | prod-alm-ci |
| pragmatismo-dns | prod-dns |
| pragmatismo-drive | prod-drive |
| pragmatismo-email | prod-email |
| pragmatismo-proxy | prod-proxy |
| pragmatismo-system | prod-system |
| pragmatismo-table-editor | prod-table-editor |
| pragmatismo-tables | prod-tables |
| pragmatismo-webmail | prod-webmail |

---

## Data Internalization Map

All external host mounts are removed. Data lives inside the container under `/opt/gbo/`.

| Container | Old host mount | New internal path | Source data to copy in |
|---|---|---|---|
| prod-alm | `/opt/gbo/conf` | `/opt/gbo/conf` | `/opt/gbo/tenants/pragmatismo/alm/` |
| prod-alm-ci | `/opt/gbo/data` | `/opt/gbo/data` | `/opt/gbo/tenants/pragmatismo/alm-ci/` |
| prod-dns | `/opt/gbo/conf` | `/opt/gbo/conf` | `/opt/gbo/tenants/pragmatismo/dns/` |
| prod-drive | `/opt/gbo/data` | `/opt/gbo/data` | `/opt/gbo/tenants/pragmatismo/drive/` |
| prod-email | `/opt/gbo/conf` | `/opt/gbo/conf` | `/opt/gbo/tenants/pragmatismo/email/` |
| prod-proxy | `/opt/gbo/conf` | `/opt/gbo/conf` | `/opt/gbo/tenants/pragmatismo/proxy/` |
| prod-system | `/opt/gbo/bin` | `/opt/gbo/bin` | `/opt/gbo/tenants/pragmatismo/system/` |
| prod-table-editor | `/opt/gbo/conf` | `/opt/gbo/conf` | `/opt/gbo/tenants/pragmatismo/table-editor/` |
| prod-tables | `/opt/gbo/data/postgres` | `/opt/gbo/data/postgres` | `/opt/gbo/tenants/pragmatismo/tables/` |
| prod-webmail | `/opt/gbo/data` | `/opt/gbo/data` | `/opt/gbo/tenants/pragmatismo/webmail/` |

### Notes on prod-tables (PostgreSQL)
- Old mount was `/etc/postgresql/14/main` — generalized to `/opt/gbo/data/postgres`
- Inside container: symlink or configure `data_directory = /opt/gbo/data/postgres` in `postgresql.conf`
- Copy: `rsync -a /opt/gbo/tenants/pragmatismo/tables/ <container>:/opt/gbo/data/postgres/`

### Notes on prod-drive (MinIO)
- Old mount was `/var/log/minio` (logs only) — generalize to `/opt/gbo/data/minio`
- Inside container: set `MINIO_VOLUMES=/opt/gbo/data/minio` in MinIO env/service file
- Copy: `rsync -a /opt/gbo/tenants/pragmatismo/drive/ <container>:/opt/gbo/data/minio/`

---

## Phase 1 — Prepare Destination (once)

```bash
# On 63.141.255.9 — run each line separately, they can hang if chained

sudo systemctl start incus

sudo incus admin init --minimal

sudo incus project create prod --config features.images=true --config features.storage.volumes=true

sudo usermod -aG incus-admin administrator

sudo incus list --project prod

# Harden SSH (no password auth, no root login)
sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo systemctl reload ssh
```

---

## Phase 2 — Migrate Each Container

Repeat for each container. Example: `alm-ci`

### On source (pragmatismo.com.br)
```bash
NAME=alm-ci
SRC=pragmatismo-${NAME}

# Stop, export rootfs, tar tenant data
lxc stop ${SRC}
lxc export ${SRC} /tmp/${SRC}.tar.gz          # omit --optimized-storage (ZFS compat issues)
tar czf /tmp/${SRC}-data.tar.gz -C /opt/gbo/tenants/pragmatismo ${NAME}

# Transfer to destination
scp /tmp/${SRC}.tar.gz /tmp/${SRC}-data.tar.gz administrator@63.141.255.9:/tmp/

# Restart source (keep prod live during migration)
lxc start ${SRC}
```

### On destination (63.141.255.9)
```bash
NAME=alm-ci
SRC=pragmatismo-${NAME}
DEST=prod-${NAME}
INTERNAL_PATH=/opt/gbo/data          # adjust per table above

# Import into prod project
sudo incus import /tmp/${SRC}.tar.gz --alias ${DEST} --project prod

# Remove any leftover device mounts
sudo incus config device remove ${DEST} $(sudo incus config device list ${DEST} 2>/dev/null) 2>/dev/null || true

# Start container
sudo incus start ${DEST} --project prod

# Push tenant data into container
mkdir -p /tmp/restore-${NAME}
tar xzf /tmp/${SRC}-data.tar.gz -C /tmp/restore-${NAME}
sudo incus exec ${DEST} --project prod -- mkdir -p ${INTERNAL_PATH}
sudo incus file push -r /tmp/restore-${NAME}/${NAME}/. ${DEST}${INTERNAL_PATH}/ --project prod

# Verify
sudo incus exec ${DEST} --project prod -- ls ${INTERNAL_PATH}
sudo incus exec ${DEST} --project prod -- systemctl status --no-pager | head -20
```

---

## Phase 3 — PostgreSQL Reconfiguration (prod-tables)

```bash
sudo incus exec prod-tables --project prod -- bash -c "
  mkdir -p /opt/gbo/data/postgres
  chown postgres:postgres /opt/gbo/data/postgres
  # Update postgresql.conf
  sed -i \"s|data_directory.*|data_directory = '/opt/gbo/data/postgres'|\" /etc/postgresql/14/main/postgresql.conf
  systemctl restart postgresql
  psql -U postgres -c '\l'
"
```

---

## Phase 4 — MinIO Reconfiguration (prod-drive)

```bash
sudo incus exec prod-drive --project prod -- bash -c "
  mkdir -p /opt/gbo/data/minio
  # Update service env
  sed -i 's|MINIO_VOLUMES=.*|MINIO_VOLUMES=/opt/gbo/data/minio|' /etc/default/minio
  systemctl restart minio
"
```

---

## Phase 5 — Validate & Cutover

```bash
sudo incus list --project prod

# Spot checks
sudo incus exec prod-tables --project prod -- psql -U postgres -c '\l'
sudo incus exec prod-proxy --project prod -- nginx -t
sudo incus exec prod-dns --project prod -- named-checkconf
sudo incus exec prod-drive --project prod -- curl -s http://localhost:9000/minio/health/live

# When all green: update DNS to 63.141.255.9
```

---

## Glacier Backup

The entire pool is a plain dir — backup is just:

```bash
# Full backup
tar czf /tmp/incus-prod-$(date +%Y%m%d).tar.gz /var/lib/incus/storage-pools/default/

# Upload to Glacier
aws s3 cp /tmp/incus-prod-$(date +%Y%m%d).tar.gz s3://your-glacier-bucket/ \
  --storage-class DEEP_ARCHIVE

# Or per-container backup
tar czf /tmp/prod-alm-ci-$(date +%Y%m%d).tar.gz \
  /var/lib/incus/storage-pools/default/containers/prod-alm-ci/
```

---

## Teleporting to Another Server (Future)

```bash
# Add new server as remote
sudo incus remote add server3 https://<new-server-ip>:8443 --accept-certificate

# Move container live (no downtime with CRIU if kernel supports it)
sudo incus move prod-alm server3:prod-alm --project prod

# Or copy (keep original running)
sudo incus copy prod-alm server3:prod-alm --project prod
```

---

## Rollback
- Source containers stay running throughout — only DNS cutover commits the migration
- Keep source containers stopped (not deleted) for 30 days after cutover

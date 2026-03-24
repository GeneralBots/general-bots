# Container Bootstrap Plan — Automating GB Container Deployment

## Overview

This document describes how to improve `installer.rs` to automate the deployment of General Bots containers on Incus. The goal is to replicate what was done manually during the pragmatismo migration from LXD to Incus.

---

## What Was Done Manually (Reference Implementation)

### Migration Summary (pragmatismo tenant)
| Item | Detail |
|------|--------|
| Source | LXD 5.21 @ 82.29.59.188 |
| Destination | Incus 6.x @ 63.141.255.9 |
| Method | `incus copy --instance-only lxd-source:<name>` |
| Data transfer | tar.gz → push to containers |
| Containers | 10 (dns, email, webmail, alm, drive, tables, system, proxy, alm-ci, table-editor) |
| Total data | ~44 GB |

---

## Container Architecture (Reference)

### Container Types & Services

| Container | Purpose | Ports | Service Binary | Service User |
|-----------|---------|-------|---------------|-------------|
| **dns** | CoreDNS | 53 | `/opt/gbo/bin/coredns` | root |
| **email** | Stalwart mail | 25,143,465,587,993,995,110,4190 | `/opt/gbo/bin/stalwart` | root |
| **webmail** | Roundcube/PHP | 80,443 | Apache (`/usr/sbin/apache2`) | www-data |
| **alm** | Forgejo ALM | 4747 | `/opt/gbo/bin/forgejo` | gbuser |
| **drive** | MinIO S3 | 9000,9001 | `/opt/gbo/bin/minio` | root |
| **tables** | PostgreSQL | 5432 | system-installed | root |
| **system** | botserver + stack | 5858, 8200, 6379, 6333, 9100 | `/opt/gbo/bin/botserver` | gbuser |
| **proxy** | Caddy | 80, 443 | `/usr/bin/caddy` | gbuser |
| **alm-ci** | Forgejo runner | none | `/opt/gbo/bin/forgejo-runner` | root |
| **table-editor** | NocoDB | 8080 | system-installed | root |

**RULE: ALL services run as gbuser where possible, ALL data under /opt/gbo, Service name = container name (e.g., proxy-caddy.service)**

### Network Layout
```
Host (63.141.255.9)
├── Incus bridge (10.107.115.x)
│   ├── dns (10.107.115.155)
│   ├── email (10.107.115.200)
│   ├── webmail (10.107.115.87)
│   ├── alm (10.107.115.4)
│   ├── drive (10.107.115.114)
│   ├── tables (10.107.115.33)
│   ├── system (10.107.115.229)
│   ├── proxy (10.107.115.189)
│   ├── alm-ci (10.107.115.190)
│   └── table-editor (10.107.115.73)
└── iptables NAT → external ports
```

---

## Key Paths (Must Match Production)

Inside each container:
```
/opt/gbo/
├── bin/           # binaries (coredns, stalwart, forgejo, caddy, minio, postgres)
├── conf/          # service configs (Corefile, config.toml, app.ini)
├── data/          # app data (zone files, databases, repos)
└── logs/          # service logs
```

On host:
```
/opt/gbo/tenants/<tenant>/
├── dns/
│   ├── bin/
│   ├── conf/
│   ├── data/
│   └── logs/
├── email/
├── webmail/
├── alm/
├── drive/
├── tables/
├── system/
├── proxy/
├── alm-ci/
└── table-editor/
```

---

## Service Files (Templates)

**RULE: ALL services run as gbuser where possible, Service name = container name (e.g., dns.service, proxy-caddy.service)**

### dns.service (CoreDNS)
```ini
[Unit]
Description=CoreDNS
After=network.target

[Service]
User=root
WorkingDirectory=/opt/gbo
ExecStart=/opt/gbo/bin/coredns -conf /opt/gbo/conf/Corefile
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

### email.service (Stalwart)
```ini
[Unit]
Description=Stalwart Mail Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/gbo
ExecStart=/opt/gbo/bin/stalwart --config /opt/gbo/conf/config.toml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

### proxy-caddy.service
```ini
[Unit]
Description=Caddy Reverse Proxy
After=network.target

[Service]
User=gbuser
Group=gbuser
WorkingDirectory=/opt/gbo
ExecStart=/usr/bin/caddy run --config /opt/gbo/conf/config --adapter caddyfile
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

### alm.service (Forgejo)
```ini
[Unit]
Description=Forgejo Git Server
After=network.target

[Service]
User=gbuser
Group=gbuser
WorkingDirectory=/opt/gbo
ExecStart=/opt/gbo/bin/forgejo web --config /opt/gbo/conf/app.ini
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

### drive-minio.service
```ini
[Unit]
Description=MinIO Object Storage
After=network-online.target
Wants=network-online.target

[Service]
User=gbuser
Group=gbuser
WorkingDirectory=/opt/gbo
ExecStart=/opt/gbo/bin/minio server --console-address :4646 /opt/gbo/data
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### tables-postgresql.service
```ini
[Unit]
Description=PostgreSQL
After=network.target

[Service]
User=gbuser
Group=gbuser
WorkingDirectory=/opt/gbo
ExecStart=/opt/gbo/bin/postgres -D /opt/gbo/data -c config_file=/opt/gbo/conf/postgresql.conf
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

### webmail-apache.service
```ini
[Unit]
Description=Apache Webmail
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=/var/www/html
ExecStart=/usr/sbin/apache2 -D FOREGROUND
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

---

## iptables NAT Rules (CRITICAL - Use ONLY iptables, NEVER socat or Incus proxy devices)

### Prerequisites
```bash
# Enable IP forwarding (persistent)
echo "net.ipv4.ip_forward = 1" | sudo tee /etc/sysctl.d/99-ipforward.conf
sudo sysctl -w net.ipv4.ip_forward=1

# Enable route_localnet for NAT to work with localhost
echo "net.ipv4.conf.all.route_localnet = 1" | sudo tee /etc/sysctl.d/99-localnet.conf
sudo sysctl -w net.ipv4.conf.all.route_localnet=1
```

### Required NAT Rules (Complete Set)
```bash
# ==================
# DNS (dns container)
# ==================
sudo iptables -t nat -A PREROUTING -p udp --dport 53 -j DNAT --to-destination 10.107.115.155:53
sudo iptables -t nat -A PREROUTING -p tcp --dport 53 -j DNAT --to-destination 10.107.115.155:53
sudo iptables -t nat -A OUTPUT -p udp --dport 53 -j DNAT --to-destination 10.107.115.155:53
sudo iptables -t nat -A OUTPUT -p tcp --dport 53 -j DNAT --to-destination 10.107.115.155:53

# ==================
# Tables (PostgreSQL) - External port 4445
# ==================
sudo iptables -t nat -A PREROUTING -p tcp --dport 4445 -j DNAT --to-destination 10.107.115.33:5432
sudo iptables -t nat -A OUTPUT -p tcp --dport 4445 -j DNAT --to-destination 10.107.115.33:5432

# ==================
# Proxy (Caddy) - 80, 443
# ==================
sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination 10.107.115.189:80
sudo iptables -t nat -A PREROUTING -p tcp --dport 443 -j DNAT --to-destination 10.107.115.189:443

# ==================
# Email (email container) - Stalwart
# ==================
sudo iptables -t nat -A PREROUTING -p tcp --dport 25 -j DNAT --to-destination 10.107.115.200:25
sudo iptables -t nat -A PREROUTING -p tcp --dport 465 -j DNAT --to-destination 10.107.115.200:465
sudo iptables -t nat -A PREROUTING -p tcp --dport 587 -j DNAT --to-destination 10.107.115.200:587
sudo iptables -t nat -A PREROUTING -p tcp --dport 993 -j DNAT --to-destination 10.107.115.200:993
sudo iptables -t nat -A PREROUTING -p tcp --dport 995 -j DNAT --to-destination 10.107.115.200:995
sudo iptables -t nat -A PREROUTING -p tcp --dport 143 -j DNAT --to-destination 10.107.115.200:143
sudo iptables -t nat -A PREROUTING -p tcp --dport 110 -j DNAT --to-destination 10.107.115.200:110
sudo iptables -t nat -A PREROUTING -p tcp --dport 4190 -j DNAT --to-destination 10.107.115.200:4190

# ==================
# FORWARD rules (required for containers to receive traffic)
# ==================
sudo iptables -A FORWARD -p tcp -d 10.107.115.155 --dport 53 -j ACCEPT
sudo iptables -A FORWARD -p udp -d 10.107.115.155 --dport 53 -j ACCEPT
sudo iptables -A FORWARD -p tcp -d 10.107.115.33 --dport 5432 -j ACCEPT
sudo iptables -A FORWARD -p tcp -s 10.107.115.33 --sport 5432 -j ACCEPT
sudo iptables -A FORWARD -p tcp -d 10.107.115.189 --dport 80 -j ACCEPT
sudo iptables -A FORWARD -p tcp -d 10.107.115.189 --dport 443 -j ACCEPT
sudo iptables -A FORWARD -p tcp -s 10.107.115.189 -j ACCEPT
sudo iptables -A FORWARD -p tcp -d 10.107.115.200 -j ACCEPT
sudo iptables -A FORWARD -p tcp -s 10.107.115.200 -j ACCEPT

# ==================
# POSTROUTING MASQUERADE (for return traffic)
# ==================
sudo iptables -t nat -A POSTROUTING -p tcp -d 10.107.115.155 -j MASQUERADE
sudo iptables -t nat -A POSTROUTING -p udp -d 10.107.115.155 -j MASQUERADE
sudo iptables -t nat -A POSTROUTING -p tcp -d 10.107.115.33 -j MASQUERADE
sudo iptables -t nat -A POSTROUTING -p tcp -d 10.107.115.189 -j MASQUERADE
sudo iptables -t nat -A POSTROUTING -p tcp -d 10.107.115.200 -j MASQUERADE

# ==================
# INPUT rules (allow incoming)
# ==================
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 4445 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 53 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 53 -j ACCEPT

# ==================
# Save rules persistently
# ==================
sudo sh -c 'iptables-save > /etc/iptables/rules.v4'
```

### IMPORTANT RULES

1. **NEVER use socat** - It causes port conflicts and doesn't integrate with iptables NAT
2. **NEVER use Incus proxy devices** - They conflict with iptables NAT rules
3. **ALWAYS add OUTPUT rules** - PREROUTING only handles external traffic; local traffic needs OUTPUT
4. **ALWAYS add FORWARD rules** - Without them, traffic won't reach containers
5. **ALWAYS add POSTROUTING MASQUERADE** - Without it, return traffic won't work
6. **ALWAYS set route_localnet=1** - Required for localhost NAT to work

### Testing NAT
```bash
# Test from host
nc -zv 127.0.0.1 4445
# Should connect to PostgreSQL at 10.107.115.33:5432

# Test from external
nc -zv 63.141.255.9 4445
# Should connect to PostgreSQL at 10.107.115.33:5432

# Test DNS
dig @127.0.0.1 webmail.pragmatismo.com.br
# Should return 63.141.255.9
```

---

## CoreDNS Setup

### Corefile Template
```corefile
ddsites.com.br:53 {
    file /opt/gbo/data/ddsites.com.br.zone
    bind 0.0.0.0
    reload 6h
    acl {
        allow type ANY net 10.0.0.0/8 127.0.0.0/8
        allow type ANY net <HOST_IP>/32
        allow type A net 0.0.0.0/0
        allow type AAAA net 0.0.0.0/0
        allow type MX net 0.0.0.0/0
        allow type TXT net 0.0.0.0/0
        allow type NS net 0.0.0.0/0
        allow type SOA net 0.0.0.0/0
        allow type SRV net 0.0.0.0/0
        allow type CNAME net 0.0.0.0/0
        allow type HTTPS net 0.0.0.0/0
        allow type CAA net 0.0.0.0/0
        block
    }
    cache
    errors
}

pragmatismo.com.br:53 {
    file /opt/gbo/data/pragmatismo.com.br.zone
    bind 0.0.0.0
    reload 6h
    acl {
        allow type ANY net 10.0.0.0/8 127.0.0.0/8
        allow type ANY net <HOST_IP>/32
        allow type A net 0.0.0.0/0
        allow type AAAA net 0.0.0.0/0
        allow type MX net 0.0.0.0/0
        allow type TXT net 0.0.0.0/0
        allow type NS net 0.0.0.0/0
        allow type SOA net 0.0.0.0/0
        allow type SRV net 0.0.0.0/0
        allow type CNAME net 0.0.0.0/0
        allow type HTTPS net 0.0.0.0/0
        allow type CAA net 0.0.0.0/0
        block
    }
    cache
    errors
}

. {
    forward . 8.8.8.8 1.1.1.1
    cache
    errors
    log
}
```

### Zone File Template (pragmatismo.com.br)
```
$ORIGIN pragmatismo.com.br.
$TTL 3600

@ IN SOA ns1.ddsites.com.br. hostmaster.dmeans.info. (
    2026032301 ; Serial (YYYYMMDDNN)
    86400      ; Refresh
    900        ; Retry
    1209600    ; Expire
    3600       ; Minimum TTL
)

@                       IN CAA     0 issue "letsencrypt.org"
@                       IN CAA     0 issuewild ";"
@                       IN CAA     0 iodef "mailto:security@pragmatismo.com.br"

@                       IN HTTPS 1 . alpn="h2,h3"

@                       IN NS      ns1.ddsites.com.br.
@                       IN NS      ns2.ddsites.com.br.

@                       IN A       <HOST_IP>

ns1                     IN A       <HOST_IP>
ns2                     IN A       <HOST_IP>

@                       IN MX 10   mail.pragmatismo.com.br.

mail                    IN A       <HOST_IP>
www                     IN A       <HOST_IP>
webmail                 IN A       <HOST_IP>
drive                   IN A       <HOST_IP>
drive-api               IN A       <HOST_IP>
alm                     IN A       <HOST_IP>
tables                  IN A       <HOST_IP>
gb                      IN A       <HOST_IP>
gb6                     IN A       <HOST_IP>
```

### Starting CoreDNS in Container
```bash
# CoreDNS won't start via systemd in Incus containers by default
# Use nohup to start it
incus exec dns -- bash -c 'mkdir -p /opt/gbo/logs && nohup /opt/gbo/bin/coredns -conf /opt/gbo/conf/Corefile > /opt/gbo/logs/coredns.log 2>&1 &'
```

### DNS Zone Records (CRITICAL - Use A records, NOT CNAMEs for internal services)
```
# WRONG - CNAME causes resolution issues
webmail                 IN CNAME   mail

# CORRECT - Direct A record
webmail                 IN A       <HOST_IP>
mail                    IN A       <HOST_IP>
```

---

## Container Cleanup (BEFORE Setting Up NAT)

**ALWAYS remove socat and Incus proxy devices before configuring iptables NAT:**

```bash
# Remove socat
pkill -9 -f socat 2>/dev/null
rm -f /usr/bin/socat /usr/sbin/socat 2>/dev/null

# Remove all proxy devices from all containers
for c in $(incus list --format csv -c n); do
  for d in $(incus config device list $c 2>/dev/null | grep -E 'proxy|port'); do
    echo "Removing $d from $c"
    incus config device remove $c $d 2>/dev/null
  done
done
```

---

## installer.rs Improvements Required

### 1. New Module Structure

```
botserver/src/core/package_manager/
├── mod.rs
├── component.rs          # ComponentConfig (existing)
├── installer.rs         # PackageManager (existing)
├── container.rs         # NEW: Container deployment logic
└── templates/           # NEW: Service file templates
    ├── dns.service
    ├── email.service
    ├── alm.service
    ├── minio.service
    └── webmail.service
```

### 2. Container Settings in ComponentConfig

```rust
// Add to component.rs

#[derive(Debug, Clone)]
pub struct NatRule {
    pub port: u16,
    pub protocol: String,  // "tcp" or "udp"
}

#[derive(Debug, Clone)]
pub struct ContainerSettings {
    pub container_name: String,
    pub ip: String,
    pub user: String,
    pub group: Option<String>,
    pub working_dir: Option<String>,
    pub service_template: String,
    pub nat_rules: Vec<NatRule>,
    pub binary_path: String,        // "/opt/gbo/bin/coredns"
    pub config_path: String,         // "/opt/gbo/conf/Corefile"
    pub data_path: Option<String>,   // "/opt/gbo/data"
    pub exec_cmd_args: Vec<String>,  // ["--config", "/opt/gbo/conf/Corefile"]
    pub internal_ports: Vec<u16>,   // Ports container listens on internally
    pub external_port: Option<u16>,  // External port (if different from internal)
}
```

### 3. Component Registration with Container Settings

```rust
fn register_dns(&mut self) {
    self.components.insert(
        "dns".to_string(),
        ComponentConfig {
            name: "dns".to_string(),
            // ... existing fields ...
            
            // NEW: Container settings
            container: Some(ContainerSettings {
                container_name: "dns".to_string(),
                ip: "10.107.115.155".to_string(),
                user: "root".to_string(),
                group: None,
                working_dir: None,
                service_template: include_str!("templates/dns.service").to_string(),
                nat_rules: vec![
                    NatRule { port: 53, protocol: "tcp".to_string() },
                    NatRule { port: 53, protocol: "udp".to_string() },
                ],
                binary_path: "/opt/gbo/bin/coredns".to_string(),
                config_path: "/opt/gbo/conf/Corefile".to_string(),
                data_path: Some("/opt/gbo/data".to_string()),
                exec_cmd_args: vec!["-conf".to_string(), "/opt/gbo/conf/Corefile".to_string()],
                internal_ports: vec![53],
                external_port: Some(53),
            }),
        },
    );
}

fn register_tables(&mut self) {
    // PostgreSQL with external port 4445
    self.components.insert(
        "tables".to_string(),
        ComponentConfig {
            name: "tables".to_string(),
            container: Some(ContainerSettings {
                container_name: "tables".to_string(),
                ip: "10.107.115.33".to_string(),
                user: "root".to_string(),
                nat_rules: vec![
                    NatRule { port: 4445, protocol: "tcp".to_string() },
                ],
                internal_ports: vec![5432],
                external_port: Some(4445),
                // ...
            }),
        },
    );
}
```

### 4. Container Deployment Methods

```rust
// Add to installer.rs

impl PackageManager {
    
    /// Bootstrap a container with all its services and NAT rules
    pub async fn bootstrap_container(
        &self,
        container_name: &str,
        source_lxd: Option<&str>,
    ) -> Result<()> {
        info!("Bootstrapping container: {}", container_name);
        
        // 0. CLEANUP - Remove any existing socat or proxy devices
        self.cleanup_existing(container_name).await?;
        
        // 1. Copy from source LXD if migrating
        if let Some(source_remote) = source_lxd {
            self.copy_container(source_remote, container_name).await?;
        }
        
        // 2. Ensure network is configured
        self.ensure_network(container_name).await?;
        
        // 3. Sync data from host to container
        self.sync_data_to_container(container_name).await?;
        
        // 4. Fix permissions
        self.fix_permissions(container_name).await?;
        
        // 5. Install and start service
        self.install_systemd_service(container_name).await?;
        
        // 6. Configure NAT rules on host (ONLY iptables, never socat)
        self.configure_iptables_nat(container_name).await?;
        
        // 7. Reload DNS if dns container
        if container_name == "dns" {
            self.reload_dns_zones().await?;
        }
        
        info!("Container {} bootstrapped successfully", container_name);
        Ok(())
    }
    
    /// Cleanup existing socat and proxy devices
    async fn cleanup_existing(&self, container: &str) -> Result<()> {
        // Remove socat processes
        SafeCommand::new("pkill")
            .and_then(|c| c.arg("-9"))
            .and_then(|c| c.arg("-f"))
            .and_then(|c| c.arg("socat"))
            .execute()?;
        
        // Remove proxy devices from container
        let output = SafeCommand::new("incus")
            .and_then(|c| c.arg("config"))
            .and_then(|c| c.arg("device"))
            .and_then(|c| c.arg("list"))
            .and_then(|c| c.arg(container))
            .and_then(|cmd| cmd.execute_with_output())?;
        
        let output_str = String::from_utf8_lossy(&output.stdout);
        for line in output_str.lines() {
            if line.contains("proxy") || line.contains("port") {
                let parts: Vec<&str> = line.split_whitespace().collect();
                if let Some(name) = parts.first() {
                    SafeCommand::new("incus")
                        .and_then(|c| c.arg("config"))
                        .and_then(|c| c.arg("device"))
                        .and_then(|c| c.arg("remove"))
                        .and_then(|c| c.arg(container))
                        .and_then(|c| c.arg(name))
                        .execute()?;
                }
            }
        }
        
        Ok(())
    }
    
    /// Copy container from LXD source
    async fn copy_container(&self, source_remote: &str, name: &str) -> Result<()> {
        info!("Copying container {} from {}", name, source_remote);
        
        SafeCommand::new("incus")
            .and_then(|c| c.arg("copy"))
            .and_then(|c| c.arg("--instance-only"))
            .and_then(|c| c.arg(format!("{}:{}", source_remote, name)))
            .and_then(|c| c.arg(name))
            .and_then(|cmd| cmd.execute())
            .context("Failed to copy container")?;
        
        SafeCommand::new("incus")
            .and_then(|c| c.arg("start"))
            .and_then(|c| c.arg(name))
            .and_then(|cmd| cmd.execute())
            .context("Failed to start container")?;
            
        Ok(())
    }
    
    /// Add eth0 network to container
    async fn ensure_network(&self, container: &str) -> Result<()> {
        let output = SafeCommand::new("incus")
            .and_then(|c| c.arg("config"))
            .and_then(|c| c.arg("device"))
            .and_then(|c| c.arg("list"))
            .and_then(|c| c.arg(container))
            .and_then(|cmd| cmd.execute_with_output())?;
            
        let output_str = String::from_utf8_lossy(&output.stdout);
        if !output_str.contains("eth0") {
            SafeCommand::new("incus")
                .and_then(|c| c.arg("config"))
                .and_then(|c| c.arg("device"))
                .and_then(|c| c.arg("add"))
                .and_then(|c| c.arg(container))
                .and_then(|c| c.arg("eth0"))
                .and_then(|c| c.arg("nic"))
                .and_then(|c| c.arg("name=eth0"))
                .and_then(|c| c.arg("network=PROD-GBO"))
                .and_then(|cmd| cmd.execute())?;
        }
        Ok(())
    }
    
    /// Sync data from host to container
    async fn sync_data_to_container(&self, container: &str) -> Result<()> {
        let source_path = format!(
            "/opt/gbo/tenants/{}/{}/",
            self.tenant, container
        );
        
        if Path::new(&source_path).exists() {
            info!("Syncing data for {}", container);
            
            SafeCommand::new("incus")
                .and_then(|c| c.arg("exec"))
                .and_then(|c| c.arg(container))
                .and_then(|c| c.arg("--"))
                .and_then(|c| c.arg("mkdir"))
                .and_then(|c| c.arg("-p"))
                .and_then(|c| c.arg("/opt/gbo"))
                .and_then(|cmd| cmd.execute())?;
            
            SafeCommand::new("incus")
                .and_then(|c| c.arg("file"))
                .and_then(|c| c.arg("push"))
                .and_then(|c| c.arg("--recursive"))
                .and_then(|c| c.arg(format!("{}.", source_path)))
                .and_then(|c| c.arg(format!("{}:/opt/gbo/", container)))
                .and_then(|cmd| cmd.execute())?;
        }
        Ok(())
    }
    
    /// Fix file permissions based on container user
    async fn fix_permissions(&self, container: &str) -> Result<()> {
        let settings = self.get_container_settings(container)?;
        
        if let Some(user) = &settings.user {
            let chown_cmd = if let Some(group) = &settings.group {
                format!("chown -R {}:{} /opt/gbo/", user, group)
            } else {
                format!("chown -R {}:{} /opt/gbo/", user, user)
            };
            
            SafeCommand::new("incus")
                .and_then(|c| c.arg("exec"))
                .and_then(|c| c.arg(container))
                .and_then(|c| c.arg("--"))
                .and_then(|c| c.arg("sh"))
                .and_then(|c| c.arg("-c"))
                .and_then(|c| c.arg(&chown_cmd))
                .and_then(|cmd| cmd.execute())?;
        }
        
        // Make binaries executable
        SafeCommand::new("incus")
            .and_then(|c| c.arg("exec"))
            .and_then(|c| c.arg(container))
            .and_then(|c| c.arg("--"))
            .and_then(|c| c.arg("chmod"))
            .and_then(|c| c.arg("+x"))
            .and_then(|c| c.arg(format!("{}/bin/*", self.base_path.display())))
            .and_then(|cmd| cmd.execute())?;
            
        Ok(())
    }
    
    /// Install systemd service file and start
    async fn install_systemd_service(&self, container: &str) -> Result<()> {
        let settings = self.get_container_settings(container)?;
        
        let service_name = format!("{}.service", container);
        let temp_path = format!("/tmp/{}", service_name);
        
        std::fs::write(&temp_path, &settings.service_template)
            .context("Failed to write service template")?;
        
        SafeCommand::new("incus")
            .and_then(|c| c.arg("file"))
            .and_then(|c| c.arg("push"))
            .and_then(|c| c.arg(&temp_path))
            .and_then(|c| c.arg(format!("{}:/etc/systemd/system/{}", container, service_name)))
            .and_then(|cmd| cmd.execute())?;
        
        for cmd_args in [
            ["daemon-reload"],
            &["enable", &service_name],
            &["start", &service_name],
        ] {
            let mut cmd = SafeCommand::new("incus")
                .and_then(|c| c.arg("exec"))
                .and_then(|c| c.arg(container))
                .and_then(|c| c.arg("--"))
                .and_then(|c| c.arg("systemctl"));
                
            for arg in cmd_args {
                cmd = cmd.and_then(|c| c.arg(arg));
            }
            cmd.execute()?;
        }
        
        std::fs::remove_file(&temp_path).ok();
        Ok(())
    }
    
    /// Configure iptables NAT rules on host - ONLY method allowed, NEVER socat
    async fn configure_iptables_nat(&self, container: &str) -> Result<()> {
        let settings = self.get_container_settings(container)?;
        
        // Set route_localnet if not already set
        SafeCommand::new("sudo")
            .and_then(|c| c.arg("sysctl"))
            .and_then(|c| c.arg("-w"))
            .and_then(|c| c.arg("net.ipv4.conf.all.route_localnet=1"))
            .execute()?;
        
        for rule in &settings.nat_rules {
            // PREROUTING rule - for external traffic
            SafeCommand::new("sudo")
                .and_then(|c| c.arg("iptables"))
                .and_then(|c| c.arg("-t"))
                .and_then(|c| c.arg("nat"))
                .and_then(|c| c.arg("-A"))
                .and_then(|c| c.arg("PREROUTING"))
                .and_then(|c| c.arg("-p"))
                .and_then(|c| c.arg(&rule.protocol))
                .and_then(|c| c.arg("--dport"))
                .and_then(|c| c.arg(rule.port.to_string()))
                .and_then(|c| c.arg("-j"))
                .and_then(|c| c.arg("DNAT"))
                .and_then(|c| c.arg("--to-destination"))
                .and_then(|c| c.arg(format!("{}:{}", settings.ip, rule.port)))
                .and_then(|cmd| cmd.execute())?;
            
            // OUTPUT rule - for local traffic (CRITICAL for NAT to work)
            SafeCommand::new("sudo")
                .and_then(|c| c.arg("iptables"))
                .and_then(|c| c.arg("-t"))
                .and_then(|c| c.arg("nat"))
                .and_then(|c| c.arg("-A"))
                .and_then(|c| c.arg("OUTPUT"))
                .and_then(|c| c.arg("-p"))
                .and_then(|c| c.arg(&rule.protocol))
                .and_then(|c| c.arg("--dport"))
                .and_then(|c| c.arg(rule.port.to_string()))
                .and_then(|c| c.arg("-j"))
                .and_then(|c| c.arg("DNAT"))
                .and_then(|c| c.arg("--to-destination"))
                .and_then(|c| c.arg(format!("{}:{}", settings.ip, rule.port)))
                .and_then(|cmd| cmd.execute())?;
            
            // FORWARD rules
            SafeCommand::new("sudo")
                .and_then(|c| c.arg("iptables"))
                .and_then(|c| c.arg("-A"))
                .and_then(|c| c.arg("FORWARD"))
                .and_then(|c| c.arg("-p"))
                .and_then(|c| c.arg(&rule.protocol))
                .and_then(|c| c.arg("-d"))
                .and_then(|c| c.arg(&settings.ip))
                .and_then(|c| c.arg("--dport"))
                .and_then(|c| c.arg(rule.port.to_string()))
                .and_then(|c| c.arg("-j"))
                .and_then(|c| c.arg("ACCEPT"))
                .and_then(|cmd| cmd.execute())?;
        }
        
        // POSTROUTING MASQUERADE for return traffic
        SafeCommand::new("sudo")
            .and_then(|c| c.arg("iptables"))
            .and_then(|c| c.arg("-t"))
            .and_then(|c| c.arg("nat"))
            .and_then(|c| c.arg("-A"))
            .and_then(|c| c.arg("POSTROUTING"))
            .and_then(|c| c.arg("-p"))
            .and_then(|c| c.arg("tcp"))
            .and_then(|c| c.arg("-d"))
            .and_then(|c| c.arg(&settings.ip))
            .and_then(|c| c.arg("-j"))
            .and_then(|c| c.arg("MASQUERADE"))
            .and_then(|cmd| cmd.execute())?;
        
        // Save rules
        SafeCommand::new("sudo")
            .and_then(|c| c.arg("sh"))
            .and_then(|c| c.arg("-c"))
            .and_then(|c| c.arg("iptables-save > /etc/iptables/rules.v4"))
            .and_then(|cmd| cmd.execute())?;
        
        Ok(())
    }
    
    /// Start CoreDNS (special case - doesn't work well with systemd in Incus)
    async fn start_coredns(&self, container: &str) -> Result<()> {
        SafeCommand::new("incus")
            .and_then(|c| c.arg("exec"))
            .and_then(|c| c.arg(container))
            .and_then(|c| c.arg("--"))
            .and_then(|c| c.arg("bash"))
            .and_then(|c| c.arg("-c"))
            .and_then(|c| c.arg("mkdir -p /opt/gbo/logs && nohup /opt/gbo/bin/coredns -conf /opt/gbo/conf/Corefile > /opt/gbo/logs/coredns.log 2>&1 &"))
            .and_then(|cmd| cmd.execute())?;
        
        Ok(())
    }
    
    /// Reload DNS zones with new IPs
    async fn reload_dns_zones(&self) -> Result<()> {
        // Update zone files to point to new IP
        SafeCommand::new("incus")
            .and_then(|c| c.arg("exec"))
            .and_then(|c| c.arg("dns"))
            .and_then(|c| c.arg("--"))
            .and_then(|c| c.arg("sh"))
            .and_then(|c| c.arg("-c"))
            .and_then(|c| c.arg("sed -i 's/OLD_IP/NEW_IP/g' /opt/gbo/data/*.zone"))
            .and_then(|cmd| cmd.execute())?;
        
        // Restart coredns
        self.start_coredns("dns").await?;
        
        Ok(())
    }
    
    /// Get container settings for a component
    fn get_container_settings(&self, container: &str) -> Result<&ContainerSettings> {
        self.components
            .get(container)
            .and_then(|c| c.container.as_ref())
            .context("Container settings not found")
    }
}
```

### 5. Binary Installation (For Fresh Containers)

```rust
/// Install binary to container from URL or fallback
async fn install_binary_to_container(
    &self,
    container: &str,
    component: &str,
) -> Result<()> {
    let config = self.components.get(component)
        .context("Component not found")?;
    
    let binary_name = config.binary_name.as_ref()
        .context("No binary name")?;
    
    let settings = config.container.as_ref()
        .context("No container settings")?;
    
    // Check if already exists
    let check = SafeCommand::new("incus")
        .and_then(|c| c.arg("exec"))
        .and_then(|c| c.arg(container))
        .and_then(|c| c.arg("--"))
        .and_then(|c| c.arg("test"))
        .and_then(|c| c.arg("-f"))
        .and_then(|c| c.arg(&settings.binary_path))
        .and_then(|cmd| cmd.execute());
    
    if check.is_ok() {
        info!("Binary {} already exists in {}", binary_name, container);
        return Ok(());
    }
    
    // Download if URL available
    if let Some(url) = &config.download_url {
        self.download_and_push_binary(container, url, binary_name).await?;
    }
    
    // Make executable
    SafeCommand::new("incus")
        .and_then(|c| c.arg("exec"))
        .and_then(|c| c.arg(container))
        .and_then(|c| c.arg("--"))
        .and_then(|c| c.arg("chmod"))
        .and_then(|c| c.arg("+x"))
        .and_then(|c| c.arg(&settings.binary_path))
        .and_then(|cmd| cmd.execute())?;
        
    Ok(())
}
```

---

## Full Bootstrap API

```rust
/// Bootstrap an entire tenant
pub async fn bootstrap_tenant(
    state: &AppState,
    tenant: &str,
    containers: &[&str],
    source_remote: Option<&str>,
) -> Result<()> {
    let pm = PackageManager::new(InstallMode::Container, Some(tenant.to_string()))?;
    
    for container in containers {
        pm.bootstrap_container(container, source_remote).await?;
    }
    
    info!("Tenant {} bootstrapped successfully", tenant);
    Ok(())
}

/// Bootstrap all pragmatismo containers
pub async fn bootstrap_pragmatismo(state: &AppState) -> Result<()> {
    let containers = [
        "dns", "email", "webmail", "alm", "drive",
        "tables", "system", "proxy", "alm-ci", "table-editor"
    ];
    
    bootstrap_tenant(state, "pragmatismo", &containers, Some("lxd-source")).await
}
```

---

## Command Line Usage

```bash
# Bootstrap single container
cargo run --bin bootstrap -- container dns --tenant pragmatismo

# Bootstrap all containers for a tenant
cargo run --bin bootstrap -- tenant pragmatismo --source lxd-source

# Only sync data (no copy from LXD)
cargo run --bin bootstrap -- sync-data dns --tenant pragmatismo

# Only configure NAT
cargo run --bin bootstrap -- configure-nat --container dns

# Only install service
cargo run --bin bootstrap -- install-service dns

# Clean up socat and proxy devices
cargo run --bin bootstrap -- cleanup --container dns
```

---

## Files to Create/Modify

### New Files
1. `botserver/src/core/package_manager/container.rs` - Container deployment logic
2. `botserver/src/core/package_manager/templates/dns.service`
3. `botserver/src/core/package_manager/templates/email.service`
4. `botserver/src/core/package_manager/templates/alm.service`
5. `botserver/src/core/package_manager/templates/minio.service`
6. `botserver/src/core/package_manager/templates/webmail.service`
7. `botserver/src/core/package_manager/templates/tables-postgresql.service`

### Modified Files
1. `botserver/src/core/package_manager/component.rs` - Add ContainerSettings
2. `botserver/src/core/package_manager/installer.rs` - Add container methods, update registrations

---

## Testing Checklist

After implementation, verify:
- [ ] `incus list` shows all containers running
- [ ] `nc -zv 127.0.0.1 4445` - PostgreSQL accessible
- [ ] `dig @127.0.0.1 webmail.pragmatismo.com.br` - Returns correct IP
- [ ] `curl https://webmail.pragmatismo.com.br` - Webmail accessible
- [ ] NAT rules work from external IP
- [ ] Zone files have correct A records (not CNAMEs)
- [ ] Services survive container restart
- [ ] `which socat` returns nothing on host
- [ ] No proxy devices in any container

---

## Known Issues Fixed

1. **socat conflicts with iptables** - NEVER use socat, use ONLY iptables NAT
2. **Incus proxy devices conflict with NAT** - Remove all proxy devices before setting up NAT
3. **PREROUTING doesn't handle local traffic** - Must add OUTPUT rules
4. **CoreDNS won't start via systemd in Incus** - Use nohup instead
5. **DNS CNAME resolution issues** - Use A records for internal services
6. **route_localnet needed for localhost NAT** - Set sysctl before NAT rules
7. **FORWARD chain blocks container traffic** - Must add FORWARD ACCEPT rules
8. **Return traffic fails without MASQUERADE** - Add POSTROUTING MASQUERADE rules
9. **Binary permissions** - chmod +x after push
10. **Apache SSL needs mod_ssl enabled** - Run `a2enmod ssl` before starting Apache

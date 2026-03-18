# Config from Vault Plan - ALL COMPONENTS

## Goal
ALL component configs read from Vault at runtime instead of hardcoded `InternalUrls`.

## Current State
- Only `VAULT_ADDR` and `VAULT_TOKEN` in `.env`
- ALL other configs hardcoded in `InternalUrls` (urls.rs)
- Component credentials stored in Vault defaults but NOT read at runtime

## ALL Components to Update

| Component | Current Hardcoded | Vault Path | Keys Needed |
|-----------|-----------------|------------|-------------|
| **Drive** | `localhost:9100` | `secret/gbo/drive` | host, port, accesskey, secret |
| **Database** | `localhost:5432` | `secret/gbo/tables` | host, port, database, username, password |
| **Cache** | `localhost:6379` | `secret/gbo/cache` | host, port, password |
| **Directory** | `localhost:8300` | `secret/gbo/directory` | url, project_id, client_id, client_secret |
| **Email/SMTP** | `localhost:8025` | `secret/gbo/email` | smtp_host, smtp_port, smtp_user, smtp_password, smtp_from |
| **LLM** | `localhost:8081` | `secret/gbo/llm` | url, model, openai_key, anthropic_key, ollama_url |
| **LiveKit** | `localhost:7880` | `secret/gbo/meet` | url, app_id, app_secret |
| **VectorDB** | `localhost:6334` | `secret/gbo/vectordb` | url, api_key |
| **Embedding** | `localhost:8082` | `secret/gbo/embedding` | url |
| **Qdrant** | `localhost:6334` | `secret/gbo/qdrant` | url, api_key |
| **Forgejo** | `localhost:3000` | `secret/gbo/forgejo` | url, token |
| **Observability** | `localhost:8086` | `secret/gbo/observability` | url, org, bucket, token |
| **ALM** | `localhost:9000` | `secret/gbo/alm` | url, token, default_org |
| **Cloud** | - | `secret/gbo/cloud` | region, access_key, secret_key |

## Implementation Steps

### Step 1: Modify `config/mod.rs`
Change ALL configs to read from Vault.

**Before:**
```rust
let drive = DriveConfig {
    server: InternalUrls::DRIVE.to_string(),
    ...
};
```

**After:**
```rust
let drive = DriveConfig {
    server: get_vault_or_default("gbo/drive", "host", "localhost:9100"),
    access_key: get_vault_or_default("gbo/drive", "accesskey", "minioadmin"),
    secret_key: get_vault_or_default("gbo/drive", "secret", "minioadmin"),
};
```

Same pattern for Database, Cache, Email, LLM, etc.

### Step 2: Add Helper Function
Create in `secrets/mod.rs`:
```rust
pub fn get_vault_or_default(path: &str, key: &str, default: &str) -> String {
    // Try to get from Vault at runtime
    // Fallback to default if not found
}
```

### Step 3: Container Installer (`facade.rs`)
When running `botserver install <component> --container`:
1. Create container
2. Install component
3. **Store URL + credentials in Vault** (`secret/gbo/<component>`)
4. Botserver reads from Vault at runtime

### Step 4: Default Values
Keep defaults in `secrets/mod.rs` for fallback when Vault not available.

## Files to Modify
- `src/core/config/mod.rs` - Read ALL from Vault
- `src/core/secrets/mod.rs` - Add helper + keep defaults
- `src/core/package_manager/facade.rs` - Container installer stores in Vault

## Test Commands
```bash
# Store ANY component config in Vault (secure interactive)
botserver vault put gbo/drive
botserver vault put gbo/tables
botserver vault put gbo/cache

# Verify
botserver vault get gbo/drive
```

## Key Principle
**Only VAULT_ADDR and VAULT_TOKEN in .env!**
All other configs from Vault at runtime.

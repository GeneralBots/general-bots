# Zitadel OAuth Client Automatic Creation - Action Plan

## Current Status (March 1, 2026)

### ✅ FIXED: Health Check & Proxy Issues

**Problems Fixed:**
1. Zitadel health checks used port **9000** but Zitadel runs on port **8300**
2. BotUI proxy used `https://localhost:9000` but BotServer runs on `http://localhost:8080`
3. Directory base URL used port 9000 instead of 8300

**Files Fixed:**
1. `botserver/src/core/bootstrap/bootstrap_utils.rs` - Health check port 9000 → 8300
2. `botserver/src/core/package_manager/installer.rs` - ZITADEL_EXTERNALPORT and check_cmd 9000 → 8300
3. `botserver/src/core/directory/api.rs` - Health check URL to port 8300
4. `botlib/src/http_client.rs` - DEFAULT_BOTSERVER_URL to http://localhost:8080
5. `botserver/src/core/urls.rs` - DIRECTORY_BASE to port 8300

**Results:**
- ✅ Zitadel health check: 2 seconds (was 300 seconds)
- ✅ BotUI proxy: correct routing to BotServer
- ✅ Bootstrap completes successfully
- ✅ No more 502 Bad Gateway errors

### ❌ REMAINING: OAuth Client Not Created

**Problem:**
```json
{
  "error": "Authentication service not configured",
  "details": "OAuth client credentials not available"
}
```

**Root Cause:**
- File `botserver-stack/conf/system/directory_config.json` is **MISSING**
- Bootstrap cannot extract Zitadel credentials from logs
- OAuth client creation fails
- Login fails

## Root Cause Analysis

### Why the Previous Fix Failed

The commit `86cfccc2` (Jan 6, 2026) added:
- `extract_initial_admin_from_log()` to parse Zitadel logs
- Password grant authentication support
- Directory config saving

**But it doesn't work because:**
1. **Zitadel doesn't log credentials** in the expected format
2. Log parsing returns `None`
3. Without credentials, OAuth client creation fails
4. Config file is never created
5. **Chicken-and-egg problem persists**

### The Real Solution

**Instead of parsing logs, the bootstrap should:**
1. **Generate admin credentials** using `generate_secure_password()`
2. **Create admin user in Zitadel** using Zitadel's Management API
3. **Use those exact credentials** to create OAuth client
4. **Save config** to `botserver-stack/conf/system/directory_config.json`
5. **Display credentials** to user via console and `~/.gb-setup-credentials`

## Automatic Solution Design

### Architecture

```
Bootstrap Flow (First Run):
1. Start Zitadel service
2. Wait for Zitadel to be ready (health check)
3. Check if directory_config.json exists
   - If YES: Load config, skip creation
   - If NO: Proceed to step 4
4. Generate admin credentials (username, email, password)
5. Create admin user in Zitadel via Management API
6. Create OAuth application via Management API
7. Save directory_config.json to botserver-stack/conf/system/
8. Display credentials to user
9. Continue bootstrap

Bootstrap Flow (Subsequent Runs):
1. Start Zitadel service
2. Wait for Zitadel to be ready
3. Check if directory_config.json exists
   - If YES: Load config, verify OAuth client
   - If NO: Run first-run flow
4. Continue bootstrap
```

### Key Changes Required

#### 1. Fix `setup_directory()` in `mod.rs`

**Current approach (broken):**
```rust
// Try to extract credentials from log
let credentials = extract_initial_admin_from_log(&log_path);
if let Some((email, password)) = credentials {
    // Use credentials
}
```

**New approach:**
```rust
// Check if config exists
let config_path = PathBuf::from("botserver-stack/conf/system/directory_config.json");
if config_path.exists() {
    // Load existing config
    return load_config(&config_path);
}

// Generate new credentials
let username = "admin";
let email = "admin@localhost";
let password = generate_secure_password();

// Create admin user in Zitadel
let setup = DirectorySetup::new_with_credentials(
    base_url,
    Some((email.clone(), password.clone()))
);

let admin_user = setup.create_admin_user(username, email, &password).await?;

// Create OAuth client
let oauth_client = setup.create_oauth_application().await?;

// Save config
let config = DirectoryConfig {
    base_url,
    admin_token: admin_user.pat_token,
    client_id: oauth_client.client_id,
    client_secret: oauth_client.client_secret,
    // ... other fields
};

save_config(&config_path, &config)?;

// Display credentials to user
print_bootstrap_credentials(&config, &password);

Ok(config)
```

#### 2. Add `create_admin_user()` to `DirectorySetup`

```rust
impl DirectorySetup {
    pub async fn create_admin_user(
        &self,
        username: &str,
        email: &str,
        password: &str,
    ) -> Result<AdminUser> {
        // Use Zitadel Management API to create user
        // Endpoint: POST /management/v1/users/human
        
        let user_payload = json!({
            "userName": username,
            "profile": {
                "firstName": "Admin",
                "lastName": "User"
            },
            "email": {
                "email": email,
                "isEmailVerified": true
            },
            "password": password,
            "passwordChangeRequired": false
        });
        
        let response = self.client
            .post(format!("{}/management/v1/users/human", self.base_url))
            .json(&user_payload)
            .send()
            .await?;
        
        // Extract user ID and create PAT token
        // ...
    }
}
```

#### 3. Ensure Directory Creation in `save_config()`

```rust
fn save_config(path: &Path, config: &DirectoryConfig) -> Result<()> {
    // Create parent directory if it doesn't exist
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)
            .map_err(|e| anyhow!("Failed to create config directory: {}", e))?;
    }
    
    // Write config
    let json = serde_json::to_string_pretty(config)?;
    fs::write(path, json)
        .map_err(|e| anyhow!("Failed to write config file: {}", e))?;
    
    info!("Saved Directory configuration to {}", path.display());
    Ok(())
}
```

#### 4. Update Config File Path

**Old path:** `config/directory_config.json`
**New path:** `botserver-stack/conf/system/directory_config.json`

Update all references in:
- `botserver/src/core/package_manager/mod.rs`
- `botserver/src/core/bootstrap/bootstrap_manager.rs`
- `botserver/src/main_module/bootstrap.rs`

## Implementation Steps

### Step 1: Create Admin User via API

**File:** `botserver/src/core/package_manager/setup/directory_setup.rs`

Add method to create admin user:
```rust
pub async fn create_admin_user(
    &self,
    username: &str,
    email: &str,
    password: &str,
) -> Result<AdminUser> {
    // Implementation using Zitadel Management API
}
```

### Step 2: Update setup_directory()

**File:** `botserver/src/core/package_manager/mod.rs`

Replace log parsing with direct user creation:
```rust
pub async fn setup_directory() -> Result<DirectoryConfig> {
    let config_path = PathBuf::from("botserver-stack/conf/system/directory_config.json");
    
    // Check existing config
    if config_path.exists() {
        return load_config(&config_path);
    }
    
    // Generate credentials
    let password = generate_secure_password();
    let email = "admin@localhost";
    let username = "admin";
    
    // Create admin and OAuth client
    let setup = DirectorySetup::new(base_url);
    let admin = setup.create_admin_user(username, email, &password).await?;
    let oauth = setup.create_oauth_application(&admin.token).await?;
    
    // Save config
    let config = DirectoryConfig { /* ... */ };
    save_config(&config_path, &config)?;
    
    // Display credentials
    print_credentials(username, email, &password);
    
    Ok(config)
}
```

### Step 3: Fix save_config()

**File:** `botserver/src/core/package_manager/setup/directory_setup.rs`

Ensure parent directory exists:
```rust
async fn save_config_internal(&self, config: &DirectoryConfig) -> Result<()> {
    let path = PathBuf::from("botserver-stack/conf/system/directory_config.json");
    
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    
    let json = serde_json::to_string_pretty(config)?;
    fs::write(&path, json)?;
    
    Ok(())
}
```

### Step 4: Remove Log Parsing

**File:** `botserver/src/core/package_manager/mod.rs`

Delete or deprecate `extract_initial_admin_from_log()` function - it's not reliable.

## Config File Structure

**Location:** `botserver-stack/conf/system/directory_config.json`

```json
{
  "base_url": "http://localhost:8300",
  "default_org": {
    "id": "<organization_id>",
    "name": "General Bots",
    "domain": "localhost"
  },
  "default_user": {
    "id": "<user_id>",
    "username": "admin",
    "email": "admin@localhost",
    "password": "",
    "first_name": "Admin",
    "last_name": "User"
  },
  "admin_token": "<personal_access_token>",
  "project_id": "<project_id>",
  "client_id": "<oauth_client_id>",
  "client_secret": "<oauth_client_secret>"
}
```

## Expected Bootstrap Flow

### First Run (No Config)

```
[Bootstrap] Starting Zitadel/Directory service...
[Bootstrap] Directory service started, waiting for readiness...
[Bootstrap] Zitadel/Directory service is responding
[Bootstrap] No directory_config.json found, initializing new setup
[Bootstrap] Generated admin password: Xk9#mP2$vL5@nQ8&
[Bootstrap] Creating admin user in Zitadel...
[Bootstrap] Admin user created: admin@localhost
[Bootstrap] Creating OAuth application...
[Bootstrap] OAuth client created: client_id=123456789
[Bootstrap] Saved Directory configuration to botserver-stack/conf/system/directory_config.json

╔════════════════════════════════════════════════════════════╗
║           🔐 ADMIN LOGIN - READY TO USE                    ║
╠════════════════════════════════════════════════════════════╣
║                                                            ║
║  Username: admin                                         ║
║  Password: Xk9#mP2$vL5@nQ8&                              ║
║  Email:    admin@localhost                               ║
║                                                            ║
║  🌐 LOGIN NOW: http://localhost:3000/suite/login           ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝

[Bootstrap] OAuth client created successfully
[Bootstrap] Bootstrap process completed!
```

### Subsequent Runs (Config Exists)

```
[Bootstrap] Starting Zitadel/Directory service...
[Bootstrap] Directory service started, waiting for readiness...
[Bootstrap] Zitadel/Directory service is responding
[Bootstrap] Loading existing Directory configuration
[Bootstrap] OAuth client verified: client_id=123456789
[Bootstrap] Bootstrap process completed!
```

## Testing Checklist

- [ ] Delete existing `botserver-stack/conf/system/directory_config.json`
- [ ] Run `./reset.sh` or restart botserver
- [ ] Verify admin user created in Zitadel
- [ ] Verify OAuth application created in Zitadel
- [ ] Verify `directory_config.json` exists with valid credentials
- [ ] Verify credentials displayed in console
- [ ] Verify `~/.gb-setup-credentials` file created
- [ ] Test login with displayed credentials
- [ ] Verify login returns valid token
- [ ] Restart botserver again
- [ ] Verify config is loaded (not recreated)
- [ ] Verify login still works

## Files to Modify

1. **`botserver/src/core/package_manager/mod.rs`**
   - Update `setup_directory()` to generate credentials
   - Remove `extract_initial_admin_from_log()` or mark deprecated
   - Update config path to `botserver-stack/conf/system/directory_config.json`

2. **`botserver/src/core/package_manager/setup/directory_setup.rs`**
   - Add `create_admin_user()` method
   - Update `save_config_internal()` to create parent directories
   - Update config path

3. **`botserver/src/core/bootstrap/bootstrap_manager.rs`**
   - Update config path reference
   - Ensure proper error handling

4. **`botserver/src/main_module/bootstrap.rs`**
   - Update `init_directory_service()` to use new path

## Benefits of This Approach

1. **Fully Automatic** - No manual steps required
2. **Reliable** - Doesn't depend on log parsing
3. **Secure** - Generates strong passwords
4. **Repeatable** - Works on every fresh install
5. **User-Friendly** - Displays credentials clearly
6. **Persistent** - Config saved in version-controlled location
7. **Fast** - No waiting for log file parsing

## Migration from Old Setup

If `~/.gb-setup-credentials` exists but `directory_config.json` doesn't:

1. **Option A:** Use existing credentials
   - Read credentials from `~/.gb-setup-credentials`
   - Create OAuth client with those credentials
   - Save to `directory_config.json`

2. **Option B:** Create new setup
   - Ignore old credentials
   - Generate new admin password
   - Update or replace old credentials file
   - Save to `directory_config.json`

**Recommendation:** Option A (use existing credentials if available)

## Summary

**Problem:** OAuth client not created because bootstrap can't extract Zitadel credentials from logs.

**Solution:** Generate credentials programmatically, create admin user via API, create OAuth client, save config automatically.

**Result:** Fully automatic, reliable bootstrap that creates all necessary credentials and configuration without manual intervention.

**Timeline:**
- Implementation: 2-4 hours
- Testing: 1 hour
- Total: 3-5 hours

**Priority:** HIGH - Blocking login functionality
# General Bots AI Agent Guidelines
- stop saving .png on root! Use /tmp. never allow new files on root.
- never push to alm without asking first - pbecause it is production!
8080 is server 3000 is client ui 
if you are in trouble with some tool, please go to the ofiical website to get proper install or instructions
To test web is http://localhost:3000 (botui!)
Use apenas a lingua culta ao falar .
test login here http://localhost:3000/suite/auth/login.html
> **⚠️ CRITICAL SECURITY WARNING**
I AM IN DEV ENV, but sometimes, pasting from PROD, do not treat my env as prod! Just fix, to me and push to CI. So I can test in PROD, for a while.
>Use Playwrigth MCP to start localhost:3000/<bot> now.
> **NEVER CREATE FILES WITH SECRETS IN THE REPOSITORY ROOT**
See botserver/src/drive/local_file_monitor.rs to see how to load from /opt/gbo/data the list of development bots.
- ❌ **NEVER** use `cargo clean` - causes 30min rebuilds, use `./reset.sh` for database issues

>
> Secret files MUST be placed in `/tmp/` only:
> - ✅ `/tmp/vault-token-gb` - Vault root token
> - ✅ `/tmp/vault-unseal-key-gb` - Vault unseal key
> - ❌ `vault-unseal-keys` - FORBIDDEN (tracked by git)
> - ❌ `start-and-unseal.sh` - FORBIDDEN (contains secrets)
>
> **Why `/tmp/`?**
> - Cleared on reboot (ephemeral)
> - Not tracked by git
> - Standard Unix security practice
> - Prevents accidental commits

---

## 📁 WORKSPACE STRUCTURE

| Crate | Purpose | Port | Tech Stack |
|-------|---------|------|------------|
| **botserver** | Main API server, business logic | 8080 | Axum, Diesel, Rhai BASIC |
| **botui** | Web UI server (dev) + proxy | 3000 | Axum, HTML/HTMX/CSS |
| **botapp** | Desktop app wrapper | - | Tauri 2 |
| **botlib** | Shared library | - | Core types, errors |
| **botbook** | Documentation | - | mdBook |
| **bottest** | Integration tests | - | tokio-test |
| **botdevice** | IoT/Device support | - | Rust |
| **botplugin** | Browser extension | - | JS |

### Key Paths
- **Binary:** `target/debug/botserver`
- **Run from:** `botserver/` directory
- **Env file:** `botserver/.env`
- **UI Files:** `botui/ui/suite/`

---

## 🧭 LLM Navigation Guide

### Reading This Workspace
/opt/gbo/data is a place also for bots.
**For LLMs analyzing this codebase:**
0. Bots are in /opt/gbo/data primary
1. Start with **[Component Dependency Graph](../README.md#-component-dependency-graph)** in README to understand relationships
2. Review **[Module Responsibility Matrix](../README.md#-module-responsibility-matrix)** for what each module does
3. Study **[Data Flow Patterns](../README.md#-data-flow-patterns)** to understand execution flow
4. Reference **[Common Architectural Patterns](../README.md#-common-architectural-patterns)** before making changes
5. Check **[Security Rules](#-security-directives---mandatory)** below - violations are blocking issues
6. Follow **[Code Patterns](#-mandatory-code-patterns)** below - consistency is mandatory

---

## 🔄 Reset Process Notes

### reset.sh Behavior
- **Purpose**: Cleans and restarts the development environment
- **Timeouts**: The script can timeout during "Step 3/4: Waiting for BotServer to bootstrap"
- **Bootstrap Process**: Takes 3-5 minutes to install all components (Vault, PostgreSQL, Valkey, MinIO, Zitadel, LLM)

### Common Issues
1. **Script Timeout**: reset.sh waits for "Bootstrap complete: admin user" message
   - If Zitadel isn't ready within 60s, admin user creation fails
   - Script continues waiting indefinitely
   - **Solution**: Check botserver.log for "Bootstrap process completed!" message

2. **Zitadel Not Ready**: "Bootstrap check failed (Zitadel may not be ready)"
   - Directory service may need more than 60 seconds to start
   - Admin user creation deferred
   - Services still start successfully

3. **Services Exit After Start**: 
   - botserver/botui may exit after initial startup
   - Check logs for "dispatch failure" errors
   - Check Vault certificate errors: "tls: failed to verify certificate: x509"

### Manual Service Management
```bash
# If reset.sh times out, manually verify services:
ps aux | grep -E "(botserver|botui)" | grep -v grep
curl http://localhost:8080/health
tail -f botserver.log botui.log

# Restart services manually:
./restart.sh
```

### Reset Verification
After reset completes, verify:
- ✅ PostgreSQL running (port 5432)
- ✅ Valkey cache running (port 6379)
- ✅ BotServer listening on port 8080
- ✅ BotUI listening on port 3000
- ✅ No errors in botserver.log

---

## 🔐 Security Directives - MANDATORY

### 1. Error Handling - NO PANICS IN PRODUCTION

```rust
// ❌ FORBIDDEN
value.unwrap()
value.expect("message")
panic!("error")
todo!()
unimplemented!()

// ✅ REQUIRED
value?
value.ok_or_else(|| Error::NotFound)?
value.unwrap_or_default()
value.unwrap_or_else(|e| { log::error!("{}", e); default })
if let Some(v) = value { ... }
match value { Ok(v) => v, Err(e) => return Err(e.into()) }
```

### 2. Command Execution - USE SafeCommand

```rust
// ❌ FORBIDDEN
Command::new("some_command").arg(user_input).output()

// ✅ REQUIRED
use crate::security::command_guard::SafeCommand;
SafeCommand::new("allowed_command")?
    .arg("safe_arg")?
    .execute()
```

### 3. Error Responses - USE ErrorSanitizer

```rust
// ❌ FORBIDDEN
Json(json!({ "error": e.to_string() }))
format!("Database error: {}", e)

// ✅ REQUIRED
use crate::security::error_sanitizer::log_and_sanitize;
let sanitized = log_and_sanitize(&e, "context", None);
(StatusCode::INTERNAL_SERVER_ERROR, sanitized)
```

### 4. SQL - USE sql_guard

```rust
// ❌ FORBIDDEN
format!("SELECT * FROM {}", user_table)

// ✅ REQUIRED
use crate::security::sql_guard::{sanitize_identifier, validate_table_name};
let safe_table = sanitize_identifier(&user_table);
validate_table_name(&safe_table)?;
```

### 5. Rate Limiting Strategy (IMP-07)

- **Default Limits:**
  - General: 100 req/s (global)
  - Auth: 10 req/s (login endpoints)
  - API: 50 req/s (per token)
- **Implementation:**
  - MUST use `governor` crate
  - MUST implement per-IP and per-User tracking
  - WebSocket connections MUST have message rate limits (e.g., 10 msgs/s)

### 6. CSRF Protection (IMP-08)

- **Requirement:** ALL state-changing endpoints (POST, PUT, DELETE, PATCH) MUST require a CSRF token.
- **Implementation:**
  - Use `tower_csrf` or similar middleware
  - Token MUST be bound to user session
  - Double-Submit Cookie pattern or Header-based token verification
  - **Exemptions:** API endpoints using Bearer Token authentication (stateless)

### 7. Security Headers (IMP-09)

- **Mandatory Headers on ALL Responses:**
  - `Content-Security-Policy`: "default-src 'self'; script-src 'self'; object-src 'none';"
  - `Strict-Transport-Security`: "max-age=63072000; includeSubDomains; preload"
  - `X-Frame-Options`: "DENY" or "SAMEORIGIN"
  - `X-Content-Type-Options`: "nosniff"
  - `Referrer-Policy`: "strict-origin-when-cross-origin"
  - `Permissions-Policy`: "geolocation=(), microphone=(), camera=()"

### 8. Dependency Management (IMP-10)

- **Pinning:**
  - Application crates (`botserver`, `botui`) MUST track `Cargo.lock`
  - Library crates (`botlib`) MUST NOT track `Cargo.lock`
- **Versions:**
  - Critical dependencies (crypto, security) MUST use exact versions (e.g., `=1.0.1`)
  - Regular dependencies MAY use caret (e.g., `1.0`)
- **Auditing:**
  - Run `cargo audit` weekly
  - Update dependencies only via PR with testing

---

## ✅ Mandatory Code Patterns

### Use Self in Impl Blocks
```rust
impl MyStruct {
    fn new() -> Self { Self { } }  // ✅ Not MyStruct
}
```

### Derive Eq with PartialEq
```rust
#[derive(PartialEq, Eq)]  // ✅ Always both
struct MyStruct { }
```

### Inline Format Args
```rust
format!("Hello {name}")  // ✅ Not format!("{}", name)
```

### Combine Match Arms
```rust
match x {
    A | B => do_thing(),  // ✅ Combine identical arms
    C => other(),
}
```

---

## ❌ Absolute Prohibitions
- NEVER search /target folder! It is binary compiled.
- ❌ **NEVER** build in release mode - ONLY debug builds allowed
- ❌ **NEVER** use `--release` flag on ANY cargo command
- ❌ **NEVER** run `cargo build` - use `cargo check` for syntax verification
- ❌ **NEVER** compile directly for production - ALWAYS use push + CI/CD pipeline
- ❌ **NEVER** use `scp` or manual transfer to deploy - ONLY CI/CD ensures correct deployment

**Current Status:** ✅ **0 clippy warnings** (down from 61 - PERFECT SCORE in YOLO mode)
- ❌ **NEVER** use `panic!()`, `todo!()`, `unimplemented!()`
- ❌ **NEVER** use `Command::new()` directly - use `SafeCommand`
- ❌ **NEVER** return raw error strings to HTTP clients
- ❌ **NEVER** use `#[allow()]` in source code - FIX the code instead
- ❌ **NEVER** add lint exceptions to `Cargo.toml` - FIX the code instead
- ❌ **NEVER** use `_` prefix for unused variables - DELETE or USE them
- ❌ **NEVER** leave unused imports or dead code
- ❌ **NEVER** use CDN links - all assets must be local
- ❌ **NEVER** create `.md` documentation files without checking `botbook/` first
- ❌ **NEVER** comment out code - FIX it or DELETE it entirely

---

## 📏 File Size Limits - MANDATORY

### Maximum 450 Lines Per File

When a file grows beyond this limit:

1. **Identify logical groups** - Find related functions
2. **Create subdirectory module** - e.g., `handlers/`
3. **Split by responsibility:**
   - `types.rs` - Structs, enums, type definitions
   - `handlers.rs` - HTTP handlers and routes
   - `operations.rs` - Core business logic
   - `utils.rs` - Helper functions
   - `mod.rs` - Re-exports and configuration
4. **Keep files focused** - Single responsibility
5. **Update mod.rs** - Re-export all public items

**NEVER let a single file exceed 450 lines - split proactively at 350 lines**

---

## 🔥 Error Fixing Workflow

### Mode 1: OFFLINE Batch Fix (PREFERRED)

When given error output:

1. **Read ENTIRE error list first**
2. **Group errors by file**
3. **For EACH file with errors:**
   a. View file → understand context
   b. Fix ALL errors in that file
   c. Write once with all fixes
4. **Move to next file**
5. **REPEAT until ALL errors addressed**
6. **ONLY THEN → verify with build/diagnostics**

**NEVER run cargo build/check/clippy DURING fixing**
**Fix ALL errors OFFLINE first, verify ONCE at the end**

### Mode 2: Interactive Loop

```
LOOP UNTIL (0 warnings AND 0 errors):
  1. Run diagnostics → pick file with issues
  2. Read entire file
  3. Fix ALL issues in that file
  4. Write file once with all fixes
  5. Verify with diagnostics
  6. CONTINUE LOOP
END LOOP
```

### ⚡ Streaming Build Rule

**Do NOT wait for `cargo` to finish.** As soon as the first errors appear in output, cancel/interrupt the build, fix those errors immediately, then re-run. This avoids wasting time on a full compile when errors are already visible.

---

## 🧠 Memory Management

When compilation fails due to memory issues (process "Killed"):

```bash
pkill -9 cargo; pkill -9 rustc; pkill -9 botserver
CARGO_BUILD_JOBS=1 cargo check -p botserver 2>&1 | tail -200
```

---

## 🎭 Playwright Browser Testing - YOLO Mode

**When user requests to start YOLO mode with Playwright:**

1. **Start the browser** - Use `mcp__playwright__browser_navigate` to open http://localhost:3000/{botname}
2. **Take snapshot** - Use `mcp__playwright__browser_snapshot` to see current page state
3. **Test user flows** - Use click, type, fill_form, etc.
4. **Verify results** - Check for expected content, errors in console, network requests
5. **Validate backend** - Check database and services to confirm process completion
6. **Report findings** - Always include screenshot evidence with `browser_take_screenshot`

**⚠️ IMPORTANT - Desktop UI Navigation:**
- The desktop may have a maximized chat window covering other apps
- To access CRM/sidebar icons, click the **middle button** (restore/down arrow) in the chat window header to minimize it
- Or navigate directly via URL: http://localhost:3000/suite/crm (after login)

**Bot-Specific Testing URL Pattern:**
`http://localhost:3000/<botname>`

**Backend Validation Checks:**
After UI interactions, validate backend state via `psql` or `tail` logs.

---

## ➕ Adding New Features Workflow

### Step 1: Plan the Feature

**Understand requirements:**
1. What problem does this solve?
2. Which module owns this functionality? (Check [Module Responsibility Matrix](../README.md#-module-responsibility-matrix))
3. What data structures are needed?
4. What are the security implications?

**Design checklist:**
- [ ] Does it fit existing architecture patterns?
- [ ] Will it require database migrations?
- [ ] Does it need new API endpoints?
- [ ] Will it affect existing features?
- [ ] What are the error cases?

### Step 2: Implement the Feature

**Follow the pattern:**
```rust
// 1. Add types to botlib if shared across crates
// botlib/src/models.rs
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NewFeature {
    pub id: Uuid,
    pub name: String,
}

// 2. Add database schema if needed
// botserver/migrations/YYYY-MM-DD-HHMMSS_feature_name/up.sql
CREATE TABLE new_features (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

// 3. Add Diesel model
// botserver/src/core/shared/models/core.rs
#[derive(Queryable, Insertable)]
#[diesel(table_name = new_features)]
pub struct NewFeatureDb {
    pub id: Uuid,
    pub name: String,
    pub created_at: DateTime<Utc>,
}

// 4. Add business logic
// botserver/src/features/new_feature.rs
pub async fn create_feature(
    state: &AppState,
    name: String,
) -> Result<NewFeature, Error> {
    // Implementation
}

// 5. Add API endpoint
// botserver/src/api/routes.rs
async fn create_feature_handler(
    Extension(state): Extension<Arc<AppState>>,
    Json(payload): Json<CreateFeatureRequest>,
) -> Result<Json<NewFeature>, (StatusCode, String)> {
    // Handler implementation
}
```

**Security checklist:**
- [ ] Input validation (use `sanitize_identifier` for SQL)
- [ ] Authentication required?
- [ ] Authorization checks?
- [ ] Rate limiting needed?
- [ ] Error messages sanitized? (use `log_and_sanitize`)
- [ ] No `unwrap()` or `expect()` in production code

### Step 3: Add BASIC Keywords (if applicable)

**For features accessible from .bas scripts:**
```rust
// botserver/src/basic/keywords/new_feature.rs
pub fn new_feature_keyword(
    state: Arc<AppState>,
    user_session: UserSession,
    engine: &mut Engine,
) {
    let state_clone = state.clone();
    let session_clone = user_session.clone();

    engine
        .register_custom_syntax(
            ["NEW_FEATURE", "$expr$"],
            true,
            move |context, inputs| {
                let param = context.eval_expression_tree(&inputs[0])?.to_string();
                
                // Call async function from sync context
                let result = tokio::task::block_in_place(|| {
                    tokio::runtime::Handle::current().block_on(async {
                        create_feature(&state_clone, param).await
                    })
                });
                
                match result {
                    Ok(feature) => Ok(Dynamic::from(feature.name)),
                    Err(e) => Err(format!("Failed: {}", e).into()),
                }
            },
        )
        .expect("valid syntax registration");
}

// Register in botserver/src/basic/keywords/mod.rs
pub mod new_feature;
pub use new_feature::new_feature_keyword;
```

### Step 4: Test the Feature

**Local testing:**
```bash
# 1. Run migrations
diesel migration run

# 2. Build and restart
./restart.sh

# 3. Test via API
curl -X POST http://localhost:9000/api/features \
  -H "Content-Type: application/json" \
  -d '{"name": "test"}'

# 4. Test via BASIC script
# Create test.bas in /opt/gbo/data/testbot.gbai/testbot.gbdialog/
# NEW_FEATURE "test"

# 5. Check logs
tail -f botserver.log | grep -i "new_feature"
```

**Integration test:**
```rust
// bottest/tests/new_feature_test.rs
#[tokio::test]
async fn test_create_feature() {
    let state = setup_test_state().await;
    let result = create_feature(&state, "test".to_string()).await;
    assert!(result.is_ok());
}
```

### Step 5: Document the Feature

**Update documentation:**
- Add to `botbook/src/features/` if user-facing
- Add to module README.md if developer-facing
- Add inline code comments for complex logic
- Update API documentation

**Example documentation:**
```markdown
## NEW_FEATURE Keyword

Creates a new feature with the given name.

**Syntax:**
```basic
NEW_FEATURE "feature_name"
```

**Example:**
```basic
NEW_FEATURE "My Feature"
TALK "Feature created!"
```

**Returns:** Feature name as string
```

### Step 6: Commit & Deploy

**Commit pattern:**
```bash
git add .
git commit -m "feat: Add NEW_FEATURE keyword

- Adds new_features table with migrations
- Implements create_feature business logic
- Adds NEW_FEATURE BASIC keyword
- Includes API endpoint at POST /api/features
- Tests: Unit tests for business logic, integration test for API"

git push alm main
git push origin main
```

---

## 🧪 Testing Strategy

### Unit Tests
- **Location**: Each crate has `tests/` directory or inline `#[cfg(test)]` modules
- **Naming**: Test functions use `test_` prefix or describe what they test
- **Running**: `cargo test -p <crate_name>` or `cargo test` for all

### Integration Tests
- **Location**: `bottest/` crate contains integration tests
- **Scope**: Tests full workflows across multiple crates
- **Running**: `cargo test -p bottest`

### Coverage Goals
- **Critical paths**: 80%+ coverage required
- **Error handling**: ALL error paths must have tests
- **Security**: All security guards must have tests

### WhatsApp Integration Testing

#### Prerequisites
1. **Enable WhatsApp Feature**: Build botserver with whatsapp feature enabled:
   ```bash
   cargo build -p botserver --bin botserver --features whatsapp
   ```
2. **Bot Configuration**: Ensure the bot has WhatsApp credentials configured in `config.csv`:
   - `whatsapp-api-key` - API key from Meta Business Suite
   - `whatsapp-verify-token` - Custom token for webhook verification
   - `whatsapp-phone-number-id` - Phone Number ID from Meta
   - `whatsapp-business-account-id` - Business Account ID from Meta

#### Using Localtunnel (lt) as Reverse Proxy

# Check database for message storage
psql -h localhost -U postgres -d botserver -c "SELECT * FROM messages WHERE bot_id = '<bot_id>' ORDER BY created_at DESC LIMIT 5;"
---

## 🐛 Debugging Rules

### 🚨 CRITICAL ERROR HANDLING RULE

**STOP EVERYTHING WHEN ERRORS APPEAR**

When ANY error appears in logs during startup or operation:
1. **IMMEDIATELY STOP** - Do not continue with other tasks
2. **IDENTIFY THE ERROR** - Read the full error message and context
3. **FIX THE ERROR** - Address the root cause, not symptoms
4. **VERIFY THE FIX** - Ensure error is completely resolved
5. **ONLY THEN CONTINUE** - Never ignore or work around errors

**NEVER restart servers to "fix" errors - FIX THE ACTUAL PROBLEM**

### Log Locations

| Component | Log File | What's Logged |
|-----------|----------|---------------|
| **botserver** | `botserver.log` | API requests, errors, script execution, **client navigation events** |
| **botui** | `botui.log` | UI rendering, WebSocket connections |
| **drive_monitor** | In botserver logs with `[drive_monitor]` prefix | File sync, compilation |
| **client errors** | In botserver logs with `CLIENT:` prefix | JavaScript errors, navigation events |

---

## 🔧 Bug Fixing Workflow

### Step 1: Reproduce & Diagnose

**Identify the symptom:**
```bash
# Check recent errors
grep -E " E | W " botserver.log | tail -20

# Check specific component
grep "component_name" botserver.log | tail -50

# Monitor live
tail -f botserver.log | grep -E "ERROR|WARN"
```

**Trace the data flow:**
1. Find where the bug manifests (UI, API, database, cache)
2. Work backwards through the call chain
3. Check logs at each layer

**Example: "Suggestions not showing"**
```bash
# 1. Check if frontend is requesting suggestions
grep "GET /api/suggestions" botserver.log | tail -5

# 2. Check if suggestions exist in cache
/opt/gbo/bin/botserver-stack/bin/cache/bin/valkey-cli --scan --pattern "suggestions:*"

# 3. Check if suggestions are being generated
grep "ADD_SUGGESTION" botserver.log | tail -10

# 4. Verify the Redis key format
grep "Adding suggestion to Redis key" botserver.log | tail -5
```

### Step 2: Find the Code

**Use code search tools:**
```bash
# Find function/keyword implementation
cd botserver/src && grep -r "ADD_SUGGESTION_TOOL" --include="*.rs"

# Find where Redis keys are constructed
grep -r "suggestions:" --include="*.rs" | grep format

# Find struct definition
grep -r "pub struct UserSession" --include="*.rs"
```

**Check module responsibility:**
- Refer to [Module Responsibility Matrix](../README.md#-module-responsibility-matrix)
- Check `mod.rs` files for module structure
- Look for related functions in same file

### Step 3: Fix the Bug

**Identify root cause:**
- Wrong variable used? (e.g., `user_id` instead of `bot_id`)
- Missing validation?
- Race condition?
- Configuration issue?

**Make minimal changes:**
```rust
// ❌ BAD: Rewrite entire function
fn add_suggestion(...) {
    // 100 lines of new code
}

// ✅ GOOD: Fix only the bug
fn add_suggestion(...) {
    // Change line 318:
    - let key = format!("suggestions:{}:{}", user_session.user_id, session_id);
    + let key = format!("suggestions:{}:{}", user_session.bot_id, session_id);
}
```

**Search for similar bugs:**
```bash
# If you fixed user_id -> bot_id in one place, check all occurrences
grep -n "user_session.user_id" botserver/src/basic/keywords/add_suggestion.rs
```

### Step 4: Test Locally

**Verify the fix:**
```bash
# 1. Build
cargo check -p botserver

# 2. Restart
./restart.sh

# 3. Test the specific feature
# - Open browser to http://localhost:3000/<botname>
# - Trigger the bug scenario
# - Verify it's fixed

# 4. Check logs for errors
tail -20 botserver.log | grep -E "ERROR|WARN"
```

### Step 5: Commit & Deploy

**Commit with clear message:**
```bash
cd botserver
git add src/path/to/file.rs
git commit -m "Fix: Use bot_id instead of user_id in suggestion keys

- Root cause: Wrong field used in Redis key format
- Impact: Suggestions stored under wrong key, frontend couldn't retrieve
- Files: src/basic/keywords/add_suggestion.rs (5 occurrences)
- Testing: Verified suggestions now appear in UI"
```

**Push to remotes:**
```bash
# Push submodule
git push alm main
git push origin main

# Update root repository
cd ..
git add botserver
git commit -m "Update botserver: Fix suggestion key bug"
git push alm main
git push origin main
```

**Production deployment:**
- ALM push triggers CI/CD pipeline
- Wait ~10 minutes for build + deploy
- Service auto-restarts on binary update
- Test in production after deployment

### Step 6: Document

**Add to AGENTS-PROD.md if production-relevant:**
- Common symptom
- Diagnosis commands
- Fix procedure
- Prevention tips

**Update code comments if needed:**
```rust
// Redis key format: suggestions:bot_id:session_id
// Note: Must use bot_id (not user_id) to match frontend queries
let key = format!("suggestions:{}:{}", user_session.bot_id, session_id);
```

---

## 🎨 Frontend Standards

### HTMX-First Approach
- Use HTMX to minimize JavaScript
- Server returns HTML fragments, not JSON
- Use `hx-get`, `hx-post`, `hx-target`, `hx-swap`
- WebSocket via htmx-ws extension

### Local Assets Only - NO CDN
```html
<!-- ✅ CORRECT -->
<script src="js/vendor/htmx.min.js"></script>

<!-- ❌ WRONG -->
<script src="https://unpkg.com/htmx.org@1.9.10"></script>
```

---

## 🚀 Performance & Size Standards

### Binary Size Optimization
- **Release Profile**: Always maintain `opt-level = "z"`, `lto = true`, `codegen-units = 1`, `strip = true`, `panic = "abort"`.
- **Dependencies**: 
  - Run `cargo tree --duplicates` weekly
  - Run `cargo machete` to remove unused dependencies
  - Use `default-features = false` and explicitly opt-in to needed features

### Linting & Code Quality
- **Clippy**: Code MUST pass `cargo clippy --workspace` with **0 warnings**.
- **No Allow**: NEVER use `#[allow(clippy::...)]` in source code - FIX the code instead.

---

## 🔧 Technical Debt

### Critical Issues to Address
- Error handling debt: instances of `unwrap()`/`expect()` in production code
- Performance debt: excessive `clone()`/`to_string()` calls
- File size debt: files exceeding 450 lines

### Weekly Maintenance Tasks
```bash
cargo tree --duplicates   # Find duplicate dependencies
cargo machete            # Remove unused dependencies
cargo build --release && ls -lh target/release/botserver  # Check binary size
cargo audit              # Security audit
```

---

## 📋 Continuation Prompt

When starting a new session or continuing work:

```
Continue on gb/ workspace. Follow AGENTS.md strictly:

1. Check current state with build/diagnostics
2. Fix ALL warnings and errors - NO #[allow()] attributes
3. Delete unused code, don't suppress warnings
4. Remove unused parameters, don't prefix with _
5. Replace ALL unwrap()/expect() with proper error handling
6. Verify after each fix batch
7. Loop until 0 warnings, 0 errors
8. Refactor files >450 lines
```

---

## 🔑 Memory & Main Directives

**LOOP AND COMPACT UNTIL 0 WARNINGS - MAXIMUM PRECISION**

- 0 warnings
- 0 errors
- Trust project diagnostics
- Respect all rules
- No `#[allow()]` in source code
- Real code fixes only

**Remember:**
- **OFFLINE FIRST** - Fix all errors from list before compiling
- **BATCH BY FILE** - Fix ALL errors in a file at once
- **WRITE ONCE** - Single edit per file with all fixes
- **VERIFY LAST** - Only compile/diagnostics after ALL fixes
- **DELETE DEAD CODE** - Don't keep unused code around
- **GIT WORKFLOW** - ALWAYS push to ALL repositories (github, pragmatismo)

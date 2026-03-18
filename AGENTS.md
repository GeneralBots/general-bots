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
- ❌ **NEVER** use `--all-targets` with clippy - too slow (1m 44s without vs 10min+ with)
- ❌ **NEVER** use `--all-features` unless testing specific feature gates
- ❌ **ALWAYS** use: `cargo clippy --workspace` (DEBUG mode, lib + bin only)
- ❌ **NEVER** run `cargo build` - use `cargo check` for syntax verification

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

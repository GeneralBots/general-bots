# VibeCode Platform - Complete Implementation Roadmap

## Executive Summary

**Current Status:** BotUI's backend is **80% complete** with powerful LLM-driven code generation. The platform needs professional frontend tools AND must support **two deployment models**:

1. **Internal GB Apps** - Apps served from GB platform using shared APIs
2. **External Forgejo ALM Projects** - Apps deployed to Forgejo repositories with CI/CD

**What Works (Backend):**
- ✅ LLM-powered app generation (AppGenerator: 3400+ lines)
- ✅ Multi-agent pipeline (Orchestrator: Plan → Build → Review → Deploy → Monitor)
- ✅ Real-time WebSocket progress
- ✅ Database schema generation
- ✅ File generation (HTML, CSS, JS, BAS)
- ✅ Designer AI (runtime modifications with undo/redo)
- ✅ chromiumoxide dependency for browser automation
- ✅ **Forgejo ALM integration** (mTLS, runners, port 3000)
- ✅ **MCP servers integration** (`botserver/src/sources/`)
- ✅ **App deployment** (`/apps/{name}` routes, Drive storage)

**What's Missing (Critical Gaps):**
- ❌ **Security fixes** - Unsafe unwraps, dependency vulnerabilities
- ❌ **Deployment routing** - Logic to choose internal vs external
- ❌ **Forgejo git push** - Repository initialization & CI/CD generation
- ❌ **MCP UI panel** - Integration into Vibe sidebar
- ❌ **Monaco editor** - Currently just textarea
- ❌ **Database UI** - No schema visualizer
- ❌ **Git operations UI** - No version control interface
- ❌ **Browser automation UI** - Engine exists, no frontend
- ❌ **Multi-file workspace** - Single file editing only
- ❌ **Enhanced terminal** - Basic implementation only

---

## Table of Contents

1. [Part I: Security & Stability (IMMEDIATE)](#part-i-security--stability)
2. [Part II: Dual Deployment Infrastructure](#part-ii-dual-deployment-infrastructure)
3. [Part III: MCP Integration](#part-iii-mcp-integration)
4. [Part IV: Professional Development Tools](#part-iv-professional-development-tools)
5. [Part V: Architecture Diagrams](#part-v-architecture-diagrams)
6. [Part VI: Implementation Phases](#part-vi-implementation-phases)
7. [Part VII: File Organization](#part-vii-file-organization)
8. [Part VIII: Testing Strategy](#part-viii-testing-strategy)
9. [Part IX: Rollout Plan](#part-ix-rollout-plan)
10. [Part X: Success Metrics](#part-x-success-metrics)

---

## Part I: Security & Stability

**Priority:** ⚠️ **CRITICAL** - Must complete before any feature work

### 1. Unsafe Unwraps in Production

**Issue:** Codebase uses `.unwrap()`, `.expect()`, `panic!()` in production, violating AGENTS.md rules.

**Vulnerable Locations:**
```
botserver/src/drive/drive_handlers.rs:269      - Response::builder() unwrap
botserver/src/basic/compiler/mod.rs            - Multiple unwrap() calls
botserver/src/llm/llm_models/deepseek_r3.rs   - unwrap() outside tests
botserver/src/botmodels/opencv.rs             - Test scope unwrap() leaks
```

**Action Items:**
- [ ] Replace ALL `.unwrap()` with safe alternatives:
  - Use `?` operator with proper error propagation
  - Use `unwrap_or_default()` for defaults
  - Use pattern matching with early returns
  - Apply `ErrorSanitizer` to avoid panics
- [ ] Run `cargo clippy -- -W clippy::unwrap_used -W clippy::expect_used`
- [ ] Add unit tests verifying error paths work correctly

**Estimated Effort:** 4-6 hours

---

### 2. Dependency Vulnerabilities

**Vulnerable Component:**
- **Crate:** `glib 0.18.5`
- **Advisory:** `RUSTSEC-2024-0429`
- **Issue:** Unsoundness in `Iterator` and `DoubleEndedIterator` impls
- **Context:** Pulled through `botdevice`/`botapp` via Tauri/GTK

**Action Items:**
- [ ] Review exact usage of glib in codebase
- [ ] Check if patches are available in newer versions
- [ ] Evaluate risk given desktop GUI context
- [ ] If critical: upgrade GTK/Glib dependencies
- [ ] If acceptable: document risk assessment

**Estimated Effort:** 2-4 hours

---

### 3. General Security Posture

**CSRF Protection:**
- ✅ Custom CSRF store exists: `redis_csrf_store.rs`
- ⚠️ **Verify:** ALL state-changing endpoints use it (standard `tower-csrf` is absent)

**Security Headers:**
- ✅ `headers.rs` provides CSP, HSTS, X-Frame-Options
- ⚠️ **Verify:** Headers are attached UNIVERSALLY, not selectively omitted

**Action Items:**
- [ ] Audit all POST/PUT/DELETE endpoints for CSRF validation
- [ ] Create middleware test to ensure security headers on all responses
- [ ] Document security checklist for new endpoints

**Estimated Effort:** 3-4 hours

---

## Part II: Dual Deployment Infrastructure

**Priority:** 🔴 **CRITICAL** - Core feature missing

### Current State

**Existing Infrastructure:**
```rust
// Forgejo ALM already configured:
botserver/src/security/mutual_tls.rs:150
  - configure_forgejo_mtls() - mTLS for Forgejo

botserver/src/core/package_manager/installer.rs
  - forgejo binary installer
  - forgejo-runner integration
  - ALM_URL environment variable
  - Port 3000 for Forgejo web UI

botserver/src/basic/keywords/create_site.rs
  - CREATE SITE keyword
  - Stores to Drive: apps/{alias}
  - Serves from: /apps/{alias}
```

### Architecture: Dual Deployment Model

```
┌──────────────────────────────────────────────────────────────────┐
│                     USER REQUEST                                 │
│              "I want a full CRM system"                          │
└────────────────────────────┬─────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│              VIBE BUILDER UI                                     │
│  ┌──────────────────┐  ┌──────────────────┐                    │
│  │ Agent Sidebar    │  │ Canvas Area      │                    │
│  │ (Mantis #1-4)    │  │ - Task Nodes     │                    │
│  │ - Status cards   │  │ - Preview        │                    │
│  │ - Workspaces     │  │ - Chat Overlay   │                    │
│  └──────────────────┘  └──────────────────┘                    │
│                                                              │
│  ⚠️ DEPLOYMENT CHOICE:                                       │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ 📱 Deploy to GB Platform     🌐 Deploy to Forgejo   │    │
│  │    - Serve from /apps/           - Push to repo     │    │
│  │    - Use GB API                  - CI/CD pipeline   │    │
│  │    - Fast iteration              - Custom domain    │    │
│  │    - Shared resources            - Independent     │    │
│  └─────────────────────────────────────────────────────┘    │
└────────────────────────────┬─────────────────────────────────────┘
                             │
                ┌────────────┴────────────┐
                │                         │
                ▼                         ▼
┌───────────────────────┐  ┌──────────────────────────────────┐
│  INTERNAL GB APPS     │  │   EXTERNAL FORGEJO PROJECTS       │
│                       │  │                                  │
│ Deployment Flow:      │  │ Deployment Flow:                 │
│ 1. Generate files     │  │ 1. Generate files                │
│ 2. Store in Drive     │  │ 2. Init git repo                 │
│ 3. Serve from /apps/  │  │ 3. Push to Forgejo               │
│ 4. Use GB APIs        │  │ 4. Create CI/CD (.forgejo/*)    │
│ 5. Shared DB          │  │ 5. Runner builds & deploys       │
│ 6. Shared auth        │  │ 6. Independent deployment       │
│                       │  │ 7. Custom domain                 │
│ ┌─────────────────┐   │  │                                  │
│ │ App Router      │   │  │ ┌──────────────────────────────┐ │
│ │ /apps/{name}    │   │  │ │ Forgejo ALM (port 3000)      │ │
│ │ - HTMX routes   │   │  │ │ - Git server                 │ │
│ │ - API proxy     │   │  │ │ - CI/CD (.forgejo/workflows) │ │
│ │ - Auth wrapper  │   │  │ │ - Packages (npm, cargo)      │ │
│ └─────────────────┘   │  │ │ - Actions runner             │ │
│                       │  │ └──────────────────────────────┘ │
└───────────────────────┘  └──────────────────────────────────┘
```

### Phase 0.1: Deployment Router

**File:** `botserver/src/deployment/mod.rs`

```rust
use serde::{Deserialize, Serialize};
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DeploymentTarget {
    /// Serve from GB platform (/apps/{name})
    Internal {
        route: String,
        shared_resources: bool,
    },
    /// Deploy to external Forgejo repository
    External {
        repo_url: String,
        custom_domain: Option<String>,
        ci_cd_enabled: bool,
    },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeploymentConfig {
    pub app_name: String,
    pub target: DeploymentTarget,
    pub environment: DeploymentEnvironment,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DeploymentEnvironment {
    Development,
    Staging,
    Production,
}

pub struct DeploymentRouter {
    forgejo_url: String,
    forgejo_token: Option<String>,
    internal_base_path: PathBuf,
}

impl DeploymentRouter {
    pub async fn deploy(
        &self,
        config: DeploymentConfig,
        generated_app: GeneratedApp,
    ) -> Result<DeploymentResult, DeploymentError> {
        match config.target {
            DeploymentTarget::Internal { route, .. } => {
                self.deploy_internal(route, generated_app).await
            }
            DeploymentTarget::External { ref repo_url, .. } => {
                self.deploy_external(repo_url, generated_app).await
            }
        }
    }
}
```

**Estimated Effort:** 12-16 hours

---

### Phase 0.2: Forgejo Integration

**File:** `botserver/src/deployment/forgejo.rs`

```rust
use git2::{Repository};
use reqwest::Client;

pub struct ForgejoClient {
    base_url: String,
    token: String,
    client: Client,
}

impl ForgejoClient {
    /// Create a new repository in Forgejo
    pub async fn create_repository(
        &self,
        name: &str,
        description: &str,
        private: bool,
    ) -> Result<ForgejoRepo, ForgejoError> {
        // API call to create repo
        todo!()
    }

    /// Push generated app to Forgejo repository
    pub async fn push_app(
        &self,
        repo_url: &str,
        app: &GeneratedApp,
        branch: &str,
    ) -> Result<String, ForgejoError> {
        // 1. Initialize local git repo
        // 2. Add all files
        // 3. Create commit
        // 4. Add Forgejo remote
        // 5. Push to Forgejo
        todo!()
    }

    /// Create CI/CD workflow for the app
    pub async fn create_cicd_workflow(
        &self,
        repo_url: &str,
        app_type: AppType,
        build_config: BuildConfig,
    ) -> Result<(), ForgejoError> {
        // Create .forgejo/workflows/deploy.yml
        todo!()
    }
}
```

**Estimated Effort:** 20-24 hours

---

### Phase 0.3: Deployment UI

**File:** `botui/ui/suite/partials/vibe-deployment.html`

```html
<!-- Deployment Choice Modal -->
<div class="deployment-modal" id="deploymentModal">
    <div class="deployment-modal-content">
        <h2>Choose Deployment Target</h2>

        <div class="deployment-targets">
            <!-- Internal GB Platform -->
            <div class="deployment-target-card" onclick="selectDeployment('internal')">
                <div class="target-icon">📱</div>
                <h3>GB Platform</h3>
                <p>Deploy directly to the GB platform with shared resources</p>
                <ul>
                    <li>✓ Fast deployment</li>
                    <li>✓ Shared authentication</li>
                    <li>✓ Shared database</li>
                    <li>✓ API integration</li>
                </ul>
            </div>

            <!-- External Forgejo -->
            <div class="deployment-target-card" onclick="selectDeployment('external')">
                <div class="target-icon">🌐</div>
                <h3>Forgejo ALM</h3>
                <p>Deploy to an external Forgejo repository with full CI/CD</p>
                <ul>
                    <li>✓ Independent deployment</li>
                    <li>✓ Custom domain</li>
                    <li>✓ Version control</li>
                    <li>✓ CI/CD pipelines</li>
                </ul>
            </div>
        </div>

        <div class="deployment-actions">
            <button onclick="confirmDeployment()">Deploy App</button>
        </div>
    </div>
</div>
```

**Estimated Effort:** 8-10 hours

---

## Part III: MCP Integration

**Priority:** 🟡 **HIGH** - Leverage existing infrastructure

### What Already Exists

**Backend Implementation:**
```
botserver/src/sources/
├── mod.rs              # Module exports
├── mcp.rs              # MCP client, connection, server types
├── ui.rs               # HTML pages for /suite/sources/*
├── knowledge_base.rs   # Knowledge base upload/query
└── sources_api         # API endpoints
```

**API Endpoints (40+ endpoints):**
```
/suite/sources:
  - Main sources list page
  - MCP server catalog
  - Add MCP server form

/api/ui/sources/*:
  - /api/ui/sources/mcp               - List MCP servers
  - /api/ui/sources/mcp/:name/enable  - Enable server
  - /api/ui/sources/mcp/:name/tools   - List tools
  - /api/ui/sources/kb/query          - Query knowledge base
  - /api/ui/sources/repositories      - List repos
  - /api/ui/sources/apps              - List apps
```

### Integration Task: Add MCP Panel to Vibe

**Goal:** Show connected MCP servers in Vibe sidebar

**Files to Create:**
1. `botui/ui/suite/partials/vibe-mcp-panel.html` - MCP panel UI
2. `botui/ui/suite/js/vibe-mcp.js` - Server management JavaScript
3. `botui/ui/suite/vibe/mcp-panel.css` - Styling

**Features:**
- List connected MCP servers
- Show server status (active/inactive)
- Display available tools per server
- Quick enable/disable toggles
- "Add Server" button (opens `/suite/sources/mcp/add`)

**Estimated Effort:** 6-8 hours

---

## Part IV: Professional Development Tools

### Phase 1: Code Editor Integration (P0 - Critical)

**Goal:** Replace textarea with Monaco Editor

**Tasks:**
1. Download Monaco Editor
   ```bash
   cd botui
   npm install monaco-editor@0.45.0
   cp -r node_modules/monaco-editor min/vs ui/suite/js/vendor/
   ```

2. Create Editor Component
   - `botui/ui/suite/partials/editor.html`
   - Monaco container with tab bar
   - File tree sidebar
   - Save/Publish buttons

3. Editor JavaScript
   - `botui/ui/suite/js/editor.js`
   - Monaco initialization
   - Language detection (.html, .css, .js, .bas, .json)
   - Tab management (open, close, switch)
   - Auto-save with WebSocket sync

4. API Endpoints
   - `botserver/src/api/editor.rs`
   - GET `/api/editor/file/{path}` - Read file
   - POST `/api/editor/file/{path}` - Save file
   - GET `/api/editor/files` - List files

**Estimated Effort:** 8-12 hours

---

### Phase 2: Database UI & Schema Visualization (P0 - Critical)

**Goal:** Visual database management and query builder

**Tasks:**
1. Schema Visualizer Component
   - `botui/ui/suite/partials/database.html`
   - Canvas-based ER diagram
   - Table cards with fields
   - Relationship lines (foreign keys)

2. Database JavaScript
   - `botui/ui/suite/js/database.js`
   - Fetch schema: `/api/database/schema`
   - Render tables using Canvas API

3. Backend API
   - `botserver/src/api/database.rs`
   - GET `/api/database/schema` - Tables, fields, relationships
   - GET `/api/database/table/{name}/data` - Paginated data
   - POST `/api/database/query` - Execute SQL

**Estimated Effort:** 16-20 hours

---

### Phase 3: Git Operations UI (P1 - High Priority)

**Goal:** Version control interface in Vibe

**Tasks:**
1. Git Status Panel
   - `botui/ui/suite/partials/git-status.html`
   - File list with status icons
   - Stage/unstage checkboxes

2. Diff Viewer
   - `botui/ui/suite/partials/git-diff.html`
   - Side-by-side comparison

3. Backend API
   - `botserver/src/api/git.rs`
   - GET `/api/git/status` - Git status
   - GET `/api/git/diff/{file}` - File diff
   - POST `/api/git/commit` - Create commit
   - GET `/api/git/branches` - List branches

**Forgejo-Specific Features:**
- View Forgejo repository status
- Sync with Forgejo remote
- View CI/CD pipeline status
- Trigger manual builds

**Estimated Effort:** 12-16 hours

---

### Phase 4: Browser Automation Engine (P1 - High Priority)

**Goal:** Pure Rust browser automation for testing & recording

**Why Rust + Chromiumoxide:**
- ✅ Already in workspace: `chromiumoxide = "0.7"`
- ✅ No Node.js dependency
- ✅ Reference implementation: `bottest/src/web/browser.rs`

**Tasks:**
1. Core Browser Module
   - `botserver/src/browser/mod.rs`
   - `BrowserSession`, `BrowserManager`
   - Methods: `navigate()`, `click()`, `fill()`, `screenshot()`

2. Action Recorder
   - `botserver/src/browser/recorder.rs`
   - `RecordedAction` - Navigate, Click, Fill, Wait, Assert
   - Export as Playwright test

3. Browser API
   - `botserver/src/browser/api.rs`
   - POST `/api/browser/session` - Create session
   - POST `/api/browser/session/:id/execute` - Run action
   - POST `/api/browser/session/:id/record/start` - Start recording

4. Vibe UI - Browser Panel
   - `botui/ui/suite/partials/browser-controls.html`
   - `botui/ui/suite/js/browser.js`

**Estimated Effort:** 20-24 hours

---

### Phase 5: Multi-File Editing Workspace (P2 - Medium Priority)

**Goal:** Professional multi-file editing

**Tasks:**
1. Tab Management
   - File tabs with close buttons
   - Active tab highlighting
   - Drag to reorder

2. Split-Pane Layout
   - Split horizontal/vertical buttons
   - Resize handles
   - 2x2 grid max

3. File Tree Sidebar
   - Nested folders
   - File type icons
   - Double-click to open

4. Quick Open
   - Ctrl+P → Search files
   - Fuzzy matching

**Estimated Effort:** 12-16 hours

---

### Phase 6: Enhanced Terminal (P2 - Medium Priority)

**Goal:** Interactive shell in Vibe

**Tasks:**
1. Terminal Container
   - xterm.js integration (already vendor file)
   - Multiple terminal tabs

2. WebSocket Terminal
   - Bi-directional WebSocket: `/ws/terminal/{session_id}`
   - Handle ANSI escape codes

3. Backend Terminal Server
   - Spawn PTY per session
   - WebSocket handler

**Estimated Effort:** 10-14 hours

---

### Phase 7: Advanced CRM Templates (P2 - Medium Priority)

**Goal:** Pre-built CRM accelerators

**Tasks:**
1. Template System
   - `botserver/src/templates/crm/`
   - Template JSON definitions

2. CRM Templates
   - **Sales CRM** - contacts, leads, opportunities
   - **Real Estate CRM** - properties, clients, showings
   - **Healthcare CRM** - patients, appointments, treatments

3. Template Gallery UI
   - `botui/ui/suite/partials/template-gallery.html`

4. Template Generator
   - Load template JSON
   - Generate all files
   - Deploy to target (internal/external)

**Estimated Effort:** 20-24 hours

---

## Part V: Architecture Diagrams

### Overall System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     USER REQUEST                             │
│              "I want a full CRM system"                      │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              VIBE BUILDER UI                                 │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐            │
│  │ Orchestrator│  │AppGenerator│  │Designer AI │            │
│  │ (5 agents)  │  │(LLM-driven)│  │(modifications)│         │
│  └────────────┘  └────────────┘  └────────────┘            │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐            │
│  │  Browser   │  │   Git      │  │  Terminal  │            │
│  │ Automation │  │ Operations │  │  Service   │            │
│  │(chromiumoxide)│ │(git2)     │  │(xterm.js)  │            │
│  └────────────┘  └────────────┘  └────────────┘            │
│  ┌────────────────────────────────────────────┐            │
│  │ MCP & Sources Integration ← ALREADY EXISTS  │            │
│  │ - botserver/src/sources/mcp.rs             │            │
│  │ - /api/ui/sources/* endpoints              │            │
│  └────────────────────────────────────────────┘            │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                  DEPLOYMENT CHOICE                           │
│  ┌──────────────────┐  ┌──────────────────┐                │
│  │ INTERNAL GB APPS │  │  FORGEJO ALM     │                │
│  │ - /apps/{name}   │  │  - Git repo      │                │
│  │ - GB APIs        │  │  - CI/CD         │                │
│  │ - Shared DB      │  │  - Custom domain │                │
│  └──────────────────┘  └──────────────────┘                │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                  GENERATED OUTPUT                            │
│  - PostgreSQL tables                                         │
│  - HTML pages with HTMX                                      │
│  - CSS styling                                               │
│  - JavaScript                                                │
│  - BASIC tools/schedulers                                    │
│  - E2E tests (Playwright)                                    │
└─────────────────────────────────────────────────────────────┘
```

### Vibe UI Layout

```
┌──────────────────────────────────────────────────────────────┐
│  VIBE BUILDER                                                │
├──────────────┬───────────────────────────────────────────────┤
│              │  PIPELINE TABS                                │
│   AGENTS     │  [PLAN] [BUILD] [REVIEW] [DEPLOY] [MONITOR]  │
│   SIDEBAR    ├───────────────────────────────────────────────┤
│              │                                               │
│ ┌──────────┐ │  CANVAS AREA                                 │
│ │Mantis #1│ │  - Task nodes (horizontal flow)              │
│ │ EVOLVED  │ │  - Preview panel                             │
│ └──────────┘ │  - Chat overlay                              │
│ ┌──────────┐ │                                               │
│ │Mantis #2│ │  [DEPLOYMENT BUTTON]                          │
│ │  BRED   │ │                                               │
│ └──────────┘ │                                               │
│ ┌──────────┐ │                                               │
│ │Mantis #3│ │                                               │
│ │  WILD   │ │                                               │
│ └──────────┘ │                                               │
│              │                                               │
│ [+ NEW AGENT] │                                               │
├──────────────┤                                               │
│   WORKSPACES │                                               │
│ ┌──────────┐ │                                               │
│ │E-Commerce│ │                                               │
│ │  App     │ │                                               │
│ └──────────┘ │                                               │
│              │                                               │
│ [+ PROJECT]  │                                               │
├──────────────┤                                               │
│   SOURCES    │  [NEW - MCP Integration]                     │
│ ┌──────────┐ │                                               │
│ │🔌 GitHub │ │                                               │
│ │   MCP    │ │                                               │
│ └──────────┘ │                                               │
│ ┌──────────┐ │                                               │
│ │🗄️ Postgres│ │                                               │
│ │   MCP    │ │                                               │
│ └──────────┘ │                                               │
│              │                                               │
│ [+ ADD MCP]  │                                               │
└──────────────┴───────────────────────────────────────────────┘
```

---

## Part VI: Implementation Phases

### Milestone 0: Security & Deployment Infrastructure (Week 0)

**Day 1-2:** Security Fixes
- Fix all unsafe `unwrap()` calls
- Address dependency vulnerabilities
- Verify CSRF & security headers

**Day 3-4:** Deployment Router
- `botserver/src/deployment/mod.rs`
- DeploymentTarget enum
- DeploymentRouter implementation

**Day 5-6:** Forgejo Integration
- `botserver/src/deployment/forgejo.rs`
- ForgejoClient implementation
- CI/CD workflow generation

**Day 7:** Deployment UI
- `botui/ui/suite/partials/vibe-deployment.html`
- Deployment modal
- Integration into Vibe

**Success Criteria:**
- ✅ Zero `unwrap()` in production code
- ✅ `cargo audit` passes
- ✅ Can deploy internally to /apps/{name}
- ✅ Can deploy externally to Forgejo
- ✅ CI/CD pipeline auto-generates

---

### Milestone 1: Core Editor (Week 1)

- Phase 1 complete (Monaco integration)

**Success Criteria:**
- Monaco loads < 2 seconds
- 5+ syntax highlighters work
- Multi-file tabs functional

---

### Milestone 2: Database & Git (Week 2)

- Phase 2 complete (Database UI)
- Phase 3 complete (Git Operations + Forgejo)

**Success Criteria:**
- Schema visualizer displays all tables
- Query builder generates valid SQL
- Git status shows changed files
- Forgejo sync works

---

### Milestone 3: Browser & Workspace (Week 3)

- Phase 4 complete (Browser Automation)
- Phase 5 complete (Multi-File Editing)

**Success Criteria:**
- Can navigate to any URL
- Recording generates valid tests
- 10+ files open in tabs
- Split view supports 2-4 panes

---

### Milestone 4: Terminal & Templates (Week 4)

- Phase 6 complete (Enhanced Terminal)
- Phase 7 complete (CRM Templates)

**Success Criteria:**
- Interactive shell works
- Multiple terminals run simultaneously
- 3+ CRM templates available
- Generation takes < 30 seconds

---

## Part VII: File Organization

### Botserver (Backend)

```
botserver/src/
  deployment/           # NEW - Deployment infrastructure
    mod.rs              # DeploymentRouter
    forgejo.rs          # ForgejoClient
    api.rs              # Deployment API endpoints
    templates.rs        # CI/CD workflow templates
  api/
    editor.rs           # NEW - Code editor API
    database.rs         # NEW - Database UI API
    git.rs              # NEW - Git operations API
  browser/
    mod.rs              # NEW - BrowserSession, BrowserManager
    recorder.rs         # NEW - ActionRecorder
    validator.rs        # NEW - TestValidator
    api.rs              # NEW - HTTP endpoints
    test_generator.rs   # NEW - Test script generator
  templates/            # NEW - CRM templates
    crm/
      sales.json
      real_estate.json
      healthcare.json
    mod.rs
  sources/              # EXISTING - MCP integration
    mod.rs
    mcp.rs
    ui.rs
    knowledge_base.rs
```

### Botui (Frontend)

```
botui/ui/suite/
  partials/
    vibe.html                    # EXISTING - Main Vibe UI
    vibe-deployment.html         # NEW - Deployment modal
    vibe-mcp-panel.html          # NEW - MCP panel
    editor.html                  # NEW - Code editor
    database.html                # NEW - Database UI
    git-status.html              # NEW - Git status
    git-diff.html                # NEW - Diff viewer
    browser-controls.html        # NEW - Browser automation
    terminal.html                # NEW - Terminal
    template-gallery.html        # NEW - Template gallery
  js/
    deployment.js                # NEW - Deployment logic
    editor.js                    # NEW - Monaco integration
    database.js                  # NEW - Database UI
    git.js                       # NEW - Git operations
    browser.js                   # NEW - Browser automation
    terminal.js                  # NEW - Terminal
    templates.js                 # NEW - Templates
  css/
    deployment.css               # NEW - Deployment styles
    editor.css                   # NEW - Editor styles
    database.css                 # NEW - Database styles
    git.css                      # NEW - Git styles
    browser.css                  # NEW - Browser styles
    terminal.css                 # NEW - Terminal styles
    templates.css                # NEW - Template styles
  vibe/
    agents-sidebar.css           # EXISTING
    mcp-panel.css                # NEW - MCP panel styles
```

---

## Part VIII: Testing Strategy

### Unit Tests
- All new modules need unit tests
- Test coverage > 80%
- Location: `botserver/src/<module>/tests.rs`

### Integration Tests
- End-to-end workflows
- Location: `bottest/tests/integration/`

### E2E Tests
- Use chromiumoxide (bottest infrastructure)
- Location: `bottest/tests/e2e/`
- Test scenarios:
  - Generate CRM from template
  - Deploy internally to /apps/{name}
  - Deploy externally to Forgejo
  - Edit in Monaco editor
  - View database schema
  - Create git commit
  - Record browser test

---

## Part IX: Rollout Plan

### Week 0: Security & Deployment (CRITICAL)
- **Day 1-2:** Security fixes
- **Day 3-4:** Deployment Router
- **Day 5-6:** Forgejo Integration
- **Day 7:** Deployment UI

### Week 1: Code Editor
- Monaco integration
- File tree
- Tab management

### Week 2: Database & Git
- Schema visualizer
- Query builder
- Git operations
- Forgejo sync

### Week 3: Browser & Workspace
- Browser automation UI
- Multi-file editing
- Split-pane layout

### Week 4: Terminal & Templates
- Enhanced terminal
- CRM templates
- Template gallery

---

## Part X: Success Metrics

### Security Milestones
- ✅ Zero `unwrap()` in production code
- ✅ `cargo audit` passes
- ✅ All endpoints have CSRF + security headers

### Deployment Infrastructure
- ✅ Internal deployment < 30 seconds
- ✅ External Forgejo deployment < 2 minutes
- ✅ CI/CD pipeline auto-generates
- ✅ Both models accessible from Vibe UI

### MCP Integration
- ✅ MCP panel visible in Vibe sidebar
- ✅ Can enable/disable servers
- ✅ Can view available tools
- ✅ Can add new servers

### Code Editor
- Monaco loads < 2 seconds
- 5+ syntax highlighters work
- Multi-file tabs functional
- Auto-save succeeds

### Database UI
- Schema visualizer displays all tables
- Query builder generates valid SQL
- Data grid supports inline edits
- Export works correctly

### Git Operations
- Git status shows changed files
- Diff viewer shows side-by-side
- Commit workflow works end-to-end
- Forgejo sync succeeds

### Browser Automation
- Can navigate to any URL
- Element picker captures selectors
- Recording generates valid tests
- Screenshots capture correctly

### Multi-File Workspace
- 10+ files open in tabs
- Split view supports 2-4 panes
- File comparison works
- Project search is fast (< 1s for 100 files)

### Terminal
- Interactive shell works
- Can run vim, top, etc.
- Multiple terminals run simultaneously
- File transfer works

### CRM Templates
- 3+ CRM templates available
- Generation takes < 30 seconds
- Generated CRMs are fully functional
- Industry-specific features work

---

## Conclusion

The VibeCode platform has a **powerful backend** capable of generating full applications via LLM. The main gaps are in **frontend user experience**, **security hardening**, and **deployment routing**.

**Critical Path:**
1. ⚠️ **Week 0:** Security fixes + Deployment infrastructure
2. 🔌 **Week 0.5:** MCP integration in Vibe
3. 📝 **Week 1:** Monaco code editor
4. 🗄️ **Week 2:** Database UI + Git operations
5. 🌐 **Week 3:** Browser automation + Multi-file workspace
6. 🖥️ **Week 4:** Terminal + CRM templates

Once these phases are complete, VibeCode will match or exceed Claude Code's capabilities while offering:

✅ **Dual deployment model** (Internal GB Apps + External Forgejo Projects)
✅ **Multi-user SaaS deployment**
✅ **Visual app building** (Vibe Builder)
✅ **Enterprise-grade multi-agent orchestration**
✅ **Pure Rust backend** (no Node.js dependency)
✅ **Integrated MCP servers** (extensible tools)
✅ **Integrated browser automation** (chromiumoxide)
✅ **Professional development environment**

**Total Estimated Effort:** 165-205 hours (~4-5 weeks with 1 developer)

---

## Appendix: Code Quality Standards

**MUST Follow (per AGENTS.md):**
1. ✅ **Error Handling** - NO panics, use `?` operator
2. ✅ **Safe Commands** - Use `SafeCommand` wrapper
3. ✅ **Error Sanitization** - Use `ErrorSanitizer`
4. ✅ **SQL Safety** - Use `sql_guard`
5. ✅ **Rate Limiting** - Per-IP and per-User limits
6. ✅ **CSRF Protection** - CSRF tokens on state-changing endpoints
7. ✅ **Security Headers** - CSP, HSTS, X-Frame-Options
8. ✅ **No CDNs** - All assets local
9. ✅ **File Size** - Max 450 lines per file
10. ✅ **Clippy Clean** - 0 warnings, no `#[allow()]`

---

## Appendix: Dependencies

### Backend (Already in Workspace)

```toml
[dependencies]
chromiumoxide = "0.7"  # Browser automation
tokio = "1.41"          # Async runtime
axum = "0.7"            # HTTP framework
diesel = "2.1"          # Database
git2 = "0.18"           # Git operations
reqwest = { version = "0.11", features = ["json"] }  # HTTP client
```

### Frontend (Download & Serve Locally)

```bash
# Code editor
npm install monaco-editor@0.45.0

# Terminal (already vendor file exists)
# xterm.js@5.3.0
```

---

**Document Version:** 2.0
**Last Updated:** 2025-02-28
**Status:** Ready for Implementation

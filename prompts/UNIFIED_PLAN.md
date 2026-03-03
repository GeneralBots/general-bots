# Unified Implementation Plan: VibeCode Platform

## Executive Summary

This document **unifies** two separate task lists into a cohesive roadmap:
- **task.md**: Security & stability fixes (immediate priority)
- **TASK.md**: Feature implementation roadmap (development pipeline)

**Current Status:**
- 🎯 Backend: **80% complete** - LLM-powered app generation, multi-agent orchestration, browser automation ready
- 🎨 Frontend: **40% complete** - Vibe UI exists, missing professional tools (Monaco, Database UI, Git, Browser)
- 🔐 Security: **Needs attention** - Unsafe unwraps, dependency vulnerabilities (see Security Priorities below)

---

## Part I: Security & Stability (FROM task.md) - IMMEDIATE PRIORITY ⚠️

### 1. Unsafe Unwraps in Production (Violates AGENTS.md Error Handling)

**Issue:** The codebase uses `.unwrap()`, `.expect()`, `panic!()` in production code, which is explicitly forbidden by AGENTS.md.

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

### 2. Dependency Vulnerabilities (Found by `cargo audit`)

**Vulnerable Component:**
- **Crate:** `glib 0.18.5`
- **Advisory:** `RUSTSEC-2024-0429`
- **Issue:** Unsoundness in `Iterator` and `DoubleEndedIterator` impls for `glib::VariantStrIter`
- **Context:** Pulled through `botdevice` and `botapp` via Tauri plugins/GTK dependencies

**Action Items:**
- [ ] Review exact usage of glib in the codebase
- [ ] Check if patches are available in newer versions
- [ ] Evaluate risk given desktop GUI context
- [ ] If critical: upgrade GTK/Glib ecosystem dependencies
- [ ] If acceptable: document risk assessment and add to security review checklist

**Estimated Effort:** 2-4 hours

---

### 3. General Security Posture Alignment

**CSRF Protection:**
- ✅ Custom CSRF store exists: `redis_csrf_store.rs`
- ⚠️ Verify: ALL state-changing endpoints use it (standard `tower-csrf` is absent from Cargo.toml)

**Security Headers:**
- ✅ `headers.rs` provides CSP, HSTS, X-Frame-Options
- ⚠️ Verify: Headers are attached UNIVERSALLY in botserver, not selectively omitted

**Action Items:**
- [ ] Audit all POST/PUT/DELETE endpoints for CSRF token validation
- [ ] Create middleware test to ensure security headers on all responses
- [ ] Document security checklist for new endpoints

**Estimated Effort:** 3-4 hours

---

## Part II: Feature Implementation Roadmap (FROM TASK.md) - DEVELOPMENT PIPELINE

### Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│                    USER REQUEST                              │
│              "I want a full CRM system"                       │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────┐
│              VIBE BUILDER UI                                  │
│  ┌──────────────────┐  ┌──────────────────┐                │
│  │ Agent Sidebar    │  │ Canvas Area      │                │
│  │ (Mantis #1-4)    │  │ - Task Nodes     │                │
│  │ - Status cards   │  │ - Preview        │                │
│  │ - Workspaces     │  │ - Chat Overlay   │                │
│  └──────────────────┘  └──────────────────┘                │
│                                                              │
│  NEW TOOLS TO ADD:                                           │
│  🔌 MCP Sources Panel ← botserver/src/sources/ui.rs          │
│  📝 Monaco Editor         ← Phase 1 (Critical)               │
│  🗄️ Database Visualizer   ← Phase 2 (Critical)               │
│  🐙 Git Operations        ← Phase 3 (High)                   │
│  🌐 Browser Automation    ← Phase 4 (High)                   │
│  📂 Multi-File Workspace  ← Phase 5 (Medium)                 │
│  🖥️ Enhanced Terminal     ← Phase 6 (Medium)                 │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────┐
│         BOTSERVER (Rust Backend)                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Orchestrator │  │ AppGenerator │  │ Designer AI  │      │
│  │ (5 agents)   │  │(LLM-driven)  │  │(modifications)│     │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Browser      │  │ Git          │  │ Terminal     │      │
│  │ Automation   │  │ Operations   │  │ Service      │      │
│  │(chromiumoxide)│ │(git2)        │  │(xterm.js)    │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│  ┌──────────────────────────────────────────────────┐       │
│  │ MCP & Sources Integration ← ALREADY IMPLEMENTED  │       │
│  │ - botserver/src/sources/mcp.rs                   │       │
│  │ - botserver/src/sources/ui.rs                    │       │
│  │ - /api/ui/sources/* endpoints                    │       │
│  └──────────────────────────────────────────────────┘       │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────┐
│                  GENERATED OUTPUT                            │
│  - PostgreSQL tables                                         │
│  - HTML pages with HTMX                                      │
│  - CSS styling                                               │
│  - JavaScript                                                │
│  - BASIC tools/schedulers                                    │
│  - E2E tests (Playwright)                                    │
└──────────────────────────────────────────────────────────────┘
```

---

## Part III: MCP & Sources Integration - EXISTING INFRASTRUCTURE ✅

### What Already Exists

**Backend Implementation (botserver/src/sources/):**
```
sources/
├── mod.rs              # Module exports
├── mcp.rs              # MCP client, connection, server types
├── ui.rs               # HTML pages for /suite/sources/*
├── knowledge_base.rs   # Knowledge base upload/query
└── sources_api         # API endpoints
```

**API Endpoints (defined in botserver/src/core/urls.rs):**
```
/sources/*:
  /suite/sources                    - Main sources list page
  /suite/sources/mcp/add            - Add MCP server form
  /suite/sources/mcp/catalog        - MCP server catalog

/api/ui/sources/*:
  /api/ui/sources/mcp               - List MCP servers
  /api/ui/sources/mcp/:name         - Get server details
  /api/ui/sources/mcp/:name/enable  - Enable server
  /api/ui/sources/mcp/:name/disable - Disable server
  /api/ui/sources/mcp/:name/tools   - List server tools
  /api/ui/sources/mcp/:name/test    - Test server connection
  /api/ui/sources/mcp/scan          - Scan for MCP servers
  /api/ui/sources/mcp-servers       - Get server catalog
  /api/ui/sources/kb/upload         - Upload to knowledge base
  /api/ui/sources/kb/list           - List knowledge base docs
  /api/ui/sources/kb/query          - Query knowledge base
  /api/ui/sources/repositories      - List repositories
  /api/ui/sources/apps              - List connected apps
```

**Vibe UI Integration (botui/ui/suite/):**
```
botui/ui/suite/
├── partials/
│   └── vibe.html           # Main Vibe Builder UI
│                           # - Agent sidebar (Mantis #1-4)
│                           # - Canvas area with task nodes
│                           # - Chat overlay
│                           # - Preview panel
├── vibe/
│   └── agents-sidebar.css  # Styles for agent sidebar
├── js/
│   └── chat-agent-mode.js  # Agent-mode JavaScript
└── css/
    └── chat-agent-mode.css # Agent-mode styles
```

### Integration Task: Add MCP Panel to Vibe UI

**Goal:** Add a "Sources" panel to Vibe that shows connected MCP servers and allows management.

**Action Items:**
1. **Create MCP Panel Component:**
   - File: `botui/ui/suite/partials/vibe-mcp-panel.html`
   - Features:
     - List connected MCP servers
     - Show server status (active/inactive)
     - Display available tools per server
     - Quick enable/disable toggles
     - "Add Server" button (opens `/suite/sources/mcp/add`)

2. **Add JavaScript:**
   - File: `botui/ui/suite/js/vibe-mcp.js`
   - Fetch servers from `/api/ui/sources/mcp`
   - Handle enable/disable actions
   - Update server status in real-time
   - Display tool risk levels

3. **Add Styles:**
   - File: `botui/ui/suite/vibe/mcp-panel.css`
   - Match existing agents-sidebar.css aesthetic
   - Server cards with status indicators
   - Tool badges with risk levels

4. **Integrate into Vibe:**
   - Add "Sources" tab to Vibe sidebar
   - Load MCP panel when tab clicked
   - Show server count badge

**Estimated Effort:** 6-8 hours

---

## Part IV: Implementation Phases (UPDATED WITH MCP INTEGRATION)

### Phase 0: Security & Stability ⚠️ - IMMEDIATE (Week 0)

**Priority: CRITICAL - Must complete before any feature work**

**Tasks:**
1. [ ] Fix all unsafe `unwrap()` calls
2. [ ] Address dependency vulnerabilities
3. [ ] Verify CSRF & security headers coverage

**Estimated Effort:** 9-14 hours

**Success Criteria:**
- ✅ Zero `unwrap()` in production code
- ✅ `cargo audit` passes cleanly
- ✅ All state-changing endpoints use CSRF tokens
- ✅ All responses include security headers

---

### Phase 0.5: MCP Integration in Vibe (Week 0.5)

**Priority: HIGH - Leverage existing infrastructure**

**Tasks:**
1. [ ] Create MCP panel component
2. [ ] Add JavaScript for server management
3. [ ] Style panel to match Vibe aesthetic
4. [ ] Integrate into Vibe sidebar

**Estimated Effort:** 6-8 hours

**Success Criteria:**
- ✅ MCP servers visible in Vibe UI
- ✅ Can enable/disable servers
- ✅ Can see available tools
- ✅ Can add new servers

---

### Phase 1: Code Editor Integration (P0 - Critical)

**Goal:** Replace textarea with professional code editor

**Tasks:**

1. **Download Monaco Editor**
   ```bash
   cd botui
   npm install monaco-editor@0.45.0
   cp -r node_modules/monaco-editor min/vs ui/suite/js/vendor/
   ```

2. **Create Editor Component**
   - `botui/ui/suite/partials/editor.html`
   - Monaco container with tab bar
   - File tree sidebar
   - Save/Publish buttons

3. **Editor JavaScript**
   - `botui/ui/suite/js/editor.js`
   - Monaco initialization
   - Language detection (.html, .css, .js, .bas, .json)
   - Tab management (open, close, switch)
   - Auto-save with WebSocket sync

4. **API Endpoints**
   - `botserver/src/api/editor.rs`
   - GET `/api/editor/file/{path}` - Read file
   - POST `/api/editor/file/{path}` - Save file
   - GET `/api/editor/files` - List files

5. **Integration**
   - Update `chat-agent-mode.html` - replace textarea with Monaco
   - Update `vibe.html` - add editor panel
   - Add keyboard shortcuts (Ctrl+S, Ctrl+P, Ctrl+Shift+F)

**Success Criteria:**
- Monaco loads in < 2 seconds
- Syntax highlighting for 5+ languages
- Multi-file tabs work
- Auto-save completes successfully

**Estimated Effort:** 8-12 hours

---

### Phase 2: Database UI & Schema Visualization (P0 - Critical)

**Goal:** Visual database management and query builder

**Tasks:**

1. **Schema Visualizer Component**
   - `botui/ui/suite/partials/database.html`
   - Canvas-based ER diagram
   - Table cards with fields
   - Relationship lines (foreign keys)
   - Zoom/pan controls

2. **Database JavaScript**
   - `botui/ui/suite/js/database.js`
   - Fetch schema: `/api/database/schema`
   - Render tables using Canvas API
   - Click table → show field details
   - Drag to rearrange

3. **Query Builder UI**
   - Visual SELECT builder
   - Table selection dropdown
   - Join interface
   - Filter conditions
   - SQL preview pane

4. **Data Grid**
   - Sortable columns
   - Inline editing
   - Pagination
   - Export (CSV/JSON)

5. **Backend API**
   - `botserver/src/api/database.rs`
   - GET `/api/database/schema` - Tables, fields, relationships
   - GET `/api/database/table/{name}/data` - Paginated data
   - POST `/api/database/query` - Execute SQL
   - POST `/api/database/table/{name}/row` - Insert/update
   - DELETE `/api/database/table/{name}/row/{id}` - Delete

**Success Criteria:**
- ER diagram shows all tables
- Query builder generates valid SQL
- Data grid supports inline edits
- Export works correctly

**Estimated Effort:** 16-20 hours

---

### Phase 3: Git Operations UI (P1 - High Priority)

**Goal:** Version control interface in Vibe

**Tasks:**

1. **Git Status Panel**
   - `botui/ui/suite/partials/git-status.html`
   - File list with status icons
   - Stage/unstage checkboxes
   - "Commit" button

2. **Diff Viewer**
   - `botui/ui/suite/partials/git-diff.html`
   - Side-by-side comparison
   - Line highlighting (green/red)
   - Syntax highlighting

3. **Commit Interface**
   - Message input
   - "Commit & Push" button
   - Progress indicator

4. **Branch Manager**
   - Branch dropdown
   - "New Branch" dialog
   - Switch/delete actions

5. **Commit Timeline**
   - Vertical timeline
   - Author, date, message
   - Click → view diff

6. **Backend API**
   - `botserver/src/api/git.rs`
   - GET `/api/git/status` - Git status
   - GET `/api/git/diff/{file}` - File diff
   - POST `/api/git/commit` - Create commit
   - POST `/api/git/push` - Push to remote
   - GET `/api/git/branches` - List branches
   - POST `/api/git/branch/{name}` - Create/switch
   - GET `/api/git/log` - Commit history

**Success Criteria:**
- Git status displays correctly
- Diff viewer shows side-by-side
- Commit workflow works end-to-end
- Branch switching succeeds

**Estimated Effort:** 12-16 hours

---

### Phase 4: Browser Automation Engine (P1 - High Priority)

**Goal:** Pure Rust browser automation for testing & recording

**Why Rust + Chromiumoxide:**
- ✅ Already in workspace: `chromiumoxide = "0.7"`
- ✅ No Node.js dependency
- ✅ Feature flag exists: `browser` in botserver/Cargo.toml
- ✅ Reference implementation: bottest/src/web/browser.rs (1000+ lines)

**Tasks:**

1. **Core Browser Module**
   - `botserver/src/browser/mod.rs`
     - `BrowserSession` - Manage browser instance
     - `BrowserManager` - Session lifecycle
     - Methods: `navigate()`, `click()`, `fill()`, `screenshot()`, `execute()`

2. **Action Recorder**
   - `botserver/src/browser/recorder.rs`
     - `RecordedAction` - Navigate, Click, Fill, Wait, Assert
     - `ActionRecorder` - Record/stop/export
     - Export as Playwright test

3. **Test Validator**
   - `botserver/src/browser/validator.rs`
     - Check for flaky selectors
     - Validate wait conditions
     - Suggest improvements via Designer AI

4. **Browser API**
   - `botserver/src/browser/api.rs`
     - POST `/api/browser/session` - Create session
     - POST `/api/browser/session/:id/execute` - Run action
     - GET `/api/browser/session/:id/screenshot` - Capture
     - POST `/api/browser/session/:id/record/start` - Start recording
     - POST `/api/browser/session/:id/record/stop` - Stop & get actions
     - GET `/api/browser/session/:id/record/export` - Export test

5. **Vibe UI - Browser Panel**
   - `botui/ui/suite/partials/browser-controls.html`
     - URL bar with navigation buttons
     - Record/Stop/Export buttons
     - Actions timeline
     - Browser preview iframe
     - Screenshot gallery

   - `botui/ui/suite/js/browser.js`
     - Session management
     - Action recording
     - Test export

   - `botui/ui/suite/css/browser.css`
     - Browser panel styling
     - Recording indicator animation
     - Actions timeline
     - Screenshot gallery grid

6. **Integration with Vibe**
   - Add "Browser Automation" button to Vibe toolbar
   - Load browser-controls.html in panel
   - Element picker for selector capture
   - Screenshot capture & gallery

**Success Criteria:**
- Can navigate to any URL
- Element picker captures selectors
- Recording generates valid Playwright tests
- Screenshots capture correctly

**Estimated Effort:** 20-24 hours

---

### Phase 5: Multi-File Editing Workspace (P2 - Medium Priority)

**Goal:** Professional multi-file editing

**Tasks:**

1. **Tab Management**
   - File tabs with close buttons
   - Active tab highlighting
   - Tab overflow scrolling
   - Drag to reorder

2. **Split-Pane Layout**
   - Split horizontal/vertical buttons
   - Resize handles
   - 2x2 grid max

3. **File Comparison**
   - Side-by-side diff
   - Line-by-line navigation
   - Copy changes (L→R)

4. **File Tree Sidebar**
   - Nested folders
   - File type icons
   - Expand/collapse
   - Double-click to open

5. **Quick Open**
   - Ctrl+P → Search files
   - Fuzzy matching
   - Arrow navigation

6. **Project Search**
   - Ctrl+Shift+F → Search all files
   - Results with line numbers
   - Click to open file

**Success Criteria:**
- 10+ files open in tabs
- Split view works (2-4 panes)
- File comparison displays diffs
- Quick open searches files

**Estimated Effort:** 12-16 hours

---

### Phase 6: Enhanced Terminal (P2 - Medium Priority)

**Goal:** Interactive shell in Vibe

**Tasks:**

1. **Terminal Container**
   - xterm.js integration (already vendor file)
   - Multiple terminal tabs
   - Fit addon for auto-resize

2. **WebSocket Terminal**
   - Bi-directional WebSocket: `/ws/terminal/{session_id}`
   - Protocol: `{"type": "input", "data": "command\n"}`
   - Handle ANSI escape codes

3. **Command History**
   - Up/Down arrows
   - Ctrl+R search
   - Persist in localStorage

4. **Command Completion**
   - Tab completion
   - File path completion
   - Command flags

5. **Backend Terminal Server**
   - Spawn PTY per session
   - WebSocket handler
   - Clean up on disconnect

6. **File Transfer**
   - Drag file to upload
   - `upload` / `download` commands
   - Progress bars

**Success Criteria:**
- Can type commands & see output
- Arrow keys navigate history
- Can run vim, top, etc.
- Multiple terminals work

**Estimated Effort:** 10-14 hours

---

### Phase 7: Advanced CRM Templates (P2 - Medium Priority)

**Goal:** Pre-built CRM accelerators

**Tasks:**

1. **Template System**
   - `botserver/src/templates/crm/`
   - Template JSON definitions
   - Prompt templates
   - Field libraries

2. **CRM Templates**
   - **Sales CRM**
     - Tables: contacts, leads, opportunities, accounts, activities
     - Pages: dashboard, pipeline, contacts list
     - Tools: lead_scoring, email_automation
     - Schedulers: daily_summary, weekly_review

   - **Real Estate CRM**
     - Tables: properties, clients, showings, offers
     - Pages: property gallery, client portal
     - Tools: mls_sync, showing_scheduler
     - Schedulers: showing_reminders, market_update

   - **Healthcare CRM**
     - Tables: patients, appointments, treatments, insurance
     - Pages: patient portal, appointment scheduler
     - Tools: insurance_verification, appointment_reminders
     - Schedulers: daily_appointments, insurance_alerts

3. **Template Gallery UI**
   - `botui/ui/suite/partials/template-gallery.html`
   - Template cards with descriptions
   - Preview screenshots
   - "Use Template" button

4. **Template Generator**
   - Load template JSON
   - Customize with user details
   - Generate all files
   - Deploy to /apps/{name}

**Success Criteria:**
- Can select template from gallery
- Template generates full CRM
- Customization works
- Generated CRM is functional

**Estimated Effort:** 20-24 hours

---

## Part V: Technical Implementation Notes

### Code Quality Standards (per AGENTS.md)

**MUST Follow:**
1. ✅ **Error Handling** - NO panics, use `?` operator
2. ✅ **Safe Commands** - Use `SafeCommand` wrapper
3. ✅ **Error Sanitization** - Use `ErrorSanitizer`
4. ✅ **SQL Safety** - Use `sql_guard`
5. ✅ **Rate Limiting** - Per-IP and per-User limits
6. ✅ **CSRF Protection** - CSRF tokens on state-changing endpoints
7. ✅ **Security Headers** - CSP, HSTS, X-Frame-Options, etc.
8. ✅ **No CDNs** - All assets local
9. ✅ **File Size** - Max 450 lines per file
10. ✅ **Clippy Clean** - 0 warnings, no `#[allow()]`

### File Organization

**Botui (Frontend):**
```
botui/ui/suite/
  partials/
    editor.html
    database.html
    git-status.html
    git-diff.html
    browser-controls.html
    terminal.html
    template-gallery.html
    vibe-mcp-panel.html          # NEW - MCP integration
  js/
    editor.js
    database.js
    git.js
    browser.js
    terminal.js
    templates.js
    vibe-mcp.js                  # NEW - MCP integration
  css/
    editor.css
    database.css
    git.css
    browser.css
    terminal.css
    templates.css
    vibe/
      mcp-panel.css              # NEW - MCP integration
```

**Botserver (Backend):**
```
botserver/src/
  api/
    editor.rs
    database.rs
    git.rs
  browser/
    mod.rs          # BrowserSession, BrowserManager
    recorder.rs     # ActionRecorder
    validator.rs    # TestValidator
    api.rs          # HTTP endpoints
    test_generator.rs
  templates/
    crm/
      sales.json
      real_estate.json
      healthcare.json
    mod.rs
  sources/         # ALREADY EXISTS
    mod.rs
    mcp.rs
    ui.rs
    knowledge_base.rs
```

### Dependencies

**Already in Workspace:**
```toml
chromiumoxide = "0.7"  # Browser automation
tokio = "1.41"          # Async runtime
axum = "0.7"            # HTTP framework
diesel = "2.1"          # Database
git2 = "0.18"           # Git operations (add if needed)
```

**Frontend (download & serve locally):**
```
monaco-editor@0.45.0    # Code editor
xterm.js@5.3.0          # Terminal (already vendor file)
```

---

## Part VI: Testing Strategy

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
  - Edit in Monaco editor
  - View database schema
  - Create git commit
  - Record browser test

---

## Part VII: Rollout Plan (UPDATED)

### Milestone 0: Security & MCP (Week 0)
- **Day 1-2:** Fix all unsafe `unwrap()` calls
- **Day 3:** Address dependency vulnerabilities
- **Day 4:** Verify CSRF & security headers
- **Day 5:** Integrate MCP panel into Vibe UI

### Milestone 1: Core Editor (Week 1)
- Phase 1 complete (Monaco integration)

### Milestone 2: Database & Git (Week 2)
- Phase 2 complete (Database UI)
- Phase 3 complete (Git Operations)

### Milestone 3: Browser & Workspace (Week 3)
- Phase 4 complete (Browser Automation)
- Phase 5 complete (Multi-File Editing)

### Milestone 4: Terminal & Templates (Week 4)
- Phase 6 complete (Enhanced Terminal)
- Phase 7 complete (CRM Templates)

---

## Part VIII: Success Metrics

### Security Milestones
- ✅ Zero `unwrap()` in production code
- ✅ `cargo audit` passes
- ✅ All endpoints have CSRF + security headers

### Phase 0.5: MCP Integration
- ✅ MCP panel visible in Vibe sidebar
- ✅ Can enable/disable servers
- ✅ Can view available tools
- ✅ Can add new servers

### Phase 1: Code Editor
- Monaco loads < 2 seconds
- 5+ syntax highlighters work
- Multi-file tabs functional
- Auto-save succeeds

### Phase 2: Database UI
- Schema visualizer displays all tables
- Query builder generates valid SQL
- Data grid supports inline edits
- Export functionality works

### Phase 3: Git Operations
- Git status shows changed files
- Diff viewer shows side-by-side
- Commit workflow works
- Branch switching succeeds

### Phase 4: Browser Automation
- Can navigate to any URL
- Element picker captures selectors
- Recording generates valid tests
- Screenshots capture correctly

### Phase 5: Multi-File Workspace
- 10+ files open in tabs
- Split view supports 2-4 panes
- File comparison works
- Project search is fast (< 1s for 100 files)

### Phase 6: Terminal
- Interactive shell works
- Can run vim, top, etc.
- Multiple terminals run simultaneously
- File transfer works

### Phase 7: CRM Templates
- 3+ CRM templates available
- Generation takes < 30 seconds
- Generated CRMs are fully functional
- Industry-specific features work

---

## Conclusion

The BotUI platform has a **powerful backend** capable of generating full applications via LLM. The main gaps are in the **frontend user experience** and **security hardening**.

**Key Insight:**
- The `botserver/src/sources/` infrastructure for MCP is **already complete**
- The Vibe UI exists and is functional
- We need to **connect** them: add an MCP panel to the Vibe sidebar

**Updated Priority Order:**
1. ⚠️ **Security fixes** (Week 0) - Unblock development risk
2. 🔌 **MCP integration** (Week 0.5) - Quick win, leverage existing code
3. 📝 **Code editor** (Week 1) - Core developer tool
4. 🗄️ **Database UI** (Week 2) - Visual data management
5. 🐙 **Git operations** (Week 2) - Version control
6. 🌐 **Browser automation** (Week 3) - Testing & recording
7. 📂 **Multi-file workspace** (Week 3) - Professional editing
8. 🖥️ **Terminal** (Week 4) - Interactive shell
9. 📇 **CRM templates** (Week 4) - Accelerators

Once these phases are complete, VibeCode will match or exceed Claude Code's capabilities while offering:

✅ **Multi-user SaaS deployment**
✅ **Visual app building** (Vibe Builder)
✅ **Enterprise-grade multi-agent orchestration**
✅ **Pure Rust backend** (no Node.js dependency)
✅ **Integrated MCP servers** (extensible tools)
✅ **Integrated browser automation** (chromiumoxide)
✅ **Professional development environment**

**Total Estimated Effort:** 113-141 hours (~3-4 weeks with 1 developer)

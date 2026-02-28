# VibeCode Complete Implementation Roadmap

## Executive Summary

**Current Status:** BotUI's backend is **80% complete** with powerful LLM-driven code generation. The frontend needs professional tools to match Claude Code's capabilities.

**What Works (Backend):**
- ✅ LLM-powered app generation (AppGenerator: 3400+ lines)
- ✅ Multi-agent pipeline (Orchestrator: Plan → Build → Review → Deploy → Monitor)
- ✅ Real-time WebSocket progress
- ✅ Database schema generation
- ✅ File generation (HTML, CSS, JS, BAS)
- ✅ Designer AI (runtime modifications with undo/redo)
- ✅ chromiumoxide dependency ready for browser automation

**What's Missing (Frontend):**
- ❌ Monaco/CodeMirror editor (just textarea now)
- ❌ Database UI (no schema visualizer)
- ❌ Git operations UI
- ❌ Browser automation engine (using Rust + chromiumoxide)
- ❌ Multi-file editing workspace
- ❌ Enhanced terminal

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     USER REQUEST                             │
│              "I want a full CRM system"                      │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              VIBE BUILDER UI                                 │
│  - Agent cards (Mantis #1-4)                                  │
│  - Task nodes visualization                                  │
│  - WebSocket real-time updates                               │
│  - Live chat overlay                                         │
│  - Code editor (Monaco)                    ← Phase 1        │
│  - Browser automation panel                 ← Phase 4        │
│  - Database schema visualizer              ← Phase 2        │
│  - Git operations UI                        ← Phase 3        │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│         BOTSERVER (Rust Backend)                             │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐            │
│  │ Orchestrator│  │AppGenerator│  │Designer AI │            │
│  │ (5 agents)  │  │(LLM-driven)│  │(modifications)│         │
│  └────────────┘  └────────────┘  └────────────┘            │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐            │
│  │  Browser   │  │   Git      │  │  Terminal  │            │
│  │ Automation │  │ Operations │  │  Service   │            │
│  │(chromiumoxide)│ │(git2)     │  │(xterm.js)  │            │
│  └────────────┘  └────────────┘  └────────────┘            │
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

---

## Implementation Phases

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

   ```rust
   pub struct BrowserSession {
       id: String,
       browser: Arc<chromiumoxide::Browser>,
       page: Arc<Mutex<chromiumoxide::Page>>,
       created_at: DateTime<Utc>,
   }

   impl BrowserSession {
       pub async fn new(headless: bool) -> Result<Self>;
       pub async fn navigate(&self, url: &str) -> Result<()>;
       pub async fn click(&self, selector: &str) -> Result<()>;
       pub async fn fill(&self, selector: &str, text: &str) -> Result<()>;
       pub async fn screenshot(&self) -> Result<Vec<u8>>;
       pub async fn execute(&self, script: &str) -> Result<Value>;
   }
   ```

2. **Action Recorder**
   - `botserver/src/browser/recorder.rs`
     - `RecordedAction` - Navigate, Click, Fill, Wait, Assert
     - `ActionRecorder` - Record/stop/export
     - Export as Playwright test

   ```rust
   #[derive(Serialize, Deserialize)]
   pub struct RecordedAction {
       pub timestamp: i64,
       pub action_type: ActionType,
       pub selector: Option<String>,
       pub value: Option<String>,
   }

   impl ActionRecorder {
       pub fn start(&mut self);
       pub fn stop(&mut self) -> Vec<RecordedAction>;
       pub fn export_test_script(&self) -> String;
   }
   ```

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
     ```javascript
     let currentSessionId = null;
     let isRecording = false;
     let recordedActions = [];

     async function initBrowser() {
         const resp = await fetch('/api/browser/session', {
             method: 'POST',
             body: JSON.stringify({ headless: false })
         });
         currentSessionId = (await resp.json()).id;
     }

     async function browserNavigate(url) {
         if (isRecording) {
             recordedActions.push({
                 type: 'navigate',
                 value: url,
                 timestamp: Date.now()
             });
         }
         await executeAction('navigate', { url });
     }

     async function browserClick(selector) {
         if (isRecording) {
             recordedActions.push({
                 type: 'click',
                 selector: selector,
                 timestamp: Date.now()
             });
         }
         await executeAction('click', { selector });
     }

     async function exportTest() {
         const resp = await fetch(`/api/browser/session/${currentSessionId}/record/export`);
         const data = await resp.json();

         // Download test file
         const blob = new Blob([data.script], { type: 'text/javascript' });
         const a = document.createElement('a');
         a.href = URL.createObjectURL(blob);
         a.download = `test-${Date.now()}.spec.js`;
         a.click();
     }
     ```

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

**Usage Example:**
```javascript
// In Vibe UI
openBrowserPanel();
toggleRecording();              // Start recording
browserNavigate('http://localhost:3000/my-crm');
browserClick('#create-btn');
browserFill('#name', 'Test');
browserClick('#save-btn');
toggleRecording();              // Stop recording
exportTest();                   // Download test-123.spec.js
```

**Generated Test Output:**
```javascript
import { test, expect } from '@playwright/test';

test('Recorded test', async ({ page }) => {
  await page.goto('http://localhost:3000/my-crm');
  await page.click('#create-btn');
  await page.fill('#name', 'Test');
  await page.click('#save-btn');
});
```

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

## Technical Implementation Notes

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
  js/
    editor.js
    database.js
    git.js
    browser.js
    terminal.js
    templates.js
  css/
    editor.css
    database.css
    git.css
    browser.css
    terminal.css
    templates.css
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

## Testing Strategy

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

## Rollout Plan

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

## Success Metrics

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

The BotUI platform already has a **powerful backend** capable of generating full applications via LLM. The main gaps are in the **frontend user experience**.

Once these 7 phases are complete, VibeCode will match or exceed Claude Code's capabilities while offering:

✅ **Multi-user SaaS deployment**
✅ **Visual app building** (Vibe Builder)
✅ **Enterprise-grade multi-agent orchestration**
✅ **Pure Rust backend** (no Node.js dependency)
✅ **Integrated browser automation** (chromiumoxide)
✅ **Professional development environment**

The biggest advantage: VibeCode can already **generate working CRMs** via the LLM pipeline. These phases add the **professional UI tools** to make it a complete development environment.

**Total Estimated Effort:** 98-126 hours (~3-4 weeks with 1 developer)

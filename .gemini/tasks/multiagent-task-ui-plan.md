# Multi-Agent Task Management UI — Implementation Plan

> **Unifying `auto_task`, `tasks`, `designer` → Draggable Multi-Agent Windows**

---

## 1. High-Level Vision (from Screenshots)

The user wants a **desktop-like environment** with these elements:

### Layout Components

```
┌──────┬──────────────────────────────────────────────────────┐
│      │  [Tasks ⚙ 👤]  ← Top Left Mini Bar (fixed)         │
│ SIDE │                                                      │
│ BAR  │  ┌─────────────────────┐ ┌────────────────────────┐ │
│      │  │ PRIMARY WINDOW      │ │ SECONDARY WINDOW       │ │
│ (far │  │ "Tasks"             │ │ "Agents & Workspaces"  │ │
│ left)│  │ Tabs:               │ │ (can be minimized)     │ │
│      │  │ - // DASHBOARD      │ │                        │ │
│ /chat│  │ - // TASK #N        │ │ Agent cards, quota     │ │
│/drive│  │                     │ │ monitors, workspace    │ │
│ etc. │  │ PLAN|BUILD|REVIEW|  │ │ assignment             │ │
│      │  │ DEPLOY|MONITOR tabs │ │                        │ │
│      │  │                     │ │                        │ │
│      │  │ Draggable task cards│ │                        │ │
│      │  │ with sub-tasks,     │ │                        │ │
│      │  │ logs, output, chat  │ │                        │ │
│      │  └─────────────────────┘ └────────────────────────┘ │
│      │                                                      │
│      │  ┌───────────────────────────────────────────────┐  │
│      │  │ // Chat  (shared chat at bottom)              │  │
│      │  │ TIP: Describe your project...                 │  │
│      │  └───────────────────────────────────────────────┘  │
│      ├──────────────────────────────────────────────────────┤
│      │  [Taskbar: open windows]       [Clock] [Date]       │
└──────┴──────────────────────────────────────────────────────┘
```

### Key Rules from User Request

1. **Sidebar** → Far left (already exists in `desktop.html`, keep it)
2. **Top-left mini bar** → Fixed bar with "Tasks" label, ⚙ Settings icon, 👤 Account icon. **Remove Mantis logo**.
3. **Where it reads "Mantis" → read "Tasks"** (generic rename throughout)
4. **Primary Window: "Tasks"** → Two tabs:
   - **// DASHBOARD** — Overview with Task #N agent card, DNA info, tokens, activity
   - **// TASK #N** (project view) — PLAN | BUILD | REVIEW | DEPLOY | MONITOR pipeline tabs, with draggable task cards showing sub-tasks, logs, output
5. **Secondary Window: "Agents & Workspaces"** → Shows agent roster, quota monitors, workspace assignments. Can be minimized.
6. **Chat panel** → Shared at bottom of task view, project-scoped
7. **All windows** → Draggable, resizable, use existing `WindowManager`
8. **VibCode integration** → Multi-draggable agents like the designer canvas

---

## 2. Codebase Inventory & Current State

### Frontend (botui/ui/suite)

| File/Dir | Purpose | Lines | Status |
|----------|---------|-------|--------|
| `desktop.html` | Main desktop shell, sidebar, tabs, workspace | 281 | ✅ Keep as shell |
| `js/window-manager.js` | Window open/close/drag/minimize/maximize | 296 | 🔧 Extend |
| `tasks/tasks.html` | Current task list + detail panel | 318 | 🔄 Refactor into new primary window |
| `tasks/tasks.js` | Task JS (3297 lines) | 3297 | 🔄 Refactor (heavy) |
| `tasks/tasks.css` | Task styles (70k+) | ~2400 | 🔄 Refactor/extend |
| `tasks/autotask.html` | AutoTask standalone UI | 484 | 🔄 Merge into primary window |
| `tasks/autotask.js` | AutoTask JS (2201 lines) | 2201 | 🔄 Merge |
| `tasks/autotask.css` | AutoTask styles | ~1200 | 🔄 Merge |
| `tasks/progress-panel.html` | Floating progress panel | 133 | 🔄 Keep as sub-component |
| `tasks/progress-panel.js` | Progress panel JS | ~550 | ✅ Keep |
| `tasks/intents.html` | Intents listing | ~400 | 🔄 Merge |
| `designer.html` | Visual .bas designer (node canvas) | 2718 | 📎 Reference for drag patterns |
| `designer.js` | Designer JS (nodes, connections, drag) | 921 | 📎 Reference for drag |
| `designer.css` | Designer styles | 500 | 📎 Reference |
| `partials/tasks.html` | Alternative tasks partial | 318 | 🔄 Will be replaced by new entry |

### Backend (botserver/src)

| File/Dir | Purpose | Lines | Status |
|----------|---------|-------|--------|
| `auto_task/autotask_api.rs` | AutoTask CRUD + execution API | 2302 | ✅ Keep (API stable) |
| `auto_task/task_types.rs` | AutoTask data types | 423 | ✅ Keep |
| `auto_task/task_manifest.rs` | Manifest tracking (progress tree) | 977 | ✅ Keep |
| `auto_task/app_generator.rs` | App generation from LLM | 3587 | ✅ Keep |
| `auto_task/intent_classifier.rs` | Intent classification | 1200+ | ✅ Keep |
| `auto_task/intent_compiler.rs` | Intent → plan compilation | 900+ | ✅ Keep |
| `auto_task/mod.rs` | Routes + WebSocket handlers | 293 | 🔧 Add new agent/workspace endpoints |
| `tasks/task_api/handlers.rs` | Task CRUD handlers | 393 | 🔧 Extend with agent-aware responses |
| `tasks/task_api/html_renderers.rs` | HTML card rendering | 700+ | 🔧 Update HTML to new design |
| `tasks/types.rs` | Task data types | 223 | 🔧 Add agent fields |
| `tasks/scheduler.rs` | Task scheduler (cron etc.) | 503 | ✅ Keep |
| `designer/workflow_canvas.rs` | Workflow design types | 421 | 📎 Reference |
| `designer/designer_api/` | Designer API handlers | ~200 | 📎 Reference |

---

## 3. Implementation Phases

### Phase 0: Terminology Rename (Mantis → Tasks/Agent)

**Scope**: All UI references
**Effort**: ~30 min

| What | Where | Change |
|------|-------|--------|
| "Mantis #1" | All HTML templates | → "Agent #1" |
| "MANTIS MANAGER" | Task cards | → "AGENT MANAGER" |
| Mantis logo/icon | Top bar, cards | → Remove, use ⚡ or 🤖 icon |
| "mantis" CSS classes | tasks CSS | → Rename to `agent-*` |
| Variable names | tasks.js, autotask.js | → `agent*` where needed |

**Files to modify**:
- `botui/ui/suite/tasks/tasks.html` — template references
- `botui/ui/suite/tasks/tasks.js` — variable names
- `botui/ui/suite/tasks/tasks.css` — class names
- `botui/ui/suite/tasks/autotask.html` — template references
- `botui/ui/suite/tasks/autotask.js` — variable names
- `botserver/src/tasks/task_api/html_renderers.rs` — server-rendered HTML

---

### Phase 1: Top-Left Mini Bar (Fixed)

**Scope**: New component added to `desktop.html`
**Effort**: ~45 min

Create a fixed top-left panel (anchored above sidebar) matching screenshot:

```
┌──────────────────────┐
│  Tasks    ⚙️    👤   │
└──────────────────────┘
```

#### 1.1 New file: `botui/ui/suite/partials/minibar.html`

```html
<div class="gb-minibar" id="gb-minibar">
    <span class="minibar-title">Tasks</span>
    <div class="minibar-actions">
        <button class="minibar-btn" id="btn-open-settings" 
                title="Settings" onclick="openSettingsWindow()">
            <!-- SVG gear icon -->
        </button>
        <button class="minibar-btn" id="btn-open-account" 
                title="Account" onclick="openAccountWindow()">
            <!-- SVG user icon -->
        </button>
    </div>
</div>
```

#### 1.2 CSS additions in `desktop.html <style>` or new `css/minibar.css`

```css
.gb-minibar {
    position: fixed;
    top: 0;
    left: 51px; /* right of sidebar */
    height: 34px;
    display: flex;
    align-items: center;
    padding: 0 12px;
    gap: 8px;
    background: var(--bg-secondary);
    border-bottom: 1px solid var(--border-color);
    z-index: 200;
    font-family: 'Fira Code', monospace;
    font-size: 13px;
    font-weight: 600;
}
.minibar-title { color: var(--text); }
.minibar-actions { display: flex; gap: 6px; }
.minibar-btn {
    width: 28px; height: 28px;
    border: none; background: transparent;
    cursor: pointer; border-radius: 6px;
    display: flex; align-items: center; justify-content: center;
    transition: background 0.15s;
}
.minibar-btn:hover { background: var(--bg-hover); }
.minibar-btn svg { width: 16px; height: 16px; stroke: var(--text-secondary); }
```

#### 1.3 Integration in `desktop.html`

- Add minibar HTML after sidebar, before main-wrapper
- Adjust `.main-wrapper` top padding to account for minibar height

---

### Phase 2: Primary Window — "Tasks" (Dashboard + Project Tabs)

**Scope**: Major refactor of `tasks/` directory
**Effort**: ~4-6 hours

This is the central window. It unifies the old `tasks.html` and `autotask.html` into one coherent window with two tab modes:

#### 2.1 New file: `botui/ui/suite/tasks/task-window.html`

Main entry point loaded by `WindowManager.open('tasks', 'Tasks', html)`.

Structure:

```html
<link rel="stylesheet" href="/suite/tasks/task-window.css" />

<div class="task-window" id="task-window">
    <!-- Tab Bar: DASHBOARD | TASK #N -->
    <div class="task-window-tabs" id="task-window-tabs">
        <button class="tw-tab active" data-tab="dashboard"
                onclick="switchTaskTab('dashboard')">
            // DASHBOARD
        </button>
        <!-- Dynamic task tabs appear here -->
    </div>

    <!-- Tab Content -->
    <div class="task-window-content" id="task-window-content">
        <!-- Dashboard tab (default) -->
        <div class="tw-panel active" id="tw-panel-dashboard">
            <!-- Agent overview cards, stats, recent activity -->
        </div>
    </div>
</div>

<script src="/suite/tasks/task-window.js"></script>
```

#### 2.2 Dashboard Tab Content (`tw-panel-dashboard`)

Based on "Agent #1" screenshot:

```html
<div class="tw-dashboard">
    <!-- Overview section -->
    <section class="agent-overview">
        <div class="agent-card">
            <div class="agent-header">
                <span class="agent-icon">⚡</span>
                <h2 class="agent-name">Agent #1</h2>
                <button class="agent-edit-btn">✏️</button>
            </div>
            <div class="agent-meta">
                <div class="meta-row">
                    <span class="meta-label">Status</span>
                    <span class="meta-value status-active">● Active</span>
                </div>
                <div class="meta-row">
                    <span class="meta-label">DNA</span>
                    <span class="meta-value">
                        <a href="#" class="meta-link">Manage Subscription</a>
                    </span>
                </div>
                <div class="meta-stats">
                    <div class="stat-item">
                        <span class="stat-label">Renewal</span>
                        <span class="stat-value" id="agent-renewal">—</span>
                    </div>
                    <div class="stat-item">
                        <span class="stat-label">Created</span>
                        <span class="stat-value" id="agent-created">—</span>
                    </div>
                    <div class="stat-item">
                        <span class="stat-label">Tokens Used</span>
                        <span class="stat-value" id="agent-tokens">—</span>
                    </div>
                    <div class="stat-item">
                        <span class="stat-label">Tasks Completed</span>
                        <span class="stat-value" id="agent-tasks-done">—</span>
                    </div>
                </div>
            </div>
        </div>
        <!-- Action buttons -->
        <div class="agent-actions">
            <button class="action-btn" onclick="parkAgent()">// PARK</button>
            <button class="action-btn" onclick="cloneAgent()">// CLONE</button>
            <button class="action-btn" onclick="exportAgent()">// EXPORT</button>
            <button class="action-btn disabled">// DELETE</button>
        </div>
    </section>

    <!-- Assigned Job section -->
    <section class="assigned-job" id="assigned-job">
        <h3>Assigned Job</h3>
        <div class="job-card" hx-get="/api/ui/tasks/current-job"
             hx-trigger="load" hx-swap="innerHTML">
            <!-- Loaded dynamically -->
        </div>
    </section>

    <!-- Recent Activity -->
    <section class="recent-activity" id="recent-activity">
        <h3>Recent Activity</h3>
        <div class="activity-list" hx-get="/api/ui/tasks/activity"
             hx-trigger="load, every 15s" hx-swap="innerHTML">
            <!-- Activity items loaded dynamically -->
        </div>
    </section>
</div>
```

#### 2.3 Project Tab Content (Opens when clicking "Open Project")

Based on the multi-agent task cards screenshot with PLAN|BUILD|REVIEW|DEPLOY|MONITOR:

```html
<div class="tw-project" id="tw-project-{project_id}">
    <!-- Top breadcrumb -->
    <div class="project-breadcrumb">
        <span>// DASHBOARD</span> <span>></span>
        <span class="project-name">// {PROJECT_NAME}</span>
    </div>

    <!-- Pipeline Tabs -->
    <div class="pipeline-tabs">
        <button class="pipeline-tab" data-phase="plan">// PLAN</button>
        <button class="pipeline-tab active" data-phase="build">// BUILD</button>
        <button class="pipeline-tab" data-phase="review">// REVIEW</button>
        <button class="pipeline-tab" data-phase="deploy">// DEPLOY</button>
        <button class="pipeline-tab" data-phase="monitor">// MONITOR</button>
    </div>

    <!-- Zoomable Canvas with draggable task cards -->
    <div class="task-canvas" id="task-canvas-{project_id}">
        <div class="canvas-controls">
            <button onclick="zoomIn()">🔍+</button>
            <span class="zoom-level">100%</span>
            <button onclick="zoomOut()">🔍-</button>
        </div>
        <div class="canvas-inner" id="canvas-inner-{project_id}">
            <!-- Draggable task cards rendered here -->
        </div>
    </div>

    <!-- Shared Chat Panel (bottom) -->
    <div class="project-chat" id="project-chat">
        <div class="chat-header">// Chat <button class="chat-download">⬇</button></div>
        <div class="chat-body" id="project-chat-body">
            <div class="chat-tip">
                💚 TIP: Describe your project. The more detail, the better the plan.
            </div>
            <!-- Chat messages -->
        </div>
        <div class="chat-input-area">
            <input type="text" placeholder="Describe what you need..."
                   id="project-chat-input" />
            <button class="chat-send" onclick="sendProjectChat()">Send</button>
        </div>
    </div>
</div>
```

#### 2.4 Draggable Task Cards on Canvas

Each task card (matching the screenshot) is a draggable element:

```html
<div class="task-card draggable" data-task-id="{id}"
     style="left: {x}px; top: {y}px;">
    <div class="task-card-drag-handle">⠿</div>
    <div class="task-card-badge">// TASK</div>

    <h3 class="task-card-title">{title}</h3>
    <div class="task-card-stats">
        <span>{file_count} files</span>
        <span>{duration}</span>
        <span>~{token_count} tokens</span>
    </div>
    <p class="task-card-desc">{description}</p>

    <div class="task-card-status">
        <span class="status-label">Status</span>
        <span class="status-value">● {status}</span>
    </div>

    <!-- Agent Manager section -->
    <div class="task-agent-section">
        <div class="agent-label">// AGENT MANAGER</div>
        <div class="agent-row">
            <span class="agent-dot">●</span>
            <span class="agent-name">Agent #1</span>
            <div class="agent-capabilities">
                <!-- capability icons -->
            </div>
            <span class="agent-level">EVOLVED</span>
        </div>
    </div>

    <!-- Collapsible sections -->
    <details class="task-detail-section">
        <summary>// SUB-TASKS</summary>
        <div class="sub-tasks-content" hx-get="/api/ui/tasks/{id}/subtasks"
             hx-trigger="toggle" hx-swap="innerHTML"></div>
    </details>
    <details class="task-detail-section">
        <summary>// LOGS</summary>
        <div class="logs-content"></div>
    </details>
    <details class="task-detail-section">
        <summary>// OUTPUT</summary>
        <div class="output-content"></div>
    </details>
</div>
```

#### 2.5 New file: `botui/ui/suite/tasks/task-window.js`

Core logic consolidated from `tasks.js` and `autotask.js`:

```javascript
// task-window.js
// Unified Task Window Manager

const TaskWindow = {
    activeTab: 'dashboard',
    openProjects: new Map(),  // projectId -> project data
    wsConnection: null,

    init() { ... },
    switchTab(tabId) { ... },
    openProject(projectId, projectName) { ... },
    closeProject(projectId) { ... },

    // Dashboard
    loadDashboard() { ... },
    loadAgentOverview() { ... },
    loadRecentActivity() { ... },

    // Project Canvas
    initCanvas(projectId) { ... },
    loadTaskCards(projectId) { ... },
    makeCardsDraggable(canvasEl) { ... },  // Uses designer.js patterns
    switchPipelinePhase(phase) { ... },

    // WebSocket
    initWebSocket() { ... },  // Reuses existing WS from tasks.js
    handleProgressMessage(data) { ... },

    // Chat
    initProjectChat(projectId) { ... },
    sendProjectChat() { ... },
};
```

Key functions to port from existing files:
- From `tasks.js`: `initWebSocket()`, `handleWebSocketMessage()`, `renderManifestProgress()`, `buildProgressTreeHTML()`, `startTaskPolling()`
- From `autotask.js`: `handleTaskProgressMessage()`, `onTaskStarted()`, `onTaskProgress()`, `selectIntent()`, `loadIntentDetail()`
- From `designer.js`: `initDragAndDrop()`, `startNodeDrag()`, canvas pan/zoom

#### 2.6 New file: `botui/ui/suite/tasks/task-window.css`

Consolidated and pixel-perfect styles. Key sections:

```css
/* Task Window Container */
.task-window { ... }

/* Tab Bar (DASHBOARD / TASK #N) */
.task-window-tabs { ... }
.tw-tab { ... }
.tw-tab.active { ... }

/* Dashboard */
.tw-dashboard { ... }
.agent-overview { ... }
.agent-card { ... }
.agent-actions { ... }
.assigned-job { ... }
.recent-activity { ... }

/* Project View */
.tw-project { ... }
.project-breadcrumb { ... }
.pipeline-tabs { ... }
.pipeline-tab { ... }

/* Task Canvas (zoomable, pannable) */
.task-canvas { ... }
.canvas-inner { ... }

/* Draggable Task Cards */
.task-card { ... }
.task-card.dragging { ... }
.task-card-badge { ... }
.task-agent-section { ... }

/* Shared Chat */
.project-chat { ... }
```

---

### Phase 3: Secondary Window — "Agents & Workspaces"

**Scope**: New component
**Effort**: ~2-3 hours

Auto-opens alongside the primary Tasks window. Can be minimized.

#### 3.1 New file: `botui/ui/suite/tasks/agents-window.html`

```html
<link rel="stylesheet" href="/suite/tasks/agents-window.css" />

<div class="agents-window" id="agents-window">
    <!-- Header -->
    <div class="aw-header">
        <h3>Agents & Workspaces</h3>
    </div>

    <!-- Agent Cards -->
    <section class="aw-agents" id="aw-agents"
             hx-get="/api/ui/agents/list" hx-trigger="load, every 30s"
             hx-swap="innerHTML">
        <!-- Agent cards loaded dynamically -->
    </section>

    <!-- Workspace List -->
    <section class="aw-workspaces" id="aw-workspaces">
        <h4>Active Workspaces</h4>
        <div class="workspace-list" hx-get="/api/ui/workspaces/list"
             hx-trigger="load" hx-swap="innerHTML">
            <!-- Workspace items -->
        </div>
    </section>

    <!-- Quota Monitor -->
    <section class="aw-quota" id="aw-quota">
        <h4>Quota Monitor</h4>
        <div class="quota-details">
            <div class="quota-row">
                <span>All Models</span>
                <span class="quota-value">90%</span>
                <div class="quota-bar">
                    <div class="quota-fill" style="width: 90%"></div>
                </div>
            </div>
            <div class="quota-stats">
                <span>Runtime: <strong id="aw-runtime">10m 15s</strong></span>
                <span>Token Consumption: <strong id="aw-tokens">13k</strong></span>
            </div>
            <div class="quota-changes">
                <span class="change added">Added <strong>+510</strong></span>
                <span class="change removed">Removed <strong>+510</strong></span>
            </div>
        </div>
    </section>
</div>

<script src="/suite/tasks/agents-window.js"></script>
```

#### 3.2 New file: `botui/ui/suite/tasks/agents-window.js`

```javascript
const AgentsWindow = {
    init() { ... },
    loadAgents() { ... },
    loadWorkspaces() { ... },
    updateQuotaMonitor(data) { ... },
    assignAgentToTask(agentId, taskId) { ... },
};
```

#### 3.3 New file: `botui/ui/suite/tasks/agents-window.css`

Styles matching the secondary window screenshot with agent cards, quota bars, etc.

---

### Phase 4: Window Manager Enhancements

**Scope**: `js/window-manager.js`
**Effort**: ~2 hours

#### 4.1 Add `openPair()` method

Opens primary + secondary windows side by side when Tasks is launched:

```javascript
openPair(primaryId, primaryTitle, primaryHtml, 
         secondaryId, secondaryTitle, secondaryHtml) {
    // Open primary window (left, 60% width)
    this.open(primaryId, primaryTitle, primaryHtml);
    const primaryEl = document.getElementById(`window-${primaryId}`);
    primaryEl.style.left = '0px';
    primaryEl.style.top = '0px';
    primaryEl.style.width = '60%';
    primaryEl.style.height = 'calc(100% - 50px)';

    // Open secondary window (right, 40% width, minimizable)
    this.open(secondaryId, secondaryTitle, secondaryHtml);
    const secondaryEl = document.getElementById(`window-${secondaryId}`);
    secondaryEl.style.left = '60%';
    secondaryEl.style.top = '0px';
    secondaryEl.style.width = '40%';
    secondaryEl.style.height = 'calc(100% - 50px)';
}
```

#### 4.2 Improve `makeResizable()`

Replace CSS `resize: both` with proper resize handles (8-directional):

```javascript
makeResizable(windowEl) {
    const handles = ['n','e','s','w','ne','nw','se','sw'];
    handles.forEach(dir => {
        const handle = document.createElement('div');
        handle.className = `resize-handle resize-${dir}`;
        windowEl.appendChild(handle);
        // Add mousedown handler for each direction
    });
}
```

#### 4.3 Add snap-to-edge behavior

When a window is dragged to the screen edge, snap to fill half:

```javascript
// In onMouseUp:
if (newLeft < 10) snapToLeft(windowEl);
if (newLeft + windowEl.offsetWidth > workspace.offsetWidth - 10) snapToRight(windowEl);
```

#### 4.4 Add `openAsSecondary()` method

Opens a window in minimized-ready state:

```javascript
openAsSecondary(id, title, htmlContent) {
    this.open(id, title, htmlContent);
    // Mark as secondary (can be auto-minimized)
    const windowObj = this.openWindows.find(w => w.id === id);
    windowObj.isSecondary = true;
}
```

---

### Phase 5: Backend API Extensions

**Scope**: `botserver/src/auto_task/` and `botserver/src/tasks/`
**Effort**: ~3 hours

#### 5.1 New Agent Management Endpoints

Add to `botserver/src/auto_task/mod.rs` route configuration:

```rust
// New routes
.route("/api/ui/agents/list", get(list_agents_handler))
.route("/api/ui/agents/:id", get(get_agent_handler))
.route("/api/ui/agents/:id/park", post(park_agent_handler))
.route("/api/ui/agents/:id/clone", post(clone_agent_handler))
.route("/api/ui/agents/:id/export", get(export_agent_handler))
.route("/api/ui/workspaces/list", get(list_workspaces_handler))
.route("/api/ui/tasks/current-job", get(current_job_handler))
.route("/api/ui/tasks/activity", get(recent_activity_handler))
.route("/api/ui/tasks/:id/subtasks", get(task_subtasks_handler))
```

#### 5.2 New file: `botserver/src/auto_task/agent_api.rs`

Agent management handlers:

```rust
pub async fn list_agents_handler(...) -> impl IntoResponse { ... }
pub async fn get_agent_handler(...) -> impl IntoResponse { ... }
pub async fn park_agent_handler(...) -> impl IntoResponse { ... }
pub async fn clone_agent_handler(...) -> impl IntoResponse { ... }
// Returns HTML fragments (HTMX pattern)
```

#### 5.3 Extend `task_types.rs` with Agent concept

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Agent {
    pub id: Uuid,
    pub name: String,
    pub status: AgentStatus,
    pub capabilities: Vec<AgentCapability>,
    pub level: AgentLevel,  // Evolved, etc.
    pub quota: QuotaInfo,
    pub assigned_tasks: Vec<Uuid>,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum AgentStatus { Active, Parked, Cloning }

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum AgentCapability { Code, Design, Data, Web, API, ML }

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum AgentLevel { Basic, Standard, Evolved, Superior }

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QuotaInfo {
    pub model_usage_percent: f64,
    pub runtime_seconds: u64,
    pub tokens_consumed: u64,
    pub items_added: i64,
    pub items_removed: i64,
}
```

#### 5.4 Extend WebSocket for multi-agent updates

In `handle_task_progress_websocket()`, add agent status broadcasts:

```rust
// New message types:
"agent_status_update" -> { agent_id, status, quota }
"workspace_update" -> { workspace_id, agents, tasks }
"project_canvas_update" -> { project_id, task_positions }
```

---

### Phase 6: Desktop Integration

**Scope**: `desktop.html` and auto-open logic
**Effort**: ~1.5 hours

#### 6.1 Modify `desktop.html` Tasks icon click

Instead of loading `tasks.html` into a single window, load the pair:

```javascript
// In desktop.html htmx:afterRequest handler
if (appId === 'tasks') {
    // Fetch both HTML files
    Promise.all([
        fetch('/suite/tasks/task-window.html').then(r => r.text()),
        fetch('/suite/tasks/agents-window.html').then(r => r.text())
    ]).then(([taskHtml, agentsHtml]) => {
        window.wm.openPair(
            'tasks', 'Tasks', taskHtml,
            'agents', 'Agents & Workspaces', agentsHtml
        );
    });
    evt.detail.isError = true; // prevent default HTMX swap
}
```

#### 6.2 Add minibar to desktop.html

Insert `minibar.html` partial via HTMX or inline.

#### 6.3 Remove old breadcrumb row

The `tabs-container` in `desktop.html` with "E-COMMERCE APP DEVELOPMENT" breadcrumb was hardcoded for demo; replace with dynamic content managed by the active window.

---

### Phase 7: Polish & Pixel-Perfect Styling

**Scope**: CSS refinement
**Effort**: ~3 hours

#### 7.1 Design System Tokens

Add to `css/theme-sentient.css`:

```css
:root {
    /* Task Card Colors */
    --task-badge-bg: rgba(132, 214, 105, 0.15);
    --task-badge-border: #84d669;
    --task-badge-text: #84d669;

    /* Agent Status Colors */
    --agent-active: #84d669;
    --agent-parked: #f9e2af;
    --agent-evolved: #84d669;

    /* Pipeline Tab Colors */
    --pipeline-active: var(--primary);
    --pipeline-inactive: var(--text-secondary);

    /* Canvas */
    --canvas-grid: rgba(0,0,0,0.03);
    --canvas-card-shadow: 0 2px 12px rgba(0,0,0,0.08);
}
```

#### 7.2 Pixel-Perfect Card Styling

Task cards must match screenshots exactly:
- Monospace font (`Fira Code`) for labels
- `//` prefix on section labels (e.g., `// TASK`, `// SUB-TASKS`)
- Green dot for active status
- Collapsible sections with `▸`/`▾` toggles
- Agent capability icons row (🔧 📝 ↗ ⚙ 🛡 📊)

#### 7.3 Animations

```css
/* Card drag feedback */
.task-card.dragging {
    opacity: 0.85;
    transform: rotate(1deg) scale(1.02);
    box-shadow: 0 8px 30px rgba(0,0,0,0.15);
    z-index: 9999;
}

/* Tab switch */
.tw-panel { transition: opacity 0.2s ease; }
.tw-panel:not(.active) { opacity: 0; position: absolute; pointer-events: none; }

/* Window open */
@keyframes window-open {
    from { transform: scale(0.95); opacity: 0; }
    to { transform: scale(1); opacity: 1; }
}
.window-element { animation: window-open 0.15s ease-out; }
```

---

## 4. File Creation & Modification Summary

### New Files to Create

| # | File | Purpose |
|---|------|---------|
| 1 | `botui/ui/suite/tasks/task-window.html` | Primary unified task window |
| 2 | `botui/ui/suite/tasks/task-window.js` | Primary window logic |
| 3 | `botui/ui/suite/tasks/task-window.css` | Primary window styles |
| 4 | `botui/ui/suite/tasks/agents-window.html` | Secondary agents/workspaces window |
| 5 | `botui/ui/suite/tasks/agents-window.js` | Secondary window logic |
| 6 | `botui/ui/suite/tasks/agents-window.css` | Secondary window styles |
| 7 | `botui/ui/suite/partials/minibar.html` | Top-left mini bar |
| 8 | `botui/ui/suite/css/minibar.css` | Mini bar styles |
| 9 | `botserver/src/auto_task/agent_api.rs` | Agent management API |

### Existing Files to Modify

| # | File | Changes |
|---|------|---------|
| 1 | `botui/ui/suite/desktop.html` | Add minibar, modify Tasks launch logic |
| 2 | `botui/ui/suite/js/window-manager.js` | Add `openPair()`, improve resize, snap |
| 3 | `botui/ui/suite/css/desktop.css` | Minibar layout adjustments |
| 4 | `botserver/src/auto_task/mod.rs` | Add agent routes, export new module |
| 5 | `botserver/src/auto_task/task_types.rs` | Add Agent, QuotaInfo types |
| 6 | `botserver/src/tasks/task_api/html_renderers.rs` | Update rendered HTML (Mantis→Agent) |
| 7 | `botui/ui/suite/css/theme-sentient.css` | Add new design tokens |

### Files to Keep (No Changes)

- `tasks/progress-panel.html` + `.js` + `.css` — reused as sub-component
- `botserver/src/auto_task/autotask_api.rs` — API stable
- `botserver/src/auto_task/app_generator.rs` — No changes needed
- `botserver/src/auto_task/task_manifest.rs` — No changes needed
- `botserver/src/tasks/scheduler.rs` — No changes needed

### Files Eventually Deprecated (Phase 8 cleanup)

- `tasks/autotask.html` → merged into `task-window.html`
- `tasks/autotask.js` → merged into `task-window.js`
- `tasks/autotask.css` → merged into `task-window.css`
- `tasks/tasks.html` → merged into `task-window.html` (keep as partial fallback)
- Original `partials/tasks.html` → replaced by `task-window.html`

---

## 5. Execution Order

```
Phase 0: Terminology Rename (Mantis → Agent/Tasks)        ~30 min
Phase 1: Top-Left Mini Bar                                  ~45 min
Phase 2: Primary Window (task-window.html/js/css)           ~4-6 hrs
  ├─ 2.1: HTML structure
  ├─ 2.2: Dashboard tab
  ├─ 2.3: Project tab with pipeline tabs
  ├─ 2.4: Draggable task cards
  ├─ 2.5: JavaScript consolidation
  └─ 2.6: CSS pixel-perfect styling
Phase 3: Secondary Window (agents-window.html/js/css)       ~2-3 hrs
Phase 4: Window Manager Enhancements                        ~2 hrs
Phase 5: Backend API Extensions                             ~3 hrs
Phase 6: Desktop Integration                                ~1.5 hrs
Phase 7: Polish & Pixel-Perfect                             ~3 hrs

Total estimated: ~17-20 hours
```

---

## 6. Key Design Decisions

1. **Single-window with tabs** vs multi-window for tasks → Using **tabs within a single primary window** (Dashboard / Task #N) matching the screenshots, plus a separate secondary window for agents.

2. **Reuse WindowManager** — All windows still go through the existing WM for consistency with chat/drive/etc.

3. **Drag system from Designer** — Port the `startNodeDrag()` and canvas pan/zoom patterns from `designer.js` for the task card canvas.

4. **HTMX-first** — All data loading uses HTMX fragments from the backend, matching existing patterns in `tasks.html` and `autotask.html`.

5. **WebSocket reuse** — The existing `task_progress_websocket_handler` in `auto_task/mod.rs` is extended with new message types for agent status, not replaced.

6. **Progressive enhancement** — Old `tasks.html` remains functional as a fallback. The new `task-window.html` is the primary entry.

7. **Scoped CSS** — Each new component gets its own CSS file to avoid conflicts with existing 70k+ lines of task styles.

---

## 7. Verification Checklist

- [ ] Sidebar stays on far left
- [ ] Mini bar shows "Tasks ⚙ 👤" at top-left (no Mantis logo)
- [ ] Tasks window opens with Dashboard tab by default
- [ ] Dashboard shows Agent #1 overview (status, tokens, tasks completed)
- [ ] "Open Project" opens project tab with PLAN|BUILD|REVIEW|DEPLOY|MONITOR
- [ ] Task cards are draggable on the canvas
- [ ] Each task card has collapsible SUB-TASKS, LOGS, OUTPUT sections
- [ ] Agent Manager section shows on each task card
- [ ] Secondary "Agents & Workspaces" window opens alongside
- [ ] Secondary window can be minimized
- [ ] Chat panel at bottom of project view
- [ ] All terminology says "Tasks" / "Agent" instead of "Mantis"
- [ ] Monospace `Fira Code` font with `//` prefix styling throughout
- [ ] WebSocket progress updates work in new UI
- [ ] Window drag, resize, minimize, maximize all functional
- [ ] Theme-aware (respects sentient/dark/light themes)

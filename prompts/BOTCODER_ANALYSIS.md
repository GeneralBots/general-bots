# BotCoder Multi-Agent OS - Architecture Analysis

## Executive Summary

Based on analysis of **botserver** (Rust backend), **botui** (Web UI), and **botapp** (Tauri Desktop), we can architect **BotCoder** as a unified multi-agent operating system that leverages the existing Mantis Farm infrastructure while adding code-specific capabilities similar to Claude Code.

---

## Current Architecture Analysis

### 1. BotServer (Rust Backend) - `botserver/src/auto_task/`

#### Multi-Agent Pipeline (The "Mantis Farm")

**File:** `orchestrator.rs` (1147 lines)

The orchestrator implements a **5-stage multi-agent pipeline**:

```
┌─────────────────────────────────────────────────────────────┐
│                    ORCHESTRATOR PIPELINE                     │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  Stage 1: PLAN  ────────►  Mantis #1 (Planner)              │
│    - Analyze user request                                    │
│    - Break down into sub-tasks                               │
│    - Identify tables, pages, tools, schedulers               │
│    - Derive enterprise-grade work breakdown                  │
│                                                               │
│  Stage 2: BUILD  ───────►  Mantis #2 (Builder)              │
│    - Generate application code                               │
│    - Create HTML/CSS/JS files                                │
│    - Define database schema                                  │
│    - Build tools & schedulers                                │
│                                                               │
│  Stage 3: REVIEW  ───────►  Mantis #3 (Reviewer)             │
│    - Validate code quality                                   │
│    - Check HTMX patterns                                     │
│    - Verify security                                         │
│    - Ensure no hardcoded data                                │
│                                                               │
│  Stage 4: DEPLOY  ───────►  Mantis #4 (Deployer)             │
│    - Deploy application                                      │
│    - Verify accessibility                                    │
│    - Confirm static assets loading                           │
│                                                               │
│  Stage 5: MONITOR  ───────►  Mantis #1 (Planner)             │
│    - Setup health monitoring                                 │
│    - Track error rates                                       │
│    - Monitor response times                                  │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

#### Agent Status System

**Agent States:**
- **WILD** - Uninitialized agent
- **BRED** - Agent created and ready
- **EVOLVED** - Agent has completed work successfully
- **WORKING** - Agent actively processing
- **DONE** - Agent finished
- **FAILED** - Agent encountered error

**Agent Roles:**
```rust
pub enum AgentRole {
    Planner,    // Mantis #1 - Architect & Analyst
    Builder,    // Mantis #2 - Code Generator
    Reviewer,   // Mantis #3 - QA & Validation
    Deployer,   // Mantis #4 - Deployment
    Monitor,    // Mantis #1 (reused) - Health checks
}
```

#### Agent Executor (Container-Based)

**File:** `agent_executor.rs` (115 lines)

Provides **containerized execution environment** for agents:

```rust
pub struct AgentExecutor {
    pub state: Arc<AppState>,
    pub session_id: String,
    pub task_id: String,
    container: Option<ContainerSession>,
}
```

**Capabilities:**
- ✅ Spawn containerized terminal sessions
- ✅ Execute shell commands
- ✅ Broadcast terminal output via WebSocket
- ✅ Browser automation integration (chromiumoxide)
- ✅ Real-time progress updates

**WebSocket Events:**
- `terminal_output` - stdout/stderr from agent
- `thought_process` - agent reasoning/thinking
- `step_progress` - pipeline stage progress (1/5, 2/5...)
- `browser_ready` - browser automation available
- `agent_thought` - agent-specific thoughts
- `agent_activity` - structured activity logs
- `task_node` - task breakdown visualization

#### Intent Classification

**File:** `intent_classifier.rs`

Classifies user requests into types:
- **APP_CREATE** - Generate new application
- **APP_MODIFY** - Modify existing app
- **CODE_REVIEW** - Review code
- **DEBUG** - Debug issues
- **DEPLOY** - Deploy application
- **ANALYZE** - Analyze codebase

**Entity Extraction:**
- Tables (database schema)
- Features (UI components)
- Pages (routes/views)
- Tools (business logic)
- Schedulers (background jobs)

#### App Generator

**File:** `app_generator.rs` (3400+ lines)

**LLM-powered code generation:**
- Generates HTMX applications
- Creates database schemas
- Builds REST API endpoints
- Generates BASIC tools
- Creates scheduled jobs
- Produces E2E tests

**Output:**
```rust
pub struct GeneratedApp {
    pub name: String,
    pub description: String,
    pub tables: Vec<TableDefinition>,
    pub pages: Vec<GeneratedPage>,
    pub tools: Vec<GeneratedTool>,
    pub schedulers: Vec<SchedulerDefinition>,
}
```

#### Designer AI

**File:** `designer_ai.rs`

Runtime code modifications with:
- Undo/redo support
- Real-time UI editing
- Visual layout changes
- Style modifications

#### Safety Layer

**File:** `safety_layer.rs`

- Constraint checking
- Simulation before execution
- Audit trail
- Approval workflows

---

### 2. BotUI (Web Interface) - `botui/ui/suite/`

#### Vibe Builder UI

**File:** `partials/vibe.html` (47KB)

**Components:**
1. **Pipeline Tabs** - Plan/Build/Review/Deploy/Monitor stages
2. **Agents Sidebar** - Mantis #1-4 status cards
3. **Workspaces List** - Project management
4. **Canvas Area** - Task node visualization
5. **Chat Overlay** - Real-time communication with agents

**Agent Cards Display:**
```html
<div class="as-agent-card" data-agent-id="1">
    <div class="as-agent-header">
        <span class="as-status-dot green"></span>
        <span class="as-agent-name">Mantis #1</span>
    </div>
    <div class="as-agent-body">
        <span class="as-agent-icons">👀 ⚙️ ⚡</span>
        <span class="as-badge badge-evolved">EVOLVED</span>
    </div>
</div>
```

**WebSocket Integration:**
```javascript
// Connect to task progress stream
const ws = new WebSocket(`ws://localhost:8080/ws/task-progress/${taskId}`);

ws.onmessage = (event) => {
    const data = JSON.parse(event.data);
    handleTaskProgress(data);
};

// Event types handled:
// - pipeline_start
// - pipeline_complete
// - step_progress (1/5, 2/5, ...)
// - agent_thought
// - agent_activity
// - task_node
// - terminal_output
// - manifest_update
```

**Real-time Updates:**
- Agent status changes (WILD → BRED → WORKING → EVOLVED)
- Task node visualization (plan breakdown)
- Terminal output streaming
- Progress indicators
- File generation notifications

#### Other UI Components

- `chat.html` - Chat interface for agent interaction
- `editor-inner.html` - Code editor (currently textarea, needs Monaco)
- `explorer-inner.html` - File browser
- `settings.html` - Configuration
- `tasks.html` - Task management
- `desktop-inner.html` - Desktop integration

---

### 3. BotApp (Desktop) - `botapp/src/`

**Tauri-based desktop application** with:
- System tray integration
- Service monitoring
- File system access
- Desktop sync (rclone)
- Native notifications

**Main Features:**
```rust
// Desktop service monitoring
pub struct ServiceMonitor {
    services: HashMap<String, ServiceStatus>,
}

// Tray management
pub struct TrayManager {
    mode: RunningMode,  // Server | Desktop | Client
}

// Drive integration
mod drive {
    list_files()
    upload_file()
    create_folder()
}

// Sync integration
mod sync {
    get_sync_status()
    start_sync()
    configure_remote()
}
```

---

## BotCoder Multi-Agent OS Architecture

### Vision

**BotCoder** = **Vibe Builder** + **Code-Specific Agents** + **Professional Tools**

Create a complete development environment that:
1. Uses the existing Mantis Farm infrastructure
2. Adds specialized coding agents (similar to Claude Code)
3. Provides professional editor experience (Monaco, terminal, git, etc.)
4. Supports both internal (GB Platform) and external (Forgejo) deployment

---

## Proposed BotCoder Agent Ecosystem

### Core Mantis Farm (Keep Existing)

```
Mantis #1: Planner & Orchestrator  ───►  Already exists in botserver
Mantis #2: Code Generator          ───►  Already exists (AppGenerator)
Mantis #3: Reviewer & Validator     ───►  Already exists
Mantis #4: Deployer                 ───►  Already exists
```

### New Specialized Agents (Add to BotCoder)

```
┌─────────────────────────────────────────────────────────────────┐
│                   BOTCODER AGENTS                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Mantis #5: Editor Agent           ───►  File operations        │
│    - Multi-file editing                                         │
│    - Syntax awareness                                           │
│    - Refactoring support                                        │
│    - Code completion                                            │
│                                                                 │
│  Mantis #6: Database Agent         ───►  Schema operations      │
│    - Query optimization                                         │
│    - Migration management                                       │
│    - Data visualization                                        │
│    - Index suggestions                                          │
│                                                                 │
│  Mantis #7: Git Agent               ───►  Version control       │
│    - Commit analysis                                           │
│    - Branch management                                         │
│    - Conflict resolution                                       │
│    - Code archaeology                                           │
│                                                                 │
│  Mantis #8: Test Agent              ───►  Quality assurance     │
│    - Test generation                                           │
│    - Coverage analysis                                         │
│    - E2E testing (chromiumoxide)                                │
│    - Performance profiling                                     │
│                                                                 │
│  Mantis #9: Browser Agent            ───►  Web automation        │
│    - Page recording                                            │
│    - Element inspection                                        │
│    - Performance monitoring                                     │
│    - SEO checking                                               │
│                                                                 │
│  Mantis #10: Terminal Agent         ───►  Command execution     │
│    - Shell command execution                                    │
│    - Build system integration                                   │
│    - Package management                                         │
│    - Docker orchestration                                       │
│                                                                 │
│  Mantis #11: Documentation Agent    ───►  Docs & comments       │
│    - Auto-generate docs                                        │
│    - Comment quality check                                      │
│    - README generation                                          │
│    - API documentation                                         │
│                                                                 │
│  Mantis #12: Security Agent          ───►  Security auditing     │
│    - Vulnerability scanning                                     │
│    - Dependency analysis                                        │
│    - Secret detection                                           │
│    - OWASP compliance                                           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## BotCoder Architecture

### Backend (Rust)

```
botserver/src/
├── auto_task/              # EXISTING - Mantis Farm
│   ├── orchestrator.rs      # Keep - Multi-agent pipeline
│   ├── agent_executor.rs   # Keep - Container execution
│   ├── app_generator.rs    # Keep - LLM code gen
│   ├── designer_ai.rs      # Keep - Runtime edits
│   ├── intent_classifier.rs # Keep - Request classification
│   └── safety_layer.rs     # Keep - Constraint checking
│
├── botcoder/               # NEW - BotCoder-specific agents
│   ├── mod.rs
│   ├── editor_agent.rs     # Mantis #5 - File operations
│   ├── database_agent.rs   # Mantis #6 - Schema ops
│   ├── git_agent.rs        # Mantis #7 - Version control
│   ├── test_agent.rs       # Mantis #8 - Testing
│   ├── browser_agent.rs    # Mantis #9 - Web automation
│   ├── terminal_agent.rs   # Mantis #10 - Command exec
│   ├── docs_agent.rs       # Mantis #11 - Documentation
│   └── security_agent.rs   # Mantis #12 - Security
│
├── deployment/             # NEW - From vibe.md Phase 0
│   ├── mod.rs              # DeploymentRouter
│   ├── forgejo.rs          # ForgejoClient
│   ├── api.rs              # Deployment endpoints
│   └── templates.rs        # CI/CD workflows
│
├── api/                    # EXTEND - Add BotCoder APIs
│   ├── editor.rs           # Monaco integration
│   ├── database.rs         # DB UI backend
│   ├── git.rs              # Git operations
│   ├── browser.rs          # Browser automation
│   └── terminal.rs         # WebSocket terminals
│
└── browser/                # NEW - From vibe.md Phase 4
    ├── mod.rs              # BrowserSession
    ├── recorder.rs         # ActionRecorder
    ├── validator.rs        # TestValidator
    └── api.rs              # HTTP endpoints
```

### Frontend (Web + Desktop)

```
botui/ui/suite/
├── partials/
│   ├── vibe.html                    # EXISTING - Agent sidebar
│   ├── vibe-deployment.html         # NEW - Deployment modal
│   ├── editor.html                  # NEW - Monaco editor
│   ├── database.html                # NEW - Schema visualizer
│   ├── git-status.html              # NEW - Git operations
│   ├── git-diff.html                # NEW - Diff viewer
│   ├── browser-controls.html        # NEW - Browser automation
│   └── terminal.html                # NEW - Enhanced terminal
│
├── js/
│   ├── vibe.js                      # EXISTING - Vibe logic
│   ├── deployment.js                # NEW - Deployment handler
│   ├── editor.js                    # NEW - Monaco integration
│   ├── database.js                  # NEW - DB visualization
│   ├── git.js                       # NEW - Git operations
│   ├── browser.js                   # NEW - Browser automation
│   └── terminal.js                  # NEW - Terminal (xterm.js)
│
└── css/
    ├── agents-sidebar.css            # EXISTING - Mantis cards
    ├── deployment.css               # NEW - Deployment styles
    ├── editor.css                    # NEW - Editor styles
    ├── database.css                  # NEW - DB UI styles
    └── terminal.css                  # NEW - Terminal styles
```

---

## Integration Strategy

### Option 1: BotCoder as Separate Repository (Recommended)

```
gb/
├── botserver/     # Existing - Backend services
├── botui/         # Existing - Web UI
├── botapp/        # Existing - Desktop app
└── botcoder/      # NEW - Multi-agent IDE
    ├── Cargo.toml
    ├── src/
    │   ├── main.rs
    │   ├── agents/         # BotCoder agents
    │   ├── editor/         # Editor integration
    │   └── workspace/      # Workspace management
    └── ui/
        ├── src/
        │   ├── components/  # React/Vue components
        │   ├── pages/       # IDE pages
        │   └── lib/
        └── index.html
```

**Pros:**
- Clean separation of concerns
- Independent release cycle
- Can be deployed standalone
- Easier to maintain

**Cons:**
- Duplicate some botserver code
- Need to share common libs

### Option 2: BotCoder as Module in BotServer

```
botserver/src/
├── auto_task/      # Existing Mantis Farm
└── botcoder/       # New BotCoder module
    ├── mod.rs
    ├── agents/
    ├── editor/
    └── workspace/
```

**Pros:**
- Share existing infrastructure
- Single deployment
- Unified WebSocket channels

**Cons:**
- Tighter coupling
- Larger monolith

### Recommendation: **Option 1 (Separate Repo)**

But share common libraries via a `botlib` crate:

```
gb/
├── botlib/         # Shared utilities
│   ├── src/
│   │   ├── agents/     # Agent traits
│   │   ├── llm/        # LLM clients
│   │   └── websocket/  # WebSocket utils
│   └── Cargo.toml
│
├── botserver/      # Uses botlib
├── botui/          # Uses botlib
├── botapp/         # Uses botlib
└── botcoder/       # Uses botlib ← NEW
```

---

## BotCoder Features vs Vibe Builder

### Vibe Builder (Existing)
- ✅ Multi-agent pipeline (Mantis #1-4)
- ✅ App generation (HTMX apps)
- ✅ WebSocket real-time updates
- ✅ Agent status visualization
- ✅ Task breakdown
- ✅ Deployment (internal GB platform)

### BotCoder (Add)
- 📝 **Monaco Editor** - Professional code editing
- 🗄️ **Database UI** - Schema visualization
- 🐙 **Git Operations** - Version control UI
- 🌐 **Browser Automation** - Testing & recording
- 📂 **Multi-File Workspace** - Tab management
- 🖥️ **Enhanced Terminal** - xterm.js integration
- 🚀 **Dual Deployment** - Internal + Forgejo
- 🔒 **Security Scanning** - Vulnerability detection
- 📚 **Auto-Documentation** - Generate docs
- 🧪 **E2E Testing** - chromiumoxide integration

---

## BotCoder Multi-Agent Workflow Example

### User Request: "Create a CRM with contacts and deals"

```
1. CLASSIFY
   └─ Intent: APP_CREATE
   └─ Entities: { tables: [contacts, deals], features: [Contact Manager, Deal Pipeline] }

2. PLAN (Mantis #1 - Planner)
   ├─ Break down into 12 sub-tasks
   ├─ Create task nodes
   └─ Estimate: 45 files, 98k tokens, 2.5 hours

3. BUILD (Mantis #2 - Builder)
   ├─ Generate HTML/CSS/JS files
   ├─ Create database schema
   ├─ Build REST API endpoints
   └─ Output: /apps/my-crm/

4. CODE REVIEW (Mantis #3 - Reviewer)
   ├─ Check HTMX patterns
   ├─ Verify security
   ├─ Validate error handling
   └─ Status: PASSED

5. OPTIMIZE (Mantis #5 - Editor Agent) ← NEW
   ├─ Analyze code structure
   ├─ Suggest refactorings
   ├─ Apply safe optimizations
   └─ Generate PR

6. TEST (Mantis #8 - Test Agent) ← NEW
   ├─ Generate unit tests
   ├─ Create E2E tests (chromiumoxide)
   ├─ Measure coverage
   └─ Status: 87% coverage

7. SECURITY CHECK (Mantis #12 - Security Agent) ← NEW
   ├─ Scan vulnerabilities
   ├─ Check dependencies
   ├─ Detect secrets
   └─ Status: 0 issues found

8. DEPLOY (Mantis #4 - Deployer)
   ├─ Choose deployment target
   │  ├─ Internal GB Platform ← Selected
   │  └─ External Forgejo (optional)
   ├─ Deploy to /apps/my-crm/
   └─ Verify accessibility

9. DOCUMENT (Mantis #11 - Documentation Agent) ← NEW
   ├─ Generate README.md
   ├─ Create API docs
   ├─ Add code comments
   └─ Output: /docs/

10. MONITOR (Mantis #1 - Planner)
    ├─ Setup uptime monitoring
    ├─ Track error rates
    ├─ Monitor response times
    └─ Status: ACTIVE
```

---

## Technical Implementation Plan

### Phase 1: Core BotCoder Infrastructure (Week 1)

**Tasks:**
1. Create `botcoder/` repository structure
2. Implement `botlib` shared crate
3. Add Mantis #5-12 agent stubs
4. Extend WebSocket protocol for new agents
5. Update orchestrator to support 12 agents

**Deliverables:**
- ✅ BotCoder repo initialized
- ✅ Agent trait system defined
- ✅ WebSocket events extended
- ✅ Orchestrator handles 12-agent pipeline

### Phase 2: Editor & Database UI (Week 2)

**Tasks:**
1. Integrate Monaco Editor (replace textarea)
2. Build database schema visualizer
3. Add query builder UI
4. Implement Mantis #5 (Editor Agent)
5. Implement Mantis #6 (Database Agent)

**Deliverables:**
- ✅ Monaco loads with syntax highlighting
- ✅ ER diagram shows tables/relationships
- ✅ Query builder generates SQL
- ✅ Editor agent can refactor code
- ✅ Database agent optimizes queries

### Phase 3: Git & Browser Automation (Week 3)

**Tasks:**
1. Build git operations UI
2. Implement diff viewer
3. Add browser automation panel (chromiumoxide)
4. Implement Mantis #7 (Git Agent)
5. Implement Mantis #9 (Browser Agent)

**Deliverables:**
- ✅ Git status shows changes
- ✅ Diff viewer displays side-by-side
- ✅ Browser automation records actions
- ✅ Git agent manages branches
- ✅ Browser agent generates Playwright tests

### Phase 4: Testing, Security & Docs (Week 4)

**Tasks:**
1. Implement test generation
2. Add security scanning
3. Build documentation generator
4. Implement Mantis #8 (Test Agent)
5. Implement Mantis #12 (Security Agent)
6. Implement Mantis #11 (Docs Agent)

**Deliverables:**
- ✅ Test agent generates coverage reports
- ✅ Security agent scans vulnerabilities
- ✅ Docs agent generates README
- ✅ E2E tests run via chromiumoxide

### Phase 5: Deployment Integration (Week 5)

**Tasks:**
1. Implement deployment router (from vibe.md Phase 0)
2. Add Forgejo integration
3. Build deployment UI
4. Integrate with existing Mantis #4 (Deployer)

**Deliverables:**
- ✅ Can deploy internally to /apps/
- ✅ Can deploy externally to Forgejo
- ✅ CI/CD pipelines auto-generated
- ✅ Deployment choice in UI

---

## Success Metrics

### Agent Performance
- ⚡ Pipeline completes in < 2 minutes
- 🎯 95%+ task success rate
- 🔄 < 5% agent failures requiring retry
- 📊 Real-time progress updates < 100ms latency

### Code Quality
- ✅ 80%+ test coverage
- 🔒 0 critical vulnerabilities
- 📝 100% documented public APIs
- 🚀 < 30s deployment time

### User Experience
- 💬 Natural language → working app
- 🎨 Beautiful UI by default
- 🔧 Professional tools (Monaco, terminal, git)
- 📱 Works on desktop + web

---

## Comparison: BotCoder vs Claude Code

| Feature | BotCoder | Claude Code |
|---------|----------|-------------|
| Multi-agent pipeline | ✅ 12 specialized agents | ❌ Single agent |
| Visual agent status | ✅ Real-time Mantis cards | ❌ No agent visibility |
| App generation | ✅ Full-stack (HTMX + DB) | ✅ Code generation only |
| Database UI | ✅ Schema visualizer | ❌ No DB tools |
| Git operations | ✅ Dedicated agent (Mantis #7) | ✅ Git integration |
| Browser automation | ✅ chromiumoxide + Mantis #9 | ✅ Playwright support |
| Deployment options | ✅ Dual (Internal + Forgejo) | ❌ No deployment |
| Desktop app | ✅ Tauri (botapp) | ❌ CLI only |
| Multi-user | ✅ SaaS platform | ❌ Single user |
| Visual workspace | ✅ Vibe Builder | ❌ Terminal only |
| Agent reasoning | ✅ Transparent thoughts | ❌ Black box |

---

## Conclusion

**BotCoder** can leverage the existing **Mantis Farm** infrastructure in `botserver` while adding specialized coding agents and professional tools. The architecture is:

1. **Foundation:** Existing orchestrator.rs (1147 lines) - 5-stage pipeline
2. **Extension:** Add 7 new specialized agents (Mantis #5-12)
3. **UI:** Extend vibe.html with editor, database, git, browser panels
4. **Desktop:** Integrate with botapp for native experience
5. **Deployment:** Dual deployment (internal GB Platform + external Forgejo)

**Estimated Effort:** 5 weeks (following vibe.md roadmap)

**Result:** A complete multi-agent development environment that exceeds Claude Code's capabilities while offering visual agent management, dual deployment, and multi-user SaaS architecture.

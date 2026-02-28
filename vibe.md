# VibeCode Complete Implementation Roadmap v3.0
## Dual Deployment: Internal GB Apps + External Forgejo ALM Projects

## Executive Summary

**Current Status:** BotUI's backend is **80% complete** with powerful LLM-driven code generation. The platform must support **two deployment models** and needs professional frontend tools to match Claude Code's capabilities.

**Dual Deployment Strategy:**
1. **Internal GB Apps** - Apps served directly from the GB platform using API endpoints
2. **External Forgejo ALM Projects** - Apps deployed to external Forgejo repositories with CI/CD

**What Works (Backend):**
- ✅ LLM-powered app generation (AppGenerator: 3400+ lines)
- ✅ Multi-agent pipeline (Orchestrator: Plan → Build → Review → Deploy → Monitor)
- ✅ Real-time WebSocket progress
- ✅ Database schema generation
- ✅ File generation (HTML, CSS, JS, BAS)
- ✅ Designer AI (runtime modifications with undo/redo)
- ✅ chromiumoxide dependency ready for browser automation
- ✅ **Forgejo ALM integration** (mTLS, runners, web server on port 3000)
- ✅ **App deployment** (`/apps/{name}` routes, Drive storage)

**What's Missing (Critical Gaps):**

**Deployment Infrastructure (Phase 0 - CRITICAL):**
- ❌ Deployment routing logic (internal vs external)
- ❌ Forgejo project initialization & git push
- ❌ CI/CD pipeline generation for Forgejo projects
- ❌ Deployment UI in Vibe Builder

**Frontend Tools (Phases 1-7):**
- ❌ Monaco/CodeMirror editor (just textarea now)
- ❌ Database UI (no schema visualizer)
- ❌ Git operations UI
- ❌ Browser automation engine UI
- ❌ Multi-file editing workspace
- ❌ Enhanced terminal

---

## Architecture: Dual Deployment Model

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
│  ⚠️ DEPLOYMENT CHOICE (Phase 0):                            │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ 📱 Deploy to GB Platform     🌐 Deploy to Forgejo   │    │
│  │    - Serve from /apps/{name}      - Push to repo     │    │
│  │    - Use GB API                   - CI/CD pipeline   │    │
│  │    - Fast iteration               - Custom domain    │    │
│  │    - Shared resources             - Independent     │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                              │
│  📝 Code Editor (Monaco)        ← Phase 1                   │
│  🗄️ Database Schema Visualizer  ← Phase 2                   │
│  🐙 Git Operations UI           ← Phase 3                   │
│  🌐 Browser Automation Panel    ← Phase 4                   │
│  📂 Multi-File Workspace        ← Phase 5                   │
│  🖥️ Enhanced Terminal           ← Phase 6                   │
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

# PART I: Deployment Infrastructure (Phase 0 - CRITICAL)

## Current State Analysis

**Existing Infrastructure:**
```rust
// Forgejo ALM is already configured:
botserver/src/security/mutual_tls.rs:150
  - configure_forgejo_mtls() - mTLS setup for Forgejo

botserver/src/core/package_manager/installer.rs
  - forgejo binary installer
  - forgejo-runner integration
  - ALM_URL environment variable
  - Port 3000 for Forgejo web UI

botserver/src/basic/keywords/create_site.rs
  - CREATE SITE keyword for app generation
  - Stores to Drive: apps/{alias}
  - Serves from: /apps/{alias}

botserver/src/basic/keywords/app_server.rs
  - Suite JS file serving
  - Vendor file routing
```

**Missing Components:**
1. ❌ Deployment routing logic (internal vs external choice)
2. ❌ Forgejo repository initialization API
3. ❌ Git push to Forgejo repositories
4. ❌ CI/CD pipeline template generation
5. ❌ Forgejo Actions workflow builder
6. ❌ Custom domain configuration for external projects

---

## Phase 0.1: Deployment Router (P0 - CRITICAL)

**Goal:** Create routing logic to deploy apps internally or to Forgejo

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
    pub fn new(
        forgejo_url: String,
        forgejo_token: Option<String>,
        internal_base_path: PathBuf,
    ) -> Self {
        Self {
            forgejo_url,
            forgejo_token,
            internal_base_path,
        }
    }

    /// Route deployment based on target type
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

    /// Deploy internally to GB platform
    async fn deploy_internal(
        &self,
        route: String,
        app: GeneratedApp,
    ) -> Result<DeploymentResult, DeploymentError> {
        // 1. Store files in Drive
        // 2. Register route in app router
        // 3. Create API endpoints
        // 4. Return deployment URL
        todo!()
    }

    /// Deploy externally to Forgejo
    async fn deploy_external(
        &self,
        repo_url: &str,
        app: GeneratedApp,
    ) -> Result<DeploymentResult, DeploymentError> {
        // 1. Initialize git repo
        // 2. Add Forgejo remote
        // 3. Push generated files
        // 4. Create CI/CD workflow
        // 5. Trigger build
        todo!()
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeploymentResult {
    pub url: String,
    pub deployment_type: String,
    pub status: DeploymentStatus,
    pub metadata: serde_json::Value,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DeploymentStatus {
    Pending,
    Building,
    Deployed,
    Failed,
}

#[derive(Debug)]
pub enum DeploymentError {
    InternalDeploymentError(String),
    ForgejoError(String),
    GitError(String),
    CiCdError(String),
}
```

**Estimated Effort:** 12-16 hours

---

## Phase 0.2: Forgejo Integration (P0 - CRITICAL)

**Goal:** Initialize repositories and push code to Forgejo

**File:** `botserver/src/deployment/forgejo.rs`

```rust
use git2::{Repository, Oid};
use serde::{Deserialize, Serialize};

pub struct ForgejoClient {
    base_url: String,
    token: String,
    client: reqwest::Client,
}

impl ForgejoClient {
    pub fn new(base_url: String, token: String) -> Self {
        Self {
            base_url,
            token,
            client: reqwest::Client::new(),
        }
    }

    /// Create a new repository in Forgejo
    pub async fn create_repository(
        &self,
        name: &str,
        description: &str,
        private: bool,
    ) -> Result<ForgejoRepo, ForgejoError> {
        let url = format!("{}/api/v1/user/repos", self.base_url);

        let payload = CreateRepoRequest {
            name: name.to_string(),
            description: description.to_string(),
            private,
            auto_init: true,
            gitignores: Some("Node,React,Vite".to_string()),
            license: Some("MIT".to_string()),
            readme: Some("Default".to_string()),
        };

        let response = self
            .client
            .post(&url)
            .header("Authorization", format!("token {}", self.token))
            .json(&payload)
            .send()
            .await
            .map_err(|e| ForgejoError::HttpError(e.to_string()))?;

        if response.status().is_success() {
            let repo: ForgejoRepo = response
                .json()
                .await
                .map_err(|e| ForgejoError::JsonError(e.to_string()))?;
            Ok(repo)
        } else {
            Err(ForgejoError::ApiError(
                response.status().to_string(),
            ))
        }
    }

    /// Push generated app to Forgejo repository
    pub async fn push_app(
        &self,
        repo_url: &str,
        app: &GeneratedApp,
        branch: &str,
    ) -> Result<String, ForgejoError> {
        // 1. Initialize local git repo
        let repo = Repository::init(app.temp_dir()?)?;

        // 2. Add all files
        let mut index = repo.index()?;
        for file in &app.files {
            index.add_path(PathBuf::from(&file.path))?;
        }
        index.write()?;

        // 3. Create commit
        let tree_id = index.write_tree()?;
        let tree = repo.find_tree(tree_id)?;

        let sig = repo.signature()?;
        let oid = repo.commit(
            Some(&format!("refs/heads/{}", branch)),
            &sig,
            &sig,
            &format!("Initial commit: {}", app.description),
            &tree,
            &[],
        )?;

        // 4. Add Forgejo remote
        let mut remote = repo.remote(
            "origin",
            &format!(
                "{}",
                repo_url.replace("https://", &format!("https://{}@", self.token))
            ),
        )?;

        // 5. Push to Forgejo
        remote.push(&[format!("refs/heads/{}", branch)], None)?;

        Ok(oid.to_string())
    }

    /// Create CI/CD workflow for the app
    pub async fn create_cicd_workflow(
        &self,
        repo_url: &str,
        app_type: AppType,
        build_config: BuildConfig,
    ) -> Result<(), ForgejoError> {
        let workflow = match app_type {
            AppType::Htmx => self.generate_htmx_workflow(build_config),
            AppType::React => self.generate_react_workflow(build_config),
            AppType::Vue => self.generate_vue_workflow(build_config),
        };

        // Create .forgejo/workflows/deploy.yml
        // Commit and push
        todo!()
    }

    fn generate_htmx_workflow(&self, config: BuildConfig) -> String {
        r#"
name: Deploy HTMX App

on:
  push:
    branches: [main, develop]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '20'

      - name: Install dependencies
        run: npm ci

      - name: Build
        run: npm run build

      - name: Deploy to server
        run: |
          # Add deployment commands here
          echo "Deploying to production..."
"#
        .to_string()
    }

    fn generate_react_workflow(&self, config: BuildConfig) -> String {
        // Generate React/Vite CI/CD workflow
        todo!()
    }

    fn generate_vue_workflow(&self, config: BuildConfig) -> String {
        // Generate Vue CI/CD workflow
        todo!()
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ForgejoRepo {
    pub id: u64,
    pub name: String,
    pub full_name: String,
    pub clone_url: String,
    pub html_url: String,
}

#[derive(Debug, Serialize)]
struct CreateRepoRequest {
    name: String,
    description: String,
    private: bool,
    auto_init: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    gitignores: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    license: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    readme: Option<String>,
}

#[derive(Debug, Clone, Copy)]
pub enum AppType {
    Htmx,
    React,
    Vue,
}

#[derive(Debug, Clone)]
pub struct BuildConfig {
    pub node_version: String,
    pub build_command: String,
    pub output_directory: String,
}

#[derive(Debug)]
pub enum ForgejoError {
    HttpError(String),
    JsonError(String),
    ApiError(String),
    GitError(String),
}
```

**API Endpoints:**
```rust
// botserver/src/deployment/api.rs

use axum::{
    extract::State,
    response::Json,
    routing::{get, post},
    Router, Json as ResponseJson,
};

use crate::core::shared::state::AppState;

pub fn configure_deployment_routes() -> Router<Arc<AppState>> {
    Router::new()
        // Get deployment targets (internal vs external)
        .route("/api/deployment/targets", get(get_deployment_targets))

        // Deploy app
        .route("/api/deployment/deploy", post(deploy_app))

        // Get deployment status
        .route("/api/deployment/status/:id", get(get_deployment_status))

        // Forgejo repositories
        .route("/api/deployment/forgejo/repos", get(list_forgejo_repos))
        .route("/api/deployment/forgejo/create-repo", post(create_forgejo_repo))

        // CI/CD workflows
        .route("/api/deployment/forgejo/workflows", get(list_workflows))
        .route("/api/deployment/forgejo/workflows/create", post(create_workflow))
}

pub async fn get_deployment_targets(
    State(_state): State<Arc<AppState>>,
) -> Json<serde_json::Value> {
    Json(serde_json::json!({
        "targets": [
            {
                "id": "internal",
                "name": "GB Platform",
                "description": "Deploy to the GB platform with shared resources",
                "features": [
                    "Fast deployment",
                    "Shared authentication",
                    "Shared database",
                    "API integration",
                    "Instant scaling"
                ],
                "icon": "📱"
            },
            {
                "id": "external",
                "name": "Forgejo ALM",
                "description": "Deploy to an external Forgejo repository with CI/CD",
                "features": [
                    "Independent deployment",
                    "Custom domain",
                    "Version control",
                    "CI/CD pipelines",
                    "Separate infrastructure"
                ],
                "icon": "🌐"
            }
        ]
    }))
}

pub async fn deploy_app(
    State(state): State<Arc<AppState>>,
    ResponseJson(payload): ResponseJson<DeploymentRequest>,
) -> Result<Json<DeploymentResult>, DeploymentError> {
    let router = state.deployment_router.clone();

    let config = DeploymentConfig {
        app_name: payload.app_name,
        target: payload.target,
        environment: payload.environment.unwrap_or(DeploymentEnvironment::Production),
    };

    let generated_app = generate_app_from_manifest(&payload.manifest).await?;

    let result = router.deploy(config, generated_app).await?;

    Ok(Json(result))
}

#[derive(Debug, Deserialize)]
pub struct DeploymentRequest {
    pub app_name: String,
    pub target: DeploymentTarget,
    pub environment: Option<DeploymentEnvironment>,
    pub manifest: serde_json::Value,
}
```

**Estimated Effort:** 20-24 hours

---

## Phase 0.3: Deployment UI in Vibe (P0 - CRITICAL)

**Goal:** Add deployment choice UI to Vibe Builder

**File:** `botui/ui/suite/partials/vibe-deployment.html`

```html
<!-- Deployment Choice Modal -->
<div class="deployment-modal" id="deploymentModal" style="display:none;">
    <div class="deployment-modal-backdrop" onclick="closeDeploymentModal()"></div>
    <div class="deployment-modal-content">
        <div class="deployment-modal-header">
            <h2>Choose Deployment Target</h2>
            <button class="close-btn" onclick="closeDeploymentModal()">&times;</button>
        </div>

        <div class="deployment-targets">
            <!-- Internal GB Platform -->
            <div class="deployment-target-card" onclick="selectDeploymentTarget('internal')">
                <div class="target-icon">📱</div>
                <div class="target-info">
                    <h3>GB Platform</h3>
                    <p>Deploy directly to the GB platform with shared resources</p>
                    <ul class="target-features">
                        <li>✓ Fast deployment</li>
                        <li>✓ Shared authentication</li>
                        <li>✓ Shared database</li>
                        <li>✓ API integration</li>
                        <li>✓ Instant scaling</li>
                    </ul>
                </div>
                <div class="target-status">Recommended for quick prototypes</div>
            </div>

            <!-- External Forgejo -->
            <div class="deployment-target-card" onclick="selectDeploymentTarget('external')">
                <div class="target-icon">🌐</div>
                <div class="target-info">
                    <h3>Forgejo ALM</h3>
                    <p>Deploy to an external Forgejo repository with full CI/CD</p>
                    <ul class="target-features">
                        <li>✓ Independent deployment</li>
                        <li>✓ Custom domain</li>
                        <li>✓ Version control</li>
                        <li>✓ CI/CD pipelines</li>
                        <li>✓ Separate infrastructure</li>
                    </ul>
                </div>
                <div class="target-status">Best for production apps</div>
            </div>
        </div>

        <!-- Forgejo Configuration (shown when external selected) -->
        <div id="forgejoConfig" class="forgejo-config" style="display:none;">
            <h3>Forgejo Configuration</h3>
            <form id="forgejoConfigForm">
                <div class="form-group">
                    <label>Repository Name</label>
                    <input type="text" id="repoName" placeholder="my-crm-app" required />
                </div>
                <div class="form-group">
                    <label>Custom Domain (Optional)</label>
                    <input type="text" id="customDomain" placeholder="crm.example.com" />
                </div>
                <div class="form-group">
                    <label>
                        <input type="checkbox" id="ciCdEnabled" checked />
                        Enable CI/CD Pipeline
                    </label>
                </div>
                <div class="form-group">
                    <label>Build Environment</label>
                    <select id="buildEnv">
                        <option value="production">Production</option>
                        <option value="staging">Staging</option>
                        <option value="development">Development</option>
                    </select>
                </div>
            </form>
        </div>

        <!-- Internal Configuration (shown when internal selected) -->
        <div id="internalConfig" class="internal-config" style="display:none;">
            <h3>Internal Deployment Configuration</h3>
            <form id="internalConfigForm">
                <div class="form-group">
                    <label>App Route</label>
                    <input type="text" id="appRoute" placeholder="/apps/my-crm" required />
                </div>
                <div class="form-group">
                    <label>
                        <input type="checkbox" id="sharedDb" checked />
                        Use Shared Database
                    </label>
                </div>
                <div class="form-group">
                    <label>
                        <input type="checkbox" id="sharedAuth" checked />
                        Use GB Authentication
                    </label>
                </div>
            </form>
        </div>

        <div class="deployment-actions">
            <button class="btn-cancel" onclick="closeDeploymentModal()">Cancel</button>
            <button class="btn-deploy" onclick="confirmDeployment()">Deploy App</button>
        </div>
    </div>
</div>

<style>
.deployment-modal {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    z-index: 1000;
    display: flex;
    align-items: center;
    justify-content: center;
}

.deployment-modal-backdrop {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.6);
    backdrop-filter: blur(4px);
}

.deployment-modal-content {
    position: relative;
    background: var(--surface, #fff);
    border-radius: 16px;
    box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
    max-width: 800px;
    width: 90%;
    max-height: 90vh;
    overflow-y: auto;
    padding: 32px;
}

.deployment-modal-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 24px;
    padding-bottom: 16px;
    border-bottom: 1px solid var(--border);
}

.deployment-modal-header h2 {
    margin: 0;
    font-size: 24px;
    font-weight: 700;
    color: var(--text);
}

.close-btn {
    background: none;
    border: none;
    font-size: 32px;
    color: var(--text-muted);
    cursor: pointer;
    padding: 0;
    width: 32px;
    height: 32px;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 8px;
    transition: background 0.15s;
}

.close-btn:hover {
    background: var(--surface-hover);
}

.deployment-targets {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
    gap: 16px;
    margin-bottom: 24px;
}

.deployment-target-card {
    border: 2px solid var(--border);
    border-radius: 12px;
    padding: 24px;
    cursor: pointer;
    transition: all 0.2s;
}

.deployment-target-card:hover {
    border-color: var(--accent);
    box-shadow: 0 4px 12px rgba(132, 214, 105, 0.2);
    transform: translateY(-2px);
}

.deployment-target-card.selected {
    border-color: var(--accent);
    background: rgba(132, 214, 105, 0.05);
}

.target-icon {
    font-size: 48px;
    margin-bottom: 12px;
}

.target-info h3 {
    margin: 0 0 8px 0;
    font-size: 18px;
    font-weight: 600;
    color: var(--text);
}

.target-info p {
    margin: 0 0 12px 0;
    font-size: 14px;
    color: var(--text-muted);
    line-height: 1.5;
}

.target-features {
    list-style: none;
    padding: 0;
    margin: 0;
}

.target-features li {
    padding: 4px 0;
    font-size: 13px;
    color: var(--text);
}

.target-status {
    margin-top: 12px;
    padding: 6px 12px;
    background: var(--surface-hover);
    border-radius: 6px;
    font-size: 12px;
    font-weight: 500;
    text-align: center;
}

.forgejo-config,
.internal-config {
    padding: 24px;
    background: var(--surface-hover);
    border-radius: 12px;
    margin-bottom: 24px;
}

.form-group {
    margin-bottom: 16px;
}

.form-group label {
    display: block;
    margin-bottom: 6px;
    font-weight: 500;
    font-size: 14px;
    color: var(--text);
}

.form-group input[type="text"],
.form-group select {
    width: 100%;
    padding: 10px 14px;
    border: 1px solid var(--border);
    border-radius: 8px;
    font-size: 14px;
    transition: border-color 0.15s;
}

.form-group input:focus,
.form-group select:focus {
    outline: none;
    border-color: var(--accent);
}

.deployment-actions {
    display: flex;
    justify-content: flex-end;
    gap: 12px;
}

.btn-cancel {
    padding: 10px 24px;
    border: 1px solid var(--border);
    border-radius: 8px;
    background: transparent;
    font-size: 14px;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.15s;
}

.btn-cancel:hover {
    background: var(--surface-hover);
}

.btn-deploy {
    padding: 10px 24px;
    border: none;
    border-radius: 8px;
    background: var(--accent);
    color: var(--bg, #fff);
    font-size: 14px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.15s;
}

.btn-deploy:hover {
    background: var(--accent-hover);
    transform: translateY(-1px);
    box-shadow: 0 4px 12px rgba(132, 214, 105, 0.3);
}
</style>

<script>
let selectedTarget = null;

function openDeploymentModal() {
    document.getElementById('deploymentModal').style.display = 'flex';
    selectedTarget = null;
    document.querySelectorAll('.deployment-target-card').forEach(card => {
        card.classList.remove('selected');
    });
    document.getElementById('forgejoConfig').style.display = 'none';
    document.getElementById('internalConfig').style.display = 'none';
}

function closeDeploymentModal() {
    document.getElementById('deploymentModal').style.display = 'none';
}

function selectDeploymentTarget(target) {
    selectedTarget = target;
    document.querySelectorAll('.deployment-target-card').forEach(card => {
        card.classList.remove('selected');
    });
    event.currentTarget.classList.add('selected');

    if (target === 'external') {
        document.getElementById('forgejoConfig').style.display = 'block';
        document.getElementById('internalConfig').style.display = 'none';
    } else {
        document.getElementById('forgejoConfig').style.display = 'none';
        document.getElementById('internalConfig').style.display = 'block';
    }
}

async function confirmDeployment() {
    if (!selectedTarget) {
        alert('Please select a deployment target');
        return;
    }

    const manifest = getCurrentManifest(); // Get from Vibe canvas

    let payload = {
        app_name: document.getElementById('repoName')?.value || document.getElementById('appRoute')?.value?.replace('/apps/', ''),
        target: {},
        environment: document.getElementById('buildEnv')?.value || 'production',
        manifest: manifest
    };

    if (selectedTarget === 'external') {
        payload.target = {
            External: {
                repo_url: `https://forgejo.example.com/${payload.app_name}`,
                custom_domain: document.getElementById('customDomain')?.value || null,
                ci_cd_enabled: document.getElementById('ciCdEnabled')?.checked ?? true
            }
        };
    } else {
        payload.target = {
            Internal: {
                route: document.getElementById('appRoute')?.value || `/apps/${payload.app_name}`,
                shared_resources: true
            }
        };
    }

    try {
        const response = await fetch('/api/deployment/deploy', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });

        const result = await response.json();

        if (result.status === 'Deployed') {
            closeDeploymentModal();
            showDeploymentSuccess(result);
        } else {
            alert('Deployment failed: ' + result.status);
        }
    } catch (e) {
        alert('Deployment error: ' + e.message);
    }
}

function showDeploymentSuccess(result) {
    const modal = document.getElementById('deploymentModal');
    modal.innerHTML = `
        <div class="deployment-success">
            <div class="success-icon">✅</div>
            <h2>Deployment Successful!</h2>
            <p>Your app is now deployed at:</p>
            <a href="${result.url}" target="_blank" class="deployment-url">${result.url}</a>
            <button onclick="location.reload()" class="btn-close">Close</button>
        </div>
    `;
}
</script>
```

**Integration into Vibe:**
```javascript
// In vibe.html, add deployment button to the canvas header:

<div class="vibe-canvas-header">
    <span>// DASHBOARD > // ${currentProject}</span>
    <button class="vibe-deploy-btn" onclick="openDeploymentModal()">
        🚀 Deploy
    </button>
</div>
```

**Estimated Effort:** 8-10 hours

---

# PART II: Frontend Feature Implementation (Phases 1-7)

After deployment infrastructure is in place, continue with the frontend tools:

## Phase 1: Code Editor Integration (P0 - Critical)

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

## Phase 2: Database UI & Schema Visualization (P0 - Critical)

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

## Phase 3: Git Operations UI (P1 - High Priority)

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

**NEW: Forgejo-Specific Operations**
- View Forgejo repository status
- Sync with Forgejo remote
- View CI/CD pipeline status
- Trigger manual builds

**Success Criteria:**
- Git status displays correctly
- Diff viewer shows side-by-side
- Commit workflow works end-to-end
- Branch switching succeeds

**Estimated Effort:** 12-16 hours

---

## Phase 4: Browser Automation Engine (P1 - High Priority)

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

## Phase 5: Multi-File Editing Workspace (P2 - Medium Priority)

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

## Phase 6: Enhanced Terminal (P2 - Medium Priority)

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

## Phase 7: Advanced CRM Templates (P2 - Medium Priority)

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
   - Deploy to /apps/{name} (internal) OR Forgejo (external)

**NEW: Dual Deployment Support**
- Internal deployment templates (use GB APIs)
- External deployment templates (standalone with CI/CD)

**Success Criteria:**
- Can select template from gallery
- Template generates full CRM
- Customization works
- Generated CRM is functional

**Estimated Effort:** 20-24 hours

---

# PART III: Technical Implementation Notes

## Code Quality Standards (per AGENTS.md)

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

## File Organization

**Botserver (Backend):**
```
botserver/src/
  deployment/           # NEW - Deployment infrastructure
    mod.rs              # DeploymentRouter
    forgejo.rs          # ForgejoClient
    api.rs              # Deployment API endpoints
    templates.rs        # CI/CD workflow templates
  api/
    editor.rs
    database.rs
    git.rs              # UPDATED - Add Forgejo git operations
  browser/
    mod.rs              # BrowserSession, BrowserManager
    recorder.rs         # ActionRecorder
    validator.rs        # TestValidator
    api.rs              # HTTP endpoints
    test_generator.rs
  templates/
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

**Botui (Frontend):**
```
botui/ui/suite/
  partials/
    vibe.html                    # UPDATED - Add deploy button
    vibe-deployment.html         # NEW - Deployment modal
    editor.html
    database.html
    git-status.html              # UPDATED - Add Forgejo status
    git-diff.html
    browser-controls.html
    terminal.html
    template-gallery.html
  js/
    deployment.js                # NEW - Deployment logic
    editor.js
    database.js
    git.js                       # UPDATED - Add Forgejo operations
    browser.js
    terminal.js
    templates.js
  css/
    deployment.css               # NEW - Deployment styles
    editor.css
    database.css
    git.css
    browser.css
    terminal.css
    templates.css
```

## Dependencies

**Already in Workspace:**
```toml
[dependencies]
chromiumoxide = "0.7"  # Browser automation
tokio = "1.41"          # Async runtime
axum = "0.7"            # HTTP framework
diesel = "2.1"          # Database
git2 = "0.18"           # Git operations
reqwest = { version = "0.11", features = ["json"] }  # HTTP client
```

**Frontend:**
```
monaco-editor@0.45.0    # Code editor
xterm.js@5.3.0          # Terminal (already vendor file)
```

---

# PART IV: Testing Strategy

## Unit Tests
- All new modules need unit tests
- Test coverage > 80%
- Location: `botserver/src/<module>/tests.rs`

## Integration Tests
- End-to-end workflows
- Location: `bottest/tests/integration/`

## E2E Tests
- Use chromiumoxide (bottest infrastructure)
- Location: `bottest/tests/e2e/`
- Test scenarios:
  - Generate CRM from template
  - Deploy to internal GB Platform
  - Deploy to external Forgejo
  - Edit in Monaco editor
  - View database schema
  - Create git commit
  - Record browser test

---

# PART V: Rollout Plan

## Milestone 0: Deployment Infrastructure (Week 0)
- **Day 1-3:** Phase 0.1 - Deployment Router
- **Day 4-5:** Phase 0.2 - Forgejo Integration
- **Day 6-7:** Phase 0.3 - Deployment UI

**Success Criteria:**
- ✅ Can deploy app internally to /apps/{name}
- ✅ Can deploy app externally to Forgejo
- ✅ CI/CD pipeline auto-generated
- ✅ Deployment choice works in Vibe UI

## Milestone 1: Core Editor (Week 1)
- Phase 1 complete (Monaco integration)

## Milestone 2: Database & Git (Week 2)
- Phase 2 complete (Database UI)
- Phase 3 complete (Git Operations + Forgejo)

## Milestone 3: Browser & Workspace (Week 3)
- Phase 4 complete (Browser Automation)
- Phase 5 complete (Multi-File Editing)

## Milestone 4: Terminal & Templates (Week 4)
- Phase 6 complete (Enhanced Terminal)
- Phase 7 complete (CRM Templates with dual deployment)

---

# PART VI: Success Metrics

## Deployment Infrastructure (Phase 0)
- Internal deployment succeeds in < 30 seconds
- External Forgejo deployment succeeds in < 2 minutes
- CI/CD pipeline auto-generates correctly
- Both deployment models accessible from Vibe UI
- Can switch between internal/external deployment

## Phase 1: Code Editor
- Monaco loads < 2 seconds
- 5+ syntax highlighters work
- Multi-file tabs functional
- Auto-save succeeds

## Phase 2: Database UI
- Schema visualizer displays all tables
- Query builder generates valid SQL
- Data grid supports inline edits
- Export functionality works

## Phase 3: Git Operations
- Git status shows changed files
- Diff viewer shows side-by-side
- Commit workflow works
- Branch switching succeeds

## Phase 4: Browser Automation
- Can navigate to any URL
- Element picker captures selectors
- Recording generates valid tests
- Screenshots capture correctly

## Phase 5: Multi-File Workspace
- 10+ files open in tabs
- Split view supports 2-4 panes
- File comparison works
- Project search is fast (< 1s for 100 files)

## Phase 6: Terminal
- Interactive shell works
- Can run vim, top, etc.
- Multiple terminals run simultaneously
- File transfer works

## Phase 7: CRM Templates
- 3+ CRM templates available
- Generation takes < 30 seconds
- Generated CRMs are fully functional
- Industry-specific features work
- Templates support both deployment models

---

# Conclusion

The **critical foundation** is the **deployment infrastructure (Phase 0)**. The platform must support:

1. **Internal GB Apps** - Quick prototypes using GB APIs and shared resources
2. **External Forgejo Projects** - Production apps with independent infrastructure and CI/CD

**Implementation Priority:**
1. ⚠️ **Phase 0** - Deployment Infrastructure (CRITICAL - Week 0)
   - Phase 0.1: Deployment Router
   - Phase 0.2: Forgejo Integration
   - Phase 0.3: Deployment UI

2. 📝 **Phase 1** - Code Editor (Week 1)

3. 🗄️ **Phase 2** - Database UI (Week 2)

4. 🐙 **Phase 3** - Git Operations + Forgejo (Week 2)

5. 🌐 **Phase 4** - Browser Automation (Week 3)

6. 📂 **Phase 5** - Multi-File Workspace (Week 3)

7. 🖥️ **Phase 6** - Terminal (Week 4)

8. 📇 **Phase 7** - CRM Templates (Week 4)

Once Phase 0 is complete, VibeCode will be able to **deploy apps both internally and externally**, giving users the flexibility to choose the right deployment model for their use case.

**Total Estimated Effort:**
- Phases 1-7: 125-155 hours (~3-4 weeks with 1 developer)
- Phase 0: +40-50 hours
- **Final Total:** 165-205 hours (~4-5 weeks with 1 developer)

The BotUI platform already has a **powerful backend** capable of generating full applications via LLM. These phases add the **deployment infrastructure** and **professional UI tools** to make it a complete development environment with dual deployment capabilities.

Once complete, VibeCode will match or exceed Claude Code's capabilities while offering:

✅ **Multi-user SaaS deployment**
✅ **Visual app building** (Vibe Builder)
✅ **Enterprise-grade multi-agent orchestration**
✅ **Pure Rust backend** (no Node.js dependency)
✅ **Integrated browser automation** (chromiumoxide)
✅ **Dual deployment model** (Internal GB Platform + External Forgejo ALM)
✅ **Professional development environment**

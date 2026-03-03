# BotCoder Hybrid Architecture v2.0
## CLI + Optional Multi-Agent Facade (BYOK vs BotServer)

## Executive Summary

**BotCoder** exists as a **terminal-based AI coding agent** with real-time streaming and tool execution. This document outlines how to extend it into a **hybrid CLI/multi-agent OS** that can:

1. **Work standalone (BYOK)** - Direct LLM access, local execution
2. **Use botserver facade** - Leverage Mantis Farm agents when available
3. **Switch dynamically** - Fall back to local if botserver unavailable

---

## Current BotCoder Architecture

### Existing CLI Implementation (`/home/rodriguez/src/pgm/botcoder`)

**Dependencies:**
```toml
tokio = "1.42"          # Async runtime
reqwest = "0.12"        # HTTP client
ratatui = "0.29"        # TUI framework
crossterm = "0.29"      # Terminal handling
futures = "0.3"         # Async utilities
regex = "1.10"          # Pattern matching
```

**Core Features:**
- ✅ Real-time streaming LLM responses
- ✅ Tool execution (read_file, execute_command, write_file)
- ✅ Delta format parsing (git-style diffs)
- ✅ TPM rate limiting
- ✅ Conversation history management
- ✅ Animated TUI with ratatui

**Tool Support:**
```rust
// Currently supported tools
fn execute_tool(tool: &str, param: &str, project_root: &str) -> String {
    match tool {
        "read_file" => read_file(param),
        "execute_command" => execute_command(param, project_root),
        "write_file" => write_file(param),
        "list_files" => list_files(param, project_root),
        _ => format!("Unknown tool: {}", tool),
    }
}
```

**LLM Integration:**
```rust
// Direct Azure OpenAI client
mod llm {
    pub struct AzureOpenAIClient {
        endpoint: String,
        api_key: String,
        deployment: String,
    }

    impl LLMProvider for AzureOpenAIClient {
        async fn generate(&self, prompt: &str, params: &serde_json::Value)
            -> Result<String, Box<dyn std::error::Error>>;
    }
}
```

---

## Proposed Hybrid Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    BOTCODER HYBRID MODE                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              BOTCODER CLI (main.rs)                      │  │
│  │  - TUI interface (ratatui)                               │  │
│  │  - Tool execution                                        │  │
│  │  - Delta parsing                                         │  │
│  │  - Rate limiting                                         │  │
│  └──────────────────────────────────────────────────────────┘  │
│                            │                                    │
│                            ▼                                    │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │            LLM PROVIDER TRAIT (abstraction)              │  │
│  └──────────────────────────────────────────────────────────┘  │
│                            │                                    │
│            ┌───────────────┴───────────────┐                  │
│            ▼                               ▼                  │
│  ┌─────────────────────┐        ┌─────────────────────┐       │
│  │   DIRECT LLM        │        │  BOTSERVER FACADE    │       │
│  │   (BYOK Mode)       │        │  (Multi-Agent Mode)  │       │
│  │                     │        │                     │       │
│  │ - Azure OpenAI      │        │ - Mantis #1-4       │       │
│  │ - Anthropic         │        │ - Mantis #5-12      │       │
│  │ - OpenAI            │        │ - Orchestrator      │       │
│  │ - Local LLM         │        │ - WebSocket         │       │
│  └─────────────────────┘        └─────────────────────┘       │
│            │                               │                    │
│            │                        (Optional)                 │
│            ▼                               ▼                    │
│  ┌─────────────────────┐        ┌─────────────────────┐       │
│  │  LOCAL EXECUTION    │        │  AGENT EXECUTION    │       │
│  │                     │        │                     │       │
│  │ - File operations   │        │ - Containerized     │       │
│  │ - Command execution │        │ - AgentExecutor     │       │
│  │ - Git operations    │        │ - Browser automation│       │
│  │ - Docker control    │        │ - Test generation   │       │
│  └─────────────────────┘        └─────────────────────┘       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Implementation Plan

### Phase 1: LLM Provider Abstraction (Week 1)

**Goal:** Create trait-based system for multiple LLM backends

**File:** `src/llm/mod.rs`

```rust
use async_trait::async_trait;

/// Unified LLM provider trait
#[async_trait]
pub trait LLMProvider: Send + Sync {
    /// Generate completion with streaming support
    async fn generate_stream(
        &self,
        prompt: &str,
        params: &GenerationParams,
    ) -> Result<StreamResponse, LLMError>;

    /// Generate completion (non-streaming)
    async fn generate(
        &self,
        prompt: &str,
        params: &GenerationParams,
    ) -> Result<String, LLMError>;

    /// Get provider capabilities
    fn capabilities(&self) -> ProviderCapabilities;

    /// Get provider name
    fn name(&self) -> &str;
}

pub struct GenerationParams {
    pub temperature: f32,
    pub max_tokens: u32,
    pub top_p: f32,
    pub tools: Vec<ToolDefinition>,
    pub system_prompt: Option<String>,
}

pub struct StreamResponse {
    pub content_stream: tokio_stream::wrappers::ReceiverStream<String>,
    pub tool_calls: Vec<ToolCall>,
    pub usage: TokenUsage,
}

pub struct ProviderCapabilities {
    pub streaming: bool,
    pub tools: bool,
    pub max_tokens: u32,
    pub supports_vision: bool,
}
```

**Implementations:**

```rust
// src/llm/azure_openai.rs
pub struct AzureOpenAIClient {
    endpoint: String,
    api_key: String,
    deployment: String,
    client: reqwest::Client,
}

#[async_trait]
impl LLMProvider for AzureOpenAIClient {
    async fn generate(&self, prompt: &str, params: &GenerationParams)
        -> Result<String, LLMError> {
        // Existing implementation
    }

    fn capabilities(&self) -> ProviderCapabilities {
        ProviderCapabilities {
            streaming: true,
            tools: true,
            max_tokens: 4096,
            supports_vision: false,
        }
    }

    fn name(&self) -> &str {
        "azure-openai"
    }
}

// src/llm/anthropic.rs
pub struct AnthropicClient {
    api_key: String,
    client: reqwest::Client,
}

#[async_trait]
impl LLMProvider for AnthropicClient {
    async fn generate(&self, prompt: &str, params: &GenerationParams)
        -> Result<String, LLMError> {
        // Anthropic API implementation
    }

    fn capabilities(&self) -> ProviderCapabilities {
        ProviderCapabilities {
            streaming: true,
            tools: true,
            max_tokens: 8192,
            supports_vision: true,
        }
    }

    fn name(&self) -> &str {
        "anthropic"
    }
}

// src/llm/botserver_facade.rs
pub struct BotServerFacade {
    base_url: String,
    api_key: Option<String>,
    client: reqwest::Client,
}

#[async_trait]
impl LLMProvider for BotServerFacade {
    async fn generate(&self, prompt: &str, params: &GenerationParams)
        -> Result<String, LLMError> {
        // Instead of direct LLM call, use botserver's orchestrator
        // 1. Classify intent
        // 2. Execute multi-agent pipeline
        // 3. Return aggregated result
    }

    fn capabilities(&self) -> ProviderCapabilities {
        ProviderCapabilities {
            streaming: true,  // Via WebSocket
            tools: true,      // Via AgentExecutor
            max_tokens: 128000,  // Multi-agent consensus
            supports_vision: true,  // Via Browser Agent
        }
    }

    fn name(&self) -> &str {
        "botserver-mantis-farm"
    }
}
```

**Configuration:**

```rust
// src/config.rs
#[derive(Debug, Clone)]
pub struct BotCoderConfig {
    pub llm_provider: LLMProviderType,
    pub botserver_url: Option<String>,
    pub project_path: PathBuf,
    pub enable_facade: bool,
    pub fallback_to_local: bool,
}

#[derive(Debug, Clone)]
pub enum LLMProviderType {
    AzureOpenAI,
    Anthropic,
    OpenAI,
    LocalLLM,
    BotServerFacade,  // Use Mantis Farm
}

impl BotCoderConfig {
    pub fn from_env() -> Result<Self, ConfigError> {
        let llm_provider = match env::var("LLM_PROVIDER").as_deref() {
            Ok("azure") => LLMProviderType::AzureOpenAI,
            Ok("anthropic") => LLMProviderType::Anthropic,
            Ok("botserver") => LLMProviderType::BotServerFacade,
            _ => LLMProviderType::AzureOpenAI,  // Default
        };

        let botserver_url = env::var("BOTSERVER_URL").ok();
        let enable_facade = env::var("ENABLE_BOTSERVER_FACADE")
            .unwrap_or_else(|_| "false".to_string()) == "true";

        Ok(Self {
            llm_provider,
            botserver_url,
            project_path: env::var("PROJECT_PATH")?.into(),
            enable_facade,
            fallback_to_local: true,
        })
    }
}
```

---

### Phase 2: Multi-Agent Facade Integration (Week 2)

**Goal:** Connect to botserver's Mantis Farm when available

**File:** `src/botserver_client.rs`

```rust
use reqwest::Client;
use serde::{Deserialize, Serialize};

pub struct BotServerClient {
    base_url: String,
    api_key: Option<String>,
    client: Client,
}

impl BotServerClient {
    pub fn new(base_url: String, api_key: Option<String>) -> Self {
        Self {
            base_url,
            api_key,
            client: Client::new(),
        }
    }

    /// Classify intent using botserver's intent classifier
    pub async fn classify_intent(&self, text: &str)
        -> Result<ClassifiedIntent, BotServerError> {
        let url = format!("{}/api/autotask/classify", self.base_url);

        let response = self.client
            .post(&url)
            .json(&serde_json::json!({ "text": text }))
            .header("Authorization", self.api_key.as_ref().map(|k| format!("Bearer {}", k)).unwrap_or_default())
            .send()
            .await?;

        if response.status().is_success() {
            Ok(response.json().await?)
        } else {
            Err(BotServerError::ClassificationFailed(response.text().await?))
        }
    }

    /// Execute multi-agent pipeline
    pub async fn execute_pipeline(&self, classification: &ClassifiedIntent)
        -> Result<OrchestrationResult, BotServerError> {
        let url = format!("{}/api/autotask/execute", self.base_url);

        let response = self.client
            .post(&url)
            .json(classification)
            .header("Authorization", self.api_key.as_ref().map(|k| format!("Bearer {}", k)).unwrap_or_default())
            .send()
            .await?;

        if response.status().is_success() {
            Ok(response.json().await?)
        } else {
            Err(BotServerError::PipelineFailed(response.text().await?))
        }
    }

    /// Subscribe to WebSocket progress updates
    pub async fn subscribe_progress(&self, task_id: &str)
        -> Result<tokio_tungstenite::WebSocketStream<tokio_tungstenite::MaybeTlsStream<tokio::net::TcpStream>>, BotServerError> {
        let ws_url = format!(
            "{}/ws/task-progress/{}",
            self.base_url.replace("http", "ws"),
            task_id
        );

        tokio_tungstenite::connect_async(&ws_url).await
            .map_err(BotServerError::WebSocketError)
    }

    /// Use specialized agents directly
    pub async fn query_agent(&self, agent_id: u8, query: &str)
        -> Result<AgentResponse, BotServerError> {
        match agent_id {
            5 => self.query_editor_agent(query).await,
            6 => self.query_database_agent(query).await,
            7 => self.query_git_agent(query).await,
            8 => self.query_test_agent(query).await,
            9 => self.query_browser_agent(query).await,
            10 => self.query_terminal_agent(query).await,
            11 => self.query_docs_agent(query).await,
            12 => self.query_security_agent(query).await,
            _ => Err(BotServerError::InvalidAgent(agent_id)),
        }
    }

    // Specific agent methods
    async fn query_editor_agent(&self, query: &str)
        -> Result<AgentResponse, BotServerError> {
        // POST /api/botcoder/editor/query
        let url = format!("{}/api/botcoder/editor/query", self.base_url);

        let response = self.client
            .post(&url)
            .json(&serde_json::json!({ "query": query }))
            .send()
            .await?;

        Ok(response.json().await?)
    }

    async fn query_database_agent(&self, query: &str)
        -> Result<AgentResponse, BotServerError> {
        // Query database schema, optimize queries
        let url = format!("{}/api/botcoder/database/query", self.base_url);

        let response = self.client
            .post(&url)
            .json(&serde_json::json!({ "query": query }))
            .send()
            .await?;

        Ok(response.json().await?)
    }

    // ... other agent methods
}

#[derive(Debug, Deserialize)]
pub struct ClassifiedIntent {
    pub intent_type: String,
    pub entities: IntentEntities,
    pub original_text: String,
}

#[derive(Debug, Deserialize)]
pub struct OrchestrationResult {
    pub success: bool,
    pub task_id: String,
    pub stages_completed: u8,
    pub app_url: Option<String>,
    pub message: String,
    pub created_resources: Vec<CreatedResource>,
}

#[derive(Debug, thiserror::Error)]
pub enum BotServerError {
    #[error("Classification failed: {0}")]
    ClassificationFailed(String),

    #[error("Pipeline execution failed: {0}")]
    PipelineFailed(String),

    #[error("WebSocket error: {0}")]
    WebSocketError(#[from] tokio_tungstenite::tungstenite::Error),

    #[error("Invalid agent ID: {0}")]
    InvalidAgent(u8),

    #[error("HTTP error: {0}")]
    HttpError(#[from] reqwest::Error),

    #[error("JSON error: {0}")]
    JsonError(#[from] serde_json::Error),
}
```

---

### Phase 3: Unified Tool Execution (Week 2-3)

**Goal:** Abstract tool execution to work locally or via agents

**File:** `src/tools/mod.rs`

```rust
use async_trait::async_trait;

/// Unified tool execution trait
#[async_trait]
pub trait ToolExecutor: Send + Sync {
    async fn execute(&self, tool: &ToolCall, context: &ExecutionContext)
        -> Result<ToolResult, ToolError>;

    fn supports_tool(&self, tool_name: &str) -> bool;
}

pub struct ToolCall {
    pub name: String,
    pub parameters: serde_json::Value,
    pub agent_id: Option<u8>,  // Which agent should execute
}

pub struct ToolResult {
    pub output: String,
    pub exit_code: i32,
    pub metadata: serde_json::Value,
}

pub struct ExecutionContext {
    pub project_path: PathBuf,
    pub botserver_client: Option<BotServerClient>,
    pub use_local_fallback: bool,
}

/// Local tool executor (existing implementation)
pub struct LocalToolExecutor {
    project_root: PathBuf,
}

#[async_trait]
impl ToolExecutor for LocalToolExecutor {
    async fn execute(&self, tool: &ToolCall, context: &ExecutionContext)
        -> Result<ToolResult, ToolError> {
        match tool.name.as_str() {
            "read_file" => self.read_file(tool.parameters).await,
            "write_file" => self.write_file(tool.parameters).await,
            "execute_command" => self.execute_command(tool.parameters).await,
            "list_files" => self.list_files(tool.parameters).await,
            "git_operation" => self.git_operation(tool.parameters).await,
            _ => Err(ToolError::UnknownTool(tool.name.clone())),
        }
    }

    fn supports_tool(&self, tool_name: &str) -> bool {
        matches!(tool_name,
            "read_file" | "write_file" | "execute_command" |
            "list_files" | "git_operation"
        )
    }
}

/// Agent-based tool executor (via botserver)
pub struct AgentToolExecutor {
    botserver_client: BotServerClient,
}

#[async_trait]
impl ToolExecutor for AgentToolExecutor {
    async fn execute(&self, tool: &ToolCall, context: &ExecutionContext)
        -> Result<ToolResult, ToolError> {
        // Route to appropriate agent
        let agent_id = tool.agent_id.unwrap_or_else(|| {
            self.infer_agent_for_tool(&tool.name)
        });

        match self.botserver_client.query_agent(agent_id, &tool.parameters.to_string()).await {
            Ok(response) => Ok(ToolResult {
                output: response.output,
                exit_code: response.exit_code,
                metadata: response.metadata,
            }),
            Err(e) => {
                // Fallback to local if enabled
                if context.use_local_fallback {
                    warn!("Agent execution failed, falling back to local: {}", e);
                    LocalToolExecutor::new(context.project_path.clone()).execute(tool, context).await?
                } else {
                    Err(ToolError::AgentError(e.to_string()))
                }
            }
        }
    }

    fn supports_tool(&self, tool_name: &str) -> bool {
        matches!(tool_name,
            "database_query" | "schema_visualize" | "git_commit" |
            "test_generate" | "browser_record" | "docs_generate" |
            "security_scan" | "code_refactor" | "optimize_query"
        )
    }

    fn infer_agent_for_tool(&self, tool_name: &str) -> u8 {
        match tool_name {
            "code_refactor" | "syntax_check" => 5,  // Editor Agent
            "database_query" | "schema_visualize" | "optimize_query" => 6,  // Database Agent
            "git_commit" | "git_branch" | "git_merge" => 7,  // Git Agent
            "test_generate" | "coverage_report" => 8,  // Test Agent
            "browser_record" | "page_test" => 9,  // Browser Agent
            "shell_execute" | "docker_build" => 10,  // Terminal Agent
            "docs_generate" | "api_docs" => 11,  // Docs Agent
            "security_scan" | "vulnerability_check" => 12,  // Security Agent
            _ => 2,  // Default to Builder Agent
        }
    }
}
```

---

### Phase 4: Hybrid Execution Loop (Week 3)

**Goal:** Main loop that seamlessly switches between local and agent execution

**File:** `src/main.rs` (modified)

```rust
use llm::LLMProvider;
use tools::{LocalToolExecutor, AgentToolExecutor, ToolExecutor};

struct BotCoder {
    config: BotCoderConfig,
    llm_provider: Box<dyn LLMProvider>,
    local_executor: LocalToolExecutor,
    agent_executor: Option<AgentToolExecutor>,
    botserver_client: Option<BotServerClient>,
}

impl BotCoder {
    pub async fn new(config: BotCoderConfig) -> Result<Self, Box<dyn std::error::Error>> {
        // Initialize LLM provider based on config
        let llm_provider: Box<dyn LLMProvider> = match config.llm_provider {
            LLMProviderType::AzureOpenAI => {
                Box::new(llm::AzureOpenAIClient::new()?)
            }
            LLMProviderType::Anthropic => {
                Box::new(llm::AnthropicClient::new()?)
            }
            LLMProviderType::BotServerFacade => {
                // Will use botserver client
                Box::new(llm::BotServerFacade::new(
                    config.botserver_url.clone().unwrap()
                )?)
            }
            _ => Box::new(llm::AzureOpenAIClient::new()?),
        };

        // Initialize tool executors
        let local_executor = LocalToolExecutor::new(config.project_path.clone());

        let mut agent_executor = None;
        let mut botserver_client = None;

        // Try to connect to botserver if enabled
        if config.enable_facade {
            if let Some(url) = &config.botserver_url {
                match BotServerClient::new(url.clone(), None).health_check().await {
                    Ok(()) => {
                        println!("✓ Connected to botserver at {}", url);
                        let client = BotServerClient::new(url.clone(), None);
                        botserver_client = Some(client.clone());
                        agent_executor = Some(AgentToolExecutor::new(client));
                    }
                    Err(e) => {
                        warn!("Failed to connect to botserver: {}", e);
                        if config.fallback_to_local {
                            println!("⚠ Falling back to local execution");
                        }
                    }
                }
            }
        }

        Ok(Self {
            config,
            llm_provider,
            local_executor,
            agent_executor,
            botserver_client,
        })
    }

    pub async fn run(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        let mut iteration = 0;
        let mut conversation_history: Vec<String> = Vec::new();

        loop {
            iteration += 1;
            println!("=== ITERATION {} ===", iteration);

            // Display execution mode
            if self.agent_executor.is_some() {
                println!("Mode: Multi-Agent (BotServer Facade)");
                println!("Agents Available: Mantis #1-12");
            } else {
                println!("Mode: Local (BYOK)");
            }
            println!();

            // Build context
            let context = self.build_context(&conversation_history);

            // Generate response (streaming)
            let response = match self.llm_provider.generate_stream(&context, &Default::default()).await {
                Ok(r) => r,
                Err(e) => {
                    // Try fallback to local if botserver fails
                    if self.agent_executor.is_some() && self.config.fallback_to_local {
                        warn!("LLM provider failed, trying fallback: {}", e);
                        // Switch to local provider
                        continue;
                    } else {
                        return Err(e.into());
                    }
                }
            };

            // Stream response to TUI
            self.display_streaming_response(response).await?;

            // Extract tools from response
            let tools = self.extract_tools(&full_response);

            // Execute tools (local or agent-based)
            for tool in tools {
                let result = self.execute_tool_hybrid(tool).await?;
                conversation_history.push(format!("Tool: {}\nResult: {}", tool.name, result));
            }

            conversation_history.push(format!("Assistant: {}", full_response));

            // Trim history
            if conversation_history.len() > 20 {
                conversation_history.drain(0..10);
            }
        }
    }

    async fn execute_tool_hybrid(&self, tool: ToolCall) -> Result<ToolResult, ToolError> {
        let context = ExecutionContext {
            project_path: self.config.project_path.clone(),
            botserver_client: self.botserver_client.clone(),
            use_local_fallback: self.config.fallback_to_local,
        };

        // Try agent executor first if available
        if let Some(agent_executor) = &self.agent_executor {
            if agent_executor.supports_tool(&tool.name) {
                println!("🤖 Executing via Mantis Agent: {}", tool.name);
                return agent_executor.execute(&tool, &context).await;
            }
        }

        // Fall back to local executor
        if self.local_executor.supports_tool(&tool.name) {
            println!("🔧 Executing locally: {}", tool.name);
            return self.local_executor.execute(&tool, &context).await;
        }

        Err(ToolError::UnknownTool(tool.name))
    }
}
```

---

## Usage Examples

### Example 1: Local Mode (BYOK)

```bash
# .env configuration
LLM_PROVIDER=azure
PROJECT_PATH=/home/user/myproject
ENABLE_BOTSERVER_FACADE=false
```

```bash
$ botcoder
=== ITERATION 1 ===
Mode: Local (BYOK)
✓ Azure OpenAI connected

> Add authentication to this Rust project

[AI Reasoning...]
I'll add JWT authentication using the `jsonwebtoken` crate.

CHANGE: Cargo.toml
<<<<<<< CURRENT
[dependencies]
tokio = "1.0"
=======
[dependencies]
tokio = "1.0"
jsonwebtoken = "9.0"
=======

[EXECUTE] Tool 1/3: write_file -> Cargo.toml
✓ File updated
```

### Example 2: Multi-Agent Mode (BotServer Facade)

```bash
# .env configuration
LLM_PROVIDER=botserver
BOTSERVER_URL=http://localhost:8080
PROJECT_PATH=/home/user/myproject
ENABLE_BOTSERVER_FACADE=true
FALLBACK_TO_LOCAL=true
```

```bash
$ botcoder
=== ITERATION 1 ===
✓ Connected to botserver at http://localhost:8080
Mode: Multi-Agent (BotServer Facade)
Agents Available: Mantis #1-12

> Create a CRM system with contacts and deals

[CLASSIFY] Intent: APP_CREATE
[PLAN] Mantis #1 breaking down request...
  ✓ 12 sub-tasks identified
  ✓ Estimated: 45 files, 98k tokens, 2.5 hours

[BUILD] Mantis #2 generating code...
  ✓ contacts table schema created
  ✓ deals table schema created
  ✓ Contact Manager page generated
  ✓ Deal Pipeline page generated

[REVIEW] Mantis #3 validating code...
  ✓ HTMX patterns verified
  ✓ Security checks passed
  ✓ 0 vulnerabilities found

[OPTIMIZE] Mantis #5 refactoring...
  ✓ Extracted duplicate code to utils.rs
  ✓ Added error handling wrappers

[TEST] Mantis #8 generating tests...
  ✓ 87% code coverage achieved
  ✓ E2E tests created (chromiumoxide)

[SECURITY] Mantis #12 scanning...
  ✓ 0 critical vulnerabilities
  ✓ All dependencies up to date

[DEPLOY] Mantis #4 deploying...
  Target: Internal GB Platform
  ✓ App deployed to /apps/my-crm/
  ✓ Verify at http://localhost:8080/apps/my-crm/

[DOCUMENT] Mantis #11 generating docs...
  ✓ README.md created
  ✓ API documentation generated

✓ Pipeline complete in 1m 47s
```

### Example 3: Hybrid Mode (Automatic Fallback)

```bash
$ botcoder
=== ITERATION 1 ===
Mode: Multi-Agent (BotServer Facade)
✓ Connected to botserver

> Refactor this function for better performance

[EDITOR] Mantis #5 analyzing code...
⚠ BotServer connection lost

[FALLBACK] Switching to local mode...
[LOCAL] Analyzing with Azure OpenAI...
✓ Refactoring complete
```

---

## Benefits of Hybrid Architecture

### For Users (BYOK)
- ✅ **Privacy** - Code never leaves local machine
- ✅ **Speed** - Direct LLM access, no intermediate hops
- ✅ **Cost Control** - Use your own API keys
- ✅ **Offline Capable** - Works with local LLMs (llama.cpp, Ollama)

### For Users (BotServer Facade)
- ✅ **Multi-Agent Consensus** - 12 specialized agents collaborate
- ✅ **Advanced Capabilities** - Browser automation, security scanning, test generation
- ✅ **Visual Debugging** - Watch agent reasoning in Vibe Builder UI
- ✅ **Enterprise Features** - Team sharing, approval workflows, audit trails

### Seamless Switching
- ✅ **Automatic Fallback** - If botserver unavailable, use local
- ✅ **Tool Routing** - Use agent for complex tasks, local for simple ones
- ✅ **Cost Optimization** - Reserve expensive agents for hard problems
- ✅ **Progressive Enhancement** - Start local, upgrade to multi-agent as needed

---

## Configuration Matrix

| Scenario | LLM Provider | Tools | When to Use |
|----------|--------------|-------|-------------|
| **Local Development** | Azure/Anthropic (Direct) | Local file ops | Privacy-critical code |
| **Enterprise Project** | BotServer Facade | Agent-based | Complex refactoring |
| **Open Source** | Local LLM (Ollama) | Local | No API budget |
| **Learning** | BotServer Facade | Agent-based | Study agent reasoning |
| **CI/CD** | BotServer Facade | Agent-based | Automated testing |
| **Quick Fix** | Azure/Anthropic (Direct) | Local | Fast iteration |
| **Security Audit** | BotServer Facade | Mantis #12 | Comprehensive scan |

---

## Implementation Roadmap

### Week 1: Foundation
- [x] Extract existing LLM client to trait
- [ ] Implement Azure OpenAI provider
- [ ] Implement Anthropic provider
- [ ] Add BotServerFacade provider (stub)

### Week 2: BotServer Integration
- [ ] Implement BotServerClient
- [ ] Add WebSocket progress streaming
- [ ] Implement agent query methods
- [ ] Add health check & fallback logic

### Week 3: Tool Execution
- [ ] Refactor existing tools to trait
- [ ] Implement LocalToolExecutor
- [ ] Implement AgentToolExecutor
- [ ] Add tool routing logic

### Week 4: Hybrid Loop
- [ ] Modify main loop for provider switching
- [ ] Add streaming TUI updates
- [ ] Implement automatic fallback
- [ ] Add mode indicator to UI

### Week 5: Testing & Docs
- [ ] Test all three modes (local, agent, hybrid)
- [ ] Add configuration examples
- [ ] Write migration guide
- [ ] Update README

---

## Conclusion

The **hybrid BotCoder** gives users the best of both worlds:

1. **CLI First** - Fast, local, privacy-focused development
2. **Multi-Agent Power** - On-demand access to 12 specialized agents
3. **Seamless Switching** - Automatic fallback between modes
4. **Progressive Enhancement** - Start simple, scale when needed

**Result:** A coding agent that works offline for quick fixes but can call in a full multi-agent orchestra when facing complex challenges.

**Estimated Effort:** 5 weeks (1 developer)
**Lines of Code:** ~2000 new lines (modular, trait-based)

The BotCoder CLI becomes the **control plane** for the Mantis Farm, offering both direct terminal access and a gateway to the full multi-agent OS when needed.

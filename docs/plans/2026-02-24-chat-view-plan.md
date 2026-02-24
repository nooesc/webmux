# Chat View Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a dual-view system to WebMux — a chat view that parses Claude Code and Codex JSONL logs into a clean conversation UI, alongside the existing terminal view with an instant toggle.

**Architecture:** Backend watches JSONL log files via inotify, parses them into a normalized message format, and streams events over WebSocket. Frontend adds a ChatView component with markdown rendering, collapsible tool cards, and an input bar. Both views share the same tmux session and WebSocket connection.

**Tech Stack:** Rust (notify crate for file watching, serde for JSONL parsing), Vue 3 + TypeScript (marked for markdown, highlight.js for code blocks), Tailwind CSS (GitHub dark theme).

---

### Task 1: Add `notify` crate and create chat_log module skeleton

**Files:**
- Modify: `backend-rust/Cargo.toml`
- Create: `backend-rust/src/chat_log/mod.rs`
- Modify: `backend-rust/src/main.rs`

**Step 1: Add notify dependency to Cargo.toml**

In `backend-rust/Cargo.toml`, add after the `futures` line:

```toml
# File watching (inotify on Linux)
notify = { version = "6.1", features = ["macos_fsevent"] }
```

**Step 2: Create chat_log module skeleton**

Create `backend-rust/src/chat_log/mod.rs`:

```rust
use anyhow::Result;
use chrono::{DateTime, Utc};
use notify::{RecommendedWatcher, RecursiveMode, Watcher, Event, EventKind};
use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};
use tokio::sync::mpsc;
use tracing::{info, warn, error};

/// Normalized content block — shared format for Claude Code and Codex
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum ContentBlock {
    Text { text: String },
    ToolCall {
        name: String,
        summary: String,
        #[serde(skip_serializing_if = "Option::is_none")]
        input: Option<serde_json::Value>,
    },
    ToolResult {
        #[serde(rename = "toolName")]
        tool_name: String,
        summary: String,
        #[serde(skip_serializing_if = "Option::is_none")]
        content: Option<String>,
    },
}

/// Normalized chat message
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ChatMessage {
    pub role: String,
    pub timestamp: Option<DateTime<Utc>>,
    pub blocks: Vec<ContentBlock>,
}

/// Which AI tool is running
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum AiTool {
    Claude,
    Codex,
}

/// Events emitted by the log watcher
#[derive(Debug, Clone)]
pub enum ChatLogEvent {
    History { messages: Vec<ChatMessage>, tool: AiTool },
    NewMessage { message: ChatMessage },
    Error { error: String },
}
```

**Step 3: Register the module in main.rs**

In `backend-rust/src/main.rs`, add `mod chat_log;` alongside the other module declarations.

**Step 4: Verify it compiles**

Run: `cd /home/cyrus/git/personal/webmux/backend-rust && cargo check`
Expected: compiles with no errors (warnings are fine)

**Step 5: Commit**

```bash
git add backend-rust/Cargo.toml backend-rust/src/chat_log/mod.rs backend-rust/src/main.rs
git commit -m "feat: add chat_log module skeleton with normalized types"
```

---

### Task 2: Implement Claude Code JSONL parser

**Files:**
- Create: `backend-rust/src/chat_log/claude_parser.rs`
- Modify: `backend-rust/src/chat_log/mod.rs`

**Step 1: Write parser test fixtures**

The Claude Code JSONL format has lines like:
```json
{"uuid":"abc","parentUuid":"def","timestamp":"2026-02-24T10:00:00Z","type":"user","message":{"role":"user","content":[{"type":"text","text":"fix the auth bug"}]}}
{"uuid":"ghi","parentUuid":"abc","timestamp":"2026-02-24T10:00:05Z","type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"I'll look at the auth module."},{"type":"tool_use","id":"tu1","name":"Read","input":{"file_path":"src/auth.ts"}},{"type":"tool_result","tool_use_id":"tu1","content":"export function auth() {...}"}]}}
```

Also includes `"type":"summary"` lines which should be skipped.

**Step 2: Create claude_parser.rs with tests**

Create `backend-rust/src/chat_log/claude_parser.rs`:

```rust
use super::{ChatMessage, ContentBlock};
use chrono::{DateTime, Utc};
use serde::Deserialize;
use tracing::warn;

/// Raw Claude Code JSONL line structure
#[derive(Debug, Deserialize)]
struct ClaudeLogLine {
    timestamp: Option<DateTime<Utc>>,
    #[serde(rename = "type")]
    line_type: String,
    message: Option<ClaudeMessage>,
}

#[derive(Debug, Deserialize)]
struct ClaudeMessage {
    role: String,
    content: serde_json::Value,
}

/// Parse a single JSONL line from a Claude Code log file.
/// Returns None for lines that aren't user/assistant messages (e.g., summary lines).
pub fn parse_line(line: &str) -> Option<ChatMessage> {
    let line = line.trim();
    if line.is_empty() {
        return None;
    }

    let log_line: ClaudeLogLine = match serde_json::from_str(line) {
        Ok(l) => l,
        Err(e) => {
            warn!("Failed to parse Claude JSONL line: {}", e);
            return None;
        }
    };

    // Only process user and assistant messages
    if log_line.line_type != "user" && log_line.line_type != "assistant" {
        return None;
    }

    let message = log_line.message?;
    let blocks = parse_content_blocks(&message.content);

    if blocks.is_empty() {
        return None;
    }

    Some(ChatMessage {
        role: message.role,
        timestamp: log_line.timestamp,
        blocks,
    })
}

fn parse_content_blocks(content: &serde_json::Value) -> Vec<ContentBlock> {
    let mut blocks = Vec::new();

    // Content can be a string or an array of blocks
    match content {
        serde_json::Value::String(s) => {
            if !s.is_empty() {
                blocks.push(ContentBlock::Text { text: s.clone() });
            }
        }
        serde_json::Value::Array(arr) => {
            for item in arr {
                if let Some(block) = parse_content_block(item) {
                    blocks.push(block);
                }
            }
        }
        _ => {}
    }

    blocks
}

fn parse_content_block(item: &serde_json::Value) -> Option<ContentBlock> {
    let block_type = item.get("type")?.as_str()?;

    match block_type {
        "text" => {
            let text = item.get("text")?.as_str()?.to_string();
            if text.is_empty() {
                return None;
            }
            Some(ContentBlock::Text { text })
        }
        "tool_use" => {
            let name = item.get("name")?.as_str()?.to_string();
            let input = item.get("input").cloned();
            let summary = generate_tool_summary(&name, &input);
            Some(ContentBlock::ToolCall { name, summary, input })
        }
        "tool_result" => {
            let content_val = item.get("content");
            let content = match content_val {
                Some(serde_json::Value::String(s)) => Some(s.clone()),
                Some(serde_json::Value::Array(arr)) => {
                    // tool_result content can be array of {type: "text", text: "..."}
                    let texts: Vec<String> = arr.iter()
                        .filter_map(|v| v.get("text").and_then(|t| t.as_str()).map(|s| s.to_string()))
                        .collect();
                    if texts.is_empty() { None } else { Some(texts.join("\n")) }
                }
                _ => None,
            };
            let tool_use_id = item.get("tool_use_id").and_then(|v| v.as_str()).unwrap_or("");
            let summary = match &content {
                Some(c) => {
                    let line_count = c.lines().count();
                    if line_count > 1 {
                        format!("{} lines", line_count)
                    } else {
                        truncate_str(c, 80)
                    }
                }
                None => "no output".to_string(),
            };
            Some(ContentBlock::ToolResult {
                tool_name: tool_use_id.to_string(),
                summary,
                content,
            })
        }
        _ => None,
    }
}

fn generate_tool_summary(name: &str, input: &Option<serde_json::Value>) -> String {
    let input = match input {
        Some(v) => v,
        None => return name.to_string(),
    };

    match name {
        "Read" => input.get("file_path")
            .and_then(|v| v.as_str())
            .unwrap_or("file")
            .to_string(),
        "Edit" => input.get("file_path")
            .and_then(|v| v.as_str())
            .unwrap_or("file")
            .to_string(),
        "Write" => input.get("file_path")
            .and_then(|v| v.as_str())
            .unwrap_or("file")
            .to_string(),
        "Bash" => input.get("command")
            .and_then(|v| v.as_str())
            .map(|s| truncate_str(s, 60))
            .unwrap_or_else(|| "command".to_string()),
        "Glob" => input.get("pattern")
            .and_then(|v| v.as_str())
            .unwrap_or("pattern")
            .to_string(),
        "Grep" => input.get("pattern")
            .and_then(|v| v.as_str())
            .unwrap_or("pattern")
            .to_string(),
        "Task" => input.get("description")
            .and_then(|v| v.as_str())
            .unwrap_or("subagent")
            .to_string(),
        "WebSearch" => input.get("query")
            .and_then(|v| v.as_str())
            .unwrap_or("search")
            .to_string(),
        _ => name.to_string(),
    }
}

fn truncate_str(s: &str, max: usize) -> String {
    if s.len() <= max {
        s.to_string()
    } else {
        format!("{}...", &s[..max])
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_user_text_message() {
        let line = r#"{"uuid":"abc","parentUuid":null,"timestamp":"2026-02-24T10:00:00Z","type":"user","message":{"role":"user","content":[{"type":"text","text":"fix the auth bug"}]}}"#;
        let msg = parse_line(line).unwrap();
        assert_eq!(msg.role, "user");
        assert_eq!(msg.blocks.len(), 1);
        match &msg.blocks[0] {
            ContentBlock::Text { text } => assert_eq!(text, "fix the auth bug"),
            _ => panic!("Expected Text block"),
        }
    }

    #[test]
    fn test_parse_assistant_with_tool_use() {
        let line = r#"{"uuid":"ghi","parentUuid":"abc","timestamp":"2026-02-24T10:00:05Z","type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Let me read that file."},{"type":"tool_use","id":"tu1","name":"Read","input":{"file_path":"src/auth.ts"}},{"type":"tool_result","tool_use_id":"tu1","content":"export function auth() {}"}]}}"#;
        let msg = parse_line(line).unwrap();
        assert_eq!(msg.role, "assistant");
        assert_eq!(msg.blocks.len(), 3);
        match &msg.blocks[1] {
            ContentBlock::ToolCall { name, summary, .. } => {
                assert_eq!(name, "Read");
                assert_eq!(summary, "src/auth.ts");
            }
            _ => panic!("Expected ToolCall block"),
        }
    }

    #[test]
    fn test_skip_summary_lines() {
        let line = r#"{"uuid":"sum1","parentUuid":null,"timestamp":"2026-02-24T10:00:10Z","type":"summary","message":{"role":"assistant","content":[{"type":"text","text":"Summary of conversation"}]}}"#;
        assert!(parse_line(line).is_none());
    }

    #[test]
    fn test_skip_empty_lines() {
        assert!(parse_line("").is_none());
        assert!(parse_line("  ").is_none());
    }

    #[test]
    fn test_skip_malformed_json() {
        assert!(parse_line("{not valid json}").is_none());
    }

    #[test]
    fn test_bash_tool_summary() {
        let line = r#"{"uuid":"b1","parentUuid":null,"timestamp":"2026-02-24T10:00:00Z","type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"tu1","name":"Bash","input":{"command":"npm test"}}]}}"#;
        let msg = parse_line(line).unwrap();
        match &msg.blocks[0] {
            ContentBlock::ToolCall { name, summary, .. } => {
                assert_eq!(name, "Bash");
                assert_eq!(summary, "npm test");
            }
            _ => panic!("Expected ToolCall"),
        }
    }

    #[test]
    fn test_string_content() {
        // Some Claude Code logs have content as a plain string
        let line = r#"{"uuid":"s1","parentUuid":null,"timestamp":"2026-02-24T10:00:00Z","type":"user","message":{"role":"user","content":"hello world"}}"#;
        let msg = parse_line(line).unwrap();
        assert_eq!(msg.blocks.len(), 1);
        match &msg.blocks[0] {
            ContentBlock::Text { text } => assert_eq!(text, "hello world"),
            _ => panic!("Expected Text block"),
        }
    }
}
```

**Step 3: Register the parser submodule in mod.rs**

Add to top of `backend-rust/src/chat_log/mod.rs`:

```rust
pub mod claude_parser;
```

**Step 4: Run tests**

Run: `cd /home/cyrus/git/personal/webmux/backend-rust && cargo test chat_log`
Expected: all tests pass

**Step 5: Commit**

```bash
git add backend-rust/src/chat_log/
git commit -m "feat: implement Claude Code JSONL parser with tests"
```

---

### Task 3: Implement Codex NDJSON parser

**Files:**
- Create: `backend-rust/src/chat_log/codex_parser.rs`
- Modify: `backend-rust/src/chat_log/mod.rs`

**Step 1: Create codex_parser.rs with tests**

Codex `--json` NDJSON format uses events like:
```json
{"type":"item.completed","item":{"id":"item_1","type":"agent_message","text":"I'll fix this."}}
{"type":"item.completed","item":{"id":"item_2","type":"command_execution","command":"bash -lc npm test","status":"completed","output":"All tests passed"}}
{"type":"item.completed","item":{"id":"item_3","type":"file_change","path":"src/auth.ts","status":"completed"}}
```

Create `backend-rust/src/chat_log/codex_parser.rs`:

```rust
use super::{ChatMessage, ContentBlock};
use serde::Deserialize;
use tracing::warn;

#[derive(Debug, Deserialize)]
struct CodexEvent {
    #[serde(rename = "type")]
    event_type: String,
    #[serde(default)]
    item: Option<CodexItem>,
}

#[derive(Debug, Deserialize)]
struct CodexItem {
    #[serde(rename = "type")]
    item_type: String,
    #[serde(default)]
    text: Option<String>,
    #[serde(default)]
    command: Option<String>,
    #[serde(default)]
    output: Option<String>,
    #[serde(default)]
    path: Option<String>,
    #[serde(default)]
    status: Option<String>,
}

/// Parse a single NDJSON line from Codex --json output.
/// Returns None for non-item-completed events.
pub fn parse_line(line: &str) -> Option<ChatMessage> {
    let line = line.trim();
    if line.is_empty() {
        return None;
    }

    let event: CodexEvent = match serde_json::from_str(line) {
        Ok(e) => e,
        Err(e) => {
            warn!("Failed to parse Codex NDJSON line: {}", e);
            return None;
        }
    };

    // Only process item.completed events
    if event.event_type != "item.completed" {
        return None;
    }

    let item = event.item?;

    match item.item_type.as_str() {
        "agent_message" => {
            let text = item.text.unwrap_or_default();
            if text.is_empty() {
                return None;
            }
            Some(ChatMessage {
                role: "assistant".to_string(),
                timestamp: None,
                blocks: vec![ContentBlock::Text { text }],
            })
        }
        "command_execution" => {
            let command = item.command.unwrap_or_else(|| "command".to_string());
            let output = item.output;
            let summary = truncate_str(&command, 60);

            let mut blocks = vec![ContentBlock::ToolCall {
                name: "Bash".to_string(),
                summary,
                input: Some(serde_json::json!({ "command": command })),
            }];

            if let Some(out) = &output {
                let line_count = out.lines().count();
                let result_summary = if line_count > 1 {
                    format!("{} lines", line_count)
                } else {
                    truncate_str(out, 80)
                };
                blocks.push(ContentBlock::ToolResult {
                    tool_name: "Bash".to_string(),
                    summary: result_summary,
                    content: Some(out.clone()),
                });
            }

            Some(ChatMessage {
                role: "assistant".to_string(),
                timestamp: None,
                blocks,
            })
        }
        "file_change" => {
            let path = item.path.unwrap_or_else(|| "file".to_string());
            Some(ChatMessage {
                role: "assistant".to_string(),
                timestamp: None,
                blocks: vec![ContentBlock::ToolCall {
                    name: "Edit".to_string(),
                    summary: path,
                    input: None,
                }],
            })
        }
        "mcp_tool_call" => {
            let text = item.text.unwrap_or_else(|| "MCP tool call".to_string());
            Some(ChatMessage {
                role: "assistant".to_string(),
                timestamp: None,
                blocks: vec![ContentBlock::ToolCall {
                    name: "MCP".to_string(),
                    summary: truncate_str(&text, 60),
                    input: None,
                }],
            })
        }
        _ => None,
    }
}

fn truncate_str(s: &str, max: usize) -> String {
    if s.len() <= max {
        s.to_string()
    } else {
        format!("{}...", &s[..max])
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_agent_message() {
        let line = r#"{"type":"item.completed","item":{"id":"item_1","type":"agent_message","text":"I'll fix the bug.","status":"completed"}}"#;
        let msg = parse_line(line).unwrap();
        assert_eq!(msg.role, "assistant");
        match &msg.blocks[0] {
            ContentBlock::Text { text } => assert_eq!(text, "I'll fix the bug."),
            _ => panic!("Expected Text block"),
        }
    }

    #[test]
    fn test_parse_command_execution() {
        let line = r#"{"type":"item.completed","item":{"id":"item_2","type":"command_execution","command":"bash -lc npm test","status":"completed","output":"All tests passed"}}"#;
        let msg = parse_line(line).unwrap();
        assert_eq!(msg.blocks.len(), 2);
        match &msg.blocks[0] {
            ContentBlock::ToolCall { name, .. } => assert_eq!(name, "Bash"),
            _ => panic!("Expected ToolCall"),
        }
        match &msg.blocks[1] {
            ContentBlock::ToolResult { content, .. } => {
                assert_eq!(content.as_deref(), Some("All tests passed"));
            }
            _ => panic!("Expected ToolResult"),
        }
    }

    #[test]
    fn test_parse_file_change() {
        let line = r#"{"type":"item.completed","item":{"id":"item_3","type":"file_change","path":"src/auth.ts","status":"completed"}}"#;
        let msg = parse_line(line).unwrap();
        match &msg.blocks[0] {
            ContentBlock::ToolCall { name, summary, .. } => {
                assert_eq!(name, "Edit");
                assert_eq!(summary, "src/auth.ts");
            }
            _ => panic!("Expected ToolCall"),
        }
    }

    #[test]
    fn test_skip_non_completed_events() {
        let line = r#"{"type":"item.started","item":{"id":"item_1","type":"agent_message","text":"","status":"in_progress"}}"#;
        assert!(parse_line(line).is_none());
    }

    #[test]
    fn test_skip_turn_events() {
        let line = r#"{"type":"turn.started"}"#;
        assert!(parse_line(line).is_none());
    }
}
```

**Step 2: Register in mod.rs**

Add to `backend-rust/src/chat_log/mod.rs`:

```rust
pub mod codex_parser;
```

**Step 3: Run tests**

Run: `cd /home/cyrus/git/personal/webmux/backend-rust && cargo test chat_log`
Expected: all tests pass (both claude_parser and codex_parser)

**Step 4: Commit**

```bash
git add backend-rust/src/chat_log/codex_parser.rs backend-rust/src/chat_log/mod.rs
git commit -m "feat: implement Codex NDJSON parser with tests"
```

---

### Task 4: Implement log file detection and watcher

**Files:**
- Create: `backend-rust/src/chat_log/watcher.rs`
- Modify: `backend-rust/src/chat_log/mod.rs`

**Step 1: Create watcher.rs**

This module detects which AI tool is running in a tmux pane, finds the log file, reads history, and watches for new lines.

Create `backend-rust/src/chat_log/watcher.rs`:

```rust
use super::{claude_parser, codex_parser, AiTool, ChatLogEvent, ChatMessage};
use anyhow::{Context, Result};
use notify::{RecommendedWatcher, RecursiveMode, Watcher};
use std::io::{BufRead, BufReader, Seek, SeekFrom};
use std::path::{Path, PathBuf};
use tokio::process::Command;
use tokio::sync::mpsc;
use tracing::{info, warn, error};

/// Detect the AI tool running in a tmux pane and find its log file.
pub async fn detect_log_file(session_name: &str, window_index: u32) -> Result<(PathBuf, AiTool)> {
    // Get the pane PID from tmux
    let pane_target = format!("{}:{}", session_name, window_index);
    let output = Command::new("tmux")
        .args(&["display-message", "-t", &pane_target, "-p", "#{pane_pid}"])
        .output()
        .await
        .context("Failed to get pane PID from tmux")?;

    let pane_pid = String::from_utf8_lossy(&output.stdout).trim().to_string();
    if pane_pid.is_empty() {
        anyhow::bail!("Could not determine pane PID for {}", pane_target);
    }

    // Walk the process tree to find claude or codex
    let (tool, cwd) = detect_ai_process(&pane_pid).await?;

    match tool {
        AiTool::Claude => {
            let log_path = find_claude_log(&cwd).await?;
            Ok((log_path, AiTool::Claude))
        }
        AiTool::Codex => {
            let log_path = find_codex_log(&pane_pid).await?;
            Ok((log_path, AiTool::Codex))
        }
    }
}

async fn detect_ai_process(pane_pid: &str) -> Result<(AiTool, String)> {
    // Use pgrep to find child processes and check for claude or codex
    let output = Command::new("ps")
        .args(&["--ppid", pane_pid, "-o", "comm=,pid=", "--no-headers"])
        .output()
        .await?;

    let ps_output = String::from_utf8_lossy(&output.stdout);

    // Also check deeper children (claude/codex may be grandchildren via shell)
    let deep_output = Command::new("ps")
        .args(&["-e", "--forest", "-o", "pid=,comm=,args="])
        .output()
        .await?;
    let deep_str = String::from_utf8_lossy(&deep_output.stdout);

    // Look for process names in the tree under pane_pid
    let all_children = get_descendant_pids(pane_pid).await?;

    for child_pid in &all_children {
        let comm_output = Command::new("ps")
            .args(&["-p", child_pid, "-o", "comm=,cwd=", "--no-headers"])
            .output()
            .await;

        if let Ok(co) = comm_output {
            let line = String::from_utf8_lossy(&co.stdout);
            let parts: Vec<&str> = line.trim().splitn(2, char::is_whitespace).collect();
            if parts.is_empty() {
                continue;
            }
            let comm = parts[0];

            if comm == "claude" || comm.contains("claude") {
                let cwd = get_process_cwd(child_pid).await.unwrap_or_default();
                return Ok((AiTool::Claude, cwd));
            }

            if comm == "codex" || comm.contains("codex") {
                let cwd = get_process_cwd(child_pid).await.unwrap_or_default();
                return Ok((AiTool::Codex, cwd));
            }
        }
    }

    anyhow::bail!("No AI CLI tool (claude/codex) found in process tree of pane PID {}", pane_pid);
}

async fn get_descendant_pids(parent_pid: &str) -> Result<Vec<String>> {
    let output = Command::new("ps")
        .args(&["--ppid", parent_pid, "-o", "pid=", "--no-headers"])
        .output()
        .await?;

    let mut pids: Vec<String> = String::from_utf8_lossy(&output.stdout)
        .lines()
        .map(|l| l.trim().to_string())
        .filter(|l| !l.is_empty())
        .collect();

    // Recurse one level deeper
    let mut grandchildren = Vec::new();
    for pid in &pids {
        if let Ok(gc) = get_descendant_pids(pid).await {
            grandchildren.extend(gc);
        }
    }
    pids.extend(grandchildren);
    Ok(pids)
}

async fn get_process_cwd(pid: &str) -> Result<String> {
    let link = format!("/proc/{}/cwd", pid);
    let cwd = tokio::fs::read_link(&link).await?;
    Ok(cwd.to_string_lossy().to_string())
}

async fn find_claude_log(cwd: &str) -> Result<PathBuf> {
    // Claude Code stores logs at ~/.claude/projects/<encoded-path>/<session-id>.jsonl
    let home = dirs::home_dir().context("No home directory")?;
    let claude_dir = home.join(".claude").join("projects");

    if !claude_dir.exists() {
        anyhow::bail!("Claude projects directory not found at {:?}", claude_dir);
    }

    // Find the project directory matching the cwd
    // Claude encodes the path by replacing / with - (e.g., -home-cyrus-project)
    let encoded_path = cwd.replace('/', "-");

    let project_dir = claude_dir.join(&encoded_path);
    if !project_dir.exists() {
        anyhow::bail!("Claude project directory not found for cwd: {}", cwd);
    }

    // Find the most recently modified .jsonl file
    let mut newest: Option<(PathBuf, std::time::SystemTime)> = None;
    let mut entries = tokio::fs::read_dir(&project_dir).await?;
    while let Some(entry) = entries.next_entry().await? {
        let path = entry.path();
        if path.extension().and_then(|e| e.to_str()) == Some("jsonl") {
            if let Ok(meta) = entry.metadata().await {
                if let Ok(modified) = meta.modified() {
                    if newest.as_ref().map_or(true, |(_, t)| modified > *t) {
                        newest = Some((path, modified));
                    }
                }
            }
        }
    }

    newest.map(|(p, _)| p).context("No JSONL files found in Claude project directory")
}

async fn find_codex_log(pane_pid: &str) -> Result<PathBuf> {
    // Look for tee'd codex output at /tmp/webmux-codex-*.jsonl
    // Find the one owned by a descendant of pane_pid
    let mut entries = tokio::fs::read_dir("/tmp").await?;
    let mut newest: Option<(PathBuf, std::time::SystemTime)> = None;

    while let Some(entry) = entries.next_entry().await? {
        let path = entry.path();
        let name = path.file_name().and_then(|n| n.to_str()).unwrap_or("");
        if name.starts_with("webmux-codex-") && name.ends_with(".jsonl") {
            if let Ok(meta) = entry.metadata().await {
                if let Ok(modified) = meta.modified() {
                    if newest.as_ref().map_or(true, |(_, t)| modified > *t) {
                        newest = Some((path, modified));
                    }
                }
            }
        }
    }

    newest.map(|(p, _)| p).context(
        "No Codex log file found. Run Codex via: codex --json 2>&1 | tee /tmp/webmux-codex-$$.jsonl"
    )
}

/// Read existing file content and parse into messages, then watch for new lines.
/// Sends events on the provided channel.
pub async fn watch_log_file(
    path: PathBuf,
    tool: AiTool,
    event_tx: mpsc::UnboundedSender<ChatLogEvent>,
) -> Result<()> {
    info!("Watching log file: {:?} (tool: {:?})", path, tool);

    // Read existing content
    let messages = read_existing_messages(&path, &tool).await?;
    event_tx.send(ChatLogEvent::History {
        messages,
        tool: tool.clone(),
    })?;

    // Watch for changes using notify
    let (notify_tx, mut notify_rx) = tokio::sync::mpsc::unbounded_channel();
    let path_clone = path.clone();

    // notify requires sync callback, bridge to async with channel
    let mut watcher = RecommendedWatcher::new(
        move |res: Result<notify::Event, notify::Error>| {
            if let Ok(event) = res {
                let _ = notify_tx.send(event);
            }
        },
        notify::Config::default(),
    )?;

    watcher.watch(path.as_ref(), RecursiveMode::NonRecursive)?;

    // Track file position for incremental reads
    let file = std::fs::File::open(&path)?;
    let mut reader = BufReader::new(file);
    reader.seek(SeekFrom::End(0))?;

    // Process file change events
    loop {
        match notify_rx.recv().await {
            Some(event) => {
                if matches!(event.kind, notify::EventKind::Modify(_)) {
                    // Read new lines from current position
                    let mut line = String::new();
                    while reader.read_line(&mut line).unwrap_or(0) > 0 {
                        let parsed = match tool {
                            AiTool::Claude => claude_parser::parse_line(&line),
                            AiTool::Codex => codex_parser::parse_line(&line),
                        };
                        if let Some(msg) = parsed {
                            let _ = event_tx.send(ChatLogEvent::NewMessage { message: msg });
                        }
                        line.clear();
                    }
                }
            }
            None => break,
        }
    }

    Ok(())
}

async fn read_existing_messages(path: &Path, tool: &AiTool) -> Result<Vec<ChatMessage>> {
    let content = tokio::fs::read_to_string(path).await?;
    let messages: Vec<ChatMessage> = content
        .lines()
        .filter_map(|line| match tool {
            AiTool::Claude => claude_parser::parse_line(line),
            AiTool::Codex => codex_parser::parse_line(line),
        })
        .collect();
    Ok(messages)
}
```

**Step 2: Register in mod.rs**

Add to `backend-rust/src/chat_log/mod.rs`:

```rust
pub mod watcher;
```

**Step 3: Verify it compiles**

Run: `cd /home/cyrus/git/personal/webmux/backend-rust && cargo check`
Expected: compiles

**Step 4: Commit**

```bash
git add backend-rust/src/chat_log/
git commit -m "feat: implement log file detection and inotify watcher"
```

---

### Task 5: Add WebSocket message types for chat log

**Files:**
- Modify: `backend-rust/src/types/mod.rs`
- Modify: `backend-rust/src/websocket/mod.rs`

**Step 1: Add new enum variants to types/mod.rs**

In the `WebSocketMessage` enum (after `GetDotfileTemplates`), add:

```rust
    // Chat log watching
    WatchChatLog {
        #[serde(rename = "sessionName")]
        session_name: String,
        #[serde(rename = "windowIndex")]
        window_index: u32,
    },
    UnwatchChatLog,
```

In the `ServerMessage` enum (after the dotfile variants), add:

```rust
    // Chat log responses
    ChatHistory {
        messages: Vec<crate::chat_log::ChatMessage>,
        tool: Option<crate::chat_log::AiTool>,
    },
    ChatEvent {
        message: crate::chat_log::ChatMessage,
    },
    ChatLogError {
        error: String,
    },
```

**Step 2: Add message handling in websocket/mod.rs**

In the `handle_message` function's match block, add:

```rust
WebSocketMessage::WatchChatLog { session_name, window_index } => {
    info!("Starting chat log watch for {}:{}", session_name, window_index);
    let message_tx = state.message_tx.clone();

    // Cancel any existing watcher
    if let Some(handle) = state.chat_log_handle.take() {
        handle.abort();
    }

    let handle = tokio::spawn(async move {
        match crate::chat_log::watcher::detect_log_file(&session_name, window_index).await {
            Ok((path, tool)) => {
                let (event_tx, mut event_rx) = tokio::sync::mpsc::unbounded_channel();

                // Spawn the file watcher
                let watcher_path = path.clone();
                let watcher_tool = tool.clone();
                tokio::spawn(async move {
                    if let Err(e) = crate::chat_log::watcher::watch_log_file(
                        watcher_path, watcher_tool, event_tx,
                    ).await {
                        error!("Chat log watcher error: {}", e);
                    }
                });

                // Forward events to WebSocket
                while let Some(event) = event_rx.recv().await {
                    let msg = match event {
                        crate::chat_log::ChatLogEvent::History { messages, tool } => {
                            ServerMessage::ChatHistory {
                                messages,
                                tool: Some(tool),
                            }
                        }
                        crate::chat_log::ChatLogEvent::NewMessage { message } => {
                            ServerMessage::ChatEvent { message }
                        }
                        crate::chat_log::ChatLogEvent::Error { error } => {
                            ServerMessage::ChatLogError { error }
                        }
                    };
                    if send_message(&message_tx, msg).await.is_err() {
                        break;
                    }
                }
            }
            Err(e) => {
                let _ = send_message(&message_tx, ServerMessage::ChatLogError {
                    error: e.to_string(),
                }).await;
            }
        }
    });

    state.chat_log_handle = Some(handle);
}
WebSocketMessage::UnwatchChatLog => {
    info!("Stopping chat log watch");
    if let Some(handle) = state.chat_log_handle.take() {
        handle.abort();
    }
}
```

Also add a `chat_log_handle: Option<tokio::task::JoinHandle<()>>` field to the `WsState` struct (or whatever per-client state struct is used in websocket/mod.rs).

**Step 3: Verify it compiles**

Run: `cd /home/cyrus/git/personal/webmux/backend-rust && cargo check`
Expected: compiles

**Step 4: Commit**

```bash
git add backend-rust/src/types/mod.rs backend-rust/src/websocket/mod.rs
git commit -m "feat: add WebSocket message types and handler for chat log"
```

---

### Task 6: Add frontend TypeScript types for chat log

**Files:**
- Modify: `src/types/index.ts`

**Step 1: Add chat log types to src/types/index.ts**

At the end of the file (before the ServerMessage union), add:

```typescript
// Chat log types
export type AiTool = 'claude' | 'codex';

export interface ContentBlock {
  type: 'text' | 'tool_call' | 'tool_result';
}

export interface TextBlock extends ContentBlock {
  type: 'text';
  text: string;
}

export interface ToolCallBlock extends ContentBlock {
  type: 'tool_call';
  name: string;
  summary: string;
  input?: Record<string, unknown>;
}

export interface ToolResultBlock extends ContentBlock {
  type: 'tool_result';
  toolName: string;
  summary: string;
  content?: string;
}

export type ChatContentBlock = TextBlock | ToolCallBlock | ToolResultBlock;

export interface ChatMessage {
  role: 'user' | 'assistant';
  timestamp?: string;
  blocks: ChatContentBlock[];
}

// Chat log WebSocket messages
export interface WatchChatLogMessage extends WsMessage {
  type: 'watch-chat-log';
  sessionName: string;
  windowIndex: number;
}

export interface UnwatchChatLogMessage extends WsMessage {
  type: 'unwatch-chat-log';
}

export interface ChatHistoryMessage extends WsMessage {
  type: 'chat-history';
  messages: ChatMessage[];
  tool: AiTool | null;
}

export interface ChatEventMessage extends WsMessage {
  type: 'chat-event';
  message: ChatMessage;
}

export interface ChatLogErrorMessage extends WsMessage {
  type: 'chat-log-error';
  error: string;
}
```

Add to the `ServerMessage` union type:

```typescript
  | ChatHistoryMessage
  | ChatEventMessage
  | ChatLogErrorMessage;
```

**Step 2: Verify types**

Run: `cd /home/cyrus/git/personal/webmux && npx vue-tsc --noEmit`
Expected: no type errors

**Step 3: Commit**

```bash
git add src/types/index.ts
git commit -m "feat: add frontend TypeScript types for chat log messages"
```

---

### Task 7: Install marked and highlight.js for markdown rendering

**Files:**
- Modify: `package.json`

**Step 1: Install dependencies**

Run: `cd /home/cyrus/git/personal/webmux && npm install marked highlight.js @types/marked`

**Step 2: Commit**

```bash
git add package.json package-lock.json
git commit -m "feat: add marked and highlight.js for chat view markdown rendering"
```

---

### Task 8: Create ChatView.vue component

**Files:**
- Create: `src/components/ChatView.vue`

**Step 1: Create the ChatView component**

Create `src/components/ChatView.vue`. This is the core frontend component — a scrollable message list with markdown rendering and collapsible tool cards, plus an input bar at the bottom.

```vue
<template>
  <div class="chat-view">
    <!-- Message list -->
    <div ref="messageList" class="chat-messages">
      <!-- Empty state -->
      <div v-if="!messages.length && !loading" class="chat-empty">
        <div v-if="error" class="chat-error">
          <p>{{ error }}</p>
          <button @click="$emit('switch-to-terminal')" class="chat-error-btn">
            Switch to Terminal
          </button>
        </div>
        <div v-else class="chat-waiting">
          <p class="text-secondary">Detecting AI session...</p>
        </div>
      </div>

      <!-- Tool badge -->
      <div v-if="activeTool" class="chat-tool-badge">
        {{ activeTool === 'claude' ? 'Claude Code' : 'Codex' }}
      </div>

      <!-- Messages -->
      <div
        v-for="(msg, i) in messages"
        :key="i"
        :class="['chat-message', `chat-message-${msg.role}`]"
      >
        <div class="chat-message-header">
          <span class="chat-role">{{ msg.role === 'user' ? 'You' : 'Assistant' }}</span>
          <span v-if="msg.timestamp" class="chat-timestamp">
            {{ formatTime(msg.timestamp) }}
          </span>
        </div>
        <div class="chat-message-body">
          <template v-for="(block, j) in msg.blocks" :key="j">
            <!-- Text block -->
            <div
              v-if="block.type === 'text'"
              class="chat-text"
              v-html="renderMarkdown((block as TextBlock).text)"
            />

            <!-- Tool call block -->
            <div v-else-if="block.type === 'tool_call'" class="chat-tool-call">
              <button
                class="chat-tool-header"
                @click="toggleExpand(`${i}-${j}`)"
              >
                <span class="chat-tool-icon">{{ toolIcon((block as ToolCallBlock).name) }}</span>
                <span class="chat-tool-name">{{ (block as ToolCallBlock).name }}</span>
                <span class="chat-tool-summary">{{ (block as ToolCallBlock).summary }}</span>
                <span class="chat-tool-chevron" :class="{ expanded: expanded.has(`${i}-${j}`) }">
                  &#9656;
                </span>
              </button>
              <div v-if="expanded.has(`${i}-${j}`)" class="chat-tool-detail">
                <pre>{{ JSON.stringify((block as ToolCallBlock).input, null, 2) }}</pre>
              </div>
            </div>

            <!-- Tool result block -->
            <div v-else-if="block.type === 'tool_result'" class="chat-tool-result">
              <button
                class="chat-tool-header chat-tool-result-header"
                @click="toggleExpand(`${i}-${j}`)"
              >
                <span class="chat-tool-summary">{{ (block as ToolResultBlock).summary }}</span>
                <span class="chat-tool-chevron" :class="{ expanded: expanded.has(`${i}-${j}`) }">
                  &#9656;
                </span>
              </button>
              <div v-if="expanded.has(`${i}-${j}`)" class="chat-tool-detail">
                <pre>{{ (block as ToolResultBlock).content || 'No output' }}</pre>
              </div>
            </div>
          </template>
        </div>
      </div>
    </div>

    <!-- Input bar -->
    <div class="chat-input-bar">
      <textarea
        ref="inputEl"
        v-model="inputText"
        placeholder="Type a message..."
        rows="1"
        @keydown.enter.exact.prevent="sendMessage"
        @keydown.shift.enter="/* allow newline */"
        @input="autoResize"
      />
      <button @click="sendMessage" :disabled="!inputText.trim()">Send</button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, onUnmounted, watch, nextTick } from 'vue'
import { marked } from 'marked'
import hljs from 'highlight.js'
import type { UseWebSocketReturn } from '@/composables/useWebSocket'
import type {
  ChatMessage,
  TextBlock,
  ToolCallBlock,
  ToolResultBlock,
  AiTool,
  ChatHistoryMessage,
  ChatEventMessage,
  ChatLogErrorMessage,
} from '@/types'

interface Props {
  session: string
  windowIndex: number
  ws: UseWebSocketReturn
}

const props = defineProps<Props>()
const emit = defineEmits<{
  'switch-to-terminal': []
}>()

const messages = ref<ChatMessage[]>([])
const activeTool = ref<AiTool | null>(null)
const error = ref<string | null>(null)
const loading = ref(true)
const inputText = ref('')
const messageList = ref<HTMLElement | null>(null)
const inputEl = ref<HTMLTextAreaElement | null>(null)
const expanded = reactive(new Set<string>())

// Configure marked
marked.setOptions({
  highlight(code: string, lang: string) {
    if (lang && hljs.getLanguage(lang)) {
      return hljs.highlight(code, { language: lang }).value
    }
    return hljs.highlightAuto(code).value
  },
  breaks: true,
})

function renderMarkdown(text: string): string {
  return marked.parse(text, { async: false }) as string
}

function formatTime(ts: string): string {
  const d = new Date(ts)
  return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
}

function toolIcon(name: string): string {
  const icons: Record<string, string> = {
    Read: '\u{1F4C4}',
    Edit: '\u{270F}',
    Write: '\u{1F4DD}',
    Bash: '\u{1F4BB}',
    Glob: '\u{1F50D}',
    Grep: '\u{1F50E}',
    Task: '\u{1F916}',
    WebSearch: '\u{1F310}',
    MCP: '\u{1F50C}',
  }
  return icons[name] || '\u{1F527}'
}

function toggleExpand(key: string) {
  if (expanded.has(key)) {
    expanded.delete(key)
  } else {
    expanded.add(key)
  }
}

function scrollToBottom() {
  nextTick(() => {
    if (messageList.value) {
      messageList.value.scrollTop = messageList.value.scrollHeight
    }
  })
}

function sendMessage() {
  const text = inputText.value.trim()
  if (!text) return
  props.ws.send({ type: 'input', data: text + '\n' })
  inputText.value = ''
  if (inputEl.value) {
    inputEl.value.style.height = 'auto'
  }
}

function autoResize() {
  if (inputEl.value) {
    inputEl.value.style.height = 'auto'
    inputEl.value.style.height = Math.min(inputEl.value.scrollHeight, 120) + 'px'
  }
}

function startWatching() {
  messages.value = []
  activeTool.value = null
  error.value = null
  loading.value = true
  expanded.clear()

  props.ws.send({
    type: 'watch-chat-log',
    sessionName: props.session,
    windowIndex: props.windowIndex,
  })
}

function stopWatching() {
  props.ws.send({ type: 'unwatch-chat-log' })
}

onMounted(() => {
  props.ws.onMessage<ChatHistoryMessage>('chat-history', (data) => {
    messages.value = data.messages
    activeTool.value = data.tool
    loading.value = false
    scrollToBottom()
  })

  props.ws.onMessage<ChatEventMessage>('chat-event', (data) => {
    messages.value.push(data.message)
    scrollToBottom()
  })

  props.ws.onMessage<ChatLogErrorMessage>('chat-log-error', (data) => {
    error.value = data.error
    loading.value = false
  })

  startWatching()
})

onUnmounted(() => {
  stopWatching()
})

watch([() => props.session, () => props.windowIndex], () => {
  stopWatching()
  startWatching()
})
</script>

<style scoped>
.chat-view {
  display: flex;
  flex-direction: column;
  height: 100%;
  background: var(--bg-primary);
}

.chat-messages {
  flex: 1;
  overflow-y: auto;
  padding: 16px;
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.chat-empty {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 100%;
}

.chat-error {
  text-align: center;
  color: var(--text-secondary);
}

.chat-error-btn {
  margin-top: 12px;
  padding: 6px 16px;
  background: var(--bg-tertiary);
  color: var(--accent-primary);
  border: 1px solid var(--border-primary);
  border-radius: 6px;
  cursor: pointer;
}

.chat-error-btn:hover {
  background: var(--border-primary);
}

.chat-waiting {
  text-align: center;
}

.text-secondary {
  color: var(--text-secondary);
}

.chat-tool-badge {
  align-self: center;
  padding: 2px 10px;
  font-size: 11px;
  border-radius: 12px;
  background: var(--bg-tertiary);
  color: var(--text-tertiary);
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.chat-message {
  max-width: 100%;
}

.chat-message-user {
  border-left: 3px solid var(--accent-primary);
  padding-left: 12px;
}

.chat-message-assistant {
  border-left: 3px solid var(--accent-success);
  padding-left: 12px;
}

.chat-message-header {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 4px;
}

.chat-role {
  font-size: 12px;
  font-weight: 600;
  color: var(--text-secondary);
  text-transform: uppercase;
  letter-spacing: 0.3px;
}

.chat-timestamp {
  font-size: 11px;
  color: var(--text-tertiary);
}

.chat-message-body {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.chat-text {
  color: var(--text-primary);
  font-size: 14px;
  line-height: 1.6;
}

.chat-text :deep(p) {
  margin: 0 0 8px;
}

.chat-text :deep(p:last-child) {
  margin-bottom: 0;
}

.chat-text :deep(code) {
  background: var(--bg-tertiary);
  padding: 2px 6px;
  border-radius: 4px;
  font-size: 13px;
}

.chat-text :deep(pre) {
  background: var(--bg-secondary);
  border: 1px solid var(--border-primary);
  border-radius: 6px;
  padding: 12px;
  overflow-x: auto;
  font-size: 13px;
}

.chat-text :deep(pre code) {
  background: none;
  padding: 0;
}

.chat-tool-call,
.chat-tool-result {
  border: 1px solid var(--border-primary);
  border-radius: 6px;
  overflow: hidden;
}

.chat-tool-result {
  margin-left: 16px;
  border-color: var(--border-secondary);
}

.chat-tool-header {
  display: flex;
  align-items: center;
  gap: 8px;
  width: 100%;
  padding: 6px 10px;
  background: var(--bg-secondary);
  border: none;
  color: var(--text-primary);
  cursor: pointer;
  font-size: 13px;
  text-align: left;
}

.chat-tool-header:hover {
  background: var(--bg-tertiary);
}

.chat-tool-result-header {
  background: var(--bg-primary);
  color: var(--text-secondary);
  font-size: 12px;
}

.chat-tool-icon {
  font-size: 14px;
  flex-shrink: 0;
}

.chat-tool-name {
  font-weight: 600;
  color: var(--accent-primary);
  flex-shrink: 0;
}

.chat-tool-summary {
  color: var(--text-secondary);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  flex: 1;
}

.chat-tool-chevron {
  flex-shrink: 0;
  color: var(--text-tertiary);
  transition: transform 0.15s;
  font-size: 12px;
}

.chat-tool-chevron.expanded {
  transform: rotate(90deg);
}

.chat-tool-detail {
  padding: 8px 10px;
  border-top: 1px solid var(--border-primary);
  background: var(--bg-primary);
}

.chat-tool-detail pre {
  margin: 0;
  font-size: 12px;
  color: var(--text-secondary);
  white-space: pre-wrap;
  word-break: break-all;
  max-height: 300px;
  overflow-y: auto;
}

.chat-input-bar {
  display: flex;
  gap: 8px;
  padding: 12px 16px;
  border-top: 1px solid var(--border-primary);
  background: var(--bg-secondary);
}

.chat-input-bar textarea {
  flex: 1;
  padding: 8px 12px;
  background: var(--bg-primary);
  border: 1px solid var(--border-primary);
  border-radius: 6px;
  color: var(--text-primary);
  font-size: 14px;
  font-family: inherit;
  resize: none;
  line-height: 1.4;
}

.chat-input-bar textarea:focus {
  outline: none;
  border-color: var(--accent-primary);
}

.chat-input-bar textarea::placeholder {
  color: var(--text-tertiary);
}

.chat-input-bar button {
  padding: 8px 16px;
  background: var(--accent-primary);
  color: var(--bg-primary);
  border: none;
  border-radius: 6px;
  font-size: 13px;
  font-weight: 600;
  cursor: pointer;
  align-self: flex-end;
}

.chat-input-bar button:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}

.chat-input-bar button:not(:disabled):hover {
  opacity: 0.9;
}
</style>
```

**Step 2: Verify types**

Run: `cd /home/cyrus/git/personal/webmux && npx vue-tsc --noEmit`
Expected: no type errors

**Step 3: Commit**

```bash
git add src/components/ChatView.vue
git commit -m "feat: create ChatView component with markdown rendering and tool cards"
```

---

### Task 9: Add view toggle to App.vue and mount ChatView

**Files:**
- Modify: `src/App.vue`

**Step 1: Add view mode state and toggle to App.vue**

This task requires reading the full App.vue to find the exact insertion points. The changes are:

1. Import ChatView and add `viewMode` ref:
   ```typescript
   import ChatView from '@/components/ChatView.vue'
   const viewMode = ref<'terminal' | 'chat'>('terminal')
   ```

2. Add a toggle control in the header (near the search bar area):
   ```html
   <div class="view-toggle">
     <button
       :class="{ active: viewMode === 'terminal' }"
       @click="viewMode = 'terminal'"
     >Terminal</button>
     <button
       :class="{ active: viewMode === 'chat' }"
       @click="viewMode = 'chat'"
     >Chat</button>
   </div>
   ```

3. In the main content area, use `v-show` to toggle between views (keep both mounted):
   ```html
   <TerminalView
     v-show="viewMode === 'terminal'"
     v-if="currentSession"
     :session="currentSession"
     :ws="ws"
   />
   <ChatView
     v-show="viewMode === 'chat'"
     v-if="currentSession"
     :session="currentSession"
     :window-index="currentWindowIndex"
     :ws="ws"
     @switch-to-terminal="viewMode = 'terminal'"
   />
   ```

   Note: `currentWindowIndex` needs to be tracked alongside `currentSession`. Add:
   ```typescript
   const currentWindowIndex = ref<number>(0)
   ```
   And update it in the `handleSelectWindow` handler.

4. Add toggle styles matching the GitHub dark theme:
   ```css
   .view-toggle {
     display: flex;
     background: var(--bg-tertiary);
     border-radius: 6px;
     padding: 2px;
   }
   .view-toggle button {
     padding: 4px 12px;
     border: none;
     background: transparent;
     color: var(--text-secondary);
     font-size: 12px;
     border-radius: 4px;
     cursor: pointer;
   }
   .view-toggle button.active {
     background: var(--accent-primary);
     color: var(--bg-primary);
   }
   ```

**Step 2: Verify it compiles and renders**

Run: `cd /home/cyrus/git/personal/webmux && npx vue-tsc --noEmit`
Expected: no type errors

**Step 3: Commit**

```bash
git add src/App.vue
git commit -m "feat: add view toggle and mount ChatView alongside TerminalView"
```

---

### Task 10: Build, test, and verify end-to-end

**Files:** None new — integration testing.

**Step 1: Build the Rust backend**

Run: `cd /home/cyrus/git/personal/webmux && npm run rust:build`
Expected: compiles in release mode

**Step 2: Build the Vue frontend**

Run: `cd /home/cyrus/git/personal/webmux && npm run build:client`
Expected: builds successfully

**Step 3: Run backend tests**

Run: `cd /home/cyrus/git/personal/webmux && npm run rust:test`
Expected: all parser tests pass

**Step 4: Manual end-to-end test**

1. Restart the service: `systemctl --user restart webmux`
2. Open `http://localhost:4000` in a browser
3. Create or select a tmux session running Claude Code
4. Click the "Chat" toggle — should show the conversation history
5. Type a message in the chat input — should appear in the terminal
6. Verify tool calls show as collapsible cards

**Step 5: Commit final build**

```bash
git add -A
git commit -m "feat: complete chat view with dual-view toggle"
```

---

### Task 11: Create Codex wrapper script

**Files:**
- Create: `scripts/webmux-codex`

**Step 1: Create the wrapper**

Create `scripts/webmux-codex`:

```bash
#!/bin/bash
# Wrapper to run Codex CLI with JSON output logging for WebMux chat view.
# Usage: webmux-codex [codex args...]
#
# Logs NDJSON to /tmp/webmux-codex-<PID>.jsonl so WebMux can parse it.

LOG_FILE="/tmp/webmux-codex-$$.jsonl"

cleanup() {
    rm -f "$LOG_FILE"
}
trap cleanup EXIT

codex --json "$@" 2>&1 | tee "$LOG_FILE"
```

**Step 2: Make executable**

Run: `chmod +x /home/cyrus/git/personal/webmux/scripts/webmux-codex`

**Step 3: Optionally symlink to PATH**

Run: `ln -sf /home/cyrus/git/personal/webmux/scripts/webmux-codex /home/cyrus/.local/bin/webmux-codex`

**Step 4: Commit**

```bash
git add scripts/webmux-codex
git commit -m "feat: add webmux-codex wrapper script for Codex JSON logging"
```

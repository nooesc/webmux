pub mod claude_parser;

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

/// Normalized content block — shared format for Claude Code and Codex.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum ContentBlock {
    Text {
        text: String,
    },
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

/// Normalized chat message.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ChatMessage {
    pub role: String,
    pub timestamp: Option<DateTime<Utc>>,
    pub blocks: Vec<ContentBlock>,
}

/// Which AI tool is running.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum AiTool {
    Claude,
    Codex,
}

/// Events emitted by the log watcher.
#[derive(Debug, Clone)]
pub enum ChatLogEvent {
    History {
        messages: Vec<ChatMessage>,
        tool: AiTool,
    },
    NewMessage {
        message: ChatMessage,
    },
    Error {
        error: String,
    },
}

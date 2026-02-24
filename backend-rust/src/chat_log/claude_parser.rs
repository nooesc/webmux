use chrono::{DateTime, Utc};
use serde::Deserialize;
use tracing::warn;

use super::{ChatMessage, ContentBlock};

// ---------------------------------------------------------------------------
// Raw JSONL shapes (private deserialization types)
// ---------------------------------------------------------------------------

#[derive(Deserialize)]
struct RawLine {
    #[serde(rename = "type")]
    line_type: String,
    timestamp: Option<DateTime<Utc>>,
    message: Option<RawMessage>,
}

#[derive(Deserialize)]
struct RawMessage {
    role: String,
    content: RawContent,
}

/// Claude Code encodes `content` as either a plain string or an array of
/// typed blocks. We handle both forms here.
#[derive(Deserialize)]
#[serde(untagged)]
enum RawContent {
    Text(String),
    Blocks(Vec<RawBlock>),
}

#[derive(Deserialize)]
struct RawBlock {
    #[serde(rename = "type")]
    block_type: String,
    // text block
    text: Option<String>,
    // tool_use block
    name: Option<String>,
    input: Option<serde_json::Value>,
    // tool_result block
    tool_use_id: Option<String>,
    content: Option<RawToolResultContent>,
}

/// Tool result content can be a plain string or a structured value.
#[derive(Deserialize)]
#[serde(untagged)]
enum RawToolResultContent {
    Text(String),
    Other(serde_json::Value),
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Parse a single JSONL line from a Claude Code log file.
///
/// Returns `None` for blank lines, summary entries, and malformed JSON
/// (the latter also emits a tracing warning).
pub fn parse_line(line: &str) -> Option<ChatMessage> {
    let trimmed = line.trim();
    if trimmed.is_empty() {
        return None;
    }

    let raw: RawLine = match serde_json::from_str(trimmed) {
        Ok(v) => v,
        Err(e) => {
            warn!("claude_parser: failed to parse JSONL line: {e}");
            return None;
        }
    };

    // Only keep user / assistant turns.
    if raw.line_type != "user" && raw.line_type != "assistant" {
        return None;
    }

    let msg = raw.message?;
    let blocks = convert_content(msg.content);

    if blocks.is_empty() {
        return None;
    }

    Some(ChatMessage {
        role: msg.role,
        timestamp: raw.timestamp,
        blocks,
    })
}

// ---------------------------------------------------------------------------
// Content conversion
// ---------------------------------------------------------------------------

fn convert_content(content: RawContent) -> Vec<ContentBlock> {
    match content {
        RawContent::Text(s) => {
            if s.is_empty() {
                vec![]
            } else {
                vec![ContentBlock::Text { text: s }]
            }
        }
        RawContent::Blocks(raw_blocks) => raw_blocks
            .into_iter()
            .filter_map(convert_block)
            .collect(),
    }
}

fn convert_block(block: RawBlock) -> Option<ContentBlock> {
    match block.block_type.as_str() {
        "text" => {
            let text = block.text.unwrap_or_default();
            if text.is_empty() {
                return None;
            }
            Some(ContentBlock::Text { text })
        }
        "tool_use" => {
            let name = block.name.unwrap_or_default();
            let summary = generate_tool_summary(&name, block.input.as_ref());
            Some(ContentBlock::ToolCall {
                name,
                summary,
                input: block.input,
            })
        }
        "tool_result" => {
            let content_str = block.content.map(|c| match c {
                RawToolResultContent::Text(s) => s,
                RawToolResultContent::Other(v) => v.to_string(),
            });
            let tool_name = block.tool_use_id.unwrap_or_default();
            let summary = generate_result_summary(content_str.as_deref());
            Some(ContentBlock::ToolResult {
                tool_name,
                summary,
                content: content_str,
            })
        }
        _ => None,
    }
}

// ---------------------------------------------------------------------------
// Summaries
// ---------------------------------------------------------------------------

/// Build a short human-readable summary of a tool invocation based on its
/// name and input object. For well-known Claude Code tools we pull out the
/// single most informative field; for unknown tools we fall back to the tool
/// name itself.
pub fn generate_tool_summary(name: &str, input: Option<&serde_json::Value>) -> String {
    let field = match name {
        "Read" | "Edit" | "Write" => "file_path",
        "Bash" => "command",
        "Glob" | "Grep" => "pattern",
        "Task" | "TaskCreate" => "description",
        "WebSearch" => "query",
        "WebFetch" => "url",
        _ => return name.to_string(),
    };

    let value = input
        .and_then(|v| v.get(field))
        .and_then(|v| v.as_str());

    match value {
        Some(s) => format!("{name}: {s}"),
        None => name.to_string(),
    }
}

/// Summarise tool-result content: show line count if multi-line, otherwise
/// the first 120 characters.
fn generate_result_summary(content: Option<&str>) -> String {
    let Some(text) = content else {
        return "(empty)".to_string();
    };

    let line_count = text.lines().count();
    if line_count > 1 {
        return format!("{line_count} lines");
    }

    if text.len() > 120 {
        format!("{}...", &text[..120])
    } else {
        text.to_string()
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_user_text_message() {
        let line = r#"{"uuid":"a","parentUuid":"b","timestamp":"2026-02-24T10:00:00Z","type":"user","message":{"role":"user","content":[{"type":"text","text":"fix the auth bug"}]}}"#;
        let msg = parse_line(line).expect("should parse");
        assert_eq!(msg.role, "user");
        assert_eq!(msg.blocks.len(), 1);
        match &msg.blocks[0] {
            ContentBlock::Text { text } => assert_eq!(text, "fix the auth bug"),
            other => panic!("expected Text, got {other:?}"),
        }
        assert!(msg.timestamp.is_some());
    }

    #[test]
    fn parse_assistant_with_tool_use_and_result() {
        let line = r#"{"uuid":"c","parentUuid":"a","timestamp":"2026-02-24T10:00:05Z","type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"I'll look at the auth module."},{"type":"tool_use","id":"tu1","name":"Read","input":{"file_path":"src/auth.ts"}},{"type":"tool_result","tool_use_id":"tu1","content":"export function auth() {...}"}]}}"#;
        let msg = parse_line(line).expect("should parse");
        assert_eq!(msg.role, "assistant");
        assert_eq!(msg.blocks.len(), 3);

        match &msg.blocks[0] {
            ContentBlock::Text { text } => {
                assert_eq!(text, "I'll look at the auth module.")
            }
            other => panic!("expected Text, got {other:?}"),
        }

        match &msg.blocks[1] {
            ContentBlock::ToolCall {
                name,
                summary,
                input,
            } => {
                assert_eq!(name, "Read");
                assert_eq!(summary, "Read: src/auth.ts");
                assert!(input.is_some());
            }
            other => panic!("expected ToolCall, got {other:?}"),
        }

        match &msg.blocks[2] {
            ContentBlock::ToolResult {
                tool_name,
                summary,
                content,
            } => {
                assert_eq!(tool_name, "tu1");
                assert_eq!(summary, "export function auth() {...}");
                assert_eq!(content.as_deref(), Some("export function auth() {...}"));
            }
            other => panic!("expected ToolResult, got {other:?}"),
        }
    }

    #[test]
    fn skip_summary_lines() {
        let line = r#"{"uuid":"s","parentUuid":"x","timestamp":"2026-02-24T10:01:00Z","type":"summary","message":{"role":"assistant","content":"summary text"}}"#;
        assert!(parse_line(line).is_none());
    }

    #[test]
    fn skip_empty_lines() {
        assert!(parse_line("").is_none());
        assert!(parse_line("   ").is_none());
        assert!(parse_line("\n").is_none());
    }

    #[test]
    fn skip_malformed_json() {
        assert!(parse_line("{not valid json}").is_none());
        assert!(parse_line("just some text").is_none());
    }

    #[test]
    fn bash_tool_summary() {
        let summary = generate_tool_summary(
            "Bash",
            Some(&serde_json::json!({"command": "cargo test"})),
        );
        assert_eq!(summary, "Bash: cargo test");
    }

    #[test]
    fn unknown_tool_summary_falls_back_to_name() {
        let summary = generate_tool_summary(
            "CustomTool",
            Some(&serde_json::json!({"some_field": "value"})),
        );
        assert_eq!(summary, "CustomTool");
    }

    #[test]
    fn string_content_not_array() {
        let line = r#"{"uuid":"d","parentUuid":"e","timestamp":"2026-02-24T10:02:00Z","type":"user","message":{"role":"user","content":"hello plain text"}}"#;
        let msg = parse_line(line).expect("should parse string content");
        assert_eq!(msg.role, "user");
        assert_eq!(msg.blocks.len(), 1);
        match &msg.blocks[0] {
            ContentBlock::Text { text } => assert_eq!(text, "hello plain text"),
            other => panic!("expected Text, got {other:?}"),
        }
    }

    #[test]
    fn multiline_result_shows_line_count() {
        let summary = generate_result_summary(Some("line one\nline two\nline three"));
        assert_eq!(summary, "3 lines");
    }

    #[test]
    fn empty_result_shows_placeholder() {
        let summary = generate_result_summary(None);
        assert_eq!(summary, "(empty)");
    }

    #[test]
    fn skip_empty_text_blocks() {
        let line = r#"{"uuid":"f","parentUuid":"g","timestamp":"2026-02-24T10:03:00Z","type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":""},{"type":"text","text":"real content"}]}}"#;
        let msg = parse_line(line).expect("should parse");
        assert_eq!(msg.blocks.len(), 1);
        match &msg.blocks[0] {
            ContentBlock::Text { text } => assert_eq!(text, "real content"),
            other => panic!("expected Text, got {other:?}"),
        }
    }
}

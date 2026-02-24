use serde::Deserialize;
use tracing::warn;

use super::{ChatMessage, ContentBlock};

// ---------------------------------------------------------------------------
// Raw NDJSON shapes (private deserialization types)
// ---------------------------------------------------------------------------

#[derive(Deserialize)]
struct RawEvent {
    #[serde(rename = "type")]
    event_type: String,
    item: Option<RawItem>,
}

#[derive(Deserialize)]
struct RawItem {
    #[serde(rename = "type")]
    item_type: String,

    // agent_message / reasoning
    text: Option<String>,

    // command_execution
    command: Option<String>,
    aggregated_output: Option<String>,

    // file_change
    changes: Option<Vec<RawFileChange>>,

    // mcp_tool_call
    server: Option<String>,
    tool: Option<String>,
}

#[derive(Deserialize)]
struct RawFileChange {
    path: String,
    #[allow(dead_code)]
    #[serde(default)]
    kind: Option<String>,
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Parse a single NDJSON line from a Codex CLI `--json` log stream.
///
/// Returns `None` for blank lines, non-`item.completed` events, unknown item
/// types, and malformed JSON (the latter also emits a tracing warning).
pub fn parse_line(line: &str) -> Option<ChatMessage> {
    let trimmed = line.trim();
    if trimmed.is_empty() {
        return None;
    }

    let event: RawEvent = match serde_json::from_str(trimmed) {
        Ok(v) => v,
        Err(e) => {
            warn!("codex_parser: failed to parse NDJSON line: {e}");
            return None;
        }
    };

    if event.event_type != "item.completed" {
        return None;
    }

    let item = event.item?;
    let blocks = convert_item(&item)?;

    Some(ChatMessage {
        role: "assistant".to_string(),
        timestamp: None,
        blocks,
    })
}

// ---------------------------------------------------------------------------
// Item conversion
// ---------------------------------------------------------------------------

fn convert_item(item: &RawItem) -> Option<Vec<ContentBlock>> {
    match item.item_type.as_str() {
        "agent_message" => convert_agent_message(item),
        "command_execution" => convert_command_execution(item),
        "file_change" => convert_file_change(item),
        "mcp_tool_call" => convert_mcp_tool_call(item),
        _ => None,
    }
}

fn convert_agent_message(item: &RawItem) -> Option<Vec<ContentBlock>> {
    let text = item.text.as_deref().unwrap_or_default();
    if text.is_empty() {
        return None;
    }

    Some(vec![ContentBlock::Text {
        text: text.to_string(),
    }])
}

fn convert_command_execution(item: &RawItem) -> Option<Vec<ContentBlock>> {
    let command = item.command.as_deref().unwrap_or_default();
    if command.is_empty() {
        return None;
    }

    let summary = truncate(command, 120);
    let mut blocks = vec![ContentBlock::ToolCall {
        name: "Bash".to_string(),
        summary,
        input: Some(serde_json::json!({ "command": command })),
    }];

    if let Some(output) = &item.aggregated_output {
        if !output.is_empty() {
            blocks.push(ContentBlock::ToolResult {
                tool_name: "Bash".to_string(),
                summary: summarize_output(output),
                content: Some(output.clone()),
            });
        }
    }

    Some(blocks)
}

fn convert_file_change(item: &RawItem) -> Option<Vec<ContentBlock>> {
    let changes = item.changes.as_deref().unwrap_or_default();
    if changes.is_empty() {
        return None;
    }

    let summary = if changes.len() == 1 {
        changes[0].path.clone()
    } else {
        format!("{} files", changes.len())
    };

    Some(vec![ContentBlock::ToolCall {
        name: "Edit".to_string(),
        summary,
        input: None,
    }])
}

fn convert_mcp_tool_call(item: &RawItem) -> Option<Vec<ContentBlock>> {
    let server = item.server.as_deref().unwrap_or("unknown");
    let tool = item.tool.as_deref().unwrap_or("unknown");
    let summary = truncate(&format!("{server}/{tool}"), 120);

    Some(vec![ContentBlock::ToolCall {
        name: "MCP".to_string(),
        summary,
        input: None,
    }])
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn truncate(s: &str, max: usize) -> String {
    if s.len() <= max {
        s.to_string()
    } else {
        format!("{}...", &s[..max])
    }
}

fn summarize_output(text: &str) -> String {
    let line_count = text.lines().count();
    if line_count > 1 {
        return format!("{line_count} lines");
    }

    truncate(text, 120)
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_agent_message() {
        let line = r#"{"type":"item.completed","item":{"id":"item_1","type":"agent_message","text":"I'll fix this.","status":"completed"}}"#;
        let msg = parse_line(line).expect("should parse");
        assert_eq!(msg.role, "assistant");
        assert_eq!(msg.blocks.len(), 1);
        match &msg.blocks[0] {
            ContentBlock::Text { text } => assert_eq!(text, "I'll fix this."),
            other => panic!("expected Text, got {other:?}"),
        }
    }

    #[test]
    fn parse_command_execution_with_output() {
        let line = r#"{"type":"item.completed","item":{"id":"item_2","type":"command_execution","command":"bash -lc npm test","status":"completed","aggregated_output":"All tests passed"}}"#;
        let msg = parse_line(line).expect("should parse");
        assert_eq!(msg.role, "assistant");
        assert_eq!(msg.blocks.len(), 2);

        match &msg.blocks[0] {
            ContentBlock::ToolCall {
                name,
                summary,
                input,
            } => {
                assert_eq!(name, "Bash");
                assert_eq!(summary, "bash -lc npm test");
                assert!(input.is_some());
            }
            other => panic!("expected ToolCall, got {other:?}"),
        }

        match &msg.blocks[1] {
            ContentBlock::ToolResult {
                tool_name,
                summary,
                content,
            } => {
                assert_eq!(tool_name, "Bash");
                assert_eq!(summary, "All tests passed");
                assert_eq!(content.as_deref(), Some("All tests passed"));
            }
            other => panic!("expected ToolResult, got {other:?}"),
        }
    }

    #[test]
    fn parse_command_execution_without_output() {
        let line = r#"{"type":"item.completed","item":{"id":"item_2b","type":"command_execution","command":"mkdir -p build","status":"completed"}}"#;
        let msg = parse_line(line).expect("should parse");
        assert_eq!(msg.blocks.len(), 1);
        match &msg.blocks[0] {
            ContentBlock::ToolCall { name, .. } => assert_eq!(name, "Bash"),
            other => panic!("expected ToolCall, got {other:?}"),
        }
    }

    #[test]
    fn parse_file_change() {
        let line = r#"{"type":"item.completed","item":{"id":"item_3","type":"file_change","changes":[{"path":"src/auth.ts","kind":"update"}],"status":"completed"}}"#;
        let msg = parse_line(line).expect("should parse");
        assert_eq!(msg.role, "assistant");
        assert_eq!(msg.blocks.len(), 1);
        match &msg.blocks[0] {
            ContentBlock::ToolCall { name, summary, .. } => {
                assert_eq!(name, "Edit");
                assert_eq!(summary, "src/auth.ts");
            }
            other => panic!("expected ToolCall, got {other:?}"),
        }
    }

    #[test]
    fn parse_file_change_multiple_files() {
        let line = r#"{"type":"item.completed","item":{"id":"item_3b","type":"file_change","changes":[{"path":"a.ts","kind":"update"},{"path":"b.ts","kind":"add"}],"status":"completed"}}"#;
        let msg = parse_line(line).expect("should parse");
        match &msg.blocks[0] {
            ContentBlock::ToolCall { name, summary, .. } => {
                assert_eq!(name, "Edit");
                assert_eq!(summary, "2 files");
            }
            other => panic!("expected ToolCall, got {other:?}"),
        }
    }

    #[test]
    fn parse_mcp_tool_call() {
        let line = r#"{"type":"item.completed","item":{"id":"item_4","type":"mcp_tool_call","server":"context7","tool":"search","status":"completed"}}"#;
        let msg = parse_line(line).expect("should parse");
        assert_eq!(msg.role, "assistant");
        assert_eq!(msg.blocks.len(), 1);
        match &msg.blocks[0] {
            ContentBlock::ToolCall { name, summary, .. } => {
                assert_eq!(name, "MCP");
                assert_eq!(summary, "context7/search");
            }
            other => panic!("expected ToolCall, got {other:?}"),
        }
    }

    #[test]
    fn skip_non_completed_events() {
        let cases = [
            r#"{"type":"item.started","item":{"id":"item_1","type":"agent_message","text":"starting"}}"#,
            r#"{"type":"item.updated","item":{"id":"item_1","type":"agent_message","text":"updating"}}"#,
        ];
        for line in &cases {
            assert!(parse_line(line).is_none(), "should skip: {line}");
        }
    }

    #[test]
    fn skip_turn_events() {
        let cases = [
            r#"{"type":"turn.started"}"#,
            r#"{"type":"turn.completed","usage":{"input_tokens":24763,"output_tokens":122}}"#,
            r#"{"type":"thread.started","thread_id":"0199a213-abc"}"#,
        ];
        for line in &cases {
            assert!(parse_line(line).is_none(), "should skip: {line}");
        }
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
    }

    #[test]
    fn skip_unknown_item_type() {
        let line = r#"{"type":"item.completed","item":{"id":"item_x","type":"unknown_future_type","text":"whatever"}}"#;
        assert!(parse_line(line).is_none());
    }

    #[test]
    fn multiline_output_summarized() {
        let line = r#"{"type":"item.completed","item":{"id":"item_5","type":"command_execution","command":"cat log.txt","status":"completed","aggregated_output":"line 1\nline 2\nline 3"}}"#;
        let msg = parse_line(line).expect("should parse");
        assert_eq!(msg.blocks.len(), 2);
        match &msg.blocks[1] {
            ContentBlock::ToolResult { summary, .. } => {
                assert_eq!(summary, "3 lines");
            }
            other => panic!("expected ToolResult, got {other:?}"),
        }
    }
}

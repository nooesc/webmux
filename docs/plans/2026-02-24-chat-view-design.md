# Chat View for WebMux

## Summary

Add a dual-view system to WebMux: the existing terminal view stays as-is, and a new chat view renders AI CLI tool output (Claude Code, Codex) as a clean, readable conversation with collapsible tool call summaries. A toggle in the header switches between views. The chat view is interactive — users can type prompts that get sent to the tmux session.

## Architecture

### Approach: Hybrid (JSONL logs + existing terminal)

The raw terminal view is untouched. The chat view reads structured JSONL log files that Claude Code and Codex already produce, parses them into a normalized message format, and renders them as a chat UI. Both views share the same tmux session.

```
┌─────────────────────────────────────────────────┐
│ Header  [Terminal | Chat]  toggle               │
├──────────┬──────────────────────────────────────┤
│ Sessions │  Chat View (or Terminal View)        │
│          │  ┌──────────────────────────────┐    │
│          │  │ User: "fix the auth bug"     │    │
│          │  │                              │    │
│          │  │ Assistant:                   │    │
│          │  │ I'll look at the auth...     │    │
│          │  │                              │    │
│          │  │ Read: src/auth.ts            │    │
│          │  │ Edit: src/auth.ts - 3 lines  │    │
│          │  │                              │    │
│          │  │ Done. Fixed the bug by...    │    │
│          │  └──────────────────────────────┘    │
│          │  ┌──────────────────────────────┐    │
│          │  │ Type a message...      [Send]│    │
│          │  └──────────────────────────────┘    │
└──────────┴──────────────────────────────────────┘
```

## Backend Changes

### JSONL Log Watcher (new Rust module: `src/chat_log/`)

**Session-to-log auto-detection:**
1. When `watch-chat-log` is requested for a tmux window, inspect the process tree of the tmux pane
2. For Claude Code: find the `claude` process, extract `--session-id` or read the most recently modified `.jsonl` in `~/.claude/projects/<cwd>/`
3. For Codex: find the `codex` process. Codex does not write persistent JSONL logs, so the backend wraps Codex sessions — when it detects a Codex process, it reads from a tee'd JSON output file (or instruments the launch)
4. Detect tool type from process name (`claude` vs `codex`)

**File watching:**
- Use `notify` crate (inotify on Linux) to watch the detected JSONL file for appends
- On each new line, parse and emit a `chat-event` WebSocket message
- On initial watch, read existing file content and send `chat-history`

**JSONL parsing — normalized format:**

Both Claude Code and Codex logs get normalized into:

```json
{
  "role": "user" | "assistant",
  "timestamp": "2026-02-24T...",
  "blocks": [
    { "type": "text", "text": "..." },
    { "type": "tool_call", "name": "Read", "summary": "src/auth.ts", "input": {...} },
    { "type": "tool_result", "tool_name": "Read", "summary": "42 lines", "content": "..." }
  ]
}
```

**Claude Code parser:** Reads JSONL lines with `message.role` and `message.content[]` (types: `text`, `tool_use`, `tool_result`). Maps directly to normalized format.

**Codex parser:** Reads NDJSON events with `type` (item.started, item.completed) and item types (`agent_message`, `command_execution`, `file_change`, `mcp_tool_call`). Maps item completions to normalized message blocks.

### New WebSocket Messages

Client to server:
- `{ type: "watch-chat-log", sessionName: string, windowIndex: number }` — start watching
- `{ type: "unwatch-chat-log" }` — stop watching

Server to client:
- `{ type: "chat-history", messages: NormalizedMessage[], tool: "claude" | "codex" | null }` — initial backfill
- `{ type: "chat-event", message: NormalizedMessage }` — incremental update
- `{ type: "chat-log-error", error: string }` — detection/parse failures

## Frontend Changes

### View Toggle (in Header / App.vue)

Segmented control: `[Terminal] [Chat]` in the header area. Both TerminalView and ChatView stay mounted (xterm.js keeps its state), but only one is visible via `v-show`. Switching is instant.

### ChatView.vue (new component)

**Message list:**
- Scrollable container with auto-scroll to bottom on new messages
- User messages: labeled block with the prompt text
- Assistant messages: markdown-rendered text (using `marked` + `highlight.js`)
- Tool calls: compact cards showing `name + short summary` (e.g., "Edit src/auth.ts — 3 lines changed"). Click to expand and see full input/output
- Tool results: nested under their tool call, collapsed by default

**Input bar:**
- Text input at bottom of chat view
- Enter sends the text as raw input to the tmux pane (via existing `input` WebSocket message type)
- Supports multi-line input (Shift+Enter for newline)

**State management:**
- Messages stored as reactive array from `chat-history` + `chat-event` events
- Watches session changes — sends `unwatch-chat-log` then `watch-chat-log` on session/window switch
- Shows a "No AI session detected" message when the backend can't find a log file

### Codex Launch Wrapper

For Codex sessions, since Codex doesn't write persistent JSONL:
- Provide a helper script `webmux-codex` that wraps `codex --json 2>/tmp/webmux-codex-$$.jsonl` and tee's output
- The backend detects these files by convention at `/tmp/webmux-codex-*.jsonl`
- Alternative: detect the Codex process and read its stdout via /proc if feasible

## Data Flow

```
Claude Code writes to ~/.claude/projects/.../<session>.jsonl
                              │
                    Backend: notify (inotify)
                              │
                    Parse JSONL line → NormalizedMessage
                              │
                    WebSocket: chat-event
                              │
                    ChatView.vue: append to messages[]
                              │
                    Render as chat bubble / tool card
```

```
User types in chat input
        │
        ▼
WebSocket: { type: "input", data: "user text\n" }
        │
        ▼
Backend sends to tmux pane (same as terminal view input)
        │
        ▼
Claude Code/Codex processes input, writes to JSONL
        │
        ▼
Backend detects new log line → chat-event → ChatView updates
```

## Error Handling

- **No AI process detected:** Show "No AI session detected in this window. Switch to terminal view or start Claude Code / Codex." with a button to switch to terminal view.
- **Log file not found:** Same message as above. The toggle still works — user can always switch to raw terminal.
- **Parse errors:** Skip malformed lines, log warning. Don't break the view.
- **Process exits:** Detect via process monitoring. Show "Session ended" in the chat view. Keep the history visible.

## Testing

- Unit tests for JSONL parsers (Claude Code format + Codex format)
- Integration test: write to a JSONL file, verify WebSocket events arrive
- Manual testing with live Claude Code and Codex sessions

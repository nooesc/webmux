use std::fs::File;
use std::io::{BufRead, BufReader, Seek, SeekFrom};
use std::path::{Path, PathBuf};
use std::process::Stdio;

use anyhow::{bail, Context, Result};
use notify::{RecursiveMode, Watcher};
use tokio::process::Command;
use tokio::sync::mpsc;
use tracing::{debug, error, info, warn};

use super::{claude_parser, codex_parser, AiTool, ChatLogEvent, ChatMessage};

// ---------------------------------------------------------------------------
// Log file detection
// ---------------------------------------------------------------------------

/// Detect which AI tool is running in the given tmux pane and locate its log
/// file.  Returns the log path and the detected tool variant.
pub async fn detect_log_file(
    session_name: &str,
    window_index: u32,
) -> Result<(PathBuf, AiTool)> {
    let target = format!("{session_name}:{window_index}");
    let pane_pid = get_pane_pid(&target).await?;
    let descendants = get_descendant_pids(pane_pid)?;

    for pid in &descendants {
        let name = match process_name(*pid) {
            Some(n) => n,
            None => continue,
        };

        if name == "claude" {
            let cwd = get_process_cwd(*pid)?;
            let log = find_claude_log(&cwd)?;
            info!("detected Claude log: {}", log.display());
            return Ok((log, AiTool::Claude));
        }

        if name == "codex" {
            let log = find_codex_log()?;
            info!("detected Codex log: {}", log.display());
            return Ok((log, AiTool::Codex));
        }
    }

    bail!(
        "no AI tool (claude/codex) found among descendants of pane PID {pane_pid}"
    );
}

// ---------------------------------------------------------------------------
// Log file watcher
// ---------------------------------------------------------------------------

/// Watch a log file for changes and emit parsed chat events.
///
/// 1. Reads the entire file and sends a `ChatLogEvent::History`.
/// 2. Uses `notify` (inotify on Linux) to detect writes, reads new lines,
///    parses them, and sends `ChatLogEvent::NewMessage` for each.
///
/// The returned `notify::RecommendedWatcher` **must be kept alive** by the
/// caller -- dropping it stops file-system notifications.
pub async fn watch_log_file(
    path: &Path,
    tool: AiTool,
    event_tx: mpsc::UnboundedSender<ChatLogEvent>,
) -> Result<notify::RecommendedWatcher> {
    // --- initial history read ---
    let file = File::open(path)
        .with_context(|| format!("failed to open log file: {}", path.display()))?;
    let mut reader = BufReader::new(file);
    let history = read_all_messages(&mut reader, &tool);

    event_tx
        .send(ChatLogEvent::History {
            messages: history,
            tool: tool.clone(),
        })
        .ok();

    // Record the position after the initial read so we only parse new data.
    let start_pos = reader.stream_position()?;

    // --- set up file-system watcher ---
    // `notify` callbacks are sync; bridge to async with an unbounded channel.
    let (notify_tx, mut notify_rx) = mpsc::unbounded_channel::<()>();

    let watcher = notify::recommended_watcher(move |res: notify::Result<notify::Event>| {
        match res {
            Ok(event) if event.kind.is_modify() => {
                let _ = notify_tx.send(());
            }
            Ok(_) => {} // ignore non-modify events
            Err(e) => {
                // Log but do not crash the watcher.
                error!("notify error: {e}");
            }
        }
    })?;

    let mut watcher = watcher;
    watcher.watch(path, RecursiveMode::NonRecursive)?;

    // Spawn a background task that reads new lines whenever notify fires.
    let file_path = path.to_path_buf();
    tokio::spawn(async move {
        let mut pos = start_pos;
        while notify_rx.recv().await.is_some() {
            // Drain any extra notifications that arrived while we were
            // processing so we do a single read per burst.
            while notify_rx.try_recv().is_ok() {}

            match read_new_lines(&file_path, &mut pos, &tool) {
                Ok(messages) => {
                    for msg in messages {
                        if event_tx.send(ChatLogEvent::NewMessage { message: msg }).is_err() {
                            debug!("event_tx closed, stopping watcher task");
                            return;
                        }
                    }
                }
                Err(e) => {
                    warn!("failed to read new log lines: {e}");
                    let _ = event_tx.send(ChatLogEvent::Error {
                        error: e.to_string(),
                    });
                }
            }
        }
    });

    Ok(watcher)
}

// ---------------------------------------------------------------------------
// File reading helpers
// ---------------------------------------------------------------------------

/// Read every line from the current reader position, parse each, and collect
/// the resulting messages.
fn read_all_messages(reader: &mut BufReader<File>, tool: &AiTool) -> Vec<ChatMessage> {
    let mut messages = Vec::new();
    let mut line_buf = String::new();

    loop {
        line_buf.clear();
        match reader.read_line(&mut line_buf) {
            Ok(0) => break, // EOF
            Ok(_) => {
                if let Some(msg) = parse_line(&line_buf, tool) {
                    messages.push(msg);
                }
            }
            Err(e) => {
                warn!("error reading log line: {e}");
                break;
            }
        }
    }

    messages
}

/// Open the file, seek to `pos`, read any new complete lines, advance `pos`,
/// and return parsed messages.
fn read_new_lines(
    path: &Path,
    pos: &mut u64,
    tool: &AiTool,
) -> Result<Vec<ChatMessage>> {
    let file = File::open(path)?;
    let mut reader = BufReader::new(file);
    reader.seek(SeekFrom::Start(*pos))?;

    let mut messages = Vec::new();
    let mut line_buf = String::new();

    loop {
        line_buf.clear();
        match reader.read_line(&mut line_buf) {
            Ok(0) => break,
            Ok(_) => {
                if let Some(msg) = parse_line(&line_buf, tool) {
                    messages.push(msg);
                }
            }
            Err(e) => {
                warn!("error reading new log line: {e}");
                break;
            }
        }
    }

    *pos = reader.stream_position()?;
    Ok(messages)
}

/// Dispatch a single line to the appropriate parser.
fn parse_line(line: &str, tool: &AiTool) -> Option<ChatMessage> {
    match tool {
        AiTool::Claude => claude_parser::parse_line(line),
        AiTool::Codex => codex_parser::parse_line(line),
    }
}

// ---------------------------------------------------------------------------
// Process-tree helpers
// ---------------------------------------------------------------------------

/// Ask tmux for the PID of the primary pane in the given target.
async fn get_pane_pid(target: &str) -> Result<u32> {
    let output = Command::new("tmux")
        .args(["display-message", "-t", target, "-p", "#{pane_pid}"])
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .await
        .context("failed to run tmux display-message")?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        bail!("tmux display-message failed: {stderr}");
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    let pid: u32 = stdout
        .trim()
        .parse()
        .with_context(|| format!("invalid pane PID: {stdout}"))?;

    Ok(pid)
}

/// Recursively collect all descendant PIDs of `parent_pid` via procfs.
///
/// This avoids shelling out to `ps` on every call and works on Linux by
/// scanning `/proc/*/stat` for processes whose PPID matches.
fn get_descendant_pids(parent_pid: u32) -> Result<Vec<u32>> {
    let mut result = vec![parent_pid];
    let mut queue = vec![parent_pid];

    while let Some(ppid) = queue.pop() {
        for child in direct_children(ppid) {
            result.push(child);
            queue.push(child);
        }
    }

    Ok(result)
}

/// Return the immediate child PIDs of `ppid` by scanning `/proc`.
fn direct_children(ppid: u32) -> Vec<u32> {
    let mut children = Vec::new();
    let Ok(entries) = std::fs::read_dir("/proc") else {
        return children;
    };

    for entry in entries.flatten() {
        let name = entry.file_name();
        let Some(pid) = name.to_str().and_then(|s| s.parse::<u32>().ok()) else {
            continue;
        };

        // /proc/<pid>/stat format: pid (comm) state ppid ...
        let stat_path = format!("/proc/{pid}/stat");
        let Ok(stat) = std::fs::read_to_string(&stat_path) else {
            continue;
        };

        // The comm field can contain spaces and parentheses, so find the last
        // ')' to locate the end of the comm field reliably.
        let Some(after_comm) = stat.rfind(')') else {
            continue;
        };
        let fields: Vec<&str> = stat[after_comm + 2..].split_whitespace().collect();
        // fields[0] = state, fields[1] = ppid
        if let Some(parent) = fields.get(1).and_then(|s| s.parse::<u32>().ok()) {
            if parent == ppid {
                children.push(pid);
            }
        }
    }

    children
}

/// Read the executable name for a given PID from `/proc/<pid>/comm`.
fn process_name(pid: u32) -> Option<String> {
    let path = format!("/proc/{pid}/comm");
    std::fs::read_to_string(path)
        .ok()
        .map(|s| s.trim().to_string())
}

/// Read the current working directory of a process via its `/proc` symlink.
fn get_process_cwd(pid: u32) -> Result<PathBuf> {
    let link = format!("/proc/{pid}/cwd");
    std::fs::read_link(&link)
        .with_context(|| format!("failed to read {link}"))
}

// ---------------------------------------------------------------------------
// Log file location helpers
// ---------------------------------------------------------------------------

/// Find the newest `.jsonl` file in Claude Code's project directory for the
/// given working directory.
///
/// Claude Code stores logs under `~/.claude/projects/<encoded_cwd>/` where
/// `<encoded_cwd>` is the absolute path with `/` replaced by `-` (with the
/// leading slash also replaced, so `/home/user/proj` becomes `-home-user-proj`
/// but the leading `-` is actually present in the directory name).
fn find_claude_log(cwd: &Path) -> Result<PathBuf> {
    let home = dirs::home_dir().context("cannot determine home directory")?;
    let encoded_cwd = cwd
        .to_str()
        .context("CWD is not valid UTF-8")?
        .replace('/', "-");
    let projects_dir = home.join(".claude").join("projects").join(&encoded_cwd);

    if !projects_dir.is_dir() {
        bail!(
            "Claude projects directory does not exist: {}",
            projects_dir.display()
        );
    }

    newest_jsonl_in(&projects_dir)
        .with_context(|| format!("no .jsonl files in {}", projects_dir.display()))
}

/// Find the newest `/tmp/webmux-codex-*.jsonl` file.
fn find_codex_log() -> Result<PathBuf> {
    let tmp = Path::new("/tmp");
    let mut best: Option<(std::time::SystemTime, PathBuf)> = None;

    for entry in std::fs::read_dir(tmp)?.flatten() {
        let name = entry.file_name();
        let Some(name_str) = name.to_str() else {
            continue;
        };
        if !name_str.starts_with("webmux-codex-") || !name_str.ends_with(".jsonl") {
            continue;
        }
        let Ok(meta) = entry.metadata() else {
            continue;
        };
        let Ok(modified) = meta.modified() else {
            continue;
        };
        if best.as_ref().is_none_or(|(t, _)| modified > *t) {
            best = Some((modified, entry.path()));
        }
    }

    best.map(|(_, p)| p)
        .context("no webmux-codex-*.jsonl files found in /tmp")
}

/// Return the path of the newest `.jsonl` file inside `dir`.
fn newest_jsonl_in(dir: &Path) -> Option<PathBuf> {
    let mut best: Option<(std::time::SystemTime, PathBuf)> = None;

    for entry in std::fs::read_dir(dir).ok()?.flatten() {
        let path = entry.path();
        if path.extension().and_then(|e| e.to_str()) != Some("jsonl") {
            continue;
        }
        let Ok(meta) = entry.metadata() else {
            continue;
        };
        let Ok(modified) = meta.modified() else {
            continue;
        };
        if best.as_ref().is_none_or(|(t, _)| modified > *t) {
            best = Some((modified, path));
        }
    }

    best.map(|(_, p)| p)
}

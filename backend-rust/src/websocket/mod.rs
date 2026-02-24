
use axum::{
    extract::{
        ws::{Message, WebSocket, WebSocketUpgrade},
        State,
    },
    response::IntoResponse,
};
use futures::{sink::SinkExt, stream::StreamExt};
use portable_pty::{native_pty_system, CommandBuilder, PtySize};
use std::{
    sync::Arc,
    io::{Read, Write},
    collections::HashMap,
};
use tokio::{
    sync::{mpsc, Mutex, RwLock},
    task::JoinHandle,
};
use tracing::{debug, error, info};
use uuid::Uuid;
use bytes::Bytes;

use crate::{
    audio,
    tmux,
    types::*,
    AppState,
};
use sysinfo::System;

type ClientId = String;

// Pre-serialized message for zero-copy broadcasting
#[derive(Clone)]
pub enum BroadcastMessage {
    Text(Arc<String>),
    Binary(Bytes),
}

// Client manager for broadcasting messages to all connected clients
pub struct ClientManager {
    clients: Arc<RwLock<HashMap<ClientId, mpsc::UnboundedSender<BroadcastMessage>>>>,
}

impl ClientManager {
    pub fn new() -> Self {
        Self {
            clients: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    pub async fn add_client(&self, client_id: ClientId, tx: mpsc::UnboundedSender<BroadcastMessage>) {
        let mut clients = self.clients.write().await;
        clients.insert(client_id, tx);
        info!("Client added. Total clients: {}", clients.len());
    }

    pub async fn remove_client(&self, client_id: &str) {
        let mut clients = self.clients.write().await;
        clients.remove(client_id);
        info!("Client removed. Total clients: {}", clients.len());
    }

    pub async fn broadcast(&self, message: ServerMessage) {
        // Serialize once for all clients
        if let Ok(serialized) = serde_json::to_string(&message) {
            let msg = BroadcastMessage::Text(Arc::new(serialized));
            let clients = self.clients.read().await;
            for (client_id, tx) in clients.iter() {
                if let Err(e) = tx.send(msg.clone()) {
                    error!("Failed to send to client {}: {}", client_id, e);
                }
            }
        }
    }
    
    pub async fn broadcast_binary(&self, data: Bytes) {
        let msg = BroadcastMessage::Binary(data);
        let clients = self.clients.read().await;
        for (client_id, tx) in clients.iter() {
            if let Err(e) = tx.send(msg.clone()) {
                error!("Failed to send binary to client {}: {}", client_id, e);
            }
        }
    }
}

struct PtySession {
    writer: Arc<Mutex<Box<dyn Write + Send>>>,
    master: Arc<Mutex<Box<dyn portable_pty::MasterPty + Send>>>,
    reader_task: JoinHandle<()>,
    child: Arc<Mutex<Box<dyn portable_pty::Child + Send>>>,
    tmux_session: String,
}

struct WsState {
    client_id: ClientId,
    current_pty: Arc<Mutex<Option<PtySession>>>,
    current_session: Arc<Mutex<Option<String>>>,
    audio_tx: Option<mpsc::UnboundedSender<BroadcastMessage>>,
    message_tx: mpsc::UnboundedSender<BroadcastMessage>,
    chat_log_handle: Arc<Mutex<Option<JoinHandle<()>>>>,
}

pub async fn ws_handler(
    ws: WebSocketUpgrade,
    State(state): State<Arc<AppState>>,
) -> impl IntoResponse {
    ws.on_upgrade(|socket| handle_socket(socket, state))
}

async fn handle_socket(socket: WebSocket, state: Arc<AppState>) {
    let client_id = Uuid::new_v4().to_string();
    info!("New WebSocket connection established: {}", client_id);

    let (mut sender, mut receiver) = socket.split();
    
    // Create channel for server messages
    let (tx, mut rx) = mpsc::unbounded_channel::<BroadcastMessage>();
    
    // Register client with the manager
    state.client_manager.add_client(client_id.clone(), tx.clone()).await;
    
    let mut ws_state = WsState {
        client_id: client_id.clone(),
        current_pty: Arc::new(Mutex::new(None)),
        current_session: Arc::new(Mutex::new(None)),
        audio_tx: None,
        message_tx: tx.clone(),
        chat_log_handle: Arc::new(Mutex::new(None)),
    };
    
    // Clone client_id for the spawned task
    let _task_client_id = client_id.clone();
    
    // Spawn task to forward server messages to WebSocket with backpressure handling
    tokio::spawn(async move {
        while let Some(msg) = rx.recv().await {
            match msg {
                BroadcastMessage::Text(json) => {
                    // Check if we can send without blocking
                    if let Err(e) = sender.send(Message::Text(json.to_string())).await {
                        error!("Failed to send message to WebSocket: {}", e);
                        break;
                    }
                    // Add small delay to prevent flooding
                    if json.contains("\"type\":\"output\"") && json.len() > 1000 {
                        tokio::time::sleep(tokio::time::Duration::from_micros(100)).await;
                    }
                }
                BroadcastMessage::Binary(data) => {
                    if let Err(e) = sender.send(Message::Binary(data.to_vec())).await {
                        error!("Failed to send binary to WebSocket: {}", e);
                        break;
                    }
                }
            }
        }
    });

    // Handle incoming messages
    while let Some(Ok(msg)) = receiver.next().await {
        match msg {
            Message::Text(text) => {
                if let Ok(ws_msg) = serde_json::from_str::<WebSocketMessage>(&text) {
                    if let Err(e) = handle_message(ws_msg, &mut ws_state).await {
                        error!("Error handling message: {}", e);
                    }
                }
            }
            Message::Close(_) => {
                info!("WebSocket connection closed: {}", client_id);
                break;
            }
            _ => {
                debug!("Ignoring WebSocket message type: {:?}", msg);
            }
        }
    }

    // Cleanup
    cleanup_session(&ws_state).await;
    state.client_manager.remove_client(&client_id).await;
}

async fn handle_message(
    msg: WebSocketMessage,
    state: &mut WsState,
) -> anyhow::Result<()> {
    match msg {
        WebSocketMessage::ListSessions => {
            let sessions = tmux::list_sessions().await.unwrap_or_default();
            let response = ServerMessage::SessionsList { sessions };
            send_message(&state.message_tx, response).await?;
        }
        
        WebSocketMessage::AttachSession { session_name, cols, rows } => {
            info!("Attaching to session: {}", session_name);
            attach_to_session(state, &session_name, cols, rows).await?;
        }
        
        WebSocketMessage::Input { data } => {
            let pty_opt = state.current_pty.lock().await;
            if let Some(ref pty) = *pty_opt {
                let mut writer = pty.writer.lock().await;
                if let Err(e) = writer.write_all(data.as_bytes()) {
                    error!("Failed to write to PTY: {}", e);
                    return Err(e.into());
                }
                writer.flush()?;
            } else {
                debug!("No PTY session active, ignoring input");
            }
        }
        
        WebSocketMessage::Resize { cols, rows } => {
            let pty_opt = state.current_pty.lock().await;
            if let Some(ref pty) = *pty_opt {
                let master = pty.master.lock().await;
                master.resize(PtySize {
                    rows,
                    cols,
                    pixel_width: 0,
                    pixel_height: 0,
                })?;
                debug!("Resized PTY to {}x{}", cols, rows);
            } else {
                debug!("No PTY session active, ignoring resize");
            }
        }
        
        WebSocketMessage::ListWindows { session_name } => {
            debug!("Listing windows for session: {}", session_name);
            match tmux::list_windows(&session_name).await {
                Ok(windows) => {
                    let response = ServerMessage::WindowsList { 
                        session_name: session_name.clone(),
                        windows 
                    };
                    send_message(&state.message_tx, response).await?;
                }
                Err(e) => {
                    error!("Failed to list windows for session {}: {}", session_name, e);
                    let response = ServerMessage::Error {
                        message: format!("Failed to list windows: {}", e),
                    };
                    send_message(&state.message_tx, response).await?;
                }
            }
        }
        
        WebSocketMessage::SelectWindow { session_name, window_index } => {
            debug!("Selecting window {} in session {}", window_index, session_name);
            
            // First, ensure we're in the right session
            let current_session = state.current_session.lock().await;
            if current_session.as_ref() != Some(&session_name) {
                drop(current_session);
                // Need to switch sessions first
                info!("Switching to session {} before selecting window", session_name);
                attach_to_session(state, &session_name, 80, 24).await?;
            }
            
            // Now select the window using tmux command
            match tmux::select_window(&session_name, &window_index.to_string()).await {
                Ok(_) => {
                    // Don't send keys to PTY - just use tmux command
                    // Sending keys can interfere with running programs like Claude Code
                    
                    let response = ServerMessage::WindowSelected {
                        success: true,
                        window_index: Some(window_index),
                        error: None,
                    };
                    send_message(&state.message_tx, response).await?;
                    
                    // Don't broadcast windows list - let frontend handle refreshing
                }
                Err(e) => {
                    let response = ServerMessage::WindowSelected {
                        success: false,
                        window_index: None,
                        error: Some(e.to_string()),
                    };
                    send_message(&state.message_tx, response).await?;
                }
            }
        }
        
        WebSocketMessage::Ping => {
            send_message(&state.message_tx, ServerMessage::Pong).await?;
        }
        
        WebSocketMessage::AudioControl { action } => {
            info!("Received audio control: {:?}", action);
            match action {
                AudioAction::Start => {
                    info!("Starting audio streaming for client");
                    let tx = state.message_tx.clone();
                    state.audio_tx = Some(tx.clone());
                    audio::start_streaming(tx).await?;
                }
                AudioAction::Stop => {
                    info!("Stopping audio streaming for client");
                    if let Some(ref tx) = state.audio_tx {
                        audio::stop_streaming_for_client(tx).await?;
                    }
                    state.audio_tx = None;
                }
            }
        }
        
        // Session management
        WebSocketMessage::CreateSession { name } => {
            let session_name = name.unwrap_or_else(|| format!("session-{}", chrono::Utc::now().timestamp_millis()));
            info!("Creating session: {}", session_name);
            
            match tmux::create_session(&session_name).await {
                Ok(_) => {
                    info!("Successfully created session: {}", session_name);
                    let response = ServerMessage::SessionCreated {
                        success: true,
                        session_name: Some(session_name),
                        error: None,
                    };
                    send_message(&state.message_tx, response).await?;
                }
                Err(e) => {
                    error!("Failed to create session: {}", e);
                    let response = ServerMessage::SessionCreated {
                        success: false,
                        session_name: None,
                        error: Some(format!("Failed to create session: {}", e)),
                    };
                    send_message(&state.message_tx, response).await?;
                }
            }
        }
        
        WebSocketMessage::KillSession { session_name } => {
            info!("Kill session request for: {}", session_name);
            
            match tmux::kill_session(&session_name).await {
                Ok(_) => {
                    info!("Successfully killed session: {}", session_name);
                    let response = ServerMessage::SessionKilled {
                        success: true,
                        error: None,
                    };
                    send_message(&state.message_tx, response).await?;
                }
                Err(e) => {
                    error!("Failed to kill session: {}", e);
                    let response = ServerMessage::SessionKilled {
                        success: false,
                        error: Some(format!("Failed to kill session: {}", e)),
                    };
                    send_message(&state.message_tx, response).await?;
                }
            }
        }
        
        WebSocketMessage::RenameSession { session_name, new_name } => {
            if new_name.trim().is_empty() {
                let response = ServerMessage::SessionRenamed {
                    success: false,
                    error: Some("Session name cannot be empty".to_string()),
                };
                send_message(&state.message_tx, response).await?;
            } else {
                match tmux::rename_session(&session_name, &new_name).await {
                    Ok(_) => {
                        let response = ServerMessage::SessionRenamed {
                            success: true,
                            error: None,
                        };
                        send_message(&state.message_tx, response).await?;
                    }
                    Err(e) => {
                        let response = ServerMessage::SessionRenamed {
                            success: false,
                            error: Some(format!("Failed to rename session: {}", e)),
                        };
                        send_message(&state.message_tx, response).await?;
                    }
                }
            }
        }
        
        // Window management
        WebSocketMessage::CreateWindow { session_name, window_name } => {
            match tmux::create_window(&session_name, window_name.as_deref()).await {
                Ok(_) => {
                    let response = ServerMessage::WindowCreated {
                        success: true,
                        error: None,
                    };
                    send_message(&state.message_tx, response).await?;
                }
                Err(e) => {
                    let response = ServerMessage::WindowCreated {
                        success: false,
                        error: Some(format!("Failed to create window: {}", e)),
                    };
                    send_message(&state.message_tx, response).await?;
                }
            }
        }
        
        WebSocketMessage::KillWindow { session_name, window_index } => {
            match tmux::kill_window(&session_name, &window_index).await {
                Ok(_) => {
                    let response = ServerMessage::WindowKilled {
                        success: true,
                        error: None,
                    };
                    send_message(&state.message_tx, response).await?;
                }
                Err(e) => {
                    let response = ServerMessage::WindowKilled {
                        success: false,
                        error: Some(format!("Failed to kill window: {}", e)),
                    };
                    send_message(&state.message_tx, response).await?;
                }
            }
        }
        
        WebSocketMessage::RenameWindow { session_name, window_index, new_name } => {
            if new_name.trim().is_empty() {
                let response = ServerMessage::WindowRenamed {
                    success: false,
                    error: Some("Window name cannot be empty".to_string()),
                };
                send_message(&state.message_tx, response).await?;
            } else {
                match tmux::rename_window(&session_name, &window_index, &new_name).await {
                    Ok(_) => {
                        let response = ServerMessage::WindowRenamed {
                            success: true,
                            error: None,
                        };
                        send_message(&state.message_tx, response).await?;
                    }
                    Err(e) => {
                        let response = ServerMessage::WindowRenamed {
                            success: false,
                            error: Some(format!("Failed to rename window: {}", e)),
                        };
                        send_message(&state.message_tx, response).await?;
                    }
                }
            }
        }
        
        // System stats
        WebSocketMessage::GetStats => {
            let mut sys = System::new_all();
            sys.refresh_all();

            let load_avg = System::load_average();
            let stats = SystemStats {
                cpu: CpuInfo {
                    cores: sys.cpus().len(),
                    model: sys.cpus().first().map(|c| c.brand().to_string()).unwrap_or_default(),
                    usage: load_avg.one as f32,
                    load_avg: [load_avg.one as f32, load_avg.five as f32, load_avg.fifteen as f32],
                },
                memory: MemoryInfo {
                    total: sys.total_memory(),
                    used: sys.used_memory(),
                    free: sys.available_memory(),
                    percent: format!("{:.1}", (sys.used_memory() as f64 / sys.total_memory() as f64) * 100.0),
                },
                uptime: System::uptime(),
                hostname: System::host_name().unwrap_or_default(),
                platform: std::env::consts::OS.to_string(),
                arch: std::env::consts::ARCH.to_string(),
            };

            let response = ServerMessage::Stats { stats };
            send_message(&state.message_tx, response).await?;
        }
        
        // Cron management
        WebSocketMessage::ListCronJobs => {
            let jobs = crate::cron::CRON_MANAGER.list_jobs().await;
            let response = ServerMessage::CronJobsList { jobs };
            send_message(&state.message_tx, response).await?;
        }
        
        WebSocketMessage::CreateCronJob { job } => {
            match crate::cron::CRON_MANAGER.create_job(job).await {
                Ok(created_job) => {
                    let response = ServerMessage::CronJobCreated { job: created_job };
                    send_message(&state.message_tx, response).await?;
                }
                Err(e) => {
                    let response = ServerMessage::Error { 
                        message: format!("Failed to create cron job: {}", e) 
                    };
                    send_message(&state.message_tx, response).await?;
                }
            }
        }
        
        WebSocketMessage::UpdateCronJob { id, job } => {
            match crate::cron::CRON_MANAGER.update_job(id, job).await {
                Ok(updated_job) => {
                    let response = ServerMessage::CronJobUpdated { job: updated_job };
                    send_message(&state.message_tx, response).await?;
                }
                Err(e) => {
                    let response = ServerMessage::Error { 
                        message: format!("Failed to update cron job: {}", e) 
                    };
                    send_message(&state.message_tx, response).await?;
                }
            }
        }
        
        WebSocketMessage::DeleteCronJob { id } => {
            match crate::cron::CRON_MANAGER.delete_job(&id).await {
                Ok(_) => {
                    let response = ServerMessage::CronJobDeleted { id };
                    send_message(&state.message_tx, response).await?;
                }
                Err(e) => {
                    let response = ServerMessage::Error { 
                        message: format!("Failed to delete cron job: {}", e) 
                    };
                    send_message(&state.message_tx, response).await?;
                }
            }
        }
        
        WebSocketMessage::ToggleCronJob { id, enabled } => {
            match crate::cron::CRON_MANAGER.toggle_job(&id, enabled).await {
                Ok(toggled_job) => {
                    let response = ServerMessage::CronJobUpdated { job: toggled_job };
                    send_message(&state.message_tx, response).await?;
                }
                Err(e) => {
                    let response = ServerMessage::Error { 
                        message: format!("Failed to toggle cron job: {}", e) 
                    };
                    send_message(&state.message_tx, response).await?;
                }
            }
        }
        
        WebSocketMessage::TestCronCommand { command } => {
            match crate::cron::CRON_MANAGER.test_command(&command).await {
                Ok(output) => {
                    let response = ServerMessage::CronCommandOutput { 
                        output, 
                        error: None 
                    };
                    send_message(&state.message_tx, response).await?;
                }
                Err(e) => {
                    let response = ServerMessage::CronCommandOutput { 
                        output: String::new(),
                        error: Some(format!("Failed to test command: {}", e)) 
                    };
                    send_message(&state.message_tx, response).await?;
                }
            }
        }
        
        // Dotfile management
        WebSocketMessage::ListDotfiles => {
            match crate::dotfiles::DOTFILES_MANAGER.list_dotfiles().await {
                Ok(files) => {
                    let response = ServerMessage::DotfilesList { files };
                    send_message(&state.message_tx, response).await?;
                }
                Err(e) => {
                    let response = ServerMessage::Error { 
                        message: format!("Failed to list dotfiles: {}", e) 
                    };
                    send_message(&state.message_tx, response).await?;
                }
            }
        }
        
        WebSocketMessage::ReadDotfile { path } => {
            match crate::dotfiles::DOTFILES_MANAGER.read_dotfile(&path).await {
                Ok(content) => {
                    let response = ServerMessage::DotfileContent { 
                        path, 
                        content,
                        error: None 
                    };
                    send_message(&state.message_tx, response).await?;
                }
                Err(e) => {
                    let response = ServerMessage::DotfileContent { 
                        path,
                        content: String::new(),
                        error: Some(format!("{}", e)) 
                    };
                    send_message(&state.message_tx, response).await?;
                }
            }
        }
        
        WebSocketMessage::WriteDotfile { path, content } => {
            match crate::dotfiles::DOTFILES_MANAGER.write_dotfile(&path, &content).await {
                Ok(_) => {
                    let response = ServerMessage::DotfileWritten { 
                        path,
                        success: true,
                        error: None 
                    };
                    send_message(&state.message_tx, response).await?;
                }
                Err(e) => {
                    let response = ServerMessage::DotfileWritten { 
                        path,
                        success: false,
                        error: Some(format!("{}", e)) 
                    };
                    send_message(&state.message_tx, response).await?;
                }
            }
        }
        
        WebSocketMessage::GetDotfileHistory { path } => {
            match crate::dotfiles::DOTFILES_MANAGER.get_file_history(&path).await {
                Ok(versions) => {
                    let response = ServerMessage::DotfileHistory { path, versions };
                    send_message(&state.message_tx, response).await?;
                }
                Err(e) => {
                    let response = ServerMessage::Error { 
                        message: format!("Failed to get dotfile history: {}", e) 
                    };
                    send_message(&state.message_tx, response).await?;
                }
            }
        }
        
        WebSocketMessage::RestoreDotfileVersion { path, timestamp } => {
            match crate::dotfiles::DOTFILES_MANAGER.restore_version(&path, timestamp).await {
                Ok(_) => {
                    let response = ServerMessage::DotfileRestored { 
                        path,
                        success: true,
                        error: None 
                    };
                    send_message(&state.message_tx, response).await?;
                }
                Err(e) => {
                    let response = ServerMessage::DotfileRestored { 
                        path,
                        success: false,
                        error: Some(format!("{}", e)) 
                    };
                    send_message(&state.message_tx, response).await?;
                }
            }
        }
        
        WebSocketMessage::GetDotfileTemplates => {
            let templates = crate::dotfiles::DOTFILES_MANAGER.get_templates();
            let response = ServerMessage::DotfileTemplates { templates };
            send_message(&state.message_tx, response).await?;
        }

        // Chat log watching
        WebSocketMessage::WatchChatLog { session_name, window_index } => {
            info!("Starting chat log watch for {}:{}", session_name, window_index);
            let message_tx = state.message_tx.clone();

            // Cancel any existing watcher
            {
                let mut handle_guard = state.chat_log_handle.lock().await;
                if let Some(handle) = handle_guard.take() {
                    handle.abort();
                }
            }

            let chat_log_handle = state.chat_log_handle.clone();
            let handle = tokio::spawn(async move {
                match crate::chat_log::watcher::detect_log_file(&session_name, window_index).await {
                    Ok((path, tool)) => {
                        let (event_tx, mut event_rx) = tokio::sync::mpsc::unbounded_channel();

                        // Spawn the file watcher -- the returned
                        // RecommendedWatcher must be kept alive for as long
                        // as we want notifications.
                        let _watcher = match crate::chat_log::watcher::watch_log_file(
                            &path, tool, event_tx,
                        ).await {
                            Ok(w) => w,
                            Err(e) => {
                                error!("Failed to start chat log watcher: {}", e);
                                let _ = send_message(&message_tx, ServerMessage::ChatLogError {
                                    error: e.to_string(),
                                }).await;
                                return;
                            }
                        };

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

            {
                let mut handle_guard = chat_log_handle.lock().await;
                *handle_guard = Some(handle);
            }
        }
        WebSocketMessage::UnwatchChatLog => {
            info!("Stopping chat log watch");
            let mut handle_guard = state.chat_log_handle.lock().await;
            if let Some(handle) = handle_guard.take() {
                handle.abort();
            }
        }
    }
    
    Ok(())
}

async fn send_message(tx: &mpsc::UnboundedSender<BroadcastMessage>, msg: ServerMessage) -> anyhow::Result<()> {
    if let Ok(json) = serde_json::to_string(&msg) {
        tx.send(BroadcastMessage::Text(Arc::new(json)))?;
    }
    Ok(())
}

async fn attach_to_session(
    state: &mut WsState,
    session_name: &str,
    cols: u16,
    rows: u16,
) -> anyhow::Result<()> {
    let tx = &state.message_tx;
    // Update current session
    {
        let mut current = state.current_session.lock().await;
        *current = Some(session_name.to_string());
    }
    
    // Clean up any existing PTY session first
    let mut pty_guard = state.current_pty.lock().await;
    if let Some(old_pty) = pty_guard.take() {
        debug!("Cleaning up previous PTY session for tmux: {}", old_pty.tmux_session);
        // Kill the child process
        {
            let mut child = old_pty.child.lock().await;
            let _ = child.kill();
            let _ = child.wait();
        }
        // Abort the reader task
        old_pty.reader_task.abort();
        let _ = old_pty.reader_task.await;
    }
    
    // Small delay to ensure cleanup is complete
    tokio::time::sleep(tokio::time::Duration::from_millis(50)).await;
    
    // Create new PTY session
    debug!("Creating new PTY session for: {}", session_name);
    
    let pty_system = native_pty_system();
    let pair = pty_system.openpty(PtySize {
        rows,
        cols,
        pixel_width: 0,
        pixel_height: 0,
    })?;
    
    let mut cmd = CommandBuilder::new("tmux");
    cmd.args(&["attach-session", "-t", session_name]);
    cmd.env("TERM", "xterm-256color");
    cmd.env("COLORTERM", "truecolor");
    
    // Clear SSH-related environment variables that might confuse starship
    cmd.env_remove("SSH_CLIENT");
    cmd.env_remove("SSH_CONNECTION");
    cmd.env_remove("SSH_TTY");
    cmd.env_remove("SSH_AUTH_SOCK");
    
    // Set up proper environment for local terminal
    cmd.env("WEBMUX", "1");
    
    // Get reader before we move master
    let reader = pair.master.try_clone_reader()?;
    
    // Get writer and spawn command
    let writer = pair.master.take_writer()?;
    let writer = Arc::new(Mutex::new(writer));
    
    // First check if session exists, if not create it
    let check_output = tokio::process::Command::new("tmux")
        .args(&["has-session", "-t", session_name])
        .output()
        .await?;
    
    if !check_output.status.success() {
        // Create the session first
        info!("Session {} doesn't exist, creating it", session_name);
        tmux::create_session(session_name).await?;
    }
    
    let child = pair.slave.spawn_command(cmd)?;
    let child: Arc<Mutex<Box<dyn portable_pty::Child + Send>>> = Arc::new(Mutex::new(child));
    
    // Set up reader task - DIRECT sending for now to fix the issue
    let tx_clone = tx.clone();
    let client_id = state.client_id.clone();
    let reader_task = tokio::task::spawn_blocking(move || {
        let mut reader = reader;
        let mut buffer = vec![0u8; 8192]; // Smaller buffer to prevent overwhelming
        let mut consecutive_errors = 0;
        let mut utf8_decoder = crate::terminal_buffer::Utf8StreamDecoder::new();
        let mut pending_output = String::with_capacity(16384);
        let mut last_send = std::time::Instant::now();
        let mut bytes_since_pause = 0usize;
        
        loop {
            match reader.read(&mut buffer) {
                Ok(0) => {
                    info!("PTY EOF for client {}", client_id);
                    // Send any pending output
                    if !pending_output.is_empty() {
                        let output = ServerMessage::Output { data: pending_output };
                        if let Ok(json) = serde_json::to_string(&output) {
                            let _ = tx_clone.send(BroadcastMessage::Text(Arc::new(json)));
                        }
                    }
                    break;
                }
                Ok(n) => {
                    consecutive_errors = 0;
                    
                    // Decode and accumulate
                    let (text, _) = utf8_decoder.decode_chunk(&buffer[..n]);
                    if !text.is_empty() {
                        pending_output.push_str(&text);
                        
                        bytes_since_pause += text.len();
                        
                        // More aggressive sending for better responsiveness
                        let should_send = pending_output.len() > 1024 || 
                                         last_send.elapsed() > std::time::Duration::from_millis(10) ||
                                         pending_output.contains('\n'); // Send on newlines
                        
                        if should_send && !pending_output.is_empty() {
                            let output = ServerMessage::Output { data: pending_output.clone() };
                            if let Ok(json) = serde_json::to_string(&output) {
                                if tx_clone.send(BroadcastMessage::Text(Arc::new(json))).is_err() {
                                    error!("Client {} disconnected, stopping PTY reader", client_id);
                                    break;
                                }
                            }
                            pending_output.clear();
                            last_send = std::time::Instant::now();
                            
                            // Flow control: pause if we're sending too much data
                            if bytes_since_pause > 65536 { // 64KB threshold
                                std::thread::sleep(std::time::Duration::from_millis(5));
                                bytes_since_pause = 0;
                            }
                        }
                    }
                }
                Err(e) => {
                    consecutive_errors += 1;
                    if consecutive_errors > 5 {
                        error!("Too many consecutive PTY read errors for client {}: {}", client_id, e);
                        break;
                    }
                    error!("PTY read error for client {} (attempt {}): {}", client_id, consecutive_errors, e);
                    std::thread::sleep(std::time::Duration::from_millis(100));
                }
            }
        }
        
        let disconnected = ServerMessage::Disconnected;
        if let Ok(json) = serde_json::to_string(&disconnected) {
            let _ = tx_clone.send(BroadcastMessage::Text(Arc::new(json)));
        }
    });
    
    let pty_session = PtySession {
        writer: writer.clone(),
        master: Arc::new(Mutex::new(pair.master)),
        reader_task,
        child,
        tmux_session: session_name.to_string(),
    };
    
    *pty_guard = Some(pty_session);
    drop(pty_guard);
    
    // Send attached confirmation
    let response = ServerMessage::Attached {
        session_name: session_name.to_string(),
    };
    send_message(tx, response).await?;
    
    Ok(())
}

async fn cleanup_session(state: &WsState) {
    info!("Cleaning up session for client: {}", state.client_id);
    
    // Clean up PTY session
    let mut pty_guard = state.current_pty.lock().await;
    if let Some(pty) = pty_guard.take() {
        info!("Cleaning up PTY for tmux session: {}", pty.tmux_session);
        
        // Kill the child process first
        {
            let mut child = pty.child.lock().await;
            let _ = child.kill();
            let _ = child.wait();
        }
        
        // Abort the reader task
        pty.reader_task.abort();
        
        // Writer and master will be dropped automatically
    }
    drop(pty_guard);
    
    // Clean up chat log watcher
    {
        let mut handle_guard = state.chat_log_handle.lock().await;
        if let Some(handle) = handle_guard.take() {
            handle.abort();
        }
    }

    // Clean up audio streaming
    if let Some(ref audio_tx) = state.audio_tx {
        if let Err(e) = audio::stop_streaming_for_client(audio_tx).await {
            error!("Failed to stop audio streaming: {}", e);
        }
    }
}

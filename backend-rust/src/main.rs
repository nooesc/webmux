use anyhow::Result;
use axum::{
    routing::get,
    Router,
};
use axum_server::tls_rustls::RustlsConfig;
use clap::Parser;
use std::{
    net::SocketAddr,
    path::PathBuf,
    sync::Arc,
};
use tokio::signal;
use tower_http::{
    cors::{Any, CorsLayer},
    services::{ServeDir, ServeFile},
};
use tracing::{error, info};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

mod audio;
mod chat_log;
mod cron;
mod dotfiles;
mod monitor;
mod terminal_buffer;
mod tmux;
mod types;
mod websocket;

// Global flag for audio logging
pub static ENABLE_AUDIO_LOGS: std::sync::atomic::AtomicBool = std::sync::atomic::AtomicBool::new(false);

#[derive(Parser, Debug)]
#[command(name = "webmux-backend")]
#[command(about = "WebMux backend server", long_about = None)]
struct Args {
    /// Enable audio streaming debug logs
    #[arg(long)]
    audio: bool,
}

use tokio::sync::mpsc;
use crate::types::ServerMessage;

#[derive(Clone)]
pub struct AppState {
    pub enable_audio_logs: bool,
    pub broadcast_tx: mpsc::UnboundedSender<ServerMessage>,
    pub client_manager: Arc<websocket::ClientManager>,
}

#[tokio::main]
async fn main() -> Result<()> {
    let args = Args::parse();
    // Initialize tracing
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "webmux_backend=debug,tower_http=info".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    // Set the global audio logging flag
    ENABLE_AUDIO_LOGS.store(args.audio, std::sync::atomic::Ordering::Relaxed);
    
    if args.audio {
        info!("Audio debug logging enabled");
    }
    
    // Create broadcast channel for tmux updates
    let (broadcast_tx, mut broadcast_rx) = mpsc::unbounded_channel::<ServerMessage>();
    
    // Create client manager
    let client_manager = Arc::new(websocket::ClientManager::new());
    let client_manager_clone = client_manager.clone();
    
    // Spawn task to forward broadcasts to all clients
    tokio::spawn(async move {
        while let Some(msg) = broadcast_rx.recv().await {
            client_manager_clone.broadcast(msg).await;
        }
    });
    
    let state = AppState {
        enable_audio_logs: args.audio,
        broadcast_tx: broadcast_tx.clone(),
        client_manager,
    };
    
    // Initialize CRON manager
    if let Err(e) = crate::cron::CRON_MANAGER.initialize().await {
        error!("Failed to initialize CRON manager: {}", e);
    }
    
    // Start tmux monitor
    let monitor = monitor::TmuxMonitor::new(broadcast_tx);
    tokio::spawn(async move {
        monitor.start().await;
    });

    // Serve static files from dist directory
    let serve_dir = ServeDir::new("../dist")
        .not_found_service(ServeFile::new("../dist/index.html"));

    // Build the router
    let app = Router::new()
        // WebSocket endpoint
        .route("/ws", get(websocket::ws_handler))
        // Serve static files (Vue app)
        .fallback_service(serve_dir)
        // Add CORS
        .layer(
            CorsLayer::new()
                .allow_origin(Any)
                .allow_methods(Any)
                .allow_headers(Any),
        )
        .with_state(Arc::new(state));

    // Dev branch uses different ports
    let http_port = 4000;
    let https_port = 4443;

    // Start HTTP server
    let http_addr = SocketAddr::from(([0, 0, 0, 0], http_port));
    info!("WebMux HTTP server running on {}", http_addr);
    info!("  Local:    http://localhost:{}", http_port);
    info!("  Network:  http://0.0.0.0:{}", http_port);

    // Check if HTTPS certificates exist
    let cert_path = PathBuf::from("../certs/cert.pem");
    let key_path = PathBuf::from("../certs/key.pem");

    if cert_path.exists() && key_path.exists() {
        // Start HTTPS server in a separate task
        let https_app = app.clone();
        tokio::spawn(async move {
            let https_addr = SocketAddr::from(([0, 0, 0, 0], https_port));
            let config = match RustlsConfig::from_pem_file(&cert_path, &key_path).await {
                Ok(config) => config,
                Err(e) => {
                    error!("Failed to load TLS certificates: {}", e);
                    return;
                }
            };

            info!("WebMux HTTPS server running on {}", https_addr);
            info!("  Local:    https://localhost:{}", https_port);
            info!("  Network:  https://0.0.0.0:{}", https_port);
            info!("  Tailscale: Use your Tailscale IP with port {}", https_port);
            info!("  Note: You may need to accept the self-signed certificate");

            if let Err(e) = axum_server::bind_rustls(https_addr, config)
                .serve(https_app.into_make_service())
                .await
            {
                error!("HTTPS server error: {}", e);
            }
        });
    } else {
        info!("Warning: Could not load SSL certificates from certs/");
        info!("HTTPS server will not be available");
    }

    // Run HTTP server with graceful shutdown
    let listener = tokio::net::TcpListener::bind(http_addr).await?;
    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await?;

    Ok(())
}

async fn shutdown_signal() {
    let ctrl_c = async {
        signal::ctrl_c()
            .await
            .expect("failed to install Ctrl+C handler");
    };

    #[cfg(unix)]
    let terminate = async {
        signal::unix::signal(signal::unix::SignalKind::terminate())
            .expect("failed to install signal handler")
            .recv()
            .await;
    };

    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        _ = ctrl_c => {
            info!("Received Ctrl+C, shutting down gracefully...");
        },
        _ = terminate => {
            info!("Received terminate signal, shutting down gracefully...");
        },
    }
}

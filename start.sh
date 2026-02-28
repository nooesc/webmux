#!/bin/bash
set -e

echo "Starting WebMux..."

# Kill any existing processes on our ports
echo "Cleaning up existing processes..."
lsof -ti :5174 -ti :5175 -ti :4010 2>/dev/null | xargs -r kill -9 2>/dev/null || true
pkill -9 -f "webmux-backend" 2>/dev/null || true
pkill -9 -f "cargo watch" 2>/dev/null || true
sleep 2

# Start the Rust backend in background
echo "Starting backend on port 4010..."
cd backend-rust && cargo run &
BACKEND_PID=$!

# Wait for backend to be ready
echo "Waiting for backend..."
for i in {1..30}; do
    if curl -s http://localhost:4010 >/dev/null 2>&1; then
        echo "Backend ready!"
        break
    fi
    sleep 1
done

# Start the Vue frontend in background
echo "Starting frontend on port 5174..."
npm run client &
FRONTEND_PID=$!

# Wait for frontend to be ready
echo "Waiting for frontend..."
for i in {1..30}; do
    if curl -s http://localhost:5174 >/dev/null 2>&1; then
        echo "Frontend ready!"
        break
    fi
    sleep 1
done

echo ""
echo "=========================================="
echo "WebMux is running!"
echo "  Frontend: http://localhost:5174"
echo "  Backend:  http://localhost:4010"
echo ""
echo "Network access:"
echo "  http://<YOUR-IP>:5174"
echo ""
echo "Press Ctrl+C to stop all services"
echo "=========================================="

# Wait for any process to exit
wait

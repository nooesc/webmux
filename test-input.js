const WebSocket = require('ws');

const WS_URL = 'ws://localhost:4010/ws';
const SESSION_NAME = 'Testing';
const WINDOW_INDEX = 0;

let ws;

function connect() {
  return new Promise((resolve, reject) => {
    ws = new WebSocket(WS_URL);

    ws.on('open', () => {
      console.log('✓ Connected to WebSocket');
      resolve();
    });

    ws.on('message', (data) => {
      try {
        const msg = JSON.parse(data.toString());
        console.log('← Received:', JSON.stringify(msg, null, 2));
      } catch (e) {
        console.log('← Received (raw):', data.toString());
      }
    });

    ws.on('error', (err) => {
      console.error('✗ WebSocket error:', err.message);
      reject(err);
    });

    ws.on('close', () => {
      console.log('✗ Disconnected');
    });
  });
}

function send(msg) {
  console.log('→ Sending:', JSON.stringify(msg));
  ws.send(JSON.stringify(msg));
}

function wait(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function attachToSession() {
  console.log('\n--- Attaching to session ---');
  send({
    type: 'attach-session',
    sessionName: SESSION_NAME,
    cols: 80,
    rows: 24,
    windowIndex: WINDOW_INDEX
  });
  await wait(500);
}

async function testInputViaPty() {
  console.log('\n=== TEST 1: Input via PTY (like Vue) ===');
  const testMessage = 'hello pty';
  send({
    type: 'input',
    data: testMessage + '\n'
  });
  await wait(1000);
}

async function testInputViaTmux() {
  console.log('\n=== TEST 2: Input via tmux send-keys ===');
  const testMessage = 'hello tmux';
  send({
    type: 'inputViaTmux',
    data: testMessage + '\n'
  });
  await wait(1000);
}

async function testInputViaTmuxWithEnter() {
  console.log('\n=== TEST 3: Input via tmux (text + Enter key) ===');
  const testMessage = 'hello enter';
  
  // Send text first
  send({
    type: 'inputViaTmux',
    data: testMessage
  });
  await wait(200);
  
  // Then send Enter
  send({
    type: 'sendEnterKey'
  });
  await wait(1000);
}

async function testInputViaTmuxLiteralNewline() {
  console.log('\n=== TEST 4: Input via tmux with literal \\n ===');
  const testMessage = 'hello literal newline';
  
  send({
    type: 'inputViaTmux',
    data: testMessage + '\n'
  });
  await wait(1000);
}

async function testDirectTmuxCommand() {
  console.log('\n=== TEST 5: Direct tmux command (control test) ===');
  const { exec } = require('child_process');
  
  // This is what the backend should be doing
  exec(`tmux send-keys -t ${SESSION_NAME}:${WINDOW_INDEX} "direct test" && tmux send-keys -t ${SESSION_NAME}:${WINDOW_INDEX} Enter`, (err, stdout, stderr) => {
    if (err) {
      console.error('Direct tmux error:', err.message);
    } else {
      console.log('✓ Direct tmux command sent');
    }
  });
  await wait(1000);
}

async function runTests() {
  try {
    await connect();
    await wait(500);
    
    await attachToSession();
    await wait(1000);
    
    console.log('\n========================================');
    console.log('Running tests - check tmux session output!');
    console.log('Session: ' + SESSION_NAME + ' Window: ' + WINDOW_INDEX);
    console.log('========================================\n');
    
    // Run tests one by one
    await testDirectTmuxCommand();
    await wait(2000);
    
    await testInputViaTmuxWithEnter();
    await wait(2000);
    
    await testInputViaTmux();
    await wait(2000);
    
    await testInputViaPty();
    await wait(2000);
    
    console.log('\n=== All tests complete ===');
    console.log('Check the tmux session "Testing" to see which test worked!');
    
    // Keep connection alive for a bit
    await wait(3000);
    ws.close();
    
  } catch (err) {
    console.error('Error:', err);
    if (ws) ws.close();
  }
}

runTests();

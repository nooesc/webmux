const WebSocket = require('ws');

const WS_URL = 'ws://localhost:4010/ws';

let ws;

function connect() {
  return new Promise((resolve, reject) => {
    ws = new WebSocket(WS_URL);

    ws.on('open', () => {
      console.log('✓ Connected');
      resolve();
    });

    ws.on('message', (data) => {
      try {
        const msg = JSON.parse(data.toString());
        console.log('← Received:', msg.type);
        if (msg.type === 'attached') {
          console.log('✓ Attached to session');
        }
      } catch (e) {}
    });

    ws.on('close', () => {
      console.log('✗ Disconnected');
    });
  });
}

async function runTest() {
  await connect();
  
  // Send attach-session first
  console.log('→ Sending attach-session...');
  ws.send(JSON.stringify({
    type: 'attach-session',
    sessionName: 'Testing',
    cols: 80,
    rows: 24,
    windowIndex: 0
  }));
  
  // Wait for attachment
  await new Promise(r => setTimeout(r, 2000));
  
  // Then send input WITH sessionName and windowIndex in the message
  console.log('→ Sending inputViaTmux with session info...');
  ws.send(JSON.stringify({
    type: 'inputViaTmux',
    sessionName: 'Testing',
    windowIndex: 0,
    data: 'hello ws test\n'
  }));
  
  await new Promise(r => setTimeout(r, 3000));
  ws.close();
}

runTest();

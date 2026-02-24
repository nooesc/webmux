# WebMux TypeScript Type Definitions

This directory contains comprehensive TypeScript type definitions for the WebMux project, providing type safety and better developer experience for both backend and frontend code.

## Structure

- **`index.ts`** - Core shared types used by both backend and frontend
- **`backend.ts`** - Node.js backend-specific types

## Usage

### In Backend Code (Node.js)

```typescript
// Import shared types
import { TmuxSession, TmuxWindow, ClientMessage, ServerMessage } from '../types';

// Import backend-specific types
import { ExtendedWebSocket, PtyProcess, WebMuxError, ErrorCode } from '../types/backend';

// Example: Type-safe WebSocket message handling
function handleMessage(ws: ExtendedWebSocket, message: ClientMessage) {
  switch (message.type) {
    case 'attach-session':
      // TypeScript knows message has sessionName, cols, rows
      attachToSession(ws, message.sessionName, { cols: message.cols, rows: message.rows });
      break;
    case 'input':
      // TypeScript knows message has data
      handleInput(ws, message.data);
      break;
  }
}
```

### In API Clients

```typescript
import { SessionsResponse, CreateSessionRequest, SystemStats } from '@/types';
import { tmuxApi } from '@/api/tmux';

// Type-safe API calls
async function fetchSessions(): Promise<TmuxSession[]> {
  const response: SessionsResponse = await tmuxApi.getSessions();
  return response.sessions;
}

async function createSession(request: CreateSessionRequest): Promise<void> {
  await tmuxApi.createSession(request.name);
}
```

## Type Categories

### Core Types
- **TMUX Types**: `TmuxSession`, `TmuxWindow`, `TmuxPane`
- **API Types**: Request/response interfaces for REST endpoints
- **WebSocket Types**: Message interfaces for real-time communication
- **Terminal Types**: Configuration for xterm.js

### Backend-Specific Types
- **PTY Types**: Process management and configuration
- **Server Types**: Express and WebSocket server configuration
- **Handler Types**: Message and request handlers
- **Error Types**: Custom error classes and error codes

## Type Guards

The types include helpful type guards for runtime type checking:

```typescript
import { isClientMessage, isServerMessage, isMessageType } from '@/types';

// Check if a message is a valid client message
if (isClientMessage(message)) {
  // message is typed as ClientMessage
}

// Check for specific message type
if (isMessageType(message, 'attach-session')) {
  // message is typed as AttachSessionMessage
  console.log(message.sessionName, message.cols, message.rows);
}
```

## Best Practices

1. **Import only what you need**: Use specific imports to keep bundle sizes small
2. **Use type guards**: Validate unknown data at runtime with provided type guards
3. **Extend interfaces**: Create project-specific extensions when needed
4. **Keep types in sync**: Update types when API or protocol changes

## Development

To check types without compiling:

```bash
cd types
npm run typecheck
```

## Contributing

When adding new types:
1. Place shared types in `index.ts`
2. Place backend-only types in `backend.ts`
3. Add JSDoc comments for better IDE support
4. Include type guards for runtime validation when appropriate

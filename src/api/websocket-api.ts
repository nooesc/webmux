import { wsManager } from '@/services/websocket'
import type { 
  TmuxSession, 
  TmuxWindow, 
  SessionCreateResponse, 
  SessionActionResponse,
  WindowCreateResponse,
  SystemStats,
  WsMessage 
} from '@/types'

// Request-response tracking
interface PendingRequest {
  resolve: (value: unknown) => void
  reject: (error: Error) => void
  timeout: NodeJS.Timeout
}

const pendingRequests = new Map<string, PendingRequest>()

// Helper to generate unique request IDs
let requestCounter = 0
function generateRequestId(type: string, context?: string): string {
  const contextStr = context ? `-${context.replace(/[^a-zA-Z0-9]/g, '_')}` : ''
  return `req-${type}${contextStr}-${Date.now()}-${++requestCounter}`
}

// Helper to send request and wait for response
async function sendRequest<T>(
  type: string, 
  data: Record<string, unknown> = {}, 
  responseType: string,
  timeout = 5000,
  context?: string
): Promise<T> {
  // Ensure WebSocket is connected
  await wsManager.ensureConnected()
  
  const requestId = generateRequestId(type, context)
  
  return new Promise<T>((resolve, reject) => {
    // Set up timeout
    const timeoutId = setTimeout(() => {
      pendingRequests.delete(requestId)
      reject(new Error(`Request ${type} timed out after ${timeout}ms`))
    }, timeout)
    
    // Store pending request
    pendingRequests.set(requestId, {
      resolve: (value: unknown) => resolve(value as T),
      reject,
      timeout: timeoutId
    })
    
    // Set up response handler
    const handler = (response: WsMessage) => {
      console.log(`Received ${responseType} response:`, response)
      // For windows-list, check if it's for the right session
      if (responseType === 'windows-list' && response.sessionName && context && response.sessionName !== context) {
        // This response is for a different session, ignore it
        return
      }
      
      const pending = pendingRequests.get(requestId)
      if (pending) {
        clearTimeout(pending.timeout)
        pendingRequests.delete(requestId)
        
        // Check for error responses
        if ('error' in response && response.error) {
          pending.reject(new Error(String(response.error)))
        } else {
          pending.resolve(response)
        }
      }
    }
    
    // Set up error handler
    const errorHandler = (response: WsMessage) => {
      const pending = pendingRequests.get(requestId)
      if (pending) {
        clearTimeout(pending.timeout)
        pendingRequests.delete(requestId)
        pending.reject(new Error(String(response.message || 'Unknown error')))
      }
    }
    
    // Register handlers
    wsManager.onMessage(responseType, handler)
    wsManager.onMessage('error', errorHandler)
    
    // Send the request
    console.log(`Sending ${type} request, waiting for ${responseType} response...`)
    wsManager.send({ type, ...data })
    
    // Clean up handlers after response or timeout
    setTimeout(() => {
      wsManager.offMessage(responseType, handler)
      wsManager.offMessage('error', errorHandler)
    }, timeout + 100)
  })
}

export const websocketApi = {
  // Session management
  async getSessions(): Promise<TmuxSession[]> {
    const response = await sendRequest<{ sessions: TmuxSession[] }>(
      'list-sessions',
      {},
      'sessions-list'
    )
    return response.sessions
  },

  async createSession(name?: string): Promise<SessionCreateResponse> {
    const response = await sendRequest<{ success: boolean; sessionName?: string; error?: string }>(
      'create-session',
      { name },
      'session-created'
    )
    return {
      success: response.success,
      sessionName: response.sessionName || '',
      message: response.error
    }
  },

  async killSession(sessionName: string): Promise<SessionActionResponse> {
    const response = await sendRequest<{ success: boolean; error?: string }>(
      'kill-session',
      { sessionName },
      'session-killed'
    )
    return {
      success: response.success,
      message: response.error
    }
  },

  async renameSession(sessionName: string, newName: string): Promise<SessionActionResponse> {
    const response = await sendRequest<{ success: boolean; error?: string }>(
      'rename-session',
      { sessionName, newName },
      'session-renamed'
    )
    return {
      success: response.success,
      message: response.error
    }
  },

  // Window management
  async getWindows(sessionName: string): Promise<TmuxWindow[]> {
    const response = await sendRequest<{ sessionName: string; windows: TmuxWindow[] }>(
      'list-windows',
      { sessionName },
      'windows-list',
      5000,
      sessionName
    )
    // Validate that we got windows for the correct session
    if (response.sessionName !== sessionName) {
      throw new Error(`Received windows for wrong session: expected ${sessionName}, got ${response.sessionName}`)
    }
    return response.windows
  },

  async createWindow(sessionName: string, windowName?: string): Promise<WindowCreateResponse> {
    const response = await sendRequest<{ success: boolean; error?: string }>(
      'create-window',
      { sessionName, windowName },
      'window-created'
    )
    return {
      success: response.success,
      message: response.error
    }
  },

  async killWindow(sessionName: string, windowIndex: number): Promise<SessionActionResponse> {
    const response = await sendRequest<{ success: boolean; error?: string }>(
      'kill-window',
      { sessionName, windowIndex: windowIndex.toString() },
      'window-killed'
    )
    return {
      success: response.success,
      message: response.error
    }
  },

  async renameWindow(sessionName: string, windowIndex: number, newName: string): Promise<SessionActionResponse> {
    const response = await sendRequest<{ success: boolean; error?: string }>(
      'rename-window',
      { sessionName, windowIndex: windowIndex.toString(), newName },
      'window-renamed'
    )
    return {
      success: response.success,
      message: response.error
    }
  },

  // System stats
  async getStats(): Promise<SystemStats> {
    const response = await sendRequest<{ stats: SystemStats }>(
      'get-stats',
      {},
      'stats'
    )
    return response.stats
  }
}

// Clean up any pending requests on WebSocket disconnect
wsManager.onDisconnect(() => {
  pendingRequests.forEach((pending) => {
    clearTimeout(pending.timeout)
    pending.reject(new Error('WebSocket disconnected'))
  })
  pendingRequests.clear()
})
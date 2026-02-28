<template>
  <div class="debug-screen">
    <header class="border-b safe-area-top" style="background: var(--bg-secondary); border-color: var(--border-primary)">
      <div class="px-3 py-2 flex items-center justify-between">
        <div class="flex items-center space-x-2">
          <button @click="emit('close')" class="p-1" style="color: var(--text-tertiary)">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
          <h1 class="text-sm font-medium">Debug Info</h1>
        </div>
        <button @click="refresh" class="p-1" style="color: var(--text-tertiary)" title="Refresh">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
          </svg>
        </button>
      </div>
    </header>

    <div class="p-3 space-y-4 overflow-y-auto" style="max-height: calc(100vh - 50px)">
      <!-- Connection Status -->
      <div class="rounded-lg p-3" :style="{ background: ws.isConnected.value ? '#22c55e20' : '#ef444420', border: '1px solid', borderColor: ws.isConnected.value ? '#22c55e' : '#ef4444' }">
        <div class="flex items-center space-x-2">
          <div class="w-2 h-2 rounded-full" :style="{ background: ws.isConnected.value ? '#22c55e' : '#ef4444' }"></div>
          <span class="font-medium" :style="{ color: ws.isConnected.value ? '#22c55e' : '#ef4444' }">
            {{ ws.isConnected.value ? 'Connected' : 'Disconnected' }}
          </span>
        </div>
        <div v-if="ws.connectionError.value" class="mt-2 text-xs" style="color: #ef4444">
          {{ ws.connectionError.value }}
        </div>
      </div>

      <!-- WebSocket URL -->
      <div class="rounded-lg p-3" style="background: var(--bg-secondary); border: 1px solid var(--border-primary)">
        <h3 class="text-xs font-medium mb-2" style="color: var(--text-secondary)">WebSocket URL</h3>
        <code class="text-xs break-all" style="color: var(--text-primary)">{{ wsUrl }}</code>
        <button @click="copyToClipboard(wsUrl)" class="mt-2 text-xs" style="color: var(--accent-primary)">Copy URL</button>
      </div>

      <!-- Connection Settings -->
      <div class="rounded-lg p-3" style="background: var(--bg-secondary); border: 1px solid var(--border-primary)">
        <h3 class="text-xs font-medium mb-2" style="color: var(--text-secondary)">Settings</h3>
        <div class="space-y-1 text-xs">
          <div class="flex justify-between">
            <span style="color: var(--text-tertiary)">Backend IP:</span>
            <span style="color: var(--text-primary)">{{ HARDCODED_BACKEND }}</span>
          </div>
          <div class="flex justify-between">
            <span style="color: var(--text-tertiary)">Protocol:</span>
            <span style="color: var(--text-primary)">ws:// (HTTP)</span>
          </div>
          <div class="flex justify-between">
            <span style="color: var(--text-tertiary)">Reconnect Attempts:</span>
            <span style="color: var(--text-primary)">{{ reconnectAttempts }} / {{ maxReconnectAttempts }}</span>
          </div>
        </div>
      </div>

      <!-- Test Connectivity -->
      <div class="rounded-lg p-3" style="background: var(--bg-secondary); border: 1px solid var(--border-primary)">
        <h3 class="text-xs font-medium mb-2" style="color: var(--text-secondary)">Test Connectivity</h3>
        <button 
          @click="testHttpConnection" 
          :disabled="testing"
          class="w-full py-2 text-xs rounded font-medium"
          style="background: var(--accent-primary); color: var(--bg-primary)"
        >
          {{ testing ? 'Testing...' : 'Test HTTP Connection' }}
        </button>
        <div v-if="httpTestResult" class="mt-2 text-xs" :style="{ color: httpTestSuccess ? '#22c55e' : '#ef4444' }">
          {{ httpTestResult }}
        </div>
      </div>

      <!-- Server Info from API -->
      <div class="rounded-lg p-3" style="background: var(--bg-secondary); border: 1px solid var(--border-primary)">
        <h3 class="text-xs font-medium mb-2" style="color: var(--text-secondary)">Server Info</h3>
        <div v-if="serverInfo" class="space-y-1 text-xs">
          <div class="flex justify-between">
            <span style="color: var(--text-tertiary)">Connected Clients:</span>
            <span style="color: var(--text-primary)">{{ serverInfo.clients }}</span>
          </div>
        </div>
        <div v-else class="text-xs" style="color: var(--text-tertiary)">
          Unable to fetch server info
        </div>
        <button 
          @click="fetchServerInfo" 
          class="mt-2 text-xs"
          style="color: var(--accent-primary)"
        >
          Refresh Server Info
        </button>
      </div>

      <!-- Device Info -->
      <div class="rounded-lg p-3" style="background: var(--bg-secondary); border: 1px solid var(--border-primary)">
        <h3 class="text-xs font-medium mb-2" style="color: var(--text-secondary)">Device Info</h3>
        <div class="space-y-1 text-xs">
          <div class="flex justify-between">
            <span style="color: var(--text-tertiary)">Platform:</span>
            <span style="color: var(--text-primary)">{{ deviceInfo.platform }}</span>
          </div>
          <div class="flex justify-between">
            <span style="color: var(--text-tertiary)">User Agent:</span>
            <span style="color: var(--text-primary)">{{ deviceInfo.userAgent }}</span>
          </div>
          <div class="flex justify-between">
            <span style="color: var(--text-tertiary)">App Version:</span>
            <span style="color: var(--text-primary)">1.0.0</span>
          </div>
        </div>
      </div>

      <!-- Network Info -->
      <div class="rounded-lg p-3" style="background: var(--bg-secondary); border: 1px solid var(--border-primary)">
        <h3 class="text-xs font-medium mb-2" style="color: var(--text-secondary)">Network</h3>
        <div class="space-y-1 text-xs">
          <div class="flex justify-between">
            <span style="color: var(--text-tertiary)">Online:</span>
            <span style="color: var(--text-primary)">{{ isOnline }}</span>
          </div>
          <div class="flex justify-between">
            <span style="color: var(--text-tertiary)">Protocol:</span>
            <span style="color: var(--text-primary)">{{ locationProtocol }}</span>
          </div>
          <div class="flex justify-between">
            <span style="color: var(--text-tertiary)">Host:</span>
            <span style="color: var(--text-primary)">{{ locationHost }}</span>
          </div>
        </div>
      </div>

      <!-- Log -->
      <div class="rounded-lg p-3" style="background: var(--bg-secondary); border: 1px solid var(--border-primary)">
        <div class="flex items-center justify-between mb-2">
          <h3 class="text-xs font-medium" style="color: var(--text-secondary)">Connection Log</h3>
          <button @click="clearLog" class="text-xs" style="color: var(--text-tertiary)">Clear</button>
        </div>
        <div class="text-xs font-mono space-y-1 max-h-40 overflow-y-auto" style="color: var(--text-primary)">
          <div v-for="(entry, i) in logs" :key="i" :style="{ color: entry.color }">
            {{ entry.time }} - {{ entry.msg }}
          </div>
          <div v-if="logs.length === 0" style="color: var(--text-tertiary)">No logs yet</div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted, computed } from 'vue'
import { wsManager } from '@/services/websocket'

const emit = defineEmits(['close'])

const ws = wsManager
const HARDCODED_BACKEND = '192.168.0.76:4010'
const wsUrl = `ws://${HARDCODED_BACKEND}/ws`
const maxReconnectAttempts = 5
const reconnectAttempts = ref(0)
const testing = ref(false)
const httpTestResult = ref('')
const httpTestSuccess = ref(false)
const serverInfo = ref<{ clients: string } | null>(null)

const deviceInfo = {
  platform: (globalThis.navigator as any).platform || 'Unknown',
  userAgent: globalThis.navigator.userAgent
}

const isOnline = computed(() => globalThis.navigator.onLine)
const locationProtocol = computed(() => globalThis.window.location.protocol)
const locationHost = computed(() => globalThis.window.location.host)

const logs = ref<Array<{ time: string; msg: string; color: string }>>([])

const addLog = (msg: string, color: string = 'var(--text-primary)') => {
  const time = new Date().toLocaleTimeString()
  logs.value.push({ time, msg, color })
  if (logs.value.length > 100) {
    logs.value.shift()
  }
}

const clearLog = () => {
  logs.value = []
}

const refresh = () => {
  fetchServerInfo()
  reconnectAttempts.value = (wsManager as any).reconnectAttempts || 0
}

const testHttpConnection = async () => {
  testing.value = true
  httpTestResult.value = ''
  
  const url = `http://${HARDCODED_BACKEND}/api/clients`
  addLog(`Testing HTTP: ${url}`, 'var(--text-secondary)')
  
  const start = Date.now()
  
  try {
    const controller = new AbortController()
    const timeout = setTimeout(() => controller.abort(), 10000)
    
    await fetch(url, { 
      mode: 'no-cors',
      signal: controller.signal 
    })
    
    clearTimeout(timeout)
    const duration = Date.now() - start
    
    httpTestSuccess.value = true
    httpTestResult.value = `Success! (${duration}ms) - App can reach the server`
    addLog(`HTTP test: Success (${duration}ms)`, '#22c55e')
  } catch (err: any) {
    const duration = Date.now() - start
    httpTestSuccess.value = false
    httpTestResult.value = `Failed: ${err.message} (${duration}ms)`
    addLog(`HTTP test: Failed - ${err.message}`, '#ef4444')
  }
  
  testing.value = false
}

const fetchServerInfo = async () => {
  try {
    const url = `http://${HARDCODED_BACKEND}/api/clients`
    await fetch(url, { mode: 'no-cors' })
    // With no-cors, we can't read the response, but if it doesn't throw, it worked
    serverInfo.value = { clients: 'Unknown (CORS blocked)' }
    addLog('Server info: Fetch succeeded (CORS prevented reading response)', '#22c55e')
  } catch (err: any) {
    serverInfo.value = null
    addLog(`Server info: Failed - ${err.message}`, '#ef4444')
  }
}

const copyToClipboard = async (text: string) => {
  try {
    await globalThis.navigator.clipboard.writeText(text)
    addLog('URL copied to clipboard', '#22c55e')
  } catch {
    addLog('Failed to copy URL', '#ef4444')
  }
}

// Intercept console.log and console.error to capture logs
const originalLog = console.log
const originalError = console.error

console.log = (...args) => {
  const msg = args.map(a => typeof a === 'object' ? JSON.stringify(a) : String(a)).join(' ')
  addLog(msg, 'var(--text-primary)')
  originalLog.apply(console, args)
}

console.error = (...args) => {
  const msg = args.map(a => typeof a === 'object' ? JSON.stringify(a) : String(a)).join(' ')
  addLog(msg, '#ef4444')
  originalError.apply(console, args)
}

onMounted(() => {
  addLog('Debug screen opened', '#22c55e')
  addLog(`WS URL: ${wsUrl}`, 'var(--text-secondary)')
  addLog(`Backend: ${HARDCODED_BACKEND}`, 'var(--text-secondary)')
  fetchServerInfo()
})

onUnmounted(() => {
  console.log = originalLog
  console.error = originalError
})
</script>

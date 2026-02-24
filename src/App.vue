<template>
  <div class="min-h-screen" style="background: var(--bg-primary)">
    <header class="border-b safe-area-top" style="background: var(--bg-secondary); border-color: var(--border-primary)">
      <div class="px-4 safe-area-left safe-area-right">
        <div class="flex items-center justify-between h-12">
          <div class="flex items-center space-x-3 md:space-x-6">
            <button
              @click="toggleSidebar"
              class="p-1.5 hover-bg rounded ml-1"
              style="color: var(--text-tertiary)"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
              </svg>
            </button>
            <h1 class="text-sm font-medium">webmux</h1>
            <div class="hidden sm:flex items-center space-x-4 text-xs" style="color: var(--text-secondary)">
              <span class="hidden md:inline">{{ stats.hostname }}</span>
              <span>{{ stats.platform }}/{{ stats.arch }}</span>
            </div>
            <div class="view-toggle">
              <button
                :class="{ active: viewMode === 'terminal' }"
                @click="viewMode = 'terminal'"
              >Terminal</button>
              <button
                :class="{ active: viewMode === 'chat' }"
                @click="viewMode = 'chat'"
              >Chat</button>
            </div>
          </div>

          <!-- Search Bar - Center section with fixed max width -->
          <div class="flex-1 flex justify-center px-2">
            <div class="relative w-full max-w-xs">
              <input
                v-model="searchQuery"
                @focus="showSearchResults = true"
                @blur="handleSearchBlur"
                @keydown.escape="closeSearch"
                @keydown.enter="selectFirstResult"
                @keydown.down.prevent="navigateResults(1)"
                @keydown.up.prevent="navigateResults(-1)"
                type="text"
                placeholder="Search windows... (⌘K)"
                class="w-full px-3 py-1 text-xs rounded-md focus:outline-none focus:ring-1 transition-all duration-150"
                :class="showSearchResults ? 'ring-1' : ''"
                style="background: var(--bg-primary); border: 1px solid var(--border-secondary); color: var(--text-primary); --tw-ring-color: var(--accent-primary)"
                ref="searchInput"
              />
              <div class="absolute inset-y-0 right-0 flex items-center pr-3 pointer-events-none">
                <svg class="w-3.5 h-3.5" style="color: var(--text-tertiary)" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                </svg>
              </div>
              
              <!-- Search Results Dropdown -->
              <transition name="fade">
                <div
                  v-if="showSearchResults && filteredWindows.length > 0"
                  class="absolute top-full left-0 right-0 mt-1 rounded-md shadow-lg overflow-hidden z-50"
                  style="background: var(--bg-secondary); border: 1px solid var(--border-primary)"
                >
                  <div class="max-h-64 overflow-y-auto">
                    <button
                      v-for="(item, index) in filteredWindows"
                      :key="`${item.sessionName}-${item.window.index}`"
                      v-memo="[item.window.name, item.sessionName, selectedIndex === index]"
                      @mousedown.prevent="selectWindow(item)"
                      @mouseenter="selectedIndex = index"
                      class="w-full px-3 py-2 text-left hover-bg transition-colors text-xs"
                      :class="{ 'bg-opacity-50': selectedIndex === index }"
                      :style="selectedIndex === index ? 'background: var(--bg-tertiary)' : ''"
                    >
                      <div class="flex items-center space-x-1">
                        <span style="color: var(--text-secondary)">{{ item.sessionName }}</span>
                        <span style="color: var(--text-tertiary)">/</span>
                        <span class="font-medium" style="color: var(--text-primary)">{{ item.window.name }}</span>
                        <span style="color: var(--text-tertiary)">&</span>
                        <span style="color: var(--text-secondary)">{{ item.window.panes }} {{ item.window.panes === 1 ? 'pane' : 'panes' }}</span>
                        <span v-if="item.window.active && item.sessionName === currentSession" 
                              class="w-1.5 h-1.5 rounded-full ml-2" 
                              style="background: var(--accent-primary)"></span>
                      </div>
                    </button>
                  </div>
                </div>
              </transition>
            </div>
          </div>
          
          <div class="flex items-center space-x-3 md:space-x-6 text-xs">
            <div class="flex items-center space-x-2 md:space-x-4">
              <div class="flex items-center space-x-1 md:space-x-2">
                <span class="hidden sm:inline" style="color: var(--text-tertiary)">CPU</span>
                <span class="stat-badge">{{ stats.cpu.loadAvg?.[0]?.toFixed(2) || '0.00' }}</span>
              </div>
              <div class="flex items-center space-x-1 md:space-x-2">
                <span class="hidden sm:inline" style="color: var(--text-tertiary)">MEM</span>
                <span class="stat-badge">{{ formatBytes(stats.memory.used) }}</span>
                <span class="hidden md:inline" style="color: var(--text-tertiary)">/ {{ formatBytes(stats.memory.total) }}</span>
                <span class="text-xs" style="color: var(--text-tertiary)">({{ stats.memory.percent }}%)</span>
              </div>
              <div class="hidden sm:flex items-center space-x-2">
                <span style="color: var(--text-tertiary)">UP</span>
                <span class="stat-badge">{{ formatUptime(stats.uptime) }}</span>
              </div>
            </div>
            <div class="text-xs pr-1" style="color: var(--text-tertiary)">
              {{ currentTime }}
            </div>
          </div>
        </div>
      </div>
    </header>

    <div class="flex h-[calc(100vh-3rem)]">
      <!-- Mobile: Backdrop when sidebar is open -->
      <div 
        v-if="isMobile && !sidebarCollapsed" 
        class="fixed top-0 left-0 right-0 bottom-0 bg-black bg-opacity-50 z-40 md:hidden"
        @click="sidebarCollapsed = true"
      ></div>
      
      <!-- Desktop: Normal sidebar that pushes content -->
      <!-- Mobile: Overlay sidebar -->
      <SessionList 
        v-show="!sidebarCollapsed || !isMobile"
        :sessions="sessions || []" 
        :currentSession="currentSession"
        :isCollapsed="sidebarCollapsed && !isMobile"
        :isMobile="isMobile"
        :isLoading="isLoading"
        @select="selectSession"
        @create="handleCreateSession"
        @kill="handleKillSession"
        @rename="handleRenameSession"
        @select-window="handleSelectWindow"
        @toggle-sidebar="toggleSidebar"
        :class="isMobile ? 'fixed left-0 top-12 bottom-0 z-50 w-64' : ''"
      />
      
      <main class="flex-1 min-w-0 overflow-hidden" style="background: var(--bg-primary)">
        <TerminalView
          v-if="currentSession"
          v-show="viewMode === 'terminal'"
          :session="currentSession"
          :ws="ws"
          class="h-full"
        />
        <ChatView
          v-if="currentSession"
          v-show="viewMode === 'chat'"
          :session="currentSession"
          :window-index="currentWindowIndex"
          :ws="ws"
          class="h-full"
          @switch-to-terminal="viewMode = 'terminal'"
        />
        <div v-if="!currentSession" class="flex items-center justify-center h-full">
          <div class="text-center p-4">
            <p class="text-sm mb-2" style="color: var(--text-secondary)">No active session</p>
            <p class="text-xs mb-4" style="color: var(--text-tertiary)">Select or create a tmux session</p>
          </div>
        </div>
      </main>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted, computed, watch } from 'vue'
import { useQuery, useQueryClient } from '@tanstack/vue-query'
import { useWebSocket } from './composables/useWebSocket'
import { websocketApi } from './api/websocket-api'
import SessionList from './components/SessionList.vue'
import TerminalView from './components/TerminalView.vue'
import ChatView from './components/ChatView.vue'
import type { TmuxSession, SystemStats, SessionsListMessage, WindowSelectedMessage, TmuxWindow } from './types'

const queryClient = useQueryClient()
const currentSession = ref<string | null>(null)
const viewMode = ref<'terminal' | 'chat'>('terminal')
const currentWindowIndex = ref<number>(0)
const sidebarCollapsed = ref<boolean>(false)
const windowWidth = ref<number>(window.innerWidth)
const ws = useWebSocket()
const currentTime = ref<string>('')

// Search functionality
const searchQuery = ref('')
const showSearchResults = ref(false)
const selectedIndex = ref(0)
const searchInput = ref<HTMLInputElement>()
const allWindows = ref<Array<{ sessionName: string, window: TmuxWindow }>>([])
let searchDebounceTimeout: ReturnType<typeof setTimeout> | null = null

const stats = ref<SystemStats>({
  uptime: 0,
  hostname: '',
  platform: '',
  arch: '',
  cpu: {
    model: '',
    cores: 0,
    usage: 0,
    loadAvg: [0, 0, 0]
  },
  memory: {
    total: 0,
    used: 0,
    free: 0,
    percent: '0'
  }
})

// Mobile detection
const isMobile = computed(() => windowWidth.value < 768) // md breakpoint


// Debounced search query
const debouncedSearchQuery = ref('')

// Watch search query and debounce it
watch(searchQuery, (newQuery) => {
  if (searchDebounceTimeout) clearTimeout(searchDebounceTimeout)
  searchDebounceTimeout = setTimeout(() => {
    debouncedSearchQuery.value = newQuery
  }, 150)
})

// Computed property for filtered windows using debounced query
const filteredWindows = computed(() => {
  if (!debouncedSearchQuery.value.trim()) return []
  const query = debouncedSearchQuery.value.toLowerCase()
  return allWindows.value.filter(item => 
    item.window.name.toLowerCase().includes(query) ||
    item.sessionName.toLowerCase().includes(query)
  )
})

// Fetch system stats
const fetchStats = async (): Promise<void> => {
  try {
    stats.value = await websocketApi.getStats()
  } catch (error) {
    console.error('Failed to fetch stats:', error)
  }
}


// Update clock and stats
let updateInterval: ReturnType<typeof setInterval> | undefined
let statsInterval: ReturnType<typeof setInterval> | undefined
let handleKeydown: ((e: KeyboardEvent) => void) | undefined
let handleResize: (() => void) | undefined

onMounted(() => {
  // Initialize sidebar state - collapsed on mobile, expanded on desktop
  sidebarCollapsed.value = isMobile.value
  
  fetchStats()
  // Update time every second
  updateInterval = setInterval(() => {
    currentTime.value = new Date().toLocaleTimeString('en-US', { 
      hour12: false,
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit'
    })
  }, 1000)
  
  // Update stats less frequently for better performance
  statsInterval = setInterval(() => {
    fetchStats()
  }, 5000)
  
  // Add keyboard shortcut for search (Cmd/Ctrl + K)
  handleKeydown = (e: KeyboardEvent) => {
    if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
      e.preventDefault()
      searchInput.value?.focus()
      showSearchResults.value = true
    }
  }
  window.addEventListener('keydown', handleKeydown)
  
  // Handle window resize for mobile detection
  handleResize = () => {
    windowWidth.value = window.innerWidth
  }
  window.addEventListener('resize', handleResize)
})

onUnmounted(() => {
  if (updateInterval) clearInterval(updateInterval)
  if (statsInterval) clearInterval(statsInterval)
  if (searchDebounceTimeout) clearTimeout(searchDebounceTimeout)
  if (handleKeydown) window.removeEventListener('keydown', handleKeydown)
  if (handleResize) window.removeEventListener('resize', handleResize)
})

// Format helpers
const formatBytes = (bytes: number): string => {
  if (!bytes) return '0B'
  const units = ['B', 'KB', 'MB', 'GB', 'TB']
  const i = Math.floor(Math.log(bytes) / Math.log(1024))
  return `${(bytes / Math.pow(1024, i)).toFixed(1)}${units[i]}`
}

const formatUptime = (seconds: number): string => {
  if (!seconds) return '0s'
  const days = Math.floor(seconds / 86400)
  const hours = Math.floor((seconds % 86400) / 3600)
  const minutes = Math.floor((seconds % 3600) / 60)
  if (days > 0) return `${days}d ${hours}h`
  if (hours > 0) return `${hours}h ${minutes}m`
  return `${minutes}m`
}

const { data: sessions = [], isLoading } = useQuery({
  queryKey: ['sessions'],
  queryFn: async () => {
    console.log('Fetching sessions...')
    const result = await websocketApi.getSessions()
    console.log('Sessions fetched:', result)
    return result
  },
  refetchInterval: 60000, // Reduced to 60s as fallback since we have real-time updates
  staleTime: 5000 // Cache for 5 seconds
})

// Update window list whenever sessions change
const updateWindowList = async (): Promise<void> => {
  const windowList: Array<{ sessionName: string, window: TmuxWindow }> = []
  
  const sessionList = Array.isArray(sessions) ? sessions : sessions.value
  if (sessionList) {
    for (const session of sessionList) {
    try {
      const windows = await websocketApi.getWindows(session.name)
      windows.forEach(window => {
        windowList.push({ sessionName: session.name, window })
      })
    } catch (err) {
      console.error(`Failed to get windows for session ${session.name}:`, err)
    }
  }
  }
  
  allWindows.value = windowList
}

// Watch sessions and update window list
watch(() => Array.isArray(sessions) ? sessions : sessions.value, () => {
  updateWindowList()
}, { immediate: true, deep: true })


const handleCreateSession = async (sessionName: string): Promise<void> => {
  // Create optimistic session
  const optimisticSession: TmuxSession = {
    name: sessionName,
    attached: false,
    created: new Date().toISOString(),
    windows: 1,
    dimensions: '80x24'
  }
  
  // Optimistically add to sessions
  queryClient.setQueryData<TmuxSession[]>(['sessions'], old => [...(old || []), optimisticSession])
  
  try {
    const result = await websocketApi.createSession(sessionName)
    
    if (result.success && result.sessionName) {
      // Select the new session
      currentSession.value = result.sessionName
      
      // On mobile, close sidebar after selecting
      if (isMobile.value) {
        sidebarCollapsed.value = true
      }
      
      // Real update will come through WebSocket
    }
  } catch (error) {
    console.error('Failed to create session:', error)
    // Revert optimistic update
    queryClient.setQueryData<TmuxSession[]>(['sessions'], old => 
      old?.filter(s => s.name !== sessionName) || []
    )
    
    let errorMessage = 'Failed to create session.'
    if (error instanceof Error) {
      errorMessage += ' ' + error.message
    }
    
    alert(errorMessage)
  }
}

const handleKillSession = async (sessionName: string): Promise<void> => {
  console.log('App.vue handleKillSession called for:', sessionName)
  try {
    await websocketApi.killSession(sessionName)
    console.log('Successfully killed session:', sessionName)
    
    // Clear current session if it's the one being killed
    if (currentSession.value === sessionName) {
      currentSession.value = null
    }
    
    // WebSocket will handle updating the sessions list
  } catch (error) {
    console.error('Failed to kill session:', error)
  }
}

const handleRenameSession = async (sessionName: string, newName: string): Promise<void> => {
  try {
    await websocketApi.renameSession(sessionName, newName)
    
    // Update current session if it's the one being renamed
    if (currentSession.value === sessionName) {
      currentSession.value = newName
    }
    
    // WebSocket will handle updating the sessions list
  } catch (error) {
    console.error('Failed to rename session:', error)
    alert('Failed to rename session. The name may already be in use.')
  }
}

// Add a refresh trigger for windows
const windowRefreshTrigger = ref(0)

const handleSelectWindow = (sessionName: string, window: TmuxWindow): void => {
  console.log('Selecting window:', window.index, 'in session:', sessionName)

  // If switching to a different session, select it first
  if (currentSession.value !== sessionName) {
    currentSession.value = sessionName
  }

  // Track the selected window index for ChatView
  currentWindowIndex.value = window.index

  // Send the window selection command
  if (ws.isConnected.value) {
    ws.send({
      type: 'select-window',
      sessionName: sessionName,
      windowIndex: window.index
    })
  }
}

ws.onMessage<SessionsListMessage>('sessions-list', (data) => {
  queryClient.setQueryData(['sessions'], data.sessions)
})

ws.onMessage<WindowSelectedMessage>('window-selected', (data) => {
  if (data.success) {
    console.log('Window selected successfully:', data.windowIndex)
    // Also trigger window refresh
    windowRefreshTrigger.value++
  } else {
    console.error('Failed to select window:', data.error)
  }
})

const toggleSidebar = (): void => {
  sidebarCollapsed.value = !sidebarCollapsed.value
}

// Close sidebar when session is selected (only on mobile)
const selectSession = (sessionName: string): void => {
  currentSession.value = sessionName
  // Only close sidebar on mobile
  if (isMobile.value) {
    sidebarCollapsed.value = true
  }
}

// Search functionality
const closeSearch = (): void => {
  searchQuery.value = ''
  showSearchResults.value = false
  selectedIndex.value = 0
  searchInput.value?.blur()
}

const handleSearchBlur = (): void => {
  // Delay to allow click on results
  setTimeout(() => {
    showSearchResults.value = false
  }, 200)
}

const selectFirstResult = (): void => {
  if (filteredWindows.value.length > 0) {
    selectWindow(filteredWindows.value[0]!)
  }
}

const navigateResults = (direction: number): void => {
  const maxIndex = filteredWindows.value.length - 1
  selectedIndex.value = Math.max(0, Math.min(maxIndex, selectedIndex.value + direction))
}

const selectWindow = async (item: { sessionName: string, window: TmuxWindow }): Promise<void> => {
  closeSearch()
  
  // First select the session if different
  if (currentSession.value !== item.sessionName) {
    currentSession.value = item.sessionName
  }
  
  // Then select the window
  await handleSelectWindow(item.sessionName, item.window)
}


</script>

<style>
.fade-enter-active, .fade-leave-active {
  transition: opacity 0.15s ease;
}
.fade-enter-from, .fade-leave-to {
  opacity: 0;
}

.view-toggle {
  display: flex;
  background: var(--bg-tertiary);
  border-radius: 6px;
  padding: 2px;
  gap: 2px;
}
.view-toggle button {
  padding: 4px 12px;
  border: none;
  background: transparent;
  color: var(--text-secondary);
  font-size: 12px;
  border-radius: 4px;
  cursor: pointer;
  transition: all 0.15s;
}
.view-toggle button.active {
  background: var(--accent-primary);
  color: var(--bg-primary);
}
.view-toggle button:not(.active):hover {
  color: var(--text-primary);
}
</style>
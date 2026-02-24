<template>
  <aside 
    class="flex flex-col border-r transition-all duration-300" 
    :class="[
      isMobile ? (isCollapsed ? 'w-0 overflow-hidden' : 'w-64') : (isCollapsed ? 'w-12' : 'w-64'),
      isMobile && !isCollapsed ? 'shadow-xl' : ''
    ]"
    style="background: var(--bg-secondary); border-color: rgba(255, 255, 255, 0.06)"
  >
    <!-- Modal for delete confirmation -->
    <div v-if="showDeleteModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" @click.self="cancelDelete">
      <div class="p-6 rounded-xl shadow-2xl max-w-sm w-full mx-4" style="background: linear-gradient(135deg, rgba(30, 41, 59, 0.95) 0%, rgba(30, 41, 59, 0.85) 100%); border: 1px solid rgba(148, 163, 184, 0.2); backdrop-filter: blur(20px)">
        <h3 class="text-lg font-semibold mb-4" style="color: var(--text-primary)">{{ deleteModalTitle }}</h3>
        <p class="mb-4" style="color: var(--text-secondary)">
          {{ deleteModalMessage }}
        </p>
        <div class="flex justify-end space-x-2">
          <button 
            @click="cancelDelete"
            class="px-4 py-2 text-sm rounded-lg transition-all duration-150"
            style="background: rgba(148, 163, 184, 0.1); color: var(--text-secondary)"
            onmouseover="this.style.background='rgba(148, 163, 184, 0.2)'"
            onmouseout="this.style.background='rgba(148, 163, 184, 0.1)'"
          >
            Cancel
          </button>
          <button 
            @click="confirmDelete"
            class="px-4 py-2 text-sm rounded-lg transition-all duration-150 font-medium"
            style="background: rgba(248, 81, 73, 0.9); color: white"
            onmouseover="this.style.background='rgba(248, 81, 73, 1)'"
            onmouseout="this.style.background='rgba(248, 81, 73, 0.9)'"
          >
            Delete
          </button>
        </div>
      </div>
    </div>

    <!-- Modal for session name input -->
    <div v-if="showCreateModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div class="p-6 rounded-xl shadow-2xl max-w-sm w-full mx-4" style="background: linear-gradient(135deg, rgba(30, 41, 59, 0.95) 0%, rgba(30, 41, 59, 0.85) 100%); border: 1px solid rgba(148, 163, 184, 0.2); backdrop-filter: blur(20px)">
        <h3 class="text-lg font-semibold mb-4" style="color: var(--text-primary)">Create New Session</h3>
        <input 
          v-model="newSessionName"
          type="text" 
          placeholder="Session name"
          class="w-full px-3 py-2 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 transition-all duration-150"
          style="background: rgba(0, 0, 0, 0.3); border: 1px solid rgba(148, 163, 184, 0.2); color: var(--text-primary)"
          @keyup.enter="confirmCreate"
          ref="sessionNameInput"
        />
        <div class="flex justify-end space-x-2 mt-4">
          <button 
            @click="cancelCreate"
            class="px-4 py-2 text-sm rounded-lg transition-all duration-150"
            style="background: rgba(148, 163, 184, 0.1); color: var(--text-secondary)"
            onmouseover="this.style.background='rgba(148, 163, 184, 0.2)'"
            onmouseout="this.style.background='rgba(148, 163, 184, 0.1)'"
          >
            Cancel
          </button>
          <button 
            @click="confirmCreate"
            class="px-4 py-2 text-sm rounded-lg transition-all duration-150 font-medium"
            style="background: rgba(59, 130, 246, 0.9); color: white"
            onmouseover="this.style.background='rgba(59, 130, 246, 1)'"
            onmouseout="this.style.background='rgba(59, 130, 246, 0.9)'"
          >
            Create
          </button>
        </div>
      </div>
    </div>
    <div class="sidebar-header">
      <div v-if="!isCollapsed || isMobile" class="header-content">
        <div class="header-title">
          <span>SESSIONS</span>
          <span class="session-count">{{ sessions.length }}</span>
        </div>
        
        <button
          @click="handleCreate"
          class="new-session-btn"
          title="New Session"
        >
          <svg class="w-3.5 h-3.5" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M10 3a1 1 0 011 1v5h5a1 1 0 110 2h-5v5a1 1 0 11-2 0v-5H4a1 1 0 110-2h5V4a1 1 0 011-1z" clip-rule="evenodd" />
          </svg>
        </button>
      </div>
      
      <!-- Collapsed state new session button (desktop only) -->
      <button
        v-else-if="!isMobile"
        @click="handleCreate"
        class="collapsed-new-btn"
        title="New Session"
      >
        <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 3a1 1 0 011 1v5h5a1 1 0 110 2h-5v5a1 1 0 11-2 0v-5H4a1 1 0 110-2h5V4a1 1 0 011-1z" clip-rule="evenodd" />
        </svg>
      </button>
      
    </div>

    <div class="flex-1 overflow-y-auto">
      <div v-if="isLoading && sessions.length === 0" class="p-4">
        <div class="text-xs" style="color: var(--text-tertiary)">Loading...</div>
      </div>
      
      <div v-else-if="sessions.length === 0" class="p-4">
        <div class="text-xs" style="color: var(--text-tertiary)">No sessions</div>
      </div>
      
      <div v-else class="py-2">
        <SessionItem
          v-for="session in sessions"
          :key="session.name"
          v-memo="[session.name, session.windows, currentSession === session.name, isCollapsed && !isMobile]"
          :session="session"
          :isActive="currentSession === session.name"
          :isCollapsed="isCollapsed && !isMobile"
          :isMobile="isMobile"
          @select="$emit('select', session.name)"
          @kill="handleKill(session.name)"
          @rename="(newName) => emit('rename', session.name, newName)"
          @select-window="(window) => $emit('select-window', session.name, window)"
        />
      </div>
    </div>
    
    <!-- CRON Section -->
    <CronSection :isCollapsed="isCollapsed && !isMobile" />
    
    <!-- Dotfiles Section -->
    <DotfilesSection :isCollapsed="isCollapsed && !isMobile" />
  </aside>
</template>

<script setup lang="ts">
import { ref, nextTick } from 'vue'
import SessionItem from './SessionItem.vue'
import CronSection from './CronSection.vue'
import DotfilesSection from './DotfilesSection.vue'
import type { TmuxSession, TmuxWindow } from '@/types'

interface Props {
  sessions: TmuxSession[]
  currentSession: string | null
  isCollapsed: boolean
  isMobile: boolean
  isLoading: boolean
}

const props = withDefaults(defineProps<Props>(), {
  sessions: () => [],
  currentSession: null,
  isCollapsed: false,
  isMobile: false,
  isLoading: false
})

const emit = defineEmits<{
  select: [sessionName: string]
  kill: [sessionName: string]
  rename: [sessionName: string, newName: string]
  create: [sessionName: string]
  'select-window': [sessionName: string, window: TmuxWindow]
  'toggle-sidebar': []
}>()

// Modal state
const showCreateModal = ref(false)
const newSessionName = ref('')
const sessionNameInput = ref<HTMLInputElement>()

// Delete modal state
const showDeleteModal = ref(false)
const sessionToDelete = ref<string | null>(null)
const deleteModalTitle = ref('')
const deleteModalMessage = ref('')

const handleCreate = (): void => {
  // Handle create new session
  showCreateModal.value = true
  newSessionName.value = `s${Date.now().toString().slice(-6)}`
  nextTick(() => {
    sessionNameInput.value?.focus()
    sessionNameInput.value?.select()
  })
}

const confirmCreate = (): void => {
  if (newSessionName.value.trim()) {
    // Create session with name
    emit('create', newSessionName.value.trim())
    showCreateModal.value = false
    newSessionName.value = ''
  }
}

const cancelCreate = (): void => {
  showCreateModal.value = false
  newSessionName.value = ''
}

const handleKill = (sessionName: string): void => {
  // Handle kill session request
  const session = props.sessions.find(s => s.name === sessionName)
  if (!session) {
    // Session not found
    return
  }
  
  sessionToDelete.value = sessionName
  deleteModalTitle.value = session.windows === 1 ? 'Close Session' : 'Kill Session'
  deleteModalMessage.value = session.windows === 1 
    ? `Are you sure you want to close session "${sessionName}"?`
    : `Are you sure you want to kill session "${sessionName}"? This will close all ${session.windows} windows.`
  
  showDeleteModal.value = true
}

const confirmDelete = (): void => {
  if (sessionToDelete.value) {
    // User confirmed kill for session
    emit('kill', sessionToDelete.value)
    showDeleteModal.value = false
    sessionToDelete.value = null
  }
}

const cancelDelete = (): void => {
  // User cancelled delete
  showDeleteModal.value = false
  sessionToDelete.value = null
}
</script>

<style scoped>
/* Sidebar header */
.sidebar-header {
  @apply px-3 py-2 border-b;
  border-color: rgba(255, 255, 255, 0.05);
}

.header-content {
  @apply flex items-center justify-between;
}

.header-title {
  @apply flex items-center gap-2 text-xs;
  color: var(--text-tertiary);
  font-weight: 500;
}

.session-count {
  font-size: 11px;
  color: var(--text-tertiary);
}

/* New session button */
.new-session-btn {
  @apply p-1 rounded;
  color: var(--text-tertiary);
  transition: all 100ms ease;
}

.new-session-btn:hover {
  color: var(--text-secondary);
  background: rgba(255, 255, 255, 0.04);
}

.new-session-btn svg {
  @apply w-3.5 h-3.5;
}

/* Collapsed new button */
.collapsed-new-btn {
  @apply w-full p-2 rounded flex items-center justify-center;
  color: var(--text-tertiary);
  transition: all 100ms ease;
}

.collapsed-new-btn:hover {
  color: var(--text-secondary);
  background: rgba(255, 255, 255, 0.04);
}

/* Session list scroll area */
.flex-1.overflow-y-auto {
  /* Custom scrollbar */
  scrollbar-width: thin;
  scrollbar-color: rgba(255, 255, 255, 0.1) transparent;
}

.flex-1.overflow-y-auto::-webkit-scrollbar {
  width: 4px;
}

.flex-1.overflow-y-auto::-webkit-scrollbar-track {
  background: transparent;
}

.flex-1.overflow-y-auto::-webkit-scrollbar-thumb {
  background: rgba(255, 255, 255, 0.1);
  border-radius: 2px;
}

.flex-1.overflow-y-auto::-webkit-scrollbar-thumb:hover {
  background: rgba(255, 255, 255, 0.15);
}

</style>

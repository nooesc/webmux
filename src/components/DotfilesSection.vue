<template>
  <div class="border-t" style="border-color: var(--border-primary)">
    <!-- Header -->
    <div class="p-3">
      <!-- Collapsed state - icon only -->
      <button
        v-if="isCollapsed"
        @click="isExpanded = !isExpanded"
        class="w-full flex items-center justify-center hover-bg rounded p-2"
        :title="`Dotfiles (${dotfiles.length})`"
      >
        <div class="relative">
          <svg 
            class="w-4 h-4" 
            fill="none" 
            stroke="currentColor" 
            viewBox="0 0 24 24"
          >
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
          </svg>
          <!-- File count badge -->
          <span 
            v-if="dotfiles.length > 0" 
            class="absolute -top-1 -right-1 w-3 h-3 text-[8px] rounded-full flex items-center justify-center font-bold"
            style="background: var(--accent-primary); color: var(--bg-primary)"
          >
            {{ dotfiles.length }}
          </span>
        </div>
      </button>
      
      <!-- Expanded state - full header -->
      <button
        v-else
        @click="isExpanded = !isExpanded"
        class="w-full flex items-center justify-between text-xs font-medium hover-bg rounded p-2"
        style="color: var(--text-secondary)"
      >
        <div class="flex items-center space-x-2">
          <svg 
            class="w-3 h-3 transition-transform" 
            :class="{ 'rotate-90': isExpanded }"
            fill="none" 
            stroke="currentColor" 
            viewBox="0 0 24 24"
          >
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
          </svg>
          <span>Dotfiles</span>
        </div>
        <span v-if="!isExpanded && dotfiles.length > 0" class="text-xs" style="color: var(--text-tertiary)">
          {{ dotfiles.length }}
        </span>
      </button>
    </div>

    <!-- Content -->
    <div v-show="isExpanded && !isCollapsed" class="pb-3">
      <!-- Loading state -->
      <div v-if="isLoading" class="px-3 py-2">
        <div class="animate-pulse text-xs" style="color: var(--text-tertiary)">
          Loading dotfiles...
        </div>
      </div>

      <!-- Dotfiles list -->
      <div v-else-if="dotfiles.length > 0" class="px-3 space-y-1">
        <div
          v-for="file in sortedDotfiles"
          :key="file.path"
          @click="openFile(file)"
          class="p-2 rounded hover-bg cursor-pointer flex items-center justify-between"
          style="background: var(--bg-tertiary)"
        >
          <div class="flex items-center space-x-2 min-w-0">
            <!-- File icon based on type -->
            <svg class="w-3 h-3 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path 
                v-if="file.fileType === 'Shell'"
                stroke-linecap="round" 
                stroke-linejoin="round" 
                stroke-width="2" 
                d="M8 9l3 3-3 3m5 0h3M5 20h14a2 2 0 002-2V6a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" 
              />
              <path 
                v-else-if="file.fileType === 'Git'"
                stroke-linecap="round" 
                stroke-linejoin="round" 
                stroke-width="2" 
                d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4" 
              />
              <path 
                v-else-if="file.fileType === 'Vim'"
                stroke-linecap="round" 
                stroke-linejoin="round" 
                stroke-width="2" 
                d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" 
              />
              <path 
                v-else
                stroke-linecap="round" 
                stroke-linejoin="round" 
                stroke-width="2" 
                d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" 
              />
            </svg>
            
            <!-- File name -->
            <span class="text-xs truncate" style="color: var(--text-primary)">
              {{ file.name }}
            </span>
          </div>

          <!-- File status indicators -->
          <div class="flex items-center space-x-1 flex-shrink-0">
            <!-- Exists indicator -->
            <div 
              v-if="!file.exists"
              class="w-2 h-2 rounded-full bg-gray-500"
              title="File doesn't exist"
            ></div>
            
            <!-- Read-only indicator -->
            <svg 
              v-if="file.exists && !file.writable"
              class="w-3 h-3" 
              fill="none" 
              stroke="currentColor" 
              viewBox="0 0 24 24"
              title="Read-only"
            >
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
            </svg>
          </div>
        </div>
      </div>

      <!-- Empty state -->
      <div v-else class="px-3 py-4 text-center">
        <p class="text-xs" style="color: var(--text-tertiary)">
          No dotfiles found
        </p>
      </div>

      <!-- Action buttons -->
      <div class="px-3 mt-3 space-y-2">
        <button
          @click="browseFile"
          class="w-full px-3 py-1.5 text-xs border rounded transition-colors"
          style="background: var(--bg-primary); border-color: var(--border-primary); color: var(--text-primary)"
          :class="'hover:border-opacity-80'"
        >
          Browse File...
        </button>
        
        <button
          @click="showTemplates"
          class="w-full px-3 py-1.5 text-xs border rounded transition-colors"
          style="background: var(--bg-primary); border-color: var(--border-primary); color: var(--text-primary)"
          :class="'hover:border-opacity-80'"
        >
          Browse Templates
        </button>
      </div>
    </div>

    <!-- Editor Modal -->
    <DotfileEditor
      v-if="editingFile"
      :file="editingFile"
      :content="fileContent"
      @save="saveFile"
      @close="closeEditor"
    />

    <!-- Templates Modal -->
    <DotfileTemplates
      v-if="showingTemplates"
      @select="applyTemplate"
      @close="showingTemplates = false"
    />
    
    <!-- Browse File Modal -->
    <div v-if="showingBrowse" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" @click.self="showingBrowse = false">
      <div class="p-6 rounded-lg shadow-xl max-w-md w-full mx-4" style="background: var(--bg-secondary); border: 1px solid var(--border-primary)">
        <h3 class="text-lg font-semibold mb-4" style="color: var(--text-primary)">
          Open File
        </h3>
        <input 
          v-model="browseFilePath"
          type="text" 
          placeholder="Enter file path (e.g., ~/.config/nvim/init.vim)"
          class="w-full px-3 py-2 border rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
          style="background: var(--bg-primary); border-color: var(--border-primary); color: var(--text-primary)"
          @keyup.enter="confirmBrowse"
          ref="browseInput"
        />
        <div class="mt-2 text-xs" style="color: var(--text-tertiary)">
          Tip: Use ~ for home directory
        </div>
        <div class="flex justify-end space-x-2 mt-4">
          <button 
            @click="showingBrowse = false"
            class="px-4 py-2 text-sm border rounded"
            style="background: var(--bg-secondary); border-color: var(--border-primary); color: var(--text-secondary)"
          >
            Cancel
          </button>
          <button 
            @click="confirmBrowse"
            class="px-4 py-2 text-sm border rounded"
            style="background: var(--bg-primary); border-color: var(--border-primary); color: var(--text-primary)"
          >
            Open
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, nextTick } from 'vue'
import { useWebSocket } from '@/composables/useWebSocket'
import DotfileEditor from './DotfileEditor.vue'
import DotfileTemplates from './DotfileTemplates.vue'
import type { DotFile, ServerMessage } from '@/types'

interface Props {
  isCollapsed?: boolean
}

withDefaults(defineProps<Props>(), {
  isCollapsed: false
})

const ws = useWebSocket()

// State
const isExpanded = ref(false)
const isLoading = ref(false)
const dotfiles = ref<DotFile[]>([])
const editingFile = ref<DotFile | null>(null)
const fileContent = ref('')
const showingTemplates = ref(false)
const showingBrowse = ref(false)
const browseFilePath = ref('')
const browseInput = ref<HTMLInputElement>()

// Computed
const sortedDotfiles = computed(() => {
  return [...dotfiles.value].sort((a, b) => {
    // Sort by file type first, then by name
    if (a.fileType !== b.fileType) {
      const typeOrder = ['Shell', 'Git', 'Vim', 'Tmux', 'SSH', 'Other']
      return typeOrder.indexOf(a.fileType) - typeOrder.indexOf(b.fileType)
    }
    return a.name.localeCompare(b.name)
  })
})

// Methods
const loadDotfiles = async () => {
  if (!isExpanded.value) return
  
  isLoading.value = true
  ws.send({ type: 'list-dotfiles' })
}

const openFile = async (file: DotFile) => {
  if (!file.exists) {
    // Create new file
    editingFile.value = file
    fileContent.value = ''
    return
  }

  // Read existing file
  editingFile.value = file
  fileContent.value = '' // Clear while loading
  console.log('Requesting dotfile:', file.path)
  ws.send({ 
    type: 'read-dotfile',
    path: file.path 
  })
}

const saveFile = async (content: string) => {
  if (!editingFile.value) return

  ws.send({
    type: 'write-dotfile',
    path: editingFile.value.path,
    content
  })
}

const closeEditor = () => {
  editingFile.value = null
  fileContent.value = ''
  // Reload dotfiles to refresh status
  loadDotfiles()
}

const showTemplates = () => {
  showingTemplates.value = true
}

const applyTemplate = (template: { path: string; content: string }) => {
  // Find the dotfile for this path
  const file = dotfiles.value.find(f => f.path === template.path)
  if (file) {
    editingFile.value = file
    fileContent.value = template.content
  }
  showingTemplates.value = false
}

const browseFile = () => {
  showingBrowse.value = true
  browseFilePath.value = '~/'
  nextTick(() => {
    browseInput.value?.focus()
    browseInput.value?.select()
  })
}

const confirmBrowse = () => {
  if (!browseFilePath.value.trim()) return
  
  // Create a temporary DotFile object for the custom path
  const customFile: DotFile = {
    name: browseFilePath.value.split('/').pop() || 'file',
    path: browseFilePath.value.trim(),
    size: 0,
    modified: new Date().toISOString(),
    exists: true, // Assume it exists, backend will handle if it doesn't
    readable: true,
    writable: true,
    fileType: 'Other'
  }
  
  showingBrowse.value = false
  openFile(customFile)
}

// WebSocket message handlers
const handleDotfilesList = (msg: Extract<ServerMessage, { type: 'dotfiles-list' }>) => {
  dotfiles.value = msg.files
  isLoading.value = false
}

const handleDotfileContent = (msg: Extract<ServerMessage, { type: 'dotfile-content' }>) => {
  console.log('Received dotfile content for:', msg.path)
  console.log('Content length:', msg.content?.length || 0)
  console.log('First 200 chars:', msg.content?.substring(0, 200) || 'NO CONTENT')
  
  if (msg.error) {
    console.error('Failed to read dotfile:', msg.error)
    fileContent.value = ''
  } else {
    fileContent.value = msg.content
  }
}

const handleDotfileWritten = (msg: Extract<ServerMessage, { type: 'dotfile-written' }>) => {
  if (msg.success) {
    closeEditor()
  } else {
    console.error('Failed to write dotfile:', msg.error)
  }
}

// Watch for expansion
let unsubscribes: (() => void)[] = []

onMounted(() => {
  // Subscribe to WebSocket messages
  unsubscribes.push(
    ws.onMessage('dotfiles-list', handleDotfilesList),
    ws.onMessage('dotfile-content', handleDotfileContent),
    ws.onMessage('dotfile-written', handleDotfileWritten)
  )
})

onUnmounted(() => {
  unsubscribes.forEach(unsub => unsub())
})

// Load dotfiles when expanded
const watchExpanded = () => {
  if (isExpanded.value) {
    loadDotfiles()
  }
}

// Watch isExpanded
import { watch } from 'vue'
watch(isExpanded, watchExpanded)
</script>

<style scoped>
.hover-bg:hover {
  filter: brightness(1.2);
}

.rotate-90 {
  transform: rotate(90deg);
}
</style>
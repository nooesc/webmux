<template>
  <div class="h-full flex flex-col">
    <div class="px-3 py-2 flex-shrink-0 border-b" 
         style="background: var(--bg-secondary); border-color: var(--border-primary)">
      <div class="flex items-center justify-between">
        <div class="flex items-center space-x-3 text-xs">
          <span style="color: var(--text-tertiary)">Session:</span>
          <span style="color: var(--text-primary)" class="font-medium">{{ session }}</span>
        </div>
        <div class="flex items-center space-x-2">
          <!-- Action buttons -->
          <button 
            @click="splitHorizontal" 
            class="px-2 py-1 text-xs rounded hover-bg"
            style="background: var(--bg-tertiary); color: var(--text-primary)"
            title="Split Horizontal"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 12h14"></path>
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 6h14M5 18h14" opacity="0.3"></path>
            </svg>
          </button>
          <button 
            @click="splitVertical" 
            class="px-2 py-1 text-xs rounded hover-bg"
            style="background: var(--bg-tertiary); color: var(--text-primary)"
            title="Split Vertical"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 5v14"></path>
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 5v14M18 5v14" opacity="0.3"></path>
            </svg>
          </button>
          <button 
            @click="pasteFromClipboard" 
            class="px-2 py-1 text-xs rounded hover-bg"
            style="background: var(--bg-tertiary); color: var(--text-primary)"
            title="Paste"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"></path>
            </svg>
          </button>
          <div class="text-xs" style="color: var(--text-tertiary)">
            <span>{{ terminalSize.cols }}×{{ terminalSize.rows }}</span>
          </div>
        </div>
      </div>
    </div>
    
    <!-- Terminal area with mobile controls -->
    <div class="flex-1 relative overflow-hidden">
      <!-- Mobile control bar - fixed at top of terminal area -->
      <div v-if="isMobile" class="absolute top-0 left-0 right-0 z-20 px-2 py-1.5 border-b overflow-x-auto mobile-controls-scrollbar shadow-md" 
           style="background: var(--bg-secondary); border-color: var(--border-primary); pointer-events: auto;">
      <div class="flex space-x-1 text-xs whitespace-nowrap">
        <button 
          @click="sendKey('Escape')" 
          class="px-3 py-1.5 rounded hover-bg"
          style="background: var(--bg-tertiary); color: var(--text-primary)"
        >
          ESC
        </button>
        <button 
          @click="sendKey('Tab')" 
          class="px-3 py-1.5 rounded hover-bg"
          style="background: var(--bg-tertiary); color: var(--text-primary)"
        >
          TAB
        </button>
        <button 
          @click="toggleCtrl" 
          :class="ctrlPressed ? 'bg-green-600' : ''"
          class="px-3 py-1.5 rounded hover-bg"
          :style="ctrlPressed ? 'background: #10b981; color: white' : 'background: var(--bg-tertiary); color: var(--text-primary)'"
        >
          CTRL {{ ctrlPressed ? '●' : '' }}
        </button>
        <button 
          @click="sendKey('ArrowUp')" 
          class="px-3 py-1.5 rounded hover-bg"
          style="background: var(--bg-tertiary); color: var(--text-primary)"
        >
          ↑
        </button>
        <button 
          @click="sendKey('ArrowDown')" 
          class="px-3 py-1.5 rounded hover-bg"
          style="background: var(--bg-tertiary); color: var(--text-primary)"
        >
          ↓
        </button>
        <button 
          @click="sendKey('ArrowLeft')" 
          class="px-3 py-1.5 rounded hover-bg"
          style="background: var(--bg-tertiary); color: var(--text-primary)"
        >
          ←
        </button>
        <button 
          @click="sendKey('ArrowRight')" 
          class="px-3 py-1.5 rounded hover-bg"
          style="background: var(--bg-tertiary); color: var(--text-primary)"
        >
          →
        </button>
        <button 
          @click="sendCtrlKey('c')" 
          class="px-3 py-1.5 rounded hover-bg"
          style="background: var(--bg-tertiary); color: var(--text-primary)"
        >
          ^C
        </button>
        <button 
          @click="sendCtrlKey('d')" 
          class="px-3 py-1.5 rounded hover-bg"
          style="background: var(--bg-tertiary); color: var(--text-primary)"
        >
          ^D
        </button>
        <button 
          @click="sendCtrlKey('z')" 
          class="px-3 py-1.5 rounded hover-bg"
          style="background: var(--bg-tertiary); color: var(--text-primary)"
        >
          ^Z
        </button>
        <button 
          @click="sendCtrlKey('a')" 
          class="px-3 py-1.5 rounded hover-bg"
          style="background: var(--bg-tertiary); color: var(--text-primary)"
        >
          ^A
        </button>
        <button 
          @click="splitHorizontal" 
          class="px-3 py-1.5 rounded hover-bg"
          style="background: var(--bg-tertiary); color: var(--text-primary)"
        >
          H-Split
        </button>
        <button 
          @click="splitVertical" 
          class="px-3 py-1.5 rounded hover-bg"
          style="background: var(--bg-tertiary); color: var(--text-primary)"
        >
          V-Split
        </button>
        <button 
          @click="pasteFromClipboard" 
          class="px-3 py-1.5 rounded hover-bg"
          style="background: var(--bg-tertiary); color: var(--text-primary)"
        >
          Paste
        </button>
      </div>
    </div>
    
    <!-- Terminal container -->
    <div 
      ref="terminalContainer" 
      class="absolute inset-0 overflow-auto touch-manipulation z-10" 
      tabindex="0" 
      :style="terminalContainerStyle" 
      @click="focusTerminal"
      @contextmenu.prevent
      @touchstart="handleTouchStart"
      @touchend="handleTouchEnd"
      @dragover.prevent="handleDragOver"
      @drop.prevent="handleDrop"
      @dragenter.prevent="isDragging = true"
      @dragleave.prevent="handleDragLeave"
      :class="{ 'drag-over': isDragging }"
    ></div>
  </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted, watch, computed, shallowRef } from 'vue'
import { Terminal } from '@xterm/xterm'
import { FitAddon } from '@xterm/addon-fit'
import '@xterm/xterm/css/xterm.css'
import type { TerminalSize, OutputMessage, AttachSessionMessage, ResizeMessage, InputMessage } from '@/types'
import type { UseWebSocketReturn } from '@/composables/useWebSocket'

interface Props {
  session: string
  ws: UseWebSocketReturn
}

const props = defineProps<Props>()

const terminalContainer = ref<HTMLDivElement | null>(null)
const terminal = shallowRef<Terminal | null>(null)
const fitAddon = shallowRef<FitAddon | null>(null)
const terminalSize = ref<TerminalSize>({ cols: 80, rows: 24 })
const ctrlPressed = ref<boolean>(false)
const isMobile = computed(() => window.innerWidth < 768)
const isDragging = ref<boolean>(false)
const keyboardHeight = ref(0)
const isKeyboardVisible = ref(false)
let dragCounter = 0

// Computed style for terminal container to handle keyboard
const terminalContainerStyle = computed(() => {
  let style = 'background: #000;'
  if (isMobile.value) {
    style += ' padding-top: 48px;'
  }
  if (keyboardHeight.value > 0) {
    style += ` padding-bottom: ${keyboardHeight.value}px;`
  }
  return style
})

// Performance optimization: Output buffering
const outputBuffer = {
  data: [] as string[],
  rafId: null as number | null,
  lastFlush: 0,
  flushInterval: 16, // 60fps max
  maxBufferSize: 100 // Flush if buffer gets too large
}


onMounted(() => {
  const term = new Terminal({
    cursorBlink: true,
    fontSize: 13,
    fontFamily: '"JetBrainsMono Nerd Font", "JetBrains Mono", "SF Mono", Monaco, Inconsolata, "Fira Code", monospace',
    theme: {
      background: '#000000',
      foreground: '#c9d1d9',
      cursor: '#c9d1d9',
      cursorAccent: '#000000',
      selectionBackground: 'rgba(88, 166, 255, 0.3)',
      black: '#000000',
      red: '#ff7b72',
      green: '#7ee787',
      yellow: '#ffa657',
      blue: '#79c0ff',
      magenta: '#d2a8ff',
      cyan: '#a5d6ff',
      white: '#c9d1d9',
      brightBlack: '#6e7681',
      brightRed: '#ffa198',
      brightGreen: '#56d364',
      brightYellow: '#ffdf5d',
      brightBlue: '#79c0ff',
      brightMagenta: '#d2a8ff',
      brightCyan: '#a5d6ff',
      brightWhite: '#ffffff'
    },
    scrollback: 5000,
    tabStopWidth: 8,
    // @ts-ignore - bellStyle is a valid option but not in types
    bellStyle: 'none',
    drawBoldTextInBrightColors: true,
    lineHeight: 1.2,
    // Mobile scrolling improvements
    smoothScrollDuration: 50,
    fastScrollModifier: 'ctrl',
    fastScrollSensitivity: 10,
    scrollSensitivity: 3
  })

  const fit = new FitAddon()
  term.loadAddon(fit)
  
  terminal.value = term
  fitAddon.value = fit
  
  if (terminalContainer.value && terminal.value) {
    terminal.value.open(terminalContainer.value)
  }
  
  // Initial fit with a small delay to ensure container is properly sized
  setTimeout(() => {
    if (fitAddon.value) fitAddon.value.fit()
    if (terminal.value) terminal.value.focus()
  }, 100)

  if (terminal.value) {
    terminal.value.onData((data) => {
      if (props.ws.isConnected.value) {
        // If CTRL is toggled on mobile, modify the input
        if (ctrlPressed.value && data.length === 1) {
          const code = data.toUpperCase().charCodeAt(0) - 64
          data = String.fromCharCode(code)
          ctrlPressed.value = false // Auto-release after use
        }
        
        const message: InputMessage = {
          type: 'input',
          data: data
        }
        props.ws.send(message)
        
        // On mobile, scroll to show cursor after input
        if (isMobile.value && terminal.value) {
          setTimeout(() => {
            const cursorLine = terminal.value?.buffer.active.cursorY ?? 0
            terminal.value?.scrollToLine(cursorLine)
          }, 50)
        }
      }
    })

    // Auto-copy selected text to clipboard
    terminal.value.onSelectionChange(() => {
      const selection = terminal.value?.getSelection()
      if (selection) {
        navigator.clipboard.writeText(selection).catch(err => {
          console.error('Failed to copy to clipboard:', err)
        })
      }
    })

    // Handle paste with Ctrl+V/Cmd+V
    terminal.value.attachCustomKeyEventHandler((event: KeyboardEvent) => {
      // Handle paste (Ctrl+V or Cmd+V)
      if ((event.ctrlKey || event.metaKey) && event.key === 'v' && !event.shiftKey) {
        event.preventDefault()
        pasteFromClipboard()
        return false
      }
      // Let other key events pass through
      return true
    })
  }

  // Add paste event listener to handle image pastes
  window.addEventListener('paste', handlePaste)

  if (terminal.value) {
    terminal.value.onResize((size) => {
      terminalSize.value = { cols: size.cols, rows: size.rows }
      if (props.ws.isConnected.value) {
        const message: ResizeMessage = {
          type: 'resize',
          cols: size.cols,
          rows: size.rows
        }
        props.ws.send(message)
      }
    })
  }

  // Optimized output buffering with flow control
  const flushOutputBuffer = () => {
    const now = performance.now()
    
    // Throttle flushes to maintain 60fps
    if (now - outputBuffer.lastFlush < outputBuffer.flushInterval && 
        outputBuffer.data.length < outputBuffer.maxBufferSize) {
      // Schedule next flush
      outputBuffer.rafId = requestAnimationFrame(flushOutputBuffer)
      return
    }
    
    if (outputBuffer.data.length > 0 && terminal.value) {
      const data = outputBuffer.data.join('')
      outputBuffer.data = []
      outputBuffer.lastFlush = now
      
      try {
        terminal.value.write(data)
      } catch (err) {
        console.error('Terminal write error:', err)
      }
    }
    outputBuffer.rafId = null
  }
  
  // WebSocket message handler with optimized buffering
  props.ws.onMessage<OutputMessage>('output', (data) => {
    if (terminal.value && data.data) {
      outputBuffer.data.push(data.data)
      
      // Schedule flush if not already scheduled
      if (!outputBuffer.rafId) {
        outputBuffer.rafId = requestAnimationFrame(flushOutputBuffer)
      }
      
      // Force flush if buffer is getting too large
      if (outputBuffer.data.length >= outputBuffer.maxBufferSize) {
        if (outputBuffer.rafId) {
          cancelAnimationFrame(outputBuffer.rafId)
        }
        flushOutputBuffer()
      }
    }
  })

  props.ws.onMessage('disconnected', () => {
    if (terminal.value) terminal.value.write('\r\n\r\n[Session disconnected]\r\n')
  })

  props.ws.onMessage('attached', () => {
    if (terminal.value) terminal.value.focus()
    handleResize()
  })
  
  // Global focus management
  // Focus terminal on click
  if (terminalContainer.value) {
    terminalContainer.value.addEventListener('click', () => {
      if (terminal.value) terminal.value.focus()
    })
  }
  
  // Remove the focus interval - it's too aggressive

  attachToSession()

  window.addEventListener('resize', debouncedResize)
  
  // Visual viewport for mobile keyboard detection
  if (isMobile.value && window.visualViewport) {
    window.visualViewport.addEventListener('resize', handleVisualViewportResize)
    window.visualViewport.addEventListener('scroll', handleVisualViewportScroll)
  }
  
  // Also observe the terminal container for size changes
  const resizeObserver = new ResizeObserver(debouncedResize)
  if (terminalContainer.value) {
    resizeObserver.observe(terminalContainer.value)
  }
})

onUnmounted(() => {
  // Cancel any pending animation frame
  if (outputBuffer.rafId) {
    cancelAnimationFrame(outputBuffer.rafId)
    outputBuffer.rafId = null
  }
  outputBuffer.data = []
  
  if (terminal.value) {
    terminal.value.dispose()
  }
  props.ws.offMessage('output')
  props.ws.offMessage('disconnected')
  props.ws.offMessage('attached')
  window.removeEventListener('resize', debouncedResize)
  window.removeEventListener('paste', handlePaste)
  if (isMobile.value && window.visualViewport) {
    window.visualViewport.removeEventListener('resize', handleVisualViewportResize)
    window.visualViewport.removeEventListener('scroll', handleVisualViewportScroll)
  }
  if (resizeTimeout) clearTimeout(resizeTimeout)
})

watch(() => props.session, () => {
  if (terminal.value) {
    terminal.value.clear()
  }
  attachToSession()
})

const attachToSession = async (): Promise<void> => {
  // Ensure WebSocket is connected
  await props.ws.ensureConnected()
  
  let cols = 80
  let rows = 24
  
  if (fitAddon.value && terminal.value) {
    const dimensions = fitAddon.value.proposeDimensions()
    if (dimensions && dimensions.cols > 0 && dimensions.rows > 0) {
      cols = dimensions.cols
      rows = dimensions.rows
    } else {
      // Use terminal dimensions as fallback
      cols = terminal.value.cols || 80
      rows = terminal.value.rows || 24
    }
  }
  
  const message: AttachSessionMessage = {
    type: 'attach-session',
    sessionName: props.session,
    cols: cols,
    rows: rows
  }
  props.ws.send(message)
}

const handleResize = (): void => {
  if (fitAddon.value && terminal.value && terminalContainer.value) {
    try {
      // Get container dimensions
      const rect = terminalContainer.value.getBoundingClientRect()
      
      // Account for keyboard height on mobile
      let availableHeight = rect.height
      if (isMobile.value && keyboardHeight.value > 0) {
        availableHeight = window.innerHeight - keyboardHeight.value
      }
      
      if (rect.width > 0 && availableHeight > 0) {
        // Temporarily adjust container height to fit above keyboard
        const originalHeight = terminalContainer.value.style.height
        if (isMobile.value && keyboardHeight.value > 0) {
          terminalContainer.value.style.height = `${availableHeight}px`
        }
        
        fitAddon.value.fit()
        
        // Restore original height
        if (isMobile.value && keyboardHeight.value > 0) {
          terminalContainer.value.style.height = originalHeight
        }
        
        // Send the new dimensions to the server
        const dimensions = fitAddon.value.proposeDimensions()
        if (dimensions && dimensions.cols > 0 && dimensions.rows > 0) {
          terminalSize.value = { cols: dimensions.cols, rows: dimensions.rows }
          if (props.ws.isConnected.value) {
            const message: ResizeMessage = {
              type: 'resize',
              cols: dimensions.cols,
              rows: dimensions.rows
            }
            props.ws.send(message)
          }
        }
      }
    } catch (e) {
      console.error('Error resizing terminal:', e)
    }
  }
}

// Add a debounced resize handler for better performance
let resizeTimeout: ReturnType<typeof setTimeout> | null = null
const debouncedResize = (): void => {
  if (resizeTimeout) clearTimeout(resizeTimeout)
  resizeTimeout = setTimeout(handleResize, 200) // Increased debounce for better performance
}

// Visual viewport handlers for mobile keyboard detection
const handleVisualViewportResize = (): void => {
  if (!window.visualViewport) return
  
  const viewport = window.visualViewport
  const initialHeight = window.innerHeight
  const currentHeight = viewport.height
  const heightDiff = initialHeight - currentHeight
  
  // Keyboard is typically at least 150px
  if (heightDiff > 150) {
    keyboardHeight.value = heightDiff
    isKeyboardVisible.value = true
  } else {
    keyboardHeight.value = 0
    isKeyboardVisible.value = false
  }
  
  // Resize terminal to fit above keyboard
  setTimeout(() => {
    handleResize()
  }, 100)
}

const handleVisualViewportScroll = (): void => {
  // Keep terminal in view when keyboard opens
  if (isKeyboardVisible.value && terminalContainer.value) {
    terminalContainer.value.scrollIntoView({ behavior: 'smooth' })
  }
}

const focusTerminal = (): void => {
  if (terminal.value) {
    terminal.value.focus()
  }
}

// Mobile touch handling
let touchStartTime = 0
const handleTouchStart = (e: TouchEvent): void => {
  touchStartTime = Date.now()
  // Prevent default to avoid scrolling issues
  if (e.target === terminalContainer.value) {
    focusTerminal()
  }
}

const handleTouchEnd = (_e: TouchEvent): void => {
  const touchDuration = Date.now() - touchStartTime
  // Only focus if it's a quick tap, not a scroll
  if (touchDuration < 200) {
    focusTerminal()
  }
}

// Mobile keyboard control methods
const sendKey = (key: string): void => {
  if (!terminal.value || !props.ws.isConnected.value) return
  
  const keyMap: Record<string, string> = {
    'Escape': '\x1b',
    'Tab': '\t',
    'ArrowUp': '\x1b[A',
    'ArrowDown': '\x1b[B',
    'ArrowLeft': '\x1b[D',
    'ArrowRight': '\x1b[C',
  }
  
  const data = keyMap[key] || key
  
  // Send through WebSocket
  const message: InputMessage = {
    type: 'input',
    data: data
  }
  props.ws.send(message)
  
  terminal.value.focus()
}

const sendCtrlKey = (key: string): void => {
  if (!terminal.value || !props.ws.isConnected.value) {
    return
  }
  
  // Convert letter to control character
  const code = key.toUpperCase().charCodeAt(0) - 64
  const ctrlChar = String.fromCharCode(code)
  
  // Send through WebSocket
  const message: InputMessage = {
    type: 'input',
    data: ctrlChar
  }
  props.ws.send(message)
  
  terminal.value.focus()
}

const toggleCtrl = (): void => {
  ctrlPressed.value = !ctrlPressed.value
  if (terminal.value) terminal.value.focus()
  
  // Auto-release after 5 seconds
  if (ctrlPressed.value) {
    setTimeout(() => {
      ctrlPressed.value = false
    }, 5000)
  }
}

const splitHorizontal = (): void => {
  // Send tmux split-window command horizontally (Ctrl-A ")
  if (!props.ws.isConnected.value) return
  
  // Send as a single message with both the prefix and command
  const message: InputMessage = {
    type: 'input',
    data: '\x01"'  // Ctrl-A followed by "
  }
  props.ws.send(message)
  
  if (terminal.value) terminal.value.focus()
}

const splitVertical = (): void => {
  // Send tmux split-window command vertically (Ctrl-A %)
  if (!props.ws.isConnected.value) return
  
  // Send as a single message with both the prefix and command
  const message: InputMessage = {
    type: 'input',
    data: '\x01%'  // Ctrl-A followed by %
  }
  props.ws.send(message)
  
  if (terminal.value) terminal.value.focus()
}

const pasteFromClipboard = async (): Promise<void> => {
  try {
    // First ensure terminal has focus
    if (terminal.value) terminal.value.focus()
    
    // Try to read from clipboard
    let text = await navigator.clipboard.readText()
    console.log('Clipboard text:', text ? `${text.length} characters` : 'empty')
    
    if (text && props.ws.isConnected.value) {
      // Escape newlines to prevent auto-execution while preserving formatting
      // This sends the text with escaped newlines that will appear as line continuations
      text = text.replace(/\n/g, '\\\n')
      
      console.log('Escaped text for paste')
      
      const message: InputMessage = {
        type: 'input',
        data: text
      }
      props.ws.send(message)
      console.log('Pasted text sent to terminal')
    } else if (!text) {
      console.warn('Clipboard is empty or no text to paste')
    } else if (!props.ws.isConnected.value) {
      console.error('WebSocket is not connected')
    }
  } catch (err) {
    console.error('Failed to read from clipboard:', err)
    
    // Try alternative paste method using execCommand
    try {
      if (terminal.value) {
        terminal.value.focus()
        const result = document.execCommand('paste')
        console.log('execCommand paste result:', result)
      }
    } catch (fallbackErr) {
      console.error('Fallback paste also failed:', fallbackErr)
      // Could show a prompt for manual paste here
      alert('Unable to paste. Please use Ctrl+V (or Cmd+V on Mac) to paste directly.')
    }
  }
}

// Drag and drop handlers
const handleDragOver = (e: DragEvent): void => {
  // Prevent default to allow drop
  e.preventDefault()
  // Add visual feedback
  isDragging.value = true
}

const handleDragLeave = (e: DragEvent): void => {
  // Handle nested elements by tracking enter/leave count
  if (e.target === terminalContainer.value) {
    dragCounter--
    if (dragCounter === 0) {
      isDragging.value = false
    }
  }
}

const handleDrop = async (e: DragEvent): Promise<void> => {
  e.preventDefault()
  isDragging.value = false
  dragCounter = 0
  
  const files = Array.from(e.dataTransfer?.files || [])
  
  for (const file of files) {
    if (file.type.startsWith('image/')) {
      await handleImageFile(file)
    }
  }
}

const handlePaste = async (e: ClipboardEvent): Promise<void> => {
  // Check if terminal has focus
  if (!terminal.value || document.activeElement !== terminalContainer.value) return
  
  e.preventDefault()
  
  // Check for image data
  const items = Array.from(e.clipboardData?.items || [])
  for (const item of items) {
    if (item.type.startsWith('image/')) {
      const file = item.getAsFile()
      if (file) {
        await handleImageFile(file)
      }
      return
    }
  }
  
  // Fallback to text paste
  const text = e.clipboardData?.getData('text/plain')
  if (text && props.ws.isConnected.value) {
    const message: InputMessage = {
      type: 'input',
      data: text.replace(/\n/g, '\\\n')
    }
    props.ws.send(message)
  }
}

// Image handling
const handleImageFile = async (file: File): Promise<void> => {
  console.log('Handling image file:', file.name, file.type, file.size)
  
  // Check file size (10MB limit)
  if (file.size > 10 * 1024 * 1024) {
    console.error('Image file too large (max 10MB):', file.size)
    showToast(`Image "${file.name}" is too large (max 10MB)`, 'error')
    return
  }
  
  try {
    // Convert to base64
    const base64 = await fileToBase64(file)
    
    // Send using iTerm2 OSC 1337 protocol
    const sequence = buildOSC1337Sequence(base64, file.name)
    
    if (props.ws.isConnected.value) {
      const message: InputMessage = {
        type: 'input',
        data: sequence
      }
      props.ws.send(message)
      showToast(`Image "${file.name}" sent to terminal`, 'success')
    }
  } catch (err) {
    console.error('Failed to process image:', err)
    showToast(`Failed to process image "${file.name}"`, 'error')
  }
}

const fileToBase64 = (file: File): Promise<string> => {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = () => {
      const result = reader.result as string
      // Remove data URL prefix to get pure base64
      const base64 = result.split(',')[1]
      if (base64) {
        resolve(base64)
      } else {
        reject(new Error('Failed to extract base64 from data URL'))
      }
    }
    reader.onerror = reject
    reader.readAsDataURL(file)
  })
}

const buildOSC1337Sequence = (base64: string, filename: string): string => {
  // iTerm2 inline image protocol
  // ESC ] 1337 ; File = name={filename};size={size};inline=1:{base64} ^G
  // Encode filename to handle Unicode characters
  const encodedName = btoa(unescape(encodeURIComponent(filename)))
  const args = `name=${encodedName};size=${base64.length};inline=1`
  return `\x1b]1337;File=${args}:${base64}\x07`
}

// Simple toast notification
const showToast = (message: string, type: 'success' | 'error'): void => {
  // Create toast element
  const toast = document.createElement('div')
  toast.className = `fixed top-4 right-4 px-4 py-2 rounded-lg text-white text-sm z-50 transition-opacity duration-300 ${
    type === 'success' ? 'bg-green-600' : 'bg-red-600'
  }`
  toast.textContent = message
  toast.style.opacity = '0'
  
  document.body.appendChild(toast)
  
  // Fade in
  requestAnimationFrame(() => {
    toast.style.opacity = '1'
  })
  
  // Remove after 3 seconds
  setTimeout(() => {
    toast.style.opacity = '0'
    setTimeout(() => {
      document.body.removeChild(toast)
    }, 300)
  }, 3000)
}
</script>

<style scoped>
.hover-bg:hover {
  filter: brightness(1.2);
}

.drag-over {
  position: relative;
}

.drag-over::before {
  content: '';
  position: absolute;
  inset: 0;
  background: rgba(59, 130, 246, 0.1);
  border: 2px dashed #3b82f6;
  pointer-events: none;
  z-index: 10;
}

.drag-over::after {
  content: 'Drop image here';
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  font-size: 1.5rem;
  color: #3b82f6;
  pointer-events: none;
  z-index: 11;
}
</style>
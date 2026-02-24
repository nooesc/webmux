<template>
  <div class="h-full flex flex-col" style="background: var(--bg-primary)">
    <!-- Header bar -->
    <div class="px-3 py-2 flex-shrink-0 border-b"
         style="background: var(--bg-secondary); border-color: var(--border-primary)">
      <div class="flex items-center justify-between">
        <div class="flex items-center space-x-3 text-xs">
          <span style="color: var(--text-tertiary)">Chat:</span>
          <span style="color: var(--text-primary)" class="font-medium">{{ session }}</span>
          <span v-if="detectedTool" class="px-1.5 py-0.5 rounded text-xs"
                style="background: var(--bg-tertiary); color: var(--accent-primary)">
            {{ detectedTool }}
          </span>
        </div>
        <button
          @click="$emit('switch-to-terminal')"
          class="px-2 py-1 text-xs rounded hover-bg"
          style="background: var(--bg-tertiary); color: var(--text-primary)"
        >
          Terminal
        </button>
      </div>
    </div>

    <!-- Message list -->
    <div
      ref="messageListRef"
      class="flex-1 overflow-y-auto px-4 py-3 space-y-4"
    >
      <!-- Empty state -->
      <div v-if="messages.length === 0 && !error" class="flex flex-col items-center justify-center h-full">
        <p style="color: var(--text-tertiary)" class="text-sm">
          {{ isConnected ? 'Detecting AI session...' : 'Connecting...' }}
        </p>
      </div>

      <!-- Error state -->
      <div v-else-if="error" class="flex flex-col items-center justify-center h-full space-y-3">
        <p style="color: var(--accent-danger)" class="text-sm">{{ error }}</p>
        <button
          @click="$emit('switch-to-terminal')"
          class="px-3 py-1.5 text-xs rounded"
          style="background: var(--bg-tertiary); color: var(--text-primary)"
        >
          Switch to Terminal
        </button>
      </div>

      <!-- Messages -->
      <template v-else>
        <div
          v-for="(msg, msgIdx) in messages"
          :key="msgIdx"
          class="chat-message rounded-lg px-4 py-3"
          :class="msg.role === 'user' ? 'chat-message--user' : 'chat-message--assistant'"
        >
          <!-- Message header -->
          <div class="flex items-center justify-between mb-2">
            <span class="text-xs font-medium" :style="msg.role === 'user'
              ? 'color: var(--accent-primary)'
              : 'color: var(--accent-success)'">
              {{ msg.role === 'user' ? 'You' : 'Assistant' }}
            </span>
            <span v-if="msg.timestamp" class="text-xs" style="color: var(--text-tertiary)">
              {{ formatTimestamp(msg.timestamp) }}
            </span>
          </div>

          <!-- Content blocks -->
          <div v-for="(block, blockIdx) in msg.blocks" :key="blockIdx" class="mb-2 last:mb-0">
            <!-- Text block -->
            <div
              v-if="block.type === 'text'"
              class="markdown-body"
              v-html="renderMarkdown(block.text)"
            ></div>

            <!-- Tool call block -->
            <div v-else-if="block.type === 'tool_call'" class="tool-card rounded border"
                 style="border-color: var(--border-primary); background: var(--bg-secondary)">
              <button
                class="w-full flex items-center px-3 py-2 text-left text-sm"
                @click="toggleBlock(msgIdx, blockIdx)"
              >
                <span class="mr-2 text-xs flex-shrink-0">{{ getToolIcon(block.name) }}</span>
                <span class="font-medium mr-2" style="color: var(--accent-primary)">{{ block.name }}</span>
                <span class="text-xs truncate flex-1" style="color: var(--text-secondary)">{{ block.summary }}</span>
                <span class="ml-2 text-xs transition-transform flex-shrink-0"
                      :class="{ 'rotate-90': isExpanded(msgIdx, blockIdx) }"
                      style="color: var(--text-tertiary)">
                  &#x25B6;
                </span>
              </button>
              <div v-if="isExpanded(msgIdx, blockIdx) && block.input" class="px-3 pb-3">
                <pre class="tool-input-pre text-xs rounded p-2 overflow-x-auto"
                     style="background: var(--bg-tertiary); color: var(--text-secondary)">{{ formatJson(block.input) }}</pre>
              </div>
            </div>

            <!-- Tool result block -->
            <div v-else-if="block.type === 'tool_result'" class="tool-card rounded border ml-4"
                 style="border-color: var(--border-secondary); background: var(--bg-secondary)">
              <button
                class="w-full flex items-center px-3 py-2 text-left text-sm"
                @click="toggleBlock(msgIdx, blockIdx)"
              >
                <span class="text-xs truncate flex-1" style="color: var(--text-secondary)">{{ block.summary }}</span>
                <span class="ml-2 text-xs transition-transform flex-shrink-0"
                      :class="{ 'rotate-90': isExpanded(msgIdx, blockIdx) }"
                      style="color: var(--text-tertiary)">
                  &#x25B6;
                </span>
              </button>
              <div v-if="isExpanded(msgIdx, blockIdx) && block.content" class="px-3 pb-3">
                <pre class="tool-result-pre text-xs rounded p-2 overflow-auto"
                     style="background: var(--bg-tertiary); color: var(--text-secondary); max-height: 300px">{{ block.content }}</pre>
              </div>
            </div>
          </div>
        </div>
      </template>
    </div>

    <!-- Input bar -->
    <div class="flex-shrink-0 px-3 py-2 border-t"
         style="background: var(--bg-secondary); border-color: var(--border-primary)">
      <div class="flex items-end space-x-2">
        <textarea
          ref="inputRef"
          v-model="inputText"
          @input="autoResizeInput"
          @keydown="handleInputKeydown"
          placeholder="Send a message..."
          rows="1"
          class="flex-1 rounded px-3 py-2 text-sm resize-none"
          style="background: var(--bg-tertiary); color: var(--text-primary); border: 1px solid var(--border-primary); max-height: 120px; outline: none"
        ></textarea>
        <button
          @click="sendMessage"
          :disabled="!inputText.trim()"
          class="px-3 py-2 rounded text-sm font-medium flex-shrink-0"
          :style="inputText.trim()
            ? 'background: var(--accent-primary); color: var(--bg-primary); cursor: pointer'
            : 'background: var(--bg-tertiary); color: var(--text-tertiary); cursor: not-allowed'"
        >
          Send
        </button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted, watch, nextTick, computed } from 'vue'
import { Marked } from 'marked'
import hljs from 'highlight.js'
import 'highlight.js/styles/github-dark.css'
import type {
  ChatMessage,
  ChatHistoryMessage,
  ChatEventMessage,
  ChatLogErrorMessage,
  AiTool,
} from '@/types'
import type { UseWebSocketReturn } from '@/composables/useWebSocket'

interface Props {
  session: string
  windowIndex: number
  ws: UseWebSocketReturn
}

const props = defineProps<Props>()

defineEmits<{
  'switch-to-terminal': []
}>()

// --- State ---

const messages = ref<ChatMessage[]>([])
const error = ref<string | null>(null)
const detectedTool = ref<AiTool | null>(null)
const inputText = ref('')
const messageListRef = ref<HTMLDivElement | null>(null)
const inputRef = ref<HTMLTextAreaElement | null>(null)
const expandedBlocks = ref<Set<string>>(new Set())
// Track texts we sent optimistically so we can dedup when the watcher echoes them back
const pendingSentTexts = ref<string[]>([])

const isConnected = computed(() => props.ws.isConnected.value)

// --- Markdown renderer ---

const markedInstance = new Marked({
  gfm: true,
  breaks: true,
  renderer: {
    code({ text, lang }: { text: string; lang?: string }): string {
      const language = lang && hljs.getLanguage(lang) ? lang : undefined
      const highlighted = language
        ? hljs.highlight(text, { language }).value
        : hljs.highlightAuto(text).value
      const langLabel = language ?? ''
      return `<pre><code class="hljs${langLabel ? ` language-${langLabel}` : ''}">${highlighted}</code></pre>`
    },
  },
})

// --- Helpers ---

function renderMarkdown(text: string): string {
  const result = markedInstance.parse(text, { async: false })
  return result as string
}

function formatTimestamp(ts: string): string {
  const date = new Date(ts)
  if (isNaN(date.getTime())) return ts
  return date.toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' })
}

function formatJson(input: Record<string, unknown>): string {
  return JSON.stringify(input, null, 2)
}

const TOOL_ICONS: Record<string, string> = {
  Read: '\u{1F4C4}',
  Edit: '\u{270F}\u{FE0F}',
  Write: '\u{1F4DD}',
  Bash: '\u{1F4BB}',
  Glob: '\u{1F50D}',
  Grep: '\u{1F50D}',
  Task: '\u{1F916}',
  TaskCreate: '\u{1F916}',
  TaskUpdate: '\u{1F916}',
  TaskList: '\u{1F916}',
  TaskGet: '\u{1F916}',
  WebSearch: '\u{1F310}',
  WebFetch: '\u{1F310}',
}

function getToolIcon(name: string): string {
  return TOOL_ICONS[name] ?? '\u{1F527}'
}

function blockKey(msgIdx: number, blockIdx: number): string {
  return `${msgIdx}:${blockIdx}`
}

function isExpanded(msgIdx: number, blockIdx: number): boolean {
  return expandedBlocks.value.has(blockKey(msgIdx, blockIdx))
}

function toggleBlock(msgIdx: number, blockIdx: number): void {
  const key = blockKey(msgIdx, blockIdx)
  if (expandedBlocks.value.has(key)) {
    expandedBlocks.value.delete(key)
  } else {
    expandedBlocks.value.add(key)
  }
}

// --- Message merging ---

/**
 * Merge consecutive assistant messages into one.  Claude Code writes each
 * block (text, tool_use) as a separate JSONL entry, but we want to present
 * them as a single assistant turn.
 */
function mergeMessages(msgs: ChatMessage[]): ChatMessage[] {
  const merged: ChatMessage[] = []
  for (const msg of msgs) {
    const last = merged[merged.length - 1]
    if (last && last.role === 'assistant' && msg.role === 'assistant') {
      last.blocks.push(...msg.blocks)
      // Keep the earliest timestamp
      if (!last.timestamp && msg.timestamp) last.timestamp = msg.timestamp
    } else {
      // Push a shallow copy so we can safely mutate blocks later
      merged.push({ ...msg, blocks: [...msg.blocks] })
    }
  }
  return merged
}

// --- Auto-scroll ---

function scrollToBottom(): void {
  nextTick(() => {
    // Use rAF to ensure the browser has laid out the DOM
    requestAnimationFrame(() => {
      if (messageListRef.value) {
        messageListRef.value.scrollTop = messageListRef.value.scrollHeight
      }
    })
  })
}

function isNearBottom(): boolean {
  if (!messageListRef.value) return true
  const el = messageListRef.value
  return el.scrollHeight - el.scrollTop - el.clientHeight < 80
}

// --- Input handling ---

function autoResizeInput(): void {
  const el = inputRef.value
  if (!el) return
  el.style.height = 'auto'
  el.style.height = Math.min(el.scrollHeight, 120) + 'px'
}

function handleInputKeydown(e: KeyboardEvent): void {
  if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault()
    sendMessage()
  }
}

function sendMessage(): void {
  const text = inputText.value.trim()
  if (!text) return

  // Show the message immediately in the chat (optimistic)
  messages.value.push({
    role: 'user',
    blocks: [{ type: 'text', text }],
  })
  pendingSentTexts.value.push(text)
  scrollToBottom()

  // Send to the tmux pane via PTY
  props.ws.send({ type: 'input', data: text + '\n' })
  inputText.value = ''

  nextTick(() => {
    if (inputRef.value) {
      inputRef.value.style.height = 'auto'
    }
  })
}

// --- WebSocket handlers ---

function handleChatHistory(data: ChatHistoryMessage): void {
  messages.value = mergeMessages(data.messages)
  detectedTool.value = data.tool
  error.value = null
  scrollToBottom()
}

function handleChatEvent(data: ChatEventMessage): void {
  const shouldScroll = isNearBottom()
  const msg = data.message

  // Dedup: if this is a user message that matches one we sent optimistically,
  // skip it (we already show it locally).
  if (msg.role === 'user' && pendingSentTexts.value.length > 0) {
    const incomingText = msg.blocks
      .filter(b => b.type === 'text')
      .map(b => (b as { type: 'text'; text: string }).text)
      .join('')
      .trim()
    const idx = pendingSentTexts.value.indexOf(incomingText)
    if (idx !== -1) {
      pendingSentTexts.value.splice(idx, 1)
      return // already displayed optimistically
    }
  }

  const last = messages.value[messages.value.length - 1]

  // Merge consecutive assistant blocks into the same message bubble
  if (last && last.role === 'assistant' && msg.role === 'assistant') {
    last.blocks.push(...msg.blocks)
  } else {
    messages.value.push(msg)
  }

  if (shouldScroll) {
    scrollToBottom()
  }
}

function handleChatLogError(data: ChatLogErrorMessage): void {
  error.value = data.error
}

function watchChatLog(): void {
  messages.value = []
  error.value = null
  detectedTool.value = null
  expandedBlocks.value.clear()
  pendingSentTexts.value = []

  props.ws.send({
    type: 'watch-chat-log',
    sessionName: props.session,
    windowIndex: props.windowIndex,
  })
}

function unwatchChatLog(): void {
  props.ws.send({ type: 'unwatch-chat-log' })
}

// --- Lifecycle ---

onMounted(async () => {
  props.ws.onMessage<ChatHistoryMessage>('chat-history', handleChatHistory)
  props.ws.onMessage<ChatEventMessage>('chat-event', handleChatEvent)
  props.ws.onMessage<ChatLogErrorMessage>('chat-log-error', handleChatLogError)

  await props.ws.ensureConnected()
  watchChatLog()
})

onUnmounted(() => {
  unwatchChatLog()
  props.ws.offMessage('chat-history')
  props.ws.offMessage('chat-event')
  props.ws.offMessage('chat-log-error')
})

watch(
  () => [props.session, props.windowIndex],
  () => {
    unwatchChatLog()
    watchChatLog()
  },
)
</script>

<style scoped>
.chat-message {
  border-left: 3px solid transparent;
}

.chat-message--user {
  border-left-color: var(--accent-primary);
  background: rgba(88, 166, 255, 0.04);
}

.chat-message--assistant {
  border-left-color: var(--accent-success);
  background: rgba(63, 185, 80, 0.04);
}

.tool-card {
  transition: background 0.15s;
}

.tool-card:hover {
  background: var(--bg-tertiary);
}

.tool-input-pre,
.tool-result-pre {
  white-space: pre-wrap;
  word-break: break-word;
  margin: 0;
}

.rotate-90 {
  transform: rotate(90deg);
}

.transition-transform {
  transition: transform 0.15s;
}

.hover-bg:hover {
  filter: brightness(1.2);
}

/* Markdown body styles scoped to this component */
.markdown-body {
  color: var(--text-primary);
  font-size: 0.875rem;
  line-height: 1.6;
  word-wrap: break-word;
}

.markdown-body :deep(h1),
.markdown-body :deep(h2),
.markdown-body :deep(h3),
.markdown-body :deep(h4),
.markdown-body :deep(h5),
.markdown-body :deep(h6) {
  margin-top: 1em;
  margin-bottom: 0.5em;
  font-weight: 600;
  color: var(--text-primary);
}

.markdown-body :deep(h1) { font-size: 1.25rem; }
.markdown-body :deep(h2) { font-size: 1.125rem; }
.markdown-body :deep(h3) { font-size: 1rem; }

.markdown-body :deep(p) {
  margin-top: 0;
  margin-bottom: 0.75em;
}

.markdown-body :deep(p:last-child) {
  margin-bottom: 0;
}

.markdown-body :deep(pre) {
  background: var(--bg-tertiary);
  border: 1px solid var(--border-primary);
  border-radius: 6px;
  padding: 12px;
  overflow-x: auto;
  margin: 0.75em 0;
}

.markdown-body :deep(code) {
  font-family: 'JetBrainsMono Nerd Font', 'JetBrains Mono', 'SF Mono', monospace;
  font-size: 0.8rem;
}

.markdown-body :deep(:not(pre) > code) {
  background: var(--bg-tertiary);
  padding: 0.15em 0.35em;
  border-radius: 3px;
  color: var(--accent-primary);
}

.markdown-body :deep(a) {
  color: var(--accent-primary);
  text-decoration: none;
}

.markdown-body :deep(a:hover) {
  text-decoration: underline;
}

.markdown-body :deep(ul),
.markdown-body :deep(ol) {
  padding-left: 1.5em;
  margin: 0.5em 0;
}

.markdown-body :deep(li) {
  margin-bottom: 0.25em;
}

.markdown-body :deep(blockquote) {
  border-left: 3px solid var(--border-primary);
  padding-left: 1em;
  margin: 0.75em 0;
  color: var(--text-secondary);
}

.markdown-body :deep(hr) {
  border: none;
  border-top: 1px solid var(--border-primary);
  margin: 1em 0;
}

.markdown-body :deep(table) {
  border-collapse: collapse;
  width: 100%;
  margin: 0.75em 0;
}

.markdown-body :deep(th),
.markdown-body :deep(td) {
  border: 1px solid var(--border-primary);
  padding: 6px 12px;
  text-align: left;
}

.markdown-body :deep(th) {
  background: var(--bg-tertiary);
  font-weight: 600;
}

.markdown-body :deep(img) {
  max-width: 100%;
  border-radius: 6px;
}

.markdown-body :deep(strong) {
  color: var(--text-primary);
  font-weight: 600;
}

.markdown-body :deep(em) {
  font-style: italic;
}
</style>

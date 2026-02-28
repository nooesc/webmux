<template>
  <div class="border-t" style="border-color: var(--border-primary)">
    <!-- CRON Header -->
    <div class="p-3">
      <!-- Collapsed state - icon only -->
      <button
        v-if="isCollapsed"
        @click="toggleExpanded"
        class="w-full flex items-center justify-center hover-bg rounded p-2"
        :title="`CRON Jobs (${jobs.length})`"
      >
        <div class="relative">
          <svg 
            class="w-4 h-4" 
            :class="{ 'text-green-500': isExpanded }"
            fill="none" 
            stroke="currentColor" 
            viewBox="0 0 24 24"
          >
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <!-- Job count badge -->
          <span 
            v-if="jobs.length > 0" 
            class="absolute -top-1 -right-1 w-3 h-3 text-[8px] rounded-full flex items-center justify-center font-bold"
            style="background: var(--accent-primary); color: var(--bg-primary)"
          >
            {{ jobs.length }}
          </span>
        </div>
      </button>
      
      <!-- Expanded state - full header -->
      <button
        v-else
        @click="toggleExpanded"
        class="w-full flex items-center justify-between hover-bg rounded p-2 -m-2"
      >
        <div class="flex items-center space-x-2">
          <!-- Clock icon -->
          <svg 
            class="w-4 h-4" 
            :class="{ 'text-green-500': isExpanded }"
            fill="none" 
            stroke="currentColor" 
            viewBox="0 0 24 24"
          >
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <span class="text-xs font-medium" style="color: var(--text-secondary)">
            CRON ({{ jobs.length }})
          </span>
        </div>
        
        <!-- Expand/Collapse icon -->
        <svg 
          class="w-3 h-3 transition-transform" 
          :class="{ 'rotate-180': isExpanded }"
          fill="none" 
          stroke="currentColor" 
          viewBox="0 0 24 24"
        >
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
        </svg>
      </button>
    </div>
    
    <!-- CRON Content -->
    <div v-show="isExpanded && !isCollapsed" class="px-3 pb-3">
      <!-- Loading state -->
      <div v-if="isLoading" class="py-4 text-center">
        <div class="animate-pulse text-xs" style="color: var(--text-tertiary)">
          Loading cron jobs...
        </div>
      </div>
      
      <!-- Error state -->
      <div v-else-if="error" class="py-4">
        <div class="text-xs text-red-500">
          {{ error }}
        </div>
      </div>
      
      <!-- Job list -->
      <div v-else-if="jobs.length > 0" class="space-y-2 mb-3">
        <CronJobItem
          v-for="job in jobs"
          :key="job.id"
          :job="job"
          @edit="editJob"
          @toggle="toggleJob"
          @delete="deleteJob"
          @test="testJob"
        />
      </div>
      
      <!-- Empty state -->
      <div v-else class="py-4 text-center">
        <p class="text-xs" style="color: var(--text-tertiary)">
          No cron jobs configured
        </p>
      </div>
      
      <!-- New Job button -->
      <button
        @click="showCreateModal = true"
        class="w-full px-3 py-1.5 text-xs border rounded transition-colors hover-bg"
        style="background: var(--bg-primary); border-color: var(--border-primary); color: var(--text-primary)"
      >
        <div class="flex items-center justify-center space-x-1">
          <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
          </svg>
          <span>New Job</span>
        </div>
      </button>
    </div>
    
    <!-- Create/Edit Modal -->
    <CronJobEditor
      v-if="showCreateModal || editingJob"
      :job="editingJob"
      @save="saveJob"
      @cancel="cancelEdit"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import { useWebSocket } from '@/composables/useWebSocket'
import CronJobItem from './CronJobItem.vue'
import CronJobEditor from './CronJobEditor.vue'
import type { 
  CronJob, 
  ListCronJobsMessage, 
  CronJobsListMessage,
  CronJobCreatedMessage,
  CronJobUpdatedMessage,
  CronJobDeletedMessage,
  CreateCronJobMessage,
  UpdateCronJobMessage,
  DeleteCronJobMessage,
  ToggleCronJobMessage
} from '@/types'

interface Props {
  isCollapsed?: boolean
}

withDefaults(defineProps<Props>(), {
  isCollapsed: false
})

const ws = useWebSocket()

const isExpanded = ref(false)
const isLoading = ref(false)
const error = ref<string | null>(null)
const jobs = ref<CronJob[]>([])
const showCreateModal = ref(false)
const editingJob = ref<CronJob | null>(null)

const toggleExpanded = () => {
  isExpanded.value = !isExpanded.value
  if (isExpanded.value && jobs.value.length === 0) {
    loadJobs()
  }
}

const loadJobs = async () => {
  if (!ws.isConnected.value) return
  
  isLoading.value = true
  error.value = null
  
  const message: ListCronJobsMessage = {
    type: 'list-cron-jobs'
  }
  ws.send(message)
}

const editJob = (job: CronJob) => {
  editingJob.value = { ...job }
}

const toggleJob = (job: CronJob) => {
  const message: ToggleCronJobMessage = {
    type: 'toggle-cron-job',
    id: job.id,
    enabled: !job.enabled
  }
  ws.send(message)
}

const deleteJob = (job: CronJob) => {
  if (!confirm(`Are you sure you want to delete "${job.name}"?`)) return
  
  const message: DeleteCronJobMessage = {
    type: 'delete-cron-job',
    id: job.id
  }
  ws.send(message)
}

const testJob = (job: CronJob) => {
  // TODO: Implement test functionality
  console.log('Test job:', job)
}

const saveJob = (job: CronJob) => {
  if (editingJob.value) {
    // Update existing job
    const message: UpdateCronJobMessage = {
      type: 'update-cron-job',
      id: job.id,
      job
    }
    ws.send(message)
  } else {
    // Create new job
    const message: CreateCronJobMessage = {
      type: 'create-cron-job',
      job
    }
    ws.send(message)
  }
  
  cancelEdit()
}

const cancelEdit = () => {
  showCreateModal.value = false
  editingJob.value = null
}

onMounted(() => {
  // Listen for cron-related messages
  ws.onMessage<CronJobsListMessage>('cron-jobs-list', (msg) => {
    jobs.value = msg.jobs
    isLoading.value = false
  })
  
  ws.onMessage<CronJobCreatedMessage>('cron-job-created', (msg) => {
    jobs.value.push(msg.job)
  })
  
  ws.onMessage<CronJobUpdatedMessage>('cron-job-updated', (msg) => {
    const index = jobs.value.findIndex(j => j.id === msg.job.id)
    if (index >= 0) {
      jobs.value[index] = msg.job
    }
  })
  
  ws.onMessage<CronJobDeletedMessage>('cron-job-deleted', (msg) => {
    jobs.value = jobs.value.filter(j => j.id !== msg.id)
  })
  
  // Handle errors
  ws.onMessage('error', (msg: any) => {
    if (msg.message?.includes('cron')) {
      error.value = msg.message
      isLoading.value = false
    }
  })
})

onUnmounted(() => {
  ws.offMessage('cron-jobs-list')
  ws.offMessage('cron-job-created')
  ws.offMessage('cron-job-updated')
  ws.offMessage('cron-job-deleted')
})
</script>

<style scoped>
.hover-bg:hover {
  filter: brightness(1.2);
}

.rotate-180 {
  transform: rotate(180deg);
}
</style>
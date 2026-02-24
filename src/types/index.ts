// WebSocket message types
export interface WsMessage {
  type: string;
  [key: string]: string | number | boolean | object | undefined;
}

export interface AttachSessionMessage extends WsMessage {
  type: 'attach-session';
  sessionName: string;
  cols: number;
  rows: number;
}

export interface InputMessage extends WsMessage {
  type: 'input';
  data: string;
}

export interface ResizeMessage extends WsMessage {
  type: 'resize';
  cols: number;
  rows: number;
}

export interface ListWindowsMessage extends WsMessage {
  type: 'list-windows';
  sessionName: string;
}

export interface SelectWindowMessage extends WsMessage {
  type: 'select-window';
  sessionName: string;
  windowIndex: number;
}

// Server response types
export interface OutputMessage extends WsMessage {
  type: 'output';
  data: string;
}

export interface AttachedMessage extends WsMessage {
  type: 'attached';
  sessionName: string;
}

export interface DisconnectedMessage extends WsMessage {
  type: 'disconnected';
}

export interface WindowsListMessage extends WsMessage {
  type: 'windows-list';
  sessionName: string;
  windows: TmuxWindow[];
}

// TMUX types
export interface TmuxSession {
  name: string;
  windows: number;
  created: string;
  attached: boolean;
  dimensions?: string;
}

export interface TmuxWindow {
  index: number;
  name: string;
  active: boolean;
  panes: number;
}

// API response types
export interface ApiResponse<T = unknown> {
  success: boolean;
  data?: T;
  error?: string;
}

// Terminal types
export interface TerminalSize {
  cols: number;
  rows: number;
}

// System stats
export interface SystemStats {
  hostname: string;
  platform: string;
  arch: string;
  uptime: number;
  cpu: {
    model: string;
    cores: number;
    usage: number;
    loadAvg: number[];
  };
  memory: {
    total: number;
    used: number;
    free: number;
    percent: string;
  };
}

// Additional WebSocket messages
export interface SessionsListMessage extends WsMessage {
  type: 'sessions-list';
  sessions: TmuxSession[];
}

export interface StatsMessage extends WsMessage {
  type: 'stats';
  stats: {
    cpu: {
      cores: number;
      model: string;
      usage: number;
      loadAvg: number[];
    };
    memory: {
      total: number;
      used: number;
      free: number;
      percent: string;
    };
    uptime: number;
    hostname: string;
    platform: string;
    arch: string;
  };
}

export interface ErrorMessage extends WsMessage {
  type: 'error';
  message: string;
}

export interface WindowSelectedMessage extends WsMessage {
  type: 'window-selected';
  sessionName: string;
  windowIndex: number;
}

export interface SessionCreatedMessage extends WsMessage {
  type: 'session-created';
  success: boolean;
  sessionName?: string;
  error?: string;
}

export interface SessionKilledMessage extends WsMessage {
  type: 'session-killed';
  success: boolean;
  error?: string;
}

export interface SessionRenamedMessage extends WsMessage {
  type: 'session-renamed';
  success: boolean;
  error?: string;
}

export interface WindowCreatedMessage extends WsMessage {
  type: 'window-created';
  success: boolean;
  error?: string;
}

export interface WindowKilledMessage extends WsMessage {
  type: 'window-killed';
  success: boolean;
  error?: string;
}

export interface WindowRenamedMessage extends WsMessage {
  type: 'window-renamed';
  success: boolean;
  error?: string;
}

// Audio streaming messages
export type AudioAction = 'start' | 'stop';

export interface AudioControlMessage extends WsMessage {
  type: 'audio-control';
  action: AudioAction;
}

export interface AudioStatusMessage extends WsMessage {
  type: 'audio-status';
  streaming: boolean;
  error?: string;
}

export interface AudioStreamMessage extends WsMessage {
  type: 'audio-stream';
  data: string; // base64 encoded audio data
}

// API-specific response types
export interface SessionCreateResponse {
  success: boolean;
  sessionName: string;
  message?: string;
}
export interface SessionActionResponse {
  success: boolean;
  message?: string;
}
export interface WindowsListResponse {
  windows: TmuxWindow[];
}
export interface WindowCreateResponse {
  success: boolean;
  window?: TmuxWindow;
  message?: string;
}

// Cron management types
export interface CronJob {
  id: string;
  name: string;
  schedule: string;
  command: string;
  enabled: boolean;
  lastRun?: string;
  nextRun?: string;
  createdAt: string;
  updatedAt: string;
  environment?: Record<string, string>;
  logOutput?: boolean;
  emailTo?: string;
  tmuxSession?: string;
}

export interface JobExecution {
  jobId: string;
  startedAt: string;
  finishedAt?: string;
  success: boolean;
  output?: string;
  error?: string;
}

// Cron WebSocket messages
export interface ListCronJobsMessage extends WsMessage {
  type: 'list-cron-jobs';
}

export interface CreateCronJobMessage extends WsMessage {
  type: 'create-cron-job';
  job: CronJob;
}

export interface UpdateCronJobMessage extends WsMessage {
  type: 'update-cron-job';
  id: string;
  job: CronJob;
}

export interface DeleteCronJobMessage extends WsMessage {
  type: 'delete-cron-job';
  id: string;
}

export interface ToggleCronJobMessage extends WsMessage {
  type: 'toggle-cron-job';
  id: string;
  enabled: boolean;
}

export interface TestCronCommandMessage extends WsMessage {
  type: 'test-cron-command';
  command: string;
}

// Cron server responses
export interface CronJobsListMessage extends WsMessage {
  type: 'cron-jobs-list';
  jobs: CronJob[];
}

export interface CronJobCreatedMessage extends WsMessage {
  type: 'cron-job-created';
  job: CronJob;
}

export interface CronJobUpdatedMessage extends WsMessage {
  type: 'cron-job-updated';
  job: CronJob;
}

export interface CronJobDeletedMessage extends WsMessage {
  type: 'cron-job-deleted';
  id: string;
}

export interface CronCommandOutputMessage extends WsMessage {
  type: 'cron-command-output';
  output: string;
  error?: string;
}

// Dotfile management types
export type DotFileType = 'Shell' | 'Git' | 'Vim' | 'Tmux' | 'SSH' | 'Other';

export interface DotFile {
  name: string;
  path: string;
  size: number;
  modified: string;
  exists: boolean;
  readable: boolean;
  writable: boolean;
  fileType: DotFileType;
}

export interface FileVersion {
  timestamp: string;
  content: string;
  size: number;
  hash: string;
}

export interface DotFileTemplate {
  name: string;
  fileType: DotFileType;
  description: string;
  content: string;
}

// Dotfile client messages
export interface ListDotfilesMessage extends WsMessage {
  type: 'list-dotfiles';
}

export interface ReadDotfileMessage extends WsMessage {
  type: 'read-dotfile';
  path: string;
}

export interface WriteDotfileMessage extends WsMessage {
  type: 'write-dotfile';
  path: string;
  content: string;
}

export interface GetDotfileHistoryMessage extends WsMessage {
  type: 'get-dotfile-history';
  path: string;
}

export interface RestoreDotfileVersionMessage extends WsMessage {
  type: 'restore-dotfile-version';
  path: string;
  timestamp: string;
}

export interface GetDotfileTemplatesMessage extends WsMessage {
  type: 'get-dotfile-templates';
}

// Dotfile server responses
export interface DotfilesListMessage extends WsMessage {
  type: 'dotfiles-list';
  files: DotFile[];
}

export interface DotfileContentMessage extends WsMessage {
  type: 'dotfile-content';
  path: string;
  content: string;
  error?: string;
}

export interface DotfileWrittenMessage extends WsMessage {
  type: 'dotfile-written';
  path: string;
  success: boolean;
  error?: string;
}

export interface DotfileHistoryMessage extends WsMessage {
  type: 'dotfile-history';
  path: string;
  versions: FileVersion[];
}

export interface DotfileRestoredMessage extends WsMessage {
  type: 'dotfile-restored';
  path: string;
  success: boolean;
  error?: string;
}

export interface DotfileTemplatesMessage extends WsMessage {
  type: 'dotfile-templates';
  templates: DotFileTemplate[];
}

// Chat log types
export type AiTool = 'claude' | 'codex';

export interface TextBlock {
  type: 'text';
  text: string;
}

export interface ToolCallBlock {
  type: 'tool_call';
  name: string;
  summary: string;
  input?: Record<string, unknown>;
}

export interface ToolResultBlock {
  type: 'tool_result';
  toolName: string;
  summary: string;
  content?: string;
}

export type ChatContentBlock = TextBlock | ToolCallBlock | ToolResultBlock;

export interface ChatMessage {
  role: 'user' | 'assistant';
  timestamp?: string;
  blocks: ChatContentBlock[];
}

export interface WatchChatLogMessage extends WsMessage {
  type: 'watch-chat-log';
  sessionName: string;
  windowIndex: number;
}

export interface UnwatchChatLogMessage extends WsMessage {
  type: 'unwatch-chat-log';
}

export interface ChatHistoryMessage extends WsMessage {
  type: 'chat-history';
  messages: ChatMessage[];
  tool: AiTool | null;
}

export interface ChatEventMessage extends WsMessage {
  type: 'chat-event';
  message: ChatMessage;
}

export interface ChatLogErrorMessage extends WsMessage {
  type: 'chat-log-error';
  error: string;
}

// Union type for all server messages
export type ServerMessage = 
  | SessionsListMessage
  | AttachedMessage
  | OutputMessage
  | DisconnectedMessage
  | WindowsListMessage
  | WindowSelectedMessage
  | SessionCreatedMessage
  | SessionKilledMessage
  | SessionRenamedMessage
  | WindowCreatedMessage
  | WindowKilledMessage
  | WindowRenamedMessage
  | StatsMessage
  | ErrorMessage
  | CronJobsListMessage
  | CronJobCreatedMessage
  | CronJobUpdatedMessage
  | CronJobDeletedMessage
  | CronCommandOutputMessage
  | DotfilesListMessage
  | DotfileContentMessage
  | DotfileWrittenMessage
  | DotfileHistoryMessage
  | DotfileRestoredMessage
  | DotfileTemplatesMessage
  | ChatHistoryMessage
  | ChatEventMessage
  | ChatLogErrorMessage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/cron_job.dart';
import '../../../data/services/websocket_service.dart';
import '../../sessions/providers/sessions_provider.dart';

class CronState {
  final List<CronJob> jobs;
  final bool isLoading;
  final String? error;
  final String? testOutput;
  final bool isTesting;

  const CronState({
    this.jobs = const [],
    this.isLoading = false,
    this.error,
    this.testOutput,
    this.isTesting = false,
  });

  CronState copyWith({
    List<CronJob>? jobs,
    bool? isLoading,
    String? error,
    String? testOutput,
    bool? isTesting,
  }) {
    return CronState(
      jobs: jobs ?? this.jobs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      testOutput: testOutput,
      isTesting: isTesting ?? this.isTesting,
    );
  }
}

class CronNotifier extends StateNotifier<CronState> {
  final WebSocketService _wsService;

  CronNotifier(this._wsService) : super(const CronState()) {
    _init();
  }

  void _init() {
    _wsService.messages.listen((message) {
      final type = message['type'] as String?;

      switch (type) {
        case 'cron-jobs-list':
        case 'cron_jobs_list':
          final jobs =
              (message['jobs'] as List?)
                  ?.map((j) => CronJob.fromJson(j as Map<String, dynamic>))
                  .toList() ??
              [];
          state = state.copyWith(jobs: jobs, isLoading: false);
          break;
        case 'cron-job-created':
        case 'cron_job_created':
          final job = CronJob.fromJson(message['job'] as Map<String, dynamic>);
          state = state.copyWith(jobs: [...state.jobs, job]);
          break;
        case 'cron-job-updated':
        case 'cron_job_updated':
          final job = CronJob.fromJson(message['job'] as Map<String, dynamic>);
          final index = state.jobs.indexWhere((j) => j.id == job.id);
          if (index >= 0) {
            final newJobs = List<CronJob>.from(state.jobs);
            newJobs[index] = job;
            state = state.copyWith(jobs: newJobs);
          }
          break;
        case 'cron-job-deleted':
        case 'cron_job_deleted':
          final id = message['id'] as String?;
          if (id != null) {
            state = state.copyWith(
              jobs: state.jobs.where((j) => j.id != id).toList(),
            );
          }
          break;
        case 'cron-command-output':
        case 'cron_command_output':
          state = state.copyWith(
            isTesting: false,
            testOutput:
                message['error'] as String? ??
                message['output'] as String? ??
                '',
          );
          break;
        case 'error':
          final errorMsg = message['message'] as String?;
          if (errorMsg != null && errorMsg.contains('cron')) {
            state = state.copyWith(error: errorMsg, isLoading: false);
          }
          break;
      }
    });

    _wsService.connectionState.listen((connected) {
      if (connected) {
        refresh();
      }
    });
  }

  void refresh() {
    if (!_wsService.isConnected) {
      return;
    }
    if (state.isLoading) {
      return;
    }
    state = state.copyWith(isLoading: true);
    _wsService.requestCronJobs();
  }

  Future<void> createCronJob(CronJob job) async {
    state = state.copyWith(jobs: [...state.jobs, job]);
    _wsService.createCronJob(job);
  }

  Future<void> updateCronJob(CronJob job) async {
    final index = state.jobs.indexWhere((j) => j.id == job.id);
    if (index >= 0) {
      final newJobs = List<CronJob>.from(state.jobs);
      newJobs[index] = job;
      state = state.copyWith(jobs: newJobs);
    }
    _wsService.updateCronJob(job);
  }

  Future<void> toggleCronJob(String id) async {
    final jobIndex = state.jobs.indexWhere((j) => j.id == id);
    if (jobIndex != -1) {
      final job = state.jobs[jobIndex];
      final newJobs = List<CronJob>.from(state.jobs);
      newJobs[jobIndex] = job.copyWith(enabled: !job.enabled);
      state = state.copyWith(jobs: newJobs);
      _wsService.toggleCronJob(id, !job.enabled);
    }
  }

  Future<void> deleteCronJob(String id) async {
    final newJobs = state.jobs.where((j) => j.id != id).toList();
    state = state.copyWith(jobs: newJobs);
    _wsService.deleteCronJob(id);
  }

  Future<void> testCommand(String command) async {
    state = state.copyWith(isTesting: true, testOutput: null);
    _wsService.testCronCommand(command);
  }

  void clearTestOutput() {
    state = state.copyWith(testOutput: null, isTesting: false);
  }
}

final cronProvider = StateNotifierProvider<CronNotifier, CronState>((ref) {
  final wsService = ref.watch(sharedWebSocketServiceProvider);
  return CronNotifier(wsService);
});

import '../models/cron_job.dart';
import '../services/websocket_service.dart';

class CronRepository {
  final WebSocketService _wsService;

  CronRepository(this._wsService);

  Future<List<CronJob>> getCronJobs() async {
    _wsService.requestCronJobs();
    await Future.delayed(const Duration(milliseconds: 500));
    return [];
  }

  Future<void> createCronJob(String schedule, String command) async {
    _wsService.createCronJob(schedule, command);
  }

  Future<void> deleteCronJob(String id) async {
    _wsService.deleteCronJob(id);
  }

  Future<void> toggleCronJob(String id, bool enabled) async {
    _wsService.toggleCronJob(id, enabled);
  }

  Future<void> updateCronJob(String id, String schedule, String command) async {
    _wsService.send({
      'action': 'update_cron',
      'id': id,
      'schedule': schedule,
      'command': command,
    });
  }
}

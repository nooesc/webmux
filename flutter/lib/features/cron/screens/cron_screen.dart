import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/cron_job.dart';
import '../providers/cron_provider.dart';

class CronScreen extends ConsumerWidget {
  const CronScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cronState = ref.watch(cronProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cron Jobs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(cronProvider.notifier).refresh(),
          ),
        ],
      ),
      body: cronState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : cronState.jobs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.schedule, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No cron jobs',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.grey[400],
                            ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: cronState.jobs.length,
                  itemBuilder: (context, index) {
                    final job = cronState.jobs[index];
                    return _CronJobTile(
                      job: job,
                      onToggle: () {
                        ref.read(cronProvider.notifier).toggleCronJob(job.id);
                      },
                      onDelete: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Cron Job'),
                            content: Text('Delete "${job.command}"?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          ref.read(cronProvider.notifier).deleteCronJob(job.id);
                        }
                      },
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateCronDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCreateCronDialog(BuildContext context, WidgetRef ref) {
    final scheduleController = TextEditingController();
    final commandController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Cron Job'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: scheduleController,
              decoration: const InputDecoration(
                labelText: 'Schedule (cron format)',
                hintText: '* * * * *',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: commandController,
              decoration: const InputDecoration(
                labelText: 'Command',
                hintText: '/path/to/script.sh',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (scheduleController.text.isNotEmpty &&
                  commandController.text.isNotEmpty) {
                ref.read(cronProvider.notifier).createCronJob(
                      scheduleController.text,
                      commandController.text,
                    );
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _CronJobTile extends StatelessWidget {
  final CronJob job;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _CronJobTile({
    required this.job,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Switch(
          value: job.enabled,
          onChanged: (_) => onToggle(),
        ),
        title: Text(job.command),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              job.schedule,
              style: TextStyle(
                fontFamily: 'monospace',
                color: job.enabled ? Colors.green : Colors.grey,
              ),
            ),
            if (job.lastRun != null)
              Text(
                'Last run: ${job.lastRun}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
          ],
        ),
        isThreeLine: job.lastRun != null,
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: onDelete,
        ),
      ),
    );
  }
}

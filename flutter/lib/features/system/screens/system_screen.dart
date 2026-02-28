import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/system_provider.dart';

class SystemScreen extends ConsumerWidget {
  const SystemScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final systemState = ref.watch(systemProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('System'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(systemProvider.notifier).refresh(),
          ),
        ],
      ),
      body: systemState.isLoading && systemState.stats == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                ref.read(systemProvider.notifier).refresh();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // CPU Usage
                    _StatCard(
                      title: 'CPU',
                      icon: Icons.memory,
                      value: systemState.stats != null
                          ? '${systemState.stats!.cpuUsage.toStringAsFixed(1)}%'
                          : '--',
                      progress: systemState.stats?.cpuUsage,
                      color: _getUsageColor(systemState.stats?.cpuUsage),
                    ),
                    const SizedBox(height: 16),

                    // Memory Usage
                    _StatCard(
                      title: 'Memory',
                      icon: Icons.storage,
                      value: systemState.stats != null
                          ? '${systemState.stats!.memoryUsedFormatted} / ${systemState.stats!.memoryTotalFormatted}'
                          : '--',
                      subtitle: systemState.stats != null
                          ? '${systemState.stats!.memoryUsage.toStringAsFixed(1)}%'
                          : null,
                      progress: systemState.stats?.memoryUsage,
                      color: _getUsageColor(systemState.stats?.memoryUsage),
                    ),
                    const SizedBox(height: 16),

                    // Disk Usage
                    _StatCard(
                      title: 'Disk',
                      icon: Icons.disc_full,
                      value: systemState.stats != null
                          ? '${systemState.stats!.diskUsedFormatted} / ${systemState.stats!.diskTotalFormatted}'
                          : '--',
                      subtitle: systemState.stats != null
                          ? '${systemState.stats!.diskUsage.toStringAsFixed(1)}%'
                          : null,
                      progress: systemState.stats?.diskUsage,
                      color: _getUsageColor(systemState.stats?.diskUsage),
                    ),
                    const SizedBox(height: 16),

                    // Uptime
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.timer),
                        title: const Text('Uptime'),
                        subtitle: Text(
                          systemState.stats?.uptime ?? '--',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Color _getUsageColor(double? usage) {
    if (usage == null) return Colors.grey;
    if (usage < 50) return Colors.green;
    if (usage < 80) return Colors.orange;
    return Colors.red;
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String value;
  final String? subtitle;
  final double? progress;
  final Color color;

  const _StatCard({
    required this.title,
    required this.icon,
    required this.value,
    this.subtitle,
    this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(color: Colors.grey[500]),
              ),
            ],
            if (progress != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress! / 100,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 8,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

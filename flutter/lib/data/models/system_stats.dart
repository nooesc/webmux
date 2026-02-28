import 'package:equatable/equatable.dart';

class SystemStats extends Equatable {
  final double cpuUsage;
  final double memoryUsage;
  final int memoryTotal;
  final int memoryUsed;
  final double diskUsage;
  final int diskTotal;
  final int diskUsed;
  final String uptime;
  final DateTime timestamp;

  const SystemStats({
    required this.cpuUsage,
    required this.memoryUsage,
    required this.memoryTotal,
    required this.memoryUsed,
    required this.diskUsage,
    required this.diskTotal,
    required this.diskUsed,
    required this.uptime,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'cpuUsage': cpuUsage,
    'memoryUsage': memoryUsage,
    'memoryTotal': memoryTotal,
    'memoryUsed': memoryUsed,
    'diskUsage': diskUsage,
    'diskTotal': diskTotal,
    'diskUsed': diskUsed,
    'uptime': uptime,
    'timestamp': timestamp.toIso8601String(),
  };

  factory SystemStats.fromJson(Map<String, dynamic> json) {
    // Handle Capacitor format: { type: 'stats', stats: { cpu: { usage: ... }, memory: { total: ..., used: ... } } }
    if (json.containsKey('stats')) {
      final stats = json['stats'] as Map<String, dynamic>;
      final cpu = stats['cpu'] as Map<String, dynamic>?;
      final memory = stats['memory'] as Map<String, dynamic>?;

      return SystemStats(
        cpuUsage: (cpu?['usage'] as num?)?.toDouble() ?? 0.0,
        memoryUsage: memory != null && memory['total'] > 0
            ? ((memory['used'] as num) / (memory['total'] as num) * 100)
                  .toDouble()
            : 0.0,
        memoryTotal: (memory?['total'] as num?)?.toInt() ?? 0,
        memoryUsed: (memory?['used'] as num?)?.toInt() ?? 0,
        diskUsage: 0.0,
        diskTotal: 0,
        diskUsed: 0,
        uptime: _formatUptime(stats['uptime'] as int? ?? 0),
        timestamp: DateTime.now(),
      );
    }

    // Handle legacy format: { cpuUsage: ..., memoryUsage: ... }
    return SystemStats(
      cpuUsage: (json['cpuUsage'] as num).toDouble(),
      memoryUsage: (json['memoryUsage'] as num).toDouble(),
      memoryTotal: json['memoryTotal'] as int,
      memoryUsed: json['memoryUsed'] as int,
      diskUsage: (json['diskUsage'] as num).toDouble(),
      diskTotal: json['diskTotal'] as int,
      diskUsed: json['diskUsed'] as int,
      uptime: json['uptime'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  static String _formatUptime(int seconds) {
    final days = seconds ~/ 86400;
    final hours = (seconds % 86400) ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (days > 0) {
      return '${days}d ${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  String get memoryUsedFormatted => _formatBytes(memoryUsed);
  String get memoryTotalFormatted => _formatBytes(memoryTotal);
  String get diskUsedFormatted => _formatBytes(diskUsed);
  String get diskTotalFormatted => _formatBytes(diskTotal);

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  List<Object?> get props => [
    cpuUsage,
    memoryUsage,
    memoryTotal,
    memoryUsed,
    diskUsage,
    diskTotal,
    diskUsed,
    uptime,
    timestamp,
  ];
}

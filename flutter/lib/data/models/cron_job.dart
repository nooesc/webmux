import 'package:equatable/equatable.dart';

class CronJob extends Equatable {
  final String id;
  final String command;
  final String schedule;
  final bool enabled;
  final DateTime? lastRun;
  final DateTime? nextRun;
  final String? output;
  final DateTime created;

  const CronJob({
    required this.id,
    required this.command,
    required this.schedule,
    required this.enabled,
    this.lastRun,
    this.nextRun,
    this.output,
    required this.created,
  });

  CronJob copyWith({
    String? id,
    String? command,
    String? schedule,
    bool? enabled,
    DateTime? lastRun,
    DateTime? nextRun,
    String? output,
    DateTime? created,
  }) {
    return CronJob(
      id: id ?? this.id,
      command: command ?? this.command,
      schedule: schedule ?? this.schedule,
      enabled: enabled ?? this.enabled,
      lastRun: lastRun ?? this.lastRun,
      nextRun: nextRun ?? this.nextRun,
      output: output ?? this.output,
      created: created ?? this.created,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'command': command,
        'schedule': schedule,
        'enabled': enabled,
        'lastRun': lastRun?.toIso8601String(),
        'nextRun': nextRun?.toIso8601String(),
        'output': output,
        'created': created.toIso8601String(),
      };

  factory CronJob.fromJson(Map<String, dynamic> json) => CronJob(
        id: json['id'] as String,
        command: json['command'] as String,
        schedule: json['schedule'] as String,
        enabled: json['enabled'] as bool? ?? true,
        lastRun: json['lastRun'] != null
            ? DateTime.parse(json['lastRun'] as String)
            : null,
        nextRun: json['nextRun'] != null
            ? DateTime.parse(json['nextRun'] as String)
            : null,
        output: json['output'] as String?,
        created: DateTime.parse(json['created'] as String),
      );

  @override
  List<Object?> get props => [id, command, schedule, enabled, lastRun, nextRun, output, created];
}

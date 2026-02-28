import 'package:equatable/equatable.dart';

class TmuxSession extends Equatable {
  final String name;
  final bool attached;
  final int windows;
  final DateTime? created;

  const TmuxSession({
    required this.name,
    required this.attached,
    required this.windows,
    this.created,
  });

  TmuxSession copyWith({
    String? name,
    bool? attached,
    int? windows,
    DateTime? created,
  }) {
    return TmuxSession(
      name: name ?? this.name,
      attached: attached ?? this.attached,
      windows: windows ?? this.windows,
      created: created ?? this.created,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'attached': attached,
        'windows': windows,
        'created': created?.toIso8601String(),
      };

  factory TmuxSession.fromJson(Map<String, dynamic> json) => TmuxSession(
        name: json['name'] as String,
        attached: json['attached'] as bool? ?? false,
        windows: json['windows'] as int? ?? 0,
        created: json['created'] != null
            ? DateTime.parse(json['created'] as String)
            : null,
      );

  @override
  List<Object?> get props => [name, attached, windows, created];
}

class TmuxWindow extends Equatable {
  final int id;
  final String name;
  final bool active;
  final int panes;

  const TmuxWindow({
    required this.id,
    required this.name,
    required this.active,
    required this.panes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'active': active,
        'panes': panes,
      };

  factory TmuxWindow.fromJson(Map<String, dynamic> json) => TmuxWindow(
        id: json['id'] as int,
        name: json['name'] as String,
        active: json['active'] as bool? ?? false,
        panes: json['panes'] as int? ?? 1,
      );

  @override
  List<Object?> get props => [id, name, active, panes];
}

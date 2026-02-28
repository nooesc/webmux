import 'package:equatable/equatable.dart';

class DotFile extends Equatable {
  final String path;
  final String name;
  final bool isDirectory;
  final int size;
  final DateTime? modified;
  final String? content;
  final List<DotFileVersion>? versions;

  const DotFile({
    required this.path,
    required this.name,
    required this.isDirectory,
    required this.size,
    this.modified,
    this.content,
    this.versions,
  });

  DotFile copyWith({
    String? path,
    String? name,
    bool? isDirectory,
    int? size,
    DateTime? modified,
    String? content,
    List<DotFileVersion>? versions,
  }) {
    return DotFile(
      path: path ?? this.path,
      name: name ?? this.name,
      isDirectory: isDirectory ?? this.isDirectory,
      size: size ?? this.size,
      modified: modified ?? this.modified,
      content: content ?? this.content,
      versions: versions ?? this.versions,
    );
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'isDirectory': isDirectory,
        'size': size,
        'modified': modified?.toIso8601String(),
        'content': content,
        'versions': versions?.map((v) => v.toJson()).toList(),
      };

  factory DotFile.fromJson(Map<String, dynamic> json) => DotFile(
        path: json['path'] as String,
        name: json['name'] as String,
        isDirectory: json['isDirectory'] as bool? ?? false,
        size: json['size'] as int? ?? 0,
        modified: json['modified'] != null
            ? DateTime.parse(json['modified'] as String)
            : null,
        content: json['content'] as String?,
        versions: json['versions'] != null
            ? (json['versions'] as List)
                .map((v) => DotFileVersion.fromJson(v as Map<String, dynamic>))
                .toList()
            : null,
      );

  @override
  List<Object?> get props => [path, name, isDirectory, size, modified, content, versions];
}

class DotFileVersion extends Equatable {
  final String id;
  final DateTime timestamp;
  final String? commitMessage;

  const DotFileVersion({
    required this.id,
    required this.timestamp,
    this.commitMessage,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'commitMessage': commitMessage,
      };

  factory DotFileVersion.fromJson(Map<String, dynamic> json) => DotFileVersion(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        commitMessage: json['commitMessage'] as String?,
      );

  @override
  List<Object?> get props => [id, timestamp, commitMessage];
}

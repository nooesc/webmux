import 'package:equatable/equatable.dart';

class Host extends Equatable {
  final String id;
  final String name;
  final String address;
  final int port;
  final String? username;
  final bool useTls;
  final DateTime? lastConnected;

  const Host({
    required this.id,
    required this.name,
    required this.address,
    required this.port,
    this.username,
    this.useTls = false,
    this.lastConnected,
  });

  String get wsUrl => useTls ? 'wss://$address:$port' : 'ws://$address:$port';
  String get httpUrl => useTls ? 'https://$address:$port' : 'http://$address:$port';

  Host copyWith({
    String? id,
    String? name,
    String? address,
    int? port,
    String? username,
    bool? useTls,
    DateTime? lastConnected,
  }) {
    return Host(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      port: port ?? this.port,
      username: username ?? this.username,
      useTls: useTls ?? this.useTls,
      lastConnected: lastConnected ?? this.lastConnected,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'port': port,
        'username': username,
        'useTls': useTls,
        'lastConnected': lastConnected?.toIso8601String(),
      };

  factory Host.fromJson(Map<String, dynamic> json) => Host(
        id: json['id'] as String,
        name: json['name'] as String,
        address: json['address'] as String,
        port: json['port'] as int,
        username: json['username'] as String?,
        useTls: json['useTls'] as bool? ?? false,
        lastConnected: json['lastConnected'] != null
            ? DateTime.parse(json['lastConnected'] as String)
            : null,
      );

  @override
  List<Object?> get props => [id, name, address, port, username, useTls, lastConnected];
}

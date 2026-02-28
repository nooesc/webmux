import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../data/services/websocket_service.dart';
import '../../sessions/providers/sessions_provider.dart';

class DebugScreen extends ConsumerStatefulWidget {
  const DebugScreen({super.key});

  @override
  ConsumerState<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends ConsumerState<DebugScreen> {
  final _urlController = TextEditingController(text: AppConfig.wsBaseUrl);
  final List<String> _logs = [];
  bool _isConnected = false;
  StreamSubscription? _logSubscription;
  StreamSubscription? _connectionSubscription;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  void _connect() {
    final service = ref.read(sharedWebSocketServiceProvider);

    _logSubscription = service.logs.listen((log) {
      if (mounted) {
        setState(() {
          _logs.add(log);
          if (_logs.length > 100) {
            _logs.removeAt(0);
          }
        });
      }
    });

    _connectionSubscription = service.connectionState.listen((connected) {
      if (mounted) {
        setState(() {
          _isConnected = connected;
        });
      }
    });

    service.connect(_urlController.text);
  }

  void _reconnect() {
    final service = ref.read(sharedWebSocketServiceProvider);
    service.disconnect();
    service.connect(_urlController.text);
  }

  @override
  void dispose() {
    _logSubscription?.cancel();
    _connectionSubscription?.cancel();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug - WebSocket Connection'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reconnect,
            tooltip: 'Reconnect',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isConnected ? Icons.check_circle : Icons.error,
                      color: _isConnected ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isConnected ? 'Connected' : 'Disconnected',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isConnected ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'WebSocket URL',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.link),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _reconnect,
                      icon: const Icon(Icons.power),
                      label: const Text('Connect'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _logs.clear();
                        });
                      },
                      child: const Text('Clear Logs'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Logs (${_logs.length})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                Color? textColor;
                if (log.contains('error') || log.contains('failed')) {
                  textColor = Colors.red;
                } else if (log.contains('Connected') ||
                    log.contains('success')) {
                  textColor = Colors.green;
                } else if (log.contains('Sending') ||
                    log.contains('Received')) {
                  textColor = Colors.blue;
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    log,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: textColor,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

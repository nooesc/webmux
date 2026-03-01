import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/config/app_config.dart';
import '../models/models.dart';

typedef MessageHandler = void Function(Map<String, dynamic> message);
typedef ConnectionHandler = void Function();

class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  bool _isConnected = false;
  String? _currentUrl;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _logController = StreamController<String>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  Stream<bool> get connectionState => _connectionController.stream;
  Stream<String> get logs => _logController.stream;
  bool get isConnected => _isConnected;
  String? get currentUrl => _currentUrl;

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    _logController.add('[$timestamp] $message');
  }

  Future<void> connect(String url) async {
    _currentUrl = url;
    _log('Connecting to: $url');
    await _doConnect();
  }

  Future<void> _doConnect() async {
    if (_currentUrl == null) return;

    try {
      _log('Attempting WebSocket connection to: $_currentUrl');
      _channel = WebSocketChannel.connect(Uri.parse(_currentUrl!));

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );

      _isConnected = true;
      _log('Connected successfully!');
      _connectionController.add(true);
      _startPingTimer();
    } catch (e) {
      _log('Connection failed: $e');
      _isConnected = false;
      _connectionController.add(false);
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic data) {
    _log('Received: $data');
    try {
      final message = jsonDecode(data as String) as Map<String, dynamic>;
      _messageController.add(message);
    } catch (e) {
      _log('Failed to parse message: $e');
    }
  }

  void _onError(dynamic error) {
    _log('WebSocket error: $error');
    _isConnected = false;
    _connectionController.add(false);
    _scheduleReconnect();
  }

  void _onDone() {
    _log('WebSocket connection closed');
    _isConnected = false;
    _connectionController.add(false);
    _scheduleReconnect();
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      send({'type': 'ping'});
    });
  }

  void _scheduleReconnect() {
    _log('Scheduling reconnect in 5 seconds...');
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _doConnect();
    });
  }

  void forceReconnect() {
    if (_currentUrl == null) return;
    _log('Forcing immediate reconnect...');
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    try {
      _subscription?.cancel();
      _channel?.sink.close();
    } catch (_) {}
    _isConnected = false;
    _connectionController.add(false);
    _doConnect();
  }

  void send(Map<String, dynamic> message) {
    if (_isConnected && _channel != null) {
      _log('Sending: $message');
      _channel!.sink.add(jsonEncode(message));
    } else {
      _log('Cannot send - not connected');
    }
  }

  // Request methods - using Capacitor web app format (type instead of action)
  void requestSessions() {
    send({'type': 'list-sessions'});
  }

  void requestWindows(String sessionName) {
    send({'type': 'list-windows', 'sessionName': sessionName});
  }

  void createSession(String name) {
    send({'type': 'create-session', 'name': name});
  }

  void killSession(String name) {
    send({'type': 'kill-session', 'sessionName': name});
  }

  void attachSession(String name, {int cols = 80, int rows = 24}) {
    send({
      'type': 'attach-session',
      'sessionName': name,
      'cols': cols,
      'rows': rows,
    });
  }

  void createWindow(String sessionName, String windowName) {
    send({
      'type': 'create-window',
      'sessionName': sessionName,
      'name': windowName,
    });
  }

  void killWindow(String sessionName, int windowId) {
    send({
      'type': 'kill-window',
      'sessionName': sessionName,
      'windowIndex': windowId,
    });
  }

  void selectWindow(String sessionName, int windowId) {
    send({
      'type': 'select-window',
      'sessionName': sessionName,
      'windowIndex': windowId,
    });
  }

  void sendTerminalData(String sessionName, String data) {
    send({'type': 'input', 'data': data});
  }

  void resizeTerminal(String sessionName, int cols, int rows) {
    send({'type': 'resize', 'cols': cols, 'rows': rows});
  }

  void requestCronJobs() {
    send({'type': 'list-cron-jobs'});
  }

  void createCronJob(String schedule, String command) {
    send({
      'type': 'create-cron-job',
      'job': {
        'name': 'New Job',
        'schedule': schedule,
        'command': command,
        'enabled': true,
      },
    });
  }

  void deleteCronJob(String id) {
    send({'type': 'delete-cron-job', 'id': id});
  }

  void toggleCronJob(String id, bool enabled) {
    send({'type': 'toggle-cron-job', 'id': id, 'enabled': enabled});
  }

  void requestDotfiles() {
    send({'type': 'list-dotfiles'});
  }

  void requestDotfileContent(String path) {
    send({'type': 'read-dotfile', 'path': path});
  }

  void saveDotfile(String path, String content) {
    send({'type': 'write-dotfile', 'path': path, 'content': content});
  }

  void requestSystemStats() {
    send({'type': 'get-stats'});
  }

  void disconnect() {
    _log('Disconnecting...');
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _isConnected = false;
    _connectionController.add(false);
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _connectionController.close();
    _logController.close();
  }
}

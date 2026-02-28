import '../models/tmux_session.dart';
import '../services/websocket_service.dart';

class SessionRepository {
  final WebSocketService _wsService;

  SessionRepository(this._wsService);

  Future<List<TmuxSession>> getSessions() async {
    _wsService.requestSessions();

    // Wait for response (in real app, use proper async handling)
    await Future.delayed(const Duration(milliseconds: 500));

    return [];
  }

  Future<List<TmuxWindow>> getWindows(String sessionName) async {
    _wsService.requestWindows(sessionName);
    await Future.delayed(const Duration(milliseconds: 500));
    return [];
  }

  Future<void> createSession(String name) async {
    _wsService.createSession(name);
  }

  Future<void> killSession(String name) async {
    _wsService.killSession(name);
  }

  Future<void> renameSession(String oldName, String newName) async {
    _wsService.send({
      'action': 'rename_session',
      'old_name': oldName,
      'name': newName,
    });
  }

  Future<void> createWindow(String sessionName, String windowName) async {
    _wsService.createWindow(sessionName, windowName);
  }

  Future<void> killWindow(String sessionName, int windowId) async {
    _wsService.killWindow(sessionName, windowId);
  }

  Future<void> renameWindow(String sessionName, int windowId, String newName) async {
    _wsService.send({
      'action': 'rename_window',
      'session': sessionName,
      'window': windowId,
      'name': newName,
    });
  }

  Future<void> selectWindow(String sessionName, int windowId) async {
    _wsService.selectWindow(sessionName, windowId);
  }

  void attachSession(String name) {
    _wsService.attachSession(name);
  }
}

import '../models/dotfile.dart';
import '../services/websocket_service.dart';

class DotfilesRepository {
  final WebSocketService _wsService;

  DotfilesRepository(this._wsService);

  Future<List<DotFile>> getDotfiles() async {
    _wsService.requestDotfiles();
    await Future.delayed(const Duration(milliseconds: 500));
    return [];
  }

  Future<String?> getDotfileContent(String path) async {
    _wsService.requestDotfileContent(path);
    await Future.delayed(const Duration(milliseconds: 500));
    return null;
  }

  Future<void> saveDotfile(String path, String content) async {
    _wsService.saveDotfile(path, content);
  }

  Future<List<DotFileVersion>> getVersions(String path) async {
    _wsService.send({
      'action': 'get_dotfile_versions',
      'path': path,
    });
    await Future.delayed(const Duration(milliseconds: 500));
    return [];
  }

  Future<void> restoreVersion(String path, String versionId) async {
    _wsService.send({
      'action': 'restore_dotfile_version',
      'path': path,
      'version': versionId,
    });
  }
}

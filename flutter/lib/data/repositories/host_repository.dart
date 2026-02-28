import 'package:hive/hive.dart';
import '../models/host.dart';

class HostRepository {
  static const String _boxName = 'hosts';
  Box<Host>? _box;

  Future<void> init() async {
    _box = await Hive.openBox<Host>(_boxName);
  }

  List<Host> getAll() {
    return _box?.values.toList() ?? [];
  }

  Host? getById(String id) {
    return _box?.get(id);
  }

  Future<void> save(Host host) async {
    await _box?.put(host.id, host);
  }

  Future<void> delete(String id) async {
    await _box?.delete(id);
  }

  Future<void> updateLastConnected(String id) async {
    final host = _box?.get(id);
    if (host != null) {
      await _box?.put(id, host.copyWith(lastConnected: DateTime.now()));
    }
  }

  Host? getSelected() {
    final hosts = getAll();
    if (hosts.isEmpty) return null;
    // Return the most recently connected or first in list
    hosts.sort((a, b) {
      if (a.lastConnected == null && b.lastConnected == null) return 0;
      if (a.lastConnected == null) return 1;
      if (b.lastConnected == null) return -1;
      return b.lastConnected!.compareTo(a.lastConnected!);
    });
    return hosts.first;
  }

  Future<void> close() async {
    await _box?.close();
  }
}

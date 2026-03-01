import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../sessions/screens/sessions_screen.dart';
import '../../cron/screens/cron_screen.dart';
import '../../dotfiles/screens/dotfiles_screen.dart';
import '../../system/screens/system_screen.dart';
import '../../debug/screens/debug_screen.dart';
import '../../terminal/screens/terminal_screen.dart';
import '../../auth/providers/auth_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final bool showDebug;

  const HomeScreen({super.key, this.showDebug = false});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = [];
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _screens.addAll([
      const SessionsScreen(),
      // Chat is now accessed via session selection
      const CronScreen(),
      const DotfilesScreen(),
      const SystemScreen(),
    ]);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreState();
    });
  }

  Future<void> _restoreState() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final savedIndex = prefs.getInt('home_index');
    final activeSession = prefs.getString('active_terminal_session');

    if (mounted) {
      setState(() {
        if (savedIndex != null && savedIndex < _screens.length) {
          _currentIndex = savedIndex;
        }
        _initialized = true;
      });

      // If there was an active terminal session, restore it
      if (activeSession != null) {
        // Wait a bit for the UI to settle
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TerminalScreen(sessionName: activeSession),
              ),
            );
          }
        });
      }
    }
  }

  Future<void> _saveIndex(int index) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt('home_index', index);
  }

  void _openDebugScreen() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const DebugScreen()));
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
          _saveIndex(index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.terminal_outlined),
            selectedIcon: Icon(Icons.terminal),
            label: 'Sessions',
          ),
          NavigationDestination(
            icon: Icon(Icons.schedule_outlined),
            selectedIcon: Icon(Icons.schedule),
            label: 'Cron',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Dotfiles',
          ),
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon: Icon(Icons.monitor_heart),
            label: 'System',
          ),
        ],
      ),
      floatingActionButton: widget.showDebug
          ? FloatingActionButton(
              onPressed: _openDebugScreen,
              child: const Icon(Icons.bug_report),
            )
          : null,
    );
  }
}

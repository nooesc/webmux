import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../sessions/screens/sessions_screen.dart';
import '../../chat/screens/chat_screen.dart';
import '../../cron/screens/cron_screen.dart';
import '../../dotfiles/screens/dotfiles_screen.dart';
import '../../system/screens/system_screen.dart';
import '../../debug/screens/debug_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final String host;
  final bool showDebug;

  const HomeScreen({super.key, required this.host, this.showDebug = false});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [];

  @override
  void initState() {
    super.initState();
    _screens.addAll([
      SessionsScreen(host: widget.host),
      const ChatScreen(),
      const CronScreen(),
      const DotfilesScreen(),
      const SystemScreen(),
    ]);
  }

  void _openDebugScreen() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const DebugScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.terminal_outlined),
            selectedIcon: Icon(Icons.terminal),
            label: 'Sessions',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
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

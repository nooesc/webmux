import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/tmux_session.dart';
import '../providers/sessions_provider.dart';
import '../../terminal/screens/terminal_screen.dart';

class SessionsScreen extends ConsumerWidget {
  final String host;

  const SessionsScreen({super.key, required this.host});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsState = ref.watch(sessionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sessions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(sessionsProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: sessionsState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : sessionsState.sessions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.terminal,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No sessions',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.grey[400],
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create a new session to get started',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[500],
                            ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: sessionsState.sessions.length,
                  itemBuilder: (context, index) {
                    final session = sessionsState.sessions[index];
                    return _SessionTile(
                      session: session,
                      host: host,
                      onAttach: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TerminalScreen(
                              host: host,
                              sessionName: session.name,
                            ),
                          ),
                        );
                      },
                      onKill: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Kill Session'),
                            content: Text(
                              'Are you sure you want to kill "${session.name}"?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('Kill'),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true) {
                          ref
                              .read(sessionsProvider.notifier)
                              .killSession(session.name);
                        }
                      },
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateSessionDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCreateSessionDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Session'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Session Name',
            hintText: 'Enter session name',
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              ref.read(sessionsProvider.notifier).createSession(value);
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref
                    .read(sessionsProvider.notifier)
                    .createSession(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final TmuxSession session;
  final String host;
  final VoidCallback onAttach;
  final VoidCallback onKill;

  const _SessionTile({
    required this.session,
    required this.host,
    required this.onAttach,
    required this.onKill,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Icon(
          Icons.terminal,
          color: session.attached ? Colors.green : Colors.grey,
        ),
        title: Text(session.name),
        subtitle: Text(
          '${session.windows} window${session.windows != 1 ? 's' : ''}',
          style: TextStyle(color: Colors.grey[500]),
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'attach',
              child: ListTile(
                leading: Icon(Icons.open_in_new),
                title: Text('Attach'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'kill',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Kill', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'attach') {
              onAttach();
            } else if (value == 'kill') {
              onKill();
            }
          },
        ),
        onTap: onAttach,
      ),
    );
  }
}

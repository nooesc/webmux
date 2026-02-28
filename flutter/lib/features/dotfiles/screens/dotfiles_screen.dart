import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/dotfile.dart';
import '../providers/dotfiles_provider.dart';

class DotfilesScreen extends ConsumerWidget {
  const DotfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dotfilesState = ref.watch(dotfilesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dotfiles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(dotfilesProvider.notifier).refresh(),
          ),
        ],
      ),
      body: dotfilesState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : dotfilesState.files.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No dotfiles found',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.grey[400],
                            ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: dotfilesState.files.length,
                  itemBuilder: (context, index) {
                    final file = dotfilesState.files[index];
                    return _DotfileTile(
                      file: file,
                      onTap: () {
                        ref.read(dotfilesProvider.notifier).selectFile(file);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DotfileEditorScreen(),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}

class _DotfileTile extends StatelessWidget {
  final DotFile file;
  final VoidCallback onTap;

  const _DotfileTile({
    required this.file,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        file.isDirectory ? Icons.folder : Icons.insert_drive_file,
        color: file.isDirectory ? Colors.amber : Colors.grey,
      ),
      title: Text(file.name),
      subtitle: Text(
        file.path,
        style: TextStyle(color: Colors.grey[500], fontSize: 12),
      ),
      trailing: file.isDirectory
          ? const Icon(Icons.chevron_right)
          : Text(
              _formatSize(file.size),
              style: TextStyle(color: Colors.grey[500]),
            ),
      onTap: file.isDirectory ? null : onTap,
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class DotfileEditorScreen extends ConsumerStatefulWidget {
  const DotfileEditorScreen({super.key});

  @override
  ConsumerState<DotfileEditorScreen> createState() => _DotfileEditorScreenState();
}

class _DotfileEditorScreenState extends ConsumerState<DotfileEditorScreen> {
  late TextEditingController _controller;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotfilesState = ref.watch(dotfilesProvider);
    final selectedFile = dotfilesState.selectedFile;

    // Update controller when content loads
    if (dotfilesState.fileContent != null && _controller.text.isEmpty) {
      _controller.text = dotfilesState.fileContent!;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(selectedFile?.name ?? 'Editor'),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: () {
                if (selectedFile != null) {
                  ref.read(dotfilesProvider.notifier).saveFile(
                        selectedFile.path,
                        _controller.text,
                      );
                  setState(() => _hasChanges = false);
                }
              },
              child: const Text('Save'),
            ),
        ],
      ),
      body: dotfilesState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TextField(
              controller: _controller,
              maxLines: null,
              expands: true,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
              ),
              onChanged: (_) {
                if (!_hasChanges) {
                  setState(() => _hasChanges = true);
                }
              },
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/dotfile.dart';
import '../providers/dotfiles_provider.dart';
import 'dotfile_editor_screen.dart';
import 'dotfiles_templates_screen.dart';

class DotfilesScreen extends ConsumerStatefulWidget {
  const DotfilesScreen({super.key});

  @override
  ConsumerState<DotfilesScreen> createState() => _DotfilesScreenState();
}

class _DotfilesScreenState extends ConsumerState<DotfilesScreen> {
  final Map<DotFileType, bool> _expandedSections = {
    DotFileType.shell: true,
    DotFileType.git: true,
    DotFileType.vim: true,
    DotFileType.tmux: true,
    DotFileType.ssh: true,
    DotFileType.other: true,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dotfilesProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dotfilesState = ref.watch(dotfilesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final groupedFiles = _groupFilesByType(dotfilesState.files);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text(
          'Dotfiles',
          style: TextStyle(
            color: isDark ? Colors.grey[100] : const Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
            onPressed: () => ref.read(dotfilesProvider.notifier).refresh(),
          ),
          IconButton(
            icon: Icon(
              Icons.bookmark_outline,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DotfilesTemplatesScreen(),
                ),
              );
            },
            tooltip: 'Templates',
          ),
        ],
      ),
      body: dotfilesState.isLoading && dotfilesState.files.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : groupedFiles.isEmpty
          ? _buildEmptyState(isDark)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: groupedFiles.length,
              itemBuilder: (context, index) {
                final entry = groupedFiles.entries.elementAt(index);
                return _buildSection(entry.key, entry.value, isDark);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showBrowsePathDialog(context, isDark),
        backgroundColor: const Color(0xFF6366F1),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Map<DotFileType, List<DotFile>> _groupFilesByType(List<DotFile> files) {
    final Map<DotFileType, List<DotFile>> grouped = {};
    for (final file in files) {
      grouped.putIfAbsent(file.fileType, () => []).add(file);
    }
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        final order = [
          DotFileType.shell,
          DotFileType.git,
          DotFileType.vim,
          DotFileType.tmux,
          DotFileType.ssh,
          DotFileType.other,
        ];
        return order.indexOf(a).compareTo(order.indexOf(b));
      });
    return {for (var key in sortedKeys) key: grouped[key]!};
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 64,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No dotfiles found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to browse a custom path',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[500] : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(DotFileType type, List<DotFile> files, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _expandedSections[type] = !(_expandedSections[type] ?? true);
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.withValues(alpha: 0.05),
            child: Row(
              children: [
                Text(type.icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  type.displayName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[200] : Colors.grey[800],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${files.length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  _expandedSections[type] ?? true
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ],
            ),
          ),
        ),
        if (_expandedSections[type] ?? true)
          ...files.map((file) => _DotfileTile(file: file, isDark: isDark)),
      ],
    );
  }

  void _showBrowsePathDialog(BuildContext context, bool isDark) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text(
          'Browse File',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        content: TextField(
          controller: controller,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: 'Enter file path (e.g., ~/.bashrc)',
            hintStyle: TextStyle(
              color: isDark ? Colors.grey[500] : Colors.grey[400],
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
              ),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF6366F1)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Navigator.pop(context);
                ref.read(dotfilesProvider.notifier).browseFile(controller.text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
            ),
            child: const Text('Open', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _DotfileTile extends ConsumerWidget {
  final DotFile file;
  final bool isDark;

  const _DotfileTile({required this.file, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () {
        ref.read(dotfilesProvider.notifier).selectFile(file);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DotfileEditorScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        margin: const EdgeInsets.only(left: 24),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.withValues(alpha: 0.1),
            ),
          ),
        ),
        child: Row(
          children: [
            _buildFileIcon(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          file.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.grey[100] : Colors.grey[800],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!file.exists) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ],
                      if (!file.writable && file.exists) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.lock_outline,
                          size: 14,
                          color: isDark ? Colors.grey[500] : Colors.grey[400],
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    file.path,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatSize(file.size),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[500],
                  ),
                ),
                if (file.modified != null)
                  Text(
                    _formatDate(file.modified!),
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.grey[600] : Colors.grey[400],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileIcon() {
    if (!file.exists) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.add, color: Colors.orange, size: 20),
      );
    }

    final color = _getTypeColor(file.fileType);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.description_outlined, color: color, size: 20),
    );
  }

  Color _getTypeColor(DotFileType type) {
    switch (type) {
      case DotFileType.shell:
        return Colors.green;
      case DotFileType.git:
        return Colors.orange;
      case DotFileType.vim:
        return Colors.green.shade700;
      case DotFileType.tmux:
        return Colors.blue;
      case DotFileType.ssh:
        return Colors.purple;
      case DotFileType.other:
        return Colors.grey;
    }
  }

  String _formatSize(int bytes) {
    if (bytes == 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    }
    return DateFormat('MMM d').format(date);
  }
}

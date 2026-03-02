import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/dotfile.dart';
import '../providers/dotfiles_provider.dart';

class DotfileEditorScreen extends ConsumerStatefulWidget {
  const DotfileEditorScreen({super.key});

  @override
  ConsumerState<DotfileEditorScreen> createState() =>
      _DotfileEditorScreenState();
}

class _DotfileEditorScreenState extends ConsumerState<DotfileEditorScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _hasChanges = false;
  String _originalContent = '';

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleKeyPress);
  }

  void _handleKeyPress() {
    if (_focusNode.hasFocus) {
      _handleKeyboardShortcuts();
    }
  }

  void _handleKeyboardShortcuts() {
    // Handle Ctrl+S / Cmd+S for save
    // This is a simplified approach - in production you'd use a proper keyboard listener
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotfilesState = ref.watch(dotfilesProvider);
    final selectedFile = dotfilesState.selectedFile;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (dotfilesState.fileContent != null && _originalContent.isEmpty) {
      _originalContent = dotfilesState.fileContent!;
      _controller.text = dotfilesState.fileContent!;
      // Allow editing - backend will handle permission errors on save
    }

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _hasChanges) {
          _showUnsavedChangesDialog(context, isDark);
        }
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyS, control: true):
              _saveFile,
          const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _saveFile,
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: isDark
                ? const Color(0xFF0F172A)
                : const Color(0xFFF8FAFC),
            appBar: AppBar(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                onPressed: () {
                  if (_hasChanges) {
                    _showUnsavedChangesDialog(context, isDark);
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedFile?.name ?? 'Editor',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  if (selectedFile != null)
                    Text(
                      selectedFile!.path,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : Colors.grey[500],
                      ),
                    ),
                ],
              ),
              actions: [
                if (_hasChanges)
                  TextButton.icon(
                    onPressed: _saveFile,
                    icon: const Icon(Icons.save, size: 18),
                    label: const Text('Save'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF6366F1),
                    ),
                  ),
                IconButton(
                  icon: Icon(
                    Icons.history,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                  onPressed: () {
                    if (selectedFile != null) {
                      ref
                          .read(dotfilesProvider.notifier)
                          .loadHistory(selectedFile.path);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              DotfileHistoryScreen(file: selectedFile!),
                        ),
                      );
                    }
                  },
                  tooltip: 'History',
                ),
                IconButton(
                  icon: Icon(
                    Icons.copy,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _controller.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copied to clipboard'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  tooltip: 'Copy',
                ),
              ],
            ),
            body: dotfilesState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Expanded(
                        child: Container(
                          color: isDark
                              ? const Color(0xFF1E1E1E)
                              : Colors.white,
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLineNumbers(isDark),
                                Expanded(child: _buildEditor(isDark)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      _buildStatusBar(isDark),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildLineNumbers(bool isDark) {
    final lines = _controller.text.split('\n').length;
    return Container(
      width: 50,
      padding: const EdgeInsets.only(top: 12, right: 8),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: List.generate(lines, (index) {
          return SizedBox(
            height: 20,
            child: Text(
              '${index + 1}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
                height: 1.4,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEditor(bool isDark) {
    final lineCount = _controller.text.split('\n').length;
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      maxLines: lineCount > 50 ? lineCount : null,
      decoration: const InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.all(12),
      ),
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 14,
        color: isDark ? Colors.grey[200] : Colors.grey[800],
        height: 1.4,
      ),
      onChanged: (value) {
        if (value != _originalContent && !_hasChanges) {
          setState(() => _hasChanges = true);
        }
        setState(() {}); // Update line numbers
      },
    );
  }

  Widget _buildStatusBar(bool isDark) {
    final lines = _controller.text.split('\n').length;
    final chars = _controller.text.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
      child: Row(
        children: [
          Text(
            'Lines: $lines',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Characters: $chars',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const Spacer(),
          if (_hasChanges)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Modified',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _saveFile() {
    if (!_hasChanges) return;

    final selectedFile = ref.read(dotfilesProvider).selectedFile;
    if (selectedFile != null) {
      ref
          .read(dotfilesProvider.notifier)
          .saveFile(selectedFile.path, _controller.text);
      setState(() {
        _hasChanges = false;
        _originalContent = _controller.text;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File saved successfully'),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showUnsavedChangesDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text(
          'Unsaved Changes',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        content: Text(
          'You have unsaved changes. Do you want to save before leaving?',
          style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(this.context);
            },
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _saveFile();
              Navigator.pop(this.context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
            ),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class DotfileHistoryScreen extends ConsumerWidget {
  final DotFile file;

  const DotfileHistoryScreen({super.key, required this.file});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final versions = ref.watch(dotfilesProvider).versions;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text(
          'Version History',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
      ),
      body: versions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 64,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No version history',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: versions.length,
              itemBuilder: (context, index) {
                final version = versions[index];
                return Card(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(
                      _formatDate(version.timestamp),
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      version.id,
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.restore, size: 20),
                          onPressed: () {
                            ref
                                .read(dotfilesProvider.notifier)
                                .restoreVersion(file.path, version.timestamp);
                            Navigator.pop(context);
                          },
                          tooltip: 'Restore',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

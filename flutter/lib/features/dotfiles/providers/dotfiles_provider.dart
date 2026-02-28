import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/dotfile.dart';
import '../../../data/services/websocket_service.dart';

class DotfilesState {
  final List<DotFile> files;
  final DotFile? selectedFile;
  final String? fileContent;
  final bool isLoading;
  final String? error;

  const DotfilesState({
    this.files = const [],
    this.selectedFile,
    this.fileContent,
    this.isLoading = false,
    this.error,
  });

  DotfilesState copyWith({
    List<DotFile>? files,
    DotFile? selectedFile,
    String? fileContent,
    bool? isLoading,
    String? error,
  }) {
    return DotfilesState(
      files: files ?? this.files,
      selectedFile: selectedFile ?? this.selectedFile,
      fileContent: fileContent ?? this.fileContent,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class DotfilesNotifier extends StateNotifier<DotfilesState> {
  final WebSocketService _wsService;

  DotfilesNotifier(this._wsService) : super(const DotfilesState()) {
    _init();
  }

  void _init() {
    _wsService.messages.listen((message) {
      if (message['type'] == 'dotfiles_list') {
        final files = (message['files'] as List?)
                ?.map((f) => DotFile.fromJson(f as Map<String, dynamic>))
                .toList() ??
            [];
        state = state.copyWith(files: files, isLoading: false);
      } else if (message['type'] == 'dotfile_content') {
        state = state.copyWith(
          fileContent: message['content'] as String?,
          isLoading: false,
        );
      }
    });
  }

  void refresh() {
    state = state.copyWith(isLoading: true);
    _wsService.requestDotfiles();
  }

  void selectFile(DotFile file) {
    state = state.copyWith(selectedFile: file, isLoading: true);
    _wsService.requestDotfileContent(file.path);
  }

  Future<void> saveFile(String path, String content) async {
    state = state.copyWith(isLoading: true);
    _wsService.saveDotfile(path, content);
    await Future.delayed(const Duration(milliseconds: 500));
    refresh();
  }

  void clearSelection() {
    state = DotfilesState(
      files: state.files,
      isLoading: state.isLoading,
    );
  }
}

final dotfilesProvider = StateNotifierProvider<DotfilesNotifier, DotfilesState>((ref) {
  final wsService = WebSocketService();
  return DotfilesNotifier(wsService);
});

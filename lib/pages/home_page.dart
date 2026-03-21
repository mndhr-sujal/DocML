import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:split_view/split_view.dart';

import '../widgets/left_sidebar.dart';
import '../widgets/center_panel.dart';
import '../widgets/right_chat.dart';

class HomePage extends StatefulWidget {
  final ValueNotifier<ThemeMode> themeMode;
  const HomePage({super.key, required this.themeMode});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Map<String, dynamic>> _recentFiles = [];

  bool _hasSelectedFile = false;
  String? _selectedFileName;
  String? _selectedFileExtension;
  String? _selectedFilePath;

  static const List<String> _supportedExtensions = [
    'bmp',
    'docx',
    'epub',
    'htm',
    'html',
    'jpeg',
    'jpg',
    'markdown',
    'md',
    'odt',
    'pdf',
    'png',
    'txt',
  ];
  late final SplitViewController _splitViewController;

  @override
  void initState() {
    super.initState();
    _splitViewController = SplitViewController(
      weights: [0.17, 0.58, 0.25],
      limits: [
        WeightLimit(min: 0.14), // left sidebar
        WeightLimit(min: 0.36), // center panel
        WeightLimit(min: 0.25), // right chat
      ],
    );
    _loadRecentFiles();
  }

  @override
  void dispose() {
    _splitViewController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentFiles() async {
    try {
      final directory = await getApplicationSupportDirectory();
      final file = File('${directory.path}/recent_files.json');
      if (await file.exists()) {
        final contents = await file.readAsString();
        final List<dynamic> decoded = jsonDecode(contents);
        setState(() {
          _recentFiles.clear();
          for (final item in decoded) {
            if (item is Map) {
              _recentFiles.add(Map<String, dynamic>.from(item));
            }
          }
          // max length of recent files is 10
          if (_recentFiles.length > 10) {
            _recentFiles.removeRange(10, _recentFiles.length);
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to load recent files: $e');
    }
  }

  Future<void> _saveRecentFiles() async {
    try {
      final directory = await getApplicationSupportDirectory();
      final file = File('${directory.path}/recent_files.json');
      await file.writeAsString(jsonEncode(_recentFiles));
    } catch (e) {
      debugPrint('Failed to save recent files: $e');
    }
  }

  void _updateSelectedFile(String name, String? ext, String path) {
    setState(() {
      _recentFiles.removeWhere(
        (element) => element['path'] == path,
      ); // remove duplicate recent files
      _recentFiles.insert(0, {'name': name, 'extension': ext, 'path': path});
      _selectedFileName = name;
      _selectedFileExtension = ext;
      _selectedFilePath = path;
      _hasSelectedFile = true;
      if (_recentFiles.length > 10) {
        _recentFiles.removeRange(10, _recentFiles.length);
      } // max length of recent files is 10
    });
    _saveRecentFiles();
  }

  void _removeRecentFile(String path) {
    setState(() {
      _recentFiles.removeWhere((element) => element['path'] == path);
    });
    _saveRecentFiles();
  }

  void _clearAllRecentFiles() {
    setState(() {
      _recentFiles.clear();
    });
    _saveRecentFiles();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _supportedExtensions,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      _updateSelectedFile(file.name, file.extension, file.path!);
    }
  }

  Future<void> _handleDroppedFile(File file) async {
    final fileName = file.path.split(Platform.pathSeparator).last;
    final extension = fileName.split('.').last.toLowerCase();

    if (!_supportedExtensions.contains(extension)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Selected file type is not supported."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _updateSelectedFile(fileName, extension, file.path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SplitView(
        viewMode: SplitViewMode.Horizontal,
        gripSize: 3,
        gripColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey.shade900
            : Colors.grey.shade200,
        gripColorActive: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey.shade700
            : Colors.grey.shade400,
        controller: _splitViewController,
        children: [
          LeftSidebar(
            recentFiles: _recentFiles,
            onRemoveRecentFile: _removeRecentFile,
            onClearRecentFiles: _clearAllRecentFiles,
            themeMode: widget.themeMode,
          ),
          CenterPanel(
            onPickFile: _pickFile,
            onDropFile: _handleDroppedFile,
            hasSelectedFile: _hasSelectedFile,
            selectedFileName: _selectedFileName,
            selectedFilePath: _selectedFilePath,
            selectedFileExtension: _selectedFileExtension,
            onClearFile: _clearSelectedFile,
          ),
          const RightChat(),
        ],
      ),
    );
  }

  void _clearSelectedFile() {
    setState(() {
      _hasSelectedFile = false;
      _selectedFileName = null;
      _selectedFileExtension = null;
      _selectedFilePath = null;
    });
    _saveRecentFiles();
  }
}

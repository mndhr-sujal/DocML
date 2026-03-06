import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../widgets/left_sidebar.dart';
import '../widgets/center_panel.dart';
import '../widgets/right_chat.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Map<String, dynamic>> recentFiles = [];

  bool hasSelectedFile =false;
  String? selectedFileName;
  String? selectedFileExtension;
  String? selectedFilePath;

  @override
  void initState() {
    super.initState();
    _loadRecentFiles();
  }

  Future<void> _loadRecentFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/recent_files.json');
      if (await file.exists()) {
        final contents = await file.readAsString();
        final List<dynamic> decoded = jsonDecode(contents);
        setState(() {
          recentFiles.clear();
          for (final item in decoded) {
            if (item is Map) {
              recentFiles.add(Map<String, dynamic>.from(item));
            }
          }
          // Keep only the most recent 10 entries
          if (recentFiles.length > 10) {
            recentFiles.removeRange(10, recentFiles.length);
          }
        });
      }
    } catch (e) {
      print('Failed to load recent files: $e');
    }
  }

  Future<void> _saveRecentFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/recent_files.json');
      await file.writeAsString(jsonEncode(recentFiles));
    } catch (e) {
      print('Failed to save recent files: $e');
    }
  }


  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpeg','jpg','png','pdf']
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;

      setState(() {
        recentFiles.insert(0, {
          'name': file.name,
          'extension': file.extension,
          'path': file.path,
        });
        selectedFileName = file.name;
        selectedFileExtension = file.extension;
        selectedFilePath = file.path;
        hasSelectedFile = true;
        // Trim to 10 most recent entries
        if (recentFiles.length > 10) {
          recentFiles.removeRange(10, recentFiles.length);
        }
      });
      await _saveRecentFiles();
    }
  }

  Future<void> handleDroppedFile(File file) async {
    final fileName = file.path.split(Platform.pathSeparator).last;
    final extension = fileName.split('.').last.toLowerCase();

     if (!['png', 'jpg', 'jpeg', 'pdf'].contains(extension)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Only image and PDF files are allowed."),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

    setState(() {
      recentFiles.insert(0, {
        'name': fileName,
        'extension': extension,
        'path': file.path,
      });
      selectedFileName = fileName;
      selectedFileExtension = extension;
      selectedFilePath = file.path;
      hasSelectedFile = true;
      // Trim to 10 most recent entries
      if (recentFiles.length > 10) {
        recentFiles.removeRange(10, recentFiles.length);
      }
    });
    await _saveRecentFiles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          LeftSidebar(
            recentFiles: recentFiles,
          ),
          Expanded(
            child: CenterPanel(
              onPickFile: pickFile,
              onDropFile: handleDroppedFile,
              hasSelectedFile: hasSelectedFile,
              selectedFileName: selectedFileName,
              selectedFilePath: selectedFilePath,
              selectedFileExtension: selectedFileExtension,
              onClearFile: clearSelectedFile,
            ),
          ),
          const RightChat(),
        ],
      ),
    );
  }

  void clearSelectedFile() {
  setState(() {
    hasSelectedFile = false;
    selectedFileName = null;
    selectedFileExtension = null;
    selectedFilePath = null;
  });
  _saveRecentFiles();
}

}

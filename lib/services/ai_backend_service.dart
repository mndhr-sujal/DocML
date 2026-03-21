import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class AiBackendService {
  static final AiBackendService _instance = AiBackendService._internal();
  factory AiBackendService() => _instance;
  AiBackendService._internal();

  final String _apiUrl = 'http://localhost:8000';
  Process? _pythonProcess;

  Future<bool> isHealthy() async {
    try {
      final response = await http
          .get(Uri.parse('$_apiUrl/health'))
          .timeout(const Duration(seconds: 1));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  String _getPythonPath() {
    if (Platform.isWindows) {
      return 'python';
    } else {
      return 'python3';
    }
  }

  Future<bool> ensureRunning({Function(String)? onStatusUpdate}) async {
    if (await isHealthy()) return true;

    onStatusUpdate?.call(
      'Starting local AI models... \nThis may take a minute.',
    );

    try {
      final pythonPath = _getPythonPath();
      _pythonProcess = await Process.start(pythonPath, ['lib/chatbot.py']);

      // Prevent full buffer
      _pythonProcess!.stdout.drain();
      _pythonProcess!.stderr.drain();

      for (int i = 0; i < 90; i++) {
        await Future.delayed(const Duration(seconds: 1));
        if (await isHealthy()) {
          onStatusUpdate?.call('AI Models loaded!');
          return true;
        }
      }
      return false;
    } catch (e) {
      onStatusUpdate?.call('Failed to start AI backend: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> sendMessage(String query) async {
    final response = await http.post(
      Uri.parse('$_apiUrl/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'query': query, 'session_id': 'default'}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get response from AI: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> uploadFile(File file, String fileName) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$_apiUrl/ingest-file'),
    );

    request.files.add(
      await http.MultipartFile.fromPath('file', file.path, filename: fileName),
    );

    request.fields['title'] = fileName;
    request.fields['doc_id'] = DateTime.now().millisecondsSinceEpoch.toString();

    var response = await request.send();
    if (response.statusCode == 200) {
      final responseData = await response.stream.bytesToString();
      return jsonDecode(responseData);
    } else {
      final errorBody = await response.stream.bytesToString();
      throw Exception('Upload failed: ${response.statusCode}\n$errorBody');
    }
  }

  Future<void> clearDatabase() async {
    if (!await isHealthy()) return;
    try {
      final response = await http.post(Uri.parse('$_apiUrl/clear'));
      if (response.statusCode != 200) {
        throw Exception('Failed to clear database: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error clearing database: $e');
    }
  }

  Future<Process> downloadModels() async {
    final pythonPath = _getPythonPath();
    return Process.start(pythonPath, ['lib/download_models.py']);
  }

  Future<ProcessResult?> runPythonScript(String script, List<String> args) async {
    try {
      final pythonPath = _getPythonPath();
      return await Process.run(pythonPath, [script, ...args]);
    } catch (e) {
      return null;
    }
  }

  void dispose() {
    _pythonProcess?.kill();
    _pythonProcess = null;
  }
}

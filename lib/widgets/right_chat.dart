import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../message/chat_message.dart';
import '../services/ai_backend_service.dart';

class RightChat extends StatefulWidget {
  const RightChat({super.key});

  @override
  State<RightChat> createState() => _RightChatState();
}

class _RightChatState extends State<RightChat> {
  final List<ChatMessage> _messages = [
    ChatMessage(
      sender: MessageSender.ai,
      text: 'Hello! Upload a document or ask me a question.',
    ),
  ];
  final TextEditingController _controller = TextEditingController();
  final AiBackendService _backend = AiBackendService();
  bool _processing = false;
  bool _startingModels = false;
  bool _isDownloading = false;
  Process? _downloadProcess;

  @override
  void dispose() {
    _downloadProcess?.kill();
    _backend.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _addMsg(MessageSender s, String t, [List<String> sources = const []]) =>
      setState(
        () => _messages.add(ChatMessage(sender: s, text: t, sources: sources)),
      );

  Future<void> _handleUpload() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'txt', 'html', 'md'],
    );
    if (res?.files.single.path == null) return;
    final file = File(res!.files.single.path!), name = res.files.single.name;

    setState(() {
      _addMsg(MessageSender.user, 'Uploading: $name');
      _startingModels = true;
    });

    final isRunning = await _backend.ensureRunning(
      onStatusUpdate: (m) => _addMsg(MessageSender.ai, m),
    );
    setState(() {
      _startingModels = false;
    });

    if (!isRunning) {
      _addMsg(MessageSender.ai, 'Backend connection failed.');
    } else {
      setState(() {
        _processing = true;
      });
      try {
        final data = await _backend.uploadFile(file, name);
        final chunks = data['chunks_ingested'] ?? 0;
        if (chunks == 0) {
          _addMsg(
            MessageSender.ai,
            'No text could be extracted from "$name".',
            [name],
          );
        } else {
          _addMsg(MessageSender.ai, 'Ingested "$name" ($chunks chunks).', [
            name,
          ]);
        }
      } catch (e) {
        _addMsg(MessageSender.ai, 'Upload error: $e');
      }
    }
    setState(() => _processing = false);
  }

  Future<void> _handleDroppedFile(String path, String name) async {
    final file = File(path);
    if (!await file.exists()) {
      _addMsg(MessageSender.ai, 'File not found: $name');
      return;
    }

    setState(() {
      _addMsg(MessageSender.user, 'Uploading: $name');
      _startingModels = true;
    });

    final isRunning = await _backend.ensureRunning(
      onStatusUpdate: (m) => _addMsg(MessageSender.ai, m),
    );
    setState(() {
      _startingModels = false;
    });

    if (!isRunning) {
      _addMsg(MessageSender.ai, 'Backend connection failed.');
    } else {
      setState(() {
        _processing = true;
      });
      try {
        final data = await _backend.uploadFile(file, name);
        final chunks = data['chunks_ingested'] ?? 0;
        if (chunks == 0) {
          _addMsg(
            MessageSender.ai,
            'No text could be extracted from "$name".',
            [name],
          );
        } else {
          _addMsg(MessageSender.ai, 'Ingested "$name" ($chunks chunks).', [
            name,
          ]);
        }
      } catch (e) {
        _addMsg(MessageSender.ai, 'Upload error: $e');
      }
    }
    setState(() => _processing = false);
  }

  Future<void> _handleChat(String text) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _addMsg(MessageSender.user, text);
      _startingModels = true;
    });
    _controller.clear();

    final isRunning = await _backend.ensureRunning(
      onStatusUpdate: (m) => _addMsg(MessageSender.ai, m),
    );
    setState(() {
      _startingModels = false;
    });

    if (isRunning) {
      setState(() {
        _processing = true;
      });
      try {
        final data = await _backend.sendMessage(text);
        _addMsg(
          MessageSender.ai,
          data['answer'],
          List<String>.from(data['sources'] ?? []),
        );
      } catch (e) {
        _addMsg(MessageSender.ai, 'Connection failed: $e');
      }
    }
    setState(() => _processing = false);
  }

  Future<void> _handleDownload() async {
    if (_isDownloading) {
      _downloadProcess?.kill();
      setState(() {
        _isDownloading = false;
        _downloadProcess = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Download cancelled.')));
      return;
    }

    setState(() => _isDownloading = true);
    try {
      _downloadProcess = await _backend.downloadModels();
      final exitCode = await _downloadProcess!.exitCode;

      if (mounted && _isDownloading) {
        if (exitCode == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Models already downloaded!')),
          );
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Download completed!')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Download error: $e')));
      }
    }
    if (mounted) {
      setState(() {
        _isDownloading = false;
        _downloadProcess = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final showLoading = _processing || _startingModels;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SelectionArea(
      child: DragTarget<Map<String, dynamic>>(
        onAcceptWithDetails: (details) {
          final data = details.data;
          final path = data['path'];
          final name = data['name'];
          if (path != null && name != null) {
            _handleDroppedFile(path, name);
          }
        },
        builder: (context, candidateData, rejectedData) {
          return Container(
            color: candidateData.isNotEmpty
                ? (isDark ? Colors.blue.shade900 : Colors.blue.shade100)
                : (isDark
                    ? Theme.of(context).colorScheme.surface
                    : const Color(0xFFF1E9FD)),
            child: Column(
              children: [
                ChatHeader(
                  onUpload: showLoading ? null : _handleUpload,
                  isDownloading: _isDownloading,
                  onDownload: _handleDownload,
                  onClear: showLoading
                      ? null
                      : () async {
                          try {
                            await _backend.clearDatabase();
                            setState(() {
                              _messages.clear();
                              _messages.add(
                                ChatMessage(
                                  sender: MessageSender.ai,
                                  text:
                                      'Hello! Upload a document or ask me a question.',
                                ),
                              );
                            });
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to clear: $e')),
                              );
                            }
                          }
                        },
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length + (showLoading ? 1 : 0),
                    itemBuilder: (_, i) => i == _messages.length
                        ? const LoadingIndicator()
                        : MessageBubble(message: _messages[i]),
                  ),
                ),
                ChatInput(
                  controller: _controller,
                  isProcessing: showLoading,
                  onSend: _handleChat,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---Chat Header---
class ChatHeader extends StatelessWidget {
  final VoidCallback? onUpload, onClear, onDownload;
  final bool isDownloading;

  const ChatHeader({
    super.key,
    this.onUpload,
    this.onClear,
    this.onDownload,
    this.isDownloading = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Doc Assistant',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete),
          iconSize: 20.0,
          onPressed: onClear,
          tooltip: 'Clear Chat',
          color: Colors.red.shade400,
        ),
        Stack(
          alignment: Alignment.center,
          children: [
            if (isDownloading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            IconButton(
              icon: Icon(
                isDownloading
                    ? Icons.stop_circle_outlined
                    : Icons.cloud_download,
                size: 20,
              ),
              onPressed: onDownload,
              tooltip: isDownloading ? 'Cancel Download' : 'Download Models',
              color: isDownloading
                  ? Colors.red.shade700
                  : Colors.green.shade700,
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.upload_file),
          onPressed: onUpload,
          tooltip: 'Upload',
          color: Colors.blue.shade700,
        ),
      ],
    ),
  );
}

// ---Chat Input---
class ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isProcessing;
  final Function(String) onSend;

  const ChatInput({
    super.key,
    required this.controller,
    required this.isProcessing,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isProcessing,
            minLines: 1,
            maxLines: 3,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              hintText: 'Ask about documents',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(24)),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onSubmitted: (val) {
              if (val.trim().isNotEmpty) {
                onSend(val);
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: isProcessing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send),
          onPressed: isProcessing ? null : () => onSend(controller.text),
        ),
      ],
    ),
  );
}

// ---Loading Indicator---
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade400,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Processing...', style: TextStyle(fontSize: 14)),
        ],
      ),
    ),
  );
}

// ---Message Bubble---
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isAI = message.isAI;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth * 0.8; // Use 80% of available width
        return Align(
          alignment: isAI ? Alignment.centerLeft : Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(12),
            constraints: BoxConstraints(maxWidth: maxWidth),
            decoration: BoxDecoration(
              color: isDark ? Colors.blue.shade400 : const Color.fromARGB(255, 144, 213, 255),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  message.text,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (isAI && message.sources.isNotEmpty) ...[
                  const Divider(height: 16),
                  Text(
                    'Sources:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  ...message.sources.map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(left: 8, top: 2),
                      child: SelectableText(
                        '• $s',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

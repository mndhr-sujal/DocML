import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';
import '../services/ai_backend_service.dart';

class CenterPanel extends StatefulWidget {
  final Future<void> Function() onPickFile;
  final Future<void> Function(File file) onDropFile;
  final bool hasSelectedFile;
  final VoidCallback onClearFile;

  final String? selectedFileName;
  final String? selectedFileExtension;
  final String? selectedFilePath;

  const CenterPanel({
    super.key,
    required this.onPickFile,
    required this.onDropFile,
    required this.hasSelectedFile,
    required this.onClearFile,
    this.selectedFileName,
    this.selectedFileExtension,
    this.selectedFilePath,
  });

  @override
  State<CenterPanel> createState() => _CenterPanelState();
}

class _CenterPanelState extends State<CenterPanel> {
  bool isDragging = false;
  bool isProcessing = false;
  bool enableTableRecognition = true;
  bool enableFormulaRecognition = true;

  static const List<String> _compressExtensions = [
    'pdf',
    'jpg',
    'jpeg',
    'png',
    'bmp',
    'txt',
    'html',
  ];
  static const List<String> _ocrExtensions = [
    'pdf',
    'jpg',
    'jpeg',
    'png',
    'bmp',
  ];

  static const Map<String, List<String>> _supportedConversions = {
    "png": ["png", "jpg", "jpeg", "bmp", "tiff", "webp", "pdf"],
    "jpg": ["jpg", "jpeg", "png", "bmp", "tiff", "webp", "pdf"],
    "jpeg": ["jpg", "jpeg", "png", "bmp", "tiff", "webp", "pdf"],
    "bmp": ["bmp", "png", "jpg", "jpeg", "tiff", "webp", "pdf"],
    "tiff": ["tiff", "png", "jpg", "jpeg", "bmp", "webp", "pdf"],
    "webp": ["webp", "png", "jpg", "jpeg", "bmp", "tiff", "pdf"],
    "md": ["html", "docx", "pdf"],
    "markdown": ["html", "docx", "pdf"],
    "html": ["md", "markdown", "docx", "pdf"],
    "htm": ["md", "markdown", "docx", "pdf"],
    "docx": ["html", "md", "markdown", "pdf"],
    "odt": ["html", "md", "markdown", "pdf"],
    "epub": ["html", "md", "markdown"],
  };

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  IconData _getFileIcon() {
    final ext = widget.selectedFileExtension?.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'png':
      case 'jpg':
      case 'jpeg':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _getConversionLabel(String format) {
    switch (format.toLowerCase()) {
      case 'pdf':
        return 'PDF';
      case 'docx':
        return 'Docx';
      case 'html':
      case 'htm':
        return 'HTML';
      case 'md':
        return 'Markdown (.md)';
      case 'markdown':
        return 'Markdown (.markdown)';
      case 'odt':
        return 'ODT';
      case 'epub':
        return 'EPUB';
      default:
        return format[0].toUpperCase() + format.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isProcessing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text("Processing..."),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          //Upload and file view switch
          widget.hasSelectedFile
              ? Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (widget.selectedFilePath != null) {
                          OpenFilex.open(widget.selectedFilePath!);
                        }
                      },
                      child: Icon(_getFileIcon(), size: 80, color: Colors.blue),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.selectedFileName ?? '',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      "Click to open",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                )
              : DragTarget<Map<String, dynamic>>(
                  onWillAcceptWithDetails: (details) =>
                      details.data['path'] != null,
                  onAcceptWithDetails: (details) {
                    final path = details.data['path'];
                    if (path != null) widget.onDropFile(File(path));
                  },
                  builder: (context, candidateData, rejectedData) {
                    final showDragging = isDragging || candidateData.isNotEmpty;
                    return DropTarget(
                      onDragEntered: (details) =>
                          setState(() => isDragging = true),
                      onDragExited: (details) =>
                          setState(() => isDragging = false),
                      onDragDone: (details) =>
                          widget.onDropFile(File(details.files.first.path)),
                      child: GestureDetector(
                        onTap: widget.onPickFile,
                        child: Container(
                          height: 200,
                          width: 500,
                          decoration: BoxDecoration(
                            color: showDragging
                                ? Colors.blue.shade50
                                : Colors.transparent,
                            border: Border.all(
                              color: showDragging ? Colors.blue : Colors.grey,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.upload,
                                size: 40,
                                color: showDragging
                                    ? Colors.blue
                                    : (Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.white
                                          : Colors.black),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "Select/Drag and drop your file",
                                style: TextStyle(
                                  fontSize: 16,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                showDragging
                                    ? "Release to upload"
                                    : "Click to choose file",
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

          const SizedBox(height: 20),

          //Buttons after file selection
          if (widget.hasSelectedFile)
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 20, // space between buttons horizontally
              runSpacing: 20, // space between rows
              children: [
                if (_compressExtensions.contains(
                  widget.selectedFileExtension?.toLowerCase(),
                ))
                  ElevatedButton(
                    onPressed: () async {
                      debugPrint("Compress clicked");
                      _showSnackBar("Compressing file...", Colors.grey);
                      final result = await AiBackendService().runPythonScript(
                        'lib/compress.py',
                        [widget.selectedFilePath!],
                      );
                      if (result != null) {
                        if (result.exitCode == 0) {
                          _showSnackBar(
                            "Compression successful!",
                            Colors.green,
                          );
                        } else {
                          _showSnackBar("Compression failed!", Colors.red);
                        }
                      } else {
                        _showSnackBar("Error running compress.py", Colors.red);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      fixedSize: const Size(130, 55),
                      backgroundColor: const Color(0xFFE3DCE4),
                    ),
                    child: const Text(
                      "Compress",
                      style: TextStyle(color: Colors.black),
                    ),
                  ),

                if (_ocrExtensions.contains(
                  widget.selectedFileExtension?.toLowerCase(),
                ))
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          setState(() => isProcessing = true);
                          debugPrint("OCR clicked");
                          _showSnackBar("Running OCR...", Colors.grey);

                          final ocrResult = await AiBackendService()
                              .runPythonScript('lib/ocr.py', [
                                widget.selectedFilePath!,
                                if (enableTableRecognition) '--table',
                                if (enableFormulaRecognition) '--formula',
                              ]);

                          if (ocrResult == null || ocrResult.exitCode != 0) {
                            if (ocrResult != null) {
                              _showSnackBar("OCR failed!", Colors.red);
                            }
                            setState(() => isProcessing = false);
                            return;
                          }

                          _showSnackBar(
                            "Running reconstruction...",
                            Colors.grey,
                          );
                          final reconstructResult = await AiBackendService()
                              .runPythonScript('lib/reconstruct.py', [
                                widget.selectedFilePath!,
                                if (enableTableRecognition) '--table',
                                if (enableFormulaRecognition) '--formula',
                              ]);

                          if (reconstructResult != null) {
                            if (reconstructResult.exitCode == 0) {
                              _showSnackBar(
                                "OCR and reconstruction successful!",
                                Colors.green,
                              );
                            } else {
                              _showSnackBar(
                                "Reconstruction failed!",
                                Colors.red,
                              );
                            }
                          }
                          setState(() => isProcessing = false);
                        },
                        style: ElevatedButton.styleFrom(
                          fixedSize: const Size(130, 55),
                          backgroundColor: const Color(0xFFE3DCE4),
                        ),
                        child: const Text(
                          "OCR",
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: 110,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FilterChip(
                              label: const Center(
                                child: Text(
                                  "Table",
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                              selected: enableTableRecognition,
                              onSelected: (val) =>
                                  setState(() => enableTableRecognition = val),
                              backgroundColor: const Color(0xFFE3DCE4),
                              selectedColor: const Color(0xFFC4B5D9),
                              labelStyle: const TextStyle(color: Colors.black),
                              checkmarkColor: Colors.black,
                            ),
                            const SizedBox(height: 8),
                            FilterChip(
                              label: const Center(
                                child: Text(
                                  "Formula",
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                              selected: enableFormulaRecognition,
                              onSelected: (val) => setState(
                                () => enableFormulaRecognition = val,
                              ),
                              backgroundColor: const Color(0xFFE3DCE4),
                              selectedColor: const Color(0xFFC4B5D9),
                              labelStyle: const TextStyle(color: Colors.black),
                              checkmarkColor: Colors.black,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                _buildConvertButton(),

                ElevatedButton.icon(
                  onPressed: widget.onClearFile,
                  style: ElevatedButton.styleFrom(
                    fixedSize: const Size(130, 55),
                    backgroundColor: const Color(0xFFE3DCE4),
                  ),
                  icon: const Icon(Icons.close, color: Colors.black),
                  label: const Text(
                    "Remove",
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ---Conversion Button---
  Widget _buildConvertButton() {
    final inputExt = widget.selectedFileExtension?.toLowerCase() ?? '';
    final allowedOutputs = _supportedConversions[inputExt] ?? [];

    // Filter out allowed outputs
    final filteredOutputs = allowedOutputs
        .where((out) => out != inputExt)
        .toList();

    if (filteredOutputs.isEmpty) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      offset: const Offset(-10, 60),
      color: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (value) async {
        debugPrint("Selected format: $value");
        _showSnackBar("Converting to $value...", Colors.grey);
        final result = await AiBackendService().runPythonScript(
          'lib/convert.py',
          [widget.selectedFilePath!, value],
        );

        if (result != null) {
          if (result.exitCode == 0) {
            _showSnackBar("Conversion to $value successful!", Colors.green);
          } else {
            _showSnackBar("Conversion to $value failed!", Colors.red);
          }
        }
      },
      itemBuilder: (context) {
        return filteredOutputs
            .map(
              (format) => PopupMenuItem<String>(
                value: format,
                child: Text(_getConversionLabel(format)),
              ),
            )
            .toList();
      },
      child: Container(
        width: 130,
        height: 55,
        decoration: BoxDecoration(
          color: const Color(0xFFE3DCE4),
          borderRadius: BorderRadius.circular(55),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("File Format", style: TextStyle(color: Colors.black)),

            Icon(Icons.arrow_drop_down, color: Colors.black),
          ],
        ),
      ),
    );
  }
}

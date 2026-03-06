import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';

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

  IconData getFileIcon() {
    switch (widget.selectedFileExtension) {
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
                        if (widget.selectedFilePath != null)
                        {
                          OpenFilex.open(widget.selectedFilePath!);
                        }
                      },
                    child: Icon(
                      getFileIcon(),
                      size: 80,
                      color: Colors.blue,
                    ),
              ),
                    const SizedBox(height: 10),
                    Text(
                      widget.selectedFileName ?? '',
                      style: const TextStyle(fontSize: 16),
                    ),

                    const SizedBox(height: 5),

                    const Text (
                      "Click to open",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                )

                
              : DragTarget<Map<String, dynamic>>(
                  onWillAccept: (data) => data != null && data['path'] != null,
                  onAccept: (data) {
                    final path = data['path'];
                    if (path != null) widget.onDropFile(File(path));
                  },
                  builder: (context, candidateData, rejectedData) {
                    final internalDragging = candidateData.isNotEmpty;
                    return DropTarget(
                      onDragEntered: (details) {
                        setState(() => isDragging = true);
                      },
                      onDragExited: (details) {
                        setState(() => isDragging = false);
                      },
                      onDragDone: (details) {
                        final file = details.files.first;
                        widget.onDropFile(File(file.path));
                      },
                      child: GestureDetector(
                        onTap: widget.onPickFile,
                        child: Container(
                          height: 200,
                          width: 500,
                          decoration: BoxDecoration(
                            color: (isDragging || internalDragging)
                                ? Colors.blue.shade50
                                : Colors.transparent,
                            border: Border.all(
                              color: (isDragging || internalDragging) ? Colors.blue : Colors.grey,
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
                                color: (isDragging || internalDragging) ? Colors.blue : Colors.black,
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                "Select/Drag and drop your file",
                                style: TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                (isDragging || internalDragging)
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

          //BUTTONS AFTER FILE SELECTION
          if (widget.hasSelectedFile)
          Wrap(
                alignment: WrapAlignment.center,
                spacing: 20,     // space between buttons horizontally
                runSpacing: 20,  // space between rows
                children: [
                ElevatedButton(
                  onPressed: () async {
                    //For Compress
                    print("Compress clicked");
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Compressing file..."),
                            backgroundColor: Colors.grey,
                          ),
                        );
                    try {
                      final result = await Process.run(
                        'python',
                        [
                          'lib/compress.py',
                          widget.selectedFilePath!
                        ],
                      );
                      
                      if (result.exitCode == 0) {
                        print("Compression successful");
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Compression successful!"),
                            backgroundColor: Colors.green,
                          ),
                        );
                        print(result.stdout);
                      } else {
                        print("Compression failed");
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Compression failed!"),
                            backgroundColor: Colors.red,
                          ),
                        );
                        print(result.stderr);
                      }
                    } catch (e) {
                      print("Error running compression: $e");
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    fixedSize: const Size(130, 55),
                    backgroundColor: const Color.fromARGB(255, 227, 220, 228),
                  ),
                  child: const Text(
                    "Compress",
                    style: TextStyle(color: Colors.black),),
                ),  


                ElevatedButton(
                  onPressed: () async {
                    setState(() => isProcessing = true);
                    print("OCR clicked");
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Running OCR..."),
                        backgroundColor: Colors.grey,
                      ),
                    );
                    try {
                      // Run OCR first
                      final ocrResult = await Process.run(
                        'python',
                        [
                          'lib/ocr.py',
                          widget.selectedFilePath!
                        ],
                      );
                      
                      if (ocrResult.exitCode != 0) {
                        print("OCR failed");
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("OCR failed!"),
                            backgroundColor: Colors.red,
                          ),
                        );
                        print(ocrResult.stderr);
                        setState(() => isProcessing = false);
                        return;
                      }
                      
                      print("OCR completed, running reconstruction...");
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Running reconstruction..."),
                          backgroundColor: Colors.grey,
                        ),
                      );
                      
                      // Run reconstruction
                      final reconstructResult = await Process.run(
                        'python',
                        [
                          'lib/reconstruct.py',
                          widget.selectedFilePath!,
                        ],
                      );
                      
                      if (reconstructResult.exitCode == 0) {
                        print("Reconstruction successful");
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("OCR and reconstruction successful!"),
                            backgroundColor: Colors.green,
                          ),
                        );
                        print(reconstructResult.stdout);
                      } else {
                        print("Reconstruction failed");
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Reconstruction failed!"),
                            backgroundColor: Colors.red,
                          ),
                        );
                        print(reconstructResult.stderr);
                      }
                      setState(() => isProcessing = false);
                    } catch (e) {
                      print("Error running OCR/reconstruction: $e");
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Error: $e"),
                          backgroundColor: Colors.red,
                        ),
                      );
                      setState(() => isProcessing = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    fixedSize: const Size(130, 55),
                    backgroundColor: const Color.fromARGB(255, 227, 220, 228),
                  ),
                  child: const Text(
                    "OCR",
                    style: TextStyle(color: Colors.black),),
                ),  

if (widget.selectedFileExtension!= 'pdf')
                PopupMenuButton<String>(
                  offset: const Offset(-10, 60),
                  color: const Color.fromARGB(255, 255, 255, 255),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  onSelected: (value) async {
                    print("Selected format: $value");
                    // Dismiss any existing snackbar
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    // Show a snackbar indicating conversion is starting
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Converting to $value..."),
                        backgroundColor: Colors.grey,
                      ),
                    );
                    try {
                      final result = await Process.run(
                        'python',
                        [
                          'lib/convert.py',
                          widget.selectedFilePath!,
                          value,  // Pass the selected format as the second argument
                        ],
                      );
                      
                      if (result.exitCode == 0) {
                        print("Conversion successful");
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Conversion to $value successful!"),
                            backgroundColor: Colors.green,
                          ),
                        );
                        print(result.stdout);
                      } else {
                        print("Conversion failed");
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Conversion to $value failed!"),
                            backgroundColor: Colors.red,
                          ),
                        );
                        print(result.stderr);
                      }
                    } catch (e) {
                      print("Error running conversion: $e");
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Error: $e"),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  itemBuilder: (context) {
                    final formats = [
                      {'value': 'pdf', 'label': 'PDF'},
                      {'value': 'jpg', 'label': 'JPG'},
                      {'value': 'png', 'label': 'PNG'},
                      {'value': 'bmp', 'label': 'BMP'},
                      {'value': 'tiff', 'label': 'TIFF'},
                                       ];
                    final filteredFormats = formats.where((format) {
                      final ext = widget.selectedFileExtension?.toLowerCase();
                      if (format['value'] == ext) return false;
                      if (ext == 'pdf' && ['jpg', 'png', 'bmp', 'tiff'].contains(format['value'])) return false;
                      return true;
                    });
                    return filteredFormats.map((format) => PopupMenuItem<String>(
                      value: format['value'],
                      child: Text(format['label']!),
                    )).toList();
                  },
                  child: Container(
                    width: 130,
                    height: 55,
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 227, 220, 228),
                      borderRadius: BorderRadius.circular(55),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "   File Format",
                          style: TextStyle(color: Colors.black),
                        ),
                        SizedBox(width: 2),
                        Icon(Icons.arrow_drop_down, color: Colors.black),
                      ],
                    ),
                  ),
                ),

                ElevatedButton.icon(
                  onPressed: widget.onClearFile,
                  style: ElevatedButton.styleFrom(
                    fixedSize: const Size(130, 55),
                    backgroundColor: const Color.fromARGB(255, 255, 185, 184),
                  ),
                  icon: const Icon(Icons.close),
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
}
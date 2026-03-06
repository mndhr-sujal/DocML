import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

class LeftSidebar extends StatelessWidget {
  final List<Map<String, dynamic>> recentFiles;

  const LeftSidebar({
    super.key,
    required this.recentFiles,
  });

  IconData _getIcon(String? extension) {
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: const Color.fromARGB(255, 196, 181, 217),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "DocML",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 30),

          const Text(
            "Recent Files",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 15),

          Expanded(
            child: recentFiles.isEmpty
                ? const Center(
                    child: Text(
                      "No recent files",
                      style: TextStyle(color: Color.fromARGB(255, 110, 110, 110)),
                    ),
                  )
                : ListView.builder(
              itemCount: recentFiles.length,
              itemBuilder: (context, index) {
                final file = recentFiles[index];

                return Draggable<Map<String, dynamic>>(
                  data: file,
                  feedback: Material(
                    elevation: 4.0,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 200,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: FileTile(
                        name: file['name'],
                        icon: _getIcon(file['extension']),
                      ),
                    ),
                  ),
                  child: InkWell(
                    onTap: () {
                      final path = file['path'];
                      if (path != null) {
                        OpenFilex.open(path); 
                      }
                    },
                    child: FileTile(
                      name: file['name'],
                      icon: _getIcon(file['extension']),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class FileTile extends StatelessWidget {
  final String name;
  final IconData icon;

  const FileTile({
    super.key,
    required this.name,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(name),
      tileColor: const Color.fromARGB(255, 148, 148, 148),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

class LeftSidebar extends StatelessWidget {
  final List<Map<String, dynamic>> recentFiles;
  final Function(String path)? onRemoveRecentFile;
  final VoidCallback? onClearRecentFiles;

  const LeftSidebar({
    super.key,
    required this.recentFiles,
    this.onRemoveRecentFile,
    this.onClearRecentFiles,
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
      color: const Color.fromARGB(255, 196, 181, 217),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "DocML",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Recent Files",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              if (recentFiles.isNotEmpty && onClearRecentFiles != null)
                TextButton(
                  onPressed: onClearRecentFiles,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Clear', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 15),
          Expanded(
            child: recentFiles.isEmpty
                ? const Center(
                    child: Text(
                      "No recent files",
                      style: TextStyle(
                        color: Color.fromARGB(255, 110, 110, 110),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: recentFiles.length,
                    itemBuilder: (context, index) {
                      final file = recentFiles[index];
                      final tile = _FileTile(
                        name: file['name'],
                        icon: _getIcon(file['extension']),
                        onTap: () {
                          final path = file['path'];
                          if (path != null) OpenFilex.open(path);
                        },
                        onRemove: () {
                          final path = file['path'];
                          if (path != null && onRemoveRecentFile != null) {
                            onRemoveRecentFile!(path);
                          }
                        },
                      );

                      return Draggable<Map<String, dynamic>>(
                        data: file,
                        feedback: Material(
                          elevation: 4.0,
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(width: 180, child: tile),
                        ),
                        child: tile,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ---Recent File Item---
class _FileTile extends StatelessWidget {
  final String name;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const _FileTile({
    required this.name,
    required this.icon,
    required this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Icon(icon, size: 20),
      title: Text(
        name,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13),
      ),
      trailing: onRemove != null
          ? IconButton(
              icon: const Icon(Icons.close, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: 16,
              onPressed: onRemove,
              tooltip: 'Remove',
            )
          : null,
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }
}

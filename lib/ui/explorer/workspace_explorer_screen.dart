import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../core/storage/workspace_service.dart';

class WorkspaceExplorerScreen extends StatefulWidget {
  final WorkspaceService workspace;

  const WorkspaceExplorerScreen({super.key, required this.workspace});

  @override
  State<WorkspaceExplorerScreen> createState() => _WorkspaceExplorerScreenState();
}

class _WorkspaceExplorerScreenState extends State<WorkspaceExplorerScreen> {
  List<FileSystemEntity> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() => _loading = true);
    try {
      final list = await widget.workspace.listFiles();
      setState(() {
        _files = list;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workspace Files'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFiles,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _files.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder_open, size: 48, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(height: 12),
                      Text('No files in workspace yet.', style: theme.textTheme.bodyMedium),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _files.length,
                  itemBuilder: (context, index) {
                    final entity = _files[index];
                    final name = p.basename(entity.path);
                    final isDir = entity is Directory;

                    return ListTile(
                      leading: Icon(
                        isDir ? Icons.folder : _getFileIcon(name),
                        color: isDir ? Colors.amber : theme.colorScheme.primary,
                      ),
                      title: Text(name, style: const TextStyle(fontFamily: 'monospace', fontSize: 14)),
                      trailing: isDir ? const Icon(Icons.chevron_right, size: 18) : null,
                      onTap: () {
                        if (!isDir) {
                          _openFileViewer(name);
                        }
                      },
                    );
                  },
                ),
    );
  }

  IconData _getFileIcon(String filename) {
    if (filename.endsWith('.py')) return Icons.code;
    if (filename.endsWith('.dart')) return Icons.flutter_dash;
    if (filename.endsWith('.js') || filename.endsWith('.ts')) return Icons.javascript;
    if (filename.endsWith('.md')) return Icons.article_outlined;
    if (filename.endsWith('.json')) return Icons.data_object;
    return Icons.insert_drive_file_outlined;
  }

  Future<void> _openFileViewer(String filename) async {
    try {
      final content = await widget.workspace.readFile(filename);
      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF1E1E1E),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) {
          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            expand: false,
            builder: (context, scrollController) {
              return Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    height: 4,
                    width: 36,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.code, size: 18, color: Colors.blueAccent),
                        const SizedBox(width: 8),
                        Text(
                          filename,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white12, height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        content,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to read file: $e')));
    }
  }
}

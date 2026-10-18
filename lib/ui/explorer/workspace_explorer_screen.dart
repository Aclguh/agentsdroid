import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../../core/proot/proot_manager.dart';
import '../../core/storage/workspace_service.dart';
import '../../l10n/app_localizations.dart';

class WorkspaceExplorerScreen extends StatefulWidget {
  final WorkspaceService workspace;
  final PRootManager? prootManager;

  const WorkspaceExplorerScreen({
    super.key,
    required this.workspace,
    this.prootManager,
  });

  @override
  State<WorkspaceExplorerScreen> createState() => _WorkspaceExplorerScreenState();
}

class _WorkspaceExplorerScreenState extends State<WorkspaceExplorerScreen> {
  List<FileSystemEntity> _files = [];
  bool _loading = true;
  String? _gitStatus;

  @override
  void initState() {
    super.initState();
    _loadFiles();
    _checkGitStatus();
  }

  Future<void> _checkGitStatus() async {
    if (widget.prootManager != null) {
      final status = await widget.workspace.getGitStatus(widget.prootManager!);
      if (mounted) {
        setState(() {
          _gitStatus = status;
        });
      }
    }
  }

  Future<void> _loadFiles() async {
    setState(() => _loading = true);
    try {
      final list = await widget.workspace.listFiles();
      setState(() {
        _files = list;
        _loading = false;
      });
      _checkGitStatus();
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _exportZip() async {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.exportingZip)),
    );

    try {
      final zip = await widget.workspace.exportWorkspaceZip();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.zipExported}\n${zip.path}'),
          action: SnackBarAction(
            label: l10n.copyContent,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: zip.path));
            },
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败: $e')),
      );
    }
  }

  Future<void> _showCloneDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();

    if (widget.prootManager == null || !await widget.prootManager!.isInstalled()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.notInstalledWarning)),
      );
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(l10n.cloneGit),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: l10n.cloneGitHint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final url = controller.text.trim();
              if (url.isEmpty) return;
              Navigator.pop(ctx);
              _performGitClone(url);
            },
            child: Text(l10n.cloneGit),
          ),
        ],
      ),
    );
  }

  Future<void> _performGitClone(String url) async {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.cloning)),
    );

    try {
      final res = await widget.workspace.cloneGitRepository(url, widget.prootManager!);
      if (!mounted) return;
      if (res.exitCode == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.cloneSuccess)),
        );
        _loadFiles();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.cloneFailed}: ${res.stderr}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.cloneFailed}: $e')),
      );
    }
  }

  Future<void> _showCreateDialog({required bool isDirectory}) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(isDirectory ? l10n.newFolder : l10n.newFile),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: isDirectory ? l10n.folderNameHint : l10n.fileNameHint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);

              if (isDirectory) {
                await widget.workspace.createDirectory(name);
              } else {
                await widget.workspace.writeFile(name, '');
              }
              _loadFiles();
            },
            child: Text(l10n.approve),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(FileSystemEntity entity) async {
    final l10n = AppLocalizations.of(context)!;
    final name = p.basename(entity.path);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(l10n.deleteConfirm),
        content: Text('${l10n.deleteConfirmMsg}\n($name)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                if (entity is Directory) {
                  await entity.delete(recursive: true);
                } else {
                  await entity.delete();
                }
                _loadFiles();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('删除失败: $e')),
                );
              }
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.workspaceFiles, style: const TextStyle(fontSize: 16)),
            if (_gitStatus != null && _gitStatus!.isNotEmpty && _gitStatus != 'Not a Git repository')
              Text(
                'Git: ${_gitStatus!.replaceAll('\n', ', ')}',
                style: const TextStyle(fontSize: 11, color: Colors.greenAccent, fontFamily: 'monospace'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            onPressed: _exportZip,
            tooltip: l10n.exportZip,
          ),
          IconButton(
            icon: const Icon(Icons.download_for_offline_outlined),
            onPressed: _showCloneDialog,
            tooltip: l10n.cloneGit,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.add),
            onSelected: (val) {
              if (val == 'file') _showCreateDialog(isDirectory: false);
              if (val == 'folder') _showCreateDialog(isDirectory: true);
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(value: 'file', child: Text(l10n.newFile)),
              PopupMenuItem(value: 'folder', child: Text(l10n.newFolder)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFiles,
            tooltip: l10n.refresh,
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
                      Text(l10n.noFilesInWorkspace, style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 16),
                      FilledButton.tonalIcon(
                        onPressed: () => _showCreateDialog(isDirectory: false),
                        icon: const Icon(Icons.add),
                        label: Text(l10n.newFile),
                      ),
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
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isDir) const Icon(Icons.chevron_right, size: 18),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.white38),
                            onPressed: () => _confirmDelete(entity),
                            tooltip: l10n.delete,
                          ),
                        ],
                      ),
                      onTap: () {
                        if (!isDir) {
                          _openFileViewer(name);
                        }
                      },
                      onLongPress: () => _confirmDelete(entity),
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
                          icon: const Icon(Icons.copy, size: 18, color: Colors.white70),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: content));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已复制文件内容到剪贴板')),
                            );
                          },
                        ),
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

import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/proot/proot_installer.dart';
import '../../core/proot/proot_manager.dart';
import '../../core/storage/key_vault.dart';
import '../../l10n/app_localizations.dart';
import '../terminal/subsystem_terminal_screen.dart';

class SubsystemSettingsScreen extends StatefulWidget {
  final KeyVault keyVault;
  final PRootManager prootManager;

  const SubsystemSettingsScreen({
    super.key,
    required this.keyVault,
    required this.prootManager,
  });

  @override
  State<SubsystemSettingsScreen> createState() => _SubsystemSettingsScreenState();
}

class _SubsystemSettingsScreenState extends State<SubsystemSettingsScreen> {
  PRootProgress? _prootProgress;
  int _installMethodIndex = 0; // 0: Online, 1: Offline
  String _selectedMirror = 'ghproxy'; // 'ghproxy', 'official', 'custom'

  late final TextEditingController _customUrlController;
  late final TextEditingController _filePathController;

  List<File> _scannedArchives = [];
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _customUrlController = TextEditingController(text: RootfsInstaller.ghproxyDebianRootfsUrl);
    _filePathController = TextEditingController(text: '/sdcard/Download/debian-arm64.tar.xz');

    widget.prootManager.statusStream.listen((progress) {
      if (mounted) {
        setState(() {
          _prootProgress = progress;
        });
      }
    });

    _scanArchives();
  }

  @override
  void dispose() {
    _customUrlController.dispose();
    _filePathController.dispose();
    super.dispose();
  }

  Future<void> _scanArchives() async {
    setState(() {
      _isScanning = true;
    });

    try {
      final archives = await RootfsInstaller.scanLocalArchives();
      if (mounted) {
        setState(() {
          _scannedArchives = archives;
          if (archives.isNotEmpty) {
            _filePathController.text = archives.first.path;
          }
          _isScanning = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  void _triggerOnlineInstall() {
    String url;
    if (_selectedMirror == 'ghproxy') {
      url = RootfsInstaller.ghproxyDebianRootfsUrl;
    } else if (_selectedMirror == 'official') {
      url = RootfsInstaller.defaultDebianRootfsUrl;
    } else {
      url = _customUrlController.text.trim();
      if (url.isEmpty) {
        url = RootfsInstaller.ghproxyDebianRootfsUrl;
      }
    }

    widget.prootManager.installSubsystem(downloadUrl: url);
  }

  void _triggerOfflineImport() {
    final l10n = AppLocalizations.of(context)!;
    final path = _filePathController.text.trim();
    if (path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.subsystemPathEmpty)),
      );
      return;
    }

    final file = File(path);
    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.subsystemFileNotFound}: $path')),
      );
      return;
    }

    widget.prootManager.installSubsystemFromArchive(file);
  }

  Future<void> _confirmResetSubsystem() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.subsystemReinstall),
        content: Text(l10n.subsystemReinstallConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await widget.prootManager.uninstallSubsystem();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.subsystemResetSuccess)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isReady = widget.prootManager.currentStatus == PRootStatus.ready;
    final isWorking = _prootProgress != null &&
        (_prootProgress!.status == PRootStatus.downloading ||
            _prootProgress!.status == PRootStatus.extracting ||
            _prootProgress!.status == PRootStatus.configuring);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.subsystemSection),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Subsystem Status Card
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isReady
                    ? Colors.greenAccent.withValues(alpha: 0.4)
                    : Colors.amberAccent.withValues(alpha: 0.4),
                width: 1.2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isReady ? Icons.check_circle : Icons.info_outline,
                        color: isReady ? Colors.greenAccent : Colors.amberAccent,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isReady ? l10n.subsystemReady : l10n.subsystemNotInstalled,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.subsystemDesc,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),

                  if (isWorking) ...[
                    const SizedBox(height: 16),
                    LinearProgressIndicator(value: _prootProgress?.progress),
                    const SizedBox(height: 8),
                    Text(
                      _prootProgress?.message ?? '',
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],

                  if (isReady && !isWorking) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SubsystemTerminalScreen(
                                  prootManager: widget.prootManager,
                                  keyVault: widget.keyVault,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.terminal, size: 18),
                          label: Text(l10n.openTerminal),
                        ),
                        OutlinedButton.icon(
                          onPressed: _confirmResetSubsystem,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: Text(l10n.subsystemReinstall),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Installation Options Card (When not ready and not currently installing)
          if (!isReady && !isWorking) ...[
            const SizedBox(height: 16),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.subsystemInstallMethod,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 14),

                    // Method selector SegmentedButton
                    Center(
                      child: SegmentedButton<int>(
                        segments: [
                          ButtonSegment<int>(
                            value: 0,
                            icon: const Icon(Icons.cloud_download_outlined, size: 18),
                            label: Text(l10n.subsystemOnlineDownload),
                          ),
                          ButtonSegment<int>(
                            value: 1,
                            icon: const Icon(Icons.folder_zip_outlined, size: 18),
                            label: Text(l10n.subsystemOfflineImport),
                          ),
                        ],
                        selected: {_installMethodIndex},
                        onSelectionChanged: (newSelection) {
                          setState(() {
                            _installMethodIndex = newSelection.first;
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Method 1: Online Download
                    if (_installMethodIndex == 0) ...[
                      Text(
                        l10n.subsystemMirrorSource,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),

                      RadioListTile<String>(
                        value: 'ghproxy',
                        groupValue: _selectedMirror,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.subsystemMirrorGhproxy, style: const TextStyle(fontSize: 13)),
                        subtitle: const Text('https://ghproxy.net/...', style: TextStyle(fontSize: 11)),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedMirror = val);
                        },
                      ),
                      RadioListTile<String>(
                        value: 'official',
                        groupValue: _selectedMirror,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.subsystemMirrorOfficial, style: const TextStyle(fontSize: 13)),
                        subtitle: const Text('https://github.com/termux/...', style: TextStyle(fontSize: 11)),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedMirror = val);
                        },
                      ),
                      RadioListTile<String>(
                        value: 'custom',
                        groupValue: _selectedMirror,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.subsystemMirrorCustom, style: const TextStyle(fontSize: 13)),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedMirror = val);
                        },
                      ),

                      if (_selectedMirror == 'custom') ...[
                        const SizedBox(height: 6),
                        TextField(
                          controller: _customUrlController,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: l10n.subsystemCustomUrlHint,
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ],

                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _triggerOnlineInstall,
                          icon: const Icon(Icons.download, size: 18),
                          label: Text(l10n.installSubsystem),
                        ),
                      ),
                    ],

                    // Method 2: Offline Import
                    if (_installMethodIndex == 1) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          l10n.subsystemOfflineHelp,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.subsystemDetectedArchives,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _isScanning ? null : _scanArchives,
                            icon: Icon(_isScanning ? Icons.hourglass_top : Icons.sync, size: 14),
                            label: Text(l10n.subsystemRescan, style: const TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),

                      if (_scannedArchives.isNotEmpty) ...[
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _scannedArchives.length,
                          itemBuilder: (context, index) {
                            final file = _scannedArchives[index];
                            final name = file.path.split(Platform.pathSeparator).last;
                            final sizeMb = (file.lengthSync() / 1024 / 1024).toStringAsFixed(1);
                            final isCurrent = _filePathController.text == file.path;

                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                              leading: Icon(
                                Icons.archive_outlined,
                                color: isCurrent ? theme.colorScheme.primary : null,
                                size: 20,
                              ),
                              title: Text(name, style: const TextStyle(fontSize: 13)),
                              subtitle: Text('$sizeMb MB • ${file.path}', style: const TextStyle(fontSize: 11)),
                              trailing: isCurrent
                                  ? Icon(Icons.check, size: 18, color: theme.colorScheme.primary)
                                  : null,
                              onTap: () {
                                setState(() {
                                  _filePathController.text = file.path;
                                });
                              },
                            );
                          },
                        ),
                      ] else ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            l10n.subsystemNoArchivesDetected,
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),
                      Text(
                        l10n.subsystemManualPath,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _filePathController,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: l10n.subsystemManualPathHint,
                          border: const OutlineInputBorder(),
                          isDense: true,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () => _filePathController.clear(),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _triggerOfflineImport,
                          icon: const Icon(Icons.file_upload_outlined, size: 18),
                          label: Text(l10n.subsystemStartImport),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Technical architecture notes card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Zero-Root PRoot Architecture',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '• 用户态隔离：所有执行均通过 ptrace 系统调用在 App 内部沙箱中模拟 root 环境，绝不需要设备 root。\n'
                    '• 标准 Linux 工具链：内置 apt 包管理器，支持安装 Node.js、Python、Git 与编译构建依赖。\n'
                    '• 原生 Agent 对接：无缝运行 Anthropic Claude Code CLI 与 Aider 等终端开发助手。',
                    style: TextStyle(fontSize: 12, height: 1.5, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

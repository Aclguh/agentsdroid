import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  List<File> _scannedArchives = [];
  File? _selectedArchive;
  String? _displayDataDirPath;
  bool _isScanning = false;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _customUrlController = TextEditingController(text: RootfsInstaller.ghproxyDebianRootfsUrl);

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
    super.dispose();
  }

  Future<void> _scanArchives() async {
    setState(() {
      _isScanning = true;
    });

    try {
      final dirs = await RootfsInstaller.getAppDataDirectories();
      final archives = await RootfsInstaller.scanLocalArchives();
      if (mounted) {
        setState(() {
          if (dirs.isNotEmpty) {
            _displayDataDirPath = dirs.first.path;
          }
          _scannedArchives = archives;
          if (archives.isNotEmpty) {
            _selectedArchive = archives.first;
          } else {
            _selectedArchive = null;
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

  void _triggerOfflineImport() async {
    final l10n = AppLocalizations.of(context)!;
    if (_isImporting ||
        _prootProgress?.status == PRootStatus.extracting ||
        _prootProgress?.status == PRootStatus.downloading) {
      return;
    }

    if (_selectedArchive == null || !_selectedArchive!.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.subsystemNoPackageToImport),
          action: SnackBarAction(
            label: l10n.subsystemRescan,
            onPressed: _scanArchives,
          ),
        ),
      );
      _scanArchives();
      return;
    }

    setState(() {
      _isImporting = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('开始解压并安装 Linux 子系统，请稍候...'),
        duration: Duration(seconds: 4),
      ),
    );

    try {
      await widget.prootManager.installSubsystemFromArchive(_selectedArchive!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('安装遇到错误: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  void _copyDataDirPath() {
    if (_displayDataDirPath == null) return;
    Clipboard.setData(ClipboardData(text: _displayDataDirPath!));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.subsystemPathCopied)),
    );
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

          // Installation Options Card (When not ready)
          if (!isReady) ...[
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
                          if (newSelection.first == 1) {
                            _scanArchives();
                          }
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
                          onPressed: (isWorking || _isImporting) ? null : _triggerOnlineInstall,
                          icon: (isWorking || _isImporting)
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.download, size: 18),
                          label: Text(
                            (isWorking || _isImporting)
                                ? '正在安装子系统...'
                                : l10n.installSubsystem,
                          ),
                        ),
                      ),
                    ],

                    // Method 2: Offline Import from App Data Directory
                    if (_installMethodIndex == 1) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.folder_shared_outlined, size: 18, color: theme.colorScheme.primary),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.subsystemDataDir,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l10n.subsystemDataDirDesc,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (_displayDataDirPath != null) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: theme.colorScheme.outlineVariant),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: SelectableText(
                                        _displayDataDirPath!,
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 11,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.copy, size: 16),
                                      tooltip: l10n.subsystemCopyPath,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: _copyDataDirPath,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _scannedArchives.isNotEmpty
                                ? l10n.subsystemDetectedPackage
                                : l10n.subsystemWaitingForPackage,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _scannedArchives.isNotEmpty
                                  ? Colors.greenAccent
                                  : theme.colorScheme.onSurfaceVariant,
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
                            int sizeBytes = 0;
                            try {
                              sizeBytes = file.lengthSync();
                            } catch (_) {}
                            final sizeMb = (sizeBytes / 1024 / 1024).toStringAsFixed(1);
                            final isSelected = _selectedArchive?.path == file.path;

                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(top: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.outlineVariant,
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              child: ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                leading: Icon(
                                  Icons.inventory_2_outlined,
                                  color: isSelected ? theme.colorScheme.primary : null,
                                  size: 22,
                                ),
                                title: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                subtitle: Text('$sizeMb MB • ${file.path}', style: const TextStyle(fontSize: 11)),
                                trailing: isSelected
                                    ? Icon(Icons.check_circle, size: 20, color: theme.colorScheme.primary)
                                    : null,
                                onTap: () {
                                  setState(() {
                                    _selectedArchive = file;
                                  });
                                },
                              ),
                            );
                          },
                        ),
                      ] else ...[
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, size: 18, color: Colors.amberAccent),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  l10n.subsystemWaitingDesc,
                                  style: const TextStyle(fontSize: 12, height: 1.4, color: Colors.white70),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),
                      if (isWorking || _isImporting) ...[
                        LinearProgressIndicator(value: _prootProgress?.progress),
                        const SizedBox(height: 8),
                        Text(
                          _prootProgress?.message ?? '正在解压并配置子系统...',
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
                        ),
                        const SizedBox(height: 12),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: (isWorking || _isImporting) ? null : _triggerOfflineImport,
                          icon: (isWorking || _isImporting)
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.file_upload_outlined, size: 18),
                          label: Text(
                            (isWorking || _isImporting)
                                ? '正在解压导入中...'
                                : l10n.subsystemStartImport,
                          ),
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

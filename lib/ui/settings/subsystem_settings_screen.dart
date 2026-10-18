import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    widget.prootManager.statusStream.listen((progress) {
      if (mounted) {
        setState(() {
          _prootProgress = progress;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isReady = widget.prootManager.currentStatus == PRootStatus.ready;

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

                  if (_prootProgress != null &&
                      (_prootProgress!.status == PRootStatus.downloading ||
                          _prootProgress!.status == PRootStatus.extracting)) ...[
                    const SizedBox(height: 16),
                    LinearProgressIndicator(value: _prootProgress!.progress),
                    const SizedBox(height: 8),
                    Text(
                      _prootProgress!.message,
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ],

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (!isReady)
                        FilledButton.icon(
                          onPressed: () => widget.prootManager.installSubsystem(),
                          icon: const Icon(Icons.download, size: 18),
                          label: Text(l10n.installSubsystem),
                        ),
                      if (isReady)
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
                    ],
                  ),
                ],
              ),
            ),
          ),

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

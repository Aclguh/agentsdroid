import 'package:flutter/material.dart';
import '../../core/proot/proot_manager.dart';
import '../../core/storage/key_vault.dart';
import '../../l10n/app_localizations.dart';

class EngineSettingsScreen extends StatefulWidget {
  final KeyVault keyVault;
  final PRootManager prootManager;

  const EngineSettingsScreen({
    super.key,
    required this.keyVault,
    required this.prootManager,
  });

  @override
  State<EngineSettingsScreen> createState() => _EngineSettingsScreenState();
}

class _EngineSettingsScreenState extends State<EngineSettingsScreen> {
  late String _selectedEngine;

  @override
  void initState() {
    super.initState();
    _selectedEngine = widget.keyVault.getSelectedEngine();
  }

  Future<void> _setEngine(String engine) async {
    setState(() => _selectedEngine = engine);
    await widget.keyVault.setSelectedEngine(engine);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isSubsystemReady = widget.prootManager.currentStatus == PRootStatus.ready;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.agentEngine),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Text(
            l10n.engineSwitchTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Built-in Agent Card
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: _selectedEngine == 'builtin'
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                width: _selectedEngine == 'builtin' ? 1.5 : 1,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _setEngine('builtin'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Radio<String>(
                      value: 'builtin',
                      groupValue: _selectedEngine,
                      onChanged: (val) {
                        if (val != null) _setEngine(val);
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                l10n.engineBuiltin,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Recommended',
                                  style: TextStyle(fontSize: 10, color: Colors.greenAccent, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.engineBuiltinDesc,
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Claude Code CLI Card
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: _selectedEngine == 'claudeCode'
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                width: _selectedEngine == 'claudeCode' ? 1.5 : 1,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _setEngine('claudeCode'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Radio<String>(
                      value: 'claudeCode',
                      groupValue: _selectedEngine,
                      onChanged: (val) {
                        if (val != null) _setEngine(val);
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.engineClaudeCode,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.engineClaudeCodeDesc,
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                isSubsystemReady ? Icons.check_circle : Icons.warning_amber_rounded,
                                size: 14,
                                color: isSubsystemReady ? Colors.greenAccent : Colors.amberAccent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isSubsystemReady ? l10n.subsystemReady : l10n.subsystemNotInstalled,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isSubsystemReady ? Colors.greenAccent : Colors.amberAccent,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

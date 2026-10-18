import 'package:flutter/material.dart';
import '../../core/proot/proot_manager.dart';
import '../../core/storage/key_vault.dart';
import '../../l10n/app_localizations.dart';
import 'about_screen.dart';
import 'engine_settings_screen.dart';
import 'language_settings_screen.dart';
import 'model_settings_screen.dart';
import 'safety_settings_screen.dart';
import 'subsystem_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  final KeyVault keyVault;
  final PRootManager prootManager;

  const SettingsScreen({
    super.key,
    required this.keyVault,
    required this.prootManager,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final activeProviderId = widget.keyVault.getActiveProviderId();
    final activeProvider = widget.keyVault.getProvider(activeProviderId);
    final activeProviderName = activeProvider?.name ?? widget.keyVault.getActiveProvider().displayName;
    final activeModelId = widget.keyVault.getActiveModel();
    final activeModel = widget.keyVault.getModel(activeModelId);
    final activeModelName = activeModel?.name ?? activeModelId;

    final selectedEngine = widget.keyVault.getSelectedEngine();
    final engineSubtitle = selectedEngine == 'claudeCode' ? l10n.engineClaudeCode : l10n.engineBuiltin;

    final approvalMode = widget.keyVault.getApprovalMode();
    final String safetySubtitle;
    switch (approvalMode) {
      case ApprovalMode.yolo:
        safetySubtitle = l10n.approvalYolo;
        break;
      case ApprovalMode.alwaysAsk:
        safetySubtitle = l10n.approvalAlwaysAsk;
        break;
      case ApprovalMode.autoApprove:
        safetySubtitle = l10n.approvalAutoApprove;
        break;
    }

    final currentLang = widget.keyVault.getLanguage();
    final langSubtitle = currentLang == 'en' ? l10n.languageEnglish : l10n.languageChinese;

    final isSubsystemReady = widget.prootManager.currentStatus == PRootStatus.ready;
    final subsystemSubtitle = isSubsystemReady ? l10n.subsystemReady : l10n.subsystemNotInstalled;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          _buildSummaryCard(
            context: context,
            title: l10n.modelsAndProviders,
            subtitle: '$activeProviderName • $activeModelName',
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ModelSettingsScreen(keyVault: widget.keyVault),
                ),
              );
              if (mounted) setState(() {});
            },
          ),
          const SizedBox(height: 12),
          _buildSummaryCard(
            context: context,
            title: l10n.agentEngine,
            subtitle: engineSubtitle,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EngineSettingsScreen(
                    keyVault: widget.keyVault,
                    prootManager: widget.prootManager,
                  ),
                ),
              );
              if (mounted) setState(() {});
            },
          ),
          const SizedBox(height: 12),
          _buildSummaryCard(
            context: context,
            title: l10n.safetySection,
            subtitle: safetySubtitle,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SafetySettingsScreen(keyVault: widget.keyVault),
                ),
              );
              if (mounted) setState(() {});
            },
          ),
          const SizedBox(height: 12),
          _buildSummaryCard(
            context: context,
            title: l10n.language,
            subtitle: langSubtitle,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LanguageSettingsScreen(keyVault: widget.keyVault),
                ),
              );
              if (mounted) setState(() {});
            },
          ),
          const SizedBox(height: 12),
          _buildSummaryCard(
            context: context,
            title: l10n.subsystemSection,
            subtitle: subsystemSubtitle,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SubsystemSettingsScreen(
                    keyVault: widget.keyVault,
                    prootManager: widget.prootManager,
                  ),
                ),
              );
              if (mounted) setState(() {});
            },
          ),
          const SizedBox(height: 12),
          _buildSummaryCard(
            context: context,
            title: l10n.about,
            subtitle: l10n.aboutSubtitle,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AboutScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

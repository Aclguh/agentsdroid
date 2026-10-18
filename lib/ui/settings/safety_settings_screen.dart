import 'package:flutter/material.dart';
import '../../core/storage/key_vault.dart';
import '../../l10n/app_localizations.dart';

class SafetySettingsScreen extends StatefulWidget {
  final KeyVault keyVault;

  const SafetySettingsScreen({super.key, required this.keyVault});

  @override
  State<SafetySettingsScreen> createState() => _SafetySettingsScreenState();
}

class _SafetySettingsScreenState extends State<SafetySettingsScreen> {
  late ApprovalMode _approvalMode;

  @override
  void initState() {
    super.initState();
    _approvalMode = widget.keyVault.getApprovalMode();
  }

  Future<void> _setMode(ApprovalMode mode) async {
    setState(() => _approvalMode = mode);
    await widget.keyVault.setApprovalMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.safetySection),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Text(
            l10n.approvalTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.approvalSubtitle,
            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),

          // Auto Approve (Recommended)
          _buildModeCard(
            context: context,
            mode: ApprovalMode.autoApprove,
            title: l10n.approvalAutoApprove,
            description: l10n.approvalAutoApproveDesc,
            badge: 'Recommended',
            badgeColor: Colors.greenAccent,
          ),
          const SizedBox(height: 12),

          // Always Ask
          _buildModeCard(
            context: context,
            mode: ApprovalMode.alwaysAsk,
            title: l10n.approvalAlwaysAsk,
            description: l10n.approvalAlwaysAskDesc,
          ),
          const SizedBox(height: 12),

          // YOLO Mode
          _buildModeCard(
            context: context,
            mode: ApprovalMode.yolo,
            title: l10n.approvalYolo,
            description: l10n.approvalYoloDesc,
            badge: 'Dangerous',
            badgeColor: Colors.redAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required BuildContext context,
    required ApprovalMode mode,
    required String title,
    required String description,
    String? badge,
    Color? badgeColor,
  }) {
    final theme = Theme.of(context);
    final isSelected = _approvalMode == mode;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _setMode(mode),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Radio<ApprovalMode>(
                value: mode,
                groupValue: _approvalMode,
                onChanged: (val) {
                  if (val != null) _setMode(val);
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
                          title,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (badgeColor ?? theme.colorScheme.primary).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                fontSize: 10,
                                color: badgeColor ?? theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

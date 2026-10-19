import 'package:flutter/material.dart';
import '../../core/storage/key_vault.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';

class ScreenRotationSettingsScreen extends StatefulWidget {
  final KeyVault keyVault;

  const ScreenRotationSettingsScreen({super.key, required this.keyVault});

  @override
  State<ScreenRotationSettingsScreen> createState() => _ScreenRotationSettingsScreenState();
}

class _ScreenRotationSettingsScreenState extends State<ScreenRotationSettingsScreen> {
  late bool _isAutoRotate;

  @override
  void initState() {
    super.initState();
    _isAutoRotate = widget.keyVault.isAutoRotateEnabled();
  }

  Future<void> _setAutoRotate(bool autoRotate) async {
    if (_isAutoRotate == autoRotate) return;
    setState(() => _isAutoRotate = autoRotate);
    await widget.keyVault.setAutoRotateEnabled(autoRotate);
    if (mounted) {
      AgentsDroidApp.setScreenOrientation(context, autoRotate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.screenRotation),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Text(
            l10n.screenRotationDesc,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Auto-rotate with Gravity
          _buildOptionCard(
            context: context,
            value: true,
            title: l10n.screenRotationAuto,
            subtitle: l10n.screenRotationAutoDesc,
          ),
          const SizedBox(height: 12),

          // Lock Portrait
          _buildOptionCard(
            context: context,
            value: false,
            title: l10n.screenRotationPortrait,
            subtitle: l10n.screenRotationPortraitDesc,
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required bool value,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    final isSelected = _isAutoRotate == value;

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
        onTap: () => _setAutoRotate(value),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Radio<bool>(
                value: value,
                groupValue: _isAutoRotate,
                onChanged: (val) {
                  if (val != null) _setAutoRotate(val);
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check, color: theme.colorScheme.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

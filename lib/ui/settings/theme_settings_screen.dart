import 'package:flutter/material.dart';
import '../../core/storage/key_vault.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';

class ThemeSettingsScreen extends StatefulWidget {
  final KeyVault keyVault;

  const ThemeSettingsScreen({super.key, required this.keyVault});

  @override
  State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
  late ThemeMode _currentMode;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.keyVault.getThemeMode();
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    if (_currentMode == mode) return;
    setState(() => _currentMode = mode);
    await widget.keyVault.setThemeMode(mode);
    if (mounted) {
      AgentsDroidApp.setThemeMode(context, mode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.themeMode),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Text(
            l10n.themeDesc,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Follow System
          _buildThemeCard(
            context: context,
            mode: ThemeMode.system,
            title: l10n.themeSystem,
            subtitle: l10n.themeSystemDesc,
          ),
          const SizedBox(height: 12),

          // Light Mode
          _buildThemeCard(
            context: context,
            mode: ThemeMode.light,
            title: l10n.themeLight,
            subtitle: l10n.themeLightDesc,
          ),
          const SizedBox(height: 12),

          // Dark Mode
          _buildThemeCard(
            context: context,
            mode: ThemeMode.dark,
            title: l10n.themeDark,
            subtitle: l10n.themeDarkDesc,
          ),
        ],
      ),
    );
  }

  Widget _buildThemeCard({
    required BuildContext context,
    required ThemeMode mode,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    final isSelected = _currentMode == mode;

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
        onTap: () => _setThemeMode(mode),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Radio<ThemeMode>(
                value: mode,
                groupValue: _currentMode,
                onChanged: (val) {
                  if (val != null) _setThemeMode(val);
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

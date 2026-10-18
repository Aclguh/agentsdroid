import 'package:flutter/material.dart';
import '../../core/storage/key_vault.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';

class LanguageSettingsScreen extends StatefulWidget {
  final KeyVault keyVault;

  const LanguageSettingsScreen({super.key, required this.keyVault});

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  late String _currentLanguage;

  @override
  void initState() {
    super.initState();
    _currentLanguage = widget.keyVault.getLanguage();
  }

  Future<void> _setLanguage(String lang) async {
    if (_currentLanguage == lang) return;
    setState(() => _currentLanguage = lang);
    await widget.keyVault.setLanguage(lang);
    if (mounted) {
      AgentsDroidApp.setLocale(context, Locale(lang));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.language),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Text(
            l10n.languageDesc,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Chinese
          _buildLanguageCard(
            context: context,
            code: 'zh',
            title: l10n.languageChinese,
            subtitle: '简体中文 (Default)',
          ),
          const SizedBox(height: 12),

          // English
          _buildLanguageCard(
            context: context,
            code: 'en',
            title: l10n.languageEnglish,
            subtitle: 'English',
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageCard({
    required BuildContext context,
    required String code,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    final isSelected = _currentLanguage == code;

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
        onTap: () => _setLanguage(code),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Radio<String>(
                value: code,
                groupValue: _currentLanguage,
                onChanged: (val) {
                  if (val != null) _setLanguage(val);
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

import 'package:flutter/material.dart';
import '../../core/proot/proot_manager.dart';
import '../../core/storage/key_vault.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart';

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
  late LLMProvider _selectedProvider;
  final _modelController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _baseUrlController = TextEditingController();

  bool _obscureKey = true;
  bool _isYolo = false;
  late String _currentLanguage;
  PRootProgress? _prootProgress;

  @override
  void initState() {
    super.initState();
    _selectedProvider = widget.keyVault.getActiveProvider();
    _modelController.text = widget.keyVault.getActiveModel();
    _isYolo = widget.keyVault.isYoloMode();
    _currentLanguage = widget.keyVault.getLanguage();

    _loadProviderData(_selectedProvider);

    widget.prootManager.statusStream.listen((progress) {
      if (mounted) {
        setState(() {
          _prootProgress = progress;
        });
      }
    });
  }

  Future<void> _loadProviderData(LLMProvider provider) async {
    final key = await widget.keyVault.getApiKey(provider);
    _apiKeyController.text = key ?? '';

    if (provider == LLMProvider.deepseek) {
      _baseUrlController.text = widget.keyVault.getDeepseekBaseUrl();
    } else if (provider == LLMProvider.custom) {
      _baseUrlController.text = widget.keyVault.getCustomBaseUrl();
    } else {
      _baseUrlController.text = '';
    }
  }

  Future<void> _saveCurrentProvider() async {
    await widget.keyVault.setActiveProvider(_selectedProvider);
    await widget.keyVault.setActiveModel(_modelController.text.trim());
    await widget.keyVault.setApiKey(_selectedProvider, _apiKeyController.text.trim());

    if (_selectedProvider == LLMProvider.deepseek) {
      await widget.keyVault.setDeepseekBaseUrl(_baseUrlController.text.trim());
    } else if (_selectedProvider == LLMProvider.custom) {
      await widget.keyVault.setCustomBaseUrl(_baseUrlController.text.trim());
    }
    await widget.keyVault.setYoloMode(_isYolo);

    if (mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsSaved)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveCurrentProvider,
            tooltip: l10n.saveSettings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section: Language Switcher
          Text(l10n.language, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: DropdownButtonFormField<String>(
                initialValue: _currentLanguage,
                decoration: InputDecoration(
                  labelText: l10n.language,
                  border: InputBorder.none,
                ),
                items: [
                  DropdownMenuItem(value: 'zh', child: Text(l10n.languageChinese)),
                  DropdownMenuItem(value: 'en', child: Text(l10n.languageEnglish)),
                ],
                onChanged: (val) {
                  if (val != null && val != _currentLanguage) {
                    setState(() {
                      _currentLanguage = val;
                    });
                    AgentsDroidApp.setLocale(context, Locale(val));
                  }
                },
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Section: Model Provider
          Text(l10n.modelConfigSection, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<LLMProvider>(
                    initialValue: _selectedProvider,
                    decoration: InputDecoration(
                      labelText: l10n.activeProvider,
                      border: const OutlineInputBorder(),
                    ),
                    items: LLMProvider.values.map((p) {
                      return DropdownMenuItem(value: p, child: Text(p.displayName));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedProvider = val;
                          _modelController.text = val.defaultModel;
                        });
                        _loadProviderData(val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _modelController,
                    decoration: InputDecoration(
                      labelText: l10n.modelName,
                      border: const OutlineInputBorder(),
                      helperText: 'e.g. claude-3-7-sonnet-20250219, deepseek-chat, gpt-4o',
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _apiKeyController,
                    obscureText: _obscureKey,
                    decoration: InputDecoration(
                      labelText: '${l10n.apiKey} (${_selectedProvider.displayName})',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureKey ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscureKey = !_obscureKey),
                      ),
                    ),
                  ),

                  if (_selectedProvider == LLMProvider.deepseek || _selectedProvider == LLMProvider.custom) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _baseUrlController,
                      decoration: InputDecoration(
                        labelText: l10n.apiBaseUrl,
                        border: const OutlineInputBorder(),
                        helperText: _selectedProvider == LLMProvider.deepseek
                            ? 'Default: https://api.deepseek.com'
                            : 'OpenAI-compatible endpoint, e.g. https://api.openai.com/v1',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Section: Execution Safety & Autonomous Mode
          Text(l10n.safetySection, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              title: Text(l10n.yoloMode),
              subtitle: Text(
                l10n.yoloModeDesc,
                style: const TextStyle(fontSize: 12),
              ),
              value: _isYolo,
              activeThumbColor: Colors.amber,
              onChanged: (val) {
                setState(() => _isYolo = val);
                widget.keyVault.setYoloMode(val);
              },
            ),
          ),

          const SizedBox(height: 24),

          // Section: In-App Linux Subsystem (PRoot)
          Text(l10n.subsystemSection, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        widget.prootManager.currentStatus == PRootStatus.ready
                            ? Icons.check_circle
                            : Icons.info_outline,
                        color: widget.prootManager.currentStatus == PRootStatus.ready
                            ? Colors.greenAccent
                            : Colors.amber,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${l10n.settings}: ${widget.prootManager.currentStatus == PRootStatus.ready ? l10n.subsystemReady : l10n.subsystemNotInstalled}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.subsystemDesc,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  if (_prootProgress != null &&
                      (_prootProgress!.status == PRootStatus.downloading ||
                          _prootProgress!.status == PRootStatus.extracting)) ...[
                    const SizedBox(height: 16),
                    LinearProgressIndicator(value: _prootProgress!.progress),
                    const SizedBox(height: 8),
                    Text(_prootProgress!.message, style: const TextStyle(fontSize: 11, color: Colors.white70)),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: widget.prootManager.currentStatus == PRootStatus.ready
                        ? null
                        : () => widget.prootManager.installSubsystem(),
                    icon: const Icon(Icons.download),
                    label: Text(
                      widget.prootManager.currentStatus == PRootStatus.ready
                          ? l10n.subsystemReady
                          : l10n.installSubsystem,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
          Center(
            child: FilledButton.tonalIcon(
              onPressed: _saveCurrentProvider,
              icon: const Icon(Icons.save),
              label: Text(l10n.saveSettings),
            ),
          ),
        ],
      ),
    );
  }
}

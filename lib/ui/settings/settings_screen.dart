import 'package:flutter/material.dart';
import '../../core/proot/proot_manager.dart';
import '../../core/storage/key_vault.dart';

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
  PRootProgress? _prootProgress;

  @override
  void initState() {
    super.initState();
    _selectedProvider = widget.keyVault.getActiveProvider();
    _modelController.text = widget.keyVault.getActiveModel();
    _isYolo = widget.keyVault.isYoloMode();

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Providers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveCurrentProvider,
            tooltip: 'Save',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section: Model Provider
          Text('Model & API Configuration', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<LLMProvider>(
                    initialValue: _selectedProvider,
                    decoration: const InputDecoration(
                      labelText: 'Active AI Provider',
                      border: OutlineInputBorder(),
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
                    decoration: const InputDecoration(
                      labelText: 'Model Name',
                      border: OutlineInputBorder(),
                      helperText: 'e.g. claude-3-7-sonnet-20250219, deepseek-chat, gpt-4o',
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _apiKeyController,
                    obscureText: _obscureKey,
                    decoration: InputDecoration(
                      labelText: 'API Key (${_selectedProvider.displayName})',
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
                        labelText: 'API Base URL',
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
          Text('Execution Safety', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              title: const Text('Autonomous Mode (YOLO Mode)'),
              subtitle: const Text(
                'Automatically approve all tool executions and file modifications without manual confirmation cards.',
                style: TextStyle(fontSize: 12),
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
          Text('Embedded Linux Subsystem (PRoot)', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
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
                        'Status: ${widget.prootManager.currentStatus == PRootStatus.ready ? 'Installed & Ready' : 'Not Installed'}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Runs Debian-arm64 directly inside the app sandbox via PRoot. Zero root required, supports official @anthropic-ai/claude-code & aider.',
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
                          ? 'Subsystem Ready'
                          : 'Download & Install Subsystem',
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
              label: const Text('Save Settings'),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/storage/key_vault.dart';
import '../../l10n/app_localizations.dart';

class ModelSettingsScreen extends StatefulWidget {
  final KeyVault keyVault;

  const ModelSettingsScreen({super.key, required this.keyVault});

  @override
  State<ModelSettingsScreen> createState() => _ModelSettingsScreenState();
}

class _ModelSettingsScreenState extends State<ModelSettingsScreen> {
  late List<ModelProviderConfig> _providers;
  late String _activeProviderId;
  late String _activeModelId;
  final Map<String, bool> _apiKeyConfiguredMap = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _providers = widget.keyVault.getProviders();
    _activeProviderId = widget.keyVault.getActiveProviderId();
    _activeModelId = widget.keyVault.getActiveModel();

    for (final p in _providers) {
      final key = await widget.keyVault.getApiKeyForProvider(p.id);
      _apiKeyConfiguredMap[p.id] = (key != null && key.isNotEmpty);
    }
    if (mounted) setState(() {});
  }

  Future<void> _setActiveModel(ModelProviderConfig provider, ModelConfig model) async {
    await widget.keyVault.setActiveProviderId(provider.id);
    await widget.keyVault.setActiveModel(model.id);
    setState(() {
      _activeProviderId = provider.id;
      _activeModelId = model.id;
    });
    if (mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.activeModelBadge}: ${model.name} (${provider.name})'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showAddProviderDialog(BuildContext context, AppLocalizations l10n) {
    final nameController = TextEditingController();
    final baseUrlController = TextEditingController();
    final apiKeyController = TextEditingController();
    final firstModelIdController = TextEditingController();
    final firstModelNameController = TextEditingController();
    String selectedProtocol = 'openai';
    bool supportsThinking = false;
    bool obscureKey = true;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: Text(l10n.addProvider),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: l10n.providerName,
                          hintText: l10n.providerNameHint,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedProtocol,
                        decoration: InputDecoration(
                          labelText: l10n.apiProtocol,
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'openai',
                            child: Text(l10n.protocolOpenAi),
                          ),
                          DropdownMenuItem(
                            value: 'anthropic',
                            child: Text(l10n.protocolAnthropic),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedProtocol = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: baseUrlController,
                        decoration: InputDecoration(
                          labelText: l10n.apiBaseUrl,
                          hintText: selectedProtocol == 'openai'
                              ? 'https://api.openai.com/v1'
                              : 'https://api.anthropic.com',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: apiKeyController,
                        obscureText: obscureKey,
                        decoration: InputDecoration(
                          labelText: l10n.apiKey,
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(obscureKey ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setDialogState(() => obscureKey = !obscureKey),
                          ),
                        ),
                      ),
                      const Divider(height: 24),
                      Text(
                        l10n.addModel,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: firstModelIdController,
                        decoration: InputDecoration(
                          labelText: l10n.modelId,
                          hintText: l10n.modelIdHint,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: firstModelNameController,
                        decoration: InputDecoration(
                          labelText: l10n.modelDisplayName,
                          hintText: l10n.modelDisplayNameHint,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.supportsThinking, style: const TextStyle(fontSize: 13)),
                        subtitle: Text(l10n.supportsThinkingDesc, style: const TextStyle(fontSize: 11)),
                        value: supportsThinking,
                        onChanged: (val) => setDialogState(() => supportsThinking = val),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final baseUrl = baseUrlController.text.trim();
                    final key = apiKeyController.text.trim();
                    final mId = firstModelIdController.text.trim();
                    final mName = firstModelNameController.text.trim();

                    if (name.isEmpty || baseUrl.isEmpty || mId.isEmpty) {
                      return;
                    }

                    final newId = 'custom_${DateTime.now().millisecondsSinceEpoch}';
                    final provider = ModelProviderConfig(
                      id: newId,
                      name: name,
                      baseUrl: baseUrl,
                      apiType: selectedProtocol,
                      models: [
                        ModelConfig(
                          id: mId,
                          name: mName.isNotEmpty ? mName : mId,
                          supportsThinking: supportsThinking,
                        ),
                      ],
                      isCustom: true,
                    );

                    await widget.keyVault.addOrUpdateProvider(provider);
                    if (key.isNotEmpty) {
                      await widget.keyVault.setApiKeyForProvider(newId, key);
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _loadData();
                  },
                  child: Text(l10n.save),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditProviderDialog(BuildContext context, ModelProviderConfig provider, AppLocalizations l10n) async {
    final nameController = TextEditingController(text: provider.name);
    final baseUrlController = TextEditingController(text: provider.baseUrl);
    final existingKey = await widget.keyVault.getApiKeyForProvider(provider.id);
    final apiKeyController = TextEditingController(text: existingKey ?? '');
    bool obscureKey = true;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: Text('${l10n.editProvider} - ${provider.name}'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (provider.isCustom) ...[
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: l10n.providerName,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: baseUrlController,
                        decoration: InputDecoration(
                          labelText: l10n.apiBaseUrl,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: apiKeyController,
                        obscureText: obscureKey,
                        decoration: InputDecoration(
                          labelText: l10n.apiKey,
                          hintText: l10n.enterApiKeyHint,
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(obscureKey ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setDialogState(() => obscureKey = !obscureKey),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () async {
                    final newBaseUrl = baseUrlController.text.trim();
                    final newKey = apiKeyController.text.trim();
                    final newName = provider.isCustom ? nameController.text.trim() : provider.name;

                    final updated = provider.copyWith(
                      name: newName.isNotEmpty ? newName : provider.name,
                      baseUrl: newBaseUrl.isNotEmpty ? newBaseUrl : provider.baseUrl,
                    );

                    await widget.keyVault.addOrUpdateProvider(updated);
                    await widget.keyVault.setApiKeyForProvider(provider.id, newKey);

                    if (ctx.mounted) Navigator.pop(ctx);
                    await _loadData();
                  },
                  child: Text(l10n.save),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddModelDialog(BuildContext context, ModelProviderConfig provider, AppLocalizations l10n) {
    final idController = TextEditingController();
    final nameController = TextEditingController();
    bool supportsThinking = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: Text('${l10n.addModel} (${provider.name})'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: idController,
                      decoration: InputDecoration(
                        labelText: l10n.modelId,
                        hintText: l10n.modelIdHint,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: l10n.modelDisplayName,
                        hintText: l10n.modelDisplayNameHint,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.supportsThinking, style: const TextStyle(fontSize: 13)),
                      subtitle: Text(l10n.supportsThinkingDesc, style: const TextStyle(fontSize: 11)),
                      value: supportsThinking,
                      onChanged: (val) => setDialogState(() => supportsThinking = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () async {
                    final id = idController.text.trim();
                    final name = nameController.text.trim();
                    if (id.isEmpty) return;

                    final model = ModelConfig(
                      id: id,
                      name: name.isNotEmpty ? name : id,
                      supportsThinking: supportsThinking,
                    );
                    await widget.keyVault.addModelToProvider(provider.id, model);
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _loadData();
                  },
                  child: Text(l10n.addModel),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteProvider(BuildContext context, ModelProviderConfig provider, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteProvider),
        content: Text(l10n.deleteProviderConfirm(provider.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.keyVault.deleteProvider(provider.id);
              await _loadData();
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteModel(BuildContext context, ModelProviderConfig provider, ModelConfig model, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteModel),
        content: Text(l10n.deleteModelConfirm(model.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.keyVault.removeModelFromProvider(provider.id, model.id);
              await _loadData();
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final activeModelConfig = widget.keyVault.getModel(_activeModelId);
    final activeProviderConfig = widget.keyVault.getProvider(_activeProviderId);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.modelsAndProviders),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.addProvider,
            onPressed: () => _showAddProviderDialog(context, l10n),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Active Model Highlight Card
          Card(
            color: theme.colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.5), width: 1.2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          l10n.currentActiveModel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        activeProviderConfig?.name ?? _activeProviderId,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    activeModelConfig?.name ?? _activeModelId,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _activeModelId,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Configured Providers Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.configuredProviders,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                onPressed: () => _showAddProviderDialog(context, l10n),
                icon: const Icon(Icons.add, size: 16),
                label: Text(l10n.addProvider, style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Provider Cards List
          ..._providers.map((p) {
            final isProviderActive = p.id == _activeProviderId;
            final hasKey = _apiKeyConfiguredMap[p.id] ?? false;

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isProviderActive
                      ? theme.colorScheme.primary.withValues(alpha: 0.4)
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Provider Header
                    Row(
                      children: [
                        Icon(
                          Icons.dns_outlined,
                          size: 20,
                          color: isProviderActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                p.name,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              if (p.isCustom) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    l10n.customProviderTag,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: theme.colorScheme.onSecondaryContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                              if (isProviderActive) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Active',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.greenAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: l10n.editProvider,
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _showEditProviderDialog(context, p, l10n),
                        ),
                        if (p.isCustom)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                            tooltip: l10n.deleteProvider,
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _confirmDeleteProvider(context, p, l10n),
                          ),
                      ],
                    ),

                    const SizedBox(height: 6),
                    Text(
                      p.baseUrl,
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                    ),

                    const SizedBox(height: 8),
                    // Key status
                    Row(
                      children: [
                        Icon(
                          hasKey ? Icons.check_circle : Icons.warning_amber_rounded,
                          size: 14,
                          color: hasKey ? Colors.greenAccent : Colors.amberAccent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          hasKey ? l10n.apiKeyConfigured : l10n.apiKeyMissing,
                          style: TextStyle(
                            fontSize: 12,
                            color: hasKey ? Colors.greenAccent : Colors.amberAccent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          borderRadius: BorderRadius.circular(4),
                          onTap: () => _showEditProviderDialog(context, p, l10n),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Text(
                              hasKey ? '●●●●●●●●' : l10n.enterApiKeyHint,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Divider(height: 20),

                    // Models list header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.modelsCount(p.models.length),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          ),
                          onPressed: () => _showAddModelDialog(context, p, l10n),
                          icon: const Icon(Icons.add, size: 14),
                          label: Text(l10n.addModel, style: const TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Models
                    ...p.models.map((m) {
                      final isModelActive = (p.id == _activeProviderId && m.id == _activeModelId);

                      return InkWell(
                        onTap: () => _setActiveModel(p, m),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: isModelActive
                                ? theme.colorScheme.primary.withValues(alpha: 0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isModelActive
                                  ? theme.colorScheme.primary.withValues(alpha: 0.5)
                                  : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isModelActive ? Icons.radio_button_checked : Icons.radio_button_off,
                                size: 18,
                                color: isModelActive ? theme.colorScheme.primary : Colors.white38,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            m.name,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isModelActive ? FontWeight.bold : FontWeight.w500,
                                              color: isModelActive ? theme.colorScheme.primary : null,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (m.supportsThinking) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.purple.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'Thinking',
                                              style: TextStyle(fontSize: 9, color: Colors.purpleAccent),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      m.id,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (p.models.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.close, size: 16),
                                  tooltip: l10n.deleteModel,
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _confirmDeleteModel(context, p, m, l10n),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

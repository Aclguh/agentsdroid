import 'package:flutter/material.dart';
import '../../core/proot/proot_manager.dart';
import '../../core/storage/key_vault.dart';
import '../../l10n/app_localizations.dart';

class SubsystemTerminalScreen extends StatefulWidget {
  final PRootManager prootManager;
  final KeyVault keyVault;

  const SubsystemTerminalScreen({
    super.key,
    required this.prootManager,
    required this.keyVault,
  });

  @override
  State<SubsystemTerminalScreen> createState() => _SubsystemTerminalScreenState();
}

class _SubsystemTerminalScreenState extends State<SubsystemTerminalScreen> {
  final _commandController = TextEditingController();
  final _scrollController = ScrollController();
  final List<String> _logs = [];

  bool _isExecuting = false;
  ToolchainStatus? _toolchainStatus;

  @override
  void initState() {
    super.initState();
    _checkToolchains();
    _logs.add('=== AgentsDroid PRoot Subsystem Terminal ===');
    _logs.add('Workspace mounted at: /workspace');
    _logs.add('Type commands below to execute in the Linux sandbox.\n');
  }

  Future<void> _checkToolchains() async {
    final status = await widget.prootManager.checkToolchains();
    if (mounted) {
      setState(() {
        _toolchainStatus = status;
      });
    }
  }

  Future<void> _executeCommand([String? overrideCmd]) async {
    final cmd = overrideCmd ?? _commandController.text.trim();
    if (cmd.isEmpty || _isExecuting) return;

    _commandController.clear();

    setState(() {
      _isExecuting = true;
      _logs.add('\$ $cmd');
    });
    _scrollToBottom();

    final isInstalled = await widget.prootManager.isInstalled();
    if (!isInstalled) {
      setState(() {
        _logs.add('Error: Linux subsystem is not installed yet. Please install it in Settings.\n');
        _isExecuting = false;
      });
      _scrollToBottom();
      return;
    }

    try {
      final env = await widget.keyVault.exportEnvironmentVariables();
      await widget.prootManager.runStreamingCommand(
        cmd,
        workingDir: '/workspace',
        environment: env,
        onOutput: (chunk) {
          if (mounted) {
            setState(() {
              _logs.add(chunk);
            });
            _scrollToBottom();
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _logs.add('Execution failed: $e\n');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExecuting = false;
        });
        _scrollToBottom();
        _checkToolchains();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _commandController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isReady = widget.prootManager.currentStatus == PRootStatus.ready;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.terminalTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.refresh,
            onPressed: () {
              _checkToolchains();
              _logs.add('[Refreshed toolchain status]');
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: l10n.clearLog,
            onPressed: () {
              setState(() {
                _logs.clear();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Subsystem not installed warning banner
          if (!isReady)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.amber.withValues(alpha: 0.15),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.notInstalledWarning,
                      style: const TextStyle(color: Colors.amber, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          // Toolchains Status Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: theme.colorScheme.surface,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildToolchainChip(
                    name: 'Node.js',
                    version: _toolchainStatus?.nodeVersion,
                  ),
                  const SizedBox(width: 8),
                  _buildToolchainChip(
                    name: 'Python',
                    version: _toolchainStatus?.pythonVersion,
                  ),
                  const SizedBox(width: 8),
                  _buildToolchainChip(
                    name: 'Git',
                    version: _toolchainStatus?.gitVersion,
                  ),
                  const SizedBox(width: 8),
                  _buildToolchainChip(
                    name: 'Claude CLI',
                    version: _toolchainStatus?.claudeCodeVersion,
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1, color: Colors.white12),

          // Quick Commands Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: const Color(0xFF141414),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(
                    '${l10n.quickCommands}: ',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  _buildQuickCommandChip('uname -a'),
                  _buildQuickCommandChip('cat /etc/os-release'),
                  _buildQuickCommandChip('ls -la /workspace'),
                  _buildQuickCommandChip('git status'),
                  _buildQuickCommandChip('python3 main.py'),
                ],
              ),
            ),
          ),

          // Terminal Output Stream Area
          Expanded(
            child: Container(
              color: const Color(0xFF0C0C0C),
              padding: const EdgeInsets.all(12),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final line = _logs[index];
                  final isCmd = line.startsWith('\$ ');
                  final isError = line.toLowerCase().contains('error') || line.toLowerCase().contains('failed');

                  return SelectableText(
                    line,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.4,
                      color: isCmd
                          ? Colors.greenAccent
                          : (isError ? Colors.redAccent : Colors.white70),
                    ),
                  );
                },
              ),
            ),
          ),

          // Command Input Bar
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF181818),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
            ),
            child: Row(
              children: [
                const Text(
                  '\$ ',
                  style: TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                ),
                Expanded(
                  child: TextField(
                    controller: _commandController,
                    style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
                    decoration: InputDecoration(
                      hintText: l10n.commandHint,
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: (_) => _executeCommand(),
                  ),
                ),
                const SizedBox(width: 8),
                _isExecuting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.greenAccent),
                      )
                    : IconButton(
                        icon: const Icon(Icons.send, size: 20, color: Colors.greenAccent),
                        onPressed: _executeCommand,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolchainChip({required String name, String? version}) {
    final isInstalled = version != null && version.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isInstalled
            ? Colors.green.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isInstalled
              ? Colors.green.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isInstalled ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 13,
            color: isInstalled ? Colors.greenAccent : Colors.white38,
          ),
          const SizedBox(width: 5),
          Text(
            name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isInstalled ? Colors.white : Colors.white60,
            ),
          ),
          if (isInstalled) ...[
            const SizedBox(width: 4),
            Text(
              version.split(' ').first,
              style: const TextStyle(fontSize: 10, color: Colors.greenAccent, fontFamily: 'monospace'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickCommandChip(String cmd) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(cmd, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
        visualDensity: VisualDensity.compact,
        backgroundColor: const Color(0xFF242424),
        side: BorderSide.none,
        onPressed: () => _executeCommand(cmd),
      ),
    );
  }
}

import 'dart:async';
import '../../models/agent_event.dart';
import '../builtin/builtin_agent_engine.dart';
import '../cli/claude_code_adapter.dart';
import '../proot/proot_manager.dart';
import '../storage/key_vault.dart';
import '../storage/workspace_service.dart';
import 'agent_engine.dart';

enum AgentEngineType {
  builtin,
  claudeCode,
}

class EngineCheckResult {
  final bool isReady;
  final String? issueTitle;
  final String? issueDetail;
  final bool canAutoFix;

  const EngineCheckResult({
    required this.isReady,
    this.issueTitle,
    this.issueDetail,
    this.canAutoFix = false,
  });

  static const ready = EngineCheckResult(isReady: true);
}

/// Coordinates between BuiltinAgentEngine and official CLI adapters like ClaudeCodeAdapter.
class EngineCoordinator implements AgentEngine {
  final KeyVault keyVault;
  final WorkspaceService workspace;
  final PRootManager prootManager;

  final _eventController = StreamController<AgentEvent>.broadcast();
  @override
  Stream<AgentEvent> get eventStream => _eventController.stream;

  late AgentEngineType _currentEngineType;
  AgentEngineType get currentEngineType => _currentEngineType;

  late AgentEngine _activeEngine;
  AgentEngine get activeEngine => _activeEngine;

  StreamSubscription<AgentEvent>? _activeSubscription;

  EngineCoordinator({
    required this.keyVault,
    required this.workspace,
    required this.prootManager,
  }) {
    final savedEngine = keyVault.getSelectedEngine();
    if (savedEngine == 'claudeCode') {
      _currentEngineType = AgentEngineType.claudeCode;
    } else {
      _currentEngineType = AgentEngineType.builtin;
    }

    _activeEngine = _createEngine(_currentEngineType);
    _forwardEvents();
  }

  @override
  AgentState get currentState => _activeEngine.currentState;

  AgentEngine _createEngine(AgentEngineType type) {
    switch (type) {
      case AgentEngineType.builtin:
        return BuiltinAgentEngine(
          keyVault,
          workspace,
          prootManager: prootManager,
        );
      case AgentEngineType.claudeCode:
        return ClaudeCodeAdapter(
          prootManager: prootManager,
          keyVault: keyVault,
          workspaceService: workspace,
        );
    }
  }

  void _forwardEvents() {
    _activeSubscription?.cancel();
    _activeSubscription = _activeEngine.eventStream.listen((event) {
      _eventController.add(event);
    });
  }

  /// Check whether an engine is ready to run, or what dependencies are missing
  Future<EngineCheckResult> checkEngineReadiness(AgentEngineType type) async {
    if (type == AgentEngineType.builtin) {
      final provider = keyVault.getActiveProvider();
      final key = await keyVault.getApiKey(provider);
      if (key == null || key.isEmpty) {
        return EngineCheckResult(
          isReady: false,
          issueTitle: '未配置 ${provider.displayName} API Key',
          issueDetail: '请前往设置填入 API Key 即可使用内置 Agent。',
        );
      }
      return EngineCheckResult.ready;
    } else if (type == AgentEngineType.claudeCode) {
      final isSubsystemInstalled = await prootManager.isInstalled();
      if (!isSubsystemInstalled) {
        return const EngineCheckResult(
          isReady: false,
          issueTitle: '未安装 Linux 子系统',
          issueDetail: '官方 Claude Code 运行在嵌入式 Debian-arm64 环境内，请前往子系统终端下载安装。',
          canAutoFix: false,
        );
      }

      final toolchains = await prootManager.checkToolchains();
      if (!toolchains.hasNode) {
        return const EngineCheckResult(
          isReady: false,
          issueTitle: '未安装 Node.js 环境',
          issueDetail: 'Claude Code 依赖 Node.js 运行时，可在子系统终端中安装 (apt install nodejs npm)。',
          canAutoFix: true,
        );
      }

      final anthropicKey = await keyVault.getAnthropicApiKey();
      if (anthropicKey == null || anthropicKey.isEmpty) {
        return const EngineCheckResult(
          isReady: false,
          issueTitle: '未配置 Anthropic API Key',
          issueDetail: '官方 Claude Code 需要 Anthropic API Key 驱动，请前往设置配置。',
        );
      }

      return EngineCheckResult.ready;
    }
    return EngineCheckResult.ready;
  }

  /// Switch the active engine
  Future<void> switchEngine(AgentEngineType type) async {
    if (_currentEngineType == type) return;

    // Interrupt previous engine if running
    await _activeEngine.interrupt();
    await _activeSubscription?.cancel();
    await _activeEngine.dispose();

    _currentEngineType = type;
    await keyVault.setSelectedEngine(type.name);

    _activeEngine = _createEngine(type);
    _forwardEvents();

    _eventController.add(StatusEvent(
      AgentState.idle,
      message: '已切换至 ${type == AgentEngineType.builtin ? "内置轻量 Agent" : "官方 Claude Code CLI"}',
    ));
  }

  @override
  Future<void> startTask(String prompt) async {
    return await _activeEngine.startTask(prompt);
  }

  @override
  Future<void> respondApproval(String toolCallId, bool approved, {String? reason}) async {
    return await _activeEngine.respondApproval(toolCallId, approved, reason: reason);
  }

  @override
  Future<void> interrupt() async {
    return await _activeEngine.interrupt();
  }

  @override
  Future<void> dispose() async {
    await _activeSubscription?.cancel();
    await _activeEngine.dispose();
    await _eventController.close();
  }
}

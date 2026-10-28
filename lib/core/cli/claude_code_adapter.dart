import 'dart:async';
import 'dart:io';

import '../../models/agent_event.dart';
import '../../models/chat_message.dart';
import '../agent/agent_engine.dart';
import '../errors/app_exceptions.dart';
import '../proot/proot_manager.dart';
import '../storage/key_vault.dart';
import '../storage/workspace_service.dart';
import 'ansi_stream_parser.dart';

/// Adapter for running official Claude Code CLI (@anthropic-ai/claude-code) inside PRoot Linux subsystem.
class ClaudeCodeAdapter implements AgentEngine {
  final PRootManager prootManager;
  final KeyVault keyVault;
  final WorkspaceService workspaceService;

  final _eventController = StreamController<AgentEvent>.broadcast();
  @override
  Stream<AgentEvent> get eventStream => _eventController.stream;

  AgentState _currentState = AgentState.idle;
  @override
  AgentState get currentState => _currentState;

  PRootProcess? _activeProcess;
  AnsiStreamParser? _parser;
  StreamSubscription<AgentEvent>? _parserSubscription;
  bool _isInterrupted = false;

  ClaudeCodeAdapter({
    required this.prootManager,
    required this.keyVault,
    required this.workspaceService,
  });

  @override
  Future<void> startTask(String prompt, {List<ChatMessage>? priorMessages}) async {
    if (_currentState != AgentState.idle && _currentState != AgentState.completed && _currentState != AgentState.error) {
      throw StateError('Agent is already running a task.');
    }

    _updateState(AgentState.thinking, message: 'Preparing Claude Code CLI environment...');

    // 1. Verify subsystem installation
    final isInstalled = await prootManager.isInstalled();
    if (!isInstalled) {
      final ex = const SubsystemNotInstalledException();
      final lang = keyVault.getLanguage();
      final msg = ex.toLocalizedMessage(languageCode: lang);
      _updateState(AgentState.error, message: msg);
      _eventController.add(MessageEvent(
        text: msg,
        isComplete: true,
      ));
      return;
    }

    // 2. Prepare API Key and Environment
    final env = <String, String>{};
    final apiKey = await keyVault.getAnthropicApiKey();
    if (apiKey != null && apiKey.isNotEmpty) {
      env['ANTHROPIC_API_KEY'] = apiKey;
    }

    final customBaseUrl = keyVault.getCustomBaseUrl();
    if (customBaseUrl.isNotEmpty) {
      env['ANTHROPIC_BASE_URL'] = customBaseUrl;
    }

    // 3. Setup ANSI Stream Parser
    await _cleanupActiveSession();
    _parser = AnsiStreamParser();
    _parserSubscription = _parser!.eventStream.listen((event) {
      if (event is StatusEvent) {
        _currentState = event.state;
      }
      _eventController.add(event);
    });

    try {
      _isInterrupted = false;
      _updateState(AgentState.thinking, message: 'Starting Claude Code CLI session...');

      // Execute safely passing prompt as positional argument without shell interpolation
      _activeProcess = await prootManager.startProcessArgs(
        [
          'sh',
          '-c',
          'command -v claude >/dev/null 2>&1 && exec claude -p "\$1" || exec npx @anthropic-ai/claude-code -p "\$1"',
          'sh',
          prompt,
        ],
        environment: env,
        workingDir: '/workspace',
      );

      // Listen to stdout and stderr
      _activeProcess!.stdout.listen(
        (chunk) => _parser?.feedChunk(chunk),
        onError: (err) {
          _eventController.add(MessageEvent(text: 'Process stdout error: $err', isComplete: false));
        },
      );

      _activeProcess!.stderr.listen(
        (chunk) => _parser?.feedChunk(chunk),
        onError: (err) {
          _eventController.add(MessageEvent(text: 'Process stderr error: $err', isComplete: false));
        },
      );

      // Wait for process exit in background
      _activeProcess!.exitCode.then((exitCode) {
        if (_isInterrupted) return;
        _parser?.flush();
        if (exitCode == 0) {
          _updateState(AgentState.completed, message: 'Claude Code completed successfully.');
          _eventController.add(MessageEvent(text: '\n[Claude Code 已成功完成任务]', isComplete: true));
        } else {
          _updateState(AgentState.error, message: 'Process exited with code $exitCode');
          _eventController.add(MessageEvent(text: '\n[Claude Code 退出，退出码: $exitCode]', isComplete: true));
        }
        _cleanupActiveSession();
      }).catchError((err) {
        if (_isInterrupted) return;
        _updateState(AgentState.error, message: 'Process error: $err');
        _cleanupActiveSession();
      });
    } catch (e, st) {
      final appEx = AppException.from(e, stackTrace: st, providerName: 'Anthropic');
      final lang = keyVault.getLanguage();
      final errorMsg = appEx.toLocalizedMessage(languageCode: lang);
      _updateState(AgentState.error, message: 'Failed to start Claude Code CLI: $e');
      _eventController.add(MessageEvent(
        text: '$errorMsg\n${lang == 'zh' ? '提示：请确认子系统内已安装 Node.js 及 @anthropic-ai/claude-code。' : 'Note: Please ensure Node.js and @anthropic-ai/claude-code are installed in the subsystem.'}',
        isComplete: true,
      ));
      await _cleanupActiveSession();
    }
  }

  @override
  Future<void> respondApproval(String toolCallId, bool approved, {String? reason}) async {
    if (_activeProcess == null) {
      return;
    }

    final input = approved ? 'y\n' : 'n\n';
    _activeProcess!.stdin.write(input);
    await _activeProcess!.stdin.flush();

    final args = <String, dynamic>{'approved': approved};
    if (reason != null) {
      args['reason'] = reason;
    }

    _updateState(AgentState.executingTool, message: approved ? 'Tool approved by user' : 'Tool rejected by user');
    _eventController.add(ToolCallEvent(
      toolCallId: toolCallId,
      toolName: 'approval_response',
      arguments: args,
      status: approved ? ToolCallStatus.approved : ToolCallStatus.rejected,
      autoApproved: false,
    ));
  }

  @override
  Future<void> interrupt() async {
    _isInterrupted = true;
    if (_activeProcess != null) {
      try {
        _activeProcess!.kill(ProcessSignal.sigint);
      } catch (_) {
        _activeProcess!.kill(ProcessSignal.sigterm);
      }
      _updateState(AgentState.idle, message: 'Claude Code CLI interrupted by user.');
      _eventController.add(MessageEvent(text: '\n[已中止任务执行]', isComplete: true));
      await _cleanupActiveSession();
    }
  }

  void _updateState(AgentState state, {String? message}) {
    _currentState = state;
    _eventController.add(StatusEvent(state, message: message));
  }

  Future<void> _cleanupActiveSession() async {
    await _parserSubscription?.cancel();
    _parserSubscription = null;
    _parser?.dispose();
    _parser = null;
    _activeProcess = null;
  }

  @override
  void resetSession() {
    _isInterrupted = true;
    if (_activeProcess != null) {
      try {
        _activeProcess!.kill(ProcessSignal.sigint);
      } catch (_) {}
    }
    _cleanupActiveSession();
    _updateState(AgentState.idle);
  }

  @override
  Future<void> dispose() async {
    await interrupt();
    await _cleanupActiveSession();
    await _eventController.close();
  }
}

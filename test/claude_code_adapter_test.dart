import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agentsdroid/core/cli/claude_code_adapter.dart';
import 'package:agentsdroid/core/proot/proot_manager.dart';
import 'package:agentsdroid/core/storage/key_vault.dart';
import 'package:agentsdroid/core/storage/workspace_service.dart';
import 'package:agentsdroid/models/agent_event.dart';

class FakeProcess implements Process {
  final Completer<int> _exitCodeCompleter = Completer<int>();
  final StreamController<List<int>> _stdoutController = StreamController<List<int>>();
  final StreamController<List<int>> _stderrController = StreamController<List<int>>();
  late final IOSink _stdinSink;

  bool killed = false;
  ProcessSignal? lastSignal;
  final List<String> writtenStdin = [];

  FakeProcess() {
    final consumer = _TestStreamConsumer((data) {
      writtenStdin.add(utf8.decode(data));
    });
    _stdinSink = IOSink(consumer);
  }

  @override
  int get pid => 12345;

  @override
  Future<int> get exitCode => _exitCodeCompleter.future;

  @override
  IOSink get stdin => _stdinSink;

  @override
  Stream<List<int>> get stdout => _stdoutController.stream;

  @override
  Stream<List<int>> get stderr => _stderrController.stream;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    lastSignal = signal;
    if (!_exitCodeCompleter.isCompleted) {
      _exitCodeCompleter.complete(-1);
    }
    return true;
  }

  void completeProcess(int code) {
    if (!_exitCodeCompleter.isCompleted) {
      _exitCodeCompleter.complete(code);
    }
  }

  void addStdout(String text) {
    _stdoutController.add(utf8.encode(text));
  }

  void addStderr(String text) {
    _stderrController.add(utf8.encode(text));
  }
}

class _TestStreamConsumer implements StreamConsumer<List<int>> {
  final void Function(List<int>) onData;
  _TestStreamConsumer(this.onData);

  @override
  Future addStream(Stream<List<int>> stream) async {
    await for (final data in stream) {
      onData(data);
    }
  }

  @override
  Future close() async {}
}

class FakePRootManager extends PRootManager {
  bool isInstalledValue = true;
  FakeProcess? nextProcess;
  List<String>? lastCommandArgs;
  Map<String, String>? lastEnvironment;
  String? lastWorkingDir;
  bool shouldThrowOnStart = false;

  @override
  Future<bool> isInstalled() async => isInstalledValue;

  @override
  Future<PRootProcess> startProcessArgs(
    List<String> commandArgs, {
    Map<String, String>? environment,
    String? workingDir,
  }) async {
    if (shouldThrowOnStart) {
      throw const SocketException('PRoot engine spawn failed');
    }

    lastCommandArgs = commandArgs;
    lastEnvironment = environment;
    lastWorkingDir = workingDir;

    final proc = nextProcess ?? FakeProcess();
    final stdoutStream = proc.stdout.transform(utf8.decoder).asBroadcastStream();
    final stderrStream = proc.stderr.transform(utf8.decoder).asBroadcastStream();

    return PRootProcess(
      process: proc,
      stdout: stdoutStream,
      stderr: stderrStream,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late KeyVault keyVault;
  late WorkspaceService workspace;
  late FakePRootManager fakePRoot;
  late ClaudeCodeAdapter adapter;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    const secureStorage = FlutterSecureStorage();
    keyVault = KeyVault(secureStorage, prefs);

    tempDir = await Directory.systemTemp.createTemp('claude_adapter_test_');
    workspace = WorkspaceService();
    await workspace.init(baseDir: tempDir);

    fakePRoot = FakePRootManager();
    adapter = ClaudeCodeAdapter(
      prootManager: fakePRoot,
      keyVault: keyVault,
      workspaceService: workspace,
    );
  });

  tearDown(() async {
    await adapter.dispose();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ClaudeCodeAdapter Tests', () {
    test('startTask fails with localized error when subsystem not installed', () async {
      fakePRoot.isInstalledValue = false;
      await keyVault.setLanguage('zh');

      final events = <AgentEvent>[];
      adapter.eventStream.listen(events.add);

      await adapter.startTask('Hello Claude');
      await Future.delayed(const Duration(milliseconds: 50));

      expect(adapter.currentState, equals(AgentState.error));
      expect(events.whereType<StatusEvent>().any((e) => e.state == AgentState.error), isTrue);
      expect(events.whereType<MessageEvent>().any((e) => e.text.contains('Linux 子系统尚未安装')), isTrue);
    });

    test('startTask passes API key and prompt correctly and handles success', () async {
      fakePRoot.isInstalledValue = true;
      await keyVault.setApiKey(LLMProvider.anthropic, 'sk-ant-test-key-12345');
      await keyVault.setCustomBaseUrl('https://custom.anthropic.api');

      final fakeProc = FakeProcess();
      fakePRoot.nextProcess = fakeProc;

      final events = <AgentEvent>[];
      adapter.eventStream.listen(events.add);

      await adapter.startTask('Create a Flutter counter app');
      await Future.delayed(const Duration(milliseconds: 20));

      // Verify environment and arguments
      expect(fakePRoot.lastEnvironment?['ANTHROPIC_API_KEY'], equals('sk-ant-test-key-12345'));
      expect(fakePRoot.lastEnvironment?['ANTHROPIC_BASE_URL'], equals('https://custom.anthropic.api'));
      expect(fakePRoot.lastCommandArgs, contains('Create a Flutter counter app'));
      expect(fakePRoot.lastWorkingDir, equals('/workspace'));

      // Simulate output and exit
      fakeProc.addStdout('Thinking about counter implementation...\n');
      await Future.delayed(const Duration(milliseconds: 20));

      fakeProc.completeProcess(0);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(adapter.currentState, equals(AgentState.completed));
      expect(events.whereType<MessageEvent>().any((e) => e.text.contains('已成功完成任务')), isTrue);
    });

    test('startTask throws StateError if already running', () async {
      final fakeProc = FakeProcess();
      fakePRoot.nextProcess = fakeProc;

      await adapter.startTask('Task 1');
      expect(adapter.currentState, isNot(equals(AgentState.idle)));

      expect(() => adapter.startTask('Task 2'), throwsA(isA<StateError>()));
    });

    test('startTask handles non-zero exit code as error', () async {
      final fakeProc = FakeProcess();
      fakePRoot.nextProcess = fakeProc;

      final events = <AgentEvent>[];
      adapter.eventStream.listen(events.add);

      await adapter.startTask('Crashing Task');
      await Future.delayed(const Duration(milliseconds: 20));

      fakeProc.addStderr('Fatal error in Claude CLI\n');
      fakeProc.completeProcess(127);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(adapter.currentState, equals(AgentState.error));
      expect(events.whereType<MessageEvent>().any((e) => e.text.contains('退出码: 127')), isTrue);
    });

    test('startTask handles process spawn failure gracefully', () async {
      fakePRoot.shouldThrowOnStart = true;
      final events = <AgentEvent>[];
      adapter.eventStream.listen(events.add);

      await adapter.startTask('Failing Task');
      await Future.delayed(const Duration(milliseconds: 50));

      expect(adapter.currentState, equals(AgentState.error));
      expect(events.whereType<StatusEvent>().any((e) => e.message?.contains('Failed to start Claude Code CLI') == true), isTrue);
    });

    test('respondApproval delivers y/n to process stdin and emits event', () async {
      final fakeProc = FakeProcess();
      fakePRoot.nextProcess = fakeProc;

      final events = <AgentEvent>[];
      adapter.eventStream.listen(events.add);

      await adapter.startTask('Task requesting permission');
      await Future.delayed(const Duration(milliseconds: 20));

      // Approve
      await adapter.respondApproval('call_tool_1', true, reason: 'Approved by user');
      await Future.delayed(const Duration(milliseconds: 20));
      expect(fakeProc.writtenStdin, contains('y\n'));
      expect(adapter.currentState, equals(AgentState.executingTool));
      expect(events.whereType<ToolCallEvent>().any((e) => e.status == ToolCallStatus.approved), isTrue);

      // Reject
      await adapter.respondApproval('call_tool_2', false, reason: 'Deny permission');
      await Future.delayed(const Duration(milliseconds: 20));
      expect(fakeProc.writtenStdin, contains('n\n'));
      expect(events.whereType<ToolCallEvent>().any((e) => e.status == ToolCallStatus.rejected), isTrue);
    });

    test('interrupt terminates process with SIGINT and sets idle state', () async {
      final fakeProc = FakeProcess();
      fakePRoot.nextProcess = fakeProc;

      await adapter.startTask('Long running task');
      await Future.delayed(const Duration(milliseconds: 20));

      await adapter.interrupt();
      expect(fakeProc.killed, isTrue);
      expect(adapter.currentState, equals(AgentState.idle));
    });

    test('resetSession kills active process and resets state', () async {
      final fakeProc = FakeProcess();
      fakePRoot.nextProcess = fakeProc;

      await adapter.startTask('Task to reset');
      await Future.delayed(const Duration(milliseconds: 20));

      adapter.resetSession();
      expect(fakeProc.killed, isTrue);
      expect(adapter.currentState, equals(AgentState.idle));
    });
  });
}

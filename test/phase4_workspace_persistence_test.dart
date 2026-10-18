import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:agentsdroid/core/notification/foreground_service_manager.dart';
import 'package:agentsdroid/core/storage/workspace_service.dart';
import 'package:agentsdroid/models/agent_event.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory docDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('agentsdroid_test_temp_');
    docDir = await Directory.systemTemp.createTemp('agentsdroid_test_docs_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
    if (await docDir.exists()) await docDir.delete(recursive: true);
  });

  group('WorkspaceService Eco Tests', () {
    test('initializes workspace and exports zip archive', () async {
      final service = WorkspaceService();
      await service.init(baseDir: docDir);

      expect(await File(service.resolvePath('README.md')).exists(), isTrue);
      expect(await File(service.resolvePath('main.py')).exists(), isTrue);

      // Create a test file
      await service.writeFile('src/test.py', 'print("test")');
      expect(await service.readFile('src/test.py'), equals('print("test")'));

      // Export Zip
      final zip = await service.exportWorkspaceZip(customTargetDir: tempDir.path);
      expect(await zip.exists(), isTrue);
      expect(zip.path.endsWith('.zip'), isTrue);
      expect(await zip.length(), greaterThan(0));
    });

    test('creates and verifies directory structure', () async {
      final service = WorkspaceService();
      await service.init(baseDir: docDir);

      await service.createDirectory('nested/folder/path');
      final dir = Directory(service.resolvePath('nested/folder/path'));
      expect(await dir.exists(), isTrue);
    });

    test('supports multi-project creation, listing, and switching', () async {
      final service = WorkspaceService();
      await service.init(baseDir: docDir);

      // Initially default project 'agentsdroid' exists
      expect(await service.listProjects(), contains('agentsdroid'));
      expect(service.currentProjectName, equals('agentsdroid'));

      // Create a new project
      await service.createProject('my-mobile-app');
      final projDir = Directory('${service.workspacesRootDir.path}/my-mobile-app');
      expect(await projDir.exists(), isTrue);
      // New projects should not automatically create README.md
      expect(await File('${projDir.path}/README.md').exists(), isFalse);

      final projects = await service.listProjects();
      expect(projects, contains('my-mobile-app'));

      // Switch to project
      await service.switchProject('my-mobile-app');
      expect(service.currentProjectName, equals('my-mobile-app'));
      expect(service.workspaceDir.path.endsWith('my-mobile-app'), isTrue);

      // Switch back
      await service.switchProject('agentsdroid');
      expect(service.currentProjectName, equals('agentsdroid'));
    });
  });

  group('ForegroundServiceManager Tests', () {
    test('binds agent events and transitions lifecycle states', () async {
      final manager = ForegroundServiceManager();
      final states = <ForegroundNotificationState>[];
      final sub = manager.stateStream.listen(states.add);

      expect(manager.currentState.level, equals(ForegroundTaskLevel.idle));
      expect(manager.isWakeLockActive, isFalse);

      manager.startTask('Analyze project architecture');
      expect(manager.currentState.level, equals(ForegroundTaskLevel.running));
      expect(manager.isWakeLockActive, isTrue);

      manager.updateProgress('Reviewing main.dart patch', waitingApproval: true);
      expect(manager.currentState.level, equals(ForegroundTaskLevel.urgentApproval));

      manager.finishTask(success: true, message: 'All done');
      expect(manager.currentState.level, equals(ForegroundTaskLevel.completed));
      expect(manager.isWakeLockActive, isFalse);

      await sub.cancel();
      manager.dispose();
    });

    test('binds stream events from status event', () async {
      final manager = ForegroundServiceManager();
      final streamController = StreamController<AgentEvent>.broadcast();
      final sub = manager.bindAgentEvents(streamController.stream);

      streamController.add(StatusEvent(AgentState.thinking, message: 'Thinking...'));
      await Future.delayed(const Duration(milliseconds: 10));
      expect(manager.currentState.level, equals(ForegroundTaskLevel.running));
      expect(manager.isWakeLockActive, isTrue);

      streamController.add(StatusEvent(AgentState.waitingApproval, message: 'Allow tool'));
      await Future.delayed(const Duration(milliseconds: 10));
      expect(manager.currentState.level, equals(ForegroundTaskLevel.urgentApproval));

      streamController.add(StatusEvent(AgentState.completed, message: 'Finished'));
      await Future.delayed(const Duration(milliseconds: 10));
      expect(manager.currentState.level, equals(ForegroundTaskLevel.completed));
      expect(manager.isWakeLockActive, isFalse);

      await sub.cancel();
      manager.dispose();
      await streamController.close();
    });
  });
}

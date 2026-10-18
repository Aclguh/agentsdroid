import 'package:flutter_test/flutter_test.dart';
import 'package:agentsdroid/core/agent/engine_coordinator.dart';
import 'package:agentsdroid/core/proot/proot_manager.dart';
import 'package:agentsdroid/core/storage/key_vault.dart';
import 'package:agentsdroid/core/storage/workspace_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EngineCoordinator Tests', () {
    late KeyVault keyVault;
    late WorkspaceService workspace;
    late PRootManager prootManager;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      const secureStorage = FlutterSecureStorage();
      final prefs = await SharedPreferences.getInstance();
      keyVault = KeyVault(secureStorage, prefs);
      workspace = WorkspaceService();
      prootManager = PRootManager();
    });

    test('default engine is builtin and switches properly', () async {
      final coordinator = EngineCoordinator(
        keyVault: keyVault,
        workspace: workspace,
        prootManager: prootManager,
      );

      expect(coordinator.currentEngineType, equals(AgentEngineType.builtin));

      await coordinator.switchEngine(AgentEngineType.claudeCode);
      expect(coordinator.currentEngineType, equals(AgentEngineType.claudeCode));
      expect(keyVault.getSelectedEngine(), equals('claudeCode'));

      await coordinator.dispose();
    });

    test('readiness check catches missing API Key or Subsystem', () async {
      final coordinator = EngineCoordinator(
        keyVault: keyVault,
        workspace: workspace,
        prootManager: prootManager,
      );

      final builtinCheck = await coordinator.checkEngineReadiness(AgentEngineType.builtin);
      expect(builtinCheck.isReady, isFalse);
      expect(builtinCheck.issueTitle, contains('API Key'));

      final claudeCheck = await coordinator.checkEngineReadiness(AgentEngineType.claudeCode);
      expect(claudeCheck.isReady, isFalse);
      expect(claudeCheck.issueTitle, contains('Linux 子系统'));

      await coordinator.dispose();
    });
  });
}

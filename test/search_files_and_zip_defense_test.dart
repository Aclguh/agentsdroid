import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agentsdroid/core/builtin/builtin_agent_engine.dart';
import 'package:agentsdroid/core/storage/key_vault.dart';
import 'package:agentsdroid/core/storage/workspace_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late WorkspaceService workspace;
  late KeyVault keyVault;
  late BuiltinAgentEngine engine;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    const secureStorage = FlutterSecureStorage();
    keyVault = KeyVault(secureStorage, prefs);
    await keyVault.setApprovalMode(ApprovalMode.yolo);

    tempDir = await Directory.systemTemp.createTemp('search_zip_test_');
    workspace = WorkspaceService();
    await workspace.init(baseDir: tempDir);

    engine = BuiltinAgentEngine(
      keyVault,
      workspace,
    );
  });

  tearDown(() async {
    engine.dispose();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('search_files memory defense and filtering tests', () {
    test('search_files finds keywords recursively and respects filters', () async {
      // 1. Normal text file in root
      await workspace.writeFile('main.dart', 'void main() { print("Hello World"); }');

      // 2. Nested file in subfolder
      await workspace.writeFile('lib/utils/helper.dart', '// Helper function for greeting\nString greet() => "Hello";');

      // 3. File in .git directory (should be ignored)
      final gitDir = Directory('${workspace.workspacePath}/.git');
      await gitDir.create(recursive: true);
      await File('${gitDir.path}/config').writeAsString('Hello from git config');

      // 4. File in node_modules (should be ignored)
      final nmDir = Directory('${workspace.workspacePath}/node_modules/pkg');
      await nmDir.create(recursive: true);
      await File('${nmDir.path}/index.js').writeAsString('Hello from node module');

      // 5. Binary file containing arbitrary bytes (should not crash decoder)
      final binFile = File('${workspace.workspacePath}/image.png');
      await binFile.writeAsBytes([0x89, 0x50, 0x4E, 0x47, 0x00, 0xFF, 0xFE, 0xFD]);

      // 6. Large file (> 2MB)
      final largeFile = File('${workspace.workspacePath}/huge_log.txt');
      final sink = largeFile.openWrite();
      for (int i = 0; i < 30000; i++) {
        sink.writeln('Line $i: Hello from giant repetitive log stream that exceeds 2MB in total size!');
      }
      await sink.flush();
      await sink.close();
      expect(await largeFile.length(), greaterThan(2 * 1024 * 1024));

      // Test search for "Hello"
      String? results;
      await engine.handleToolExecutionForTesting(
        callId: 'call_search_1',
        toolName: 'search_files',
        arguments: {'query': 'Hello'},
        onResult: (res) => results = res,
      );
      expect(results, isNotNull);
      final matchPaths = results!;

      // Should find normal root & nested files
      expect(matchPaths.contains('main.dart'), isTrue);
      expect(matchPaths.contains('helper.dart'), isTrue);

      // Should NOT contain .git or node_modules
      expect(matchPaths.contains('.git'), isFalse);
      expect(matchPaths.contains('node_modules'), isFalse);

      // Should NOT contain large file (>2MB)
      expect(matchPaths.contains('huge_log.txt'), isFalse);

      // Should NOT contain binary file
      expect(matchPaths.contains('image.png'), isFalse);

      // Empty query returns empty list
      String? emptyResults;
      await engine.handleToolExecutionForTesting(
        callId: 'call_search_2',
        toolName: 'search_files',
        arguments: {'query': ''},
        onResult: (res) => emptyResults = res,
      );
      expect(emptyResults, contains('"output":[]'));
    });
  });

  group('exportWorkspaceZip streaming zip tests', () {
    test('streams zip archive and extracts correctly with ZipDecoder', () async {
      await workspace.writeFile('file1.txt', 'Content 1');
      await workspace.writeFile('dir/file2.txt', 'Content 2');

      final gitDir = Directory('${workspace.workspacePath}/.git');
      await gitDir.create(recursive: true);
      await File('${gitDir.path}/gitfile.txt').writeAsString('Git content');

      // Export without git
      final zipWithoutGit = await workspace.exportWorkspaceZip(
        customTargetDir: tempDir.path,
        includeGit: false,
      );
      expect(zipWithoutGit.existsSync(), isTrue);

      final bytes = await zipWithoutGit.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final fileNames = archive.map((e) => e.name).toList();
      expect(fileNames.any((n) => n.contains('file1.txt')), isTrue);
      expect(fileNames.any((n) => n.contains('file2.txt')), isTrue);
      expect(fileNames.any((n) => n.contains('.git')), isFalse);

      // Export with git
      final zipWithGit = await workspace.exportWorkspaceZip(
        customTargetDir: tempDir.path,
        includeGit: true,
      );
      final bytesGit = await zipWithGit.readAsBytes();
      final archiveGit = ZipDecoder().decodeBytes(bytesGit);
      final fileNamesGit = archiveGit.map((e) => e.name).toList();
      expect(fileNamesGit.any((n) => n.contains('.git')), isTrue);
    });
  });
}

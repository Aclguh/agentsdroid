import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../models/agent_event.dart';
import '../proot/proot_manager.dart';

class WorkspaceService {
  Directory? _workspacesRootDir;
  Directory? _workspaceDir;

  Future<void> init({Directory? baseDir}) async {
    final appDir = baseDir ?? await getApplicationDocumentsDirectory();
    _workspacesRootDir = Directory(p.join(appDir.path, 'workspace'));
    if (!await _workspacesRootDir!.exists()) {
      await _workspacesRootDir!.create(recursive: true);
    }

    final agentsdroidDir = Directory(p.join(_workspacesRootDir!.path, 'agentsdroid'));
    final defaultDir = Directory(p.join(_workspacesRootDir!.path, 'default_project'));

    if (await agentsdroidDir.exists()) {
      _workspaceDir = agentsdroidDir;
    } else if (await defaultDir.exists()) {
      _workspaceDir = defaultDir;
    } else {
      _workspaceDir = agentsdroidDir;
      await _workspaceDir!.create(recursive: true);
      await _createSampleProject();
    }
  }

  Directory get workspacesRootDir {
    if (_workspacesRootDir == null) {
      throw StateError('WorkspaceService not initialized. Call init() first.');
    }
    return _workspacesRootDir!;
  }

  Directory get workspaceDir {
    if (_workspaceDir == null) {
      throw StateError('WorkspaceService not initialized. Call init() first.');
    }
    return _workspaceDir!;
  }

  String get workspacePath => workspaceDir.path;

  String get currentProjectName => _workspaceDir != null ? p.basename(_workspaceDir!.path) : 'agentsdroid';

  Future<List<String>> listProjects() async {
    final root = workspacesRootDir;
    if (!await root.exists()) return ['agentsdroid'];

    final projects = <String>[];
    final entities = root.listSync();
    for (final e in entities) {
      if (e is Directory) {
        projects.add(p.basename(e.path));
      }
    }
    if (projects.isEmpty) {
      projects.add('agentsdroid');
    }
    projects.sort();
    return projects;
  }

  Future<void> switchProject(String projectName) async {
    final target = Directory(p.join(workspacesRootDir.path, projectName));
    if (!await target.exists()) {
      await target.create(recursive: true);
    }
    _workspaceDir = target;
  }

  Future<void> createProject(String projectName) async {
    final target = Directory(p.join(workspacesRootDir.path, projectName));
    if (!await target.exists()) {
      await target.create(recursive: true);
    }
  }

  // Resolves a relative or absolute path safely within the workspace
  String resolvePath(String relativeOrAbsolutePath) {
    if (p.isAbsolute(relativeOrAbsolutePath) && relativeOrAbsolutePath.startsWith(workspacePath)) {
      return relativeOrAbsolutePath;
    }
    final normalized = p.normalize(relativeOrAbsolutePath);
    return p.join(workspacePath, normalized);
  }

  Future<List<FileSystemEntity>> listFiles({String relativePath = ''}) async {
    final targetDir = Directory(resolvePath(relativePath));
    if (!await targetDir.exists()) {
      return [];
    }
    return targetDir.listSync(recursive: false);
  }

  Future<String> readFile(String relativePath) async {
    final file = File(resolvePath(relativePath));
    if (!await file.exists()) {
      throw FileSystemException('File not found', relativePath);
    }
    return await file.readAsString();
  }

  Future<void> writeFile(String relativePath, String content) async {
    final file = File(resolvePath(relativePath));
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsString(content);
  }

  Future<void> patchFile(String relativePath, String oldContent, String newContent) async {
    final file = File(resolvePath(relativePath));
    if (!await file.exists()) {
      throw FileSystemException('File not found', relativePath);
    }
    final current = await file.readAsString();
    if (!current.contains(oldContent)) {
      throw ArgumentError('The old content block to replace was not found in $relativePath');
    }
    final updated = current.replaceFirst(oldContent, newContent);
    await file.writeAsString(updated);
  }

  Future<void> deleteFile(String relativePath) async {
    final file = File(resolvePath(relativePath));
    if (await file.exists()) {
      await file.delete();
    }
  }

  // Generate unified diff model for review
  DiffEvent computeDiff(String relativePath, String originalContent, String newContent) {
    final origLines = originalContent.split('\n');
    final newLines = newContent.split('\n');
    final diffLines = <DiffLine>[];

    // Simple line-by-line diff generation
    int i = 0, j = 0;
    while (i < origLines.length || j < newLines.length) {
      if (i < origLines.length && j < newLines.length && origLines[i] == newLines[j]) {
        diffLines.add(DiffLine(
          type: DiffLineType.unchanged,
          text: origLines[i],
          oldLineNumber: i + 1,
          newLineNumber: j + 1,
        ));
        i++;
        j++;
      } else {
        if (i < origLines.length && (j >= newLines.length || !newLines.contains(origLines[i]))) {
          diffLines.add(DiffLine(
            type: DiffLineType.removed,
            text: origLines[i],
            oldLineNumber: i + 1,
          ));
          i++;
        } else if (j < newLines.length) {
          diffLines.add(DiffLine(
            type: DiffLineType.added,
            text: newLines[j],
            newLineNumber: j + 1,
          ));
          j++;
        }
      }
    }

    return DiffEvent(
      filePath: relativePath,
      originalContent: originalContent,
      newContent: newContent,
      diffLines: diffLines,
    );
  }

  Future<void> createDirectory(String relativePath) async {
    final dir = Directory(resolvePath(relativePath));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  /// Exports the workspace files as a .zip archive into app cache or external downloads
  Future<File> exportWorkspaceZip({String? customTargetDir, bool includeGit = false}) async {
    final targetDirectory = customTargetDir != null
        ? Directory(customTargetDir)
        : await getTemporaryDirectory();

    if (!await targetDirectory.exists()) {
      await targetDirectory.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final zipFile = File(p.join(targetDirectory.path, 'workspace_export_$timestamp.zip'));

    final archive = Archive();
    final entities = workspaceDir.listSync(recursive: true);

    for (final entity in entities) {
      if (entity is File) {
        final relPath = p.relative(entity.path, from: workspacePath);
        if (!includeGit && (relPath.startsWith('.git') || relPath.contains('/.git'))) {
          continue;
        }
        final bytes = await entity.readAsBytes();
        archive.addFile(ArchiveFile(relPath, bytes.length, bytes));
      }
    }

    final encoder = ZipEncoder();
    final zipBytes = encoder.encode(archive);
    await zipFile.writeAsBytes(zipBytes);
    return zipFile;
  }

  /// Clone external Git repository into workspace using subsystem git or dart shell
  Future<ProcessResult> cloneGitRepository(String repoUrl, PRootManager prootManager) async {
    final isInstalled = await prootManager.isInstalled();
    if (!isInstalled) {
      throw StateError('Linux Subsystem is required to clone git repositories.');
    }

    // Clone directly into /workspace
    return await prootManager.runCommand(
      'git clone $repoUrl .',
      workingDir: '/workspace',
    );
  }

  /// Get current Git branch and status
  Future<String> getGitStatus(PRootManager prootManager) async {
    if (!await prootManager.isInstalled()) {
      return 'Subsystem not installed';
    }
    final gitDir = Directory(p.join(workspacePath, '.git'));
    if (!await gitDir.exists()) {
      return 'Not a Git repository';
    }

    try {
      final res = await prootManager.runCommand('git status -s', workingDir: '/workspace');
      return res.stdout.toString().trim();
    } catch (e) {
      return 'Git error: $e';
    }
  }

  /// Commit changes via subsystem Git
  Future<ProcessResult> gitCommit(String message, PRootManager prootManager) async {
    if (!await prootManager.isInstalled()) {
      throw StateError('Linux Subsystem is required for git commit.');
    }
    final sanitizedMsg = message.replaceAll('"', '\\"');
    return await prootManager.runCommand(
      'git add . && git commit -m "$sanitizedMsg"',
      workingDir: '/workspace',
    );
  }

  Future<void> _createSampleProject() async {
    final readme = File(p.join(workspacePath, 'README.md'));
    if (!await readme.exists()) {
      await readme.writeAsString('''# Welcome to AgentsDroid!

This is your mobile coding workspace running entirely on Android.

### Features
- Native AI Agent support with direct tool calls
- In-app PRoot Linux environment support
- Safe file modification & review with native Diff cards

Try asking AgentsDroid:
"Please read the main.py file and add a function to calculate Fibonacci numbers."
''');
    }

    final mainPy = File(p.join(workspacePath, 'main.py'));
    if (!await mainPy.exists()) {
      await mainPy.writeAsString('''# AgentsDroid Mobile Workspace Demo
def greet(name: str):
    print(f"Hello, {name}! AgentsDroid is ready.")

if __name__ == "__main__":
    greet("Developer")
''');
    }
  }
}

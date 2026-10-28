import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../models/agent_event.dart';
import '../proot/proot_manager.dart';

class WorkspaceService {
  static const String defaultProjectName = 'default_project';

  Directory? _workspacesRootDir;
  Directory? _workspaceDir;
  PRootManager? _prootManager;

  void attachPRootManager(PRootManager prootManager) {
    _prootManager = prootManager;
    if (_workspaceDir != null) {
      _prootManager!.setWorkspacePath(_workspaceDir!.path);
    }
  }

  Future<void> init({Directory? baseDir}) async {
    final appDir = baseDir ?? await getApplicationDocumentsDirectory();
    _workspacesRootDir = Directory(p.join(appDir.path, 'workspace'));
    if (!await _workspacesRootDir!.exists()) {
      await _workspacesRootDir!.create(recursive: true);
    }

    final defaultDir = Directory(p.join(_workspacesRootDir!.path, defaultProjectName));
    if (!await defaultDir.exists()) {
      await defaultDir.create(recursive: true);
    }
    _workspaceDir = defaultDir;
    _prootManager?.setWorkspacePath(_workspaceDir!.path);
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

  String get currentProjectName => _workspaceDir != null ? p.basename(_workspaceDir!.path) : defaultProjectName;

  Future<List<String>> listProjects() async {
    final root = workspacesRootDir;
    if (!root.existsSync()) return [];

    final projects = <String>[];
    final entities = root.listSync();
    for (final e in entities) {
      if (e is Directory) {
        final name = p.basename(e.path);
        if (name != defaultProjectName && !name.startsWith('.')) {
          projects.add(name);
        }
      }
    }
    projects.sort();
    return projects;
  }

  Future<void> switchProject(String? projectName) async {
    final targetName = (projectName == null || projectName.isEmpty || projectName == defaultProjectName)
        ? defaultProjectName
        : projectName;
    final target = Directory(p.join(workspacesRootDir.path, targetName));
    if (!target.existsSync()) {
      target.createSync(recursive: true);
    }
    _workspaceDir = target;
    _prootManager?.setWorkspacePath(target.path);
  }

  Future<void> createProject(String projectName) async {
    final target = Directory(p.join(workspacesRootDir.path, projectName));
    if (!target.existsSync()) {
      target.createSync(recursive: true);
    }
  }

  // Resolves a relative or absolute path safely within the workspace
  String resolvePath(String relativeOrAbsolutePath) {
    final String fullPath;
    if (p.isAbsolute(relativeOrAbsolutePath)) {
      fullPath = p.normalize(relativeOrAbsolutePath);
    } else {
      fullPath = p.normalize(p.join(workspacePath, relativeOrAbsolutePath));
    }

    final normalizedWs = p.normalize(workspacePath);
    if (!p.equals(fullPath, normalizedWs) && !p.isWithin(normalizedWs, fullPath)) {
      throw FileSystemException(
        'Path traversal detected: path escapes workspace sandbox',
        relativeOrAbsolutePath,
      );
    }
    return fullPath;
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
    final diffLines = _myersDiff(origLines, newLines);

    return DiffEvent(
      filePath: relativePath,
      originalContent: originalContent,
      newContent: newContent,
      diffLines: diffLines,
    );
  }

  /// High-performance Myers difference algorithm with linear common prefix/suffix optimization
  List<DiffLine> _myersDiff(List<String> origLines, List<String> newLines) {
    final diffLines = <DiffLine>[];

    // 1. Common prefix optimization
    int prefix = 0;
    while (prefix < origLines.length &&
        prefix < newLines.length &&
        origLines[prefix] == newLines[prefix]) {
      diffLines.add(DiffLine(
        type: DiffLineType.unchanged,
        text: origLines[prefix],
        oldLineNumber: prefix + 1,
        newLineNumber: prefix + 1,
      ));
      prefix++;
    }

    // 2. Common suffix optimization
    int suffix = 0;
    while (suffix < (origLines.length - prefix) &&
        suffix < (newLines.length - prefix) &&
        origLines[origLines.length - 1 - suffix] ==
            newLines[newLines.length - 1 - suffix]) {
      suffix++;
    }

    final a = origLines.sublist(prefix, origLines.length - suffix);
    final b = newLines.sublist(prefix, newLines.length - suffix);

    final n = a.length;
    final m = b.length;

    if (n > 0 && m == 0) {
      for (int i = 0; i < n; i++) {
        diffLines.add(DiffLine(
          type: DiffLineType.removed,
          text: a[i],
          oldLineNumber: prefix + i + 1,
        ));
      }
    } else if (n == 0 && m > 0) {
      for (int j = 0; j < m; j++) {
        diffLines.add(DiffLine(
          type: DiffLineType.added,
          text: b[j],
          newLineNumber: prefix + j + 1,
        ));
      }
    } else if (n > 0 && m > 0) {
      final max = n + m;
      final offset = max;
      final v = List<int>.filled(2 * max + 1, 0);
      final trace = <List<int>>[];

      int? finalD;
      for (int d = 0; d <= max; d++) {
        trace.add(List<int>.from(v));
        for (int k = -d; k <= d; k += 2) {
          int x;
          if (k == -d || (k != d && v[k - 1 + offset] < v[k + 1 + offset])) {
            x = v[k + 1 + offset];
          } else {
            x = v[k - 1 + offset] + 1;
          }
          int y = x - k;
          while (x < n && y < m && a[x] == b[y]) {
            x++;
            y++;
          }
          v[k + offset] = x;
          if (x >= n && y >= m) {
            finalD = d;
            break;
          }
        }
        if (finalD != null) break;
        if (d >= 1000) {
          // Fallback guard for massive unaligned edits
          break;
        }
      }

      if (finalD != null) {
        int x = n;
        int y = m;
        final edits = <_DiffOp>[];
        for (int d = finalD; d > 0; d--) {
          final vPrev = trace[d];
          final k = x - y;
          int prevK;
          if (k == -d || (k != d && vPrev[k - 1 + offset] < vPrev[k + 1 + offset])) {
            prevK = k + 1;
          } else {
            prevK = k - 1;
          }
          final prevX = vPrev[prevK + offset];
          final prevY = prevX - prevK;

          while (x > prevX && y > prevY) {
            x--;
            y--;
            edits.add(_DiffOp(DiffLineType.unchanged, x, y));
          }

          if (x == prevX) {
            y--;
            edits.add(_DiffOp(DiffLineType.added, null, y));
          } else {
            x--;
            edits.add(_DiffOp(DiffLineType.removed, x, null));
          }
        }
        while (x > 0 && y > 0) {
          x--;
          y--;
          edits.add(_DiffOp(DiffLineType.unchanged, x, y));
        }

        final ops = edits.reversed.toList();
        for (final op in ops) {
          switch (op.type) {
            case DiffLineType.unchanged:
              diffLines.add(DiffLine(
                type: DiffLineType.unchanged,
                text: a[op.aIndex!],
                oldLineNumber: prefix + op.aIndex! + 1,
                newLineNumber: prefix + op.bIndex! + 1,
              ));
              break;
            case DiffLineType.removed:
              diffLines.add(DiffLine(
                type: DiffLineType.removed,
                text: a[op.aIndex!],
                oldLineNumber: prefix + op.aIndex! + 1,
              ));
              break;
            case DiffLineType.added:
              diffLines.add(DiffLine(
                type: DiffLineType.added,
                text: b[op.bIndex!],
                newLineNumber: prefix + op.bIndex! + 1,
              ));
              break;
          }
        }
      } else {
        // Fallback for extreme distances
        for (int i = 0; i < n; i++) {
          diffLines.add(DiffLine(
            type: DiffLineType.removed,
            text: a[i],
            oldLineNumber: prefix + i + 1,
          ));
        }
        for (int j = 0; j < m; j++) {
          diffLines.add(DiffLine(
            type: DiffLineType.added,
            text: b[j],
            newLineNumber: prefix + j + 1,
          ));
        }
      }
    }

    // 3. Common suffix
    final origSuffixStart = origLines.length - suffix;
    final newSuffixStart = newLines.length - suffix;
    for (int k = 0; k < suffix; k++) {
      diffLines.add(DiffLine(
        type: DiffLineType.unchanged,
        text: origLines[origSuffixStart + k],
        oldLineNumber: origSuffixStart + k + 1,
        newLineNumber: newSuffixStart + k + 1,
      ));
    }

    return diffLines;
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

    final encoder = ZipFileEncoder();
    encoder.create(zipFile.path);

    try {
      final entities = workspaceDir.listSync(recursive: true);
      for (final entity in entities) {
        if (entity is File) {
          final relPath = p.relative(entity.path, from: workspacePath);
          final normalizedRelPath = p.posix.joinAll(p.split(relPath));
          if (!includeGit && (normalizedRelPath.startsWith('.git') || normalizedRelPath.contains('/.git'))) {
            continue;
          }
          await encoder.addFile(entity, normalizedRelPath);
        }
      }
    } finally {
      await encoder.close();
    }

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
    final addRes = await prootManager.runCommandArgs(['git', 'add', '.'], workingDir: '/workspace');
    if (addRes.exitCode != 0) {
      return addRes;
    }
    return await prootManager.runCommandArgs(
      ['git', 'commit', '-m', message],
      workingDir: '/workspace',
    );
  }
}

class _DiffOp {
  final DiffLineType type;
  final int? aIndex;
  final int? bIndex;

  _DiffOp(this.type, this.aIndex, this.bIndex);
}

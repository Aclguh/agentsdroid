import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../models/agent_event.dart';

class WorkspaceService {
  Directory? _workspaceDir;

  Future<void> init() async {
    final appDir = await getApplicationDocumentsDirectory();
    _workspaceDir = Directory(p.join(appDir.path, 'workspace', 'default_project'));
    if (!await _workspaceDir!.exists()) {
      await _workspaceDir!.create(recursive: true);
      await _createSampleProject();
    }
  }

  Directory get workspaceDir {
    if (_workspaceDir == null) {
      throw StateError('WorkspaceService not initialized. Call init() first.');
    }
    return _workspaceDir!;
  }

  String get workspacePath => workspaceDir.path;

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

  Future<void> _createSampleProject() async {
    final readme = File(p.join(workspacePath, 'README.md'));
    if (!await readme.exists()) {
      await readme.writeAsString('''# Welcome to AgentsDroid! 🚀

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

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'proot_installer.dart';

enum PRootStatus {
  notInstalled,
  downloading,
  extracting,
  configuring,
  ready,
  error,
}

class PRootProgress {
  final PRootStatus status;
  final double progress; // 0.0 to 1.0
  final String message;
  final int downloadedBytes;
  final int totalBytes;

  PRootProgress({
    required this.status,
    this.progress = 0.0,
    required this.message,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
  });
}

class ToolchainStatus {
  final String? nodeVersion;
  final String? npmVersion;
  final String? pythonVersion;
  final String? gitVersion;
  final String? claudeCodeVersion;

  ToolchainStatus({
    this.nodeVersion,
    this.npmVersion,
    this.pythonVersion,
    this.gitVersion,
    this.claudeCodeVersion,
  });

  bool get hasNode => nodeVersion != null && nodeVersion!.isNotEmpty;
  bool get hasPython => pythonVersion != null && pythonVersion!.isNotEmpty;
  bool get hasGit => gitVersion != null && gitVersion!.isNotEmpty;
  bool get hasClaudeCode => claudeCodeVersion != null && claudeCodeVersion!.isNotEmpty;
}

class PRootManager {
  Directory? _rootfsDir;
  Directory? _binDir;
  File? _prootBin;
  String? _workspacePath;

  final _statusController = StreamController<PRootProgress>.broadcast();
  Stream<PRootProgress> get statusStream => _statusController.stream;

  PRootStatus _currentStatus = PRootStatus.notInstalled;
  PRootStatus get currentStatus => _currentStatus;

  Future<void> init({String? workspacePath}) async {
    _workspacePath = workspacePath;
    final appDir = await getApplicationSupportDirectory();
    _rootfsDir = Directory(p.join(appDir.path, 'rootfs'));
    _binDir = Directory(p.join(appDir.path, 'bin'));
    _prootBin = File(p.join(_binDir!.path, 'proot'));

    if (await isInstalled()) {
      _currentStatus = PRootStatus.ready;
      _statusController.add(PRootProgress(
        status: PRootStatus.ready,
        progress: 1.0,
        message: 'Debian-arm64 Linux Subsystem is ready.',
      ));
    } else {
      _currentStatus = PRootStatus.notInstalled;
      _statusController.add(PRootProgress(
        status: PRootStatus.notInstalled,
        progress: 0.0,
        message: 'Linux Subsystem not installed.',
      ));
    }
  }

  Directory get rootfsDir {
    if (_rootfsDir == null) {
      throw StateError('PRootManager not initialized. Call init() first.');
    }
    return _rootfsDir!;
  }

  void setWorkspacePath(String path) {
    _workspacePath = path;
  }

  Future<bool> isInstalled() async {
    if (_rootfsDir == null) return false;
    final bash = File(p.join(_rootfsDir!.path, 'bin', 'bash'));
    final sh = File(p.join(_rootfsDir!.path, 'bin', 'sh'));
    return (await bash.exists()) || (await sh.exists());
  }

  /// Downloads and extracts the Linux rootfs into the app private storage
  Future<void> installSubsystem({String? downloadUrl, bool mockForDev = false}) async {
    if (_currentStatus == PRootStatus.downloading || _currentStatus == PRootStatus.extracting) {
      return;
    }

    try {
      _currentStatus = PRootStatus.downloading;
      final url = downloadUrl ?? RootfsInstaller.defaultDebianRootfsUrl;
      final tempArchive = File(p.join(_rootfsDir!.parent.path, 'rootfs_temp.tar.xz'));

      if (mockForDev) {
        // Dev / fast path for local testing without downloading 40MB
        await _setupMinimalMockRootfs();
      } else {
        await RootfsInstaller.install(
          downloadUrl: url,
          targetDir: _rootfsDir!,
          targetArchiveFile: tempArchive,
          onProgress: (pInfo) {
            PRootStatus status = PRootStatus.downloading;
            if (pInfo.stage == 'extracting') status = PRootStatus.extracting;
            if (pInfo.stage == 'configuring') status = PRootStatus.configuring;
            if (pInfo.stage == 'completed') status = PRootStatus.ready;

            _currentStatus = status;
            _statusController.add(PRootProgress(
              status: status,
              progress: pInfo.progress,
              message: pInfo.message,
              downloadedBytes: pInfo.downloadedBytes,
              totalBytes: pInfo.totalBytes,
            ));
          },
        );
      }

      _currentStatus = PRootStatus.ready;
      _statusController.add(PRootProgress(
        status: PRootStatus.ready,
        progress: 1.0,
        message: 'Debian-arm64 Subsystem installed successfully!',
      ));
    } catch (e) {
      _currentStatus = PRootStatus.error;
      _statusController.add(PRootProgress(
        status: PRootStatus.error,
        progress: 0.0,
        message: 'Failed to install subsystem: $e',
      ));
    }
  }

  Future<void> _setupMinimalMockRootfs() async {
    _statusController.add(PRootProgress(
      status: PRootStatus.downloading,
      progress: 0.4,
      message: 'Initializing minimal Debian environment...',
    ));

    final binDir = Directory(p.join(_rootfsDir!.path, 'bin'));
    if (!await binDir.exists()) {
      await binDir.create(recursive: true);
    }

    final bashFile = File(p.join(binDir.path, 'bash'));
    await bashFile.writeAsString('#!/bin/sh\nexec sh "\$@"\n');

    final shFile = File(p.join(binDir.path, 'sh'));
    await shFile.writeAsString('#!/bin/sh\nexec sh "\$@"\n');

    await RootfsInstaller.configureEnvironment(_rootfsDir!);
  }

  /// Run command inside PRoot isolated sandbox
  Future<ProcessResult> runCommand(
    String command, {
    Map<String, String>? environment,
    String? workingDir,
  }) async {
    if (!await isInstalled()) {
      throw StateError('Linux subsystem is not installed yet.');
    }

    final fullEnv = _buildEnvironment(environment);

    // If proot binary exists on Android device:
    if (_prootBin != null && await _prootBin!.exists()) {
      final args = _buildPRootArgs(command, workingDir: workingDir);
      return await Process.run(
        _prootBin!.path,
        args,
        environment: fullEnv,
        workingDirectory: _rootfsDir!.path,
      );
    } else {
      // Fallback for native platform execution
      final effectiveWd = workingDir != null
          ? (_workspacePath != null && workingDir.startsWith('/workspace')
              ? _workspacePath!
              : p.join(_rootfsDir!.path, workingDir.replaceFirst('/', '')))
          : _workspacePath;

      return await Process.run(
        'sh',
        ['-c', command],
        workingDirectory: effectiveWd,
        environment: fullEnv,
      );
    }
  }

  /// Stream command stdout and stderr in real-time
  Future<int> runStreamingCommand(
    String command, {
    Map<String, String>? environment,
    String? workingDir,
    required void Function(String) onOutput,
  }) async {
    if (!await isInstalled()) {
      throw StateError('Linux subsystem is not installed yet.');
    }

    final fullEnv = _buildEnvironment(environment);

    Process process;
    if (_prootBin != null && await _prootBin!.exists()) {
      final args = _buildPRootArgs(command, workingDir: workingDir);
      process = await Process.start(
        _prootBin!.path,
        args,
        environment: fullEnv,
        workingDirectory: _rootfsDir!.path,
      );
    } else {
      final effectiveWd = workingDir != null
          ? (_workspacePath != null && workingDir.startsWith('/workspace')
              ? _workspacePath!
              : p.join(_rootfsDir!.path, workingDir.replaceFirst('/', '')))
          : _workspacePath;

      process = await Process.start(
        'sh',
        ['-c', command],
        workingDirectory: effectiveWd,
        environment: fullEnv,
      );
    }

    process.stdout.transform(utf8.decoder).listen((data) => onOutput(data));
    process.stderr.transform(utf8.decoder).listen((data) => onOutput(data));

    return await process.exitCode;
  }

  /// Inspect installed developer toolchains inside the subsystem
  Future<ToolchainStatus> checkToolchains() async {
    if (!await isInstalled()) {
      return ToolchainStatus();
    }

    String? node;
    String? npm;
    String? python;
    String? git;
    String? claude;

    try {
      final res = await runCommand('node -v');
      if (res.exitCode == 0) node = res.stdout.toString().trim();
    } catch (_) {}

    try {
      final res = await runCommand('npm -v');
      if (res.exitCode == 0) npm = res.stdout.toString().trim();
    } catch (_) {}

    try {
      final res = await runCommand('python3 --version');
      if (res.exitCode == 0) python = res.stdout.toString().trim();
    } catch (_) {}

    try {
      final res = await runCommand('git --version');
      if (res.exitCode == 0) git = res.stdout.toString().trim();
    } catch (_) {}

    try {
      final res = await runCommand('claude --version');
      if (res.exitCode == 0) claude = res.stdout.toString().trim();
    } catch (_) {}

    return ToolchainStatus(
      nodeVersion: node,
      npmVersion: npm,
      pythonVersion: python,
      gitVersion: git,
      claudeCodeVersion: claude,
    );
  }

  List<String> _buildPRootArgs(String command, {String? workingDir}) {
    final args = <String>[
      '-r', _rootfsDir!.path,
      '-0',
      '-b', '/dev',
      '-b', '/proc',
      '-b', '/sys',
    ];

    if (_workspacePath != null && Directory(_workspacePath!).existsSync()) {
      args.addAll(['-b', '$_workspacePath:/workspace']);
    }

    final wd = workingDir ?? '/workspace';
    args.addAll(['-w', wd, '/bin/bash', '-c', command]);
    return args;
  }

  Map<String, String> _buildEnvironment(Map<String, String>? extraEnv) {
    final env = <String, String>{
      'PATH': '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
      'HOME': '/root',
      'TERM': 'xterm-256color',
      'LANG': 'C.UTF-8',
      'LC_ALL': 'C.UTF-8',
    };
    if (extraEnv != null) {
      env.addAll(extraEnv);
    }
    return env;
  }

  void dispose() {
    _statusController.close();
  }
}

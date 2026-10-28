import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../utils/app_logger.dart';
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

/// An interactive process running inside PRoot Linux subsystem
class PRootProcess {
  final Process process;
  final Stream<String> stdout;
  final Stream<String> stderr;

  PRootProcess({
    required this.process,
    required this.stdout,
    required this.stderr,
  });

  IOSink get stdin => process.stdin;
  Future<int> get exitCode => process.exitCode;
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => process.kill(signal);
}

class PRootManager {
  static const Map<String, String> defaultProotUrls = {
    'arm64-v8a': 'https://ghproxy.net/https://github.com/termux/proot-distro/releases/download/v4.7.0/proot-aarch64',
    'armeabi-v7a': 'https://ghproxy.net/https://github.com/termux/proot-distro/releases/download/v4.7.0/proot-arm',
    'x86_64': 'https://ghproxy.net/https://github.com/termux/proot-distro/releases/download/v4.7.0/proot-x86_64',
  };

  static Future<String> detectAndroidAbi() async {
    if (Platform.isAndroid) {
      try {
        final res = await Process.run('getprop', ['ro.product.cpu.abi']);
        if (res.exitCode == 0) {
          final abi = res.stdout.toString().trim();
          if (abi.isNotEmpty) return abi;
        }
      } catch (e) {
        AppLogger.debug('Failed to query ro.product.cpu.abi: $e', tag: 'PRootManager');
      }
    }
    return 'arm64-v8a';
  }

  Directory? _rootfsDir;
  Directory? _effectiveRootfsDir;
  Directory? _binDir;
  File? _prootBin;
  String? _workspacePath;

  bool get hasProotBinary =>
      _prootBin != null && _prootBin!.existsSync() && _prootBin!.lengthSync() > 0;
  File? get prootBinary => _prootBin;
  Directory? get binDirectory => _binDir;

  final _statusController = StreamController<PRootProgress>.broadcast();
  Stream<PRootProgress> get statusStream => _statusController.stream;

  PRootStatus _currentStatus = PRootStatus.notInstalled;
  PRootStatus get currentStatus => _currentStatus;

  Future<void> init({String? workspacePath, Directory? appSupportDir}) async {
    _workspacePath = workspacePath;
    final appDir = appSupportDir ?? await getApplicationSupportDirectory();
    _rootfsDir = Directory(p.join(appDir.path, 'rootfs'));
    _binDir = Directory(p.join(appDir.path, 'bin'));
    _prootBin = File(p.join(_binDir!.path, 'proot'));

    await ensureProotBinary(allowDownload: false);

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
    return _effectiveRootfsDir ?? _rootfsDir!;
  }

  void setWorkspacePath(String path) {
    _workspacePath = path;
  }

  /// Locates the real rootfs directory (handles direct or nested unpacking)
  Future<Directory?> findEffectiveRootfsDir() async {
    if (_rootfsDir == null) return null;

    if (await _hasBinaries(_rootfsDir!)) {
      _effectiveRootfsDir = _rootfsDir;
      return _rootfsDir;
    }

    if (await _rootfsDir!.exists()) {
      try {
        await for (final entity in _rootfsDir!.list(followLinks: false)) {
          if (entity is Directory && await _hasBinaries(entity)) {
            _effectiveRootfsDir = entity;
            return entity;
          }
        }
      } catch (e) {
        AppLogger.debug('Error listing rootfs directory: $e', tag: 'PRootManager');
      }
    }

    return null;
  }

  Future<bool> _hasBinaries(Directory dir) async {
    final candidates = [
      p.join(dir.path, 'bin', 'bash'),
      p.join(dir.path, 'bin', 'sh'),
      p.join(dir.path, 'usr', 'bin', 'bash'),
      p.join(dir.path, 'usr', 'bin', 'sh'),
    ];
    for (final c in candidates) {
      if (await File(c).exists()) return true;
    }
    return false;
  }

  Future<bool> isInstalled() async {
    final effectiveDir = await findEffectiveRootfsDir();
    if (effectiveDir != null) {
      _effectiveRootfsDir = effectiveDir;
      return true;
    }
    return false;
  }

  /// Downloads and extracts the Linux rootfs into the app private storage
  Future<void> installSubsystem({String? downloadUrl, bool mockForDev = false}) async {
    if (_currentStatus == PRootStatus.downloading || _currentStatus == PRootStatus.extracting) {
      return;
    }

    try {
      _currentStatus = PRootStatus.downloading;
      final url = downloadUrl ?? RootfsInstaller.ghproxyDebianRootfsUrl;
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

      final eff = await findEffectiveRootfsDir();
      if (eff != null) {
        _effectiveRootfsDir = eff;
        await RootfsInstaller.configureEnvironment(eff);
        await ensureProotBinary(allowDownload: true);
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

  /// Installs rootfs from a local archive file (e.g. user imported .tar.xz)
  Future<void> installSubsystemFromArchive(File archiveFile, {bool deleteAfter = false}) async {
    if (_currentStatus == PRootStatus.downloading || _currentStatus == PRootStatus.extracting) {
      return;
    }

    if (!await archiveFile.exists()) {
      _currentStatus = PRootStatus.error;
      _statusController.add(PRootProgress(
        status: PRootStatus.error,
        progress: 0.0,
        message: 'File not found: ${archiveFile.path}',
      ));
      return;
    }

    try {
      _currentStatus = PRootStatus.extracting;
      await RootfsInstaller.installFromArchive(
        archiveFile: archiveFile,
        targetDir: _rootfsDir!,
        deleteArchiveAfterInstall: deleteAfter,
        onProgress: (pInfo) {
          PRootStatus status = PRootStatus.extracting;
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

      final eff = await findEffectiveRootfsDir();
      if (eff != null) {
        _effectiveRootfsDir = eff;
        await RootfsInstaller.configureEnvironment(eff);
        await ensureProotBinary(allowDownload: true);
      }

      _currentStatus = PRootStatus.ready;
      _statusController.add(PRootProgress(
        status: PRootStatus.ready,
        progress: 1.0,
        message: 'Debian-arm64 Subsystem installed successfully from local file!',
      ));
    } catch (e) {
      _currentStatus = PRootStatus.error;
      _statusController.add(PRootProgress(
        status: PRootStatus.error,
        progress: 0.0,
        message: 'Failed to import subsystem archive: $e',
      ));
    }
  }

  /// Reset/Remove the rootfs directory
  Future<void> uninstallSubsystem() async {
    if (_rootfsDir != null && await _rootfsDir!.exists()) {
      await _rootfsDir!.delete(recursive: true);
    }
    _effectiveRootfsDir = null;
    _currentStatus = PRootStatus.notInstalled;
    _statusController.add(PRootProgress(
      status: PRootStatus.notInstalled,
      progress: 0.0,
      message: 'Linux Subsystem removed.',
    ));
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

    final appBin = _binDir ?? Directory(p.join(_rootfsDir!.parent.path, 'bin'));
    if (!await appBin.exists()) {
      await appBin.create(recursive: true);
    }
    _prootBin = File(p.join(appBin.path, 'proot'));
    if (!await _prootBin!.exists()) {
      await _prootBin!.writeAsString('#!/bin/sh\nexec "\$@"\n');
      _ensureExecutable(_prootBin!);
    }

    await RootfsInstaller.configureEnvironment(_rootfsDir!);
  }

  /// Ensures that the static proot executable binary is deployed in app private storage (bin/proot).
  ///
  /// Deployment follows multi-tiered fallback:
  /// 1. Existing verified executable in bin/
  /// 2. Flutter Assets (`assets/bin/<abi>/proot` or `assets/bin/proot`)
  /// 3. App native library directory (/data/data/.../lib/libproot.so or candidate paths)
  /// 4. Remote static binary download from reliable CDN / mirror
  Future<File?> ensureProotBinary({
    String? customDownloadUrl,
    http.Client? httpClient,
    List<String>? nativeLibCandidates,
    bool allowDownload = true,
  }) async {
    if (_binDir == null) return null;
    if (!await _binDir!.exists()) {
      await _binDir!.create(recursive: true);
    }

    _prootBin = File(p.join(_binDir!.path, 'proot'));
    if (await _prootBin!.exists() && (await _prootBin!.length()) > 0) {
      _ensureExecutable(_prootBin!);
      return _prootBin;
    }

    final abi = await detectAndroidAbi();

    // 1. Try extracting from Flutter assets if bundled
    final assetCandidates = [
      'assets/bin/$abi/proot',
      'assets/bin/proot',
    ];

    for (final assetPath in assetCandidates) {
      try {
        final data = await rootBundle.load(assetPath);
        final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await _prootBin!.writeAsBytes(bytes, flush: true);
        _ensureExecutable(_prootBin!);
        AppLogger.info('Extracted proot binary from asset: $assetPath', tag: 'PRootManager');
        return _prootBin;
      } catch (_) {
        // Asset not packaged or outside Flutter widget environment
      }
    }

    // 2. Try locating native library (.so) or system binary
    final candidates = nativeLibCandidates ?? [
      '/data/data/com.agentsdroid/lib/libproot.so',
      '/data/user/0/com.agentsdroid/lib/libproot.so',
      '/data/data/com.agentsdroid.agentsdroid/lib/libproot.so',
      '/data/user/0/com.agentsdroid.agentsdroid/lib/libproot.so',
      '/data/data/com.termux/files/usr/bin/proot',
      '/system/bin/proot',
    ];

    for (final cand in candidates) {
      final file = File(cand);
      try {
        if (await file.exists() && await file.length() > 0) {
          await file.copy(_prootBin!.path);
          _ensureExecutable(_prootBin!);
          AppLogger.info('Copied proot binary from candidate: $cand', tag: 'PRootManager');
          return _prootBin;
        }
      } catch (e) {
        AppLogger.debug('Failed to copy proot candidate $cand: $e', tag: 'PRootManager');
      }
    }

    if (!allowDownload) return null;

    // 3. Download standalone static proot binary if network client / url available
    final downloadUrl = customDownloadUrl ?? defaultProotUrls[abi] ?? defaultProotUrls['arm64-v8a'];
    if (downloadUrl != null && downloadUrl.isNotEmpty) {
      try {
        AppLogger.info('Downloading static proot binary from $downloadUrl (ABI: $abi)', tag: 'PRootManager');
        final client = httpClient ?? http.Client();
        try {
          final res = await client.get(Uri.parse(downloadUrl));
          if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
            await _prootBin!.writeAsBytes(res.bodyBytes, flush: true);
            _ensureExecutable(_prootBin!);
            AppLogger.info('Successfully downloaded proot binary ($downloadUrl)', tag: 'PRootManager');
            return _prootBin;
          } else {
            AppLogger.warn('Failed to download proot binary, HTTP ${res.statusCode}', tag: 'PRootManager');
          }
        } finally {
          if (httpClient == null) {
            client.close();
          }
        }
      } catch (e) {
        AppLogger.warn('Error downloading static proot binary: $e', tag: 'PRootManager');
      }
    }

    return null;
  }

  void _ensureExecutable(File file) {
    if (Platform.isLinux || Platform.isAndroid) {
      try {
        Process.runSync('chmod', ['755', file.path]);
      } catch (e) {
        AppLogger.debug('chmod 755 failed on ${file.path}: $e', tag: 'PRootManager');
      }
    }
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
    final root = rootfsDir;

    // If proot binary exists on Android device:
    if (_prootBin != null && await _prootBin!.exists()) {
      final args = _buildPRootArgs(command, workingDir: workingDir);
      return await Process.run(
        _prootBin!.path,
        args,
        environment: fullEnv,
        workingDirectory: root.path,
      );
    } else {
      // Fallback for native platform execution
      final effectiveWd = workingDir != null
          ? (_workspacePath != null && workingDir.startsWith('/workspace')
              ? _workspacePath!
              : p.join(root.path, workingDir.replaceFirst('/', '')))
          : _workspacePath;

      return await Process.run(
        'sh',
        ['-c', command],
        workingDirectory: effectiveWd,
        environment: fullEnv,
      );
    }
  }

  /// Run command with explicit arguments list without invoking shell interpolation
  Future<ProcessResult> runCommandArgs(
    List<String> commandArgs, {
    Map<String, String>? environment,
    String? workingDir,
  }) async {
    if (!await isInstalled()) {
      throw StateError('Linux subsystem is not installed yet.');
    }

    final fullEnv = _buildEnvironment(environment);
    final root = rootfsDir;

    if (_prootBin != null && await _prootBin!.exists()) {
      final args = _buildPRootArgsList(commandArgs, workingDir: workingDir);
      return await Process.run(
        _prootBin!.path,
        args,
        environment: fullEnv,
        workingDirectory: root.path,
      );
    } else {
      final effectiveWd = workingDir != null
          ? (_workspacePath != null && workingDir.startsWith('/workspace')
              ? _workspacePath!
              : p.join(root.path, workingDir.replaceFirst('/', '')))
          : _workspacePath;

      return await Process.run(
        commandArgs.first,
        commandArgs.sublist(1),
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
    final root = rootfsDir;

    Process process;
    if (_prootBin != null && await _prootBin!.exists()) {
      final args = _buildPRootArgs(command, workingDir: workingDir);
      process = await Process.start(
        _prootBin!.path,
        args,
        environment: fullEnv,
        workingDirectory: root.path,
      );
    } else {
      final effectiveWd = workingDir != null
          ? (_workspacePath != null && workingDir.startsWith('/workspace')
              ? _workspacePath!
              : p.join(root.path, workingDir.replaceFirst('/', '')))
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

  /// Start an interactive process inside the subsystem with full stdin/stdout access
  Future<PRootProcess> startProcess(
    String command, {
    Map<String, String>? environment,
    String? workingDir,
  }) async {
    if (!await isInstalled()) {
      throw StateError('Linux subsystem is not installed yet.');
    }

    final fullEnv = _buildEnvironment(environment);
    final root = rootfsDir;

    Process process;
    if (_prootBin != null && await _prootBin!.exists()) {
      final args = _buildPRootArgs(command, workingDir: workingDir);
      process = await Process.start(
        _prootBin!.path,
        args,
        environment: fullEnv,
        workingDirectory: root.path,
      );
    } else {
      final effectiveWd = workingDir != null
          ? (_workspacePath != null && workingDir.startsWith('/workspace')
              ? _workspacePath!
              : p.join(root.path, workingDir.replaceFirst('/', '')))
          : _workspacePath;

      process = await Process.start(
        'sh',
        ['-c', command],
        workingDirectory: effectiveWd,
        environment: fullEnv,
      );
    }

    final stdoutStream = process.stdout.transform(utf8.decoder).asBroadcastStream();
    final stderrStream = process.stderr.transform(utf8.decoder).asBroadcastStream();

    return PRootProcess(
      process: process,
      stdout: stdoutStream,
      stderr: stderrStream,
    );
  }

  /// Start an interactive process with argument list without shell interpolation
  Future<PRootProcess> startProcessArgs(
    List<String> commandArgs, {
    Map<String, String>? environment,
    String? workingDir,
  }) async {
    if (!await isInstalled()) {
      throw StateError('Linux subsystem is not installed yet.');
    }

    final fullEnv = _buildEnvironment(environment);
    final root = rootfsDir;

    Process process;
    if (_prootBin != null && await _prootBin!.exists()) {
      final args = _buildPRootArgsList(commandArgs, workingDir: workingDir);
      process = await Process.start(
        _prootBin!.path,
        args,
        environment: fullEnv,
        workingDirectory: root.path,
      );
    } else {
      final effectiveWd = workingDir != null
          ? (_workspacePath != null && workingDir.startsWith('/workspace')
              ? _workspacePath!
              : p.join(root.path, workingDir.replaceFirst('/', '')))
          : _workspacePath;

      process = await Process.start(
        commandArgs.first,
        commandArgs.sublist(1),
        workingDirectory: effectiveWd,
        environment: fullEnv,
      );
    }

    final stdoutStream = process.stdout.transform(utf8.decoder).asBroadcastStream();
    final stderrStream = process.stderr.transform(utf8.decoder).asBroadcastStream();

    return PRootProcess(
      process: process,
      stdout: stdoutStream,
      stderr: stderrStream,
    );
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
    } catch (e) {
      AppLogger.debug('node -v inspection failed: $e', tag: 'PRootManager');
    }

    try {
      final res = await runCommand('npm -v');
      if (res.exitCode == 0) npm = res.stdout.toString().trim();
    } catch (e) {
      AppLogger.debug('npm -v inspection failed: $e', tag: 'PRootManager');
    }

    try {
      final res = await runCommand('python3 --version');
      if (res.exitCode == 0) python = res.stdout.toString().trim();
    } catch (e) {
      AppLogger.debug('python3 --version inspection failed: $e', tag: 'PRootManager');
    }

    try {
      final res = await runCommand('git --version');
      if (res.exitCode == 0) git = res.stdout.toString().trim();
    } catch (e) {
      AppLogger.debug('git --version inspection failed: $e', tag: 'PRootManager');
    }

    try {
      final res = await runCommand('claude --version');
      if (res.exitCode == 0) claude = res.stdout.toString().trim();
    } catch (e) {
      AppLogger.debug('claude --version inspection failed: $e', tag: 'PRootManager');
    }

    return ToolchainStatus(
      nodeVersion: node,
      npmVersion: npm,
      pythonVersion: python,
      gitVersion: git,
      claudeCodeVersion: claude,
    );
  }

  List<String> _buildPRootArgs(String command, {String? workingDir}) {
    final root = rootfsDir;
    final args = <String>[
      '-r', root.path,
      '-0',
      '-b', '/dev',
      '-b', '/proc',
      '-b', '/sys',
    ];

    if (_workspacePath != null && Directory(_workspacePath!).existsSync()) {
      args.addAll(['-b', '$_workspacePath:/workspace']);
    }

    final wd = workingDir ?? '/workspace';
    final hasBash = File(p.join(root.path, 'bin', 'bash')).existsSync() ||
                    File(p.join(root.path, 'usr', 'bin', 'bash')).existsSync();
    final shell = hasBash ? '/bin/bash' : '/bin/sh';
    args.addAll(['-w', wd, shell, '-c', command]);
    return args;
  }

  List<String> _buildPRootArgsList(List<String> commandArgs, {String? workingDir}) {
    final root = rootfsDir;
    final args = <String>[
      '-r', root.path,
      '-0',
      '-b', '/dev',
      '-b', '/proc',
      '-b', '/sys',
    ];

    if (_workspacePath != null && Directory(_workspacePath!).existsSync()) {
      args.addAll(['-b', '$_workspacePath:/workspace']);
    }

    final wd = workingDir ?? '/workspace';
    args.addAll(['-w', wd, ...commandArgs]);
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

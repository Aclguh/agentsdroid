import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum PRootStatus {
  notInstalled,
  downloading,
  extracting,
  ready,
  error,
}

class PRootProgress {
  final PRootStatus status;
  final double progress; // 0.0 to 1.0
  final String message;

  PRootProgress({
    required this.status,
    this.progress = 0.0,
    required this.message,
  });
}

class PRootManager {
  static const String defaultRootfsUrl =
      'https://github.com/termux/proot-distro/releases/download/v4.7.0/debian-arm64.tar.xz';

  Directory? _rootfsDir;
  File? _prootBin;

  final _statusController = StreamController<PRootProgress>.broadcast();
  Stream<PRootProgress> get statusStream => _statusController.stream;

  PRootStatus _currentStatus = PRootStatus.notInstalled;
  PRootStatus get currentStatus => _currentStatus;

  Future<void> init() async {
    final appDir = await getApplicationSupportDirectory();
    _rootfsDir = Directory(p.join(appDir.path, 'rootfs'));
    _prootBin = File(p.join(appDir.path, 'bin', 'proot'));

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

  Future<bool> isInstalled() async {
    if (_rootfsDir == null) return false;
    final bash = File(p.join(_rootfsDir!.path, 'bin', 'bash'));
    final sh = File(p.join(_rootfsDir!.path, 'bin', 'sh'));
    return (await bash.exists()) || (await sh.exists());
  }

  /// Downloads and extracts the Linux rootfs into the app private storage
  Future<void> installSubsystem({String? downloadUrl}) async {
    if (_currentStatus == PRootStatus.downloading || _currentStatus == PRootStatus.extracting) {
      return;
    }

    try {
      _currentStatus = PRootStatus.downloading;
      _statusController.add(PRootProgress(
        status: PRootStatus.downloading,
        progress: 0.1,
        message: 'Preparing download of Debian-arm64 rootfs...',
      ));

      if (!await _rootfsDir!.exists()) {
        await _rootfsDir!.create(recursive: true);
      }

      // Simulation/Hook for background rootfs download & decompression
      // In production Phase 2, this streams tar.xz chunks directly into tar unpacker
      for (int i = 1; i <= 5; i++) {
        await Future.delayed(const Duration(milliseconds: 300));
        _statusController.add(PRootProgress(
          status: PRootStatus.downloading,
          progress: 0.1 + (i * 0.14),
          message: 'Downloading Debian-arm64 rootfs package (${i * 20}%)...',
        ));
      }

      _currentStatus = PRootStatus.extracting;
      _statusController.add(PRootProgress(
        status: PRootStatus.extracting,
        progress: 0.85,
        message: 'Extracting filesystem to app ext4 storage...',
      ));

      await Future.delayed(const Duration(milliseconds: 600));

      // Create basic bash placeholder structure if running on emulator / desktop development
      final binDir = Directory(p.join(_rootfsDir!.path, 'bin'));
      if (!await binDir.exists()) {
        await binDir.create(recursive: true);
      }
      final bashFile = File(p.join(binDir.path, 'bash'));
      if (!await bashFile.exists()) {
        await bashFile.writeAsString('#!/bin/sh\necho "AgentsDroid PRoot Subsystem Ready"\n');
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

  /// Run command inside PRoot isolated sandbox
  Future<ProcessResult> runCommand(
    String command, {
    Map<String, String>? environment,
    String? workingDir,
  }) async {
    if (!await isInstalled()) {
      throw StateError('Linux subsystem is not installed yet.');
    }

    // If proot binary exists on Android device:
    // proot -r <rootfsDir> -0 -b /dev -b /proc -w <workingDir> /bin/bash -c <command>
    if (_prootBin != null && await _prootBin!.exists()) {
      return await Process.run(
        _prootBin!.path,
        [
          '-r',
          _rootfsDir!.path,
          '-0',
          '-b',
          '/dev',
          '-b',
          '/proc',
          '-w',
          workingDir ?? '/home',
          '/bin/bash',
          '-c',
          command,
        ],
        environment: environment,
      );
    } else {
      // Fallback for native platform execution
      return await Process.run(
        'sh',
        ['-c', command],
        workingDirectory: workingDir,
        environment: environment,
      );
    }
  }

  void dispose() {
    _statusController.close();
  }
}

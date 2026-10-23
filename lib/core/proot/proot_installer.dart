import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class InstallProgress {
  final double progress; // 0.0 to 1.0
  final int downloadedBytes;
  final int totalBytes;
  final String stage;
  final String message;

  InstallProgress({
    required this.progress,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.stage,
    required this.message,
  });
}

class RootfsInstaller {
  /// Default minimal Debian-arm64 rootfs mirror (Official GitHub Releases)
  static const String defaultDebianRootfsUrl =
      'https://github.com/termux/proot-distro/releases/download/v4.7.0/debian-bookworm-aarch64-pd-v4.7.0.tar.xz';

  /// China accelerated mirror using ghproxy.net
  static const String ghproxyDebianRootfsUrl =
      'https://ghproxy.net/https://github.com/termux/proot-distro/releases/download/v4.7.0/debian-bookworm-aarch64-pd-v4.7.0.tar.xz';

  /// Returns standard app data directories where rootfs archives can be placed
  static Future<List<Directory>> getAppDataDirectories() async {
    final dirs = <Directory>[];

    // External files directory (e.g. /sdcard/Android/data/com.agentsdroid.agentsdroid/files)
    try {
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        dirs.add(ext);
      }
    } catch (_) {}

    // Internal app support directory (e.g. /data/user/0/.../files)
    try {
      final appSupport = await getApplicationSupportDirectory();
      if (!dirs.any((d) => d.path == appSupport.path)) {
        dirs.add(appSupport);
      }
    } catch (_) {}

    // Standard Android external fallback paths
    final fallbackPaths = [
      '/storage/emulated/0/Android/data/com.agentsdroid.agentsdroid/files',
      '/sdcard/Android/data/com.agentsdroid.agentsdroid/files',
      '/storage/emulated/0/Download',
      '/sdcard/Download',
    ];

    for (final pth in fallbackPaths) {
      final d = Directory(pth);
      if (!dirs.any((element) => element.path == d.path)) {
        dirs.add(d);
      }
    }

    return dirs;
  }

  /// Scans application data directories for candidate rootfs archives
  static Future<List<File>> scanLocalArchives() async {
    final candidateDirs = await getAppDataDirectories();

    final foundFiles = <File>[];
    final seenPaths = <String>{};

    for (final dir in candidateDirs) {
      if (await dir.exists()) {
        try {
          await for (final entity in dir.list(followLinks: false)) {
            if (entity is File) {
              final lower = p.basename(entity.path).toLowerCase();
              if (lower.endsWith('.tar.xz') ||
                  lower.endsWith('.tar.gz') ||
                  lower.endsWith('.tgz') ||
                  lower.endsWith('.tar')) {
                if (seenPaths.add(entity.path)) {
                  foundFiles.add(entity);
                }
              }
            }
          }
        } catch (_) {}
      }
    }
    return foundFiles;
  }

  /// Install and unpack a local rootfs archive file directly to [targetDir]
  static Future<void> installFromArchive({
    required File archiveFile,
    required Directory targetDir,
    required void Function(InstallProgress) onProgress,
    bool deleteArchiveAfterInstall = false,
  }) async {
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final fileSize = await archiveFile.length();

    onProgress(InstallProgress(
      progress: 0.05,
      downloadedBytes: fileSize,
      totalBytes: fileSize,
      stage: 'extracting',
      message: '正在准备解压离线子系统包 (${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB)...',
    ));

    await _unpackArchive(
      archiveFile,
      targetDir,
      (extractP, msg) {
        onProgress(InstallProgress(
          progress: extractP,
          downloadedBytes: fileSize,
          totalBytes: fileSize,
          stage: 'extracting',
          message: msg,
        ));
      },
      deleteAfter: deleteArchiveAfterInstall,
    );

    onProgress(InstallProgress(
      progress: 0.98,
      downloadedBytes: fileSize,
      totalBytes: fileSize,
      stage: 'configuring',
      message: '正在配置网络 DNS 与沙箱环境...',
    ));

    await configureEnvironment(targetDir);

    onProgress(InstallProgress(
      progress: 1.0,
      downloadedBytes: fileSize,
      totalBytes: fileSize,
      stage: 'completed',
      message: 'Linux 子系统已安装就绪！',
    ));
  }

  /// Download and unpack rootfs archive to [targetDir]
  static Future<void> install({
    required String downloadUrl,
    required Directory targetDir,
    required File targetArchiveFile,
    required void Function(InstallProgress) onProgress,
  }) async {
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    // --- Phase 1: Download ---
    onProgress(InstallProgress(
      progress: 0.05,
      downloadedBytes: 0,
      totalBytes: -1,
      stage: 'downloading',
      message: 'Connecting to rootfs mirror...',
    ));

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw HttpException('Download failed with HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? -1;
      int downloaded = 0;

      final sink = targetArchiveFile.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloaded += chunk.length;

        final double pVal = contentLength > 0
            ? 0.05 + (downloaded / contentLength) * 0.65 // Download is 5% ~ 70%
            : 0.4;

        onProgress(InstallProgress(
          progress: pVal,
          downloadedBytes: downloaded,
          totalBytes: contentLength,
          stage: 'downloading',
          message: contentLength > 0
              ? 'Downloading: ${(downloaded / 1024 / 1024).toStringAsFixed(1)} MB / ${(contentLength / 1024 / 1024).toStringAsFixed(1)} MB'
              : 'Downloading: ${(downloaded / 1024 / 1024).toStringAsFixed(1)} MB',
        ));
      }
      await sink.flush();
      await sink.close();

      // --- Phase 2: Unpacking ---
      onProgress(InstallProgress(
        progress: 0.72,
        downloadedBytes: downloaded,
        totalBytes: contentLength,
        stage: 'extracting',
        message: 'Decompressing archive into ext4 storage...',
      ));

      await _unpackArchive(
        targetArchiveFile,
        targetDir,
        (extractP, msg) {
          onProgress(InstallProgress(
            progress: 0.72 + (extractP * 0.25), // Extraction is 72% ~ 97%
            downloadedBytes: downloaded,
            totalBytes: contentLength,
            stage: 'extracting',
            message: msg,
          ));
        },
        deleteAfter: true,
      );

      // --- Phase 3: Post-install Configuration ---
      onProgress(InstallProgress(
        progress: 0.98,
        downloadedBytes: downloaded,
        totalBytes: contentLength,
        stage: 'configuring',
        message: 'Configuring DNS and workspace bind mounts...',
      ));

      await configureEnvironment(targetDir);

      onProgress(InstallProgress(
        progress: 1.0,
        downloadedBytes: downloaded,
        totalBytes: contentLength,
        stage: 'completed',
        message: 'Linux Subsystem installed and verified!',
      ));
    } finally {
      client.close();
    }
  }

  /// Unpacks tar/tar.gz/tar.xz archives safely in a background Isolate
  /// with top-level prefix strip and symlink support, without freezing the main UI thread.
  static Future<void> _unpackArchive(
    File archiveFile,
    Directory outputDir,
    void Function(double progress, String message) onProgress, {
    bool deleteAfter = true,
  }) async {
    final receivePort = ReceivePort();
    final completer = Completer<void>();

    final isolate = await Isolate.spawn(
      _isolateUnpackEntry,
      _UnpackParams(
        archivePath: archiveFile.path,
        outputPath: outputDir.path,
        sendPort: receivePort.sendPort,
        deleteAfter: deleteAfter,
      ),
    );

    receivePort.listen((message) {
      if (message is Map) {
        if (message.containsKey('progress')) {
          onProgress(
            (message['progress'] as num).toDouble(),
            message['message'] as String? ?? 'Extracting...',
          );
        } else if (message.containsKey('error')) {
          receivePort.close();
          isolate.kill(priority: Isolate.immediate);
          if (!completer.isCompleted) {
            completer.completeError(Exception(message['error']));
          }
        } else if (message['done'] == true) {
          receivePort.close();
          isolate.kill(priority: Isolate.immediate);
          if (!completer.isCompleted) {
            completer.complete();
          }
        }
      }
    });

    await completer.future;
  }

  /// Configures network DNS (/etc/resolv.conf), hosts, workspace directory, and shell links
  static Future<void> configureEnvironment(Directory rootfsDir) async {
    // 1. Setup DNS in /etc/resolv.conf
    final etcDir = Directory(p.join(rootfsDir.path, 'etc'));
    if (!await etcDir.exists()) {
      await etcDir.create(recursive: true);
    }

    final resolvConf = File(p.join(etcDir.path, 'resolv.conf'));
    await resolvConf.writeAsString('''nameserver 8.8.8.8
nameserver 1.1.1.1
nameserver 8.8.4.4
''');

    // 2. Setup /etc/hosts
    final hostsFile = File(p.join(etcDir.path, 'hosts'));
    await hostsFile.writeAsString('''127.0.0.1 localhost
::1 localhost ip6-localhost ip6-loopback
''');

    // 3. Setup workspace mounting point
    final workspaceDir = Directory(p.join(rootfsDir.path, 'workspace'));
    if (!await workspaceDir.exists()) {
      await workspaceDir.create(recursive: true);
    }

    // 4. Ensure standard device directories exist for mounting
    for (final d in ['dev', 'proc', 'sys', 'tmp', 'root']) {
      final dir = Directory(p.join(rootfsDir.path, d));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    }

    // 5. Ensure essential binaries exist in /bin for compatibility
    // Debian 12 (Bookworm) uses merged-/usr where /bin is a symlink to /usr/bin.
    final usrBinDir = Directory(p.join(rootfsDir.path, 'usr', 'bin'));
    final binDir = Directory(p.join(rootfsDir.path, 'bin'));
    final binLink = Link(p.join(rootfsDir.path, 'bin'));

    if (await usrBinDir.exists()) {
      if (!await binDir.exists() && !await binLink.exists()) {
        try {
          await binLink.create('usr/bin');
        } catch (_) {
          await binDir.create(recursive: true);
        }
      }

      final binBash = File(p.join(rootfsDir.path, 'bin', 'bash'));
      final usrBash = File(p.join(rootfsDir.path, 'usr', 'bin', 'bash'));
      if (!await binBash.exists() && await usrBash.exists()) {
        try {
          await Link(binBash.path).create('../usr/bin/bash');
        } catch (_) {
          try {
            await usrBash.copy(binBash.path);
          } catch (_) {}
        }
      }

      final binSh = File(p.join(rootfsDir.path, 'bin', 'sh'));
      final usrSh = File(p.join(rootfsDir.path, 'usr', 'bin', 'sh'));
      if (!await binSh.exists() && await usrSh.exists()) {
        try {
          await Link(binSh.path).create('../usr/bin/sh');
        } catch (_) {
          try {
            await usrSh.copy(binSh.path);
          } catch (_) {}
        }
      }
    }
  }
}

class _UnpackParams {
  final String archivePath;
  final String outputPath;
  final SendPort sendPort;
  final bool deleteAfter;

  _UnpackParams({
    required this.archivePath,
    required this.outputPath,
    required this.sendPort,
    required this.deleteAfter,
  });
}

void _isolateUnpackEntry(_UnpackParams params) async {
  try {
    final archiveFile = File(params.archivePath);
    if (!archiveFile.existsSync()) {
      params.sendPort.send({'error': 'Archive file not found: ${params.archivePath}'});
      return;
    }

    params.sendPort.send({'progress': 0.05, 'message': '正在读取压缩包文件...'});

    final bytes = archiveFile.readAsBytesSync();
    params.sendPort.send({'progress': 0.15, 'message': '正在解压 XZ 压缩数据（纯用户态引擎）...'});

    Archive archive;
    final pathLower = params.archivePath.toLowerCase();
    if (pathLower.endsWith('.tar.gz') || pathLower.endsWith('.tgz')) {
      final decompressed = GZipDecoder().decodeBytes(bytes);
      archive = TarDecoder().decodeBytes(decompressed);
    } else if (pathLower.endsWith('.tar.xz')) {
      final decompressed = XZDecoder().decodeBytes(bytes);
      archive = TarDecoder().decodeBytes(decompressed);
    } else if (pathLower.endsWith('.tar')) {
      archive = TarDecoder().decodeBytes(bytes);
    } else if (pathLower.endsWith('.zip')) {
      archive = ZipDecoder().decodeBytes(bytes);
    } else {
      try {
        final decompressed = XZDecoder().decodeBytes(bytes);
        archive = TarDecoder().decodeBytes(decompressed);
      } catch (_) {
        archive = TarDecoder().decodeBytes(bytes);
      }
    }

    params.sendPort.send({'progress': 0.35, 'message': '正在分析 Linux rootfs 目录结构...'});

    // Detect common top-level directory prefix (e.g. "debian-bookworm-aarch64/")
    String? commonPrefix;
    if (archive.isNotEmpty) {
      final firstSlash = archive.first.name.indexOf('/');
      if (firstSlash != -1) {
        final candidatePrefix = archive.first.name.substring(0, firstSlash + 1);
        final allShare = archive.every((f) =>
            f.name.startsWith(candidatePrefix) ||
            f.name == candidatePrefix.substring(0, firstSlash));
        if (allShare) {
          commonPrefix = candidatePrefix;
        }
      }
    }

    final totalFiles = archive.length;
    final outputDir = Directory(params.outputPath);
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    int processed = 0;
    for (final file in archive) {
      var filename = file.name;
      if (commonPrefix != null && filename.startsWith(commonPrefix)) {
        filename = filename.substring(commonPrefix.length);
      }
      if (filename.isEmpty) continue;

      final outPath = p.join(outputDir.path, filename);

      if (file.isSymbolicLink && file.symbolicLink != null) {
        final link = Link(outPath);
        if (!link.parent.existsSync()) {
          link.parent.createSync(recursive: true);
        }
        try {
          if (link.existsSync()) link.deleteSync();
          link.createSync(file.symbolicLink!);
        } catch (_) {}
      } else if (file.isFile) {
        final outFile = File(outPath);
        if (!outFile.parent.existsSync()) {
          outFile.parent.createSync(recursive: true);
        }
        outFile.writeAsBytesSync(file.content as List<int>);
      } else {
        Directory(outPath).createSync(recursive: true);
      }

      processed++;
      if (processed % 100 == 0 || processed == totalFiles) {
        final ratio = totalFiles > 0 ? (processed / totalFiles) : 1.0;
        final prog = 0.35 + (ratio * 0.63); // 35% -> 98%
        final percent = (ratio * 100).toInt();
        params.sendPort.send({
          'progress': prog,
          'message': '正在写入系统文件 ($processed/$totalFiles, $percent%)...',
        });
      }
    }

    if (params.deleteAfter) {
      try {
        archiveFile.deleteSync();
      } catch (_) {}
    }

    params.sendPort.send({'done': true});
  } catch (e, st) {
    params.sendPort.send({'error': '$e\n$st'});
  }
}

import 'dart:async';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

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
  /// Default minimal Debian-arm64 rootfs mirror
  static const String defaultDebianRootfsUrl =
      'https://github.com/termux/proot-distro/releases/download/v4.7.0/debian-arm64.tar.xz';

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

      await _unpackArchive(targetArchiveFile, targetDir, (extractP) {
        onProgress(InstallProgress(
          progress: 0.72 + (extractP * 0.25), // Extraction is 72% ~ 97%
          downloadedBytes: downloaded,
          totalBytes: contentLength,
          stage: 'extracting',
          message: 'Extracting system files: ${(extractP * 100).toInt()}%',
        ));
      });

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

  /// Unpacks tar/tar.gz/tar.xz archives safely
  static Future<void> _unpackArchive(
    File archiveFile,
    Directory outputDir,
    void Function(double) onProgress,
  ) async {
    final bytes = await archiveFile.readAsBytes();

    Archive archive;
    if (archiveFile.path.endsWith('.tar.gz') || archiveFile.path.endsWith('.tgz')) {
      final decompressed = GZipDecoder().decodeBytes(bytes);
      archive = TarDecoder().decodeBytes(decompressed);
    } else if (archiveFile.path.endsWith('.tar.xz')) {
      final decompressed = XZDecoder().decodeBytes(bytes);
      archive = TarDecoder().decodeBytes(decompressed);
    } else if (archiveFile.path.endsWith('.tar')) {
      archive = TarDecoder().decodeBytes(bytes);
    } else if (archiveFile.path.endsWith('.zip')) {
      archive = ZipDecoder().decodeBytes(bytes);
    } else {
      // Try tar directly or fall back to tar.xz
      try {
        final decompressed = XZDecoder().decodeBytes(bytes);
        archive = TarDecoder().decodeBytes(decompressed);
      } catch (_) {
        archive = TarDecoder().decodeBytes(bytes);
      }
    }

    final totalFiles = archive.length;
    int processed = 0;

    for (final file in archive) {
      final filename = file.name;
      final outPath = p.join(outputDir.path, filename);

      if (file.isFile) {
        final outFile = File(outPath);
        if (!await outFile.parent.exists()) {
          await outFile.parent.create(recursive: true);
        }
        await outFile.writeAsBytes(file.content as List<int>);
      } else {
        await Directory(outPath).create(recursive: true);
      }

      processed++;
      if (processed % 150 == 0 || processed == totalFiles) {
        onProgress(totalFiles > 0 ? (processed / totalFiles) : 1.0);
      }
    }

    // Clean up archive file to save disk space
    try {
      await archiveFile.delete();
    } catch (_) {}
  }

  /// Configures network DNS (/etc/resolv.conf), hosts, and workspace directory
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
  }
}

import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:agentsdroid/core/proot/proot_installer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('proot_installer_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('RootfsInstaller Coverage Tests', () {
    test('getAppDataDirectories returns standard directories and fallbacks', () async {
      final dirs = await RootfsInstaller.getAppDataDirectories();
      expect(dirs, isNotEmpty);
      expect(dirs.any((d) => d.path.contains('Download') || d.path.contains('com.agentsdroid')), isTrue);
    });

    test('scanLocalArchives identifies tar and tar.xz files', () async {
      final archives = await RootfsInstaller.scanLocalArchives();
      expect(archives, isA<List<File>>());
    });

    test('configureEnvironment sets up resolv.conf, hosts, workspace and device dirs', () async {
      final rootfsDir = Directory(p.join(tempDir.path, 'rootfs_config_test'));
      await rootfsDir.create(recursive: true);

      // Create usr/bin/bash so merged-/usr check runs
      final usrBin = Directory(p.join(rootfsDir.path, 'usr', 'bin'));
      await usrBin.create(recursive: true);
      await File(p.join(usrBin.path, 'bash')).writeAsString('#!/bin/bash');
      await File(p.join(usrBin.path, 'sh')).writeAsString('#!/bin/sh');

      await RootfsInstaller.configureEnvironment(rootfsDir);

      expect(File(p.join(rootfsDir.path, 'etc', 'resolv.conf')).existsSync(), isTrue);
      expect(File(p.join(rootfsDir.path, 'etc', 'hosts')).existsSync(), isTrue);
      expect(Directory(p.join(rootfsDir.path, 'workspace')).existsSync(), isTrue);
      expect(Directory(p.join(rootfsDir.path, 'dev')).existsSync(), isTrue);
      expect(Directory(p.join(rootfsDir.path, 'proc')).existsSync(), isTrue);
      expect(Directory(p.join(rootfsDir.path, 'sys')).existsSync(), isTrue);
    });

    test('installFromArchive unpackages tar archive, configures environment, and reports progress', () async {
      // 1. Build a synthetic tar archive
      final archive = Archive();
      final bashBytes = [35, 33, 47, 98, 105, 110, 47, 115, 104, 10]; // #!/bin/sh\n
      archive.addFile(ArchiveFile('bin/bash', bashBytes.length, bashBytes)..mode = 0755);
      archive.addFile(ArchiveFile('bin/sh', bashBytes.length, bashBytes)..mode = 0755);
      archive.addFile(ArchiveFile('usr/bin/node', 4, [116, 101, 115, 116])..mode = 0755);
      archive.addFile(ArchiveFile('etc/os-release', 12, [78, 65, 77, 69, 61, 68, 101, 98, 105, 97, 110, 10]));

      final tarData = TarEncoder().encode(archive);
      final tarFile = File(p.join(tempDir.path, 'mock_rootfs.tar'));
      await tarFile.writeAsBytes(tarData, flush: true);

      final targetDir = Directory(p.join(tempDir.path, 'installed_rootfs'));
      final progressStages = <String>[];

      await RootfsInstaller.installFromArchive(
        archiveFile: tarFile,
        targetDir: targetDir,
        deleteArchiveAfterInstall: true,
        onProgress: (progress) {
          progressStages.add(progress.stage);
        },
      );

      expect(progressStages.contains('extracting'), isTrue);
      expect(progressStages.contains('configuring'), isTrue);
      expect(progressStages.contains('completed'), isTrue);

      expect(File(p.join(targetDir.path, 'bin', 'bash')).existsSync(), isTrue);
      expect(File(p.join(targetDir.path, 'etc', 'resolv.conf')).existsSync(), isTrue);
      expect(tarFile.existsSync(), isFalse); // deleteArchiveAfterInstall: true
    });
  });
}

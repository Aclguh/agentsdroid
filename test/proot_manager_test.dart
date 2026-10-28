import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

import 'package:agentsdroid/core/proot/proot_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late PRootManager manager;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('proot_manager_test_');
    manager = PRootManager();
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('PRootManager Initialization and Lifecycle Tests', () {
    test('accessing rootfsDir before init throws StateError', () {
      expect(() => manager.rootfsDir, throwsA(isA<StateError>()));
    });

    test('init with uninstalled directory sets PRootStatus.notInstalled', () async {
      final statuses = <PRootProgress>[];
      final sub = manager.statusStream.listen(statuses.add);

      await manager.init(appSupportDir: tempDir, workspacePath: '/test/workspace');

      expect(manager.currentStatus, equals(PRootStatus.notInstalled));
      expect(await manager.isInstalled(), isFalse);
      expect(statuses.any((s) => s.status == PRootStatus.notInstalled), isTrue);

      await sub.cancel();
    });

    test('findEffectiveRootfsDir finds direct and nested rootfs structures', () async {
      await manager.init(appSupportDir: tempDir);

      // 1. Empty rootfs dir -> returns null
      expect(await manager.findEffectiveRootfsDir(), isNull);

      // 2. Direct rootfs with bin/sh
      final directBin = Directory(p.join(tempDir.path, 'rootfs', 'bin'));
      await directBin.create(recursive: true);
      final directSh = File(p.join(directBin.path, 'sh'));
      await directSh.writeAsString('#!/bin/sh');

      final effDirect = await manager.findEffectiveRootfsDir();
      expect(effDirect, isNotNull);
      expect(effDirect!.path, equals(p.join(tempDir.path, 'rootfs')));
      expect(await manager.isInstalled(), isTrue);

      // 3. Nested rootfs under rootfs/debian_arm64/usr/bin/bash
      final freshManager = PRootManager();
      await freshManager.init(appSupportDir: tempDir);
      await directBin.delete(recursive: true);
      final nestedDir = Directory(p.join(tempDir.path, 'rootfs', 'debian_arm64', 'usr', 'bin'));
      await nestedDir.create(recursive: true);
      final nestedBash = File(p.join(nestedDir.path, 'bash'));
      await nestedBash.writeAsString('#!/bin/bash');

      final effNested = await freshManager.findEffectiveRootfsDir();
      expect(effNested, isNotNull);
      expect(effNested!.path, equals(p.join(tempDir.path, 'rootfs', 'debian_arm64')));
      expect(freshManager.rootfsDir.path, equals(effNested.path));
    });

    test('execution methods throw StateError when subsystem is not installed', () async {
      await manager.init(appSupportDir: tempDir);
      expect(await manager.isInstalled(), isFalse);

      expect(() => manager.runCommand('ls'), throwsA(isA<StateError>()));
      expect(() => manager.runCommandArgs(['ls', '-la']), throwsA(isA<StateError>()));
      expect(
        () => manager.runStreamingCommand('ls', onOutput: (_) {}),
        throwsA(isA<StateError>()),
      );
      expect(() => manager.startProcess('ls'), throwsA(isA<StateError>()));
      expect(() => manager.startProcessArgs(['ls']), throwsA(isA<StateError>()));
    });

    test('mock install initializes minimal rootfs and enables execution', () async {
      final statuses = <PRootProgress>[];
      final sub = manager.statusStream.listen(statuses.add);

      await manager.init(appSupportDir: tempDir, workspacePath: tempDir.path);
      await manager.installSubsystem(mockForDev: true);

      expect(manager.currentStatus, equals(PRootStatus.ready));
      expect(await manager.isInstalled(), isTrue);
      expect(statuses.any((s) => s.status == PRootStatus.ready), isTrue);

      final binDir = Directory(p.join(tempDir.path, 'rootfs', 'bin'));
      expect(File(p.join(binDir.path, 'bash')).existsSync(), isTrue);
      expect(File(p.join(binDir.path, 'sh')).existsSync(), isTrue);

      await sub.cancel();
    });

    test('uninstallSubsystem deletes rootfs and transitions to notInstalled', () async {
      await manager.init(appSupportDir: tempDir);
      await manager.installSubsystem(mockForDev: true);
      expect(await manager.isInstalled(), isTrue);

      final statuses = <PRootProgress>[];
      final sub = manager.statusStream.listen(statuses.add);

      await manager.uninstallSubsystem();

      expect(manager.currentStatus, equals(PRootStatus.notInstalled));
      expect(await manager.isInstalled(), isFalse);
      expect(Directory(p.join(tempDir.path, 'rootfs')).existsSync(), isFalse);
      expect(statuses.any((s) => s.status == PRootStatus.notInstalled), isTrue);

      await sub.cancel();
    });

    test('checkToolchains returns empty toolchains when subsystem not installed', () async {
      await manager.init(appSupportDir: tempDir);
      final status = await manager.checkToolchains();

      expect(status.hasNode, isFalse);
      expect(status.hasPython, isFalse);
      expect(status.hasGit, isFalse);
      expect(status.hasClaudeCode, isFalse);
      expect(status.nodeVersion, isNull);
    });

    test('PRootProgress and ToolchainStatus data models work correctly', () {
      final progress = PRootProgress(
        status: PRootStatus.downloading,
        progress: 0.5,
        message: 'Downloading...',
        downloadedBytes: 500,
        totalBytes: 1000,
      );
      expect(progress.status, equals(PRootStatus.downloading));
      expect(progress.progress, equals(0.5));
      expect(progress.downloadedBytes, equals(500));
      expect(progress.totalBytes, equals(1000));

      final toolchain = ToolchainStatus(
        nodeVersion: 'v20.10.0',
        npmVersion: '10.2.3',
        pythonVersion: 'Python 3.11.2',
        gitVersion: 'git version 2.39.2',
        claudeCodeVersion: '0.2.9',
      );
      expect(toolchain.hasNode, isTrue);
      expect(toolchain.hasPython, isTrue);
      expect(toolchain.hasGit, isTrue);
      expect(toolchain.hasClaudeCode, isTrue);
      expect(toolchain.npmVersion, equals('10.2.3'));
    });
  });

  group('PRoot Binary Detection and Deployment Tests', () {
    test('detectAndroidAbi returns valid ABI identifier', () async {
      final abi = await PRootManager.detectAndroidAbi();
      expect(abi, isNotEmpty);
      expect(PRootManager.defaultProotUrls.containsKey('arm64-v8a'), isTrue);
    });

    test('hasProotBinary is false when binary does not exist', () async {
      await manager.init(appSupportDir: tempDir);
      expect(manager.hasProotBinary, isFalse);
      expect(manager.binDirectory, isNotNull);
    });

    test('ensureProotBinary copies binary from local native library candidate', () async {
      await manager.init(appSupportDir: tempDir);

      // Create a mock native library candidate
      final mockLibDir = Directory(p.join(tempDir.path, 'mock_lib'));
      await mockLibDir.create(recursive: true);
      final mockLibProot = File(p.join(mockLibDir.path, 'libproot.so'));
      await mockLibProot.writeAsString('MOCK_ELF_PROOT_BINARY_CONTENT');

      final deployed = await manager.ensureProotBinary(
        nativeLibCandidates: [mockLibProot.path],
      );

      expect(deployed, isNotNull);
      expect(deployed!.existsSync(), isTrue);
      expect(manager.hasProotBinary, isTrue);
      expect(await deployed.readAsString(), equals('MOCK_ELF_PROOT_BINARY_CONTENT'));
    });

    test('ensureProotBinary downloads binary via http when candidate absent', () async {
      await manager.init(appSupportDir: tempDir);

      final mockClient = MockClient((request) async {
        if (request.url.toString().contains('mock-proot')) {
          return http.Response.bytes(utf8.encode('DOWNLOADED_PROOT_BINARY_BYTES'), 200);
        }
        return http.Response('Not Found', 404);
      });

      final deployed = await manager.ensureProotBinary(
        customDownloadUrl: 'https://example.com/mock-proot',
        httpClient: mockClient,
        nativeLibCandidates: [], // No candidates
      );

      expect(deployed, isNotNull);
      expect(deployed!.existsSync(), isTrue);
      expect(manager.hasProotBinary, isTrue);
      expect(await deployed.readAsString(), equals('DOWNLOADED_PROOT_BINARY_BYTES'));
    });

    test('ensureProotBinary returns existing binary without redownloading', () async {
      await manager.init(appSupportDir: tempDir);

      // Pre-populate proot in binDir
      final binDir = manager.binDirectory!;
      final prootFile = File(p.join(binDir.path, 'proot'));
      await prootFile.writeAsString('EXISTING_PROOT_BINARY');

      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        return http.Response('should not be called', 500);
      });

      final result = await manager.ensureProotBinary(
        customDownloadUrl: 'https://example.com/mock-proot',
        httpClient: mockClient,
      );

      expect(result, isNotNull);
      expect(requestCount, equals(0));
      expect(await result!.readAsString(), equals('EXISTING_PROOT_BINARY'));
    });
  });
}

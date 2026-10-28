import 'package:flutter_test/flutter_test.dart';
import 'package:agentsdroid/core/storage/workspace_service.dart';
import 'package:agentsdroid/models/agent_event.dart';

void main() {
  late WorkspaceService service;

  setUp(() {
    service = WorkspaceService();
  });

  group('WorkspaceService Myers Diff Algorithm Tests', () {
    test('computes diff for identical strings', () {
      const content = 'line 1\nline 2\nline 3';
      final diff = service.computeDiff('test.txt', content, content);

      expect(diff.filePath, equals('test.txt'));
      expect(diff.diffLines.length, equals(3));
      for (final line in diff.diffLines) {
        expect(line.type, equals(DiffLineType.unchanged));
      }
      expect(diff.diffLines[0].oldLineNumber, equals(1));
      expect(diff.diffLines[0].newLineNumber, equals(1));
      expect(diff.diffLines[2].oldLineNumber, equals(3));
      expect(diff.diffLines[2].newLineNumber, equals(3));
    });

    test('computes diff for pure insertions', () {
      const orig = 'line 1\nline 3';
      const modified = 'line 1\nline 2\nline 3';
      final diff = service.computeDiff('test.txt', orig, modified);

      expect(diff.diffLines.length, equals(3));
      expect(diff.diffLines[0].type, equals(DiffLineType.unchanged));
      expect(diff.diffLines[0].text, equals('line 1'));

      expect(diff.diffLines[1].type, equals(DiffLineType.added));
      expect(diff.diffLines[1].text, equals('line 2'));
      expect(diff.diffLines[1].oldLineNumber, isNull);
      expect(diff.diffLines[1].newLineNumber, equals(2));

      expect(diff.diffLines[2].type, equals(DiffLineType.unchanged));
      expect(diff.diffLines[2].text, equals('line 3'));
      expect(diff.diffLines[2].oldLineNumber, equals(2));
      expect(diff.diffLines[2].newLineNumber, equals(3));
    });

    test('computes diff for pure deletions', () {
      const orig = 'line 1\nline 2\nline 3';
      const modified = 'line 1\nline 3';
      final diff = service.computeDiff('test.txt', orig, modified);

      expect(diff.diffLines.length, equals(3));
      expect(diff.diffLines[0].type, equals(DiffLineType.unchanged));

      expect(diff.diffLines[1].type, equals(DiffLineType.removed));
      expect(diff.diffLines[1].text, equals('line 2'));
      expect(diff.diffLines[1].oldLineNumber, equals(2));
      expect(diff.diffLines[1].newLineNumber, isNull);

      expect(diff.diffLines[2].type, equals(DiffLineType.unchanged));
      expect(diff.diffLines[2].oldLineNumber, equals(3));
      expect(diff.diffLines[2].newLineNumber, equals(2));
    });

    test('computes diff for modifications (classic Myers sequence)', () {
      // Classic Myers: ABCABBA -> CBABAC
      final orig = ['A', 'B', 'C', 'A', 'B', 'B', 'A'].join('\n');
      final current = ['C', 'B', 'A', 'B', 'A', 'C'].join('\n');
      final diff = service.computeDiff('myers.txt', orig, current);

      final types = diff.diffLines.map((e) => e.type).toList();

      expect(types, contains(DiffLineType.removed));
      expect(types, contains(DiffLineType.added));
      expect(types, contains(DiffLineType.unchanged));

      // Reconstructed from diff:
      // Removed lines from orig:
      final removed = diff.diffLines
          .where((l) => l.type == DiffLineType.removed)
          .map((l) => l.text)
          .toList();
      // Added lines to new:
      final added = diff.diffLines
          .where((l) => l.type == DiffLineType.added)
          .map((l) => l.text)
          .toList();

      expect(removed, isNotEmpty);
      expect(added, isNotEmpty);
    });

    test('efficiently processes large file diffs in linear time', () {
      final bigOrig = List.generate(5000, (i) => 'Line $i').join('\n');
      final bigNewList = List.generate(5000, (i) => 'Line $i');
      bigNewList[100] = 'Modified Line 100';
      bigNewList.insert(2500, 'Inserted at 2500');
      final bigNew = bigNewList.join('\n');

      final sw = Stopwatch()..start();
      final diff = service.computeDiff('big.txt', bigOrig, bigNew);
      sw.stop();

      expect(diff.diffLines.length, equals(5002));
      expect(sw.elapsedMilliseconds, lessThan(2000),
          reason: 'Myers diff with common prefix/suffix must complete in under 2s for 5000 lines');
    });
  });
}

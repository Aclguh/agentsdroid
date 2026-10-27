import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agentsdroid/l10n/app_localizations.dart';
import 'package:agentsdroid/models/agent_event.dart';
import 'package:agentsdroid/ui/diff/diff_viewer_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestableWidget(DiffEvent diff, {Locale locale = const Locale('zh')}) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh'), Locale('en')],
      home: DiffViewerScreen(diff: diff),
    );
  }

  testWidgets('DiffViewerScreen renders header, counts, and diff lines correctly (ZH)', (tester) async {
    final diff = DiffEvent(
      filePath: 'lib/example.dart',
      originalContent: 'void main() {\n  print("old");\n}',
      newContent: 'void main() {\n  print("new 1");\n  print("new 2");\n}',
      diffLines: [
        DiffLine(type: DiffLineType.unchanged, text: 'void main() {', oldLineNumber: 1, newLineNumber: 1),
        DiffLine(type: DiffLineType.removed, text: '  print("old");', oldLineNumber: 2),
        DiffLine(type: DiffLineType.added, text: '  print("new 1");', newLineNumber: 2),
        DiffLine(type: DiffLineType.added, text: '  print("new 2");', newLineNumber: 3),
        DiffLine(type: DiffLineType.unchanged, text: '}', oldLineNumber: 3, newLineNumber: 4),
      ],
    );

    await tester.pumpWidget(buildTestableWidget(diff));
    await tester.pumpAndSettle();

    // Check title and addition/deletion badges
    expect(find.text('lib/example.dart'), findsOneWidget);
    expect(find.text('+2 '), findsOneWidget);
    expect(find.text('-1'), findsOneWidget);

    // Check line contents
    expect(find.text('void main() {'), findsOneWidget);
    expect(find.text('  print("old");'), findsOneWidget);
    expect(find.text('  print("new 1");'), findsOneWidget);
    expect(find.text('  print("new 2");'), findsOneWidget);

    // Copy button tap
    expect(find.byIcon(Icons.copy), findsOneWidget);
    await tester.tap(find.byIcon(Icons.copy));
    await tester.pump();

    // Verify snackbar appears
    expect(find.text('已复制到剪贴板'), findsOneWidget);
  });

  testWidgets('DiffViewerScreen renders correctly in English', (tester) async {
    final diff = DiffEvent(
      filePath: 'README.md',
      originalContent: '# Old',
      newContent: '# New',
      diffLines: [
        DiffLine(type: DiffLineType.removed, text: '# Old', oldLineNumber: 1),
        DiffLine(type: DiffLineType.added, text: '# New', newLineNumber: 1),
      ],
    );

    await tester.pumpWidget(buildTestableWidget(diff, locale: const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('README.md'), findsOneWidget);
    expect(find.text('+1 '), findsOneWidget);
    expect(find.text('-1'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.copy));
    await tester.pump();
    expect(find.text('Copied to clipboard'), findsOneWidget);
  });
}

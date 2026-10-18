import 'package:flutter/material.dart';
import '../../models/agent_event.dart';

class DiffViewerScreen extends StatelessWidget {
  final DiffEvent diff;

  const DiffViewerScreen({super.key, required this.diff});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final additions = diff.diffLines.where((l) => l.type == DiffLineType.added).length;
    final deletions = diff.diffLines.where((l) => l.type == DiffLineType.removed).length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              diff.filePath,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
            ),
            Row(
              children: [
                Text('+$additions ', style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                Text('-$deletions', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
      body: Container(
        color: const Color(0xFF1E1E1E), // Classic IDE editor dark
        child: ListView.builder(
          itemCount: diff.diffLines.length,
          itemBuilder: (context, index) {
            final line = diff.diffLines[index];
            return _buildDiffLineWidget(line, theme);
          },
        ),
      ),
    );
  }

  Widget _buildDiffLineWidget(DiffLine line, ThemeData theme) {
    Color? bgColor;
    Color textColor = Colors.white70;
    String prefix = ' ';

    if (line.type == DiffLineType.added) {
      bgColor = Colors.green.withValues(alpha: 0.18);
      textColor = const Color(0xFFB5E8A9);
      prefix = '+';
    } else if (line.type == DiffLineType.removed) {
      bgColor = Colors.red.withValues(alpha: 0.18);
      textColor = const Color(0xFFF4A8A8);
      prefix = '-';
    }

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Line Numbers
          SizedBox(
            width: 32,
            child: Text(
              line.oldLineNumber?.toString() ?? '',
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white30, fontSize: 11, fontFamily: 'monospace'),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 32,
            child: Text(
              line.newLineNumber?.toString() ?? '',
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white30, fontSize: 11, fontFamily: 'monospace'),
            ),
          ),
          const SizedBox(width: 8),

          // Prefix (+/-)
          Text(
            prefix,
            style: TextStyle(
              color: line.type == DiffLineType.added
                  ? Colors.greenAccent
                  : (line.type == DiffLineType.removed ? Colors.redAccent : Colors.white30),
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),

          // Code Text
          Expanded(
            child: Text(
              line.text,
              style: TextStyle(
                color: textColor,
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

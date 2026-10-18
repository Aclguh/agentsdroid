import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../models/agent_event.dart';

/// State of the ANSI Stream Parser
enum ParserSection {
  idle,
  thinking,
  toolExecution,
  diff,
  message,
}

/// An intelligent parser that transforms raw ANSI terminal streams into structured [AgentEvent]s.
class AnsiStreamParser {
  final _eventController = StreamController<AgentEvent>.broadcast();
  Stream<AgentEvent> get eventStream => _eventController.stream;

  final _uuid = const Uuid();
  final StringBuffer _lineBuffer = StringBuffer();
  final List<String> _currentDiffLines = [];
  String? _currentDiffFile;

  ParserSection _currentSection = ParserSection.idle;
  String? _currentPendingToolCallId;
  String? _currentToolName;
  Map<String, dynamic>? _currentToolArgs;

  // Regex patterns for ANSI sequences
  static final RegExp _ansiEscapeRegex = RegExp(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])');
  static final RegExp _oscRegex = RegExp(r'\x1B\].*?(?:\x07|\x1B\\)');

  // Regex patterns for Claude Code / CLI structures
  static final RegExp _thinkingStartRegex = RegExp(
    r'(?:[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏*>]|\s)*\b(?:Thinking|Claude is thinking|Reasoning)\b(?:\.{3}|:)?\s*(.*)',
    caseSensitive: false,
  );

  static final RegExp _toolCommandRegex = RegExp(
    r'(?:Running|Executing|Bash|Command):\s*(.+)',
    caseSensitive: false,
  );

  static final RegExp _toolFileReadRegex = RegExp(
    r'(?:Reading|Read|View):\s*(.+)',
    caseSensitive: false,
  );

  static final RegExp _toolFileWriteRegex = RegExp(
    r'(?:Writing to|Writing|Updated|Created|Edited|Patching):\s*(.+)',
    caseSensitive: false,
  );

  static final RegExp _approvalPromptRegex = RegExp(
    r'(?:Do you want to (?:proceed|run|execute)|Allow (?:this|Claude)|Continue\?|Approve).*?(?:\[y\/n\]|\(y\/n\)|\[Y\/n\]|\[y\/N\]|\(yes\/no\))|\[y\/n\]\s*$',
    caseSensitive: false,
  );

  static final RegExp _diffHeaderOldRegex = RegExp(r'^---\s+(?:a\/)?(.+)$');
  static final RegExp _diffHeaderNewRegex = RegExp(r'^\+\+\+\s+(?:b\/)?(.+)$');

  /// Strip all ANSI escape sequences from a string
  static String stripAnsi(String text) {
    if (text.isEmpty) return text;
    return text.replaceAll(_oscRegex, '').replaceAll(_ansiEscapeRegex, '');
  }

  /// Feed incoming raw terminal text chunk (stdout or stderr)
  void feedChunk(String chunk) {
    for (int i = 0; i < chunk.length; i++) {
      final char = chunk[i];
      if (char == '\r') {
        // Carriage return: in interactive terminal, this is often used for spinners.
        // If followed by '\n', handle at '\n'.
        if (i + 1 < chunk.length && chunk[i + 1] == '\n') {
          continue;
        } else {
          // In-line overwrite
          _processLine(_lineBuffer.toString(), isCarriageReturn: true);
          _lineBuffer.clear();
        }
      } else if (char == '\n') {
        _processLine(_lineBuffer.toString(), isCarriageReturn: false);
        _lineBuffer.clear();
      } else {
        _lineBuffer.write(char);
      }
    }

    // Check if the current line buffer has an interactive approval prompt without newline
    final currentBufferClean = stripAnsi(_lineBuffer.toString()).trim();
    if (_approvalPromptRegex.hasMatch(currentBufferClean)) {
      _triggerApproval(currentBufferClean);
      _lineBuffer.clear();
    }
  }

  /// Signal that the stream has finished
  void flush() {
    if (_lineBuffer.isNotEmpty) {
      _processLine(_lineBuffer.toString(), isCarriageReturn: false);
      _lineBuffer.clear();
    }
    _finalizeDiff();
  }

  void _processLine(String rawLine, {required bool isCarriageReturn}) {
    final stripped = stripAnsi(rawLine);
    final cleanLine = stripped.trim();
    if (cleanLine.isEmpty && !stripped.startsWith(' ')) return;

    // 1. Check for Approval Prompt
    if (_approvalPromptRegex.hasMatch(cleanLine)) {
      _triggerApproval(cleanLine);
      return;
    }

    // 2. Check for Diff Headers
    if (_diffHeaderOldRegex.hasMatch(cleanLine)) {
      _finalizeDiff();
      final match = _diffHeaderOldRegex.firstMatch(cleanLine);
      _currentDiffFile = match?.group(1);
      _currentDiffLines.clear();
      _currentDiffLines.add(cleanLine);
      _currentSection = ParserSection.diff;
      return;
    }

    if (_currentSection == ParserSection.diff) {
      if (_diffHeaderNewRegex.hasMatch(cleanLine)) {
        final match = _diffHeaderNewRegex.firstMatch(cleanLine);
        _currentDiffFile ??= match?.group(1);
        _currentDiffLines.add(cleanLine);
        return;
      }

      if (stripped.startsWith('@@') ||
          stripped.startsWith('+') ||
          stripped.startsWith('-') ||
          stripped.startsWith(' ')) {
        _currentDiffLines.add(stripped.trimRight());
        return;
      } else {
        // Diff ended
        _finalizeDiff();
      }
    }

    // 3. Check for Thinking
    final thinkingMatch = _thinkingStartRegex.firstMatch(cleanLine);
    if (thinkingMatch != null) {
      final thoughtContent = thinkingMatch.group(1)?.trim() ?? '';
      _currentSection = ParserSection.thinking;
      _eventController.add(StatusEvent(AgentState.thinking));
      _eventController.add(ThoughtEvent(
        thought: thoughtContent.isNotEmpty ? thoughtContent : 'Claude is analyzing the codebase...',
        isComplete: false,
      ));
      return;
    }

    // 4. Check for Tool Commands (Bash / Run)
    final cmdMatch = _toolCommandRegex.firstMatch(cleanLine);
    if (cmdMatch != null) {
      final cmd = cmdMatch.group(1)!.trim();
      _currentToolName = 'run_command';
      _currentToolArgs = {'command': cmd};
      _currentPendingToolCallId = _uuid.v4();
      _currentSection = ParserSection.toolExecution;

      _eventController.add(StatusEvent(AgentState.executingTool, message: 'Running: $cmd'));
      _eventController.add(ToolCallEvent(
        toolCallId: _currentPendingToolCallId!,
        toolName: 'run_command',
        arguments: {'command': cmd},
        status: ToolCallStatus.executing,
        autoApproved: true,
      ));
      return;
    }

    // 5. Check for File Read
    final readMatch = _toolFileReadRegex.firstMatch(cleanLine);
    if (readMatch != null) {
      final file = readMatch.group(1)!.trim();
      _currentToolName = 'read_file';
      _currentToolArgs = {'path': file};
      _currentPendingToolCallId = _uuid.v4();
      _currentSection = ParserSection.toolExecution;

      _eventController.add(StatusEvent(AgentState.executingTool, message: 'Reading: $file'));
      _eventController.add(ToolCallEvent(
        toolCallId: _currentPendingToolCallId!,
        toolName: 'read_file',
        arguments: {'path': file},
        status: ToolCallStatus.executing,
        autoApproved: true,
      ));
      return;
    }

    // 6. Check for File Write / Edit
    final writeMatch = _toolFileWriteRegex.firstMatch(cleanLine);
    if (writeMatch != null) {
      final file = writeMatch.group(1)!.trim();
      _currentToolName = 'write_file';
      _currentToolArgs = {'path': file};
      _currentPendingToolCallId = _uuid.v4();
      _currentSection = ParserSection.toolExecution;

      _eventController.add(StatusEvent(AgentState.executingTool, message: 'Updating: $file'));
      _eventController.add(ToolCallEvent(
        toolCallId: _currentPendingToolCallId!,
        toolName: 'write_file',
        arguments: {'path': file},
        status: ToolCallStatus.executing,
        autoApproved: true,
      ));
      return;
    }

    // 7. Regular message or output line
    if (!isCarriageReturn) {
      _currentSection = ParserSection.message;
      _eventController.add(MessageEvent(text: cleanLine, isComplete: false));
    }
  }

  void _triggerApproval(String prompt) {
    final toolCallId = _currentPendingToolCallId ?? _uuid.v4();
    final toolName = _currentToolName ?? 'execute_action';
    final args = _currentToolArgs ?? {'prompt': prompt};

    _eventController.add(StatusEvent(AgentState.waitingApproval, message: prompt));
    _eventController.add(ToolCallEvent(
      toolCallId: toolCallId,
      toolName: toolName,
      arguments: args,
      status: ToolCallStatus.pending,
      autoApproved: false,
    ));
  }

  void _finalizeDiff() {
    if (_currentDiffLines.isEmpty || _currentDiffFile == null) {
      _currentDiffLines.clear();
      _currentDiffFile = null;
      return;
    }

    final diffLines = <DiffLine>[];
    final originalSb = StringBuffer();
    final newSb = StringBuffer();

    int oldLine = 1;
    int newLine = 1;

    for (final line in _currentDiffLines) {
      if (line.startsWith('---') || line.startsWith('+++')) {
        continue;
      } else if (line.startsWith('@@')) {
        // Hunk header e.g. @@ -1,5 +1,6 @@
        continue;
      } else if (line.startsWith('-')) {
        final text = line.substring(1);
        originalSb.writeln(text);
        diffLines.add(DiffLine(
          type: DiffLineType.removed,
          text: text,
          oldLineNumber: oldLine++,
        ));
      } else if (line.startsWith('+')) {
        final text = line.substring(1);
        newSb.writeln(text);
        diffLines.add(DiffLine(
          type: DiffLineType.added,
          text: text,
          newLineNumber: newLine++,
        ));
      } else {
        final text = line.startsWith(' ') ? line.substring(1) : line;
        originalSb.writeln(text);
        newSb.writeln(text);
        diffLines.add(DiffLine(
          type: DiffLineType.unchanged,
          text: text,
          oldLineNumber: oldLine++,
          newLineNumber: newLine++,
        ));
      }
    }

    _eventController.add(DiffEvent(
      filePath: _currentDiffFile!,
      originalContent: originalSb.toString(),
      newContent: newSb.toString(),
      diffLines: diffLines,
    ));

    _currentDiffLines.clear();
    _currentDiffFile = null;
    _currentSection = ParserSection.idle;
  }

  void dispose() {
    _eventController.close();
  }
}

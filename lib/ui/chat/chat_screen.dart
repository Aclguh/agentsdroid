import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:uuid/uuid.dart';

import '../../core/builtin/builtin_agent_engine.dart';
import '../../core/proot/proot_manager.dart';
import '../../core/storage/key_vault.dart';
import '../../core/storage/workspace_service.dart';
import '../../l10n/app_localizations.dart';
import '../../models/agent_event.dart';
import '../../models/chat_message.dart';
import '../diff/diff_viewer_screen.dart';
import '../explorer/workspace_explorer_screen.dart';
import '../settings/settings_screen.dart';
import 'widgets/thought_card.dart';
import 'widgets/tool_approval_card.dart';

class ChatScreen extends StatefulWidget {
  final KeyVault keyVault;
  final WorkspaceService workspace;
  final PRootManager prootManager;

  const ChatScreen({
    super.key,
    required this.keyVault,
    required this.workspace,
    required this.prootManager,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final BuiltinAgentEngine _engine;
  StreamSubscription<AgentEvent>? _subscription;

  final List<ChatMessage> _messages = [];
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _uuid = const Uuid();

  AgentState _agentState = AgentState.idle;
  String? _statusMessage;
  ChatMessage? _currentAssistantMessage;

  @override
  void initState() {
    super.initState();
    _engine = BuiltinAgentEngine(widget.keyVault, widget.workspace);
    _listenToEngineEvents();
  }

  void _listenToEngineEvents() {
    _subscription = _engine.eventStream.listen((event) {
      if (!mounted) return;

      setState(() {
        if (event is StatusEvent) {
          _agentState = event.state;
          _statusMessage = event.message;
        } else if (event is ThoughtEvent) {
          if (_currentAssistantMessage != null) {
            _currentAssistantMessage!.thought = event.thought;
          }
        } else if (event is MessageEvent) {
          if (_currentAssistantMessage == null) {
            _currentAssistantMessage = ChatMessage(
              id: _uuid.v4(),
              role: MessageRole.assistant,
              content: event.text,
            );
            _messages.add(_currentAssistantMessage!);
          } else {
            _currentAssistantMessage!.content += (event.text.isNotEmpty ? '\n\n${event.text}' : '');
          }
          if (event.isComplete) {
            _currentAssistantMessage!.isStreaming = false;
          }
        } else if (event is ToolCallEvent) {
          if (_currentAssistantMessage == null) {
            _currentAssistantMessage = ChatMessage(
              id: _uuid.v4(),
              role: MessageRole.assistant,
              content: '',
            );
            _messages.add(_currentAssistantMessage!);
          }

          final existingIdx = _currentAssistantMessage!.toolCalls
              .indexWhere((tc) => tc.toolCallId == event.toolCallId);
          if (existingIdx != -1) {
            _currentAssistantMessage!.toolCalls[existingIdx] = event;
          } else {
            _currentAssistantMessage!.toolCalls.add(event);
          }
        } else if (event is DiffEvent) {
          if (_currentAssistantMessage != null) {
            _currentAssistantMessage!.diffs.add(event);
          }
        }
      });

      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSendMessage([String? overrideText]) async {
    final text = overrideText ?? _textController.text.trim();
    if (text.isEmpty || _agentState != AgentState.idle) return;

    _textController.clear();

    final userMessage = ChatMessage(
      id: _uuid.v4(),
      role: MessageRole.user,
      content: text,
    );

    setState(() {
      _messages.add(userMessage);
      _currentAssistantMessage = null; // Start fresh for new assistant turn
    });

    _scrollToBottom();
    await _engine.startTask(text);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _engine.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final activeModel = widget.keyVault.getActiveModel();
    final isYolo = widget.keyVault.isYoloMode();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const SizedBox(width: 16),
            const Icon(Icons.smart_toy_outlined, color: Colors.blueAccent),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.appTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Text(
                      activeModel,
                      style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                    ),
                    if (isYolo) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('YOLO', style: TextStyle(fontSize: 9, color: Colors.amber, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_outlined),
            tooltip: l10n.workspaceFiles,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WorkspaceExplorerScreen(workspace: widget.workspace),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.settings,
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(
                    keyVault: widget.keyVault,
                    prootManager: widget.prootManager,
                  ),
                ),
              );
              setState(() {}); // Refresh active model name, language and badges
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Agent Status Banner (if working)
          if (_agentState != AgentState.idle)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: _agentState == AgentState.waitingApproval
                  ? Colors.amber.withValues(alpha: 0.15)
                  : theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _agentState == AgentState.waitingApproval
                          ? Colors.amber
                          : theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _statusMessage ?? l10n.agentWorking,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _agentState == AgentState.waitingApproval
                            ? Colors.amber
                            : theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  if (_agentState != AgentState.idle)
                    GestureDetector(
                      onTap: () => _engine.interrupt(),
                      child: Text(
                        l10n.stop,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),

          // Chat Messages
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState(theme, l10n)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return _buildMessageItem(msg, theme, l10n);
                    },
                  ),
          ),

          // Bottom Input Bar
          _buildInputBar(theme, l10n),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, AppLocalizations l10n) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.terminal, size: 48, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.welcomeTitle,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.welcomeSubtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),

            // Prompt suggestions
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.info_outline, size: 16),
                  label: Text(l10n.promptSummary),
                  onPressed: () => _handleSendMessage(l10n.promptSummaryQuery),
                ),
                ActionChip(
                  avatar: const Icon(Icons.code, size: 16),
                  label: Text(l10n.promptFibonacci),
                  onPressed: () => _handleSendMessage(l10n.promptFibonacciQuery),
                ),
                ActionChip(
                  avatar: const Icon(Icons.folder_open, size: 16),
                  label: Text(l10n.promptListFiles),
                  onPressed: () => _handleSendMessage(l10n.promptListFilesQuery),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(ChatMessage msg, ThemeData theme, AppLocalizations l10n) {
    final isUser = msg.role == MessageRole.user;

    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(
            msg.content,
            style: TextStyle(color: theme.colorScheme.onPrimary, fontSize: 14),
          ),
        ),
      );
    }

    // Assistant message
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.95),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Reasoning thought card
            if (msg.thought != null && msg.thought!.isNotEmpty)
              ThoughtCard(thought: msg.thought!, isStreaming: msg.isStreaming),

            // Content text
            if (msg.content.trim().isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: MarkdownBody(
                  data: msg.content,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                    p: const TextStyle(fontSize: 14, height: 1.45),
                    code: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    codeblockDecoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

            // Tool Approval Cards
            for (final tool in msg.toolCalls)
              ToolApprovalCard(
                toolCall: tool,
                onApprove: () => _engine.respondApproval(tool.toolCallId, true),
                onReject: () => _engine.respondApproval(tool.toolCallId, false),
                onViewDiff: msg.diffs.isNotEmpty
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DiffViewerScreen(diff: msg.diffs.last),
                          ),
                        );
                      }
                    : null,
              ),

            // Diff Cards (if any diffs generated)
            for (final diff in msg.diffs)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: const Color(0xFF1E1E1E),
                child: ListTile(
                  leading: const Icon(Icons.difference_outlined, color: Colors.greenAccent),
                  title: Text(diff.filePath, style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13)),
                  subtitle: Text(
                    '${l10n.diffGenerated} (${diff.diffLines.length} lines)',
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DiffViewerScreen(diff: diff),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(ThemeData theme, AppLocalizations l10n) {
    final isWorking = _agentState != AgentState.idle;

    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: isWorking ? l10n.inputHintWorking : l10n.inputHintIdle,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _handleSendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: isWorking ? () => _engine.interrupt() : () => _handleSendMessage(),
            icon: Icon(isWorking ? Icons.stop : Icons.arrow_upward),
            style: IconButton.styleFrom(
              backgroundColor: isWorking ? Colors.redAccent : theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

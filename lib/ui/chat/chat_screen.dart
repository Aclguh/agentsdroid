import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/agent/engine_coordinator.dart';
import '../../core/notification/foreground_service_manager.dart';
import '../../core/proot/proot_manager.dart';
import '../../core/storage/key_vault.dart';
import '../../core/storage/session_service.dart';
import '../../core/storage/workspace_service.dart';
import '../../l10n/app_localizations.dart';
import '../../models/agent_event.dart';
import '../../models/chat_message.dart';
import '../../models/chat_session.dart';
import '../diff/diff_viewer_screen.dart';
import '../explorer/workspace_explorer_screen.dart';
import '../settings/settings_screen.dart';
import '../terminal/subsystem_terminal_screen.dart';
import 'widgets/thought_card.dart';
import 'widgets/tool_approval_card.dart';

class ChatScreen extends StatefulWidget {
  final KeyVault keyVault;
  final WorkspaceService workspace;
  final PRootManager prootManager;
  final SessionService? sessionService;

  const ChatScreen({
    super.key,
    required this.keyVault,
    required this.workspace,
    required this.prootManager,
    this.sessionService,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final EngineCoordinator _coordinator;
  late final ForegroundServiceManager _foregroundManager;
  late final SessionService _sessionService;

  StreamSubscription<AgentEvent>? _subscription;
  StreamSubscription<AgentEvent>? _foregroundSubscription;

  final List<ChatMessage> _messages = [];
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _uuid = const Uuid();

  AgentState _agentState = AgentState.idle;
  String? _statusMessage;
  ChatMessage? _currentAssistantMessage;
  ChatSession? _currentSession;

  @override
  void initState() {
    super.initState();
    _coordinator = EngineCoordinator(
      keyVault: widget.keyVault,
      workspace: widget.workspace,
      prootManager: widget.prootManager,
    );
    _foregroundManager = ForegroundServiceManager();
    _foregroundSubscription = _foregroundManager.bindAgentEvents(_coordinator.eventStream);
    _sessionService = widget.sessionService ?? SessionService();
    _initSessionService();
    _listenToEngineEvents();
  }

  Future<void> _initSessionService() async {
    if (widget.sessionService == null) {
      await _sessionService.init();
    }
    // Requirement: Always start with a fresh new conversation on app open
    _currentSession = await _sessionService.createSession(title: '新会话');
    if (mounted) {
      setState(() {
        _messages.clear();
        _currentAssistantMessage = null;
      });
    }
  }

  void _persistCurrentSession() {
    if (_currentSession == null) return;
    // Requirement: Do not retain conversations with no messages in history
    if (_messages.isEmpty) {
      _sessionService.deleteSession(_currentSession!.id);
      return;
    }
    _currentSession!.messages.clear();
    _currentSession!.messages.addAll(_messages);
    _sessionService.saveSession(_currentSession!);
  }

  void _listenToEngineEvents() {
    _subscription = _coordinator.eventStream.listen((event) {
      if (!mounted) return;

      setState(() {
        if (event is StatusEvent) {
          _agentState = event.state;
          _statusMessage = event.message;
          if (event.state == AgentState.idle ||
              event.state == AgentState.completed ||
              event.state == AgentState.error) {
            _persistCurrentSession();
          }
        } else if (event is ThoughtEvent) {
          if (_currentAssistantMessage != null) {
            final lastThought = _currentAssistantMessage!.blocks.whereType<ThoughtBlock>().lastOrNull;
            if (lastThought != null) {
              lastThought.thought = event.thought;
            } else {
              _currentAssistantMessage!.blocks.add(ThoughtBlock(event.thought));
            }
          }
        } else if (event is ToolCallEvent) {
          if (_currentAssistantMessage == null) {
            _currentAssistantMessage = ChatMessage(
              id: _uuid.v4(),
              role: MessageRole.assistant,
            );
            _messages.add(_currentAssistantMessage!);
          }

          final existingBlock = _currentAssistantMessage!.blocks
              .whereType<ToolCallBlock>()
              .where((b) => b.toolCall.toolCallId == event.toolCallId)
              .firstOrNull;

          if (existingBlock != null) {
            existingBlock.toolCall = event;
          } else {
            _currentAssistantMessage!.blocks.add(ToolCallBlock(event));
          }
          _persistCurrentSession();
        } else if (event is MessageEvent) {
          if (_currentAssistantMessage == null) {
            _currentAssistantMessage = ChatMessage(
              id: _uuid.v4(),
              role: MessageRole.assistant,
            );
            _messages.add(_currentAssistantMessage!);
          }

          if (_currentAssistantMessage!.blocks.isNotEmpty &&
              _currentAssistantMessage!.blocks.last is TextBlock) {
            final lastBlock = _currentAssistantMessage!.blocks.last as TextBlock;
            lastBlock.text += (event.text.isNotEmpty ? '\n\n${event.text}' : '');
          } else if (event.text.isNotEmpty) {
            _currentAssistantMessage!.blocks.add(TextBlock(event.text));
          }

          if (event.isComplete) {
            _currentAssistantMessage!.isStreaming = false;
            _persistCurrentSession();
          }
        } else if (event is DiffEvent) {
          if (_currentAssistantMessage != null) {
            _currentAssistantMessage!.blocks.add(DiffBlock(event));
            _persistCurrentSession();
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

    if (_currentSession != null) {
      if (_currentSession!.title == '新会话' ||
          _currentSession!.title == 'New Chat' ||
          _currentSession!.title == 'Untitled Session' ||
          _currentSession!.title.isEmpty) {
        _currentSession!.title = text.length > 25 ? '${text.substring(0, 25)}...' : text;
      }
      _persistCurrentSession();
    }

    _scrollToBottom();
    await _coordinator.startTask(text);
  }

  Future<void> _handleNewSession([AppLocalizations? l10n]) async {
    if (_agentState != AgentState.idle) {
      await _coordinator.interrupt();
    }
    _persistCurrentSession();
    _coordinator.resetSession();

    final defaultTitle = l10n?.sessionUntitled ?? '新会话';
    final newSession = await _sessionService.createSession(title: defaultTitle);
    if (!mounted) return;

    setState(() {
      _currentSession = newSession;
      _messages.clear();
      _currentAssistantMessage = null;
    });

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(); // Close drawer if open
    }
  }

  Future<void> _handleSwitchSession(String sessionId) async {
    if (_currentSession?.id == sessionId) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      return;
    }

    if (_agentState != AgentState.idle) {
      await _coordinator.interrupt();
    }

    _persistCurrentSession();
    _coordinator.resetSession();

    final session = await _sessionService.getSession(sessionId);
    if (!mounted) return;

    if (session != null) {
      setState(() {
        _currentSession = session;
        _messages.clear();
        _messages.addAll(session.messages);
        _currentAssistantMessage = null;
      });
      _scrollToBottom();
    }

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleDeleteSession(String sessionId, AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(l10n.deleteSession),
        content: Text(l10n.deleteSessionConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _sessionService.deleteSession(sessionId);
      if (_currentSession?.id == sessionId) {
        final remaining = await _sessionService.listSessions();
        if (remaining.isNotEmpty) {
          await _handleSwitchSession(remaining.first.id);
        } else {
          await _handleNewSession(l10n);
        }
      } else {
        setState(() {});
      }
    }
  }

  Future<void> _handleRenameSession(ChatSessionSummary summary, AppLocalizations l10n) async {
    final controller = TextEditingController(text: summary.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(l10n.renameSession),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.sessionTitleHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (newTitle != null && newTitle.isNotEmpty && mounted) {
      await _sessionService.renameSession(summary.id, newTitle);
      if (_currentSession?.id == summary.id) {
        setState(() {
          _currentSession?.title = newTitle;
        });
      } else {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _persistCurrentSession();
    _foregroundSubscription?.cancel();
    _foregroundManager.dispose();
    _subscription?.cancel();
    _coordinator.dispose();
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
      drawer: _buildHistoryDrawer(context, l10n, theme),
      appBar: AppBar(
        titleSpacing: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: l10n.chatHistory,
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _currentSession?.title.isNotEmpty == true
                  ? _currentSession!.title
                  : l10n.appTitle,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    activeModel,
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isYolo) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text('YOLO', style: TextStyle(fontSize: 8, color: Colors.amber, fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            tooltip: l10n.newChat,
            onPressed: () => _handleNewSession(l10n),
          ),
          IconButton(
            icon: const Icon(Icons.terminal_outlined),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            tooltip: l10n.subsystemTerminal,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SubsystemTerminalScreen(
                    prootManager: widget.prootManager,
                    keyVault: widget.keyVault,
                  ),
                ),
              );
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
                      onTap: () => _coordinator.interrupt(),
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

          // Input Bar
          _buildInputBar(theme, l10n),
        ],
      ),
    );
  }

  Widget _buildHistoryDrawer(BuildContext context, AppLocalizations l10n, ThemeData theme) {
    return Drawer(
      backgroundColor: const Color(0xFF141414),
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.history, color: Colors.blueAccent),
                  const SizedBox(width: 10),
                  Text(
                    l10n.chatHistory,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // New Chat Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: FilledButton.icon(
                onPressed: () => _handleNewSession(l10n),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.newChat),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),

            const Divider(color: Color(0xFF262626), height: 16),

            // Session List
            Expanded(
              child: FutureBuilder<List<ChatSessionSummary>>(
                future: _sessionService.listSessions(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final sessions = snapshot.data ?? [];
                  if (sessions.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 40,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.noHistorySessions,
                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final item = sessions[index];
                      final isSelected = item.id == _currentSession?.id;

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primary.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: isSelected
                              ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.5), width: 1)
                              : Border.all(color: Colors.transparent, width: 1),
                        ),
                        child: ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          leading: Icon(
                            isSelected ? Icons.chat : Icons.chat_bubble_outline,
                            size: 18,
                            color: isSelected ? theme.colorScheme.primary : Colors.white60,
                          ),
                          title: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.white : Colors.white70,
                            ),
                          ),
                          subtitle: Text(
                            '${DateFormat('MM/dd HH:mm').format(item.updatedAt)} • ${item.messageCount} msgs',
                            style: const TextStyle(fontSize: 10, color: Colors.white38),
                          ),
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 16, color: Colors.white38),
                            padding: EdgeInsets.zero,
                            color: const Color(0xFF1E1E1E),
                            onSelected: (val) {
                              if (val == 'rename') {
                                _handleRenameSession(item, l10n);
                              } else if (val == 'delete') {
                                _handleDeleteSession(item.id, l10n);
                              }
                            },
                            itemBuilder: (ctx) => [
                              PopupMenuItem(
                                value: 'rename',
                                child: Row(
                                  children: [
                                    const Icon(Icons.edit_outlined, size: 16),
                                    const SizedBox(width: 8),
                                    Text(l10n.renameSession),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                    const SizedBox(width: 8),
                                    Text(l10n.deleteSession, style: const TextStyle(color: Colors.redAccent)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          onTap: () => _handleSwitchSession(item.id),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            const Divider(color: Color(0xFF262626), height: 1),

            // Bottom Shortcuts
            ListTile(
              dense: true,
              leading: const Icon(Icons.folder_outlined, size: 18),
              title: Text(l10n.workspaceFiles, style: const TextStyle(fontSize: 13)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WorkspaceExplorerScreen(
                      workspace: widget.workspace,
                      prootManager: widget.prootManager,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.settings_outlined, size: 18),
              title: Text(l10n.settings, style: const TextStyle(fontSize: 13)),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsScreen(
                      keyVault: widget.keyVault,
                      prootManager: widget.prootManager,
                    ),
                  ),
                );
                if (mounted) setState(() {});
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, AppLocalizations l10n) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.code_outlined,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.welcomeTitle,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.welcomeSubtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            _buildPromptSuggestion(l10n.promptSummary, l10n.promptSummaryQuery, theme),
            _buildPromptSuggestion(l10n.promptFibonacci, l10n.promptFibonacciQuery, theme),
            _buildPromptSuggestion(l10n.promptListFiles, l10n.promptListFilesQuery, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptSuggestion(String label, String prompt, ThemeData theme) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () => _handleSendMessage(prompt),
        child: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface),
        ),
      ),
    );
  }

  Widget _buildMessageItem(ChatMessage msg, ThemeData theme, AppLocalizations l10n) {
    if (msg.role == MessageRole.user) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(16).copyWith(bottomRight: const Radius.circular(2)),
          ),
          child: Text(
            msg.content,
            style: const TextStyle(color: Colors.white, fontSize: 14),
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
            for (final block in msg.blocks) ...[
              if (block is ThoughtBlock && block.thought.isNotEmpty)
                ThoughtCard(thought: block.thought, isStreaming: msg.isStreaming),

              if (block is ToolCallBlock)
                ToolApprovalCard(
                  toolCall: block.toolCall,
                  onApprove: () => _coordinator.respondApproval(block.toolCall.toolCallId, true),
                  onReject: () => _coordinator.respondApproval(block.toolCall.toolCallId, false),
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

              if (block is TextBlock && block.text.trim().isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: MarkdownBody(
                    data: block.text,
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

              if (block is DiffBlock)
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: const Color(0xFF1E1E1E),
                  child: ListTile(
                    leading: const Icon(Icons.difference_outlined, color: Colors.greenAccent),
                    title: Text(block.diff.filePath, style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13)),
                    subtitle: Text(
                      '${l10n.diffGenerated} (${block.diff.diffLines.length} lines)',
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DiffViewerScreen(diff: block.diff),
                        ),
                      );
                    },
                  ),
                ),
            ],
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
            onPressed: isWorking ? () => _coordinator.interrupt() : () => _handleSendMessage(),
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

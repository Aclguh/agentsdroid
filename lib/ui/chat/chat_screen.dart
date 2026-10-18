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

enum ConversationSortOrder { recent, name }
enum ProjectSortOrder { name, recent }

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

  final Set<String> _expandedProjects = {'agentsdroid'};
  bool _showArchived = false;
  ConversationSortOrder _conversationSortOrder = ConversationSortOrder.recent;
  ProjectSortOrder _projectSortOrder = ProjectSortOrder.name;

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
    _expandedProjects.add(widget.workspace.currentProjectName);
    // Requirement: Always start with a fresh new conversation on app open
    _currentSession = await _sessionService.createSession(
      title: '新会话',
      projectName: widget.workspace.currentProjectName,
    );
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

  Future<void> _handleNewSession(AppLocalizations l10n, {String? projectName}) async {
    if (_agentState != AgentState.idle) {
      await _coordinator.interrupt();
    }
    _persistCurrentSession();
    _coordinator.resetSession();

    if (projectName != null) {
      await widget.workspace.switchProject(projectName);
    }

    final defaultTitle = l10n.sessionUntitled;
    final newSession = await _sessionService.createSession(
      title: defaultTitle,
      projectName: projectName,
    );
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
      if (session.projectName != null && session.projectName!.isNotEmpty) {
        await widget.workspace.switchProject(session.projectName!);
      }
      if (!mounted) return;

      setState(() {
        _currentSession = session;
        _messages.clear();
        _messages.addAll(session.messages);
        _currentAssistantMessage = null;
      });
      _scrollToBottom();
    }

    if (mounted && Navigator.of(context).canPop()) {
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
        final remaining = await _sessionService.listSessions(isArchived: false);
        if (remaining.isNotEmpty) {
          await _handleSwitchSession(remaining.first.id);
        } else {
          await _handleNewSession(l10n, projectName: widget.workspace.currentProjectName);
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

  Future<void> _handleArchiveSession(String sessionId, AppLocalizations l10n) async {
    await _sessionService.archiveSession(sessionId);
    if (!mounted) return;

    if (_currentSession?.id == sessionId) {
      await _handleNewSession(l10n, projectName: widget.workspace.currentProjectName);
    } else {
      setState(() {});
    }
  }

  Future<void> _handleUnarchiveSession(String sessionId, AppLocalizations l10n) async {
    await _sessionService.unarchiveSession(sessionId);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _handleCreateProject(AppLocalizations l10n) async {
    final controller = TextEditingController();
    final projectName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(l10n.newProject),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.projectNameHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.create),
          ),
        ],
      ),
    );

    if (projectName != null && projectName.isNotEmpty && mounted) {
      await widget.workspace.createProject(projectName);
      setState(() {
        _expandedProjects.add(projectName);
      });
      await _handleNewSession(l10n, projectName: projectName);
    }
  }

  String _formatRelativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 30) return '${diff.inDays}d';
    return DateFormat('MM/dd').format(dateTime);
  }

  void _showConversationHistorySheet(BuildContext context, AppLocalizations l10n, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _ConversationHistoryModal(
          sessionService: _sessionService,
          currentSessionId: _currentSession?.id,
          onSelectSession: (id) {
            Navigator.pop(ctx);
            Navigator.pop(context); // close drawer
            _handleSwitchSession(id);
          },
          onArchiveSession: (id) => _handleArchiveSession(id, l10n),
          onUnarchiveSession: (id) => _handleUnarchiveSession(id, l10n),
          onDeleteSession: (id) => _handleDeleteSession(id, l10n),
          formatRelativeTime: _formatRelativeTime,
          l10n: l10n,
        );
      },
    );
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
                if (_currentSession?.projectName != null) ...[
                  Icon(Icons.folder_outlined, size: 10, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 3),
                  Text(
                    _currentSession!.projectName!,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('•', style: TextStyle(fontSize: 8, color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(width: 4),
                ],
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
            onPressed: () => _handleNewSession(l10n, projectName: widget.workspace.currentProjectName),
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
            // Top Action Buttons (Matching reference UI)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Column(
                children: [
                  // + New Conversation Button
                  Material(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        Navigator.pop(context);
                        _handleNewSession(l10n, projectName: null);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF2C2C2C), width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.add, size: 18, color: Colors.white70),
                            const SizedBox(width: 10),
                            Text(
                              l10n.newConversation,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Conversation History Button
                  Material(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _showConversationHistorySheet(context, l10n, theme),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF2C2C2C), width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.history_rounded, size: 18, color: Colors.white70),
                            const SizedBox(width: 10),
                            Text(
                              l10n.conversationHistory,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: Color(0xFF262626), height: 16),

            // Header: Projects / Display Options (Filter & Sort) / Create Project
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
              child: Row(
                children: [
                  Text(
                    _showArchived ? l10n.archivedSessions : l10n.projects,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _showArchived ? Colors.amber : Colors.white70,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (_showArchived) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() {
                          _showArchived = false;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.close, size: 12, color: Colors.amber),
                            const SizedBox(width: 2),
                            Text(l10n.hideArchived, style: const TextStyle(fontSize: 10, color: Colors.amber)),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  // Display Options PopupMenu (Image 1)
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.filter_list_rounded,
                      size: 20,
                      color: _showArchived ? Colors.amber : Colors.white60,
                    ),
                    tooltip: l10n.displayOptions,
                    color: const Color(0xFF222222),
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Color(0xFF333333)),
                    ),
                    onSelected: (val) {
                      setState(() {
                        if (val == 'sort_conv_recent') {
                          _conversationSortOrder = ConversationSortOrder.recent;
                        } else if (val == 'sort_conv_name') {
                          _conversationSortOrder = ConversationSortOrder.name;
                        } else if (val == 'sort_proj_name') {
                          _projectSortOrder = ProjectSortOrder.name;
                        } else if (val == 'sort_proj_recent') {
                          _projectSortOrder = ProjectSortOrder.recent;
                        } else if (val == 'toggle_archived') {
                          _showArchived = !_showArchived;
                        }
                      });
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem<String>(
                        enabled: false,
                        height: 26,
                        child: Text(
                          l10n.sortConversations,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white38),
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'sort_conv_recent',
                        height: 36,
                        child: Row(
                          children: [
                            Icon(
                              _conversationSortOrder == ConversationSortOrder.recent ? Icons.check : Icons.circle_outlined,
                              size: 16,
                              color: _conversationSortOrder == ConversationSortOrder.recent ? Colors.amber : Colors.white30,
                            ),
                            const SizedBox(width: 8),
                            Text(l10n.sortRecent, style: const TextStyle(fontSize: 13, color: Colors.white)),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'sort_conv_name',
                        height: 36,
                        child: Row(
                          children: [
                            Icon(
                              _conversationSortOrder == ConversationSortOrder.name ? Icons.check : Icons.circle_outlined,
                              size: 16,
                              color: _conversationSortOrder == ConversationSortOrder.name ? Colors.amber : Colors.white30,
                            ),
                            const SizedBox(width: 8),
                            Text(l10n.sortName, style: const TextStyle(fontSize: 13, color: Colors.white)),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(height: 8),
                      PopupMenuItem<String>(
                        enabled: false,
                        height: 26,
                        child: Text(
                          l10n.sortProjects,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white38),
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'sort_proj_name',
                        height: 36,
                        child: Row(
                          children: [
                            Icon(
                              _projectSortOrder == ProjectSortOrder.name ? Icons.check : Icons.circle_outlined,
                              size: 16,
                              color: _projectSortOrder == ProjectSortOrder.name ? Colors.amber : Colors.white30,
                            ),
                            const SizedBox(width: 8),
                            Text(l10n.sortName, style: const TextStyle(fontSize: 13, color: Colors.white)),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'sort_proj_recent',
                        height: 36,
                        child: Row(
                          children: [
                            Icon(
                              _projectSortOrder == ProjectSortOrder.recent ? Icons.check : Icons.circle_outlined,
                              size: 16,
                              color: _projectSortOrder == ProjectSortOrder.recent ? Colors.amber : Colors.white30,
                            ),
                            const SizedBox(width: 8),
                            Text(l10n.sortRecent, style: const TextStyle(fontSize: 13, color: Colors.white)),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(height: 8),
                      PopupMenuItem<String>(
                        value: 'toggle_archived',
                        height: 38,
                        child: Row(
                          children: [
                            Icon(
                              _showArchived ? Icons.check_box : Icons.check_box_outline_blank,
                              size: 18,
                              color: _showArchived ? Colors.amber : Colors.white38,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.archivedOnly,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _showArchived ? FontWeight.bold : FontWeight.normal,
                                color: _showArchived ? Colors.amber : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!_showArchived)
                    IconButton(
                      icon: const Icon(Icons.create_new_folder_outlined, size: 19, color: Colors.white60),
                      tooltip: l10n.newProject,
                      onPressed: () => _handleCreateProject(l10n),
                    ),
                ],
              ),
            ),

            // Content Area: Either Archived List or Projects + Conversations Tree
            Expanded(
              child: _showArchived
                  ? _buildArchivedList(context, l10n, theme)
                  : _buildProjectsAndConversationsTree(context, l10n, theme),
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
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectsAndConversationsTree(
      BuildContext context, AppLocalizations l10n, ThemeData theme) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        widget.workspace.listProjects(),
        _sessionService.listSessions(isArchived: false),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final rawProjects = (snapshot.data?[0] as List<String>?) ?? ['agentsdroid'];
        final sessions = (snapshot.data?[1] as List<ChatSessionSummary>?) ?? [];
        final projects = List<String>.from(rawProjects);

        // Group sessions by project or standalone
        final projectSessions = <String, List<ChatSessionSummary>>{};
        final standaloneSessions = <ChatSessionSummary>[];

        for (final s in sessions) {
          if (s.projectName != null && s.projectName!.isNotEmpty) {
            projectSessions.putIfAbsent(s.projectName!, () => []).add(s);
          } else {
            standaloneSessions.add(s);
          }
        }

        // Sort sessions within each group
        void sortSessions(List<ChatSessionSummary> list) {
          if (_conversationSortOrder == ConversationSortOrder.recent) {
            list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          } else {
            list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
          }
        }

        for (final list in projectSessions.values) {
          sortSessions(list);
        }
        sortSessions(standaloneSessions);

        // Sort projects
        if (_projectSortOrder == ProjectSortOrder.name) {
          projects.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        } else {
          projects.sort((a, b) {
            final aSessions = projectSessions[a] ?? [];
            final bSessions = projectSessions[b] ?? [];
            final aTime = aSessions.isEmpty ? DateTime.fromMillisecondsSinceEpoch(0) : aSessions.first.updatedAt;
            final bTime = bSessions.isEmpty ? DateTime.fromMillisecondsSinceEpoch(0) : bSessions.first.updatedAt;
            return bTime.compareTo(aTime);
          });
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          children: [
            // Projects List
            for (final projectName in projects) ...[
              _buildProjectFolderTile(
                projectName,
                projectSessions[projectName] ?? [],
                l10n,
                theme,
              ),
            ],

            const SizedBox(height: 16),

            // Conversations Section Header
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 0, 4),
              child: Row(
                children: [
                  Text(
                    l10n.conversations,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add, size: 20, color: Colors.white70),
                    tooltip: l10n.newStandaloneSession,
                    onPressed: () => _handleNewSession(l10n, projectName: null),
                  ),
                ],
              ),
            ),

            // Standalone Conversations List
            if (standaloneSessions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text(
                  l10n.noHistorySessions,
                  style: const TextStyle(fontSize: 11, color: Colors.white30, fontStyle: FontStyle.italic),
                ),
              )
            else
              for (final s in standaloneSessions)
                _buildSessionItem(s, l10n, theme, indent: false),
          ],
        );
      },
    );
  }

  Widget _buildProjectFolderTile(
    String projectName,
    List<ChatSessionSummary> sessions,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final isExpanded = _expandedProjects.contains(projectName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedProjects.remove(projectName);
              } else {
                _expandedProjects.add(projectName);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.folder_open_outlined : Icons.folder_outlined,
                  size: 18,
                  color: Colors.white70,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    projectName,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 16, color: Colors.white38),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  tooltip: l10n.newProjectSession,
                  onPressed: () => _handleNewSession(l10n, projectName: projectName),
                ),
              ],
            ),
          ),
        ),

        // Child sessions when folder is expanded
        if (isExpanded) ...[
          if (sessions.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 2, bottom: 8),
              child: GestureDetector(
                onTap: () => _handleNewSession(l10n, projectName: projectName),
                child: Text(
                  '+ ${l10n.newProjectSession}',
                  style: const TextStyle(fontSize: 11, color: Colors.white30, fontStyle: FontStyle.italic),
                ),
              ),
            )
          else
            for (final s in sessions)
              _buildSessionItem(s, l10n, theme, indent: true),
        ],
      ],
    );
  }

  Widget _buildSessionItem(
    ChatSessionSummary s,
    AppLocalizations l10n,
    ThemeData theme, {
    required bool indent,
  }) {
    final isSelected = s.id == _currentSession?.id;

    return Padding(
      padding: EdgeInsets.only(left: indent ? 16.0 : 0.0, top: 2, bottom: 2),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF262626) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _handleSwitchSession(s.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    s.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _formatRelativeTime(s.updatedAt),
                  style: const TextStyle(fontSize: 11, color: Colors.white38),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 16, color: Colors.white38),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  color: const Color(0xFF1E1E1E),
                  onSelected: (val) {
                    if (val == 'rename') {
                      _handleRenameSession(s, l10n);
                    } else if (val == 'archive') {
                      _handleArchiveSession(s.id, l10n);
                    } else if (val == 'delete') {
                      _handleDeleteSession(s.id, l10n);
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
                      value: 'archive',
                      child: Row(
                        children: [
                          const Icon(Icons.archive_outlined, size: 16),
                          const SizedBox(width: 8),
                          Text(l10n.archive),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArchivedList(BuildContext context, AppLocalizations l10n, ThemeData theme) {
    return FutureBuilder<List<ChatSessionSummary>>(
      future: _sessionService.listSessions(isArchived: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final archived = snapshot.data ?? [];
        if (archived.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.archive_outlined, size: 40, color: Colors.white24),
                const SizedBox(height: 12),
                Text(l10n.noArchivedSessions, style: const TextStyle(color: Colors.white38, fontSize: 13)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          itemCount: archived.length,
          itemBuilder: (context, index) {
            final s = archived[index];
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                leading: const Icon(Icons.archive_outlined, size: 18, color: Colors.amber),
                title: Text(
                  s.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
                subtitle: Text(
                  '${s.projectName ?? l10n.conversations} • ${_formatRelativeTime(s.updatedAt)}',
                  style: const TextStyle(fontSize: 10, color: Colors.white38),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.unarchive_outlined, size: 18, color: Colors.greenAccent),
                      tooltip: l10n.unarchive,
                      onPressed: () => _handleUnarchiveSession(s.id, l10n),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                      tooltip: l10n.delete,
                      onPressed: () => _handleDeleteSession(s.id, l10n),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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

class _ConversationHistoryModal extends StatefulWidget {
  final SessionService sessionService;
  final String? currentSessionId;
  final ValueChanged<String> onSelectSession;
  final Future<void> Function(String id) onArchiveSession;
  final Future<void> Function(String id) onUnarchiveSession;
  final Future<void> Function(String id) onDeleteSession;
  final String Function(DateTime dt) formatRelativeTime;
  final AppLocalizations l10n;

  const _ConversationHistoryModal({
    required this.sessionService,
    required this.currentSessionId,
    required this.onSelectSession,
    required this.onArchiveSession,
    required this.onUnarchiveSession,
    required this.onDeleteSession,
    required this.formatRelativeTime,
    required this.l10n,
  });

  @override
  State<_ConversationHistoryModal> createState() => _ConversationHistoryModalState();
}

class _ConversationHistoryModalState extends State<_ConversationHistoryModal> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all';
  List<ChatSessionSummary> _allSessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final list = await widget.sessionService.listSessions(isArchived: null);
    if (mounted) {
      setState(() {
        _allSessions = list;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final availableProjects = <String>{};
    for (final s in _allSessions) {
      if (s.projectName != null && s.projectName!.isNotEmpty) {
        availableProjects.add(s.projectName!);
      }
    }

    final filtered = _allSessions.where((s) {
      if (_selectedFilter == 'standalone' && s.projectName != null) return false;
      if (_selectedFilter == 'archived' && !s.isArchived) return false;
      if (_selectedFilter != 'all' && _selectedFilter != 'standalone' && _selectedFilter != 'archived') {
        if (s.projectName != _selectedFilter) return false;
      }
      if (_selectedFilter != 'archived' && s.isArchived) return false;

      if (query.isNotEmpty) {
        final titleMatches = s.title.toLowerCase().contains(query);
        final projectMatches = s.projectName?.toLowerCase().contains(query) ?? false;
        if (!titleMatches && !projectMatches) return false;
      }
      return true;
    }).toList();

    filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF181818),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.history_rounded, size: 22, color: Colors.white70),
                const SizedBox(width: 10),
                Text(
                  widget.l10n.conversationHistory,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Colors.white60),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: widget.l10n.searchConversations,
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 18, color: Colors.white38),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16, color: Colors.white38),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF242424),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                _buildFilterChip('all', widget.l10n.allConversations),
                const SizedBox(width: 6),
                _buildFilterChip('standalone', widget.l10n.conversations),
                const SizedBox(width: 6),
                for (final proj in availableProjects) ...[
                  _buildFilterChip(proj, proj, isProject: true),
                  const SizedBox(width: 6),
                ],
                _buildFilterChip('archived', widget.l10n.archivedSessions),
              ],
            ),
          ),

          const Divider(color: Color(0xFF262626), height: 1),

          // Sessions List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Text(
                          widget.l10n.noMatchingConversations,
                          style: const TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 4),
                        itemBuilder: (ctx, i) {
                          final s = filtered[i];
                          final isCurrent = s.id == widget.currentSessionId;

                          return Container(
                            decoration: BoxDecoration(
                              color: isCurrent ? const Color(0xFF282828) : const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isCurrent ? Colors.blueAccent.withValues(alpha: 0.5) : const Color(0xFF2C2C2C),
                              ),
                            ),
                            child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              onTap: () => widget.onSelectSession(s.id),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      s.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                        color: isCurrent ? Colors.white : Colors.white,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    widget.formatRelativeTime(s.updatedAt),
                                    style: const TextStyle(fontSize: 11, color: Colors.white38),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    if (s.projectName != null) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.blueAccent.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          s.projectName!,
                                          style: const TextStyle(fontSize: 10, color: Colors.blueAccent),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ] else ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.white10,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          widget.l10n.conversations,
                                          style: const TextStyle(fontSize: 10, color: Colors.white60),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    if (s.isArchived)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          widget.l10n.archivedSessions,
                                          style: const TextStyle(fontSize: 10, color: Colors.amber),
                                        ),
                                      ),
                                    const Spacer(),
                                    Text(
                                      '${s.messageCount} msgs',
                                      style: const TextStyle(fontSize: 10, color: Colors.white24),
                                    ),
                                  ],
                                ),
                              ),
                              trailing: PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 16, color: Colors.white38),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                color: const Color(0xFF252525),
                                onSelected: (val) async {
                                  if (val == 'archive') {
                                    await widget.onArchiveSession(s.id);
                                    await _loadSessions();
                                  } else if (val == 'unarchive') {
                                    await widget.onUnarchiveSession(s.id);
                                    await _loadSessions();
                                  } else if (val == 'delete') {
                                    await widget.onDeleteSession(s.id);
                                    await _loadSessions();
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  if (!s.isArchived)
                                    PopupMenuItem(
                                      value: 'archive',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.archive_outlined, size: 16),
                                          const SizedBox(width: 8),
                                          Text(widget.l10n.archive),
                                        ],
                                      ),
                                    )
                                  else
                                    PopupMenuItem(
                                      value: 'unarchive',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.unarchive_outlined, size: 16),
                                          const SizedBox(width: 8),
                                          Text(widget.l10n.unarchive),
                                        ],
                                      ),
                                    ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                        const SizedBox(width: 8),
                                        Text(widget.l10n.delete, style: const TextStyle(color: Colors.redAccent)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, {bool isProject = false}) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedFilter = key;
        });
      },
      avatar: isProject ? const Icon(Icons.folder_outlined, size: 14) : null,
      labelStyle: TextStyle(
        fontSize: 12,
        color: isSelected ? Colors.white : Colors.white60,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      backgroundColor: const Color(0xFF222222),
      selectedColor: const Color(0xFF333333),
      side: BorderSide(
        color: isSelected ? Colors.blueAccent : const Color(0xFF333333),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      visualDensity: VisualDensity.compact,
    );
  }
}

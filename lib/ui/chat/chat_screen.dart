import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart' hide TextDirection;
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
import '../settings/model_settings_screen.dart';
import '../settings/settings_screen.dart';
import '../terminal/subsystem_terminal_screen.dart';
import 'widgets/agents_droid_mark.dart';
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

  static MarkdownStyleSheet buildMarkdownStyleSheet(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final effectiveTheme = theme.textTheme.bodyMedium?.fontSize != null
        ? theme
        : theme.copyWith(
            textTheme: theme.textTheme.copyWith(
              bodyMedium: (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(fontSize: 14),
            ),
          );
    final defaultSheet = MarkdownStyleSheet.fromTheme(effectiveTheme);

    return defaultSheet.copyWith(
      p: TextStyle(
        fontSize: 14,
        height: 1.45,
        color: theme.colorScheme.onSurface,
      ),
      h1: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurface,
      ),
      h2: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurface,
      ),
      h3: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface,
      ),
      h4: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface,
      ),
      blockquote: TextStyle(
        fontSize: 13.5,
        height: 1.45,
        color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
        fontStyle: FontStyle.italic,
      ),
      blockquotePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      blockquoteDecoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2330) : const Color(0xFFEFF6FF),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
        border: Border(
          left: BorderSide(
            color: theme.colorScheme.primary,
            width: 3.5,
          ),
        ),
      ),
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: 12.5,
        color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
        backgroundColor: isDark ? const Color(0xFF232733) : const Color(0xFFF1F5F9),
      ),
      codeblockPadding: const EdgeInsets.all(10),
      codeblockDecoration: BoxDecoration(
        color: isDark ? const Color(0xFF181A20) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2E3D) : const Color(0xFFE2E8F0),
        ),
      ),
      listBullet: TextStyle(color: theme.colorScheme.onSurface),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      tableBorder: TableBorder.all(
        color: theme.dividerColor.withValues(alpha: 0.3),
        width: 0.8,
      ),
      tableHead: TextStyle(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface,
      ),
      tableBody: TextStyle(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
      ),
    );
  }

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
  final _inputFocusNode = FocusNode();
  final _scrollController = ScrollController();
  final _uuid = const Uuid();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  DateTime? _lastBackPressTime;

  AgentState _agentState = AgentState.idle;
  String? _statusMessage;
  ChatMessage? _currentAssistantMessage;
  ChatSession? _currentSession;

  final Set<String> _expandedProjects = {};
  bool _showArchived = false;
  late bool _isProjectsSectionExpanded;
  late bool _isConversationsSectionExpanded;
  DateTime? _currentTurnThinkingStart;
  ConversationSortOrder _conversationSortOrder = ConversationSortOrder.recent;
  ProjectSortOrder _projectSortOrder = ProjectSortOrder.name;
  Future<List<dynamic>>? _treeDataFuture;

  void _refreshTreeData() {
    _treeDataFuture = Future.wait([
      widget.workspace.listProjects(),
      _sessionService.listSessions(isArchived: false),
    ]);
  }

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
    _expandedProjects.addAll(widget.keyVault.getExpandedProjects());
    _isProjectsSectionExpanded = widget.keyVault.isProjectsSectionExpanded();
    _isConversationsSectionExpanded = widget.keyVault.isConversationsSectionExpanded();
    _refreshTreeData();
    _textController.addListener(_onTextChanged);
    _initSessionService();
    _listenToEngineEvents();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initSessionService() async {
    if (widget.sessionService == null) {
      await _sessionService.init();
    }
    // Requirement: Software opens with a standalone session not belonging to any project
    _currentSession = await _sessionService.createSession(
      title: '新会话',
      projectName: null,
    );
    await widget.workspace.switchProject(null);
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

  void _finalizeThinkingDuration() {
    if (_currentTurnThinkingStart != null) {
      final elapsed = DateTime.now().difference(_currentTurnThinkingStart!).inSeconds;
      final lastThought = _currentAssistantMessage?.blocks.whereType<ThoughtBlock>().lastOrNull;
      if (lastThought != null && lastThought.durationSeconds == null) {
        lastThought.durationSeconds = elapsed > 0 ? elapsed : 1;
      }
      _currentTurnThinkingStart = null;
    }
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
            _finalizeThinkingDuration();
            _persistCurrentSession();
          }
        } else if (event is ThoughtEvent) {
          if (_currentAssistantMessage == null) {
            _currentAssistantMessage = ChatMessage(
              id: _uuid.v4(),
              role: MessageRole.assistant,
            );
            _messages.add(_currentAssistantMessage!);
          }
          _currentTurnThinkingStart ??= DateTime.now();

          final lastThought = _currentAssistantMessage!.blocks.whereType<ThoughtBlock>().lastOrNull;
          if (lastThought != null) {
            lastThought.thought = event.thought;
          } else {
            _currentAssistantMessage!.blocks.add(ThoughtBlock(event.thought));
          }
        } else if (event is ToolCallEvent) {
          _finalizeThinkingDuration();

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
          _finalizeThinkingDuration();

          if (_currentAssistantMessage == null) {
            _currentAssistantMessage = ChatMessage(
              id: _uuid.v4(),
              role: MessageRole.assistant,
              isStreaming: !event.isComplete,
            );
            _messages.add(_currentAssistantMessage!);
          } else if (!event.isComplete) {
            _currentAssistantMessage!.isStreaming = true;
          }

          if (_currentAssistantMessage!.blocks.isNotEmpty &&
              _currentAssistantMessage!.blocks.last is TextBlock) {
            final lastBlock = _currentAssistantMessage!.blocks.last as TextBlock;
            if (event.isDelta) {
              lastBlock.text += event.text;
            } else if (_currentAssistantMessage!.isStreaming) {
              lastBlock.text = event.text;
            } else {
              lastBlock.text += (event.text.isNotEmpty ? '\n\n${event.text}' : '');
            }
          } else if (event.text.isNotEmpty) {
            _currentAssistantMessage!.blocks.add(TextBlock(event.text));
          }

          if (event.isComplete) {
            _currentAssistantMessage!.isStreaming = false;
            _persistCurrentSession();
            _refreshTreeData();
          }
        } else if (event is DiffEvent) {
          if (_currentAssistantMessage != null) {
            _currentAssistantMessage!.blocks.add(DiffBlock(event));
            _persistCurrentSession();
            _refreshTreeData();
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

    final priorMessages = List<ChatMessage>.from(_messages);

    final userMessage = ChatMessage(
      id: _uuid.v4(),
      role: MessageRole.user,
      content: text,
    );

    setState(() {
      _currentTurnThinkingStart = null;
      _messages.add(userMessage);
      _currentAssistantMessage = null; // Start fresh for new assistant turn
    });

    if (_currentSession != null) {
      if (_currentSession!.title == '新会话' ||
          _currentSession!.title == 'New Chat' ||
          _currentSession!.title == 'Untitled Session' ||
          _currentSession!.title == '无标题会话' ||
          _currentSession!.title.isEmpty) {
        _currentSession!.title = text.length > 25 ? '${text.substring(0, 25)}...' : text;
      }
      _persistCurrentSession();
      _refreshTreeData();
    }

    _scrollToBottom();
    await _coordinator.startTask(text, priorMessages: priorMessages);
  }

  Future<void> _handleNewSession(AppLocalizations l10n, {String? projectName}) async {
    _inputFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    if (_agentState != AgentState.idle) {
      await _coordinator.interrupt();
    }
    _persistCurrentSession();
    _coordinator.resetSession();

    final actualProject = (projectName != null &&
            projectName.isNotEmpty &&
            projectName != WorkspaceService.defaultProjectName)
        ? projectName
        : null;
    await widget.workspace.switchProject(actualProject);

    if (actualProject != null) {
      _expandedProjects.add(actualProject);
      widget.keyVault.setExpandedProjects(_expandedProjects);
    }

    final defaultTitle = l10n.sessionUntitled;
    final newSession = await _sessionService.createSession(
      title: defaultTitle,
      projectName: actualProject,
    );
    if (!mounted) return;

    setState(() {
      _currentSession = newSession;
      _messages.clear();
      _currentAssistantMessage = null;
      _refreshTreeData();
    });

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(); // Close drawer if open
    }
  }

  Future<void> _handleSwitchSession(String sessionId) async {
    _inputFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
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
      final actualProject = (session.projectName != null &&
              session.projectName!.isNotEmpty &&
              session.projectName != WorkspaceService.defaultProjectName)
          ? session.projectName
          : null;
      await widget.workspace.switchProject(actualProject);
      if (!mounted) return;

      _refreshTreeData();
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
          await _handleNewSession(l10n, projectName: null);
        }
      }
      _refreshTreeData();
      setState(() {});
    }
  }

  Future<void> _handleRenameSession(ChatSessionSummary summary, AppLocalizations l10n) async {
    final controller = TextEditingController(text: summary.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
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
        _currentSession?.title = newTitle;
      }
      _refreshTreeData();
      setState(() {});
    }
  }

  Future<void> _handleArchiveSession(String sessionId, AppLocalizations l10n) async {
    final isCurrent = _currentSession?.id == sessionId;
    if (isCurrent && _currentSession != null) {
      _currentSession!.isArchived = true;
      _currentSession!.messages.clear();
      _currentSession!.messages.addAll(_messages);
      await _sessionService.saveSession(_currentSession!);
    } else {
      await _sessionService.archiveSession(sessionId);
    }
    if (!mounted) return;

    if (isCurrent) {
      await _handleNewSession(l10n, projectName: null);
    }
    _refreshTreeData();
    setState(() {});
  }

  Future<void> _handleUnarchiveSession(String sessionId, AppLocalizations l10n) async {
    await _sessionService.unarchiveSession(sessionId);
    if (mounted) {
      _refreshTreeData();
      setState(() {});
    }
  }

  Future<void> _handleCreateProject(AppLocalizations l10n) async {
    final controller = TextEditingController();
    final projectName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
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
      await widget.keyVault.setExpandedProjects(_expandedProjects);
      await _handleNewSession(l10n, projectName: projectName);
    }
  }

  Future<void> _showChangeProjectDialog(AppLocalizations l10n) async {
    final rawProjects = await widget.workspace.listProjects();
    final projects = List<String>.from(rawProjects)
      ..removeWhere((p) => p == WorkspaceService.defaultProjectName);

    if (!mounted) return;

    final currentProject = (_currentSession?.projectName != null &&
            _currentSession!.projectName!.isNotEmpty &&
            _currentSession!.projectName != WorkspaceService.defaultProjectName)
        ? _currentSession!.projectName
        : null;

    _inputFocusNode.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
    FocusManager.instance.primaryFocus?.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.selectProjectForSession,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  leading: Icon(Icons.folder_off_outlined, color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant, size: 20),
                  title: Text(
                    l10n.noProject,
                    style: TextStyle(
                      color: currentProject == null ? (isDark ? Colors.white : theme.colorScheme.primary) : (isDark ? Colors.white70 : theme.colorScheme.onSurface),
                      fontSize: 14,
                      fontWeight: currentProject == null ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: currentProject == null ? const Icon(Icons.check, color: Colors.blueAccent, size: 18) : null,
                  onTap: () async {
                    Navigator.pop(ctx);
                    await widget.workspace.switchProject(null);
                    if (_currentSession != null) {
                      _currentSession!.projectName = null;
                      await _sessionService.saveSession(_currentSession!);
                    }
                    _refreshTreeData();
                    if (mounted) setState(() {});
                  },
                ),
                Divider(height: 1, color: isDark ? const Color(0xFF2C2C2C) : theme.colorScheme.outlineVariant),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: projects.length,
                    separatorBuilder: (context, index) => Divider(height: 1, color: isDark ? const Color(0xFF2C2C2C) : theme.colorScheme.outlineVariant),
                    itemBuilder: (c, idx) {
                      final proj = projects[idx];
                      final isSelected = proj == currentProject;
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        leading: Icon(Icons.folder_outlined, color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant, size: 20),
                        title: Text(
                          proj,
                          style: TextStyle(
                            color: isSelected ? (isDark ? Colors.white : theme.colorScheme.primary) : (isDark ? Colors.white70 : theme.colorScheme.onSurface),
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: isSelected ? const Icon(Icons.check, color: Colors.blueAccent, size: 18) : null,
                        onTap: () async {
                          Navigator.pop(ctx);
                          await widget.workspace.switchProject(proj);
                          if (_currentSession != null) {
                            _currentSession!.projectName = proj;
                            await _sessionService.saveSession(_currentSession!);
                            _expandedProjects.add(proj);
                            widget.keyVault.setExpandedProjects(_expandedProjects);
                          }
                          _refreshTreeData();
                          if (mounted) setState(() {});
                        },
                      );
                    },
                  ),
                ),
                Divider(height: 1, color: isDark ? const Color(0xFF2C2C2C) : theme.colorScheme.outlineVariant),
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  leading: const Icon(Icons.create_new_folder_outlined, color: Colors.blueAccent, size: 20),
                  title: Text(
                    l10n.newProject,
                    style: const TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _handleCreateProject(l10n);
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
    ).then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _inputFocusNode.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
        FocusManager.instance.primaryFocus?.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
      });
    });
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
    _inputFocusNode.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
    FocusManager.instance.primaryFocus?.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _ConversationHistoryModal(
          sessionService: _sessionService,
          currentSessionId: _currentSession?.id,
          currentSessionSummary: _currentSession?.toSummary(),
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
    ).then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _inputFocusNode.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
        FocusManager.instance.primaryFocus?.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
      });
    });
  }

  @override
  void dispose() {
    _persistCurrentSession();
    _foregroundSubscription?.cancel();
    _foregroundManager.dispose();
    _subscription?.cancel();
    _coordinator.dispose();
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (_scaffoldKey.currentState?.isDrawerOpen == true) {
          _scaffoldKey.currentState?.closeDrawer();
          return;
        }

        final now = DateTime.now();
        if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.pressBackAgainToExit),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        await SystemNavigator.pop();
      },
      child: Scaffold(
        key: _scaffoldKey,
        onDrawerChanged: (isOpen) {
        if (isOpen) {
          _refreshTreeData();
          setState(() {});
        } else {
          _inputFocusNode.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
          FocusScope.of(context).unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
          FocusManager.instance.primaryFocus?.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
        }
      },
      drawer: _buildHistoryDrawer(context, l10n, theme),
      appBar: AppBar(
        titleSpacing: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: l10n.chatHistory,
            onPressed: () {
              _inputFocusNode.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
              FocusScope.of(context).unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
              FocusManager.instance.primaryFocus?.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
              _refreshTreeData();
              setState(() {});
              Scaffold.of(ctx).openDrawer();
            },
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
            Builder(
              builder: (ctx) {
                final isNewSession = _messages.isEmpty;
                final rawProject = _currentSession?.projectName;
                final hasProject = rawProject != null &&
                    rawProject.isNotEmpty &&
                    rawProject != WorkspaceService.defaultProjectName;
                final displayProjectName = hasProject ? rawProject : l10n.noProject;

                if (isNewSession) {
                  return InkWell(
                    key: const Key('top_bar_project_selector'),
                    borderRadius: BorderRadius.circular(4),
                    onTap: () => _showChangeProjectDialog(l10n),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasProject ? Icons.folder_outlined : Icons.folder_off_outlined,
                            size: 11,
                            color: Colors.blueAccent,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            displayProjectName,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.blueAccent,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.arrow_drop_down, size: 14, color: Colors.blueAccent),
                        ],
                      ),
                    ),
                  );
                }

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasProject ? Icons.folder_outlined : Icons.folder_off_outlined,
                      size: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      displayProjectName,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            tooltip: l10n.newChat,
            onPressed: () => _handleNewSession(l10n, projectName: _currentSession?.projectName),
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
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          _inputFocusNode.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
          FocusScope.of(context).unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
          FocusManager.instance.primaryFocus?.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
        },
        child: Column(
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
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
      ),
    ),
  );
}

  Widget _buildHistoryDrawer(BuildContext context, AppLocalizations l10n, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Drawer(
      backgroundColor: isDark ? const Color(0xFF141414) : theme.colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            // App Name Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                children: [
                  Text(
                    l10n.appTitle,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                      color: isDark ? Colors.white : theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),

            Divider(color: isDark ? const Color(0xFF262626) : theme.colorScheme.outlineVariant, height: 1),
            const SizedBox(height: 10),

            // Top Action Buttons (Matching reference UI)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Column(
                children: [
                  // + New Conversation Button
                  Material(
                    color: isDark ? const Color(0xFF1E1E1E) : theme.colorScheme.surfaceContainerHighest,
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
                          border: Border.all(
                            color: isDark ? const Color(0xFF2C2C2C) : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.add, size: 18, color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 10),
                            Text(
                              l10n.newConversation,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white : theme.colorScheme.onSurface,
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
                    color: isDark ? const Color(0xFF1E1E1E) : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _showConversationHistorySheet(context, l10n, theme),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? const Color(0xFF2C2C2C) : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.history_rounded, size: 18, color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 10),
                            Text(
                              l10n.conversationHistory,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white : theme.colorScheme.onSurface,
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

            Divider(color: isDark ? const Color(0xFF262626) : theme.colorScheme.outlineVariant, height: 16),

            if (_showArchived)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                child: Row(
                  children: [
                    Text(
                      l10n.archivedSessions,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                        letterSpacing: 0.5,
                      ),
                    ),
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
                    const Spacer(),
                    _buildDisplayOptionsMenu(l10n),
                  ],
                ),
              ),

            // Content Area: Either Archived List or Projects + Conversations Tree
            Expanded(
              child: _showArchived
                  ? _buildArchivedList(context, l10n, theme)
                  : _buildProjectsAndConversationsTree(context, l10n, theme),
            ),

            Divider(color: isDark ? const Color(0xFF262626) : theme.colorScheme.outlineVariant, height: 1),

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

  Widget _buildDisplayOptionsMenu(AppLocalizations l10n, [ThemeData? theme]) {
    final isDark = (theme ?? Theme.of(context)).brightness == Brightness.dark;
    final currentTheme = theme ?? Theme.of(context);
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.filter_list_rounded,
        size: 19,
        color: _showArchived ? Colors.amber : (isDark ? Colors.white60 : currentTheme.colorScheme.onSurfaceVariant),
      ),
      tooltip: l10n.displayOptions,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      color: isDark ? const Color(0xFF222222) : currentTheme.colorScheme.surface,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isDark ? const Color(0xFF333333) : currentTheme.colorScheme.outlineVariant),
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
    );
  }

  Widget _buildProjectsAndConversationsTree(
      BuildContext context, AppLocalizations l10n, ThemeData theme) {
    _treeDataFuture ??= Future.wait([
      widget.workspace.listProjects(),
      _sessionService.listSessions(isArchived: false),
    ]);
    return FutureBuilder<List<dynamic>>(
      future: _treeDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final rawProjects = (snapshot.data?[0] as List<String>?) ?? [];
        final rawSessions = (snapshot.data?[1] as List<ChatSessionSummary>?) ?? [];
        final sessions = List<ChatSessionSummary>.from(rawSessions);

        // Ensure active current session is immediately displayed under its project (or standalone)
        if (_currentSession != null && !_currentSession!.isArchived) {
          final index = sessions.indexWhere((s) => s.id == _currentSession!.id);
          if (index >= 0) {
            sessions[index] = _currentSession!.toSummary();
          } else {
            sessions.add(_currentSession!.toSummary());
          }
        }

        final projects = List<String>.from(rawProjects)
          ..removeWhere((p) => p == WorkspaceService.defaultProjectName);

        // Group sessions by project or standalone
        final projectSessions = <String, List<ChatSessionSummary>>{};
        final standaloneSessions = <ChatSessionSummary>[];

        for (final s in sessions) {
          if (s.projectName != null &&
              s.projectName!.isNotEmpty &&
              s.projectName != WorkspaceService.defaultProjectName) {
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

        final isDark = theme.brightness == Brightness.dark;

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          children: [
            // Projects Section Header
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 0, 2),
              child: Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      setState(() {
                        _isProjectsSectionExpanded = !_isProjectsSectionExpanded;
                      });
                      widget.keyVault.setProjectsSectionExpanded(_isProjectsSectionExpanded);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.projects,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 4),
                          RotatedBox(
                            quarterTurns: _isProjectsSectionExpanded ? 1 : 0,
                            child: Icon(Icons.chevron_right, size: 15, color: isDark ? Colors.white54 : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  _buildDisplayOptionsMenu(l10n, theme),
                  IconButton(
                    icon: Icon(Icons.create_new_folder_outlined, size: 19, color: isDark ? Colors.white60 : theme.colorScheme.onSurfaceVariant),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    tooltip: l10n.newProject,
                    onPressed: () => _handleCreateProject(l10n),
                  ),
                ],
              ),
            ),

            if (_isProjectsSectionExpanded) ...[
              for (final projectName in projects)
                _buildProjectFolderTile(
                  projectName,
                  projectSessions[projectName] ?? [],
                  l10n,
                  theme,
                ),
            ],

            const SizedBox(height: 10),

            // Conversations Section Header
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 0, 2),
              child: Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      setState(() {
                        _isConversationsSectionExpanded = !_isConversationsSectionExpanded;
                      });
                      widget.keyVault.setConversationsSectionExpanded(_isConversationsSectionExpanded);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.conversations,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 4),
                          RotatedBox(
                            quarterTurns: _isConversationsSectionExpanded ? 1 : 0,
                            child: Icon(Icons.chevron_right, size: 15, color: isDark ? Colors.white54 : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.add, size: 20, color: isDark ? Colors.white60 : theme.colorScheme.onSurfaceVariant),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    tooltip: l10n.newStandaloneSession,
                    onPressed: () => _handleNewSession(l10n, projectName: null),
                  ),
                ],
              ),
            ),

            if (_isConversationsSectionExpanded) ...[
              if (standaloneSessions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text(
                    l10n.noHistorySessions,
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white30 : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5), fontStyle: FontStyle.italic),
                  ),
                )
              else
                for (final s in standaloneSessions)
                  _buildSessionItem(s, l10n, theme, indent: false),
            ],
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
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 0.5),
          child: Container(
            height: 26,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(5),
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedProjects.remove(projectName);
                  } else {
                    _expandedProjects.add(projectName);
                  }
                });
                widget.keyVault.setExpandedProjects(_expandedProjects);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    Icon(
                      isExpanded ? Icons.folder_open_outlined : Icons.folder_outlined,
                      size: 15,
                      color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        projectName,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : theme.colorScheme.onSurface,
                          fontSize: 12.5,
                          height: 1.1,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.add, size: 15, color: isDark ? Colors.white38 : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                      tooltip: l10n.newProjectSession,
                      onPressed: () => _handleNewSession(l10n, projectName: projectName),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Child sessions when folder is expanded
        if (isExpanded) ...[
          if (sessions.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 28, top: 2, bottom: 4),
              child: GestureDetector(
                onTap: () => _handleNewSession(l10n, projectName: projectName),
                child: Text(
                  '+ ${l10n.newProjectSession}',
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white30 : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5), fontStyle: FontStyle.italic),
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
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(left: indent ? 16.0 : 0.0, top: 0.5, bottom: 0.5),
      child: Container(
        height: 26,
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? const Color(0xFF262626) : theme.colorScheme.surfaceContainerHighest) : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(5),
          onTap: () => _handleSwitchSession(s.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    s.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.1,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? (isDark ? Colors.white : theme.colorScheme.primary) : (isDark ? Colors.white70 : theme.colorScheme.onSurface),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _formatRelativeTime(s.updatedAt),
                  style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, size: 13, color: isDark ? Colors.white38 : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  color: isDark ? const Color(0xFF1E1E1E) : theme.colorScheme.surface,
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
              child: AgentsDroidMark(
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
          ],
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
            color: const Color(0xFF2563EB),
            borderRadius: BorderRadius.circular(16).copyWith(bottomRight: const Radius.circular(2)),
          ),
          child: Text(
            msg.content,
            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
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
                ThoughtCard(
                  thought: block.thought,
                  isStreaming: msg.isStreaming,
                  durationSeconds: block.durationSeconds,
                ),

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
                    styleSheet: ChatScreen.buildMarkdownStyleSheet(theme),
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

  IconData _getApprovalModeIcon(ApprovalMode mode) {
    switch (mode) {
      case ApprovalMode.alwaysAsk:
        return Icons.pan_tool_outlined;
      case ApprovalMode.autoApprove:
        return Icons.shield_outlined;
      case ApprovalMode.yolo:
        return Icons.warning_amber_rounded;
    }
  }

  String _getApprovalModeLabel(ApprovalMode mode, AppLocalizations l10n) {
    switch (mode) {
      case ApprovalMode.alwaysAsk:
        return l10n.approvalAlwaysAsk;
      case ApprovalMode.autoApprove:
        return l10n.approvalAutoApprove;
      case ApprovalMode.yolo:
        return l10n.approvalYolo;
    }
  }

  String _getApprovalModeDesc(ApprovalMode mode, AppLocalizations l10n) {
    switch (mode) {
      case ApprovalMode.alwaysAsk:
        return l10n.approvalAlwaysAskDesc;
      case ApprovalMode.autoApprove:
        return l10n.approvalAutoApproveDesc;
      case ApprovalMode.yolo:
        return l10n.approvalYoloDesc;
    }
  }

  String _getThinkingLabel(ThinkingIntensity intensity, AppLocalizations l10n) {
    switch (intensity) {
      case ThinkingIntensity.off:
        return l10n.thinkingOff;
      case ThinkingIntensity.low:
        return l10n.thinkingLow;
      case ThinkingIntensity.medium:
        return l10n.thinkingMedium;
      case ThinkingIntensity.high:
        return l10n.thinkingHigh;
      case ThinkingIntensity.veryHigh:
        return l10n.thinkingVeryHigh;
    }
  }

  String _getThinkingShortLabel(ThinkingIntensity intensity) {
    switch (intensity) {
      case ThinkingIntensity.off:
        return 'off';
      case ThinkingIntensity.low:
        return 'low';
      case ThinkingIntensity.medium:
        return 'medium';
      case ThinkingIntensity.high:
        return 'high';
      case ThinkingIntensity.veryHigh:
        return 'max';
    }
  }

  String _getThinkingDesc(ThinkingIntensity intensity, AppLocalizations l10n) {
    switch (intensity) {
      case ThinkingIntensity.off:
        return l10n.thinkingOffDesc;
      case ThinkingIntensity.low:
        return l10n.thinkingLowDesc;
      case ThinkingIntensity.medium:
        return l10n.thinkingMediumDesc;
      case ThinkingIntensity.high:
        return l10n.thinkingHighDesc;
      case ThinkingIntensity.veryHigh:
        return l10n.thinkingVeryHighDesc;
    }
  }

  String _getDisplayModelName(String model, AppLocalizations l10n) {
    if (model.isEmpty) return l10n.noModelsConfigured;
    final config = widget.keyVault.getModel(model);
    if (config != null) return config.name;
    if (model.contains('claude-3-7-sonnet')) return 'Claude 3.7 Sonnet';
    if (model.contains('claude-3-5-sonnet')) return 'Claude 3.5 Sonnet';
    if (model == 'deepseek-chat') return 'DeepSeek V3';
    if (model == 'deepseek-reasoner') return 'DeepSeek R1';
    if (model == 'gpt-4o') return 'GPT-4o';
    if (model == 'gpt-4o-mini') return 'GPT-4o mini';
    if (model == 'o3-mini') return 'o3-mini';
    if (model.contains('gemini-2.5-flash')) return 'Gemini 2.5 Flash';
    if (model.contains('gemini-2.5-pro')) return 'Gemini 2.5 Pro';
    if (model.length > 36) return '${model.substring(0, 33)}...';
    return model;
  }

  void _showApprovalModeSheet(BuildContext context, AppLocalizations l10n) {
    _inputFocusNode.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
    FocusScope.of(context).unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
    FocusManager.instance.primaryFocus?.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);

    final currentMode = widget.keyVault.getApprovalMode();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    l10n.approvalTitle,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.approvalSubtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : theme.colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final mode in ApprovalMode.values) ...[
                    Material(
                      color: currentMode == mode
                          ? (isDark ? const Color(0xFF2A2A2A) : theme.colorScheme.primaryContainer.withValues(alpha: 0.35))
                          : (isDark ? const Color(0xFF222222) : theme.colorScheme.surfaceContainerHighest),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          Navigator.pop(ctx);
                          await widget.keyVault.setApprovalMode(mode);
                          if (mounted) setState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: currentMode == mode
                                  ? theme.colorScheme.primary
                                  : (isDark ? const Color(0xFF333333) : theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                _getApprovalModeIcon(mode),
                                size: 22,
                                color: mode == ApprovalMode.yolo ? Colors.amber : (isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _getApprovalModeLabel(mode, l10n),
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      _getApprovalModeDesc(mode, l10n),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.white60 : theme.colorScheme.onSurfaceVariant,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (currentMode == mode) ...[
                                const SizedBox(width: 8),
                                Icon(Icons.check, color: theme.colorScheme.primary, size: 20),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _inputFocusNode.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
        FocusScope.of(context).unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
        FocusManager.instance.primaryFocus?.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
      });
    });
  }

  void _showThinkingIntensitySheet(BuildContext context, AppLocalizations l10n) {
    _inputFocusNode.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
    FocusScope.of(context).unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
    FocusManager.instance.primaryFocus?.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);

    var intensity = widget.keyVault.getThinkingIntensity();
    final activeModel = widget.keyVault.getActiveModel();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetCtx, setModalState) {
            return SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : theme.colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Header row: Thinking label on left, Model switch + Reset on right
                    Row(
                      children: [
                        Text(
                          '${l10n.thinkingTitle}：${_getThinkingLabel(intensity, l10n)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : theme.colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        // Model switch button
                        Material(
                          color: isDark ? const Color(0xFF2C2C2C) : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              Navigator.pop(ctx);
                              _showModelPickerSheet(context, l10n);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF3D3D3D) : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _getDisplayModelName(activeModel, l10n),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.chevron_right, size: 16, color: isDark ? Colors.white54 : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Reset button
                        IconButton(
                          icon: Icon(Icons.refresh_rounded, size: 20, color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant),
                          tooltip: l10n.resetToDefault,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: () {
                            setModalState(() {
                              intensity = ThinkingIntensity.high;
                            });
                            widget.keyVault.setThinkingIntensity(ThinkingIntensity.high);
                            if (mounted) setState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Discrete Slider
                    SliderTheme(
                      data: SliderTheme.of(sheetCtx).copyWith(
                        activeTrackColor: isDark ? Colors.white : theme.colorScheme.primary,
                        inactiveTrackColor: isDark ? Colors.white24 : theme.colorScheme.outlineVariant,
                        thumbColor: isDark ? Colors.white : theme.colorScheme.primary,
                        overlayColor: (isDark ? Colors.white : theme.colorScheme.primary).withValues(alpha: 0.12),
                        tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 2.5),
                        activeTickMarkColor: isDark ? Colors.white70 : theme.colorScheme.primary,
                        inactiveTickMarkColor: isDark ? Colors.white30 : theme.colorScheme.outlineVariant,
                        trackHeight: 3.5,
                      ),
                      child: Slider(
                        value: intensity.level.toDouble(),
                        min: 0,
                        max: 4,
                        divisions: 4,
                        onChanged: (val) {
                          final newIntensity = ThinkingIntensity.values[val.round()];
                          setModalState(() {
                            intensity = newIntensity;
                          });
                          widget.keyVault.setThinkingIntensity(newIntensity);
                          if (mounted) setState(() {});
                        },
                      ),
                    ),
                    // Labels under ticks
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (final t in ThinkingIntensity.values)
                            Text(
                              _getThinkingLabel(t, l10n),
                              style: TextStyle(
                                fontSize: 11,
                                color: t == intensity
                                    ? (isDark ? Colors.white : theme.colorScheme.primary)
                                    : (isDark ? Colors.white38 : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                                fontWeight: t == intensity ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Description box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF262626) : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? const Color(0xFF333333) : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        _getThinkingDesc(intensity, l10n),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
    ).then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _inputFocusNode.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
        FocusScope.of(context).unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
        FocusManager.instance.primaryFocus?.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
      });
    });
}

  void _showModelPickerSheet(BuildContext context, AppLocalizations l10n) {
    _inputFocusNode.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
    FocusScope.of(context).unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
    FocusManager.instance.primaryFocus?.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);

    final currentModel = widget.keyVault.getActiveModel();
    final providers = widget.keyVault.getProviders();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.selectModel,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : theme.colorScheme.onSurface,
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: Icon(Icons.tune, size: 16, color: isDark ? Colors.white70 : theme.colorScheme.primary),
                        label: Text(l10n.modelsAndProviders, style: TextStyle(color: isDark ? Colors.white70 : theme.colorScheme.primary, fontSize: 12)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ModelSettingsScreen(
                                keyVault: widget.keyVault,
                              ),
                            ),
                          ).then((_) {
                            if (mounted) setState(() {});
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (providers.isEmpty || providers.every((p) => p.models.isEmpty))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: Text(
                          l10n.noModelsConfigured,
                          style: TextStyle(fontSize: 14, color: isDark ? Colors.white54 : theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: providers.length,
                        itemBuilder: (c, pIdx) {
                          final p = providers[pIdx];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 10, bottom: 4, left: 4),
                                child: Row(
                                  children: [
                                    Text(
                                      p.name,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white54 : theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    if (p.isCustom) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white10 : theme.colorScheme.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          l10n.customProviderTag,
                                          style: TextStyle(fontSize: 9, color: isDark ? Colors.white60 : theme.colorScheme.onSurfaceVariant),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              ...p.models.map((m) {
                                final isSelected = m.id == currentModel;
                                return ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  title: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          m.name,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            color: isSelected ? (isDark ? Colors.white : theme.colorScheme.primary) : (isDark ? Colors.white70 : theme.colorScheme.onSurface),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (m.supportsThinking) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.purple.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'Thinking',
                                            style: TextStyle(fontSize: 9, color: Colors.purpleAccent),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  subtitle: Text(
                                    '${p.name} • ${m.id}',
                                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                                  ),
                                  trailing: isSelected ? Icon(Icons.check, color: theme.colorScheme.primary, size: 18) : null,
                                  onTap: () async {
                                    Navigator.pop(ctx);
                                    await widget.keyVault.setActiveProviderId(p.id);
                                    await widget.keyVault.setActiveModel(m.id);
                                    if (mounted) setState(() {});
                                  },
                                );
                              }),
                              Divider(height: 12, color: isDark ? const Color(0xFF2A2A2A) : theme.colorScheme.outlineVariant),
                            ],
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SettingsScreen(
                            keyVault: widget.keyVault,
                            prootManager: widget.prootManager,
                          ),
                        ),
                      ).then((_) {
                        if (mounted) setState(() {});
                      });
                    },
                    child: Text(l10n.moreModelSettings, style: const TextStyle(color: Colors.white60, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _inputFocusNode.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
        FocusScope.of(context).unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
        FocusManager.instance.primaryFocus?.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
      });
    });
}

  void _showAttachmentMenu(BuildContext context, AppLocalizations l10n) {
    _inputFocusNode.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
    FocusScope.of(context).unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
    FocusManager.instance.primaryFocus?.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.addContext,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ListTile(
                    leading: Icon(Icons.insert_drive_file_outlined, color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant),
                    title: Text(l10n.addProjectFile, style: TextStyle(color: isDark ? Colors.white : theme.colorScheme.onSurface, fontSize: 14)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showFilePickerSheet(l10n);
                    },
                  ),
                  Divider(height: 1, color: isDark ? const Color(0xFF2C2C2C) : theme.colorScheme.outlineVariant),
                  ListTile(
                    leading: Icon(Icons.content_paste_outlined, color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant),
                    title: Text(l10n.pasteClipboard, style: TextStyle(color: isDark ? Colors.white : theme.colorScheme.onSurface, fontSize: 14)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null && data!.text!.isNotEmpty) {
                        final currentText = _textController.text;
                        final selection = _textController.selection;
                        if (selection.isValid && selection.start >= 0) {
                          final newText = currentText.replaceRange(selection.start, selection.end, data.text!);
                          _textController.text = newText;
                          _textController.selection = TextSelection.collapsed(offset: selection.start + data.text!.length);
                        } else {
                          _textController.text = currentText.isEmpty ? data.text! : '$currentText\n${data.text}';
                          _textController.selection = TextSelection.collapsed(offset: _textController.text.length);
                        }
                      }
                    },
                  ),
                  Divider(height: 1, color: isDark ? const Color(0xFF2C2C2C) : theme.colorScheme.outlineVariant),
                  ListTile(
                    leading: Icon(Icons.lightbulb_outline_rounded, color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant),
                    title: Text(l10n.commonPrompts, style: TextStyle(color: isDark ? Colors.white : theme.colorScheme.onSurface, fontSize: 14)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showCommonPromptsSheet(context, l10n);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _inputFocusNode.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
        FocusScope.of(context).unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
        FocusManager.instance.primaryFocus?.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
      });
    });
  }

  void _showFilePickerSheet(AppLocalizations l10n) async {
    _inputFocusNode.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
    FocusScope.of(context).unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
    FocusManager.instance.primaryFocus?.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);

    final proj = (_currentSession?.projectName != null &&
            _currentSession!.projectName!.isNotEmpty &&
            _currentSession!.projectName != WorkspaceService.defaultProjectName)
        ? 'projects/${_currentSession!.projectName}'
        : 'projects/${WorkspaceService.defaultProjectName}';
    final files = await widget.workspace.listFiles(relativePath: proj);

    if (!mounted) return;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.addProjectFile,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                if (files.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        l10n.noFilesInProject,
                        style: TextStyle(color: isDark ? Colors.white38 : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 13),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: files.length,
                      separatorBuilder: (context, index) => Divider(height: 1, color: isDark ? const Color(0xFF2C2C2C) : theme.colorScheme.outlineVariant),
                      itemBuilder: (c, idx) {
                        final file = files[idx];
                        final name = file.path.split(Platform.pathSeparator).last;
                        final isDir = file is Directory;
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            isDir ? Icons.folder_outlined : Icons.insert_drive_file_outlined,
                            size: 20,
                            color: isDir ? Colors.amber : (isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant),
                          ),
                          title: Text(
                            name,
                            style: TextStyle(fontSize: 13.5, color: isDark ? Colors.white : theme.colorScheme.onSurface),
                          ),
                          onTap: () {
                            final tag = '@$name ';
                            final currentText = _textController.text;
                            final selection = _textController.selection;
                            if (selection.isValid && selection.start >= 0) {
                              final newText = currentText.replaceRange(selection.start, selection.end, tag);
                              _textController.text = newText;
                              _textController.selection = TextSelection.collapsed(offset: selection.start + tag.length);
                            } else {
                              _textController.text = currentText.isEmpty ? tag : '$currentText $tag';
                              _textController.selection = TextSelection.collapsed(offset: _textController.text.length);
                            }
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _inputFocusNode.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
        FocusScope.of(context).unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
        FocusManager.instance.primaryFocus?.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
      });
    });
  }

  void _showCommonPromptsSheet(BuildContext context, AppLocalizations l10n) {
    _inputFocusNode.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
    FocusScope.of(context).unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
    FocusManager.instance.primaryFocus?.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);

    final prompts = [
      '请分析当前项目的架构设计与模块分工',
      '请审查代码中是否存在潜在 Bug 或未捕获的边界异常',
      '请为核心函数编写对应的单元测试用例',
      '请重构此段代码以提高执行效率与可维护性',
      '请为项目编写清晰的 API 文档与使用说明',
    ];

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.commonPrompts,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final p in prompts)
                    ListTile(
                      dense: true,
                      title: Text(p, style: TextStyle(fontSize: 13.5, color: isDark ? Colors.white : theme.colorScheme.onSurface)),
                      trailing: Icon(Icons.arrow_forward_ios, size: 12, color: isDark ? Colors.white38 : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                      onTap: () {
                        _textController.text = p;
                        _textController.selection = TextSelection.collapsed(offset: p.length);
                        Navigator.pop(ctx);
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _inputFocusNode.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
        FocusScope.of(context).unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
        FocusManager.instance.primaryFocus?.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
      });
    });
  }

  Widget _buildInputBar(ThemeData theme, AppLocalizations l10n) {
    final isWorking = _agentState != AgentState.idle;
    final isDark = theme.brightness == Brightness.dark;
    final approvalMode = widget.keyVault.getApprovalMode();
    final thinkingIntensity = widget.keyVault.getThinkingIntensity();
    final activeModel = widget.keyVault.getActiveModel();
    final hasText = _textController.text.trim().isNotEmpty;

    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 4,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF212121) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark ? const Color(0xFF333333) : const Color(0xFFE5E7EB),
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Multiline Input Field
            TextField(
              controller: _textController,
              focusNode: _inputFocusNode,
              autofocus: false,
              minLines: 2,
              maxLines: 6,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              onTapOutside: (_) {
                _inputFocusNode.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
                FocusManager.instance.primaryFocus?.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
              },
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white : Colors.black87,
                height: 1.35,
              ),
              decoration: InputDecoration.collapsed(
                hintText: isWorking ? l10n.inputHintWorking : l10n.inputBoxHint,
                hintStyle: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Bottom Action Bar
            Row(
              children: [
                // + Attachment Button
                Material(
                  color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE5E7EB),
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _showAttachmentMenu(context, l10n),
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: Icon(
                        Icons.add,
                        size: 18,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Approval Mode Pill
                Material(
                  color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _showApprovalModeSheet(context, l10n),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFD1D5DB),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getApprovalModeIcon(approvalMode),
                            size: 14,
                            color: approvalMode == ApprovalMode.yolo
                                ? Colors.amber
                                : (isDark ? Colors.white70 : Colors.black87),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getApprovalModeLabel(approvalMode, l10n),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.keyboard_arrow_down,
                            size: 14,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Model & Thinking Intensity Pill - dynamically expands/shrinks, right-aligned next to send button
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Material(
                      color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: activeModel.isEmpty
                            ? () => _showModelPickerSheet(context, l10n)
                            : () => _showThinkingIntensitySheet(context, l10n),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFD1D5DB),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  activeModel.isEmpty
                                      ? l10n.noModelsConfigured
                                      : '${_getDisplayModelName(activeModel, l10n)} ${_getThinkingShortLabel(thinkingIntensity)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.keyboard_arrow_down,
                                size: 14,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Send / Stop Circular Button (Primary color restored)
                Material(
                  color: isWorking
                      ? Colors.redAccent
                      : (hasText
                          ? theme.colorScheme.primary
                          : (isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE0E0E0))),
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: isWorking
                        ? () => _coordinator.interrupt()
                        : (hasText ? () => _handleSendMessage() : null),
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: Icon(
                        isWorking ? Icons.stop_rounded : Icons.arrow_upward_rounded,
                        size: 18,
                        color: isWorking || hasText
                            ? Colors.white
                            : (isDark ? Colors.white30 : Colors.black26),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationHistoryModal extends StatefulWidget {
  final SessionService sessionService;
  final String? currentSessionId;
  final ChatSessionSummary? currentSessionSummary;
  final ValueChanged<String> onSelectSession;
  final Future<void> Function(String id) onArchiveSession;
  final Future<void> Function(String id) onUnarchiveSession;
  final Future<void> Function(String id) onDeleteSession;
  final String Function(DateTime dt) formatRelativeTime;
  final AppLocalizations l10n;

  const _ConversationHistoryModal({
    required this.sessionService,
    required this.currentSessionId,
    this.currentSessionSummary,
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
    if (widget.currentSessionSummary != null && !widget.currentSessionSummary!.isArchived) {
      final idx = list.indexWhere((s) => s.id == widget.currentSessionSummary!.id);
      if (idx >= 0) {
        list[idx] = widget.currentSessionSummary!;
      } else {
        list.insert(0, widget.currentSessionSummary!);
      }
    }
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
      if (s.projectName != null &&
          s.projectName!.isNotEmpty &&
          s.projectName != WorkspaceService.defaultProjectName) {
        availableProjects.add(s.projectName!);
      }
    }

    final filtered = _allSessions.where((s) {
      final isStandalone = s.projectName == null ||
          s.projectName!.isEmpty ||
          s.projectName == WorkspaceService.defaultProjectName;
      if (_selectedFilter == 'standalone' && !isStandalone) return false;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181818) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black26,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Icon(Icons.history_rounded, size: 22, color: isDark ? Colors.white70 : Colors.black54),
                const SizedBox(width: 10),
                Text(
                  widget.l10n.conversationHistory,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, size: 20, color: isDark ? Colors.white60 : Colors.black45),
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
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: widget.l10n.searchConversations,
                hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 13),
                prefixIcon: Icon(Icons.search, size: 18, color: isDark ? Colors.white38 : Colors.black38),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, size: 16, color: isDark ? Colors.white38 : Colors.black38),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? const Color(0xFF242424) : const Color(0xFFF1F5F9),
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
                _buildFilterChip('all', widget.l10n.allConversations, isDark: isDark),
                const SizedBox(width: 6),
                _buildFilterChip('standalone', widget.l10n.conversations, isDark: isDark),
                const SizedBox(width: 6),
                for (final proj in availableProjects) ...[
                  _buildFilterChip(proj, proj, isProject: true, isDark: isDark),
                  const SizedBox(width: 6),
                ],
                _buildFilterChip('archived', widget.l10n.archivedSessions, isDark: isDark),
              ],
            ),
          ),

          Divider(color: isDark ? const Color(0xFF262626) : const Color(0xFFE5E7EB), height: 1),

          // Sessions List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Text(
                          widget.l10n.noMatchingConversations,
                          style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 13),
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
                              color: isCurrent
                                  ? (isDark ? const Color(0xFF282828) : const Color(0xFFEFF6FF))
                                  : (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFAFAFA)),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isCurrent
                                    ? Colors.blueAccent.withValues(alpha: 0.5)
                                    : (isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE2E8F0)),
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
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    widget.formatRelativeTime(s.updatedAt),
                                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    if (s.projectName != null &&
                                        s.projectName!.isNotEmpty &&
                                        s.projectName != WorkspaceService.defaultProjectName) ...[
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
                                          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          widget.l10n.conversations,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isDark ? Colors.white60 : Colors.black54,
                                          ),
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
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isDark ? Colors.white24 : Colors.black38,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              trailing: PopupMenuButton<String>(
                                icon: Icon(Icons.more_vert, size: 16, color: isDark ? Colors.white38 : Colors.black45),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                color: isDark ? const Color(0xFF252525) : Colors.white,
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

  Widget _buildFilterChip(String key, String label, {bool isProject = false, required bool isDark}) {
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
        color: isSelected
            ? (isDark ? Colors.white : Colors.blueAccent)
            : (isDark ? Colors.white60 : Colors.black54),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      backgroundColor: isDark ? const Color(0xFF222222) : const Color(0xFFF1F5F9),
      selectedColor: isDark ? const Color(0xFF333333) : const Color(0xFFDBEAFE),
      side: BorderSide(
        color: isSelected ? Colors.blueAccent : (isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      visualDensity: VisualDensity.compact,
    );
  }
}

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:uuid/uuid.dart';

import '../../core/agent/engine_coordinator.dart';
import '../../core/notification/foreground_service_manager.dart';
import '../../core/proot/proot_manager.dart';
import '../../core/providers/app_providers.dart';
import '../../core/storage/key_vault.dart';
import '../../core/storage/session_service.dart';
import '../../core/storage/workspace_service.dart';
import '../../l10n/app_localizations.dart';
import '../../models/agent_event.dart';
import '../../models/chat_message.dart';
import '../../models/chat_session.dart';
import '../explorer/workspace_explorer_screen.dart';
import '../settings/model_settings_screen.dart';
import '../settings/settings_screen.dart';
import '../terminal/subsystem_terminal_screen.dart';
import 'widgets/agents_droid_mark.dart';
import 'widgets/chat_bottom_input_bar.dart';
import 'widgets/chat_message_bubble.dart';
import 'widgets/conversation_history_modal.dart';
import 'widgets/chat_history_drawer.dart';

class ChatScreen extends StatelessWidget {
  final KeyVault? keyVault;
  final WorkspaceService? workspace;
  final PRootManager? prootManager;
  final SessionService? sessionService;

  const ChatScreen({
    super.key,
    this.keyVault,
    this.workspace,
    this.prootManager,
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

  bool _hasProviderScope(BuildContext context) {
    try {
      ProviderScope.containerOf(context, listen: false);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = _ChatScreenView(
      keyVault: keyVault,
      workspace: workspace,
      prootManager: prootManager,
      sessionService: sessionService,
    );

    if (_hasProviderScope(context)) {
      return view;
    }

    return ProviderScope(
      overrides: [
        if (keyVault != null) keyVaultProvider.overrideWithValue(keyVault!),
        if (workspace != null) workspaceServiceProvider.overrideWithValue(workspace!),
        if (sessionService != null) sessionServiceProvider.overrideWithValue(sessionService!),
        if (prootManager != null) prootManagerProvider.overrideWithValue(prootManager!),
      ],
      child: view,
    );
  }
}

class _ChatScreenView extends ConsumerStatefulWidget {
  final KeyVault? keyVault;
  final WorkspaceService? workspace;
  final PRootManager? prootManager;
  final SessionService? sessionService;

  const _ChatScreenView({
    this.keyVault,
    this.workspace,
    this.prootManager,
    this.sessionService,
  });

  @override
  ConsumerState<_ChatScreenView> createState() => _ChatScreenViewState();
}

class _ChatScreenViewState extends ConsumerState<_ChatScreenView> {
  KeyVault get _effectiveKeyVault {
    if (widget.keyVault != null) return widget.keyVault!;
    try {
      return ref.read(keyVaultProvider);
    } catch (_) {
      throw StateError('KeyVault must be provided via constructor or ProviderScope');
    }
  }

  WorkspaceService get _effectiveWorkspace {
    if (widget.workspace != null) return widget.workspace!;
    try {
      return ref.read(workspaceServiceProvider);
    } catch (_) {
      throw StateError('WorkspaceService must be provided via constructor or ProviderScope');
    }
  }

  SessionService get _effectiveSessionService {
    if (widget.sessionService != null) return widget.sessionService!;
    try {
      return ref.read(sessionServiceProvider);
    } catch (_) {
      return SessionService();
    }
  }

  PRootManager get _effectivePRootManager {
    if (widget.prootManager != null) return widget.prootManager!;
    try {
      return ref.read(prootManagerProvider);
    } catch (_) {
      return PRootManager();
    }
  }

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
  DateTime? _currentTurnThinkingStart;
  Future<List<dynamic>>? _treeDataFuture;

  void _refreshTreeData() {
    _treeDataFuture = Future.wait([
      _effectiveWorkspace.listProjects(),
      _sessionService.listSessions(isArchived: false),
    ]);
  }

  @override
  void initState() {
    super.initState();
    final kv = _effectiveKeyVault;
    final ws = _effectiveWorkspace;
    final pm = _effectivePRootManager;

    _coordinator = EngineCoordinator(
      keyVault: kv,
      workspace: ws,
      prootManager: pm,
    );
    _foregroundManager = ForegroundServiceManager();
    _foregroundSubscription = _foregroundManager.bindAgentEvents(_coordinator.eventStream);
    _sessionService = _effectiveSessionService;
    _expandedProjects.addAll(kv.preferences.getExpandedProjects());
    _refreshTreeData();
    _initSessionService();
    _listenToEngineEvents();
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
    await _effectiveWorkspace.switchProject(null);
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
    await _effectiveWorkspace.switchProject(actualProject);

    if (actualProject != null) {
      _expandedProjects.add(actualProject);
      _effectiveKeyVault.preferences.setExpandedProjects(_expandedProjects);
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
      await _effectiveWorkspace.switchProject(actualProject);
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
      await _effectiveWorkspace.createProject(projectName);
      setState(() {
        _expandedProjects.add(projectName);
      });
      await _effectiveKeyVault.preferences.setExpandedProjects(_expandedProjects);
      await _handleNewSession(l10n, projectName: projectName);
    }
  }

  Future<void> _showChangeProjectDialog(AppLocalizations l10n) async {
    final rawProjects = await _effectiveWorkspace.listProjects();
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
                    await _effectiveWorkspace.switchProject(null);
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
                          await _effectiveWorkspace.switchProject(proj);
                          if (_currentSession != null) {
                            _currentSession!.projectName = proj;
                            await _sessionService.saveSession(_currentSession!);
                            _expandedProjects.add(proj);
                            _effectiveKeyVault.preferences.setExpandedProjects(_expandedProjects);
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
        return ConversationHistoryModal(
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
                    prootManager: _effectivePRootManager,
                    keyVault: _effectiveKeyVault,
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
    return ChatHistoryDrawer(
      workspace: _effectiveWorkspace,
      sessionService: _sessionService,
      keyVault: _effectiveKeyVault,
      prootManager: _effectivePRootManager,
      currentSessionId: _currentSession?.id,
      currentSession: _currentSession,
      treeDataFuture: _treeDataFuture,
      onRefreshTree: _refreshTreeData,
      onNewSession: (projectName) => _handleNewSession(l10n, projectName: projectName),
      onSelectSession: (s) => _handleSwitchSession(s.id),
      onRenameSession: (s) => _handleRenameSession(s, l10n),
      onArchiveSession: (id) => _handleArchiveSession(id, l10n),
      onUnarchiveSession: (id) => _handleUnarchiveSession(id, l10n),
      onDeleteSession: (id) => _handleDeleteSession(id, l10n),
      onCreateProject: () => _handleCreateProject(l10n),
      onOpenConversationHistory: () => _showConversationHistorySheet(context, l10n, theme),
      onOpenWorkspaceFiles: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WorkspaceExplorerScreen(
              workspace: _effectiveWorkspace,
              prootManager: _effectivePRootManager,
            ),
          ),
        );
      },
      onOpenSettings: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SettingsScreen(
              keyVault: _effectiveKeyVault,
              prootManager: _effectivePRootManager,
            ),
          ),
        );
        if (mounted) setState(() {});
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
    return ChatMessageBubble(
      message: msg,
      markdownStyleSheet: ChatScreen.buildMarkdownStyleSheet(theme),
      onApprovalResponse: (toolCallId, approve) => _coordinator.respondApproval(toolCallId, approve),
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
    final config = _effectiveKeyVault.getModel(model);
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

    ApprovalMode currentMode;
    try {
      currentMode = ref.read(approvalModeProvider);
    } catch (_) {
      currentMode = _effectiveKeyVault.getApprovalMode();
    }
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
                          try {
                            ref.read(approvalModeProvider.notifier).setApprovalMode(mode);
                          } catch (_) {
                            await _effectiveKeyVault.setApprovalMode(mode);
                          }
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

    ThinkingIntensity intensity;
    try {
      intensity = ref.read(thinkingIntensityProvider);
    } catch (_) {
      intensity = _effectiveKeyVault.getThinkingIntensity();
    }
    String activeModel;
    try {
      activeModel = ref.read(activeModelProvider);
    } catch (_) {
      activeModel = _effectiveKeyVault.getActiveModel();
    }
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
                            try {
                              ref.read(thinkingIntensityProvider.notifier).setThinkingIntensity(ThinkingIntensity.high);
                            } catch (_) {
                              _effectiveKeyVault.setThinkingIntensity(ThinkingIntensity.high);
                            }
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
                          try {
                            ref.read(thinkingIntensityProvider.notifier).setThinkingIntensity(newIntensity);
                          } catch (_) {
                            _effectiveKeyVault.setThinkingIntensity(newIntensity);
                          }
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

    String currentModel;
    try {
      currentModel = ref.read(activeModelProvider);
    } catch (_) {
      currentModel = _effectiveKeyVault.getActiveModel();
    }
    final providers = _effectiveKeyVault.getProviders();
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
                                keyVault: _effectiveKeyVault,
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
                                    await _effectiveKeyVault.setActiveProviderId(p.id);
                                    try {
                                      ref.read(activeModelProvider.notifier).setActiveModel(m.id);
                                    } catch (_) {
                                      await _effectiveKeyVault.setActiveModel(m.id);
                                    }
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
                            keyVault: _effectiveKeyVault,
                            prootManager: _effectivePRootManager,
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
    final files = await _effectiveWorkspace.listFiles(relativePath: proj);

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
    ApprovalMode approvalMode;
    try {
      approvalMode = ref.watch(approvalModeProvider);
    } catch (_) {
      approvalMode = _effectiveKeyVault.getApprovalMode();
    }

    ThinkingIntensity thinkingIntensity;
    try {
      thinkingIntensity = ref.watch(thinkingIntensityProvider);
    } catch (_) {
      thinkingIntensity = _effectiveKeyVault.getThinkingIntensity();
    }

    String activeModel;
    try {
      activeModel = ref.watch(activeModelProvider);
    } catch (_) {
      activeModel = _effectiveKeyVault.getActiveModel();
    }

    return ChatBottomInputBar(
      textController: _textController,
      inputFocusNode: _inputFocusNode,
      isWorking: isWorking,
      approvalMode: approvalMode,
      thinkingIntensity: thinkingIntensity,
      activeModel: activeModel,
      displayModelName: _getDisplayModelName(activeModel, l10n),
      approvalModeLabel: _getApprovalModeLabel(approvalMode, l10n),
      approvalModeIcon: _getApprovalModeIcon(approvalMode),
      thinkingShortLabel: _getThinkingShortLabel(thinkingIntensity),
      onAttachmentTap: () => _showAttachmentMenu(context, l10n),
      onApprovalModeTap: () => _showApprovalModeSheet(context, l10n),
      onThinkingTap: activeModel.isEmpty
          ? () => _showModelPickerSheet(context, l10n)
          : () => _showThinkingIntensitySheet(context, l10n),
      onSend: _handleSendMessage,
      onStop: () => _coordinator.interrupt(),
    );
  }
}
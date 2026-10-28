import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/storage/key_vault.dart';
import '../../../core/storage/session_service.dart';
import '../../../core/storage/workspace_service.dart';
import '../../../core/proot/proot_manager.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/chat_session.dart';

enum ConversationSortOrder { recent, name }
enum ProjectSortOrder { name, recent }

/// Modular, responsive Drawer widget for project navigation and session history.
class ChatHistoryDrawer extends StatefulWidget {
  final WorkspaceService workspace;
  final SessionService sessionService;
  final KeyVault keyVault;
  final PRootManager? prootManager;
  final String? currentSessionId;
  final ChatSession? currentSession;
  final Future<List<dynamic>>? treeDataFuture;
  final VoidCallback onRefreshTree;
  final void Function(String? projectName) onNewSession;
  final void Function(ChatSessionSummary session) onSelectSession;
  final void Function(ChatSessionSummary session) onRenameSession;
  final void Function(String sessionId) onArchiveSession;
  final void Function(String sessionId) onUnarchiveSession;
  final void Function(String sessionId) onDeleteSession;
  final VoidCallback onCreateProject;
  final VoidCallback onOpenConversationHistory;
  final VoidCallback onOpenWorkspaceFiles;
  final VoidCallback onOpenSettings;

  const ChatHistoryDrawer({
    super.key,
    required this.workspace,
    required this.sessionService,
    required this.keyVault,
    this.prootManager,
    this.currentSessionId,
    this.currentSession,
    this.treeDataFuture,
    required this.onRefreshTree,
    required this.onNewSession,
    required this.onSelectSession,
    required this.onRenameSession,
    required this.onArchiveSession,
    required this.onUnarchiveSession,
    required this.onDeleteSession,
    required this.onCreateProject,
    required this.onOpenConversationHistory,
    required this.onOpenWorkspaceFiles,
    required this.onOpenSettings,
  });

  @override
  State<ChatHistoryDrawer> createState() => _ChatHistoryDrawerState();
}

class _ChatHistoryDrawerState extends State<ChatHistoryDrawer> {
  final Set<String> _expandedProjects = {};
  bool _showArchived = false;
  late bool _isProjectsSectionExpanded;
  late bool _isConversationsSectionExpanded;
  ConversationSortOrder _conversationSortOrder = ConversationSortOrder.recent;
  ProjectSortOrder _projectSortOrder = ProjectSortOrder.name;

  @override
  void initState() {
    super.initState();
    _expandedProjects.addAll(widget.keyVault.getExpandedProjects());
    _isProjectsSectionExpanded = widget.keyVault.isProjectsSectionExpanded();
    _isConversationsSectionExpanded = widget.keyVault.isConversationsSectionExpanded();
  }

  String _formatRelativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 30) return '${diff.inDays}d';
    return DateFormat('MM/dd').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
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

            // Top Action Buttons
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
                        widget.onNewSession(null);
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
                      onTap: () {
                        widget.onOpenConversationHistory();
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
                    _buildDisplayOptionsMenu(l10n, theme),
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
                widget.onOpenWorkspaceFiles();
              },
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.settings_outlined, size: 18),
              title: Text(l10n.settings, style: const TextStyle(fontSize: 13)),
              onTap: () {
                Navigator.pop(context);
                widget.onOpenSettings();
              },
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildDisplayOptionsMenu(AppLocalizations l10n, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.filter_list_rounded,
        size: 19,
        color: _showArchived ? Colors.amber : (isDark ? Colors.white60 : theme.colorScheme.onSurfaceVariant),
      ),
      tooltip: l10n.displayOptions,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      color: isDark ? const Color(0xFF222222) : theme.colorScheme.surface,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isDark ? const Color(0xFF333333) : theme.colorScheme.outlineVariant),
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
    return FutureBuilder<List<dynamic>>(
      future: widget.treeDataFuture ??
          Future.wait([
            widget.workspace.listProjects(),
            widget.sessionService.listSessions(isArchived: false),
          ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final rawProjects = (snapshot.data?[0] as List<String>?) ?? [];
        final rawSessions = (snapshot.data?[1] as List<ChatSessionSummary>?) ?? [];
        final sessions = List<ChatSessionSummary>.from(rawSessions);

        if (widget.currentSession != null && !widget.currentSession!.isArchived) {
          final index = sessions.indexWhere((s) => s.id == widget.currentSession!.id);
          if (index >= 0) {
            sessions[index] = widget.currentSession!.toSummary();
          } else {
            sessions.add(widget.currentSession!.toSummary());
          }
        }

        final projects = List<String>.from(rawProjects)
          ..removeWhere((p) => p == WorkspaceService.defaultProjectName);

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
                    onPressed: widget.onCreateProject,
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
                    onPressed: () => widget.onNewSession(null),
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
                    Text(
                      '${sessions.length}',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white38 : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(Icons.add, size: 14, color: isDark ? Colors.white54 : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                      tooltip: l10n.newProjectSession,
                      onPressed: () => widget.onNewSession(projectName),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (isExpanded)
          for (final s in sessions)
            _buildSessionItem(s, l10n, theme, indent: true),
      ],
    );
  }

  Widget _buildSessionItem(
    ChatSessionSummary s,
    AppLocalizations l10n,
    ThemeData theme, {
    required bool indent,
  }) {
    final isSelected = widget.currentSessionId == s.id;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        left: indent ? 22.0 : 4.0,
        right: 4.0,
        top: 0.5,
        bottom: 0.5,
      ),
      child: Container(
        height: 26,
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF262626) : theme.colorScheme.primary.withValues(alpha: 0.12))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(5),
          onTap: () {
            Navigator.pop(context);
            widget.onSelectSession(s);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 13,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : (isDark ? Colors.white38 : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    s.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.1,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? (isDark ? Colors.white : theme.colorScheme.primary)
                          : (isDark ? Colors.white70 : theme.colorScheme.onSurface),
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
                      widget.onRenameSession(s);
                    } else if (val == 'archive') {
                      widget.onArchiveSession(s.id);
                    } else if (val == 'delete') {
                      widget.onDeleteSession(s.id);
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
      future: widget.sessionService.listSessions(isArchived: true),
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
                      onPressed: () => widget.onUnarchiveSession(s.id),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                      tooltip: l10n.delete,
                      onPressed: () => widget.onDeleteSession(s.id),
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
}

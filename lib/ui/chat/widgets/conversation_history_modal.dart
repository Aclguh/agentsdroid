import 'package:flutter/material.dart';
import '../../../core/storage/session_service.dart';
import '../../../core/storage/workspace_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/chat_session.dart';

class ConversationHistoryModal extends StatefulWidget {
  final SessionService sessionService;
  final String? currentSessionId;
  final ChatSessionSummary? currentSessionSummary;
  final ValueChanged<String> onSelectSession;
  final Future<void> Function(String id) onArchiveSession;
  final Future<void> Function(String id) onUnarchiveSession;
  final Future<void> Function(String id) onDeleteSession;
  final String Function(DateTime dt) formatRelativeTime;
  final AppLocalizations l10n;

  const ConversationHistoryModal({
    super.key,
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
  State<ConversationHistoryModal> createState() => _ConversationHistoryModalState();
}

class _ConversationHistoryModalState extends State<ConversationHistoryModal> {
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
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
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

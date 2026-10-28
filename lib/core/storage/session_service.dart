import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/chat_session.dart';

class SessionService {
  Directory? _sessionsDir;
  final _uuid = const Uuid();
  final Map<String, ChatSessionSummary> _summaryCache = {};
  final Map<String, ChatSession> _sessionCache = {};
  bool _cacheLoaded = false;

  static const String _indexFileName = 'sessions_index.json';

  Future<void> init({Directory? baseDir}) async {
    final appDir = baseDir ?? await getApplicationDocumentsDirectory();
    _sessionsDir = Directory(p.join(appDir.path, 'sessions'));
    if (!_sessionsDir!.existsSync()) {
      _sessionsDir!.createSync(recursive: true);
    }
    _loadIndex();
  }

  Directory get sessionsDir {
    if (_sessionsDir == null) {
      throw StateError('SessionService not initialized. Call init() first.');
    }
    return _sessionsDir!;
  }

  File _getSessionFile(String id) {
    return File(p.join(sessionsDir.path, '$id.json'));
  }

  File _getIndexFile() {
    return File(p.join(sessionsDir.path, _indexFileName));
  }

  void _saveIndex() {
    try {
      final indexFile = _getIndexFile();
      final list = _summaryCache.values.map((s) => s.toJson()).toList();
      indexFile.writeAsStringSync(jsonEncode(list));
    } catch (_) {}
  }

  void _loadIndex() {
    final dir = sessionsDir;
    if (!dir.existsSync()) return;
    _summaryCache.clear();

    final indexFile = _getIndexFile();
    if (indexFile.existsSync()) {
      try {
        final content = indexFile.readAsStringSync();
        final list = jsonDecode(content) as List<dynamic>;
        for (final item in list) {
          final summary = ChatSessionSummary.fromJson(item as Map<String, dynamic>);
          _summaryCache[summary.id] = summary;
        }
        _cacheLoaded = true;
        return;
      } catch (_) {
        // Fallback to directory scan if index corrupted
        _summaryCache.clear();
      }
    }

    try {
      final entities = dir.listSync();
      for (final entity in entities) {
        if (entity is File &&
            entity.path.endsWith('.json') &&
            !entity.path.endsWith(_indexFileName)) {
          try {
            final content = entity.readAsStringSync();
            final json = jsonDecode(content) as Map<String, dynamic>;
            final rawMessages = json['messages'] as List<dynamic>? ?? const [];
            if (rawMessages.isNotEmpty) {
              final id = json['id'] as String;
              final isArchived = json['isArchived'] as bool? ?? false;
              _summaryCache[id] = ChatSessionSummary(
                id: id,
                title: json['title'] as String? ?? '新会话',
                createdAt: DateTime.parse(json['createdAt'] as String),
                updatedAt: DateTime.parse(json['updatedAt'] as String),
                messageCount: rawMessages.length,
                projectName: json['projectName'] as String?,
                isArchived: isArchived,
              );
            } else {
              entity.deleteSync();
            }
          } catch (_) {}
        }
      }
      _saveIndex();
    } catch (_) {}

    _cacheLoaded = true;
  }

  Future<List<ChatSessionSummary>> listSessions({bool? isArchived}) async {
    if (!_cacheLoaded) {
      _loadIndex();
    }

    final list = _summaryCache.values
        .where((s) => isArchived == null || s.isArchived == isArchived)
        .toList();

    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  Future<ChatSession?> getSession(String id) async {
    if (_sessionCache.containsKey(id)) {
      final cached = _sessionCache[id]!;
      if (cached.messages.isEmpty) {
        _sessionCache.remove(id);
        _summaryCache.remove(id);
        final file = _getSessionFile(id);
        if (file.existsSync()) {
          file.deleteSync();
        }
        _saveIndex();
        return null;
      }
      return cached;
    }

    final file = _getSessionFile(id);
    if (!file.existsSync()) return null;

    try {
      final content = file.readAsStringSync();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final session = ChatSession.fromJson(json);
      if (session.messages.isEmpty) {
        file.deleteSync();
        _summaryCache.remove(id);
        _saveIndex();
        return null;
      }
      _sessionCache[id] = session;
      _summaryCache[id] = session.toSummary();
      return session;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSession(ChatSession session) async {
    final file = _getSessionFile(session.id);
    if (session.messages.isEmpty) {
      _sessionCache.remove(session.id);
      _summaryCache.remove(session.id);
      if (file.existsSync()) {
        file.deleteSync();
      }
      _saveIndex();
      return;
    }

    session.updatedAt = DateTime.now();
    _sessionCache[session.id] = session;
    _summaryCache[session.id] = session.toSummary();
    final jsonString = jsonEncode(session.toJson());
    file.writeAsStringSync(jsonString);
    _saveIndex();
  }

  Future<void> deleteSession(String id) async {
    _sessionCache.remove(id);
    _summaryCache.remove(id);
    final file = _getSessionFile(id);
    if (file.existsSync()) {
      file.deleteSync();
    }
    _saveIndex();
  }

  Future<ChatSession> renameSession(String id, String newTitle) async {
    final summary = _summaryCache[id];
    if (summary != null) {
      summary.title = newTitle;
    }
    final session = await getSession(id);
    if (session == null) {
      throw FileSystemException('Session not found', id);
    }
    session.title = newTitle;
    await saveSession(session);
    return session;
  }

  Future<ChatSession> archiveSession(String id) async {
    final summary = _summaryCache[id];
    if (summary != null) {
      summary.isArchived = true;
    }
    final session = await getSession(id);
    if (session == null) {
      throw FileSystemException('Session not found', id);
    }
    session.isArchived = true;
    await saveSession(session);
    return session;
  }

  Future<ChatSession> unarchiveSession(String id) async {
    final summary = _summaryCache[id];
    if (summary != null) {
      summary.isArchived = false;
    }
    final session = await getSession(id);
    if (session == null) {
      throw FileSystemException('Session not found', id);
    }
    session.isArchived = false;
    await saveSession(session);
    return session;
  }

  Future<ChatSession> createSession({
    String title = '新会话',
    String? projectName,
  }) async {
    final session = ChatSession(
      id: _uuid.v4(),
      title: title,
      projectName: projectName,
    );
    return session;
  }

  Future<ChatSession> getOrCreateLatestSession({
    String defaultTitle = '新会话',
    String? projectName,
  }) async {
    final list = await listSessions(isArchived: false);
    if (list.isNotEmpty) {
      final latest = await getSession(list.first.id);
      if (latest != null && latest.messages.isNotEmpty) return latest;
    }
    return await createSession(title: defaultTitle, projectName: projectName);
  }
}

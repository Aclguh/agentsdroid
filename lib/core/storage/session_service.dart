import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/chat_session.dart';

class SessionService {
  Directory? _sessionsDir;
  final _uuid = const Uuid();

  Future<void> init({Directory? baseDir}) async {
    final appDir = baseDir ?? await getApplicationDocumentsDirectory();
    _sessionsDir = Directory(p.join(appDir.path, 'sessions'));
    if (!_sessionsDir!.existsSync()) {
      _sessionsDir!.createSync(recursive: true);
    }
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

  Future<List<ChatSessionSummary>> listSessions({bool? isArchived}) async {
    final dir = sessionsDir;
    if (!dir.existsSync()) return [];

    final List<ChatSessionSummary> summaries = [];
    final entities = dir.listSync();

    for (final entity in entities) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final content = entity.readAsStringSync();
          final json = jsonDecode(content) as Map<String, dynamic>;
          final session = ChatSession.fromJson(json);
          // Only retain sessions that have actual messages
          if (session.messages.isNotEmpty) {
            if (isArchived == null || session.isArchived == isArchived) {
              summaries.add(session.toSummary());
            }
          } else {
            // Clean up any empty session file from disk
            entity.deleteSync();
          }
        } catch (_) {
          // Gracefully skip invalid or corrupted session files
        }
      }
    }

    // Sort by latest update first
    summaries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return summaries;
  }

  Future<ChatSession?> getSession(String id) async {
    final file = _getSessionFile(id);
    if (!file.existsSync()) return null;

    try {
      final content = file.readAsStringSync();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final session = ChatSession.fromJson(json);
      if (session.messages.isEmpty) {
        file.deleteSync();
        return null;
      }
      return session;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSession(ChatSession session) async {
    final file = _getSessionFile(session.id);
    // If the session has no messages, delete it from disk if exists (do not persist empty sessions)
    if (session.messages.isEmpty) {
      if (file.existsSync()) {
        file.deleteSync();
      }
      return;
    }

    session.updatedAt = DateTime.now();
    final jsonString = jsonEncode(session.toJson());
    file.writeAsStringSync(jsonString);
  }

  Future<void> deleteSession(String id) async {
    final file = _getSessionFile(id);
    if (file.existsSync()) {
      file.deleteSync();
    }
  }

  Future<ChatSession> renameSession(String id, String newTitle) async {
    final session = await getSession(id);
    if (session == null) {
      throw FileSystemException('Session not found', id);
    }
    session.title = newTitle;
    await saveSession(session);
    return session;
  }

  Future<ChatSession> archiveSession(String id) async {
    final session = await getSession(id);
    if (session == null) {
      throw FileSystemException('Session not found', id);
    }
    session.isArchived = true;
    await saveSession(session);
    return session;
  }

  Future<ChatSession> unarchiveSession(String id) async {
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
    return ChatSession(
      id: _uuid.v4(),
      title: title,
      projectName: projectName,
    );
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

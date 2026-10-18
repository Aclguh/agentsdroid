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
    if (!await _sessionsDir!.exists()) {
      await _sessionsDir!.create(recursive: true);
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

  Future<List<ChatSessionSummary>> listSessions() async {
    final dir = sessionsDir;
    if (!await dir.exists()) return [];

    final List<ChatSessionSummary> summaries = [];
    final entities = dir.listSync();

    for (final entity in entities) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final content = await entity.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;
          final session = ChatSession.fromJson(json);
          summaries.add(session.toSummary());
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
    if (!await file.exists()) return null;

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return ChatSession.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSession(ChatSession session) async {
    session.updatedAt = DateTime.now();
    final file = _getSessionFile(session.id);
    final jsonString = jsonEncode(session.toJson());
    await file.writeAsString(jsonString);
  }

  Future<void> deleteSession(String id) async {
    final file = _getSessionFile(id);
    if (await file.exists()) {
      await file.delete();
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

  Future<ChatSession> createSession({String title = '新会话'}) async {
    final session = ChatSession(
      id: _uuid.v4(),
      title: title,
    );
    await saveSession(session);
    return session;
  }

  Future<ChatSession> getOrCreateLatestSession({String defaultTitle = '新会话'}) async {
    final list = await listSessions();
    if (list.isNotEmpty) {
      final latest = await getSession(list.first.id);
      if (latest != null) return latest;
    }
    return await createSession(title: defaultTitle);
  }
}

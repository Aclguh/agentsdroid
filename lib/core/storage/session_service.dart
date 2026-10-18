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
          // Only retain sessions that have actual messages
          if (session.messages.isNotEmpty) {
            summaries.add(session.toSummary());
          } else {
            // Clean up any empty session file from disk
            await entity.delete();
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
    if (!await file.exists()) return null;

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final session = ChatSession.fromJson(json);
      if (session.messages.isEmpty) {
        await file.delete();
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
      if (await file.exists()) {
        await file.delete();
      }
      return;
    }

    session.updatedAt = DateTime.now();
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
    // Returns a new in-memory ChatSession; will not be written to disk until it has messages
    return ChatSession(
      id: _uuid.v4(),
      title: title,
    );
  }

  Future<ChatSession> getOrCreateLatestSession({String defaultTitle = '新会话'}) async {
    final list = await listSessions();
    if (list.isNotEmpty) {
      final latest = await getSession(list.first.id);
      if (latest != null && latest.messages.isNotEmpty) return latest;
    }
    return await createSession(title: defaultTitle);
  }
}

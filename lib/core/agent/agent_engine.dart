import '../../models/agent_event.dart';
import '../../models/chat_message.dart';

abstract class AgentEngine {
  Stream<AgentEvent> get eventStream;
  AgentState get currentState;

  Future<void> startTask(String prompt, {List<ChatMessage>? priorMessages});
  Future<void> respondApproval(String toolCallId, bool approved, {String? reason});
  Future<void> interrupt();
  void resetSession();
  Future<void> dispose();
}

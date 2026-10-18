import '../../models/agent_event.dart';

abstract class AgentEngine {
  Stream<AgentEvent> get eventStream;
  AgentState get currentState;

  Future<void> startTask(String prompt);
  Future<void> respondApproval(String toolCallId, bool approved, {String? reason});
  Future<void> interrupt();
  void resetSession();
  Future<void> dispose();
}

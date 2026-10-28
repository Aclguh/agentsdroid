import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../models/agent_event.dart';
import '../utils/app_logger.dart';

enum ForegroundTaskLevel {
  idle,
  running,
  urgentApproval,
  completed,
  error,
}

class ForegroundNotificationState {
  final ForegroundTaskLevel level;
  final String title;
  final String body;
  final bool isWakeLockHeld;
  final DateTime updatedAt;

  ForegroundNotificationState({
    required this.level,
    required this.title,
    required this.body,
    required this.isWakeLockHeld,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  static ForegroundNotificationState idle() => ForegroundNotificationState(
        level: ForegroundTaskLevel.idle,
        title: 'AgentsDroid 就绪',
        body: '等待发起新的 AI 编程任务',
        isWakeLockHeld: false,
      );
}

/// Manages Android foreground notification status and CPU WakeLock coordination.
class ForegroundServiceManager {
  final _stateController = StreamController<ForegroundNotificationState>.broadcast();
  Stream<ForegroundNotificationState> get stateStream => _stateController.stream;

  ForegroundNotificationState _currentState = ForegroundNotificationState.idle();
  ForegroundNotificationState get currentState => _currentState;

  bool _isWakeLockActive = false;
  bool get isWakeLockActive => _isWakeLockActive;

  /// Starts or transitions foreground execution
  void startTask(String taskPrompt) {
    _isWakeLockActive = true;
    _updateState(
      level: ForegroundTaskLevel.running,
      title: 'AgentsDroid: 正在执行任务',
      body: taskPrompt.length > 50 ? '${taskPrompt.substring(0, 50)}...' : taskPrompt,
    );
  }

  /// Updates current execution progress or tool step
  void updateProgress(String statusMessage, {bool waitingApproval = false}) {
    if (waitingApproval) {
      _updateState(
        level: ForegroundTaskLevel.urgentApproval,
        title: 'AgentsDroid: 待确认审批',
        body: statusMessage,
      );
    } else {
      _updateState(
        level: ForegroundTaskLevel.running,
        title: 'AgentsDroid: 正在运行',
        body: statusMessage,
      );
    }
  }

  /// Completes or halts foreground task
  void finishTask({required bool success, String? message}) {
    _isWakeLockActive = false;
    _updateState(
      level: success ? ForegroundTaskLevel.completed : ForegroundTaskLevel.error,
      title: success ? 'AgentsDroid: 任务已完成' : 'AgentsDroid: 任务异常中止',
      body: message ?? (success ? '所有文件修改与指令执行已就绪。' : '执行遇到错误。'),
    );
  }

  /// Attach to an Agent event stream to automatically reflect live lifecycle updates
  StreamSubscription<AgentEvent> bindAgentEvents(Stream<AgentEvent> eventStream) {
    return eventStream.listen((event) {
      if (event is StatusEvent) {
        switch (event.state) {
          case AgentState.idle:
            if (_currentState.level != ForegroundTaskLevel.idle) {
              _isWakeLockActive = false;
              _updateState(
                level: ForegroundTaskLevel.idle,
                title: 'AgentsDroid 就绪',
                body: event.message ?? '等待任务',
              );
            }
            break;
          case AgentState.thinking:
            _isWakeLockActive = true;
            _updateState(
              level: ForegroundTaskLevel.running,
              title: 'AgentsDroid: 思考中',
              body: event.message ?? 'Agent 正在分析代码上下文...',
            );
            break;
          case AgentState.executingTool:
            _isWakeLockActive = true;
            _updateState(
              level: ForegroundTaskLevel.running,
              title: 'AgentsDroid: 执行中',
              body: event.message ?? '正在执行工具命令或修改文件...',
            );
            break;
          case AgentState.waitingApproval:
            _updateState(
              level: ForegroundTaskLevel.urgentApproval,
              title: 'AgentsDroid: 等待用户审批',
              body: event.message ?? '需要确认是否允许执行带副作用的操作',
            );
            break;
          case AgentState.completed:
            finishTask(success: true, message: event.message);
            break;
          case AgentState.error:
            finishTask(success: false, message: event.message);
            break;
        }
      }
    });
  }

  static const MethodChannel _channel = MethodChannel('com.agentsdroid/foreground_service');

  void _updateState({
    required ForegroundTaskLevel level,
    required String title,
    required String body,
  }) {
    _currentState = ForegroundNotificationState(
      level: level,
      title: title,
      body: body,
      isWakeLockHeld: _isWakeLockActive,
    );
    _stateController.add(_currentState);
    AppLogger.info(
      '${level.name.toUpperCase()}: $title - $body (WakeLock: $_isWakeLockActive)',
      tag: 'ForegroundService',
    );

    if (!kIsWeb) {
      try {
        if (Platform.isAndroid) {
          if (level == ForegroundTaskLevel.running || level == ForegroundTaskLevel.urgentApproval) {
            _channel.invokeMethod('startOrUpdate', {
              'title': title,
              'body': body,
              'urgent': level == ForegroundTaskLevel.urgentApproval,
            });
          } else if (level == ForegroundTaskLevel.completed || level == ForegroundTaskLevel.idle || level == ForegroundTaskLevel.error) {
            _channel.invokeMethod('stopService');
          }
        }
      } catch (_) {}
    }
  }

  void dispose() {
    _stateController.close();
  }
}

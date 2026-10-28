import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/agent_event.dart';
import '../../models/chat_message.dart';
import '../agent/agent_engine.dart';
import '../errors/app_exceptions.dart';
import '../proot/proot_manager.dart';
import '../storage/key_vault.dart';
import '../storage/workspace_service.dart';

class BuiltinAgentEngine implements AgentEngine {
  final KeyVault _keyVault;
  final WorkspaceService _workspace;
  final PRootManager? prootManager;
  final http.Client? httpClient;

  final _eventController = StreamController<AgentEvent>.broadcast();
  @override
  Stream<AgentEvent> get eventStream => _eventController.stream;

  AgentState _currentState = AgentState.idle;
  @override
  AgentState get currentState => _currentState;

  // Pending approval completers: toolCallId -> Completer<bool>
  final Map<String, Completer<bool>> _pendingApprovals = {};
  bool _isInterrupted = false;

  // Active executing command processes for timeout and cancellation
  PRootProcess? _activePRootProcess;
  Process? _activeProcess;

  // Conversation history in memory
  final List<Map<String, dynamic>> _openaiHistory = [];
  final List<Map<String, dynamic>> _anthropicHistory = [];

  @visibleForTesting
  List<Map<String, dynamic>> get openaiHistory => List.unmodifiable(_openaiHistory);

  @visibleForTesting
  List<Map<String, dynamic>> get anthropicHistory => List.unmodifiable(_anthropicHistory);

  BuiltinAgentEngine(this._keyVault, this._workspace, {this.prootManager, this.httpClient});

  void _setState(AgentState state, [String? message]) {
    _currentState = state;
    _eventController.add(StatusEvent(state, message: message));
  }

  void syncSessionHistory(List<ChatMessage> priorMessages) {
    _openaiHistory.clear();
    _anthropicHistory.clear();

    _openaiHistory.add({
      'role': 'system',
      'content': _getSystemPrompt(),
    });

    final messagesToSync = priorMessages.length > 30
        ? priorMessages.sublist(priorMessages.length - 30)
        : priorMessages;

    for (final msg in messagesToSync) {
      if (msg.role == MessageRole.user) {
        if (msg.content.trim().isNotEmpty) {
          _openaiHistory.add({
            'role': 'user',
            'content': msg.content.trim(),
          });
          if (_anthropicHistory.isNotEmpty && _anthropicHistory.last['role'] == 'user') {
            final lastContent = _anthropicHistory.last['content'];
            if (lastContent is String) {
              _anthropicHistory.last['content'] = '$lastContent\n\n${msg.content.trim()}';
            } else if (lastContent is List) {
              lastContent.add({'type': 'text', 'text': msg.content.trim()});
            }
          } else {
            _anthropicHistory.add({
              'role': 'user',
              'content': msg.content.trim(),
            });
          }
        }
      } else if (msg.role == MessageRole.assistant) {
        final textContent = msg.content.trim();
        final toolCalls = msg.blocks.whereType<ToolCallBlock>().toList();

        if (toolCalls.isNotEmpty) {
          final toolCallsJson = <Map<String, dynamic>>[];
          for (final tc in toolCalls) {
            toolCallsJson.add({
              'id': tc.toolCall.toolCallId,
              'type': 'function',
              'function': {
                'name': tc.toolCall.toolName,
                'arguments': jsonEncode(tc.toolCall.arguments),
              },
            });
          }

          _openaiHistory.add({
            'role': 'assistant',
            'content': null,
            'tool_calls': toolCallsJson,
          });

          for (final tc in toolCalls) {
            final res = tc.toolCall.result?.toString() ??
                tc.toolCall.errorMessage ??
                (tc.toolCall.status == ToolCallStatus.rejected ? 'Operation rejected by user' : 'Completed');
            _openaiHistory.add({
              'role': 'tool',
              'tool_call_id': tc.toolCall.toolCallId,
              'content': res,
            });
          }

          if (textContent.isNotEmpty) {
            _openaiHistory.add({
              'role': 'assistant',
              'content': textContent,
            });
          }

          final anthropicToolUses = <Map<String, dynamic>>[];
          for (final tc in toolCalls) {
            anthropicToolUses.add({
              'type': 'tool_use',
              'id': tc.toolCall.toolCallId,
              'name': tc.toolCall.toolName,
              'input': tc.toolCall.arguments,
            });
          }
          _anthropicHistory.add({
            'role': 'assistant',
            'content': anthropicToolUses,
          });

          final toolResults = <Map<String, dynamic>>[];
          for (final tc in toolCalls) {
            final res = tc.toolCall.result?.toString() ??
                tc.toolCall.errorMessage ??
                'Completed';
            toolResults.add({
              'type': 'tool_result',
              'tool_use_id': tc.toolCall.toolCallId,
              'content': res,
            });
          }
          _anthropicHistory.add({
            'role': 'user',
            'content': toolResults,
          });

          if (textContent.isNotEmpty) {
            _anthropicHistory.add({
              'role': 'assistant',
              'content': textContent,
            });
          }
        } else if (textContent.isNotEmpty) {
          _openaiHistory.add({
            'role': 'assistant',
            'content': textContent,
          });
          if (_anthropicHistory.isNotEmpty && _anthropicHistory.last['role'] == 'assistant') {
            final lastContent = _anthropicHistory.last['content'];
            if (lastContent is String) {
              _anthropicHistory.last['content'] = '$lastContent\n\n$textContent';
            } else if (lastContent is List) {
              lastContent.add({'type': 'text', 'text': textContent});
            }
          } else {
            _anthropicHistory.add({
              'role': 'assistant',
              'content': textContent,
            });
          }
        }
      }
    }

    // Ensure Anthropic starts with user message if not empty
    while (_anthropicHistory.isNotEmpty && _anthropicHistory.first['role'] != 'user') {
      _anthropicHistory.removeAt(0);
    }
  }

  @override
  Future<void> startTask(String prompt, {List<ChatMessage>? priorMessages}) async {
    _isInterrupted = false;
    _setState(AgentState.thinking, 'Thinking...');

    if (priorMessages != null) {
      syncSessionHistory(priorMessages);
    }

    final providerId = _keyVault.getActiveProviderId();
    final providerConfig = _keyVault.getProvider(providerId);
    final activeModel = _keyVault.getActiveModel();

    if (providerId.isEmpty || providerConfig == null || activeModel.isEmpty) {
      _setState(AgentState.error, 'No AI provider or model configured.');
      _eventController.add(MessageEvent(
        text: '⚠️ **未配置可用模型**: 请前往「设置」->「模型与服务商」添加服务商并配置生效模型。',
        isComplete: true,
      ));
      _setState(AgentState.idle);
      return;
    }

    final apiKey = await _keyVault.getApiKeyForProvider(providerId);
    final providerDisplayName = providerConfig.name;

    if (apiKey == null || apiKey.isEmpty) {
      final authEx = AgentAuthException(
        'API Key missing for $providerDisplayName',
        providerName: providerDisplayName,
      );
      final lang = _keyVault.getLanguage();
      final msg = authEx.toLocalizedMessage(languageCode: lang);
      _setState(AgentState.error, msg);
      _eventController.add(MessageEvent(
        text: msg,
        isComplete: true,
      ));
      _setState(AgentState.idle);
      return;
    }

    try {
      final isAnthropic = (providerConfig.apiType == 'anthropic') ||
          (_keyVault.getActiveProvider() == LLMProvider.anthropic);
      if (isAnthropic) {
        await _runAnthropicLoop(prompt, apiKey, providerConfig.baseUrl);
      } else {
        final baseUrl = providerConfig.baseUrl.isNotEmpty
            ? providerConfig.baseUrl
            : (_keyVault.getActiveProvider() == LLMProvider.deepseek
                ? _keyVault.getDeepseekBaseUrl()
                : _keyVault.getCustomBaseUrl());
        await _runOpenAiCompatibleLoop(prompt, apiKey, baseUrl);
      }
    } catch (e, st) {
      final appEx = AppException.from(e, stackTrace: st, providerName: providerDisplayName);
      final lang = _keyVault.getLanguage();
      final errorMsg = appEx.toLocalizedMessage(languageCode: lang);
      _setState(AgentState.error, errorMsg);
      _eventController.add(MessageEvent(
        text: errorMsg,
        isComplete: true,
      ));
    } finally {
      _setState(AgentState.idle);
    }
  }

  // --- OpenAI Compatible Loop (OpenAI, DeepSeek, Gemini, Custom) ---
  Future<void> _runOpenAiCompatibleLoop(String prompt, String apiKey, String customBaseUrl) async {
    String baseUrl = customBaseUrl.trim();
    if (baseUrl.isEmpty) {
      baseUrl = 'https://api.openai.com/v1';
    }
    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }

    final model = _keyVault.getActiveModel();

    if (_openaiHistory.isEmpty) {
      _openaiHistory.add({
        'role': 'system',
        'content': _getSystemPrompt(),
      });
    }

    _openaiHistory.add({
      'role': 'user',
      'content': prompt,
    });

    int turnCount = 0;
    const maxTurns = 15;

    while (turnCount < maxTurns && !_isInterrupted) {
      turnCount++;
      _setState(AgentState.thinking, 'Analyzing codebase & planning next step...');

      final url = Uri.parse('$baseUrl/chat/completions');
      final thinkingIntensity = _keyVault.getThinkingIntensity();
      final requestBody = <String, dynamic>{
        'model': model,
        'messages': _openaiHistory,
        'tools': _getOpenAiTools(),
        'tool_choice': 'auto',
      };
      if (thinkingIntensity != ThinkingIntensity.off) {
        if (model.startsWith('o1') || model.startsWith('o3')) {
          String effort = 'medium';
          if (thinkingIntensity == ThinkingIntensity.low) effort = 'low';
          if (thinkingIntensity == ThinkingIntensity.high || thinkingIntensity == ThinkingIntensity.veryHigh) {
            effort = 'high';
          }
          requestBody['reasoning_effort'] = effort;
        }
      }

      requestBody['stream'] = true;

      final request = http.Request('POST', url);
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
        'Accept': 'text/event-stream',
      });
      request.body = jsonEncode(requestBody);

      final client = httpClient ?? http.Client();
      final http.StreamedResponse streamedResponse;
      try {
        streamedResponse = await client.send(request);
      } catch (e) {
        if (httpClient == null) client.close();
        rethrow;
      }

      if (streamedResponse.statusCode != 200) {
        final errBytes = await streamedResponse.stream.toBytes();
        final errBody = utf8.decode(errBytes);
        if (httpClient == null) client.close();
        final provider = _keyVault.getProvider(_keyVault.getActiveProviderId());
        throw AppException.fromHttpError(
          streamedResponse.statusCode,
          errBody,
          providerName: provider?.name,
          model: model,
        );
      }

      final accumulatedContent = StringBuffer();
      final accumulatedReasoning = StringBuffer();
      final accumulatedToolCalls = <int, Map<String, dynamic>>{};

      final linesStream = streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in linesStream) {
        if (_isInterrupted) break;
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith(':')) continue;
        if (trimmed == 'data: [DONE]') break;
        if (!trimmed.startsWith('data: ')) continue;

        final jsonStr = trimmed.substring(6).trim();
        if (jsonStr.isEmpty) continue;

        try {
          final data = jsonDecode(jsonStr) as Map<String, dynamic>;
          final choices = data['choices'] as List?;
          if (choices == null || choices.isEmpty) continue;
          final choice = choices[0] as Map<String, dynamic>;
          final delta = choice['delta'] as Map<String, dynamic>?;
          if (delta == null) continue;

          // 1. Thinking / Reasoning delta (e.g. DeepSeek R1)
          final reasoningChunk = delta['reasoning_content'] as String?;
          if (reasoningChunk != null && reasoningChunk.isNotEmpty) {
            accumulatedReasoning.write(reasoningChunk);
            _eventController.add(ThoughtEvent(thought: accumulatedReasoning.toString()));
          }

          // 2. Main content delta
          final textChunk = delta['content'] as String?;
          if (textChunk != null && textChunk.isNotEmpty) {
            accumulatedContent.write(textChunk);
            _eventController.add(MessageEvent(
              text: accumulatedContent.toString(),
              isComplete: false,
            ));
          }

          // 3. Tool call streaming delta
          final deltaTools = delta['tool_calls'] as List?;
          if (deltaTools != null) {
            for (final dt in deltaTools) {
              final idx = (dt['index'] as num?)?.toInt() ?? 0;
              final toolEntry = accumulatedToolCalls.putIfAbsent(idx, () => {
                'id': '',
                'type': 'function',
                'name': '',
                'arguments': StringBuffer(),
              });
              if (dt['id'] != null) {
                toolEntry['id'] = dt['id'];
              }
              final fn = dt['function'] as Map<String, dynamic>?;
              if (fn != null) {
                if (fn['name'] != null) {
                  toolEntry['name'] = (toolEntry['name'] as String) + (fn['name'] as String);
                }
                if (fn['arguments'] != null) {
                  (toolEntry['arguments'] as StringBuffer).write(fn['arguments']);
                }
              }
            }
          }
        } catch (_) {}
      }

      if (httpClient == null) {
        client.close();
      }

      final toolCallsList = <Map<String, dynamic>>[];
      if (accumulatedToolCalls.isNotEmpty) {
        final sortedKeys = accumulatedToolCalls.keys.toList()..sort();
        for (final k in sortedKeys) {
          final tc = accumulatedToolCalls[k]!;
          toolCallsList.add({
            'id': tc['id'],
            'type': 'function',
            'function': {
              'name': tc['name'],
              'arguments': (tc['arguments'] as StringBuffer).toString(),
            },
          });
        }
      }

      final assistantMessage = <String, dynamic>{
        'role': 'assistant',
        'content': accumulatedContent.isNotEmpty ? accumulatedContent.toString() : null,
      };
      if (toolCallsList.isNotEmpty) {
        assistantMessage['tool_calls'] = toolCallsList;
      }
      if (accumulatedReasoning.isNotEmpty) {
        assistantMessage['reasoning_content'] = accumulatedReasoning.toString();
      }

      if (accumulatedContent.isNotEmpty) {
        _eventController.add(MessageEvent(
          text: accumulatedContent.toString(),
          isComplete: toolCallsList.isEmpty,
        ));
      }

      _openaiHistory.add(assistantMessage);

      if (toolCallsList.isEmpty) {
        break;
      }

      // Process tool calls
      for (final tc in toolCallsList) {
        if (_isInterrupted) break;

        final callId = tc['id'] as String;
        final fn = tc['function'];
        final toolName = fn['name'] as String;
        final args = jsonDecode(fn['arguments'] as String) as Map<String, dynamic>;

        await _handleToolExecution(
          callId: callId,
          toolName: toolName,
          arguments: args,
          onResult: (resultStr) {
            _openaiHistory.add({
              'role': 'tool',
              'tool_call_id': callId,
              'content': resultStr,
            });
          },
        );
      }
    }
  }

  // --- Anthropic Loop (Claude) ---
  Future<void> _runAnthropicLoop(String prompt, String apiKey, [String? customBaseUrl]) async {
    final model = _keyVault.getActiveModel();
    String base = (customBaseUrl != null && customBaseUrl.trim().isNotEmpty)
        ? customBaseUrl.trim()
        : 'https://api.anthropic.com';
    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    final url = base.endsWith('/v1/messages') ? base : '$base/v1/messages';

    if (_anthropicHistory.isNotEmpty && _anthropicHistory.last['role'] == 'user') {
      final lastContent = _anthropicHistory.last['content'];
      if (lastContent is String) {
        _anthropicHistory.last['content'] = '$lastContent\n\n$prompt';
      } else if (lastContent is List) {
        final list = List<dynamic>.from(lastContent);
        list.add({
          'type': 'text',
          'text': prompt,
        });
        _anthropicHistory.last['content'] = list;
      } else {
        _anthropicHistory.add({
          'role': 'user',
          'content': prompt,
        });
      }
    } else {
      _anthropicHistory.add({
        'role': 'user',
        'content': prompt,
      });
    }

    int turnCount = 0;
    const maxTurns = 15;

    while (turnCount < maxTurns && !_isInterrupted) {
      turnCount++;
      _setState(AgentState.thinking, 'Claude is reasoning...');

      final thinkingIntensity = _keyVault.getThinkingIntensity();
      final requestBody = <String, dynamic>{
        'model': model,
        'system': _getSystemPrompt(),
        'messages': _anthropicHistory,
        'tools': _getAnthropicTools(),
      };

      if (thinkingIntensity != ThinkingIntensity.off && model.contains('3-7')) {
        int budgetTokens;
        switch (thinkingIntensity) {
          case ThinkingIntensity.low:
            budgetTokens = 1024;
            break;
          case ThinkingIntensity.medium:
            budgetTokens = 2048;
            break;
          case ThinkingIntensity.high:
            budgetTokens = 4096;
            break;
          case ThinkingIntensity.veryHigh:
            budgetTokens = 8192;
            break;
          case ThinkingIntensity.off:
            budgetTokens = 0;
            break;
        }
        requestBody['thinking'] = {
          'type': 'enabled',
          'budget_tokens': budgetTokens,
        };
        requestBody['max_tokens'] = budgetTokens + 4096;
      } else {
        requestBody['max_tokens'] = 4096;
      }

      requestBody['stream'] = true;

      final request = http.Request('POST', Uri.parse(url));
      request.headers.addAll({
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'Accept': 'text/event-stream',
      });
      request.body = jsonEncode(requestBody);

      final client = httpClient ?? http.Client();
      final http.StreamedResponse streamedResponse;
      try {
        streamedResponse = await client.send(request);
      } catch (e) {
        if (httpClient == null) client.close();
        rethrow;
      }

      if (streamedResponse.statusCode != 200) {
        final errBytes = await streamedResponse.stream.toBytes();
        final errBody = utf8.decode(errBytes);
        if (httpClient == null) client.close();
        final provider = _keyVault.getProvider(_keyVault.getActiveProviderId());
        throw AppException.fromHttpError(
          streamedResponse.statusCode,
          errBody,
          providerName: provider?.name ?? 'Anthropic',
          model: model,
        );
      }

      final contentBlocks = <int, Map<String, dynamic>>{};
      final accumulatedThought = StringBuffer();
      final accumulatedText = StringBuffer();

      final linesStream = streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in linesStream) {
        if (_isInterrupted) break;
        final trimmed = line.trim();
        if (!trimmed.startsWith('data: ')) continue;
        final jsonStr = trimmed.substring(6).trim();
        if (jsonStr.isEmpty) continue;

        try {
          final data = jsonDecode(jsonStr) as Map<String, dynamic>;
          final type = data['type'] as String?;

          if (type == 'content_block_start') {
            final idx = (data['index'] as num).toInt();
            final cb = data['content_block'] as Map<String, dynamic>;
            final blockType = cb['type'] as String;
            contentBlocks[idx] = {
              'type': blockType,
              if (blockType == 'tool_use') ...{
                'id': cb['id'],
                'name': cb['name'],
                'partial_json': StringBuffer(),
              },
            };
          } else if (type == 'content_block_delta') {
            final idx = (data['index'] as num).toInt();
            final delta = data['delta'] as Map<String, dynamic>;
            final deltaType = delta['type'] as String?;

            if (deltaType == 'thinking_delta') {
              final chunk = delta['thinking'] as String? ?? '';
              accumulatedThought.write(chunk);
              _eventController.add(ThoughtEvent(thought: accumulatedThought.toString()));
            } else if (deltaType == 'text_delta') {
              final chunk = delta['text'] as String? ?? '';
              accumulatedText.write(chunk);
              _eventController.add(MessageEvent(
                text: accumulatedText.toString(),
                isComplete: false,
              ));
            } else if (deltaType == 'input_json_delta') {
              final chunk = delta['partial_json'] as String? ?? '';
              if (contentBlocks[idx] != null && contentBlocks[idx]!['partial_json'] != null) {
                (contentBlocks[idx]!['partial_json'] as StringBuffer).write(chunk);
              }
            }
          }
        } catch (_) {}
      }

      if (httpClient == null) {
        client.close();
      }

      final toolUses = <Map<String, dynamic>>[];
      final finalContentList = <Map<String, dynamic>>[];

      if (accumulatedThought.isNotEmpty) {
        finalContentList.add({
          'type': 'thinking',
          'thinking': accumulatedThought.toString(),
        });
      }
      if (accumulatedText.isNotEmpty) {
        finalContentList.add({
          'type': 'text',
          'text': accumulatedText.toString(),
        });
      }

      final sortedIndices = contentBlocks.keys.toList()..sort();
      for (final idx in sortedIndices) {
        final b = contentBlocks[idx]!;
        if (b['type'] == 'tool_use') {
          Map<String, dynamic> parsedInput = {};
          try {
            parsedInput = jsonDecode((b['partial_json'] as StringBuffer).toString()) as Map<String, dynamic>;
          } catch (_) {}
          final tu = {
            'type': 'tool_use',
            'id': b['id'],
            'name': b['name'],
            'input': parsedInput,
          };
          toolUses.add(tu);
          finalContentList.add(tu);
        }
      }

      if (accumulatedText.isNotEmpty) {
        _eventController.add(MessageEvent(
          text: accumulatedText.toString(),
          isComplete: toolUses.isEmpty,
        ));
      }

      _anthropicHistory.add({
        'role': 'assistant',
        'content': finalContentList,
      });

      if (toolUses.isEmpty) {
        break;
      }

      // Execute tool uses
      final toolResults = <Map<String, dynamic>>[];
      for (final tu in toolUses) {
        if (_isInterrupted) break;

        final callId = tu['id'] as String;
        final toolName = tu['name'] as String;
        final args = tu['input'] as Map<String, dynamic>;

        await _handleToolExecution(
          callId: callId,
          toolName: toolName,
          arguments: args,
          onResult: (resultStr) {
            toolResults.add({
              'type': 'tool_result',
              'tool_use_id': callId,
              'content': resultStr,
            });
          },
        );
      }

      _anthropicHistory.add({
        'role': 'user',
        'content': toolResults,
      });
    }
  }

  // --- Common Tool Execution & Approval Logic ---
  @visibleForTesting
  Future<void> handleToolExecutionForTesting({
    required String callId,
    required String toolName,
    required Map<String, dynamic> arguments,
    required Function(String) onResult,
  }) {
    return _handleToolExecution(
      callId: callId,
      toolName: toolName,
      arguments: arguments,
      onResult: onResult,
    );
  }

  Future<void> _handleToolExecution({
    required String callId,
    required String toolName,
    required Map<String, dynamic> arguments,
    required Function(String) onResult,
  }) async {
    final isReadOnly = toolName == 'read_file' ||
        toolName == 'list_directory' ||
        toolName == 'search_files';

    final approvalMode = _keyVault.getApprovalMode();
    final bool autoApprove;
    switch (approvalMode) {
      case ApprovalMode.alwaysAsk:
        autoApprove = false;
        break;
      case ApprovalMode.autoApprove:
        autoApprove = isReadOnly;
        break;
      case ApprovalMode.yolo:
        autoApprove = true;
        break;
    }

    // Check if we need to show a Diff before approval
    if (toolName == 'write_file' || toolName == 'patch_file') {
      try {
        final path = arguments['path'] as String;
        String orig = '';
        try {
          orig = await _workspace.readFile(path);
        } catch (_) {}

        String newContent = '';
        if (toolName == 'write_file') {
          newContent = arguments['content'] as String;
        } else {
          final oldBlock = arguments['old_content'] as String;
          final newBlock = arguments['new_content'] as String;
          newContent = orig.replaceFirst(oldBlock, newBlock);
        }

        final diffEvent = _workspace.computeDiff(path, orig, newContent);
        _eventController.add(diffEvent);
      } catch (_) {}
    }

    if (!autoApprove) {
      _setState(AgentState.waitingApproval, 'Waiting for approval: $toolName');

      final completer = Completer<bool>();
      _pendingApprovals[callId] = completer;

      _eventController.add(ToolCallEvent(
        toolCallId: callId,
        toolName: toolName,
        arguments: arguments,
        status: ToolCallStatus.pending,
        autoApproved: false,
      ));

      final approved = await completer.future;
      _pendingApprovals.remove(callId);

      if (!approved) {
        _eventController.add(ToolCallEvent(
          toolCallId: callId,
          toolName: toolName,
          arguments: arguments,
          status: ToolCallStatus.rejected,
          errorMessage: 'User rejected this operation.',
        ));
        onResult(jsonEncode({'status': 'rejected', 'error': 'User rejected this operation.'}));
        return;
      }
    } else {
      _eventController.add(ToolCallEvent(
        toolCallId: callId,
        toolName: toolName,
        arguments: arguments,
        status: ToolCallStatus.executing,
        autoApproved: true,
      ));
    }

    _setState(AgentState.executingTool, 'Executing $toolName...');

    try {
      final res = await _executeTool(toolName, arguments);
      _eventController.add(ToolCallEvent(
        toolCallId: callId,
        toolName: toolName,
        arguments: arguments,
        status: ToolCallStatus.completed,
        result: res,
      ));
      onResult(jsonEncode({'status': 'success', 'output': res}));
    } catch (e) {
      _eventController.add(ToolCallEvent(
        toolCallId: callId,
        toolName: toolName,
        arguments: arguments,
        status: ToolCallStatus.failed,
        errorMessage: e.toString(),
      ));
      onResult(jsonEncode({'status': 'error', 'error': e.toString()}));
    }
  }

  Future<dynamic> _executeTool(String toolName, Map<String, dynamic> args) async {
    switch (toolName) {
      case 'read_file':
        return await _workspace.readFile(args['path'] as String);
      case 'write_file':
        await _workspace.writeFile(args['path'] as String, args['content'] as String);
        return 'File written successfully: ${args['path']}';
      case 'patch_file':
        await _workspace.patchFile(
          args['path'] as String,
          args['old_content'] as String,
          args['new_content'] as String,
        );
        return 'File patched successfully: ${args['path']}';
      case 'list_directory':
        final list = await _workspace.listFiles(relativePath: (args['path'] as String?) ?? '');
        return list.map((e) => e.path.split(Platform.pathSeparator).last).toList();
      case 'search_files':
        final list = await _workspace.listFiles();
        final query = (args['query'] as String).toLowerCase();
        final matches = <String>[];
        for (final item in list) {
          if (item is File) {
            try {
              final text = await item.readAsString();
              if (text.toLowerCase().contains(query)) {
                matches.add(item.path.split(Platform.pathSeparator).last);
              }
            } catch (_) {}
          }
        }
        return matches;
      case 'run_command':
        // Execute in PRoot Linux sandbox if installed, otherwise local process with timeout
        final cmd = args['command'] as String;
        final timeoutSec = args['timeout'] is num
            ? (args['timeout'] as num).toInt()
            : (args['timeout_ms'] is num ? ((args['timeout_ms'] as num) / 1000).ceil() : 60);
        final timeoutDuration = args['timeout_ms'] is num
            ? Duration(milliseconds: (args['timeout_ms'] as num).toInt())
            : Duration(seconds: timeoutSec);
        final pm = prootManager;

        if (pm != null && await pm.isInstalled()) {
          final env = await _keyVault.exportEnvironmentVariables();
          final prootProc = await pm.startProcess(
            cmd,
            workingDir: '/workspace',
            environment: env,
          );
          _activePRootProcess = prootProc;

          final stdoutBuf = StringBuffer();
          final stderrBuf = StringBuffer();
          final stdoutSub = prootProc.stdout.listen((s) => stdoutBuf.write(s));
          final stderrSub = prootProc.stderr.listen((s) => stderrBuf.write(s));

          try {
            final exitCode = await prootProc.exitCode.timeout(
              timeoutDuration,
              onTimeout: () {
                try {
                  prootProc.kill();
                } catch (_) {}
                throw TimeoutException('Command timed out after $timeoutSec seconds');
              },
            );
            await stdoutSub.cancel();
            await stderrSub.cancel();
            return {
              'exitCode': exitCode,
              'stdout': stdoutBuf.toString(),
              'stderr': stderrBuf.toString(),
              'sandbox': 'proot-debian',
            };
          } finally {
            _activePRootProcess = null;
          }
        } else {
          final executable = Platform.isWindows ? 'cmd' : 'sh';
          final execArgs = Platform.isWindows ? ['/c', cmd] : ['-c', cmd];
          final proc = await Process.start(
            executable,
            execArgs,
            workingDirectory: _workspace.workspacePath,
          );
          _activeProcess = proc;

          final stdoutBuf = StringBuffer();
          final stderrBuf = StringBuffer();
          const decoder = Utf8Decoder(allowMalformed: true);
          final stdoutSub = proc.stdout.transform(decoder).listen((s) => stdoutBuf.write(s));
          final stderrSub = proc.stderr.transform(decoder).listen((s) => stderrBuf.write(s));

          try {
            final exitCode = await proc.exitCode.timeout(
              timeoutDuration,
              onTimeout: () {
                try {
                  proc.kill();
                } catch (_) {}
                throw TimeoutException('Command timed out after $timeoutSec seconds');
              },
            );
            await stdoutSub.cancel();
            await stderrSub.cancel();
            return {
              'exitCode': exitCode,
              'stdout': stdoutBuf.toString(),
              'stderr': stderrBuf.toString(),
              'sandbox': 'host',
            };
          } finally {
            _activeProcess = null;
          }
        }
      default:
        throw UnimplementedError('Unknown tool: $toolName');
    }
  }

  @override
  Future<void> respondApproval(String toolCallId, bool approved, {String? reason}) async {
    final completer = _pendingApprovals[toolCallId];
    if (completer != null && !completer.isCompleted) {
      completer.complete(approved);
    }
  }

  @override
  Future<void> interrupt() async {
    _isInterrupted = true;
    for (final completer in _pendingApprovals.values) {
      if (!completer.isCompleted) completer.complete(false);
    }
    _pendingApprovals.clear();

    if (_activePRootProcess != null) {
      try {
        _activePRootProcess!.kill(ProcessSignal.sigint);
      } catch (_) {
        _activePRootProcess!.kill(ProcessSignal.sigkill);
      }
      _activePRootProcess = null;
    }

    if (_activeProcess != null) {
      try {
        _activeProcess!.kill(ProcessSignal.sigint);
      } catch (_) {
        _activeProcess!.kill(ProcessSignal.sigkill);
      }
      _activeProcess = null;
    }

    _setState(AgentState.idle, 'Task interrupted.');
  }

  @override
  void resetSession() {
    _openaiHistory.clear();
    _anthropicHistory.clear();
    _isInterrupted = false;
    for (final completer in _pendingApprovals.values) {
      if (!completer.isCompleted) completer.complete(false);
    }
    _pendingApprovals.clear();

    if (_activePRootProcess != null) {
      try {
        _activePRootProcess!.kill(ProcessSignal.sigint);
      } catch (_) {
        _activePRootProcess!.kill(ProcessSignal.sigkill);
      }
      _activePRootProcess = null;
    }

    if (_activeProcess != null) {
      try {
        _activeProcess!.kill(ProcessSignal.sigint);
      } catch (_) {
        _activeProcess!.kill(ProcessSignal.sigkill);
      }
      _activeProcess = null;
    }

    _setState(AgentState.idle);
  }

  @override
  Future<void> dispose() async {
    await interrupt();
    await _eventController.close();
  }

  String _getSystemPrompt() {
    return '''You are AgentsDroid, an expert AI programming assistant running natively on Android.
You help the user develop, debug, and manage code projects.

Your workspace path is: ${_workspace.workspacePath}
You have access to tools to read, write, patch, list files, and run commands.
Always think step-by-step:
1. First inspect relevant files using read_file or list_directory.
2. Formulate a plan before editing code.
3. Make minimal, surgical edits using patch_file or write_file.
4. Explain clearly what you did in concise markdown format.
''';
  }

  List<Map<String, dynamic>> _getOpenAiTools() {
    return [
      {
        'type': 'function',
        'function': {
          'name': 'read_file',
          'description': 'Read the contents of a file in the workspace.',
          'parameters': {
            'type': 'object',
            'properties': {
              'path': {'type': 'string', 'description': 'Relative file path from workspace root'}
            },
            'required': ['path'],
          }
        }
      },
      {
        'type': 'function',
        'function': {
          'name': 'write_file',
          'description': 'Create or overwrite a file with full content.',
          'parameters': {
            'type': 'object',
            'properties': {
              'path': {'type': 'string', 'description': 'Relative file path'},
              'content': {'type': 'string', 'description': 'Full file content'}
            },
            'required': ['path', 'content'],
          }
        }
      },
      {
        'type': 'function',
        'function': {
          'name': 'patch_file',
          'description': 'Replace a specific block of text in an existing file.',
          'parameters': {
            'type': 'object',
            'properties': {
              'path': {'type': 'string', 'description': 'Relative file path'},
              'old_content': {'type': 'string', 'description': 'Exact existing text block to replace'},
              'new_content': {'type': 'string', 'description': 'New replacement text'}
            },
            'required': ['path', 'old_content', 'new_content'],
          }
        }
      },
      {
        'type': 'function',
        'function': {
          'name': 'list_directory',
          'description': 'List files and directories in the workspace.',
          'parameters': {
            'type': 'object',
            'properties': {
              'path': {'type': 'string', 'description': 'Relative directory path (empty for root)'}
            }
          }
        }
      },
      {
        'type': 'function',
        'function': {
          'name': 'search_files',
          'description': 'Search for a string across workspace text files.',
          'parameters': {
            'type': 'object',
            'properties': {
              'query': {'type': 'string', 'description': 'Substring to search for'}
            },
            'required': ['query'],
          }
        }
      },
      {
        'type': 'function',
        'function': {
          'name': 'run_command',
          'description': 'Execute a shell command in the project directory.',
          'parameters': {
            'type': 'object',
            'properties': {
              'command': {'type': 'string', 'description': 'Command string to run'}
            },
            'required': ['command'],
          }
        }
      },
    ];
  }

  List<Map<String, dynamic>> _getAnthropicTools() {
    return [
      {
        'name': 'read_file',
        'description': 'Read the contents of a file in the workspace.',
        'input_schema': {
          'type': 'object',
          'properties': {
            'path': {'type': 'string', 'description': 'Relative file path'}
          },
          'required': ['path']
        }
      },
      {
        'name': 'write_file',
        'description': 'Create or overwrite a file with full content.',
        'input_schema': {
          'type': 'object',
          'properties': {
            'path': {'type': 'string', 'description': 'Relative file path'},
            'content': {'type': 'string', 'description': 'Full file content'}
          },
          'required': ['path', 'content']
        }
      },
      {
        'name': 'patch_file',
        'description': 'Replace a specific block of text in an existing file.',
        'input_schema': {
          'type': 'object',
          'properties': {
            'path': {'type': 'string', 'description': 'Relative file path'},
            'old_content': {'type': 'string', 'description': 'Exact existing text block to replace'},
            'new_content': {'type': 'string', 'description': 'New replacement text'}
          },
          'required': ['path', 'old_content', 'new_content']
        }
      },
      {
        'name': 'list_directory',
        'description': 'List files and directories in the workspace.',
        'input_schema': {
          'type': 'object',
          'properties': {
            'path': {'type': 'string', 'description': 'Relative directory path (empty for root)'}
          }
        }
      },
      {
        'name': 'search_files',
        'description': 'Search for a string across workspace text files.',
        'input_schema': {
          'type': 'object',
          'properties': {
            'query': {'type': 'string', 'description': 'Substring to search for'}
          },
          'required': ['query']
        }
      },
      {
        'name': 'run_command',
        'description': 'Execute a shell command in the project directory.',
        'input_schema': {
          'type': 'object',
          'properties': {
            'command': {'type': 'string', 'description': 'Command string to run'}
          },
          'required': ['command']
        }
      },
    ];
  }
}

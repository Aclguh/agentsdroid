import 'dart:convert';
import 'dart:io';

/// Base application domain exception
abstract class AppException implements Exception {
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  const AppException(this.message, {this.cause, this.stackTrace});

  /// Produces a human-readable localized message in Chinese or English
  String toLocalizedMessage({String languageCode = 'zh'});

  @override
  String toString() => '$runtimeType: $message${cause != null ? ' (Cause: $cause)' : ''}';

  /// Converts any unexpected exception or error into a typed AppException
  factory AppException.from(
    Object error, {
    StackTrace? stackTrace,
    String? providerName,
  }) {
    if (error is AppException) return error;

    if (error is SocketException ||
        error is HttpException ||
        error.toString().contains('Failed host lookup') ||
        error.toString().contains('Connection refused') ||
        error.toString().contains('Connection reset')) {
      return AgentNetworkException(
        'Network error: $error',
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (error.toString().contains('TimeoutException') ||
        error.toString().toLowerCase().contains('timeout')) {
      return AgentNetworkException(
        'Request timed out: $error',
        cause: error,
        stackTrace: stackTrace,
      );
    }

    return AgentEngineException(
      error.toString(),
      cause: error,
      stackTrace: stackTrace,
    );
  }

  /// Parses HTTP errors from LLM providers (Anthropic, OpenAI, DeepSeek, etc.)
  factory AppException.fromHttpError(
    int statusCode,
    String responseBody, {
    String? providerName,
    String? model,
  }) {
    String parsedDetail = '';
    try {
      final json = jsonDecode(responseBody);
      if (json is Map<String, dynamic>) {
        if (json['error'] is Map) {
          parsedDetail = (json['error']['message'] ?? '').toString();
        } else if (json['error'] is String) {
          parsedDetail = json['error'] as String;
        } else if (json['message'] != null) {
          parsedDetail = json['message'].toString();
        }
      }
    } catch (_) {
      parsedDetail = responseBody;
    }

    if (statusCode == 401 || statusCode == 403) {
      return AgentAuthException(
        parsedDetail.isNotEmpty ? parsedDetail : 'Authentication failed with status $statusCode',
        providerName: providerName ?? 'AI Provider',
      );
    }

    if (statusCode == 429) {
      if (parsedDetail.toLowerCase().contains('quota') ||
          parsedDetail.toLowerCase().contains('insufficient') ||
          parsedDetail.toLowerCase().contains('balance') ||
          parsedDetail.toLowerCase().contains('credit')) {
        return AgentQuotaExceededException(
          parsedDetail,
          providerName: providerName,
        );
      }
      return AgentRateLimitException(
        parsedDetail.isNotEmpty ? parsedDetail : 'Rate limit exceeded (HTTP 429)',
      );
    }

    if (statusCode == 404) {
      return AgentModelNotFoundException(
        parsedDetail.isNotEmpty ? parsedDetail : 'Model or endpoint not found (HTTP 404)',
        model: model,
      );
    }

    return AgentEngineException(
      'HTTP $statusCode: ${parsedDetail.isNotEmpty ? parsedDetail : responseBody}',
      statusCode: statusCode,
    );
  }
}

/// Authentication and API Key errors
class AgentAuthException extends AppException {
  final String providerName;

  const AgentAuthException(
    super.message, {
    required this.providerName,
    super.cause,
    super.stackTrace,
  });

  @override
  String toLocalizedMessage({String languageCode = 'zh'}) {
    if (languageCode == 'zh') {
      return '未配置 API 密钥或认证失败：请在右上角「设置」中配置 $providerName 的有效 API Key。';
    }
    return 'API Key missing or invalid: Please configure a valid API Key for $providerName in Settings.';
  }
}

/// Request rate limit (429) errors
class AgentRateLimitException extends AppException {
  const AgentRateLimitException(
    super.message, {
    super.cause,
    super.stackTrace,
  });

  @override
  String toLocalizedMessage({String languageCode = 'zh'}) {
    if (languageCode == 'zh') {
      return '模型请求频率超限 (429)：服务当前受限，请稍后再试或检查并发限额。';
    }
    return 'Rate limit exceeded (429): AI model is currently throttled, please try again shortly.';
  }
}

/// Account quota or balance exhausted errors
class AgentQuotaExceededException extends AppException {
  final String? providerName;

  const AgentQuotaExceededException(
    super.message, {
    this.providerName,
    super.cause,
    super.stackTrace,
  });

  @override
  String toLocalizedMessage({String languageCode = 'zh'}) {
    final prefix = providerName != null ? '$providerName: ' : '';
    if (languageCode == 'zh') {
      return '$prefix' '账户额度不足或已耗尽：请前往服务商控制台充值或检查账单配额。';
    }
    return '$prefix' 'Account quota exhausted: Please top up your account or check billing settings.';
  }
}

/// Model not found or unavailable errors
class AgentModelNotFoundException extends AppException {
  final String? model;

  const AgentModelNotFoundException(
    super.message, {
    this.model,
    super.cause,
    super.stackTrace,
  });

  @override
  String toLocalizedMessage({String languageCode = 'zh'}) {
    final name = model != null ? ' ($model)' : '';
    if (languageCode == 'zh') {
      return '指定模型未找到$name：请在设置中检查当前所选模型名称是否正确。';
    }
    return 'Model not found$name: Please check if the selected model is valid in Settings.';
  }
}

/// Network connectivity, socket and timeout errors
class AgentNetworkException extends AppException {
  const AgentNetworkException(
    super.message, {
    super.cause,
    super.stackTrace,
  });

  @override
  String toLocalizedMessage({String languageCode = 'zh'}) {
    if (languageCode == 'zh') {
      return '网络连接失败：无法访问 AI 服务服务器，请检查设备网络或代理配置。';
    }
    return 'Network connection failed: Unable to connect to AI server. Please check your network or proxy.';
  }
}

/// General agent engine inference failure
class AgentEngineException extends AppException {
  final int? statusCode;

  const AgentEngineException(
    super.message, {
    this.statusCode,
    super.cause,
    super.stackTrace,
  });

  @override
  String toLocalizedMessage({String languageCode = 'zh'}) {
    if (languageCode == 'zh') {
      return 'AI 执行发生异常: $message';
    }
    return 'AI execution error: $message';
  }
}

/// PRoot subsystem not installed
class SubsystemNotInstalledException extends AppException {
  const SubsystemNotInstalledException([
    super.message = 'Linux subsystem is not installed.',
  ]);

  @override
  String toLocalizedMessage({String languageCode = 'zh'}) {
    if (languageCode == 'zh') {
      return 'Linux 子系统尚未安装：请前往「设置 -> 嵌入式 Linux 子系统」完成安装。';
    }
    return 'Linux subsystem is not installed: Please navigate to Settings to install Debian PRoot.';
  }
}

/// Subsystem process execution failure
class SubsystemExecutionException extends AppException {
  final int exitCode;
  final String? stderr;

  const SubsystemExecutionException(
    super.message, {
    required this.exitCode,
    this.stderr,
    super.cause,
    super.stackTrace,
  });

  @override
  String toLocalizedMessage({String languageCode = 'zh'}) {
    final err = stderr != null && stderr!.isNotEmpty ? ' ($stderr)' : '';
    if (languageCode == 'zh') {
      return '子系统指令执行失败 (退出码 $exitCode)$err';
    }
    return 'Subsystem command failed (exit code $exitCode)$err';
  }
}

/// Path traversal or security perimeter violation
class WorkspaceSecurityException extends AppException {
  final String path;

  const WorkspaceSecurityException(
    super.message, {
    required this.path,
    super.cause,
    super.stackTrace,
  });

  @override
  String toLocalizedMessage({String languageCode = 'zh'}) {
    if (languageCode == 'zh') {
      return '工作区安全拦截：禁止越界访问工作区外部路径 ($path)。';
    }
    return 'Workspace security violation: Access to path outside workspace boundary is blocked ($path).';
  }
}

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:agentsdroid/core/errors/app_exceptions.dart';

void main() {
  group('AppException Domain Model and Localization Tests (CODE-02)', () {
    test('parses 401/403 into AgentAuthException', () {
      final ex = AppException.fromHttpError(
        401,
        '{"error": {"message": "Invalid API key provided."}}',
        providerName: 'DeepSeek',
      );

      expect(ex, isA<AgentAuthException>());
      final authEx = ex as AgentAuthException;
      expect(authEx.providerName, 'DeepSeek');
      expect(authEx.toLocalizedMessage(languageCode: 'zh'), contains('未配置 API 密钥或认证失败'));
      expect(authEx.toLocalizedMessage(languageCode: 'zh'), contains('DeepSeek'));
      expect(authEx.toLocalizedMessage(languageCode: 'en'), contains('API Key missing or invalid'));
    });

    test('parses 429 rate limit into AgentRateLimitException', () {
      final ex = AppException.fromHttpError(
        429,
        '{"error": {"message": "Rate limit reached for requests."}}',
      );

      expect(ex, isA<AgentRateLimitException>());
      expect(ex.toLocalizedMessage(languageCode: 'zh'), contains('模型请求频率超限 (429)'));
      expect(ex.toLocalizedMessage(languageCode: 'en'), contains('Rate limit exceeded (429)'));
    });

    test('parses 429 quota exhaustion into AgentQuotaExceededException', () {
      final ex = AppException.fromHttpError(
        429,
        '{"error": {"message": "You exceeded your current quota, please check your plan and billing details."}}',
        providerName: 'OpenAI',
      );

      expect(ex, isA<AgentQuotaExceededException>());
      expect(ex.toLocalizedMessage(languageCode: 'zh'), contains('账户额度不足或已耗尽'));
      expect(ex.toLocalizedMessage(languageCode: 'zh'), contains('OpenAI'));
      expect(ex.toLocalizedMessage(languageCode: 'en'), contains('Account quota exhausted'));
    });

    test('parses 404 into AgentModelNotFoundException', () {
      final ex = AppException.fromHttpError(
        404,
        '{"error": {"message": "The model claude-fake does not exist."}}',
        model: 'claude-fake',
      );

      expect(ex, isA<AgentModelNotFoundException>());
      final modelEx = ex as AgentModelNotFoundException;
      expect(modelEx.model, 'claude-fake');
      expect(modelEx.toLocalizedMessage(languageCode: 'zh'), contains('指定模型未找到 (claude-fake)'));
      expect(modelEx.toLocalizedMessage(languageCode: 'en'), contains('Model not found (claude-fake)'));
    });

    test('parses SocketException into AgentNetworkException', () {
      final ex = AppException.from(
        const SocketException('Failed host lookup: api.openai.com'),
      );

      expect(ex, isA<AgentNetworkException>());
      expect(ex.toLocalizedMessage(languageCode: 'zh'), contains('网络连接失败'));
      expect(ex.toLocalizedMessage(languageCode: 'en'), contains('Network connection failed'));
    });

    test('SubsystemNotInstalledException returns friendly localized guidance', () {
      const ex = SubsystemNotInstalledException();
      expect(ex.toLocalizedMessage(languageCode: 'zh'), contains('Linux 子系统尚未安装'));
      expect(ex.toLocalizedMessage(languageCode: 'en'), contains('Linux subsystem is not installed'));
    });

    test('SubsystemExecutionException returns exit code and stderr', () {
      const ex = SubsystemExecutionException('Command failed', exitCode: 127, stderr: 'command not found');
      expect(ex.toLocalizedMessage(languageCode: 'zh'), contains('退出码 127'));
      expect(ex.toLocalizedMessage(languageCode: 'zh'), contains('command not found'));
      expect(ex.toLocalizedMessage(languageCode: 'en'), contains('exit code 127'));
    });

    test('WorkspaceSecurityException returns perimeter defense alert', () {
      const ex = WorkspaceSecurityException('Path traversal attempt', path: '../../etc/passwd');
      expect(ex.toLocalizedMessage(languageCode: 'zh'), contains('工作区安全拦截'));
      expect(ex.toLocalizedMessage(languageCode: 'zh'), contains('../../etc/passwd'));
      expect(ex.toLocalizedMessage(languageCode: 'en'), contains('Workspace security violation'));
    });
  });
}

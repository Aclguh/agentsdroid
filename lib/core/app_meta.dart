/// 应用版本与仓库元数据。
class AppMeta {
  AppMeta._();

  /// 应用显示名称
  static const String appName = 'AgentsDroid';

  /// 语义化版本号 (与 pubspec.yaml version 保持一致)
  static const String version = '1.0.0';

  /// 构建号 (与 pubspec.yaml version 保持一致)
  static const String buildNumber = '1';

  /// Android 应用包名
  static const String packageName = 'com.agentsdroid.agentsdroid';

  /// GitHub 官方开源仓库地址
  static const String repoUrl = 'https://github.com/Aclguh/agentsdroid';

  /// 开源协议名称
  static const String license = 'MIT License';

  /// 应用图标本地资源路径
  static const String iconAsset = 'assets/branding/agentsdroid-icon.png';
}

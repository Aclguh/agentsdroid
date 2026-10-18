// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'AgentsDroid';

  @override
  String get thinking => '思考中...';

  @override
  String get reasoningProcess => '推理过程';

  @override
  String get agentWorking => 'Agent 正在执行任务...';

  @override
  String get stop => '停止';

  @override
  String get welcomeTitle => '欢迎使用 AgentsDroid';

  @override
  String get welcomeSubtitle => '你的移动端 AI 编程工作台。\n在手机上即可审查代码、编辑项目与执行命令。';

  @override
  String get promptSummary => '阅读 README.md 并解释项目';

  @override
  String get promptSummaryQuery => '请阅读 README.md 并为我总结这个项目。';

  @override
  String get promptFibonacci => '在 main.py 中添加斐波那契函数';

  @override
  String get promptFibonacciQuery => '请检查 main.py 并添加一个递归斐波那契函数与测试输出。';

  @override
  String get promptListFiles => '列出所有项目文件';

  @override
  String get promptListFilesQuery => '请列出当前工作区的所有文件并展示目录结构。';

  @override
  String get inputHintWorking => 'Agent 正在执行中...';

  @override
  String get inputHintIdle => '输入指令让 Agent 审查代码、修改或运行...';

  @override
  String get workspaceFiles => '工作区文件';

  @override
  String get settings => '设置';

  @override
  String get settingsTitle => '设置与模型服务';

  @override
  String get modelConfigSection => '模型与 API 配置';

  @override
  String get activeProvider => '当前 AI 服务商';

  @override
  String get modelName => '模型名称';

  @override
  String get apiKey => 'API 密钥';

  @override
  String get apiBaseUrl => 'API 基础地址 (Base URL)';

  @override
  String get safetySection => '执行安全策略';

  @override
  String get yoloMode => '完全自主模式 (YOLO Mode)';

  @override
  String get yoloModeDesc => '自动放行所有文件修改与命令执行，不再弹出确认审批卡片。';

  @override
  String get subsystemSection => '嵌入式 Linux 子系统 (PRoot)';

  @override
  String get subsystemDesc =>
      '基于 PRoot 在 App 私有沙箱内运行 Debian-arm64。零 Root 权限，直接兼容官方 @anthropic-ai/claude-code 与 aider。';

  @override
  String get subsystemReady => '已安装并就绪';

  @override
  String get subsystemNotInstalled => '未安装';

  @override
  String get installSubsystem => '下载并安装子系统';

  @override
  String get saveSettings => '保存设置';

  @override
  String get settingsSaved => '设置已成功保存！';

  @override
  String get language => '界面语言';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get reviewDiff => '审查变更';

  @override
  String get approve => '允许';

  @override
  String get reject => '拒绝';

  @override
  String get needsApproval => '待审批';

  @override
  String get approved => '已允许';

  @override
  String get executing => '执行中...';

  @override
  String get autoExecuted => '自动执行';

  @override
  String get completed => '已完成';

  @override
  String get rejected => '已拒绝';

  @override
  String get failed => '失败';

  @override
  String get diffGenerated => '代码变更已生成';

  @override
  String get noFilesInWorkspace => '工作区暂无文件';

  @override
  String get refresh => '刷新';

  @override
  String get close => '关闭';

  @override
  String get subsystemTerminal => '子系统终端';

  @override
  String get terminalTitle => 'Linux 子系统控制台';

  @override
  String get toolchainStatus => '开发工具链状态';

  @override
  String get runCommand => '运行指令';

  @override
  String get quickCommands => '常用指令';

  @override
  String get commandHint => '输入 Linux 命令 (如 node -v, git status)...';

  @override
  String get notInstalledWarning => 'Linux 子系统尚未安装，请前往「设置」进行安装';

  @override
  String get clearLog => '清屏';
}

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

  @override
  String get agentEngine => 'Agent 引擎';

  @override
  String get engineBuiltin => '内置轻量 Agent';

  @override
  String get engineBuiltinShort => '内置 Agent';

  @override
  String get engineClaudeCode => '官方 Claude Code CLI';

  @override
  String get engineClaudeCodeShort => 'Claude CLI';

  @override
  String get engineSwitchTitle => '选择 Agent 执行引擎';

  @override
  String get engineBuiltinDesc => '轻量极速，直接调用大模型 API，无需额外安装 npm 依赖。';

  @override
  String get engineClaudeCodeDesc =>
      'Anthropic 官方 Claude Code CLI，运行于嵌入式 Linux PRoot 沙箱内。';

  @override
  String get engineNotReady => '引擎环境尚未就绪';

  @override
  String get goToSubsystemTerminal => '前往子系统终端';

  @override
  String get goToSettings => '前往设置';

  @override
  String get cancel => '取消';

  @override
  String get exportZip => '导出 Zip 压缩包';

  @override
  String get exportingZip => '正在压缩并导出工作区...';

  @override
  String get zipExported => '工作区已成功导出为 Zip 压缩包！';

  @override
  String get cloneGit => '克隆 Git 仓库';

  @override
  String get cloneGitHint => '输入 Git 仓库 URL (如 https://github.com/...)';

  @override
  String get cloning => '正在克隆代码仓库...';

  @override
  String get cloneSuccess => 'Git 仓库克隆成功！';

  @override
  String get cloneFailed => 'Git 仓库克隆失败';

  @override
  String get newFile => '新建文件';

  @override
  String get newFolder => '新建文件夹';

  @override
  String get fileNameHint => '输入文件名 (如 utils.py)';

  @override
  String get folderNameHint => '输入文件夹名';

  @override
  String get deleteConfirm => '确认删除';

  @override
  String get deleteConfirmMsg => '确认要删除该项吗？此操作无法撤销。';

  @override
  String get delete => '删除';

  @override
  String get copyContent => '复制修改后内容';

  @override
  String get copiedToClipboard => '已复制到剪贴板';

  @override
  String get chatHistory => '历史会话';

  @override
  String get newChat => '新建会话';

  @override
  String get noHistorySessions => '暂无历史会话';

  @override
  String get deleteSession => '删除会话';

  @override
  String get deleteSessionConfirm => '确定要删除此会话记录吗？';

  @override
  String get renameSession => '重命名会话';

  @override
  String get sessionTitleHint => '输入会话标题';

  @override
  String get save => '保存';

  @override
  String get sessionUntitled => '新会话';

  @override
  String get projects => '项目';

  @override
  String get conversations => '会话';

  @override
  String get newProject => '新建项目';

  @override
  String get projectNameHint => '输入项目名称 (如 my_app)';

  @override
  String get create => '创建';

  @override
  String get archive => '归档';

  @override
  String get unarchive => '恢复';

  @override
  String get archivedSessions => '已归档会话';

  @override
  String get showArchived => '查看归档';

  @override
  String get hideArchived => '返回活跃会话';

  @override
  String get noArchivedSessions => '暂无归档会话';

  @override
  String get newProjectSession => '新建项目会话';

  @override
  String get newStandaloneSession => '新建独立会话';

  @override
  String get archiveSessionConfirm => '确定要归档此会话吗？';

  @override
  String get unarchiveSessionConfirm => '确定要恢复此会话吗？';

  @override
  String get newConversation => '新建对话';

  @override
  String get conversationHistory => '会话历史';

  @override
  String get displayOptions => '显示设置';

  @override
  String get sortConversations => '会话排序';

  @override
  String get sortProjects => '项目排序';

  @override
  String get sortRecent => '最近更新';

  @override
  String get sortName => '按名称 (A-Z)';

  @override
  String get archivedOnly => '仅显示归档';

  @override
  String get searchConversations => '搜索会话...';

  @override
  String get allConversations => '全部会话';

  @override
  String get noMatchingConversations => '未找到匹配会话';

  @override
  String get approvalTitle => '应如何批准 Agent 操作？';

  @override
  String get approvalSubtitle => '此设置适用于此会话中的命令执行和文件修改。您可以随时进行更改。';

  @override
  String get approvalAlwaysAsk => '请求批准';

  @override
  String get approvalAlwaysAskDesc => '建议大多数用户使用。对所有操作请求批准。';

  @override
  String get approvalAutoApprove => '帮我批准';

  @override
  String get approvalAutoApproveDesc => '推荐用于快速、协作的会话。只读操作自动批准，有副作用的操作请求批准。';

  @override
  String get approvalYolo => '完全访问权限';

  @override
  String get approvalYoloDesc => '需要完全信任。不进行审批即可完全访问环境（包括编辑文件和执行命令）。';

  @override
  String get thinkingTitle => '思考';

  @override
  String get thinkingIntensity => '思考强度';

  @override
  String get thinkingOff => '关闭';

  @override
  String get thinkingLow => '低';

  @override
  String get thinkingMedium => '中';

  @override
  String get thinkingHigh => '高';

  @override
  String get thinkingVeryHigh => '极高';

  @override
  String get thinkingOffDesc => '关闭：不进行额外思考推理，响应速度最快。';

  @override
  String get thinkingLowDesc => '低：快速思考，适合简单修改与轻量问答。';

  @override
  String get thinkingMediumDesc => '中：适度思考，兼顾推理质量与响应速度。';

  @override
  String get thinkingHighDesc => '高：深入思考，适用于大多数代码开发与重构任务。';

  @override
  String get thinkingVeryHighDesc => '极高：模型将进行深入思考并探索多种解决途径，适用于复杂编码任务。';

  @override
  String get resetToDefault => '重置为默认';

  @override
  String get selectModel => '切换模型';

  @override
  String get moreModelSettings => '更多设置与 API Key...';

  @override
  String get addContext => '添加上下文';

  @override
  String get addProjectFile => '引用项目文件 (@file)';

  @override
  String get pasteClipboard => '粘贴剪贴板内容';

  @override
  String get commonPrompts => '常用提示词';

  @override
  String get noFilesInProject => '当前项目暂无文件';

  @override
  String get inputBoxHint => '问问任何问题或提需求...';
}

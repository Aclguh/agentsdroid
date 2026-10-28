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

  @override
  String get noProject => '无项目';

  @override
  String get changeProject => '更改项目';

  @override
  String get selectProjectForSession => '选择此会话所属的项目';

  @override
  String thoughtDuration(int seconds) {
    return '已思考 $seconds 秒';
  }

  @override
  String get modelsAndProviders => '模型与服务商';

  @override
  String get modelsAndProvidersDesc => '管理 AI 服务商、Base URL、API Key 与可用模型';

  @override
  String get agentEngineDesc => '选择内置轻量 Agent 或官方 Claude Code CLI';

  @override
  String get safetySectionDesc => '设置自主审批等级与 YOLO 模式';

  @override
  String get languageDesc => '切换应用界面显示语言';

  @override
  String get subsystemSectionDesc => '查看嵌入式 Linux Debian 沙箱运行与安装状态';

  @override
  String get addProvider => '添加服务商';

  @override
  String get editProvider => '编辑服务商';

  @override
  String get deleteProvider => '删除服务商';

  @override
  String deleteProviderConfirm(String name) {
    return '确定要删除服务商「$name」及其所有模型吗？';
  }

  @override
  String get providerName => '服务商名称';

  @override
  String get providerNameHint => '如：SiliconFlow, Ollama, OpenRouter';

  @override
  String get apiProtocol => '接口协议';

  @override
  String get protocolOpenAi => 'OpenAI 兼容协议';

  @override
  String get protocolAnthropic => 'Anthropic 协议';

  @override
  String modelsCount(int count) {
    return '$count 个模型';
  }

  @override
  String get addModel => '添加模型';

  @override
  String get deleteModel => '删除模型';

  @override
  String deleteModelConfirm(String name) {
    return '确定要删除模型「$name」吗？';
  }

  @override
  String get modelId => '模型标识 (Model ID)';

  @override
  String get modelIdHint => '如：deepseek-chat, gpt-4o';

  @override
  String get modelDisplayName => '显示名称';

  @override
  String get modelDisplayNameHint => '如：DeepSeek Chat (V3)';

  @override
  String get supportsThinking => '支持思考推理 (Reasoning)';

  @override
  String get supportsThinkingDesc => '启用后模型可输出思考过程与调节思考强度';

  @override
  String get customProviderTag => '自定义';

  @override
  String get apiKeyConfigured => '已配置密钥';

  @override
  String get apiKeyMissing => '未配置密钥';

  @override
  String get activeModelBadge => '当前生效';

  @override
  String get setAsActive => '设为当前生效模型';

  @override
  String get openTerminal => '打开 Linux 终端';

  @override
  String get configuredProviders => '已配置的服务商';

  @override
  String get currentActiveModel => '当前生效模型';

  @override
  String get enterApiKeyHint => '输入或粘贴 API Key';

  @override
  String get confirm => '确定';

  @override
  String get pressBackAgainToExit => '再次返回退出应用';

  @override
  String get noModelsConfigured => '未配置模型';

  @override
  String get noProvidersConfigured => '暂无已配置的服务商';

  @override
  String get noModelsInProvider => '该服务商下暂无可用模型';

  @override
  String get addProviderHint => '请点击下方按钮添加服务商与模型';

  @override
  String get noActiveModelHint => '未设置生效模型，请在设置中添加并选择模型';

  @override
  String get about => '关于';

  @override
  String get aboutSubtitle => '版本、包名与开源信息';

  @override
  String get versionSection => '版本信息';

  @override
  String get versionLabel => '版本号';

  @override
  String get buildLabel => '构建号';

  @override
  String get packageNameLabel => '包名';

  @override
  String get repositorySection => '开源仓库';

  @override
  String get repositoryCopied => '仓库地址已复制到剪贴板';

  @override
  String get licenseSection => '开源许可';

  @override
  String get licenseAppCode => '应用代码与设计';

  @override
  String get creditsSection => '致谢与技术基石';

  @override
  String get creditFlutter => '跨平台原生渲染框架';

  @override
  String get creditPRoot => 'Android 用户态 Linux 沙箱环境';

  @override
  String get creditClaudeCode => '终端 Agent 执行引擎与协议参考';

  @override
  String get copyrightNotice =>
      'AgentsDroid © 2026 Aclguh. All rights reserved.';

  @override
  String get themeMode => '外观主题';

  @override
  String get themeDesc => '选择应用程序的视觉显示主题';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeSystemDesc => '保持与操作系统深浅色设置一致';

  @override
  String get themeLight => '浅色模式';

  @override
  String get themeLightDesc => '明亮清晰的浅色视觉风格';

  @override
  String get themeDark => '深色模式';

  @override
  String get themeDarkDesc => '护眼专注的经典深色视觉风格';

  @override
  String get screenRotation => '屏幕旋转';

  @override
  String get screenRotationDesc => '设置应用界面的方向旋转偏好';

  @override
  String get screenRotationAuto => '随重力感应旋转';

  @override
  String get screenRotationAutoDesc => '界面随设备重力感应自动切换横屏与竖屏';

  @override
  String get screenRotationPortrait => '锁定竖屏';

  @override
  String get screenRotationPortraitDesc => '始终保持纵向竖屏显示，避免设备晃动时误旋转';

  @override
  String get subsystemInstallMethod => '安装方式';

  @override
  String get subsystemOnlineDownload => '在线下载';

  @override
  String get subsystemOfflineImport => '离线导入';

  @override
  String get subsystemMirrorSource => '下载镜像源';

  @override
  String get subsystemMirrorGhproxy => '国内加速镜像 (ghproxy.net - 推荐)';

  @override
  String get subsystemMirrorOfficial => '官方源 (GitHub Releases)';

  @override
  String get subsystemMirrorCustom => '自定义下载 URL';

  @override
  String get subsystemCustomUrlHint => '请输入 rootfs 压缩包直链下载地址';

  @override
  String get subsystemDetectedArchives => '已扫描到的本地离线包';

  @override
  String get subsystemNoArchivesDetected => '在下载目录中未检测到 .tar.xz 离线包';

  @override
  String get subsystemRescan => '重新扫描';

  @override
  String get subsystemManualPath => '手动输入文件路径';

  @override
  String get subsystemManualPathHint =>
      '例如: /sdcard/Download/debian-arm64.tar.xz';

  @override
  String get subsystemStartImport => '开始导入解压';

  @override
  String get subsystemOfflineHelp =>
      '提示：可通过手机浏览器直接下载 debian-arm64.tar.xz 到手机 Download 目录后在此导入。';

  @override
  String get subsystemReinstall => '重置子系统';

  @override
  String get subsystemReinstallConfirm => '确定要清空并重置 Linux 子系统吗？已安装的软件包和配置将被删除。';

  @override
  String get subsystemResetSuccess => '子系统已重置';

  @override
  String get subsystemPathEmpty => '请输入有效的文件路径';

  @override
  String get subsystemFileNotFound => '指定的文件不存在';

  @override
  String get subsystemDataDir => '应用专属数据目录';

  @override
  String get subsystemDataDirDesc =>
      '请将下载好的 rootfs 压缩包（如 debian-arm64.tar.xz）放入此应用数据目录中，放入后直接点击开始导入即可。';

  @override
  String get subsystemCopyPath => '复制路径';

  @override
  String get subsystemPathCopied => '数据目录路径已复制到剪贴板';

  @override
  String get subsystemDetectedPackage => '检测到已放入的子系统包';

  @override
  String get subsystemWaitingForPackage => '等待放入子系统压缩包';

  @override
  String get subsystemWaitingDesc =>
      '请通过手机文件管理器或电脑 USB 连接将 debian-arm64.tar.xz 放入上方目录，然后点击重新检测。';

  @override
  String get subsystemNoPackageToImport => '未在应用数据目录中发现可导入的 rootfs 压缩包';

  @override
  String errorApiKeyMissing(String provider) {
    return '未配置 API 密钥：请在右上角「设置」中输入 $provider 的有效 API Key。';
  }

  @override
  String errorAuthFailed(String provider) {
    return 'API 身份认证失败 (401)：请检查设置中 $provider 的 API Key 是否有效。';
  }

  @override
  String get errorRateLimit => '请求频率超限 (429)：模型服务当前受限，请稍后再试。';

  @override
  String get errorQuotaExceeded => '账户额度不足或已耗尽：请前往服务商控制台充值或检查账单配额。';

  @override
  String get errorNetworkConnection => '网络连接失败：无法访问 AI 服务，请检查移动网络连接或代理设置。';

  @override
  String get errorModelNotFound => '指定模型未找到：请在设置中检查模型名称是否正确。';

  @override
  String get errorSubsystemNotInstalled => 'Linux 子系统尚未安装：请前往「设置」完成安装。';

  @override
  String errorSubsystemExecution(int exitCode) {
    return '子系统指令执行失败 (退出码 $exitCode)';
  }

  @override
  String get errorWorkspaceSecurity => '工作区安全拦截：禁止越界访问工作区外部路径。';
}

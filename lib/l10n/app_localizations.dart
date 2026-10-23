import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'AgentsDroid'**
  String get appTitle;

  /// No description provided for @thinking.
  ///
  /// In zh, this message translates to:
  /// **'思考中...'**
  String get thinking;

  /// No description provided for @reasoningProcess.
  ///
  /// In zh, this message translates to:
  /// **'推理过程'**
  String get reasoningProcess;

  /// No description provided for @agentWorking.
  ///
  /// In zh, this message translates to:
  /// **'Agent 正在执行任务...'**
  String get agentWorking;

  /// No description provided for @stop.
  ///
  /// In zh, this message translates to:
  /// **'停止'**
  String get stop;

  /// No description provided for @welcomeTitle.
  ///
  /// In zh, this message translates to:
  /// **'欢迎使用 AgentsDroid'**
  String get welcomeTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'你的移动端 AI 编程工作台。\n在手机上即可审查代码、编辑项目与执行命令。'**
  String get welcomeSubtitle;

  /// No description provided for @promptSummary.
  ///
  /// In zh, this message translates to:
  /// **'阅读 README.md 并解释项目'**
  String get promptSummary;

  /// No description provided for @promptSummaryQuery.
  ///
  /// In zh, this message translates to:
  /// **'请阅读 README.md 并为我总结这个项目。'**
  String get promptSummaryQuery;

  /// No description provided for @promptFibonacci.
  ///
  /// In zh, this message translates to:
  /// **'在 main.py 中添加斐波那契函数'**
  String get promptFibonacci;

  /// No description provided for @promptFibonacciQuery.
  ///
  /// In zh, this message translates to:
  /// **'请检查 main.py 并添加一个递归斐波那契函数与测试输出。'**
  String get promptFibonacciQuery;

  /// No description provided for @promptListFiles.
  ///
  /// In zh, this message translates to:
  /// **'列出所有项目文件'**
  String get promptListFiles;

  /// No description provided for @promptListFilesQuery.
  ///
  /// In zh, this message translates to:
  /// **'请列出当前工作区的所有文件并展示目录结构。'**
  String get promptListFilesQuery;

  /// No description provided for @inputHintWorking.
  ///
  /// In zh, this message translates to:
  /// **'Agent 正在执行中...'**
  String get inputHintWorking;

  /// No description provided for @inputHintIdle.
  ///
  /// In zh, this message translates to:
  /// **'输入指令让 Agent 审查代码、修改或运行...'**
  String get inputHintIdle;

  /// No description provided for @workspaceFiles.
  ///
  /// In zh, this message translates to:
  /// **'工作区文件'**
  String get workspaceFiles;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @settingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置与模型服务'**
  String get settingsTitle;

  /// No description provided for @modelConfigSection.
  ///
  /// In zh, this message translates to:
  /// **'模型与 API 配置'**
  String get modelConfigSection;

  /// No description provided for @activeProvider.
  ///
  /// In zh, this message translates to:
  /// **'当前 AI 服务商'**
  String get activeProvider;

  /// No description provided for @modelName.
  ///
  /// In zh, this message translates to:
  /// **'模型名称'**
  String get modelName;

  /// No description provided for @apiKey.
  ///
  /// In zh, this message translates to:
  /// **'API 密钥'**
  String get apiKey;

  /// No description provided for @apiBaseUrl.
  ///
  /// In zh, this message translates to:
  /// **'API 基础地址 (Base URL)'**
  String get apiBaseUrl;

  /// No description provided for @safetySection.
  ///
  /// In zh, this message translates to:
  /// **'执行安全策略'**
  String get safetySection;

  /// No description provided for @yoloMode.
  ///
  /// In zh, this message translates to:
  /// **'完全自主模式 (YOLO Mode)'**
  String get yoloMode;

  /// No description provided for @yoloModeDesc.
  ///
  /// In zh, this message translates to:
  /// **'自动放行所有文件修改与命令执行，不再弹出确认审批卡片。'**
  String get yoloModeDesc;

  /// No description provided for @subsystemSection.
  ///
  /// In zh, this message translates to:
  /// **'嵌入式 Linux 子系统 (PRoot)'**
  String get subsystemSection;

  /// No description provided for @subsystemDesc.
  ///
  /// In zh, this message translates to:
  /// **'基于 PRoot 在 App 私有沙箱内运行 Debian-arm64。零 Root 权限，直接兼容官方 @anthropic-ai/claude-code 与 aider。'**
  String get subsystemDesc;

  /// No description provided for @subsystemReady.
  ///
  /// In zh, this message translates to:
  /// **'已安装并就绪'**
  String get subsystemReady;

  /// No description provided for @subsystemNotInstalled.
  ///
  /// In zh, this message translates to:
  /// **'未安装'**
  String get subsystemNotInstalled;

  /// No description provided for @installSubsystem.
  ///
  /// In zh, this message translates to:
  /// **'下载并安装子系统'**
  String get installSubsystem;

  /// No description provided for @saveSettings.
  ///
  /// In zh, this message translates to:
  /// **'保存设置'**
  String get saveSettings;

  /// No description provided for @settingsSaved.
  ///
  /// In zh, this message translates to:
  /// **'设置已成功保存！'**
  String get settingsSaved;

  /// No description provided for @language.
  ///
  /// In zh, this message translates to:
  /// **'界面语言'**
  String get language;

  /// No description provided for @languageChinese.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get languageChinese;

  /// No description provided for @languageEnglish.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @reviewDiff.
  ///
  /// In zh, this message translates to:
  /// **'审查变更'**
  String get reviewDiff;

  /// No description provided for @approve.
  ///
  /// In zh, this message translates to:
  /// **'允许'**
  String get approve;

  /// No description provided for @reject.
  ///
  /// In zh, this message translates to:
  /// **'拒绝'**
  String get reject;

  /// No description provided for @needsApproval.
  ///
  /// In zh, this message translates to:
  /// **'待审批'**
  String get needsApproval;

  /// No description provided for @approved.
  ///
  /// In zh, this message translates to:
  /// **'已允许'**
  String get approved;

  /// No description provided for @executing.
  ///
  /// In zh, this message translates to:
  /// **'执行中...'**
  String get executing;

  /// No description provided for @autoExecuted.
  ///
  /// In zh, this message translates to:
  /// **'自动执行'**
  String get autoExecuted;

  /// No description provided for @completed.
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get completed;

  /// No description provided for @rejected.
  ///
  /// In zh, this message translates to:
  /// **'已拒绝'**
  String get rejected;

  /// No description provided for @failed.
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get failed;

  /// No description provided for @diffGenerated.
  ///
  /// In zh, this message translates to:
  /// **'代码变更已生成'**
  String get diffGenerated;

  /// No description provided for @noFilesInWorkspace.
  ///
  /// In zh, this message translates to:
  /// **'工作区暂无文件'**
  String get noFilesInWorkspace;

  /// No description provided for @refresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get refresh;

  /// No description provided for @close.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get close;

  /// No description provided for @subsystemTerminal.
  ///
  /// In zh, this message translates to:
  /// **'子系统终端'**
  String get subsystemTerminal;

  /// No description provided for @terminalTitle.
  ///
  /// In zh, this message translates to:
  /// **'Linux 子系统控制台'**
  String get terminalTitle;

  /// No description provided for @toolchainStatus.
  ///
  /// In zh, this message translates to:
  /// **'开发工具链状态'**
  String get toolchainStatus;

  /// No description provided for @runCommand.
  ///
  /// In zh, this message translates to:
  /// **'运行指令'**
  String get runCommand;

  /// No description provided for @quickCommands.
  ///
  /// In zh, this message translates to:
  /// **'常用指令'**
  String get quickCommands;

  /// No description provided for @commandHint.
  ///
  /// In zh, this message translates to:
  /// **'输入 Linux 命令 (如 node -v, git status)...'**
  String get commandHint;

  /// No description provided for @notInstalledWarning.
  ///
  /// In zh, this message translates to:
  /// **'Linux 子系统尚未安装，请前往「设置」进行安装'**
  String get notInstalledWarning;

  /// No description provided for @clearLog.
  ///
  /// In zh, this message translates to:
  /// **'清屏'**
  String get clearLog;

  /// No description provided for @agentEngine.
  ///
  /// In zh, this message translates to:
  /// **'Agent 引擎'**
  String get agentEngine;

  /// No description provided for @engineBuiltin.
  ///
  /// In zh, this message translates to:
  /// **'内置轻量 Agent'**
  String get engineBuiltin;

  /// No description provided for @engineBuiltinShort.
  ///
  /// In zh, this message translates to:
  /// **'内置 Agent'**
  String get engineBuiltinShort;

  /// No description provided for @engineClaudeCode.
  ///
  /// In zh, this message translates to:
  /// **'官方 Claude Code CLI'**
  String get engineClaudeCode;

  /// No description provided for @engineClaudeCodeShort.
  ///
  /// In zh, this message translates to:
  /// **'Claude CLI'**
  String get engineClaudeCodeShort;

  /// No description provided for @engineSwitchTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择 Agent 执行引擎'**
  String get engineSwitchTitle;

  /// No description provided for @engineBuiltinDesc.
  ///
  /// In zh, this message translates to:
  /// **'轻量极速，直接调用大模型 API，无需额外安装 npm 依赖。'**
  String get engineBuiltinDesc;

  /// No description provided for @engineClaudeCodeDesc.
  ///
  /// In zh, this message translates to:
  /// **'Anthropic 官方 Claude Code CLI，运行于嵌入式 Linux PRoot 沙箱内。'**
  String get engineClaudeCodeDesc;

  /// No description provided for @engineNotReady.
  ///
  /// In zh, this message translates to:
  /// **'引擎环境尚未就绪'**
  String get engineNotReady;

  /// No description provided for @goToSubsystemTerminal.
  ///
  /// In zh, this message translates to:
  /// **'前往子系统终端'**
  String get goToSubsystemTerminal;

  /// No description provided for @goToSettings.
  ///
  /// In zh, this message translates to:
  /// **'前往设置'**
  String get goToSettings;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @exportZip.
  ///
  /// In zh, this message translates to:
  /// **'导出 Zip 压缩包'**
  String get exportZip;

  /// No description provided for @exportingZip.
  ///
  /// In zh, this message translates to:
  /// **'正在压缩并导出工作区...'**
  String get exportingZip;

  /// No description provided for @zipExported.
  ///
  /// In zh, this message translates to:
  /// **'工作区已成功导出为 Zip 压缩包！'**
  String get zipExported;

  /// No description provided for @cloneGit.
  ///
  /// In zh, this message translates to:
  /// **'克隆 Git 仓库'**
  String get cloneGit;

  /// No description provided for @cloneGitHint.
  ///
  /// In zh, this message translates to:
  /// **'输入 Git 仓库 URL (如 https://github.com/...)'**
  String get cloneGitHint;

  /// No description provided for @cloning.
  ///
  /// In zh, this message translates to:
  /// **'正在克隆代码仓库...'**
  String get cloning;

  /// No description provided for @cloneSuccess.
  ///
  /// In zh, this message translates to:
  /// **'Git 仓库克隆成功！'**
  String get cloneSuccess;

  /// No description provided for @cloneFailed.
  ///
  /// In zh, this message translates to:
  /// **'Git 仓库克隆失败'**
  String get cloneFailed;

  /// No description provided for @newFile.
  ///
  /// In zh, this message translates to:
  /// **'新建文件'**
  String get newFile;

  /// No description provided for @newFolder.
  ///
  /// In zh, this message translates to:
  /// **'新建文件夹'**
  String get newFolder;

  /// No description provided for @fileNameHint.
  ///
  /// In zh, this message translates to:
  /// **'输入文件名 (如 utils.py)'**
  String get fileNameHint;

  /// No description provided for @folderNameHint.
  ///
  /// In zh, this message translates to:
  /// **'输入文件夹名'**
  String get folderNameHint;

  /// No description provided for @deleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确认删除'**
  String get deleteConfirm;

  /// No description provided for @deleteConfirmMsg.
  ///
  /// In zh, this message translates to:
  /// **'确认要删除该项吗？此操作无法撤销。'**
  String get deleteConfirmMsg;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @copyContent.
  ///
  /// In zh, this message translates to:
  /// **'复制修改后内容'**
  String get copyContent;

  /// No description provided for @copiedToClipboard.
  ///
  /// In zh, this message translates to:
  /// **'已复制到剪贴板'**
  String get copiedToClipboard;

  /// No description provided for @chatHistory.
  ///
  /// In zh, this message translates to:
  /// **'历史会话'**
  String get chatHistory;

  /// No description provided for @newChat.
  ///
  /// In zh, this message translates to:
  /// **'新建会话'**
  String get newChat;

  /// No description provided for @noHistorySessions.
  ///
  /// In zh, this message translates to:
  /// **'暂无历史会话'**
  String get noHistorySessions;

  /// No description provided for @deleteSession.
  ///
  /// In zh, this message translates to:
  /// **'删除会话'**
  String get deleteSession;

  /// No description provided for @deleteSessionConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除此会话记录吗？'**
  String get deleteSessionConfirm;

  /// No description provided for @renameSession.
  ///
  /// In zh, this message translates to:
  /// **'重命名会话'**
  String get renameSession;

  /// No description provided for @sessionTitleHint.
  ///
  /// In zh, this message translates to:
  /// **'输入会话标题'**
  String get sessionTitleHint;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @sessionUntitled.
  ///
  /// In zh, this message translates to:
  /// **'新会话'**
  String get sessionUntitled;

  /// No description provided for @projects.
  ///
  /// In zh, this message translates to:
  /// **'项目'**
  String get projects;

  /// No description provided for @conversations.
  ///
  /// In zh, this message translates to:
  /// **'会话'**
  String get conversations;

  /// No description provided for @newProject.
  ///
  /// In zh, this message translates to:
  /// **'新建项目'**
  String get newProject;

  /// No description provided for @projectNameHint.
  ///
  /// In zh, this message translates to:
  /// **'输入项目名称 (如 my_app)'**
  String get projectNameHint;

  /// No description provided for @create.
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get create;

  /// No description provided for @archive.
  ///
  /// In zh, this message translates to:
  /// **'归档'**
  String get archive;

  /// No description provided for @unarchive.
  ///
  /// In zh, this message translates to:
  /// **'恢复'**
  String get unarchive;

  /// No description provided for @archivedSessions.
  ///
  /// In zh, this message translates to:
  /// **'已归档会话'**
  String get archivedSessions;

  /// No description provided for @showArchived.
  ///
  /// In zh, this message translates to:
  /// **'查看归档'**
  String get showArchived;

  /// No description provided for @hideArchived.
  ///
  /// In zh, this message translates to:
  /// **'返回活跃会话'**
  String get hideArchived;

  /// No description provided for @noArchivedSessions.
  ///
  /// In zh, this message translates to:
  /// **'暂无归档会话'**
  String get noArchivedSessions;

  /// No description provided for @newProjectSession.
  ///
  /// In zh, this message translates to:
  /// **'新建项目会话'**
  String get newProjectSession;

  /// No description provided for @newStandaloneSession.
  ///
  /// In zh, this message translates to:
  /// **'新建独立会话'**
  String get newStandaloneSession;

  /// No description provided for @archiveSessionConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要归档此会话吗？'**
  String get archiveSessionConfirm;

  /// No description provided for @unarchiveSessionConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要恢复此会话吗？'**
  String get unarchiveSessionConfirm;

  /// No description provided for @newConversation.
  ///
  /// In zh, this message translates to:
  /// **'新建对话'**
  String get newConversation;

  /// No description provided for @conversationHistory.
  ///
  /// In zh, this message translates to:
  /// **'会话历史'**
  String get conversationHistory;

  /// No description provided for @displayOptions.
  ///
  /// In zh, this message translates to:
  /// **'显示设置'**
  String get displayOptions;

  /// No description provided for @sortConversations.
  ///
  /// In zh, this message translates to:
  /// **'会话排序'**
  String get sortConversations;

  /// No description provided for @sortProjects.
  ///
  /// In zh, this message translates to:
  /// **'项目排序'**
  String get sortProjects;

  /// No description provided for @sortRecent.
  ///
  /// In zh, this message translates to:
  /// **'最近更新'**
  String get sortRecent;

  /// No description provided for @sortName.
  ///
  /// In zh, this message translates to:
  /// **'按名称 (A-Z)'**
  String get sortName;

  /// No description provided for @archivedOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅显示归档'**
  String get archivedOnly;

  /// No description provided for @searchConversations.
  ///
  /// In zh, this message translates to:
  /// **'搜索会话...'**
  String get searchConversations;

  /// No description provided for @allConversations.
  ///
  /// In zh, this message translates to:
  /// **'全部会话'**
  String get allConversations;

  /// No description provided for @noMatchingConversations.
  ///
  /// In zh, this message translates to:
  /// **'未找到匹配会话'**
  String get noMatchingConversations;

  /// No description provided for @approvalTitle.
  ///
  /// In zh, this message translates to:
  /// **'应如何批准 Agent 操作？'**
  String get approvalTitle;

  /// No description provided for @approvalSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'此设置适用于此会话中的命令执行和文件修改。您可以随时进行更改。'**
  String get approvalSubtitle;

  /// No description provided for @approvalAlwaysAsk.
  ///
  /// In zh, this message translates to:
  /// **'请求批准'**
  String get approvalAlwaysAsk;

  /// No description provided for @approvalAlwaysAskDesc.
  ///
  /// In zh, this message translates to:
  /// **'建议大多数用户使用。对所有操作请求批准。'**
  String get approvalAlwaysAskDesc;

  /// No description provided for @approvalAutoApprove.
  ///
  /// In zh, this message translates to:
  /// **'帮我批准'**
  String get approvalAutoApprove;

  /// No description provided for @approvalAutoApproveDesc.
  ///
  /// In zh, this message translates to:
  /// **'推荐用于快速、协作的会话。只读操作自动批准，有副作用的操作请求批准。'**
  String get approvalAutoApproveDesc;

  /// No description provided for @approvalYolo.
  ///
  /// In zh, this message translates to:
  /// **'完全访问权限'**
  String get approvalYolo;

  /// No description provided for @approvalYoloDesc.
  ///
  /// In zh, this message translates to:
  /// **'需要完全信任。不进行审批即可完全访问环境（包括编辑文件和执行命令）。'**
  String get approvalYoloDesc;

  /// No description provided for @thinkingTitle.
  ///
  /// In zh, this message translates to:
  /// **'思考'**
  String get thinkingTitle;

  /// No description provided for @thinkingIntensity.
  ///
  /// In zh, this message translates to:
  /// **'思考强度'**
  String get thinkingIntensity;

  /// No description provided for @thinkingOff.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get thinkingOff;

  /// No description provided for @thinkingLow.
  ///
  /// In zh, this message translates to:
  /// **'低'**
  String get thinkingLow;

  /// No description provided for @thinkingMedium.
  ///
  /// In zh, this message translates to:
  /// **'中'**
  String get thinkingMedium;

  /// No description provided for @thinkingHigh.
  ///
  /// In zh, this message translates to:
  /// **'高'**
  String get thinkingHigh;

  /// No description provided for @thinkingVeryHigh.
  ///
  /// In zh, this message translates to:
  /// **'极高'**
  String get thinkingVeryHigh;

  /// No description provided for @thinkingOffDesc.
  ///
  /// In zh, this message translates to:
  /// **'关闭：不进行额外思考推理，响应速度最快。'**
  String get thinkingOffDesc;

  /// No description provided for @thinkingLowDesc.
  ///
  /// In zh, this message translates to:
  /// **'低：快速思考，适合简单修改与轻量问答。'**
  String get thinkingLowDesc;

  /// No description provided for @thinkingMediumDesc.
  ///
  /// In zh, this message translates to:
  /// **'中：适度思考，兼顾推理质量与响应速度。'**
  String get thinkingMediumDesc;

  /// No description provided for @thinkingHighDesc.
  ///
  /// In zh, this message translates to:
  /// **'高：深入思考，适用于大多数代码开发与重构任务。'**
  String get thinkingHighDesc;

  /// No description provided for @thinkingVeryHighDesc.
  ///
  /// In zh, this message translates to:
  /// **'极高：模型将进行深入思考并探索多种解决途径，适用于复杂编码任务。'**
  String get thinkingVeryHighDesc;

  /// No description provided for @resetToDefault.
  ///
  /// In zh, this message translates to:
  /// **'重置为默认'**
  String get resetToDefault;

  /// No description provided for @selectModel.
  ///
  /// In zh, this message translates to:
  /// **'切换模型'**
  String get selectModel;

  /// No description provided for @moreModelSettings.
  ///
  /// In zh, this message translates to:
  /// **'更多设置与 API Key...'**
  String get moreModelSettings;

  /// No description provided for @addContext.
  ///
  /// In zh, this message translates to:
  /// **'添加上下文'**
  String get addContext;

  /// No description provided for @addProjectFile.
  ///
  /// In zh, this message translates to:
  /// **'引用项目文件 (@file)'**
  String get addProjectFile;

  /// No description provided for @pasteClipboard.
  ///
  /// In zh, this message translates to:
  /// **'粘贴剪贴板内容'**
  String get pasteClipboard;

  /// No description provided for @commonPrompts.
  ///
  /// In zh, this message translates to:
  /// **'常用提示词'**
  String get commonPrompts;

  /// No description provided for @noFilesInProject.
  ///
  /// In zh, this message translates to:
  /// **'当前项目暂无文件'**
  String get noFilesInProject;

  /// No description provided for @inputBoxHint.
  ///
  /// In zh, this message translates to:
  /// **'问问任何问题或提需求...'**
  String get inputBoxHint;

  /// No description provided for @noProject.
  ///
  /// In zh, this message translates to:
  /// **'无项目'**
  String get noProject;

  /// No description provided for @changeProject.
  ///
  /// In zh, this message translates to:
  /// **'更改项目'**
  String get changeProject;

  /// No description provided for @selectProjectForSession.
  ///
  /// In zh, this message translates to:
  /// **'选择此会话所属的项目'**
  String get selectProjectForSession;

  /// No description provided for @thoughtDuration.
  ///
  /// In zh, this message translates to:
  /// **'已思考 {seconds} 秒'**
  String thoughtDuration(int seconds);

  /// No description provided for @modelsAndProviders.
  ///
  /// In zh, this message translates to:
  /// **'模型与服务商'**
  String get modelsAndProviders;

  /// No description provided for @modelsAndProvidersDesc.
  ///
  /// In zh, this message translates to:
  /// **'管理 AI 服务商、Base URL、API Key 与可用模型'**
  String get modelsAndProvidersDesc;

  /// No description provided for @agentEngineDesc.
  ///
  /// In zh, this message translates to:
  /// **'选择内置轻量 Agent 或官方 Claude Code CLI'**
  String get agentEngineDesc;

  /// No description provided for @safetySectionDesc.
  ///
  /// In zh, this message translates to:
  /// **'设置自主审批等级与 YOLO 模式'**
  String get safetySectionDesc;

  /// No description provided for @languageDesc.
  ///
  /// In zh, this message translates to:
  /// **'切换应用界面显示语言'**
  String get languageDesc;

  /// No description provided for @subsystemSectionDesc.
  ///
  /// In zh, this message translates to:
  /// **'查看嵌入式 Linux Debian 沙箱运行与安装状态'**
  String get subsystemSectionDesc;

  /// No description provided for @addProvider.
  ///
  /// In zh, this message translates to:
  /// **'添加服务商'**
  String get addProvider;

  /// No description provided for @editProvider.
  ///
  /// In zh, this message translates to:
  /// **'编辑服务商'**
  String get editProvider;

  /// No description provided for @deleteProvider.
  ///
  /// In zh, this message translates to:
  /// **'删除服务商'**
  String get deleteProvider;

  /// No description provided for @deleteProviderConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除服务商「{name}」及其所有模型吗？'**
  String deleteProviderConfirm(String name);

  /// No description provided for @providerName.
  ///
  /// In zh, this message translates to:
  /// **'服务商名称'**
  String get providerName;

  /// No description provided for @providerNameHint.
  ///
  /// In zh, this message translates to:
  /// **'如：SiliconFlow, Ollama, OpenRouter'**
  String get providerNameHint;

  /// No description provided for @apiProtocol.
  ///
  /// In zh, this message translates to:
  /// **'接口协议'**
  String get apiProtocol;

  /// No description provided for @protocolOpenAi.
  ///
  /// In zh, this message translates to:
  /// **'OpenAI 兼容协议'**
  String get protocolOpenAi;

  /// No description provided for @protocolAnthropic.
  ///
  /// In zh, this message translates to:
  /// **'Anthropic 协议'**
  String get protocolAnthropic;

  /// No description provided for @modelsCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个模型'**
  String modelsCount(int count);

  /// No description provided for @addModel.
  ///
  /// In zh, this message translates to:
  /// **'添加模型'**
  String get addModel;

  /// No description provided for @deleteModel.
  ///
  /// In zh, this message translates to:
  /// **'删除模型'**
  String get deleteModel;

  /// No description provided for @deleteModelConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除模型「{name}」吗？'**
  String deleteModelConfirm(String name);

  /// No description provided for @modelId.
  ///
  /// In zh, this message translates to:
  /// **'模型标识 (Model ID)'**
  String get modelId;

  /// No description provided for @modelIdHint.
  ///
  /// In zh, this message translates to:
  /// **'如：deepseek-chat, gpt-4o'**
  String get modelIdHint;

  /// No description provided for @modelDisplayName.
  ///
  /// In zh, this message translates to:
  /// **'显示名称'**
  String get modelDisplayName;

  /// No description provided for @modelDisplayNameHint.
  ///
  /// In zh, this message translates to:
  /// **'如：DeepSeek Chat (V3)'**
  String get modelDisplayNameHint;

  /// No description provided for @supportsThinking.
  ///
  /// In zh, this message translates to:
  /// **'支持思考推理 (Reasoning)'**
  String get supportsThinking;

  /// No description provided for @supportsThinkingDesc.
  ///
  /// In zh, this message translates to:
  /// **'启用后模型可输出思考过程与调节思考强度'**
  String get supportsThinkingDesc;

  /// No description provided for @customProviderTag.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get customProviderTag;

  /// No description provided for @apiKeyConfigured.
  ///
  /// In zh, this message translates to:
  /// **'已配置密钥'**
  String get apiKeyConfigured;

  /// No description provided for @apiKeyMissing.
  ///
  /// In zh, this message translates to:
  /// **'未配置密钥'**
  String get apiKeyMissing;

  /// No description provided for @activeModelBadge.
  ///
  /// In zh, this message translates to:
  /// **'当前生效'**
  String get activeModelBadge;

  /// No description provided for @setAsActive.
  ///
  /// In zh, this message translates to:
  /// **'设为当前生效模型'**
  String get setAsActive;

  /// No description provided for @openTerminal.
  ///
  /// In zh, this message translates to:
  /// **'打开 Linux 终端'**
  String get openTerminal;

  /// No description provided for @configuredProviders.
  ///
  /// In zh, this message translates to:
  /// **'已配置的服务商'**
  String get configuredProviders;

  /// No description provided for @currentActiveModel.
  ///
  /// In zh, this message translates to:
  /// **'当前生效模型'**
  String get currentActiveModel;

  /// No description provided for @enterApiKeyHint.
  ///
  /// In zh, this message translates to:
  /// **'输入或粘贴 API Key'**
  String get enterApiKeyHint;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get confirm;

  /// No description provided for @pressBackAgainToExit.
  ///
  /// In zh, this message translates to:
  /// **'再次返回退出应用'**
  String get pressBackAgainToExit;

  /// No description provided for @noModelsConfigured.
  ///
  /// In zh, this message translates to:
  /// **'未配置模型'**
  String get noModelsConfigured;

  /// No description provided for @noProvidersConfigured.
  ///
  /// In zh, this message translates to:
  /// **'暂无已配置的服务商'**
  String get noProvidersConfigured;

  /// No description provided for @noModelsInProvider.
  ///
  /// In zh, this message translates to:
  /// **'该服务商下暂无可用模型'**
  String get noModelsInProvider;

  /// No description provided for @addProviderHint.
  ///
  /// In zh, this message translates to:
  /// **'请点击下方按钮添加服务商与模型'**
  String get addProviderHint;

  /// No description provided for @noActiveModelHint.
  ///
  /// In zh, this message translates to:
  /// **'未设置生效模型，请在设置中添加并选择模型'**
  String get noActiveModelHint;

  /// No description provided for @about.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get about;

  /// No description provided for @aboutSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'版本、包名与开源信息'**
  String get aboutSubtitle;

  /// No description provided for @versionSection.
  ///
  /// In zh, this message translates to:
  /// **'版本信息'**
  String get versionSection;

  /// No description provided for @versionLabel.
  ///
  /// In zh, this message translates to:
  /// **'版本号'**
  String get versionLabel;

  /// No description provided for @buildLabel.
  ///
  /// In zh, this message translates to:
  /// **'构建号'**
  String get buildLabel;

  /// No description provided for @packageNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'包名'**
  String get packageNameLabel;

  /// No description provided for @repositorySection.
  ///
  /// In zh, this message translates to:
  /// **'开源仓库'**
  String get repositorySection;

  /// No description provided for @repositoryCopied.
  ///
  /// In zh, this message translates to:
  /// **'仓库地址已复制到剪贴板'**
  String get repositoryCopied;

  /// No description provided for @licenseSection.
  ///
  /// In zh, this message translates to:
  /// **'开源许可'**
  String get licenseSection;

  /// No description provided for @licenseAppCode.
  ///
  /// In zh, this message translates to:
  /// **'应用代码与设计'**
  String get licenseAppCode;

  /// No description provided for @creditsSection.
  ///
  /// In zh, this message translates to:
  /// **'致谢与技术基石'**
  String get creditsSection;

  /// No description provided for @creditFlutter.
  ///
  /// In zh, this message translates to:
  /// **'跨平台原生渲染框架'**
  String get creditFlutter;

  /// No description provided for @creditPRoot.
  ///
  /// In zh, this message translates to:
  /// **'Android 用户态 Linux 沙箱环境'**
  String get creditPRoot;

  /// No description provided for @creditClaudeCode.
  ///
  /// In zh, this message translates to:
  /// **'终端 Agent 执行引擎与协议参考'**
  String get creditClaudeCode;

  /// No description provided for @copyrightNotice.
  ///
  /// In zh, this message translates to:
  /// **'AgentsDroid © 2026 Aclguh. All rights reserved.'**
  String get copyrightNotice;

  /// No description provided for @themeMode.
  ///
  /// In zh, this message translates to:
  /// **'外观主题'**
  String get themeMode;

  /// No description provided for @themeDesc.
  ///
  /// In zh, this message translates to:
  /// **'选择应用程序的视觉显示主题'**
  String get themeDesc;

  /// No description provided for @themeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get themeSystem;

  /// No description provided for @themeSystemDesc.
  ///
  /// In zh, this message translates to:
  /// **'保持与操作系统深浅色设置一致'**
  String get themeSystemDesc;

  /// No description provided for @themeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色模式'**
  String get themeLight;

  /// No description provided for @themeLightDesc.
  ///
  /// In zh, this message translates to:
  /// **'明亮清晰的浅色视觉风格'**
  String get themeLightDesc;

  /// No description provided for @themeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色模式'**
  String get themeDark;

  /// No description provided for @themeDarkDesc.
  ///
  /// In zh, this message translates to:
  /// **'护眼专注的经典深色视觉风格'**
  String get themeDarkDesc;

  /// No description provided for @screenRotation.
  ///
  /// In zh, this message translates to:
  /// **'屏幕旋转'**
  String get screenRotation;

  /// No description provided for @screenRotationDesc.
  ///
  /// In zh, this message translates to:
  /// **'设置应用界面的方向旋转偏好'**
  String get screenRotationDesc;

  /// No description provided for @screenRotationAuto.
  ///
  /// In zh, this message translates to:
  /// **'随重力感应旋转'**
  String get screenRotationAuto;

  /// No description provided for @screenRotationAutoDesc.
  ///
  /// In zh, this message translates to:
  /// **'界面随设备重力感应自动切换横屏与竖屏'**
  String get screenRotationAutoDesc;

  /// No description provided for @screenRotationPortrait.
  ///
  /// In zh, this message translates to:
  /// **'锁定竖屏'**
  String get screenRotationPortrait;

  /// No description provided for @screenRotationPortraitDesc.
  ///
  /// In zh, this message translates to:
  /// **'始终保持纵向竖屏显示，避免设备晃动时误旋转'**
  String get screenRotationPortraitDesc;

  /// No description provided for @subsystemInstallMethod.
  ///
  /// In zh, this message translates to:
  /// **'安装方式'**
  String get subsystemInstallMethod;

  /// No description provided for @subsystemOnlineDownload.
  ///
  /// In zh, this message translates to:
  /// **'在线下载'**
  String get subsystemOnlineDownload;

  /// No description provided for @subsystemOfflineImport.
  ///
  /// In zh, this message translates to:
  /// **'离线导入'**
  String get subsystemOfflineImport;

  /// No description provided for @subsystemMirrorSource.
  ///
  /// In zh, this message translates to:
  /// **'下载镜像源'**
  String get subsystemMirrorSource;

  /// No description provided for @subsystemMirrorGhproxy.
  ///
  /// In zh, this message translates to:
  /// **'国内加速镜像 (ghproxy.net - 推荐)'**
  String get subsystemMirrorGhproxy;

  /// No description provided for @subsystemMirrorOfficial.
  ///
  /// In zh, this message translates to:
  /// **'官方源 (GitHub Releases)'**
  String get subsystemMirrorOfficial;

  /// No description provided for @subsystemMirrorCustom.
  ///
  /// In zh, this message translates to:
  /// **'自定义下载 URL'**
  String get subsystemMirrorCustom;

  /// No description provided for @subsystemCustomUrlHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入 rootfs 压缩包直链下载地址'**
  String get subsystemCustomUrlHint;

  /// No description provided for @subsystemDetectedArchives.
  ///
  /// In zh, this message translates to:
  /// **'已扫描到的本地离线包'**
  String get subsystemDetectedArchives;

  /// No description provided for @subsystemNoArchivesDetected.
  ///
  /// In zh, this message translates to:
  /// **'在下载目录中未检测到 .tar.xz 离线包'**
  String get subsystemNoArchivesDetected;

  /// No description provided for @subsystemRescan.
  ///
  /// In zh, this message translates to:
  /// **'重新扫描'**
  String get subsystemRescan;

  /// No description provided for @subsystemManualPath.
  ///
  /// In zh, this message translates to:
  /// **'手动输入文件路径'**
  String get subsystemManualPath;

  /// No description provided for @subsystemManualPathHint.
  ///
  /// In zh, this message translates to:
  /// **'例如: /sdcard/Download/debian-arm64.tar.xz'**
  String get subsystemManualPathHint;

  /// No description provided for @subsystemStartImport.
  ///
  /// In zh, this message translates to:
  /// **'开始导入解压'**
  String get subsystemStartImport;

  /// No description provided for @subsystemOfflineHelp.
  ///
  /// In zh, this message translates to:
  /// **'提示：可通过手机浏览器直接下载 debian-arm64.tar.xz 到手机 Download 目录后在此导入。'**
  String get subsystemOfflineHelp;

  /// No description provided for @subsystemReinstall.
  ///
  /// In zh, this message translates to:
  /// **'重置子系统'**
  String get subsystemReinstall;

  /// No description provided for @subsystemReinstallConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要清空并重置 Linux 子系统吗？已安装的软件包和配置将被删除。'**
  String get subsystemReinstallConfirm;

  /// No description provided for @subsystemResetSuccess.
  ///
  /// In zh, this message translates to:
  /// **'子系统已重置'**
  String get subsystemResetSuccess;

  /// No description provided for @subsystemPathEmpty.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效的文件路径'**
  String get subsystemPathEmpty;

  /// No description provided for @subsystemFileNotFound.
  ///
  /// In zh, this message translates to:
  /// **'指定的文件不存在'**
  String get subsystemFileNotFound;

  /// No description provided for @subsystemDataDir.
  ///
  /// In zh, this message translates to:
  /// **'应用专属数据目录'**
  String get subsystemDataDir;

  /// No description provided for @subsystemDataDirDesc.
  ///
  /// In zh, this message translates to:
  /// **'请将下载好的 rootfs 压缩包（如 debian-arm64.tar.xz）放入此应用数据目录中，放入后直接点击开始导入即可。'**
  String get subsystemDataDirDesc;

  /// No description provided for @subsystemCopyPath.
  ///
  /// In zh, this message translates to:
  /// **'复制路径'**
  String get subsystemCopyPath;

  /// No description provided for @subsystemPathCopied.
  ///
  /// In zh, this message translates to:
  /// **'数据目录路径已复制到剪贴板'**
  String get subsystemPathCopied;

  /// No description provided for @subsystemDetectedPackage.
  ///
  /// In zh, this message translates to:
  /// **'检测到已放入的子系统包'**
  String get subsystemDetectedPackage;

  /// No description provided for @subsystemWaitingForPackage.
  ///
  /// In zh, this message translates to:
  /// **'等待放入子系统压缩包'**
  String get subsystemWaitingForPackage;

  /// No description provided for @subsystemWaitingDesc.
  ///
  /// In zh, this message translates to:
  /// **'请通过手机文件管理器或电脑 USB 连接将 debian-arm64.tar.xz 放入上方目录，然后点击重新检测。'**
  String get subsystemWaitingDesc;

  /// No description provided for @subsystemNoPackageToImport.
  ///
  /// In zh, this message translates to:
  /// **'未在应用数据目录中发现可导入的 rootfs 压缩包'**
  String get subsystemNoPackageToImport;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

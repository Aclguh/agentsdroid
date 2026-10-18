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

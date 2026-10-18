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

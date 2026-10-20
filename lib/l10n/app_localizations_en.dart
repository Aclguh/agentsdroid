// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'AgentsDroid';

  @override
  String get thinking => 'Thinking...';

  @override
  String get reasoningProcess => 'Reasoning Process';

  @override
  String get agentWorking => 'Agent is working...';

  @override
  String get stop => 'Stop';

  @override
  String get welcomeTitle => 'Welcome to AgentsDroid';

  @override
  String get welcomeSubtitle =>
      'Your mobile AI programming workspace.\nInspect files, edit code, and run tests right on your phone.';

  @override
  String get promptSummary => 'Read README.md and explain project';

  @override
  String get promptSummaryQuery =>
      'Please read README.md and summarize this project for me.';

  @override
  String get promptFibonacci => 'Add Fibonacci function to main.py';

  @override
  String get promptFibonacciQuery =>
      'Please inspect main.py and add a recursive Fibonacci function with test output.';

  @override
  String get promptListFiles => 'List all project files';

  @override
  String get promptListFilesQuery =>
      'Please list all files in the current workspace and show the directory structure.';

  @override
  String get inputHintWorking => 'Agent is executing...';

  @override
  String get inputHintIdle => 'Ask agent to inspect, code, or run...';

  @override
  String get workspaceFiles => 'Workspace Files';

  @override
  String get settings => 'Settings';

  @override
  String get settingsTitle => 'Settings & Providers';

  @override
  String get modelConfigSection => 'Model & API Configuration';

  @override
  String get activeProvider => 'Active AI Provider';

  @override
  String get modelName => 'Model Name';

  @override
  String get apiKey => 'API Key';

  @override
  String get apiBaseUrl => 'API Base URL';

  @override
  String get safetySection => 'Execution Safety';

  @override
  String get yoloMode => 'Autonomous Mode (YOLO Mode)';

  @override
  String get yoloModeDesc =>
      'Automatically approve all tool executions and file modifications without manual confirmation cards.';

  @override
  String get subsystemSection => 'Embedded Linux Subsystem (PRoot)';

  @override
  String get subsystemDesc =>
      'Runs Debian-arm64 directly inside the app sandbox via PRoot. Zero root required, supports official @anthropic-ai/claude-code & aider.';

  @override
  String get subsystemReady => 'Installed & Ready';

  @override
  String get subsystemNotInstalled => 'Not Installed';

  @override
  String get installSubsystem => 'Download & Install Subsystem';

  @override
  String get saveSettings => 'Save Settings';

  @override
  String get settingsSaved => 'Settings saved successfully!';

  @override
  String get language => 'Language';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get reviewDiff => 'Review Diff';

  @override
  String get approve => 'Approve';

  @override
  String get reject => 'Reject';

  @override
  String get needsApproval => 'Needs Approval';

  @override
  String get approved => 'Approved';

  @override
  String get executing => 'Running...';

  @override
  String get autoExecuted => 'Auto Executed';

  @override
  String get completed => 'Completed';

  @override
  String get rejected => 'Rejected';

  @override
  String get failed => 'Failed';

  @override
  String get diffGenerated => 'Diff generated';

  @override
  String get noFilesInWorkspace => 'No files in workspace yet.';

  @override
  String get refresh => 'Refresh';

  @override
  String get close => 'Close';

  @override
  String get subsystemTerminal => 'Subsystem Terminal';

  @override
  String get terminalTitle => 'Linux Subsystem Console';

  @override
  String get toolchainStatus => 'Toolchains Status';

  @override
  String get runCommand => 'Run Command';

  @override
  String get quickCommands => 'Quick Commands';

  @override
  String get commandHint => 'Enter Linux command (e.g. node -v, git status)...';

  @override
  String get notInstalledWarning =>
      'Linux Subsystem is not installed yet. Please install it in Settings.';

  @override
  String get clearLog => 'Clear';

  @override
  String get agentEngine => 'Agent Engine';

  @override
  String get engineBuiltin => 'Built-in Light Agent';

  @override
  String get engineBuiltinShort => 'Built-in';

  @override
  String get engineClaudeCode => 'Official Claude Code CLI';

  @override
  String get engineClaudeCodeShort => 'Claude CLI';

  @override
  String get engineSwitchTitle => 'Select Agent Execution Engine';

  @override
  String get engineBuiltinDesc =>
      'Ultra-fast & light, directly calls LLM API without npm dependencies.';

  @override
  String get engineClaudeCodeDesc =>
      'Official Anthropic Claude Code CLI running inside embedded PRoot Linux.';

  @override
  String get engineNotReady => 'Engine Environment Not Ready';

  @override
  String get goToSubsystemTerminal => 'Go to Subsystem Console';

  @override
  String get goToSettings => 'Go to Settings';

  @override
  String get cancel => 'Cancel';

  @override
  String get exportZip => 'Export Zip Archive';

  @override
  String get exportingZip => 'Archiving & exporting workspace...';

  @override
  String get zipExported => 'Workspace successfully exported as Zip archive!';

  @override
  String get cloneGit => 'Clone Git Repository';

  @override
  String get cloneGitHint => 'Enter Git repo URL (e.g. https://github.com/...)';

  @override
  String get cloning => 'Cloning repository...';

  @override
  String get cloneSuccess => 'Repository cloned successfully!';

  @override
  String get cloneFailed => 'Failed to clone repository';

  @override
  String get newFile => 'New File';

  @override
  String get newFolder => 'New Folder';

  @override
  String get fileNameHint => 'Enter file name (e.g. utils.py)';

  @override
  String get folderNameHint => 'Enter folder name';

  @override
  String get deleteConfirm => 'Confirm Delete';

  @override
  String get deleteConfirmMsg =>
      'Are you sure you want to delete this item? This cannot be undone.';

  @override
  String get delete => 'Delete';

  @override
  String get copyContent => 'Copy Modified Content';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get chatHistory => 'Chat History';

  @override
  String get newChat => 'New Chat';

  @override
  String get noHistorySessions => 'No conversation history';

  @override
  String get deleteSession => 'Delete Session';

  @override
  String get deleteSessionConfirm =>
      'Are you sure you want to delete this session?';

  @override
  String get renameSession => 'Rename Session';

  @override
  String get sessionTitleHint => 'Enter session title';

  @override
  String get save => 'Save';

  @override
  String get sessionUntitled => 'New Chat';

  @override
  String get projects => 'Projects';

  @override
  String get conversations => 'Conversations';

  @override
  String get newProject => 'New Project';

  @override
  String get projectNameHint => 'Enter project name (e.g. my_app)';

  @override
  String get create => 'Create';

  @override
  String get archive => 'Archive';

  @override
  String get unarchive => 'Restore';

  @override
  String get archivedSessions => 'Archived Sessions';

  @override
  String get showArchived => 'View Archived';

  @override
  String get hideArchived => 'View Active';

  @override
  String get noArchivedSessions => 'No archived sessions';

  @override
  String get newProjectSession => 'New Project Session';

  @override
  String get newStandaloneSession => 'New Standalone Session';

  @override
  String get archiveSessionConfirm =>
      'Are you sure you want to archive this session?';

  @override
  String get unarchiveSessionConfirm =>
      'Are you sure you want to restore this session?';

  @override
  String get newConversation => 'New Conversation';

  @override
  String get conversationHistory => 'Conversation History';

  @override
  String get displayOptions => 'Display Options';

  @override
  String get sortConversations => 'Sort Conversations';

  @override
  String get sortProjects => 'Sort Projects';

  @override
  String get sortRecent => 'Most Recent';

  @override
  String get sortName => 'By Name (A-Z)';

  @override
  String get archivedOnly => 'Archived Only';

  @override
  String get searchConversations => 'Search conversations...';

  @override
  String get allConversations => 'All Conversations';

  @override
  String get noMatchingConversations => 'No matching conversations found';

  @override
  String get approvalTitle => 'How should Agent actions be approved?';

  @override
  String get approvalSubtitle =>
      'This applies to command execution and file edits in this session. You can change it anytime.';

  @override
  String get approvalAlwaysAsk => 'Ask for approval';

  @override
  String get approvalAlwaysAskDesc =>
      'Recommended for most users. Asks for approval on all actions.';

  @override
  String get approvalAutoApprove => 'Approve for me';

  @override
  String get approvalAutoApproveDesc =>
      'Recommended for fast, collaborative sessions. Read-only actions auto-approve, actions with side effects require approval.';

  @override
  String get approvalYolo => 'Full access';

  @override
  String get approvalYoloDesc =>
      'Requires full trust. Full access without approval (including editing files and running commands).';

  @override
  String get thinkingTitle => 'Thinking';

  @override
  String get thinkingIntensity => 'Reasoning Intensity';

  @override
  String get thinkingOff => 'Off';

  @override
  String get thinkingLow => 'Low';

  @override
  String get thinkingMedium => 'Medium';

  @override
  String get thinkingHigh => 'High';

  @override
  String get thinkingVeryHigh => 'Very High';

  @override
  String get thinkingOffDesc => 'Off: No extra reasoning, fastest response.';

  @override
  String get thinkingLowDesc =>
      'Low: Quick reasoning, suitable for light tasks.';

  @override
  String get thinkingMediumDesc =>
      'Medium: Moderate reasoning, balancing quality and speed.';

  @override
  String get thinkingHighDesc =>
      'High: In-depth reasoning, suitable for development and refactoring.';

  @override
  String get thinkingVeryHighDesc =>
      'Very High: Deep reasoning across alternative solutions, ideal for complex coding.';

  @override
  String get resetToDefault => 'Reset to default';

  @override
  String get selectModel => 'Switch Model';

  @override
  String get moreModelSettings => 'More Settings & API Key...';

  @override
  String get addContext => 'Add Context';

  @override
  String get addProjectFile => 'Reference Project File (@file)';

  @override
  String get pasteClipboard => 'Paste Clipboard Content';

  @override
  String get commonPrompts => 'Common Developer Prompts';

  @override
  String get noFilesInProject => 'No files in current project';

  @override
  String get inputBoxHint => 'Ask any question or prompt...';

  @override
  String get noProject => 'No Project';

  @override
  String get changeProject => 'Change Project';

  @override
  String get selectProjectForSession => 'Select project for this session';

  @override
  String thoughtDuration(int seconds) {
    return 'Thought for ${seconds}s';
  }

  @override
  String get modelsAndProviders => 'Models & Providers';

  @override
  String get modelsAndProvidersDesc =>
      'Configure LLM providers, API keys and available models';

  @override
  String get agentEngineDesc =>
      'Switch between Built-in Agent and Claude Code CLI';

  @override
  String get safetySectionDesc => 'Configure approval level and YOLO mode';

  @override
  String get languageDesc => 'Switch application display language';

  @override
  String get subsystemSectionDesc => 'Manage Linux Debian PRoot sandbox status';

  @override
  String get addProvider => 'Add Provider';

  @override
  String get editProvider => 'Edit Provider';

  @override
  String get deleteProvider => 'Delete Provider';

  @override
  String deleteProviderConfirm(String name) {
    return 'Are you sure you want to delete provider \"$name\" and its models?';
  }

  @override
  String get providerName => 'Provider Name';

  @override
  String get providerNameHint => 'e.g. SiliconFlow, Ollama, OpenRouter';

  @override
  String get apiProtocol => 'API Protocol';

  @override
  String get protocolOpenAi => 'OpenAI Compatible';

  @override
  String get protocolAnthropic => 'Anthropic Protocol';

  @override
  String modelsCount(int count) {
    return '$count models';
  }

  @override
  String get addModel => 'Add Model';

  @override
  String get deleteModel => 'Delete Model';

  @override
  String deleteModelConfirm(String name) {
    return 'Are you sure you want to delete model \"$name\"?';
  }

  @override
  String get modelId => 'Model ID';

  @override
  String get modelIdHint => 'e.g. deepseek-chat, gpt-4o';

  @override
  String get modelDisplayName => 'Display Name';

  @override
  String get modelDisplayNameHint => 'e.g. DeepSeek Chat (V3)';

  @override
  String get supportsThinking => 'Supports Reasoning (Thinking)';

  @override
  String get supportsThinkingDesc =>
      'Allows reasoning collapse and thinking intensity control';

  @override
  String get customProviderTag => 'Custom';

  @override
  String get apiKeyConfigured => 'Key Configured';

  @override
  String get apiKeyMissing => 'No Key';

  @override
  String get activeModelBadge => 'Active';

  @override
  String get setAsActive => 'Set as Active Model';

  @override
  String get openTerminal => 'Open Linux Terminal';

  @override
  String get configuredProviders => 'Configured Providers';

  @override
  String get currentActiveModel => 'Active Model';

  @override
  String get enterApiKeyHint => 'Enter or paste API Key';

  @override
  String get confirm => 'Confirm';

  @override
  String get pressBackAgainToExit => 'Press back again to exit';

  @override
  String get noModelsConfigured => 'No Models Configured';

  @override
  String get noProvidersConfigured => 'No Providers Configured';

  @override
  String get noModelsInProvider => 'No models available in this provider';

  @override
  String get addProviderHint =>
      'Please tap the button below to add a provider and models';

  @override
  String get noActiveModelHint =>
      'No active model set. Please configure and select a model in Settings.';

  @override
  String get about => 'About';

  @override
  String get aboutSubtitle => 'Version, package & open-source info';

  @override
  String get versionSection => 'Version Information';

  @override
  String get versionLabel => 'Version';

  @override
  String get buildLabel => 'Build';

  @override
  String get packageNameLabel => 'Package Name';

  @override
  String get repositorySection => 'Repository';

  @override
  String get repositoryCopied => 'Repository URL copied to clipboard';

  @override
  String get licenseSection => 'License';

  @override
  String get licenseAppCode => 'App Source & Design';

  @override
  String get creditsSection => 'Credits & Foundations';

  @override
  String get creditFlutter => 'Cross-platform native framework';

  @override
  String get creditPRoot => 'User-space Linux sandbox on Android';

  @override
  String get creditClaudeCode =>
      'Terminal Agent execution engine and protocol reference';

  @override
  String get copyrightNotice =>
      'AgentsDroid © 2026 Aclguh. All rights reserved.';

  @override
  String get themeMode => 'Theme';

  @override
  String get themeDesc => 'Choose the visual display theme for the application';

  @override
  String get themeSystem => 'Follow System';

  @override
  String get themeSystemDesc => 'Match your system appearance preference';

  @override
  String get themeLight => 'Light Theme';

  @override
  String get themeLightDesc => 'Clean and bright visual style';

  @override
  String get themeDark => 'Dark Theme';

  @override
  String get themeDarkDesc => 'Classic dark visual style for eye comfort';

  @override
  String get screenRotation => 'Screen Rotation';

  @override
  String get screenRotationDesc =>
      'Set the orientation rotation preference for the application';

  @override
  String get screenRotationAuto => 'Auto-rotate with Gravity';

  @override
  String get screenRotationAutoDesc =>
      'Screen automatically switches between portrait and landscape based on device sensor';

  @override
  String get screenRotationPortrait => 'Lock Portrait';

  @override
  String get screenRotationPortraitDesc =>
      'Keep in portrait orientation to prevent accidental rotation when moving device';

  @override
  String get subsystemInstallMethod => 'Installation Method';

  @override
  String get subsystemOnlineDownload => 'Online Download';

  @override
  String get subsystemOfflineImport => 'Offline Import';

  @override
  String get subsystemMirrorSource => 'Download Mirror Source';

  @override
  String get subsystemMirrorGhproxy =>
      'China Accelerator (ghproxy.net - Recommended)';

  @override
  String get subsystemMirrorOfficial => 'Official Source (GitHub Releases)';

  @override
  String get subsystemMirrorCustom => 'Custom Download URL';

  @override
  String get subsystemCustomUrlHint =>
      'Enter rootfs archive direct download URL';

  @override
  String get subsystemDetectedArchives => 'Detected Local Archives';

  @override
  String get subsystemNoArchivesDetected =>
      'No .tar.xz archive found in Download directory';

  @override
  String get subsystemRescan => 'Rescan';

  @override
  String get subsystemManualPath => 'Manual File Path';

  @override
  String get subsystemManualPathHint =>
      'e.g. /sdcard/Download/debian-arm64.tar.xz';

  @override
  String get subsystemStartImport => 'Start Import & Extract';

  @override
  String get subsystemOfflineHelp =>
      'Tip: You can download debian-arm64.tar.xz using your browser to the Download folder, then import it here.';

  @override
  String get subsystemReinstall => 'Reset Subsystem';

  @override
  String get subsystemReinstallConfirm =>
      'Are you sure you want to reset the Linux subsystem? Installed packages and configurations will be deleted.';

  @override
  String get subsystemResetSuccess => 'Subsystem has been reset';

  @override
  String get subsystemPathEmpty => 'Please enter a valid file path';

  @override
  String get subsystemFileNotFound => 'Specified file does not exist';
}

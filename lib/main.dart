import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/app_providers.dart';
import 'core/proot/proot_manager.dart';
import 'core/storage/key_vault.dart';
import 'core/storage/session_service.dart';
import 'core/storage/workspace_service.dart';
import 'core/utils/app_logger.dart';
import 'l10n/app_localizations.dart';
import 'ui/chat/chat_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Core Services
    final keyVault = await KeyVault.create();
    AgentsDroidApp.applyScreenOrientation(keyVault.isAutoRotateEnabled());

    final workspaceService = WorkspaceService();
    await workspaceService.init();

    final sessionService = SessionService();
    await sessionService.init();

    final prootManager = PRootManager();
    await prootManager.init(workspacePath: workspaceService.workspacePath);
    workspaceService.attachPRootManager(prootManager);

    runApp(
      ProviderScope(
        overrides: [
          keyVaultProvider.overrideWithValue(keyVault),
          workspaceServiceProvider.overrideWithValue(workspaceService),
          sessionServiceProvider.overrideWithValue(sessionService),
          prootManagerProvider.overrideWithValue(prootManager),
        ],
        child: AgentsDroidApp(
          keyVault: keyVault,
          workspaceService: workspaceService,
          sessionService: sessionService,
          prootManager: prootManager,
        ),
      ),
    );
  } catch (e, stackTrace) {
    AppLogger.error('Initialization error: $e', tag: 'Main', error: e, stackTrace: stackTrace);
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        ),
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    const Text(
                      'AgentsDroid 启动遇到问题',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$e',
                      style: const TextStyle(fontSize: 13, color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AgentsDroidApp extends ConsumerStatefulWidget {
  final KeyVault keyVault;
  final WorkspaceService workspaceService;
  final SessionService sessionService;
  final PRootManager prootManager;

  const AgentsDroidApp({
    super.key,
    required this.keyVault,
    required this.workspaceService,
    required this.sessionService,
    required this.prootManager,
  });

  static void setLocale(BuildContext context, Locale newLocale) {
    try {
      ProviderScope.containerOf(context, listen: false)
          .read(appLocaleProvider.notifier)
          .setLocale(newLocale);
    } catch (_) {
      final _AgentsDroidAppState? state = context.findAncestorStateOfType<_AgentsDroidAppState>();
      state?.setLocale(newLocale);
    }
  }

  static void setThemeMode(BuildContext context, ThemeMode newThemeMode) {
    try {
      ProviderScope.containerOf(context, listen: false)
          .read(appThemeModeProvider.notifier)
          .setThemeMode(newThemeMode);
    } catch (_) {
      final _AgentsDroidAppState? state = context.findAncestorStateOfType<_AgentsDroidAppState>();
      state?.setThemeMode(newThemeMode);
    }
  }

  static void setScreenOrientation(BuildContext context, bool autoRotate) {
    try {
      ProviderScope.containerOf(context, listen: false)
          .read(appAutoRotateProvider.notifier)
          .setScreenOrientation(autoRotate);
      applyScreenOrientation(autoRotate);
    } catch (_) {
      final _AgentsDroidAppState? state = context.findAncestorStateOfType<_AgentsDroidAppState>();
      state?.setScreenOrientation(autoRotate);
    }
  }

  static void applyScreenOrientation(bool autoRotate) {
    if (autoRotate) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  @override
  ConsumerState<AgentsDroidApp> createState() => _AgentsDroidAppState();
}

class _AgentsDroidAppState extends ConsumerState<AgentsDroidApp> {
  @override
  void initState() {
    super.initState();
    AgentsDroidApp.applyScreenOrientation(widget.keyVault.isAutoRotateEnabled());
  }

  void setLocale(Locale newLocale) {
    ref.read(appLocaleProvider.notifier).setLocale(newLocale);
  }

  void setThemeMode(ThemeMode newThemeMode) {
    ref.read(appThemeModeProvider.notifier).setThemeMode(newThemeMode);
  }

  void setScreenOrientation(bool autoRotate) {
    ref.read(appAutoRotateProvider.notifier).setScreenOrientation(autoRotate);
    AgentsDroidApp.applyScreenOrientation(autoRotate);
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(appLocaleProvider);
    final themeMode = ref.watch(appThemeModeProvider);

    return MaterialApp(
      title: 'AgentsDroid',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB), // Modern Blue / Indigo
          brightness: Brightness.light,
          surface: Colors.white,
        ).copyWith(
          primary: const Color(0xFF2563EB),
          onPrimary: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0F172A),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
        dividerColor: const Color(0xFFE2E8F0),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB), // Modern Blue / Indigo
          brightness: Brightness.dark,
          surface: const Color(0xFF141414),
        ).copyWith(
          primary: const Color(0xFF2563EB),
          onPrimary: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF141414),
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1A1A1A),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF2A2A2A)),
          ),
        ),
        dividerColor: const Color(0xFF2A2A2A),
      ),
      home: ChatScreen(
        keyVault: widget.keyVault,
        workspace: widget.workspaceService,
        sessionService: widget.sessionService,
        prootManager: widget.prootManager,
      ),
    );
  }
}

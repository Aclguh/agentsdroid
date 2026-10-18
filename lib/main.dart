import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/proot/proot_manager.dart';
import 'core/storage/key_vault.dart';
import 'core/storage/session_service.dart';
import 'core/storage/workspace_service.dart';
import 'l10n/app_localizations.dart';
import 'ui/chat/chat_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Core Services
    final keyVault = await KeyVault.create();
    final workspaceService = WorkspaceService();
    await workspaceService.init();

    final sessionService = SessionService();
    await sessionService.init();

    final prootManager = PRootManager();
    await prootManager.init(workspacePath: workspaceService.workspacePath);

    runApp(
      ProviderScope(
        child: AgentsDroidApp(
          keyVault: keyVault,
          workspaceService: workspaceService,
          sessionService: sessionService,
          prootManager: prootManager,
        ),
      ),
    );
  } catch (e, stackTrace) {
    debugPrint('Initialization error: $e\n$stackTrace');
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

class AgentsDroidApp extends StatefulWidget {
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
    final _AgentsDroidAppState? state = context.findAncestorStateOfType<_AgentsDroidAppState>();
    state?.setLocale(newLocale);
  }

  @override
  State<AgentsDroidApp> createState() => _AgentsDroidAppState();
}

class _AgentsDroidAppState extends State<AgentsDroidApp> {
  late Locale _locale;

  @override
  void initState() {
    super.initState();
    _locale = Locale(widget.keyVault.getLanguage());
  }

  void setLocale(Locale newLocale) {
    setState(() {
      _locale = newLocale;
    });
    widget.keyVault.setLanguage(newLocale.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgentsDroid',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      locale: _locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB), // Modern Blue / Indigo
          brightness: Brightness.dark,
          surface: const Color(0xFF141414),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF141414),
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

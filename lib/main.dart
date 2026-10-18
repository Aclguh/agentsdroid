import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/proot/proot_manager.dart';
import 'core/storage/key_vault.dart';
import 'core/storage/workspace_service.dart';
import 'ui/chat/chat_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Core Services
  final keyVault = await KeyVault.create();
  final workspaceService = WorkspaceService();
  await workspaceService.init();

  final prootManager = PRootManager();
  await prootManager.init();

  runApp(
    ProviderScope(
      child: AgentsDroidApp(
        keyVault: keyVault,
        workspaceService: workspaceService,
        prootManager: prootManager,
      ),
    ),
  );
}

class AgentsDroidApp extends StatelessWidget {
  final KeyVault keyVault;
  final WorkspaceService workspaceService;
  final PRootManager prootManager;

  const AgentsDroidApp({
    super.key,
    required this.keyVault,
    required this.workspaceService,
    required this.prootManager,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgentsDroid',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
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
        keyVault: keyVault,
        workspace: workspaceService,
        prootManager: prootManager,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'config/app_config.dart';
import 'core/network/api_client.dart';
import 'core/server_config/server_config_service.dart';
import 'core/auth/auth_controller.dart';
import 'core/auth/auth_repository.dart';
import 'core/init/app_initializer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ⭐ NEW: Create and initialize AppInitializer FIRST
  final initializer = AppInitializer();
  await initializer.initialize(); // Wait for this BEFORE anything else

  // 1. Load server config
  final serverConfig = ServerConfigService();
  await serverConfig.init();

  // 2. Set AppConfig.baseUrl
  if (serverConfig.serverUrl != null && serverConfig.serverUrl!.isNotEmpty) {
    AppConfig.baseUrl = serverConfig.serverUrl!;
  }

  // 3. Initialize ApiClient
  final apiClient = ApiClient(baseUrl: AppConfig.baseUrl);

  // 4. Initialize Repositories
  final authRepository = AuthRepository(apiClient: apiClient);

  runApp(
    MultiProvider(
      providers: [
        // ⭐ ADD initializer provider (before AppRouter depends on it)
        ChangeNotifierProvider<AppInitializer>.value(value: initializer),
        
        // ... existing providers ...
        ChangeNotifierProvider<ServerConfigService>.value(value: serverConfig),
        ChangeNotifierProvider<ApiClient>.value(value: apiClient),
        ChangeNotifierProvider<AuthRepository>.value(value: authRepository),
        
        ChangeNotifierProvider<AuthController>(
          create: (context) => AuthController(
            authRepository: context.read<AuthRepository>(),
            apiClient: context.read<ApiClient>(),
          )..restoreSession(), // This can now safely run after init
        ),
      ],
      child: MobileVMSApp( // ← Pass initializer to app
        initializer: initializer,
        serverConfig: serverConfig,
        apiClient: apiClient,
        authRepository: authRepository,
      ),
    ),
  );
}
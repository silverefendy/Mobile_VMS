import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/auth/auth_controller.dart';
import 'core/server_config/server_config_service.dart';
import 'core/network/api_client.dart';
import 'core/init/app_initializer.dart';
import 'domain/repositories/auth_repository.dart';
import 'app/app_router.dart';
import 'theme/app_theme.dart';

class MobileVMSApp extends StatelessWidget {
  const MobileVMSApp({
    super.key,
    required this.initializer,
    required this.serverConfig,
    required this.apiClient,
    required this.authRepository,
  });

  final AppInitializer initializer;
  final ServerConfigService serverConfig;
  final ApiClient apiClient;
  final AuthRepository authRepository; // pakai abstract interface

  @override
  Widget build(BuildContext context) {
    final authController = context.read<AuthController>();

    final appRouter = AppRouter(
      authController,
      serverConfig,
      initializer,
    );

    return MaterialApp.router(
      title: 'Visitor Management',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter.router,
    );
  }
}

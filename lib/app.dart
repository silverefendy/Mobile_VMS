import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/app_router.dart';
import 'core/auth/auth_controller.dart';
import 'core/network/api_client.dart';
import 'core/server_config/server_config_service.dart';
import 'domain/repositories/auth_repository.dart';
import 'theme/app_theme.dart';

// Re-export agar file lain yang masih import '../../app.dart'
// tidak perlu diubah satu per satu — cukup app.dart yang forward ke theme/colors.dart
export 'theme/colors.dart';

class MobileVMSApp extends StatefulWidget {
  const MobileVMSApp({
    super.key,
    required this.serverConfig,
    required this.apiClient,
    required this.authRepository,
  });

  final ServerConfigService serverConfig;
  final ApiClient apiClient;
  final AuthRepository authRepository;

  @override
  State<MobileVMSApp> createState() => _MobileVMSAppState();
}

class _MobileVMSAppState extends State<MobileVMSApp> {
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    // Router dibuat SEKALI di initState agar tidak rebuild setiap frame
    final auth = context.read<AuthController>();
    _appRouter = AppRouter(auth, widget.serverConfig);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Visitor Management',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      routerConfig: _appRouter.router,
    );
  }
}

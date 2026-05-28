import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/app_router.dart';
import 'core/auth/auth_controller.dart';
import 'core/lifecycle/app_lifecycle_coordinator.dart';
import 'core/settings/settings_controller.dart';
import 'features/dashboard/dashboard_controller.dart';
import 'features/menu/app_menu_controller.dart';

class MobileVMSApp extends StatefulWidget {
  const MobileVMSApp({super.key});

  @override
  State<MobileVMSApp> createState() => _MobileVMSAppState();
}

class _MobileVMSAppState extends State<MobileVMSApp> {
  AppLifecycleCoordinator? _lifecycle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _lifecycle != null) return;
      _lifecycle = AppLifecycleCoordinator(
        onResume: _handleAppResume,
        onPause: () {},
      )..attach();
    });
  }

  Future<void> _handleAppResume() async {
    if (!mounted) return;
    final auth = context.read<AuthController>();
    await auth.restoreSessionOnResume();
    if (!mounted || auth.status != AuthStatus.authenticated) return;

    // Refresh authenticated data after Android/iOS resumes the process so stale
    // failed dashboard/menu requests recover without forcing logout/login.
    await Future.wait<void>([
      context.read<AppMenuController>().refresh(),
      context.read<DashboardController>().refresh(force: true),
    ]);
  }

  @override
  void dispose() {
    _lifecycle?.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final router = AppRouter(auth).router;
    final settings = context.watch<SettingsController>();

    final themeMode = switch (settings.themeMode) {
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
      AppThemeMode.system => ThemeMode.system,
    };

    return MaterialApp.router(
      title: 'Mobile VMS',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      darkTheme: ThemeData.dark(useMaterial3: true),
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      routerConfig: router,
    );
  }
}

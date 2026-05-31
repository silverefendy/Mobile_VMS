import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/app_router.dart';
import 'core/auth/auth_controller.dart';
import 'core/lifecycle/app_lifecycle_coordinator.dart';
import 'core/settings/settings_controller.dart';
import 'features/dashboard/dashboard_controller.dart';
import 'features/employee/employee_dashboard_controller.dart';
import 'features/menu/app_menu_controller.dart';

/// Brand teal color — dipakai di seluruh app
const kBrandTeal = Color(0xFF0D7490);
const kBrandTealDark = Color(0xFF0A5F75);
const kBrandTealLight = Color(0xFFE0F2F7);

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
    await context.read<AppMenuController>().refresh();
    final dashboard = context.read<DashboardController>();
    if (dashboard.cards.isEmpty && !dashboard.loading) {
      await dashboard.refresh();
    }
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
      title: 'VMS',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: kBrandTeal,
        appBarTheme: const AppBarTheme(
          backgroundColor: kBrandTeal,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: kBrandTeal,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: kBrandTeal,
        brightness: Brightness.dark,
      ),
      routerConfig: router,
    );
  }
}

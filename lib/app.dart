import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/app_router.dart';
import 'core/auth/auth_controller.dart';
import 'core/settings/settings_controller.dart';

class MobileVMSApp extends StatelessWidget {
  const MobileVMSApp({super.key});

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

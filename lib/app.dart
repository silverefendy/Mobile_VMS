import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/app_router.dart';
import 'core/auth/auth_controller.dart';

class MobileVMSApp extends StatelessWidget {
  const MobileVMSApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final router = AppRouter(auth).router;

    return MaterialApp.router(
      title: 'Mobile VMS',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      darkTheme: ThemeData.dark(useMaterial3: true),
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      routerConfig: router,
    );
  }
}

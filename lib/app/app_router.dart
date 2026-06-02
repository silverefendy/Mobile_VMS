import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_controller.dart';
import '../core/server_config/server_config_service.dart';
import '../features/activity/activity_screen.dart';
import '../features/app_shell/app_shell_screen.dart';
import '../features/approvals/approvals_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/server_setup_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/employee/employee_dashboard_screen.dart';
import '../features/scanner/scanner_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/visitors/visitors_screen.dart';

class AppRouter {
  AppRouter(this._authController, this._serverConfig);

  final AuthController _authController;
  final ServerConfigService _serverConfig;

  late final GoRouter router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: Listenable.merge([_authController, _serverConfig]),
    redirect: (_, state) {
      final isAuth = _authController.status == AuthStatus.authenticated;
      final isBooting = _authController.status == AuthStatus.booting;
      final isConfigured = _serverConfig.isConfigured;
      final currentRoute = state.matchedLocation;

      _debugLog(
        'REDIRECT CHECK',
        'route=$currentRoute, isAuth=$isAuth, isBooting=$isBooting, '
        'isConfigured=$isConfigured, serverStatus=${_serverConfig.status}',
      );

      // PRIORITAS 1: Masih booting — selalu tampilkan splash
      if (isBooting) {
        if (currentRoute == '/splash') return null;
        return '/splash';
      }

      // PRIORITAS 2: Server belum dikonfigurasi — harus setup dulu
      if (!isConfigured) {
        if (currentRoute == '/setup') return null;
        return '/setup';
      }

      // PRIORITAS 3: Server sudah ada, tapi belum login
      if (!isAuth) {
        if (currentRoute == '/login') return null;
        return '/login';
      }

      // PRIORITAS 4: Sudah login — jangan biarkan di halaman auth
      if (currentRoute == '/splash' ||
          currentRoute == '/login' ||
          currentRoute == '/setup') {
        return '/app';
      }

      // PRIORITAS 5: Semua kondisi normal — tidak perlu redirect
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/setup', builder: (_, __) => const ServerSetupScreen()),
      GoRoute(path: '/app', builder: (_, __) => const AppShellScreen()),
      GoRoute(path: '/scanner', builder: (_, __) => const ScannerScreen()),
      GoRoute(path: '/visitors', builder: (_, __) => const VisitorsScreen()),
      GoRoute(path: '/approvals', builder: (_, __) => const ApprovalsScreen()),
      GoRoute(path: '/activity', builder: (_, __) => const ActivityScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(
        path: '/employee',
        builder: (_, __) => const EmployeeDashboardScreen(),
      ),
    ],
  );

  void _debugLog(String method, String message) {
    debugPrint('[AppRouter.$method] $message');
  }
}

import 'package:flutter/material.dart';
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
      final needsSetup = !_serverConfig.isConfigured;

      if (isBooting) return '/splash';
      if (needsSetup && state.matchedLocation != '/setup') return '/setup';
      if (isAuth &&
          (state.matchedLocation == '/login' ||
              state.matchedLocation == '/splash' ||
              state.matchedLocation == '/setup')) return '/app';
      if (!isAuth && state.matchedLocation == '/setup') return '/setup';
      if (!isAuth && state.matchedLocation != '/login') return '/login';
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
      // Employee dashboard — semua role bisa akses, konten menyesuaikan role
      GoRoute(
        path: '/employee',
        builder: (_, __) => const EmployeeDashboardScreen(),
      ),
    ],
  );
}

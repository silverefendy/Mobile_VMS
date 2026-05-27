import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_controller.dart';
import '../features/app_shell/app_shell_screen.dart';
import '../features/auth/login_screen.dart';

class AppRouter {
  AppRouter(this._authController);

  final AuthController _authController;

  late final GoRouter router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: _authController,
    redirect: (_, state) {
      final isAuth = _authController.status == AuthStatus.authenticated;
      final isBooting = _authController.status == AuthStatus.booting;
      if (isBooting) return '/splash';
      if (!isAuth && state.matchedLocation != '/login') return '/login';
      if (isAuth && (state.matchedLocation == '/login' || state.matchedLocation == '/splash')) return '/app';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const Scaffold(body: Center(child: CircularProgressIndicator()))),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/app', builder: (_, __) => const AppShellScreen()),
    ],
  );
}

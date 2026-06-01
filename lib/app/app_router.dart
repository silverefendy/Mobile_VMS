import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import '../core/auth/auth_controller.dart';
import '../core/server_config/server_config_service.dart';
import '../core/init/app_initializer.dart';
import '../features/auth/splash_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/server_setup_screen.dart';
import '../features/app_shell/app_shell_screen.dart';

class AppRouter {
  AppRouter(
    this._authController, 
    this._serverConfig,
    this._initializer,
  );

  final AuthController _authController;
  final ServerConfigService _serverConfig;
  final AppInitializer _initializer;

  late final GoRouter router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: Listenable.merge([
      _authController, 
      _serverConfig,
      _initializer,
    ]),
    redirect: (_, state) {
      // ⭐ CRITICAL: Block all redirects until initialization completes
      if (!_initializer.isInitialized) {
        _debugLog('REDIRECT', '-> /splash (initialization in progress)');
        return '/splash';
      }

      final isAuth = _authController.status == AuthStatus.authenticated;
      final isBooting = _authController.status == AuthStatus.booting;
      
      // Use isReadyForLogin (strict) instead of isConfigured (loose)
      final serverReady = _serverConfig.isReadyForLogin;
      final serverInvalid = _serverConfig.status == ServerConfigStatus.invalid;
      final currentRoute = state.matchedLocation;

      _debugLog('REDIRECT CHECK', 
        'route=$currentRoute, isAuth=$isAuth, isBooting=$isBooting, '
        'serverReady=$serverReady, serverInvalid=$serverInvalid, '
        'serverStatus=${_serverConfig.status}');

      // 1. If auth still booting, stay on splash
      if (isBooting) {
        _debugLog('REDIRECT', '-> /splash (auth booting)');
        return '/splash';
      }
      
      // 2. Server invalid → force setup (highest priority after booting)
      if (serverInvalid && currentRoute != '/setup') {
        _debugLog('REDIRECT', '-> /setup (server status=invalid)');
        return '/setup';
      }
      
      // 3. Server not ready → setup (only if not already there)
      if (!serverReady && currentRoute != '/setup') {
        _debugLog('REDIRECT', '-> /setup (server not ready)');
        return '/setup';
      }
      
      // 4. Server ready + not authenticated → login
      if (serverReady && !isAuth && currentRoute != '/login') {
        _debugLog('REDIRECT', '-> /login (server ready, not auth)');
        return '/login';
      }
      
      // 5. Authenticated + on auth/setup pages → app
      if (isAuth && 
          (currentRoute == '/login' || 
           currentRoute == '/splash' || 
           currentRoute == '/setup')) {
        _debugLog('REDIRECT', '-> /app (authenticated)');
        return '/app';
      }
      
      // 6. Not authenticated + trying to access app routes → login
      if (!isAuth && 
          currentRoute != '/login' && 
          currentRoute != '/setup' && 
          currentRoute != '/splash') {
        _debugLog('REDIRECT', '-> /login (unauthenticated accessing protected)');
        return '/login';
      }

      // No redirect needed
      _debugLog('REDIRECT', '-> null (no redirect)');
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/setup', builder: (_, __) => const ServerSetupScreen()),
      GoRoute(path: '/app', builder: (_, __) => const AppShellScreen()),
    ],
  );

  void _debugLog(String method, String message) {
    if (kDebugMode) {
      debugPrint('[AppRouter.$method] $message');
    }
  }
}
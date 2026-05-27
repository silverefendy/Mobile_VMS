import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/auth/auth_controller.dart';
import 'core/connectivity/connectivity_service.dart';
import 'core/network/api_client.dart';
import 'core/storage/secure_session_storage.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/menu_repository_impl.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/repositories/menu_repository.dart';
import 'features/menu/menu_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final apiClient = ApiClient();
  final sessionStorage = SecureSessionStorage();
  final authRepository = AuthRepositoryImpl(apiClient: apiClient, storage: sessionStorage);
  final menuRepository = MenuRepositoryImpl(apiClient: apiClient);

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: apiClient),
        Provider<ConnectivityService>(create: (_) => ConnectivityService()),
        Provider<AuthRepository>.value(value: authRepository),
        Provider<MenuRepository>.value(value: menuRepository),
        ChangeNotifierProvider<AuthController>(
          create: (context) => AuthController(
            authRepository: context.read<AuthRepository>(),
            apiClient: context.read<ApiClient>(),
          )..restoreSession(),
        ),
        ChangeNotifierProxyProvider<AuthController, MenuController>(
          create: (context) => MenuController(context.read<MenuRepository>()),
          update: (_, auth, menuController) {
            menuController ??= MenuController(menuRepository);
            menuController.bindAuth(auth);
            return menuController;
          },
        ),
      ],
      child: const MobileVMSApp(),
    ),
  );
}

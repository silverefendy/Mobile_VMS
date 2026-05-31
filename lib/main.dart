import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/auth/auth_controller.dart';
import 'core/connectivity/connectivity_service.dart';
import 'core/network/api_client.dart';
import 'core/qr/qr_validation_service.dart';
import 'core/settings/settings_controller.dart';
import 'core/storage/secure_session_storage.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/menu_repository_impl.dart';
import 'data/repositories/operations_repository_impl.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/repositories/menu_repository.dart';
import 'domain/repositories/operations_repository.dart';
import 'features/activity/activity_controller.dart';
import 'features/approvals/approvals_controller.dart';
import 'features/dashboard/dashboard_controller.dart';
import 'features/employee/employee_dashboard_controller.dart';
import 'features/menu/app_menu_controller.dart';
import 'features/scanner/scan_coordinator.dart';
import 'features/visitors/visitors_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final supportDir = await getApplicationSupportDirectory();
  final cookieJar = PersistCookieJar(
    ignoreExpires: false,
    storage: FileStorage('${supportDir.path}/erpnext_cookies'),
  );
  final apiClient = ApiClient(cookieJar: cookieJar);
  final sessionStorage = SecureSessionStorage();
  final authRepository =
      AuthRepositoryImpl(apiClient: apiClient, storage: sessionStorage);
  final menuRepository = MenuRepositoryImpl(apiClient: apiClient);
  final operationsRepository = OperationsRepositoryImpl(apiClient);

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: apiClient),
        Provider<ConnectivityService>(create: (_) => ConnectivityService()),
        Provider<AuthRepository>.value(value: authRepository),
        Provider<MenuRepository>.value(value: menuRepository),
        Provider<OperationsRepository>.value(value: operationsRepository),

        ChangeNotifierProvider<AuthController>(
          create: (context) => AuthController(
            authRepository: context.read<AuthRepository>(),
            apiClient: context.read<ApiClient>(),
          )..restoreSession(),
        ),

        Provider<QrValidationService>(
          create: (_) => QrValidationService(
            activeSecrets: const ['vms-default-rotating-secret-v1'],
          ),
        ),

        ChangeNotifierProvider<ScanCoordinator>(
          create: (context) => ScanCoordinator(
            context.read<OperationsRepository>(),
            context.read<ConnectivityService>(),
            context.read<QrValidationService>(),
          ),
        ),

        ChangeNotifierProvider<VisitorsController>(
          create: (context) =>
              VisitorsController(context.read<OperationsRepository>()),
        ),
        ChangeNotifierProvider<ApprovalsController>(
          create: (context) =>
              ApprovalsController(context.read<OperationsRepository>()),
        ),
        ChangeNotifierProvider<ActivityController>(
          create: (context) =>
              ActivityController(context.read<OperationsRepository>()),
        ),
        ChangeNotifierProvider<SettingsController>(
          create: (_) => SettingsController(),
        ),
        ChangeNotifierProvider<DashboardController>(
          create: (context) =>
              DashboardController(context.read<MenuRepository>()),
        ),

        // Employee dashboard — role-based (employee lihat miliknya, manager lihat semua)
        ChangeNotifierProvider<EmployeeDashboardController>(
          create: (context) =>
              EmployeeDashboardController(context.read<ApiClient>()),
        ),

        ChangeNotifierProxyProvider<AuthController, AppMenuController>(
          create: (context) =>
              AppMenuController(context.read<MenuRepository>()),
          update: (_, auth, menuController) {
            menuController ??= AppMenuController(menuRepository);
            menuController.bindAuth(auth);
            return menuController;
          },
        ),
      ],
      child: const MobileVMSApp(),
    ),
  );
}

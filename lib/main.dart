import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'config/app_config.dart';
import 'core/auth/auth_controller.dart';
import 'core/auth/auth_repository.dart';
import 'core/init/app_initializer.dart';
import 'core/network/api_client.dart';
import 'core/server_config/server_config_service.dart';
import 'core/settings/settings_controller.dart';
import 'core/storage/secure_session_storage.dart';
import 'data/repositories/menu_repository_impl.dart';
import 'data/repositories/operations_repository_impl.dart';
import 'domain/repositories/auth_repository.dart';
import 'features/activity/activity_controller.dart';
import 'features/approvals/approvals_controller.dart';
import 'features/dashboard/dashboard_controller.dart';
import 'features/employee/employee_dashboard_controller.dart';
import 'features/menu/app_menu_controller.dart';
import 'features/visitors/visitors_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize app initializer
  final initializer = AppInitializer();
  await initializer.initialize();

  // 2. Load server config
  final serverConfig = ServerConfigService();
  await serverConfig.init();

  // 3. Set AppConfig.baseUrl
  if (serverConfig.serverUrl != null && serverConfig.serverUrl!.isNotEmpty) {
    AppConfig.baseUrl = serverConfig.serverUrl!;
  }

  // 4. Initialize CookieJar dengan persistent storage
  final appDocDir = await getApplicationDocumentsDirectory();
  final cookieJar = PersistCookieJar(
    storage: FileStorage('${appDocDir.path}/.cookies/'),
  );

  // 5. Initialize ApiClient (tanpa baseUrl di constructor — set via AppConfig)
  final apiClient = ApiClient(cookieJar: cookieJar);

  // 6. Initialize storage & repository
  final secureStorage = SecureSessionStorage();
  final AuthRepository authRepository = AuthRepositoryImpl(
    apiClient: apiClient,
    storage: secureStorage,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppInitializer>.value(value: initializer),
        ChangeNotifierProvider<ServerConfigService>.value(value: serverConfig),
        // ApiClient bukan ChangeNotifier — pakai Provider biasa
        Provider<ApiClient>.value(value: apiClient),
        // AuthRepository adalah abstract — expose via interface
        Provider<AuthRepository>.value(value: authRepository),
        // AuthRepositoryImpl sebagai ChangeNotifier
        ChangeNotifierProvider<AuthRepositoryImpl>.value(
          value: authRepository as AuthRepositoryImpl,
        ),
        ChangeNotifierProvider<AuthController>(
          create: (context) => AuthController(
            authRepository: context.read<AuthRepository>(),
            apiClient: context.read<ApiClient>(),
          )..restoreSession(),
        ),
        ChangeNotifierProvider<SettingsController>(
          create: (_) => SettingsController(),
        ),
        ChangeNotifierProvider<AppMenuController>(
          create: (context) => AppMenuController(
            MenuRepositoryImpl(apiClient: context.read<ApiClient>()),
          ),
        ),
        ChangeNotifierProvider<DashboardController>(
          create: (context) => DashboardController(
            MenuRepositoryImpl(apiClient: context.read<ApiClient>()),
          ),
        ),
        ChangeNotifierProvider<VisitorsController>(
          create: (context) => VisitorsController(
            OperationsRepositoryImpl(context.read<ApiClient>()),
          ),
        ),
        ChangeNotifierProvider<ApprovalsController>(
          create: (context) => ApprovalsController(
            OperationsRepositoryImpl(context.read<ApiClient>()),
          ),
        ),
        ChangeNotifierProvider<ActivityController>(
          create: (context) => ActivityController(
            OperationsRepositoryImpl(context.read<ApiClient>()),
          ),
        ),
        ChangeNotifierProvider<EmployeeDashboardController>(
          create: (context) => EmployeeDashboardController(
            context.read<ApiClient>(),
          ),
        ),
      ],
      child: MobileVMSApp(
        initializer: initializer,
        serverConfig: serverConfig,
        apiClient: apiClient,
        authRepository: authRepository,
      ),
    ),
  );
}

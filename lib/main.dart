import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/craft_hub_theme.dart';
import 'providers/app_settings_controller.dart';
import 'providers/auth_controller.dart';
import 'services/local_notification_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home_shell.dart';
import 'screens/splash/craft_hub_splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalNotificationService.instance.init();
  final settings = AppSettingsController();
  await settings.bootstrap();
  runApp(CraftHubApp(initialSettings: settings));
}

class CraftHubApp extends StatelessWidget {
  const CraftHubApp({super.key, required this.initialSettings});

  final AppSettingsController initialSettings;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProxyProvider<AuthController, AppSettingsController>(
          create: (_) => initialSettings,
          update: (_, auth, settings) {
            settings ??= initialSettings;
            settings.attachRemoteUser(auth.user);
            return settings;
          },
        ),
      ],
      child: Consumer<AppSettingsController>(
        builder: (context, settings, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Craft Hub',
          theme: CraftHubTheme.lightTheme,
          darkTheme: CraftHubTheme.darkTheme,
          themeMode: settings.flutterThemeMode,
          home: const _Root(),
        ),
      ),
    );
  }
}

class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  bool _splashDone = false;
  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();
    _startSplashTimer();
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    super.dispose();
  }

  void _startSplashTimer() {
    _splashTimer?.cancel();
    _splashTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) {
        setState(() => _splashDone = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (!_splashDone || !auth.ready) {
      return const CraftHubSplashScreen();
    }
    if (auth.token == null || auth.user == null) {
      return const LoginScreen();
    }
    return const HomeShell();
  }
}

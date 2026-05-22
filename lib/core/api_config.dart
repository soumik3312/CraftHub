import 'dart:io';

/// Backend base URL (no trailing slash).
/// - Android emulator → `http://192.168.151.233:3000` reaches host machine’s localhost:3000
/// - iOS simulator → `http://127.0.0.1:3000`
/// - Physical phone → `http://192.168.151.233:3000` (same Wi‑Fi)
///
/// Override at build time:
/// `flutter run --dart-define=API_BASE=http://192.168.151.233:3000`
class ApiConfig {
  static const String fromEnv = String.fromEnvironment(
    'API_BASE',
    defaultValue: '',
  );

  static String get baseUrl {
    if (fromEnv.isNotEmpty) return fromEnv.replaceAll(RegExp(r'/$'), '');
    if (Platform.isAndroid) return 'https://crafthub-backend.onrender.com';
    return 'https://crafthub-backend.onrender.com';
  }
}

import 'package:flutter/foundation.dart';

/// Public OAuth client identifiers supplied at build time. These are IDs, not
/// client secrets. The backend independently verifies every returned ID token.
class GoogleAuthConfig {
  static const String webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const String iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  static String? get platformClientId {
    if (kIsWeb) return webClientId.isEmpty ? null : webClientId;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return iosClientId.isEmpty ? null : iosClientId;
      default:
        return null;
    }
  }
}

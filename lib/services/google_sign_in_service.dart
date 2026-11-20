import 'package:google_sign_in/google_sign_in.dart';

import '../core/google_auth_config.dart';

class GoogleSignInCancelled implements Exception {
  const GoogleSignInCancelled({this.mayBeConfigurationIssue = false});

  /// Android Credential Manager can report a client/SHA mismatch as a generic
  /// cancellation after the account picker has been shown.
  final bool mayBeConfigurationIssue;
}

class GoogleSignInConfigurationException implements Exception {
  const GoogleSignInConfigurationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Wraps the current google_sign_in 7.x singleton API. Google is used only to
/// obtain an ID token; Craft Hub continues to own the app session/JWT.
class GoogleSignInService {
  GoogleSignInService._();

  static Future<void>? _initialization;

  static Future<void> initialize() {
    if (GoogleAuthConfig.webClientId.isEmpty) {
      throw const GoogleSignInConfigurationException(
        'Google sign-in has not been configured for this build yet.',
      );
    }
    return _initialization ??= GoogleSignIn.instance.initialize(
      clientId: GoogleAuthConfig.platformClientId,
      // Android needs the Web/server client ID when google-services.json is
      // intentionally not used. It also makes the ID-token audience predictable
      // for the Craft Hub backend.
      serverClientId: GoogleAuthConfig.webClientId,
    );
  }

  static Stream<GoogleSignInAuthenticationEvent> get authenticationEvents =>
      GoogleSignIn.instance.authenticationEvents;

  static String? idTokenFromEvent(GoogleSignInAuthenticationEvent event) {
    if (event is GoogleSignInAuthenticationEventSignIn) {
      return event.user.authentication.idToken;
    }
    return null;
  }

  static Future<String> interactiveIdToken() async {
    await initialize();
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw const GoogleSignInConfigurationException(
        'This platform requires the Google-managed sign-in button.',
      );
    }
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const GoogleSignInConfigurationException(
          'Google did not return an ID token. Check the OAuth client configuration.',
        );
      }
      return idToken;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled ||
          error.code == GoogleSignInExceptionCode.interrupted) {
        throw const GoogleSignInCancelled(mayBeConfigurationIssue: true);
      }
      final detail = error.description?.trim();
      throw GoogleSignInConfigurationException(
        detail == null || detail.isEmpty
            ? 'Google sign-in failed. Check your Google OAuth configuration and try again.'
            : 'Google sign-in failed: $detail',
      );
    }
  }
}

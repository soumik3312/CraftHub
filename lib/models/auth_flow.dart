/// After email+password login: either success, an error, or a pending
/// registration OTP if the account exists but email is still unverified.
class LoginFlowResult {
  const LoginFlowResult._(this.error, this.email, this.preAuthToken);

  final String? error;
  final String? email;
  final String? preAuthToken;

  factory LoginFlowResult.success() {
    return const LoginFlowResult._(null, null, null);
  }

  /// Account exists but email not verified, so registration OTP must be completed.
  factory LoginFlowResult.finishRegistrationOtp(String email) {
    return LoginFlowResult._(null, email, null);
  }

  factory LoginFlowResult.failure(String message) {
    return LoginFlowResult._(message, null, null);
  }

  bool get needsLoginOtp => false;
  bool get needsRegisterOtp => preAuthToken == null && email != null && error == null;
}

/// After register form: OTP email sent to [verifyEmail], or [error].
class RegisterFlowResult {
  const RegisterFlowResult({this.error, this.verifyEmail});

  final String? error;
  final String? verifyEmail;

  bool get needsOtp => verifyEmail != null && error == null;
}

/// Returned after Google is verified server-side. This token is only for
/// completing account registration; it is never an authenticated app session.
class PendingGoogleRegistration {
  const PendingGoogleRegistration({
    required this.registrationToken,
    required this.name,
    required this.email,
  });

  final String registrationToken;
  final String name;
  final String email;
}

class GoogleRegistrationStartResult {
  const GoogleRegistrationStartResult({this.error, this.pending});

  final String? error;
  final PendingGoogleRegistration? pending;

  bool get isReady => error == null && pending != null;
}

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as google_web;

import '../services/google_sign_in_service.dart';

/// Google requires the official GIS-rendered button for browser sign-in.
class GoogleWebSignInButton extends StatefulWidget {
  const GoogleWebSignInButton({
    super.key,
    required this.onIdToken,
    required this.onError,
    this.busy = false,
  });

  final Future<void> Function(String idToken) onIdToken;
  final ValueChanged<String> onError;
  final bool busy;

  @override
  State<GoogleWebSignInButton> createState() => _GoogleWebSignInButtonState();
}

class _GoogleWebSignInButtonState extends State<GoogleWebSignInButton> {
  StreamSubscription<GoogleSignInAuthenticationEvent>? _subscription;
  bool _ready = false;
  bool _handling = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      await GoogleSignInService.initialize();
      _subscription = GoogleSignInService.authenticationEvents.listen(
        _onAuthenticationEvent,
        onError: (_) => widget.onError('Google sign-in failed. Please try again.'),
      );
      if (mounted) setState(() => _ready = true);
    } on GoogleSignInConfigurationException catch (error) {
      widget.onError(error.message);
    } catch (_) {
      widget.onError('Google sign-in could not be initialized.');
    }
  }

  Future<void> _onAuthenticationEvent(
    GoogleSignInAuthenticationEvent event,
  ) async {
    if (_handling || widget.busy) return;
    final idToken = GoogleSignInService.idTokenFromEvent(event);
    if (idToken == null || idToken.isEmpty) return;
    _handling = true;
    try {
      await widget.onIdToken(idToken);
    } finally {
      _handling = false;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SizedBox(height: 40);
    return IgnorePointer(
      ignoring: widget.busy,
      child: google_web.renderButton(),
    );
  }
}

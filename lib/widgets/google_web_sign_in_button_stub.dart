import 'package:flutter/widgets.dart';

/// Replaced with the GIS-rendered button in browser builds.
class GoogleWebSignInButton extends StatelessWidget {
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
  Widget build(BuildContext context) => const SizedBox.shrink();
}

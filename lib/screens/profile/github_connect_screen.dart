import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/craft_hub_theme.dart';
import '../../providers/auth_controller.dart';
import '../../widgets/craft_hub_ui.dart';

class GitHubConnectResult {
  const GitHubConnectResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class GitHubConnectScreen extends StatefulWidget {
  const GitHubConnectScreen({
    super.key,
    required this.authorizeUrl,
    this.completeUrl = '',
    this.flowToken = '',
  });

  final String authorizeUrl;
  final String completeUrl;
  final String flowToken;

  @override
  State<GitHubConnectScreen> createState() => _GitHubConnectScreenState();
}

class _GitHubConnectScreenState extends State<GitHubConnectScreen>
    with WidgetsBindingObserver {
  Timer? _pollTimer;
  bool _openingBrowser = false;
  bool _checkingStatus = false;
  bool _completed = false;
  bool _browserOpened = false;
  String _statusText = 'Preparing a secure GitHub sign-in...';

  bool get _hasFlowToken => widget.flowToken.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startBrowserFlow());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkFlowStatus();
    }
  }

  Future<void> _startBrowserFlow() async {
    if (_openingBrowser || _completed) return;
    final uri = Uri.tryParse(widget.authorizeUrl);
    if (uri == null) {
      _finish(
        success: false,
        message: 'GitHub sign-in link is invalid. Please try again.',
      );
      return;
    }

    setState(() {
      _openingBrowser = true;
      _statusText = 'Opening GitHub in your browser...';
    });

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted || _completed) return;

    if (!launched) {
      setState(() {
        _openingBrowser = false;
        _statusText =
            'We could not open GitHub automatically. Tap "Open GitHub" to try again.';
      });
      return;
    }

    setState(() {
      _openingBrowser = false;
      _browserOpened = true;
      _statusText = _hasFlowToken
          ? 'Finish the GitHub authorization in your browser, then return to CraftHub.'
          : 'Finish the GitHub authorization in your browser, then return to CraftHub. We will check your GitHub status directly.';
    });

    _pollTimer ??= Timer.periodic(
      const Duration(seconds: 2),
      (_) => _checkFlowStatus(silent: true),
    );
    _checkFlowStatus(silent: true);
  }

  Future<void> _checkFlowStatus({bool silent = false}) async {
    if (_checkingStatus || _completed) return;
    _checkingStatus = true;
    try {
      final api = context.read<AuthController>().api;
      final data = _hasFlowToken
          ? await api.githubConnectPoll(widget.flowToken)
          : await api.githubStatus();
      if (!mounted || _completed) return;

      if (!_hasFlowToken) {
        final user = data['user'] as Map<String, dynamic>? ?? const {};
        final connected = user['githubConnected'] == true;
        final githubUsername = (user['githubUsername'] as String? ?? '').trim();
        if (connected) {
          _finish(
            success: true,
            message: githubUsername.isEmpty
                ? 'GitHub connected.'
                : 'Connected as @$githubUsername.',
          );
          return;
        }

        if (!silent) {
          setState(() {
            _statusText = _browserOpened
                ? 'GitHub authorization is still in progress. Complete it in the browser, then return here.'
                : 'Tap "Open GitHub" to continue the connection.';
          });
        }
        return;
      }

      final status = (data['status'] as String? ?? 'pending').trim();
      final message = (data['message'] as String? ?? '').trim();

      if (status == 'success') {
        _finish(
          success: true,
          message: message.isEmpty ? 'GitHub connected.' : message,
        );
        return;
      }

      if (status == 'error' || status == 'expired') {
        _finish(
          success: false,
          message: message.isEmpty
              ? 'GitHub connection failed. Please try again.'
              : message,
        );
        return;
      }

      if (!silent) {
        setState(() {
          _statusText = _browserOpened
              ? 'Still waiting for GitHub authorization. Complete it in the browser, then come back here.'
              : 'Tap "Open GitHub" to continue the connection.';
        });
      }
    } catch (e) {
      if (!mounted || _completed) return;
      if (!silent) {
        setState(() {
          _statusText = _hasFlowToken
              ? context.read<AuthController>().api.friendlyError(e)
              : 'GitHub opened, but CraftHub could not confirm the result yet. If your backend is still on the older Render deploy, returning from the browser may take a moment.';
        });
      }
    } finally {
      _checkingStatus = false;
    }
  }

  void _finish({required bool success, required String message}) {
    if (_completed || !mounted) return;
    _completed = true;
    _pollTimer?.cancel();
    Navigator.pop(
      context,
      GitHubConnectResult(success: success, message: message),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CraftHubBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Connect GitHub',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: CraftHubPanel(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    CraftHubColors.cyan,
                                    CraftHubColors.lavender,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: CraftHubColors.lavender.withValues(
                                      alpha: 0.28,
                                    ),
                                    blurRadius: 28,
                                    offset: const Offset(0, 14),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.shield_outlined,
                                color: Colors.black,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Secure browser sign-in',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'GitHub blocks some mobile sign-ins inside embedded app views, so CraftHub now opens the authorization in your real browser for a safer connection.',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: CraftHubColors.text.withValues(
                                      alpha: 0.78,
                                    ),
                                    height: 1.45,
                                  ),
                            ),
                            const SizedBox(height: 22),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: CraftHubColors.panelAlt.withValues(
                                  alpha: 0.88,
                                ),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: CraftHubColors.border,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      _statusText,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(height: 1.45),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              _hasFlowToken
                                  ? '1. Tap Open GitHub.\n2. Approve CraftHub in your browser.\n3. Return to the app and we will finish the connection automatically.'
                                  : '1. Tap Open GitHub.\n2. Approve CraftHub in your browser.\n3. Return to the app and we will check your GitHub connection status.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: CraftHubColors.text.withValues(
                                      alpha: 0.74,
                                    ),
                                    height: 1.6,
                                  ),
                            ),
                            const SizedBox(height: 22),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _openingBrowser
                                    ? null
                                    : _startBrowserFlow,
                                icon: const Icon(Icons.open_in_browser_rounded),
                                label: Text(
                                  _openingBrowser
                                      ? 'Opening GitHub...'
                                      : 'Open GitHub',
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _checkingStatus
                                        ? null
                                        : () => _checkFlowStatus(),
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text('Check Again'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => Navigator.pop(context),
                                    icon: const Icon(Icons.close_rounded),
                                    label: const Text('Cancel'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

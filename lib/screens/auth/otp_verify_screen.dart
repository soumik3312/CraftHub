import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../widgets/craft_hub_ui.dart';
import '../../providers/auth_controller.dart';

class OtpVerifyScreen extends StatefulWidget {
  const OtpVerifyScreen({
    super.key,
    required this.email,
    required this.isLoginOtp,
    this.preAuthToken,
    this.title,
  });

  final String email;
  final bool isLoginOtp;
  final String? preAuthToken;
  final String? title;

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthController>();
    setState(() => _busy = true);
    String? err;
    if (widget.isLoginOtp) {
      final token = widget.preAuthToken;
      if (token == null) {
        err = 'Missing login session. Go back and sign in again.';
      } else {
        err = await auth.verifyLoginOtp(preAuthToken: token, code: _code.text);
      }
    } else {
      err = await auth.verifyRegisterOtp(email: widget.email, code: _code.text);
    }
    setState(() => _busy = false);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  Future<void> _resend() async {
    final auth = context.read<AuthController>();
    setState(() => _busy = true);
    String? err;
    if (widget.isLoginOtp && widget.preAuthToken != null) {
      err = await auth.resendLoginOtp(widget.preAuthToken!);
    } else {
      err = await auth.resendRegisterOtp(widget.email);
    }
    setState(() => _busy = false);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('New code sent')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CraftHubBackground(
        padding: const EdgeInsets.all(24),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: CraftHubPanel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.title ?? 'Verify Signal',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'We sent a secure code to ${widget.email}. Enter it below to continue.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _code,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(8),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Verification code',
                        hintText: '6 digits',
                      ),
                      onSubmitted: (_) => _busy ? null : _submit(),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Continue'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy ? null : _resend,
                      child: const Text('Resend code'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

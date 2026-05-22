import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/craft_hub_theme.dart';
import '../../providers/auth_controller.dart';
import '../../widgets/craft_hub_ui.dart';
import 'otp_verify_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    final auth = context.read<AuthController>();
    final result =
        await auth.loginWithPassword(_email.text.trim(), _pass.text);
    setState(() => _loading = false);
    if (!mounted) return;

    if (result.error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.error!)));
      return;
    }
    if (result.needsRegisterOtp) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerifyScreen(
            email: result.email!,
            isLoginOtp: false,
            title: 'Verify Signal',
          ),
        ),
      );
    }
  }

  void _socialSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label sign-in is not connected yet in the backend.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = CraftHubPalette.of(context);
    return Scaffold(
      body: CraftHubBackground(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: CraftHubPanel(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                borderRadius: 30,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _AuthHero(large: true),
                      const SizedBox(height: 18),
                      const Center(
                        child: CraftHubGradientText(
                          'Craft Hub',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Email',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _email,
                        decoration: const InputDecoration(
                          hintText: 'dev@crafthub.com',
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Password',
                              style:
                                  Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                _socialSoon('Password recovery'),
                            child: const Text('Forgot password?'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _pass,
                        obscureText: true,
                        decoration: const InputDecoration(
                          hintText: 'Enter your password',
                        ),
                      ),
                      const SizedBox(height: 22),
                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Text('Sign In'),
                                  SizedBox(width: 10),
                                  Icon(Icons.arrow_forward_rounded),
                                ],
                              ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          color:
                              palette.panelAlt.withValues(alpha: 0.88),
                          border: Border.all(color: palette.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _socialSoon('GitHub'),
                                icon: const Icon(Icons.code),
                                label: const Text('GitHub'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _socialSoon('Google'),
                                icon:
                                    const Icon(Icons.alternate_email),
                                label: const Text('Google'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const RegisterScreen(),
                            ),
                          ),
                          child:
                              const Text('Create a new account'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthHero extends StatelessWidget {
  const _AuthHero({required this.large});

  final bool large;

  @override
  Widget build(BuildContext context) {
    final palette = CraftHubPalette.of(context);
    final size = large ? 136.0 : 112.0;

    return Center(
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [CraftHubColors.cyan, CraftHubColors.lavender],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: CraftHubColors.purple.withValues(alpha: 0.24),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: palette.panel,
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/logo.jpg',
              fit: BoxFit.cover,
              width: size,
              height: size,
            ),
          ),
        ),
      ),
    );
  }
}
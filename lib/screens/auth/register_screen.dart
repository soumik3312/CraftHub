import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/craft_hub_theme.dart';
import '../../models/auth_flow.dart';
import '../../providers/auth_controller.dart';
import '../../services/google_sign_in_service.dart';
import '../../widgets/craft_hub_ui.dart';
import '../../widgets/google_web_sign_in_button.dart';
import 'otp_verify_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.pendingGoogleRegistration});

  final PendingGoogleRegistration? pendingGoogleRegistration;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _bio = TextEditingController();
  final _search = TextEditingController();
  final Set<String> _genres = {};
  bool _loading = false;

  final Map<String, List<String>> _groups = const {
    'App Development': ['App development', 'Web development', 'UI / UX'],
    'AI & Machine Learning': ['AI / ML', 'Data science', 'Open source'],
    'Cloud & Systems': ['Cloud', 'DevOps', 'Cybersecurity'],
    'Emerging Tech': ['Blockchain', 'Game development', 'IoT'],
  };

  bool get _isGoogleRegistration => widget.pendingGoogleRegistration != null;

  @override
  void initState() {
    super.initState();
    final pending = widget.pendingGoogleRegistration;
    if (pending != null) {
      _name.text = pending.name;
      _email.text = pending.email;
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _name.dispose();
    _username.dispose();
    _bio.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final validationError = _validateRequiredFields();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }
    setState(() => _loading = true);
    final auth = context.read<AuthController>();
    final pending = widget.pendingGoogleRegistration;
    if (pending != null) {
      final error = await auth.completeGoogleRegistration(
        pending: pending,
        password: _pass.text,
        name: _name.text.trim(),
        username: _username.text.trim(),
        bio: _bio.text.trim(),
        genres: _genres.toList(),
      );
      if (mounted) setState(() => _loading = false);
      if (!mounted) return;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      } else {
        // AuthController now holds the normal Craft Hub JWT; Root will switch
        // to HomeShell. There is intentionally no OTP route in this branch.
        Navigator.popUntil(context, (route) => route.isFirst);
      }
      return;
    }

    final res = await auth.registerAccount(
      email: _email.text.trim(),
      password: _pass.text,
      name: _name.text.trim(),
      username: _username.text.trim(),
      bio: _bio.text.trim(),
      genres: _genres.toList(),
    );
    if (mounted) setState(() => _loading = false);
    if (!mounted) return;
    if (res.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.error!)));
      return;
    }
    if (res.needsOtp) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerifyScreen(
            email: res.verifyEmail!,
            isLoginOtp: false,
            title: 'Verify Email',
          ),
        ),
      );
    }
  }

  String? _validateRequiredFields() {
    if (_name.text.trim().isEmpty) return 'Display name is required.';
    if (_username.text.trim().isEmpty) return 'Username is required.';
    if (_email.text.trim().isEmpty) return 'Email is required.';
    if (_pass.text.isEmpty) return 'Password is required.';
    return null;
  }

  Future<void> _startGoogleRegistration() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final idToken = await GoogleSignInService.interactiveIdToken();
      await _startGoogleRegistrationWithIdToken(idToken, managesLoading: false);
    } on GoogleSignInCancelled {
      // Account selection was dismissed; keep the form available without noise.
    } on GoogleSignInConfigurationException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google sign-in failed. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startGoogleRegistrationFromWeb(String idToken) =>
      _startGoogleRegistrationWithIdToken(idToken, managesLoading: true);

  Future<void> _startGoogleRegistrationWithIdToken(
    String idToken, {
    required bool managesLoading,
  }) async {
    if (_loading && managesLoading) return;
    if (managesLoading && mounted) setState(() => _loading = true);
    try {
      final result = await context
          .read<AuthController>()
          .startGoogleRegistration(idToken);
      if (!mounted) return;
      if (!result.isReady) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'Google registration could not be started.')),
        );
        return;
      }
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RegisterScreen(pendingGoogleRegistration: result.pending),
        ),
      );
    } finally {
      if (managesLoading && mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = _search.text.trim().toLowerCase();
    final googleRegistration = _isGoogleRegistration;
    return Scaffold(
      body: CraftHubBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 36),
            children: [
              Row(
                children: [
                  const BackButton(),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 12),
              const _RegisterHero(),
              const SizedBox(height: 24),
              if (!googleRegistration) ...[
                Text(
                  'Or verify with Google first',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),
                if (kIsWeb)
                  GoogleWebSignInButton(
                    busy: _loading,
                    onIdToken: _startGoogleRegistrationFromWeb,
                    onError: (message) => ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(message))),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _startGoogleRegistration,
                    icon: const Icon(Icons.g_mobiledata_rounded),
                    label: const Text('Continue with Google'),
                  ),
                const SizedBox(height: 18),
              ],
              CraftHubPanel(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                borderRadius: 28,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (googleRegistration) ...[
                      const _GoogleRegistrationNotice(),
                      const SizedBox(height: 16),
                    ],
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Display name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _username,
                      decoration: const InputDecoration(labelText: 'Username'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _email,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        helperText: googleRegistration
                            ? 'Verified by Google and locked to this account'
                            : null,
                        suffixIcon: googleRegistration
                            ? const Icon(Icons.verified_rounded)
                            : null,
                      ),
                      keyboardType: TextInputType.emailAddress,
                      readOnly: googleRegistration,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pass,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _bio,
                      decoration: const InputDecoration(labelText: 'Bio'),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              CraftHubPanel(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                borderRadius: 28,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Interests',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        if (_genres.isNotEmpty)
                          CraftHubTag(
                            label: '${_genres.length} selected',
                            highlight: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _search,
                      decoration: const InputDecoration(
                        hintText: 'Search skills',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 18),
                    for (final entry in _groups.entries) ...[
                      _SkillGroup(
                        title: entry.key,
                        values: entry.value
                            .where((genre) => filter.isEmpty || genre.toLowerCase().contains(filter))
                            .toList(),
                        selected: _genres,
                        onToggle: (genre, enabled) => setState(() {
                          if (enabled) {
                            _genres.add(genre);
                          } else {
                            _genres.remove(genre);
                          }
                        }),
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (_genres.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _genres
                            .map((genre) => CraftHubTag(label: genre, highlight: true))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(googleRegistration ? 'Complete Account' : 'Create Account'),
                          const SizedBox(width: 10),
                          const Icon(Icons.arrow_forward_rounded),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegisterHero extends StatelessWidget {
  const _RegisterHero();

  @override
  Widget build(BuildContext context) {
    return CraftHubPanel(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      borderRadius: 28,
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [CraftHubColors.cyan, CraftHubColors.lavender],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: CraftHubColors.purple.withValues(alpha: 0.18),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF12061A)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CraftHubGradientText(
                  'Join Craft Hub',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 64,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(
                      colors: [CraftHubColors.cyan, CraftHubColors.lavender],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleRegistrationNotice extends StatelessWidget {
  const _GoogleRegistrationNotice();

  @override
  Widget build(BuildContext context) {
    final palette = CraftHubPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CraftHubColors.cyan.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your Google email is verified. Complete the rest of your Craft Hub profile and create a password to finish.',
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillGroup extends StatelessWidget {
  const _SkillGroup({
    required this.title,
    required this.values,
    required this.selected,
    required this.onToggle,
  });

  final String title;
  final List<String> values;
  final Set<String> selected;
  final void Function(String value, bool enabled) onToggle;

  @override
  Widget build(BuildContext context) {
    final palette = CraftHubPalette.of(context);
    if (values.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: palette.panelAlt.withValues(alpha: 0.82),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: values.map((value) {
              final enabled = selected.contains(value);
              return FilterChip(
                label: Text(value),
                selected: enabled,
                onSelected: (next) => onToggle(value, next),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/craft_hub_theme.dart';
import '../../providers/app_settings_controller.dart';
import '../../providers/auth_controller.dart';
import '../../widgets/craft_hub_ui.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsController>();
    final auth = context.read<AuthController>();
    final user = auth.user;
    final notifications = settings.notifications;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CraftHubBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Row(
                children: [
                  const BackButton(),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Settings',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const CraftHubSectionTitle(
                eyebrow: 'Appearance',
                title: 'Choose your display mode',
                subtitle:
                    'Switch between dark, light, or follow the device setting.',
              ),
              const SizedBox(height: 14),
              CraftHubPanel(
                child: Column(
                  children: [
                    _ThemeChoiceTile(
                      mode: CraftThemeMode.system,
                      currentMode: settings.themeMode,
                      title: 'System default',
                      subtitle: 'Follow your phone theme automatically.',
                      onTap: () => settings.setThemeMode(
                        CraftThemeMode.system,
                        api: auth.api,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ThemeChoiceTile(
                      mode: CraftThemeMode.dark,
                      currentMode: settings.themeMode,
                      title: 'Dark mode',
                      subtitle: 'Keep the current Craft Hub night palette.',
                      onTap: () => settings.setThemeMode(
                        CraftThemeMode.dark,
                        api: auth.api,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ThemeChoiceTile(
                      mode: CraftThemeMode.light,
                      currentMode: settings.themeMode,
                      title: 'Light mode',
                      subtitle: 'Use the brighter Craft Hub surface palette.',
                      onTap: () => settings.setThemeMode(
                        CraftThemeMode.light,
                        api: auth.api,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const CraftHubSectionTitle(
                eyebrow: 'Notifications',
                title: 'Control what reaches your phone',
                subtitle:
                    'Keep notifications focused on direct and workspace messages.',
              ),
              const SizedBox(height: 14),
              CraftHubPanel(
                child: Column(
                  children: [
                    _SettingsSwitchRow(
                      title: 'All notifications',
                      subtitle: settings.notificationPermissionGranted
                          ? 'Master control for all Craft Hub alerts.'
                          : 'Notifications are currently blocked on this device.',
                      value: notifications.enabled,
                      onChanged: (value) => settings.setNotifications(
                        notifications.copyWith(enabled: value),
                        api: auth.api,
                      ),
                    ),
                    const Divider(height: 22),
                    _SettingsSwitchRow(
                      title: 'Direct inbox messages',
                      subtitle:
                          'Notify me when someone sends a direct message.',
                      value: notifications.directMessages,
                      enabled: notifications.enabled,
                      onChanged: (value) => settings.setNotifications(
                        notifications.copyWith(directMessages: value),
                        api: auth.api,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SettingsSwitchRow(
                      title: 'Workspace messages',
                      subtitle:
                          'Notify me when new messages arrive in workspaces.',
                      value: notifications.workspaceMessages,
                      enabled: notifications.enabled,
                      onChanged: (value) => settings.setNotifications(
                        notifications.copyWith(workspaceMessages: value),
                        api: auth.api,
                      ),
                    ),
                    if (!settings.notificationPermissionGranted) ...[
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.tonalIcon(
                          onPressed: () => settings
                              .requestAndEnableNotifications(api: auth.api),
                          icon: const Icon(Icons.notifications_active_rounded),
                          label: const Text('Allow notifications'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const CraftHubSectionTitle(
                eyebrow: 'Security',
                title: 'Account and access',
              ),
              const SizedBox(height: 14),
              CraftHubPanel(
                child: Column(
                  children: [
                    _SettingsLinkRow(
                      title: 'Security overview',
                      subtitle:
                          'Email verified, OTP login enabled, and account session controls.',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SettingsDetailScreen(
                            title: 'Security Overview',
                            body:
                                '''
Email: ${user?['email'] ?? 'Connected account'}

Verification:
Your account uses email verification and OTP-based sign in.

Session:
Use log out below to remove this device session.

Password:
Password management still follows the current backend auth flow.
''',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () => auth.logout(),
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Log out of this device'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const CraftHubSectionTitle(
                eyebrow: 'Legal',
                title: 'Agreements and app info',
              ),
              const SizedBox(height: 14),
              CraftHubPanel(
                child: Column(
                  children: [
                    _SettingsLinkRow(
                      title: 'User agreement',
                      subtitle:
                          'Platform usage expectations for creators and collaborators.',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsDetailScreen(
                            title: 'User Agreement',
                            body: '''
Craft Hub is for legitimate creative collaboration.

Users agree to:
- share accurate profile and project information
- respect collaborator ownership and repository access
- avoid abusive, fraudulent, or unlawful activity
- use shared workspaces responsibly
''',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SettingsLinkRow(
                      title: 'Terms and conditions',
                      subtitle:
                          'Core platform terms for accounts, collaboration, and content.',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsDetailScreen(
                            title: 'Terms and Conditions',
                            body: '''
Craft Hub services are provided as-is.

Key terms:
- account access remains the responsibility of each user
- collaborators must respect project ownership and permissions
- uploaded content must belong to the user or be properly licensed
- platform misuse may result in restricted access
''',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SettingsLinkRow(
                      title: 'About us',
                      subtitle:
                          'What Craft Hub is building for creators and teams.',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsDetailScreen(
                            title: 'About Craft Hub',
                            body: '''
Craft Hub is built for creators who want to discover collaborators, share projects, and work together in connected spaces.

The app combines profile building, project discovery, collaboration requests, messaging, and shared workspaces in one place.
''',
                          ),
                        ),
                      ),
                    ),
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

class _ThemeChoiceTile extends StatelessWidget {
  const _ThemeChoiceTile({
    required this.mode,
    required this.currentMode,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final CraftThemeMode mode;
  final CraftThemeMode currentMode;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = mode == currentMode;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: selected
              ? CraftHubColors.lavender.withValues(alpha: 0.12)
              : Colors.transparent,
          border: Border.all(
            color: selected ? CraftHubColors.lavender : CraftHubColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? CraftHubColors.lavender : CraftHubColors.muted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSwitchRow extends StatelessWidget {
  const _SettingsSwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(value: value, onChanged: enabled ? onChanged : null),
        ],
      ),
    );
  }
}

class _SettingsLinkRow extends StatelessWidget {
  const _SettingsLinkRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: CraftHubColors.panelAlt.withValues(alpha: 0.72),
          border: Border.all(color: CraftHubColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class SettingsDetailScreen extends StatelessWidget {
  const SettingsDetailScreen({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CraftHubBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Row(
                children: [
                  const BackButton(),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              CraftHubPanel(
                child: Text(
                  body.trim(),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

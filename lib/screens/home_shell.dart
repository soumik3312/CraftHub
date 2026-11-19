import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import '../core/api_config.dart';
import '../core/craft_hub_theme.dart';
import '../providers/app_settings_controller.dart';
import '../providers/auth_controller.dart';
import '../services/local_notification_service.dart';
import '../services/realtime_sync_bus.dart';
import '../widgets/craft_hub_ui.dart';
import 'collab/collab_tab.dart';
import 'explore/explore_tab.dart';
import 'feed/feed_tab.dart';
import 'messages/chat_list_screen.dart';
import 'profile/profile_tab.dart';
import 'projects/project_create_screen.dart';
import 'posts/post_compose_screen.dart';
import 'search/search_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const Duration _chatRefreshInterval = Duration(seconds: 90);
  int _index = 0;
  int _chatBadgeCount = 0;
  Timer? _badgeTimer;
  socket_io.Socket? _socket;
  bool _promptChecked = false;
  int _notificationId = 1000;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshChatBadge();
      _connectRealtime();
      _maybeAskNotificationPermission();
      _badgeTimer = Timer.periodic(
        _chatRefreshInterval,
        (_) => _refreshChatBadge(),
      );
    });
  }

  @override
  void dispose() {
    _badgeTimer?.cancel();
    _socket?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _connectRealtime() {
    final token = context.read<AuthController>().token;
    if (token == null || token.isEmpty || _socket != null) return;

    final socket = socket_io.io(
      ApiConfig.baseUrl,
      socket_io.OptionBuilder().setTransports(['websocket']).setAuth({
        'token': token,
      }).build(),
    );

    void refresh(dynamic _) {
      _refreshChatBadge();
    }

    socket.on('sync_event', RealtimeSyncBus.emit);
    socket.on('message_notification', (raw) {
      RealtimeSyncBus.emit({'entity': 'message'});
      refresh(raw);
      _handleRealtimeNotification(raw);
    });
    socket.onDisconnect((_) {
      if (identical(_socket, socket)) {
        _socket = null;
      }
    });
    socket.onConnectError((_) {
      if (identical(_socket, socket)) {
        _socket = null;
      }
    });
    socket.connect();
    _socket = socket;
  }

  Future<void> _maybeAskNotificationPermission() async {
    if (!mounted || _promptChecked) return;
    final settings = context.read<AppSettingsController>();
    if (!settings.shouldAskNotificationPermission) {
      _promptChecked = true;
      return;
    }
    _promptChecked = true;
    final auth = context.read<AuthController>();
    final allow = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Allow notifications'),
        content: const Text(
          'Craft Hub can notify you about direct messages and workspace messages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Decline'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Allow'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (allow == true) {
      final granted = await settings.requestAndEnableNotifications(
        api: auth.api,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            granted
                ? 'Notifications enabled for Craft Hub.'
                : 'Notification permission was not granted on this device.',
          ),
        ),
      );
    } else {
      await settings.declineNotifications(api: auth.api);
    }
  }

  Future<void> _handleRealtimeNotification(dynamic raw) async {
    if (!mounted || raw is! Map) return;
    final payload = Map<String, dynamic>.from(raw);
    final settings = context.read<AppSettingsController>();
    final eventType = _eventTypeFromPayload(payload);
    if (!settings.allowsEvent(eventType)) return;
    final body = (payload['body'] as String? ?? '').trim();
    if (body.isEmpty) return;
    await LocalNotificationService.instance.show(
      id: _notificationId++,
      title: 'Craft Hub',
      body: body,
    );
  }

  String _eventTypeFromPayload(Map<String, dynamic> payload) {
    if ((payload['conversationType'] as String? ?? '') == 'group') {
      return 'workspace_message';
    }
    return 'direct_message';
  }

  Future<void> _refreshChatBadge() async {
    if (!mounted) return;
    final auth = context.read<AuthController>();
    if (auth.token == null || auth.token!.isEmpty) {
      if (_chatBadgeCount != 0 && mounted) {
        setState(() => _chatBadgeCount = 0);
      }
      return;
    }

    if (_socket == null) {
      _connectRealtime();
    }

    try {
      final conversations = await auth.api.conversations();
      final incoming = await auth.api.incomingCollab();
      final summary =
          conversations['summary'] as Map<String, dynamic>? ??
          const <String, dynamic>{};
      final unread = (summary['unreadMessages'] as num?)?.toInt() ?? 0;
      final incomingPending = (incoming['requests'] as List<dynamic>? ?? [])
          .where((r) => (r as Map<String, dynamic>)['status'] == 'pending')
          .length;
      final next = unread + incomingPending;
      if (mounted && next != _chatBadgeCount) {
        setState(() => _chatBadgeCount = next);
      }
    } catch (_) {}
  }

  Future<void> _openChats() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _StandaloneShell(
          title: 'Messages',
          child: ChatListScreen(
            onInboxChanged: _refreshChatBadge,
            onOpenCollab: () {
              Navigator.pop(context);
              _selectTab(2);
            },
          ),
        ),
      ),
    );
    _refreshChatBadge();
  }

  void _selectTab(int index) {
    if (_index != index) {
      setState(() => _index = index);
    }
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
    if (index == 2) {
      _refreshChatBadge();
    }
  }

  void _onPageChanged(int index) {
    if (_index != index && mounted) {
      setState(() => _index = index);
    }
    if (index == 2) {
      _refreshChatBadge();
    }
  }

  void _handleBackPress(bool didPop) {
    if (didPop) return;
    if (_index != 0) {
      _selectTab(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthController>();
    final palette = CraftHubPalette.of(context);

    final pages = [
      const FeedTab(),
      const ExploreTab(),
      CollabTab(onRequestsChanged: _refreshChatBadge),
      const ProfileTab(),
    ];

    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) => _handleBackPress(didPop),
      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,
        body: CraftHubBackground(
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                  child: Row(
                    children: [
                      PopupMenuButton<String>(
                        tooltip: 'Create',
                        color: palette.panel,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(color: palette.border),
                        ),
                        onSelected: (value) async {
                          if (value == 'post') {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PostComposeScreen(),
                              ),
                            );
                          } else if (value == 'project') {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ProjectCreateScreen(),
                              ),
                            );
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'post',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined),
                                SizedBox(width: 10),
                                Text('New post'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'project',
                            child: Row(
                              children: [
                                Icon(Icons.folder_open_outlined),
                                SizedBox(width: 10),
                                Text('New project'),
                              ],
                            ),
                          ),
                        ],
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: palette.panelAlt.withValues(alpha: 0.9),
                            border: Border.all(color: palette.border),
                          ),
                          child: const Icon(Icons.add_rounded, size: 20),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: CraftHubGradientText(
                          'Craft Hub',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SearchScreen(),
                          ),
                        ),
                        visualDensity: const VisualDensity(
                          horizontal: -2,
                          vertical: -2,
                        ),
                        constraints: const BoxConstraints.tightFor(
                          width: 36,
                          height: 36,
                        ),
                        icon: const Icon(Icons.search),
                      ),
                      const SizedBox(width: 2),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            onPressed: _openChats,
                            visualDensity: const VisualDensity(
                              horizontal: -2,
                              vertical: -2,
                            ),
                            constraints: const BoxConstraints.tightFor(
                              width: 36,
                              height: 36,
                            ),
                            icon: const Icon(Icons.message),
                          ),
                          if (_chatBadgeCount > 0)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                width: 9,
                                height: 9,
                                decoration: const BoxDecoration(
                                  color: CraftHubColors.lavender,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const BouncingScrollPhysics(),
                    onPageChanged: _onPageChanged,
                    children: pages,
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            decoration: BoxDecoration(
              color: palette.panel.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: palette.border.withValues(alpha: 0.95)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.24),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _pageController,
              builder: (context, _) {
                final page = _pageController.hasClients
                    ? (_pageController.page ?? _index.toDouble())
                    : _index.toDouble();
                return Row(
                  children: [
                    Expanded(
                      child: _NavItem(
                        icon: Icons.home_rounded,
                        label: 'Home',
                        selectedProgress: (1 - (page - 0).abs()).clamp(
                          0.0,
                          1.0,
                        ),
                        onTap: () => _selectTab(0),
                      ),
                    ),
                    Expanded(
                      child: _NavItem(
                        icon: Icons.folder_open_rounded,
                        label: 'Projects',
                        selectedProgress: (1 - (page - 1).abs()).clamp(
                          0.0,
                          1.0,
                        ),
                        onTap: () => _selectTab(1),
                      ),
                    ),
                    Expanded(
                      child: _NavItem(
                        icon: Icons.auto_awesome_rounded,
                        label: 'Match',
                        selectedProgress: (1 - (page - 2).abs()).clamp(
                          0.0,
                          1.0,
                        ),
                        onTap: () => _selectTab(2),
                      ),
                    ),
                    Expanded(
                      child: _NavItem(
                        icon: Icons.person_rounded,
                        label: 'Profile',
                        selectedProgress: (1 - (page - 3).abs()).clamp(
                          0.0,
                          1.0,
                        ),
                        onTap: () => _selectTab(3),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selectedProgress,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final double selectedProgress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = CraftHubPalette.of(context);
    final iconColor = Color.lerp(
      palette.muted,
      const Color(0xFF240A31),
      selectedProgress,
    )!;
    final labelColor = Color.lerp(
      palette.muted,
      CraftHubColors.lavender,
      selectedProgress,
    )!;
    final pillColor = Color.lerp(
      Colors.transparent,
      CraftHubColors.lavender.withValues(alpha: 0.1),
      selectedProgress,
    )!;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedScale(
        scale: 0.98 + (selectedProgress * 0.02),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: pillColor,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: 34 + (selectedProgress * 5),
                height: 34 + (selectedProgress * 5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: selectedProgress > 0.02
                      ? CraftHubColors.accent
                      : null,
                  color: selectedProgress > 0.02 ? null : Colors.transparent,
                  boxShadow: selectedProgress > 0.02
                      ? [
                          BoxShadow(
                            color: CraftHubColors.purple.withValues(
                              alpha: 0.16 + (selectedProgress * 0.22),
                            ),
                            blurRadius: 12 + (selectedProgress * 10),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  icon,
                  size: 17 + (selectedProgress * 1.5),
                  color: iconColor,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.visible,
                softWrap: false,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: labelColor,
                  fontWeight: selectedProgress > 0.5
                      ? FontWeight.w800
                      : FontWeight.w700,
                  fontSize: 9.5,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StandaloneShell extends StatelessWidget {
  const _StandaloneShell({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CraftHubBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    const BackButton(),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

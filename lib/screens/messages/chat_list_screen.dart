import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/craft_hub_theme.dart';
import '../../providers/auth_controller.dart';
import '../../widgets/craft_hub_ui.dart';
import '../../widgets/user_avatar.dart';
import 'chat_room_screen.dart';
import 'craftbro_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key, this.onInboxChanged, this.onOpenCollab});

  final VoidCallback? onInboxChanged;
  final VoidCallback? onOpenCollab;

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const Duration _refreshInterval = Duration(seconds: 7);
  List<dynamic> _list = [];
  int _unreadMessages = 0;
  bool _aiReady = false;
  String _aiStatusMessage = '';
  bool _loading = true;
  String _query = '';
  Timer? _refreshTimer;
  bool _refreshing = false;
  late TabController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = TabController(length: 3, vsync: this);
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
    _load();
    _refreshTimer = Timer.periodic(
      _refreshInterval,
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load(silent: true);
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    if (!silent && mounted) {
      setState(() => _loading = true);
    }
    try {
      final api = context.read<AuthController>().api;
      final results = await Future.wait<dynamic>([
        api.conversations(),
        api.aiStatus().catchError((_) => <String, dynamic>{}),
      ]);
      final data = results[0] as Map<String, dynamic>;
      final aiStatus = results[1] as Map<String, dynamic>;
      final summary = data['summary'] as Map<String, dynamic>? ?? const {};
      if (!mounted) return;
      setState(() {
        _list = data['conversations'] as List<dynamic>? ?? [];
        _unreadMessages = (summary['unreadMessages'] as num?)?.toInt() ?? 0;
        _aiReady = aiStatus['ready'] == true;
        _aiStatusMessage = (aiStatus['error'] as String? ?? '').trim();
        _loading = false;
      });
      widget.onInboxChanged?.call();
    } catch (_) {
      if (mounted && !silent) {
        setState(() => _loading = false);
      }
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _openConversation(Map<String, dynamic> conversation) async {
    final api = context.read<AuthController>().api;
    final otherUsers = (conversation['otherUsers'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final avatarUrl = otherUsers.isNotEmpty
        ? api.assetUrl(otherUsers.first['avatarUrl'] as String?)
        : '';
    final participantCount =
        ((conversation['members'] as List<dynamic>?)?.length ??
            (conversation['participants'] as List<dynamic>?)?.length ??
            otherUsers.length) +
        1;
    final isWorkspace = (conversation['type'] as String? ?? '') == 'group';

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          conversationId: conversation['id'] as String,
          title: conversation['name'] as String? ?? 'Chat',
          projectId: conversation['projectId'] as String?,
          isWorkspace: isWorkspace,
          avatarUrl: avatarUrl,
          participantCount: participantCount,
        ),
      ),
    );
    await _load();
  }

  String _formatTime(String? raw) {
    final parsed = raw == null ? null : DateTime.tryParse(raw);
    if (parsed == null) return '';
    final time = parsed.toLocal();
    final now = DateTime.now();
    if (now.year == time.year &&
        now.month == time.month &&
        now.day == time.day) {
      return DateFormat.jm().format(time);
    }
    if (now.difference(time).inDays < 7) return DateFormat.E().format(time);
    return DateFormat.MMMd().format(time);
  }

  String _preview(Map<String, dynamic> conversation) {
    final text = (conversation['lastMessageText'] as String? ?? '').trim();
    if (text.isEmpty) {
      return conversation['type'] == 'group'
          ? 'Workspace is ready to chat'
          : 'Start the conversation';
    }
    final sender = conversation['lastMessageSender'] as Map<String, dynamic>?;
    final me = context.read<AuthController>().user?['id'] as String?;
    final prefix = sender == null
        ? ''
        : sender['id'] == me
        ? 'You'
        : (sender['name'] as String? ?? '');
    return prefix.isEmpty ? text : '$prefix: $text';
  }

  List<Map<String, dynamic>> _filtered(bool workspaceOnly) {
    return _list.whereType<Map<String, dynamic>>().where((conversation) {
      final isWorkspace = (conversation['type'] as String? ?? '') == 'group';
      if (workspaceOnly != isWorkspace) return false;
      if (_query.trim().isEmpty) return true;
      final q = _query.toLowerCase();
      final name = (conversation['name'] as String? ?? '').toLowerCase();
      final preview = _preview(conversation).toLowerCase();
      return name.contains(q) || preview.contains(q);
    }).toList();
  }

  double _tabViewHeight(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height - 230;
    if (height < 380) return 380;
    return height;
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AuthController>().api;
    final direct = _filtered(false);
    final workspaces = _filtered(true);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 940),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InboxHero(
                    unreadMessages: _unreadMessages,
                    directCount: direct.length,
                    workspaceCount: workspaces.length,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        colors: [
                          CraftHubColors.panel.withValues(alpha: 0.96),
                          CraftHubColors.panelAlt.withValues(alpha: 0.92),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: CraftHubColors.border.withValues(alpha: 0.9),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.16),
                          blurRadius: 24,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search messages, people, or workspaces',
                        prefixIcon: Icon(Icons.search_rounded),
                        suffixIcon: Icon(Icons.tune_rounded),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        fillColor: Colors.transparent,
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _InboxSwitcher(
                    controller: _controller,
                    directCount: direct.length,
                    workspaceCount: workspaces.length,
                    showWorkspacePulse: _unreadMessages > 0,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: _tabViewHeight(context),
                    child: TabBarView(
                      controller: _controller,
                      children: [
                        _ConversationList(
                          conversations: direct,
                          previewBuilder: _preview,
                          timeBuilder: _formatTime,
                          onTap: _openConversation,
                          assetUrl: api.assetUrl,
                          emptyLabel: 'No direct conversations yet.',
                        ),
                        _ConversationList(
                          conversations: workspaces,
                          previewBuilder: _preview,
                          timeBuilder: _formatTime,
                          onTap: _openConversation,
                          assetUrl: api.assetUrl,
                          emptyLabel:
                              'Workspace chats will appear here when collaboration spaces are available.',
                        ),
                        _CraftBroTab(
                          aiReady: _aiReady,
                          statusMessage: _aiStatusMessage,
                          onOpen: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CraftBroScreen(),
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
        ],
      ),
    );
  }
}

class _InboxHero extends StatelessWidget {
  const _InboxHero({
    required this.unreadMessages,
    required this.directCount,
    required this.workspaceCount,
  });

  final int unreadMessages;
  final int directCount;
  final int workspaceCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            CraftHubColors.panel.withValues(alpha: 0.96),
            CraftHubColors.panelAlt.withValues(alpha: 0.92),
            CraftHubColors.cyan.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: CraftHubColors.cyan.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          CraftHubStatChip(
            label: 'Direct',
            value: '$directCount',
            icon: Icons.chat_bubble_rounded,
            highlight: true,
          ),
          CraftHubStatChip(
            label: 'Workspace',
            value: '$workspaceCount',
            icon: Icons.groups_rounded,
          ),
          CraftHubStatChip(
            label: 'Unread',
            value: '$unreadMessages',
            icon: Icons.mark_chat_unread_rounded,
          ),
        ],
      ),
    );
  }
}

class _CraftBroTab extends StatelessWidget {
  const _CraftBroTab({
    required this.aiReady,
    required this.statusMessage,
    required this.onOpen,
  });

  final bool aiReady;
  final String statusMessage;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: CraftHubPanel(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    CraftHubIconBubble(
                      icon: Icons.auto_awesome_rounded,
                      active: true,
                      size: 46,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'CraftBro',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: CraftHubColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  aiReady
                      ? 'Open the assistant chat.'
                      : (statusMessage.isEmpty
                            ? 'AI is not configured yet.'
                            : statusMessage),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: aiReady ? onOpen : null,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Open CraftBro'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationList extends StatelessWidget {
  const _ConversationList({
    required this.conversations,
    required this.previewBuilder,
    required this.timeBuilder,
    required this.onTap,
    required this.assetUrl,
    required this.emptyLabel,
  });

  final List<Map<String, dynamic>> conversations;
  final String Function(Map<String, dynamic>) previewBuilder;
  final String Function(String?) timeBuilder;
  final Future<void> Function(Map<String, dynamic>) onTap;
  final String Function(String?) assetUrl;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (conversations.isEmpty) {
      return CraftHubEmptyState(
        icon: Icons.forum_rounded,
        title: 'Nothing here yet',
        subtitle: emptyLabel,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 6),
      itemCount: conversations.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final conversation = conversations[index];
        final otherUsers = (conversation['otherUsers'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        final user = otherUsers.isNotEmpty ? otherUsers.first : null;
        final unreadCount = (conversation['unreadCount'] as num?)?.toInt() ?? 0;
        final isWorkspace = (conversation['type'] as String? ?? '') == 'group';
        return _ConversationCard(
          conversation: conversation,
          unreadCount: unreadCount,
          isWorkspace: isWorkspace,
          preview: previewBuilder(conversation),
          timeLabel: timeBuilder(conversation['lastMessageAt'] as String?),
          imageUrl: assetUrl(user?['avatarUrl'] as String?),
          onTap: () => onTap(conversation),
        );
      },
    );
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({
    required this.conversation,
    required this.unreadCount,
    required this.isWorkspace,
    required this.preview,
    required this.timeLabel,
    required this.imageUrl,
    required this.onTap,
  });

  final Map<String, dynamic> conversation;
  final int unreadCount;
  final bool isWorkspace;
  final String preview;
  final String timeLabel;
  final String imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = CraftHubPalette.of(context);
    final title = conversation['name'] as String? ?? 'Chat';
    final cleanPreview = preview.replaceAll(RegExp(r'\s+'), ' ').trim();
    final previewColor = unreadCount > 0
        ? palette.text.withValues(alpha: 0.86)
        : palette.text.withValues(alpha: 0.62);

    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: LinearGradient(
            colors: unreadCount > 0
                ? [
                    palette.panel.withValues(alpha: 0.98),
                    CraftHubColors.cyan.withValues(alpha: 0.08),
                  ]
                : [
                    palette.panel.withValues(alpha: 0.96),
                    palette.panelAlt.withValues(alpha: 0.92),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: unreadCount > 0
                ? CraftHubColors.cyan.withValues(alpha: 0.24)
                : palette.border.withValues(alpha: 0.9),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  UserAvatar(
                    imageUrl: imageUrl,
                    radius: 30,
                    borderColor: palette.border,
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 0,
                      top: 1,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: CraftHubColors.lime,
                          shape: BoxShape.circle,
                          border: Border.all(color: palette.panel, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontSize: 17,
                                    fontWeight: unreadCount > 0
                                        ? FontWeight.w900
                                        : FontWeight.w800,
                                  ),
                            ),
                          ),
                        ),
                        if (timeLabel.isNotEmpty)
                          Text(
                            timeLabel,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: unreadCount > 0
                                      ? CraftHubColors.cyan
                                      : palette.muted,
                                  fontWeight: unreadCount > 0
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 10, top: 2),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isWorkspace
                                ? CraftHubColors.lavender.withValues(
                                    alpha: 0.14,
                                  )
                                : CraftHubColors.cyan.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: isWorkspace
                                  ? CraftHubColors.lavender.withValues(
                                      alpha: 0.22,
                                    )
                                  : CraftHubColors.cyan.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            isWorkspace ? 'Workspace' : 'Direct',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: isWorkspace
                                      ? CraftHubColors.lavender
                                      : CraftHubColors.cyan,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            cleanPreview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: previewColor,
                                  fontWeight: unreadCount > 0
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  height: 1.38,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (unreadCount > 0)
                    Container(
                      constraints: const BoxConstraints(minWidth: 28),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: CraftHubColors.cyan,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(999),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: CraftHubColors.cyan.withValues(alpha: 0.24),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF0B1620),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: palette.panelAlt.withValues(alpha: 0.92),
                        border: Border.all(color: palette.border),
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: palette.muted.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InboxSwitcher extends StatelessWidget {
  const _InboxSwitcher({
    required this.controller,
    required this.directCount,
    required this.workspaceCount,
    required this.showWorkspacePulse,
  });

  final TabController controller;
  final int directCount;
  final int workspaceCount;
  final bool showWorkspacePulse;

  @override
  Widget build(BuildContext context) {
    final palette = CraftHubPalette.of(context);
    final animation =
        controller.animation ??
        AlwaysStoppedAnimation<double>(controller.index.toDouble());

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            palette.panelAlt.withValues(alpha: 0.98),
            palette.panel.withValues(alpha: 0.94),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final segmentWidth = constraints.maxWidth / 3;
            return AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                final current = animation.value.clamp(0.0, 2.0);
                return Stack(
                  children: [
                    Positioned(
                      left: current * segmentWidth,
                      top: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        child: Container(
                          width: segmentWidth,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
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
                                color: CraftHubColors.cyan.withValues(
                                  alpha: 0.16,
                                ),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _InboxSwitchButton(
                            label: 'Direct',
                            count: directCount,
                            selectedProgress: (1 - (current - 0).abs()).clamp(
                              0.0,
                              1.0,
                            ),
                            onTap: () => controller.animateTo(0),
                          ),
                        ),
                        Expanded(
                          child: _InboxSwitchButton(
                            label: 'Workspaces',
                            count: workspaceCount,
                            selectedProgress: (1 - (current - 1).abs()).clamp(
                              0.0,
                              1.0,
                            ),
                            showPulse: showWorkspacePulse,
                            onTap: () => controller.animateTo(1),
                          ),
                        ),
                        Expanded(
                          child: _InboxSwitchButton(
                            label: 'CraftBro',
                            selectedProgress: (1 - (current - 2).abs()).clamp(
                              0.0,
                              1.0,
                            ),
                            onTap: () => controller.animateTo(2),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _InboxSwitchButton extends StatelessWidget {
  const _InboxSwitchButton({
    required this.label,
    required this.selectedProgress,
    required this.onTap,
    this.count = 0,
    this.showPulse = false,
  });

  final String label;
  final double selectedProgress;
  final VoidCallback onTap;
  final int count;
  final bool showPulse;

  @override
  Widget build(BuildContext context) {
    final palette = CraftHubPalette.of(context);
    final labelColor = Color.lerp(
      palette.muted,
      const Color(0xFF081823),
      selectedProgress,
    )!;
    final badgeColor = Color.lerp(
      palette.panel.withValues(alpha: 0.95),
      Colors.white.withValues(alpha: 0.92),
      selectedProgress,
    )!;
    final badgeTextColor = Color.lerp(
      palette.text,
      const Color(0xFF08202A),
      selectedProgress,
    )!;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedScale(
        scale: 0.985 + (selectedProgress * 0.015),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: labelColor,
                    fontWeight: selectedProgress > 0.55
                        ? FontWeight.w800
                        : FontWeight.w700,
                  ),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 7),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: badgeTextColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ] else if (showPulse) ...[
                const SizedBox(width: 8),
                AnimatedScale(
                  scale: 0.92 + (selectedProgress * 0.14),
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: CraftHubColors.lime,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

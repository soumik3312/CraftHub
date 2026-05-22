import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_config.dart';
import '../../core/craft_hub_theme.dart';
import '../../providers/auth_controller.dart';
import '../../widgets/craft_hub_ui.dart';
import '../../widgets/user_avatar.dart';
import '../projects/github_workspace_screen.dart';

class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({
    super.key,
    required this.conversationId,
    required this.title,
    this.projectId,
    this.isWorkspace = false,
    this.avatarUrl,
    this.participantCount = 0,
  });

  final String conversationId;
  final String title;
  final String? projectId;
  final bool isWorkspace;
  final String? avatarUrl;
  final int participantCount;

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen>
    with WidgetsBindingObserver {
  static const Duration _refreshInterval = Duration(seconds: 7);
  final _text = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _msgs = [];
  socket_io.Socket? _socket;
  Map<String, dynamic>? _replyTarget;
  String _workspaceRepoUrl = '';
  String _workspaceEditorUrl = '';
  bool _loading = true;
  Timer? _refreshTimer;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
    _refreshTimer = Timer.periodic(
      _refreshInterval,
      (_) => _refreshMessages(silent: true),
    );
  }

  Future<void> _bootstrap() async {
    final auth = context.read<AuthController>();
    final token = auth.token;
    try {
      await _refreshMessages();
      if (!mounted) return;
      _scrollBottom();

      if (token == null) return;
      final s = socket_io.io(
        ApiConfig.baseUrl,
        socket_io.OptionBuilder().setTransports(['websocket']).setAuth({
          'token': token,
        }).build(),
      );
      _socket = s;
      s.connect();
      s.onConnect((_) {
        s.emit('join', widget.conversationId);
      });
      s.on('message', (raw) {
        if (raw is Map) {
          final m = Map<String, dynamic>.from(raw);
          if (m['conversationId'] == widget.conversationId && mounted) {
            final index = _msgs.indexWhere((entry) => entry['id'] == m['id']);
            setState(() {
              if (index == -1) {
                _msgs.add(m);
              } else {
                _msgs[index] = m;
              }
            });
            _scrollBottom();
          }
        }
      });
      s.on('message_reaction', (raw) {
        if (raw is Map && mounted) {
          final m = Map<String, dynamic>.from(raw);
          if (m['conversationId'] == widget.conversationId) {
            final idx = _msgs.indexWhere((x) => x['id'] == m['id']);
            if (idx != -1) {
              setState(() => _msgs[idx] = m);
            }
          }
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshMessages(silent: true);
    }
  }

  Future<void> _refreshMessages({bool silent = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    if (!silent && mounted) {
      setState(() => _loading = true);
    }
    try {
      final api = context.read<AuthController>().api;
      final results = await Future.wait<dynamic>([
        api.messages(widget.conversationId),
        if (widget.projectId != null) api.project(widget.projectId!),
      ]);
      final data = results.first as Map<String, dynamic>;
      final project = results.length > 1
          ? results[1] as Map<String, dynamic>
          : null;
      final projectData = project == null
          ? null
          : project['project'] as Map<String, dynamic>?;
      final workspace = projectData == null
          ? null
          : projectData['workspace'] as Map<String, dynamic>?;
      if (!mounted) return;
      final nextMessages = (data['messages'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final shouldScroll = nextMessages.length > _msgs.length || _loading;
      setState(() {
        _msgs = nextMessages;
        _workspaceRepoUrl = (workspace?['repoUrl'] as String? ?? '').trim();
        _workspaceEditorUrl = (workspace?['editorUrl'] as String? ?? '').trim();
        _loading = false;
      });
      if (shouldScroll) {
        _scrollBottom();
      }
    } catch (_) {
      if (mounted && !silent) {
        setState(() => _loading = false);
      }
    } finally {
      _refreshing = false;
    }
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _socket?.emit('leave', widget.conversationId);
    _socket?.dispose();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    _text.clear();
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthController>();
    try {
      await auth.api.sendMessage(
        widget.conversationId,
        t,
        replyToMessageId: _replyTarget?['id'] as String?,
      );
      _replyTarget = null;
      await _refreshMessages(silent: true);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _openWorkspace() async {
    final token = context.read<AuthController>().token;
    if (_workspaceRepoUrl.isEmpty ||
        !mounted ||
        widget.projectId == null ||
        token == null ||
        token.isEmpty) {
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GitHubWorkspaceScreen(
          title: '${widget.title} IDE',
          projectId: widget.projectId!,
          repoUrl: _workspaceRepoUrl,
          apiBaseUrl: ApiConfig.baseUrl,
          authToken: token,
        ),
      ),
    );
  }

  Future<void> _openRepo() async {
    final uri = Uri.tryParse(_workspaceRepoUrl);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the GitHub repository.')),
      );
    }
  }

  String _subtitle() {
    if (widget.isWorkspace) {
      final count = math.max(widget.participantCount, 2);
      return '$count active contributors';
    }
    return 'online';
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthController>().user?['id'] as String?;
    final palette = CraftHubPalette.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CraftHubBackground(
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                children: [
                  _RoomHeader(
                    title: widget.title,
                    subtitle: _subtitle(),
                    avatarUrl: widget.avatarUrl,
                    isWorkspace: widget.isWorkspace,
                    onOpenWorkspace: _workspaceEditorUrl.isNotEmpty
                        ? _openWorkspace
                        : null,
                    onOpenRepo: _workspaceRepoUrl.isNotEmpty ? _openRepo : null,
                  ),
                  if (widget.isWorkspace &&
                      (_workspaceEditorUrl.isNotEmpty ||
                          _workspaceRepoUrl.isNotEmpty))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              if (_workspaceEditorUrl.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: _WorkspaceActionChip(
                                    label: 'Run Workspace',
                                    icon: Icons.terminal_rounded,
                                    onTap: _openWorkspace,
                                  ),
                                ),
                              if (_workspaceRepoUrl.isNotEmpty)
                                _WorkspaceActionChip(
                                  label: 'Open Repo',
                                  icon: Icons.open_in_new_rounded,
                                  onTap: _openRepo,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: LinearGradient(
                          colors: [
                            palette.panel.withValues(alpha: 0.76),
                            palette.panelAlt.withValues(alpha: 0.58),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: palette.border.withValues(alpha: 0.9),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 28,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: Stack(
                          children: [
                            Positioned(
                              top: -50,
                              right: -60,
                              child: Container(
                                width: 180,
                                height: 180,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      CraftHubColors.cyan.withValues(
                                        alpha: 0.18,
                                      ),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (_loading)
                              const Center(child: CircularProgressIndicator())
                            else
                              ListView.builder(
                                controller: _scroll,
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  18,
                                  16,
                                  24,
                                ),
                                itemCount: _msgs.length,
                                itemBuilder: (ctx, i) {
                                  final m = _msgs[i];
                                  final sender =
                                      m['sender'] as Map<String, dynamic>? ??
                                      {};
                                  final mine = sender['id'] == me;
                                  final replyTo =
                                      m['replyTo'] as Map<String, dynamic>?;
                                  final reactions =
                                      (m['reactions'] as List<dynamic>? ?? [])
                                          .whereType<Map<String, dynamic>>()
                                          .toList();
                                  final currentTime = DateTime.tryParse(
                                    m['createdAt'] as String? ?? '',
                                  )?.toLocal();
                                  final previousTime = i == 0
                                      ? null
                                      : DateTime.tryParse(
                                          _msgs[i - 1]['createdAt']
                                                  as String? ??
                                              '',
                                        )?.toLocal();
                                  final showDateChip =
                                      i == 0 ||
                                      !_isSameDay(currentTime, previousTime);

                                  return Column(
                                    children: [
                                      if (showDateChip)
                                        _TimelineDateChip(
                                          label: _formatTimelineDate(
                                            currentTime,
                                          ),
                                        ),
                                      Dismissible(
                                        key: ValueKey('msg-${m['id']}'),
                                        direction: mine
                                            ? DismissDirection.endToStart
                                            : DismissDirection.startToEnd,
                                        movementDuration: const Duration(
                                          milliseconds: 160,
                                        ),
                                        resizeDuration: null,
                                        dismissThresholds: const {
                                          DismissDirection.startToEnd: 0.25,
                                          DismissDirection.endToStart: 0.25,
                                        },
                                        background: Container(
                                          margin: const EdgeInsets.symmetric(
                                            vertical: 6,
                                          ),
                                          alignment: mine
                                              ? Alignment.centerRight
                                              : Alignment.centerLeft,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                          ),
                                          child: Icon(
                                            Icons.reply_rounded,
                                            color: CraftHubColors.cyan
                                                .withValues(alpha: 0.9),
                                          ),
                                        ),
                                        confirmDismiss: (_) async {
                                          setState(() => _replyTarget = m);
                                          return false;
                                        },
                                        child: _MessageRow(
                                          mine: mine,
                                          isWorkspace: widget.isWorkspace,
                                          senderName:
                                              sender['name'] as String? ?? '',
                                          senderAvatar: context
                                              .read<AuthController>()
                                              .api
                                              .assetUrl(
                                                sender['avatarUrl'] as String?,
                                              ),
                                          text: m['text'] as String? ?? '',
                                          timeLabel: _formatMessageTime(
                                            m['createdAt'] as String?,
                                          ),
                                          replyTo: replyTo,
                                          reactions: reactions,
                                          onLongPress: () => _pickReaction(m),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _ComposerBar(
                    controller: _text,
                    replyTarget: _replyTarget,
                    isWorkspace: widget.isWorkspace,
                    onClearReply: () => setState(() => _replyTarget = null),
                    onSend: _send,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatMessageTime(String? raw) {
    final parsed = raw == null ? null : DateTime.tryParse(raw);
    if (parsed == null) return '';
    return DateFormat('h:mm a').format(parsed.toLocal());
  }

  bool _isSameDay(DateTime? left, DateTime? right) {
    if (left == null || right == null) return false;
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  String _formatTimelineDate(DateTime? value) {
    if (value == null) return 'Conversation';
    final today = DateTime.now();
    final date = DateTime(value.year, value.month, value.day);
    final current = DateTime(today.year, today.month, today.day);
    final difference = current.difference(date).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference < 7) return DateFormat.EEEE().format(value);
    return DateFormat('MMM d, yyyy').format(value);
  }

  Future<void> _pickReaction(Map<String, dynamic> message) async {
    const emojis = [
      '\u{1F44D}',
      '\u{2764}\u{FE0F}',
      '\u{1F525}',
      '\u{1F602}',
      '\u{1F44F}',
      '\u{1F389}',
    ];
    final pick = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: CraftHubColors.panel,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: emojis
              .map(
                (e) => ListTile(
                  title: Text(e, style: const TextStyle(fontSize: 22)),
                  onTap: () => Navigator.pop(ctx, e),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (pick == null || !mounted) return;
    try {
      final data = await context.read<AuthController>().api.reactToMessage(
        widget.conversationId,
        message['id'] as String,
        pick,
      );
      final updated = data['message'] as Map<String, dynamic>?;
      if (updated != null) {
        final idx = _msgs.indexWhere((x) => x['id'] == updated['id']);
        if (idx != -1) {
          setState(() => _msgs[idx] = updated);
        }
      }
    } catch (_) {}
  }
}

class _RoomHeader extends StatelessWidget {
  const _RoomHeader({
    required this.title,
    required this.subtitle,
    required this.isWorkspace,
    this.avatarUrl,
    this.onOpenWorkspace,
    this.onOpenRepo,
  });

  final String title;
  final String subtitle;
  final String? avatarUrl;
  final bool isWorkspace;
  final VoidCallback? onOpenWorkspace;
  final VoidCallback? onOpenRepo;

  @override
  Widget build(BuildContext context) {
    final palette = CraftHubPalette.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            palette.panel.withValues(alpha: 0.98),
            palette.panelAlt.withValues(alpha: 0.94),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          _HeaderActionButton(
            onPressed: () => Navigator.pop(context),
            icon: Icons.arrow_back_rounded,
          ),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.panelAlt.withValues(alpha: 0.96),
              border: Border.all(color: palette.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: isWorkspace
                ? const Icon(Icons.groups_rounded, color: CraftHubColors.cyan)
                : UserAvatar(
                    imageUrl: avatarUrl,
                    radius: 22,
                    borderColor: palette.border,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontSize: 19),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isWorkspace
                            ? CraftHubColors.cyan
                            : CraftHubColors.lime,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        subtitle,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isWorkspace
                              ? CraftHubColors.cyan
                              : palette.muted,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onOpenWorkspace != null)
            _HeaderActionButton(
              onPressed: onOpenWorkspace!,
              icon: Icons.computer_rounded,
            ),
          if (onOpenRepo != null)
            _HeaderActionButton(
              onPressed: onOpenRepo!,
              icon: Icons.open_in_new_rounded,
            ),
        ],
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({required this.onPressed, required this.icon});

  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = CraftHubPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: palette.panelAlt.withValues(alpha: 0.96),
            border: Border.all(color: palette.border),
          ),
          child: Icon(icon, color: palette.text, size: 20),
        ),
      ),
    );
  }
}

class _WorkspaceActionChip extends StatelessWidget {
  const _WorkspaceActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = CraftHubPalette.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: LinearGradient(
            colors: [
              palette.panelAlt.withValues(alpha: 0.98),
              palette.panel.withValues(alpha: 0.92),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: CraftHubColors.cyan.withValues(alpha: 0.14),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: CraftHubColors.cyan),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: palette.text),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.mine,
    required this.isWorkspace,
    required this.senderName,
    required this.senderAvatar,
    required this.text,
    required this.timeLabel,
    required this.reactions,
    this.replyTo,
    this.onLongPress,
  });

  final bool mine;
  final bool isWorkspace;
  final String senderName;
  final String senderAvatar;
  final String text;
  final String timeLabel;
  final List<Map<String, dynamic>> reactions;
  final Map<String, dynamic>? replyTo;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final palette = CraftHubPalette.of(context);
    final showAvatar = isWorkspace && !mine;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bubbleMaxWidth = math.min(constraints.maxWidth * 0.8, 560.0);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: mine
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (showAvatar) ...[
                UserAvatar(
                  imageUrl: senderAvatar,
                  radius: 16,
                  borderColor: palette.border,
                ),
                const SizedBox(width: 10),
              ] else if (!mine)
                const SizedBox(width: 26),
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
                  child: GestureDetector(
                    onLongPress: onLongPress,
                    child: Column(
                      crossAxisAlignment: mine
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        if (isWorkspace && !mine)
                          Padding(
                            padding: const EdgeInsets.only(left: 8, bottom: 6),
                            child: Text(
                              senderName,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: CraftHubColors.cyan,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                  ),
                            ),
                          ),
                        _MessageBubble(
                          mine: mine,
                          text: text,
                          replyTo: replyTo,
                          timeLabel: timeLabel,
                        ),
                        if (reactions.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(
                              top: 8,
                              left: mine ? 0 : 10,
                              right: mine ? 10 : 0,
                            ),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: reactions
                                  .map(
                                    (r) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        color: palette.panelAlt.withValues(
                                          alpha: 0.96,
                                        ),
                                        border: Border.all(
                                          color: palette.border,
                                        ),
                                      ),
                                      child: Text(
                                        r['emoji'] as String? ?? '',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.mine,
    required this.text,
    required this.timeLabel,
    this.replyTo,
  });

  final bool mine;
  final String text;
  final String timeLabel;
  final Map<String, dynamic>? replyTo;

  bool get _looksLikeCode {
    final trimmed = text.trim();
    return trimmed.contains('```') ||
        (trimmed.contains('\n') &&
            (trimmed.contains('{') ||
                trimmed.contains('class ') ||
                trimmed.contains('const ') ||
                trimmed.contains('return ') ||
                trimmed.contains(';')));
  }

  @override
  Widget build(BuildContext context) {
    final palette = CraftHubPalette.of(context);
    final incomingColor = palette.panel.withValues(alpha: 0.96);
    final mineTextColor = Colors.white;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(24),
          topRight: const Radius.circular(24),
          bottomLeft: Radius.circular(mine ? 24 : 10),
          bottomRight: Radius.circular(mine ? 10 : 24),
        ),
        gradient: mine
            ? const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: mine ? null : incomingColor,
        border: Border.all(
          color: mine
              ? const Color(0xFF4E8DFF).withValues(alpha: 0.85)
              : palette.border,
        ),
        boxShadow: [
          BoxShadow(
            color: mine
                ? const Color(0xFF2563EB).withValues(alpha: 0.18)
                : Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (replyTo != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: mine
                    ? Colors.white.withValues(alpha: 0.12)
                    : palette.bgSoft.withValues(alpha: 0.6),
                border: Border.all(
                  color: mine
                      ? Colors.white.withValues(alpha: 0.16)
                      : palette.border.withValues(alpha: 0.85),
                ),
              ),
              child: Text(
                '${((replyTo!['sender'] as Map?)?['name'] ?? 'Reply')}: ${replyTo!['text'] ?? ''}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: mine
                      ? Colors.white.withValues(alpha: 0.82)
                      : palette.text.withValues(alpha: 0.78),
                ),
              ),
            ),
          if (_looksLikeCode)
            _CodePreview(text: text)
          else
            Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 15,
                height: 1.46,
                color: mine
                    ? mineTextColor
                    : palette.text.withValues(alpha: 0.94),
              ),
            ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              timeLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: mine
                    ? Colors.white.withValues(alpha: 0.78)
                    : palette.text.withValues(alpha: 0.5),
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodePreview extends StatelessWidget {
  const _CodePreview({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cleaned = text.replaceAll('```', '').trim();
    final palette = CraftHubPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: palette.bgSoft.withValues(alpha: 0.92),
        border: Border.all(color: palette.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(
          cleaned,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12.5,
            height: 1.45,
            color: palette.text,
          ),
        ),
      ),
    );
  }
}

class _ComposerBar extends StatelessWidget {
  const _ComposerBar({
    required this.controller,
    required this.replyTarget,
    required this.isWorkspace,
    required this.onClearReply,
    required this.onSend,
  });

  final TextEditingController controller;
  final Map<String, dynamic>? replyTarget;
  final bool isWorkspace;
  final VoidCallback onClearReply;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final palette = CraftHubPalette.of(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              colors: [
                palette.panel.withValues(alpha: 0.98),
                palette.panelAlt.withValues(alpha: 0.94),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: palette.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 26,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (replyTarget != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: palette.panelAlt.withValues(alpha: 0.94),
                    border: Border.all(
                      color: CraftHubColors.cyan.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 30,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: CraftHubColors.cyan,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Replying to ${replyTarget!['text'] ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      IconButton(
                        onPressed: onClearReply,
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ],
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isWorkspace)
                    Padding(
                      padding: const EdgeInsets.only(right: 8, bottom: 2),
                      child: _ComposerIconButton(
                        icon: Icons.add_rounded,
                        onTap: () {},
                      ),
                    ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        color: palette.panelAlt.withValues(alpha: 0.96),
                        border: Border.all(color: palette.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (isWorkspace)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 12,
                                bottom: 13,
                              ),
                              child: Icon(
                                Icons.alternate_email_rounded,
                                size: 18,
                                color: palette.muted,
                              ),
                            ),
                          Expanded(
                            child: TextField(
                              controller: controller,
                              minLines: 1,
                              maxLines: 5,
                              decoration: InputDecoration(
                                hintText: isWorkspace
                                    ? 'Message the team or mention someone with @'
                                    : 'Write a message...',
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                fillColor: Colors.transparent,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: isWorkspace ? 10 : 16,
                                  vertical: 15,
                                ),
                              ),
                              onSubmitted: (_) => onSend(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    margin: const EdgeInsets.only(bottom: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF2563EB,
                          ).withValues(alpha: 0.28),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: onSend,
                      icon: const Icon(Icons.arrow_upward_rounded),
                      color: Colors.white,
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

class _TimelineDateChip extends StatelessWidget {
  const _TimelineDateChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = CraftHubPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: palette.panelAlt.withValues(alpha: 0.9),
            border: Border.all(color: palette.border),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: palette.text.withValues(alpha: 0.72),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = CraftHubPalette.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Ink(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: palette.panelAlt,
          border: Border.all(color: palette.border),
        ),
        child: Icon(icon, color: palette.text, size: 18),
      ),
    );
  }
}

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/craft_hub_theme.dart';
import '../../core/project_tech_stack.dart';
import '../../providers/auth_controller.dart';
import '../../services/realtime_sync_bus.dart';
import '../../widgets/craft_hub_ui.dart';
import '../projects/project_detail_screen.dart';

class ExploreTab extends StatefulWidget {
  const ExploreTab({super.key});

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  final List<Map<String, dynamic>> _items = [];
  final PageController _controller = PageController();
  String? _cursor;
  bool _loading = true;
  bool _loadingMore = false;
  StreamSubscription<Map<String, dynamic>>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _fetch();
    _syncSubscription = RealtimeSyncBus.events.listen((event) {
      if (event['entity'] == 'project' || event['entity'] == 'workspace') {
        _fetch();
      }
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String _text(dynamic value, [String fallback = '']) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return <String, dynamic>{};
  }

  String _compactCount(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return '$value';
  }

  String _relativeTime(String raw) {
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _fetch({bool append = false}) async {
    final api = context.read<AuthController>().api;
    if (!append) {
      setState(() => _loading = true);
    } else {
      if (_loadingMore) return;
      _loadingMore = true;
    }
    try {
      final data = await api.explore(cursor: append ? _cursor : null);
      final list = (data['projects'] as List<dynamic>? ?? [])
          .map(_map)
          .where((entry) => entry.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        if (!append) _items.clear();
        _items.addAll(list);
        _cursor = data['nextCursor'] as String?;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    } finally {
      _loadingMore = false;
    }
  }

  void _patchProject(String projectId, Map<String, dynamic> patch) {
    final index = _items.indexWhere((item) => _text(item['id']) == projectId);
    if (index == -1 || !mounted) return;
    final next = Map<String, dynamic>.from(_items[index])..addAll(patch);
    setState(() => _items[index] = next);
  }

  Future<void> _openProject(String projectId) async {
    if (projectId.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectDetailScreen(projectId: projectId),
      ),
    );
    await _fetch();
  }

  Future<void> _toggleLike(Map<String, dynamic> project) async {
    final projectId = _text(project['id']);
    if (projectId.isEmpty) return;
    final api = context.read<AuthController>().api;
    final liked = project['likedByMe'] == true;
    try {
      final data = liked
          ? await api.unlikeProject(projectId)
          : await api.likeProject(projectId);
      _patchProject(projectId, {
        'likedByMe': data['likedByMe'] == true,
        'likeCount': (data['likeCount'] as num?)?.toInt() ?? 0,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(api.friendlyError(e))),
      );
    }
  }

  Future<void> _requestJoin(Map<String, dynamic> project) async {
    final api = context.read<AuthController>().api;
    final owner = _map(project['owner']);
    final ownerId = _text(owner['id']);
    final projectId = _text(project['id']);
    final title = _text(project['title'], 'this project');
    if (ownerId.isEmpty || projectId.isEmpty) return;
    try {
      await api.sendCollabRequest(
        toUserId: ownerId,
        type: 'project_request',
        projectId: projectId,
        message: 'I would like to collaborate on "$title".',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project join request sent.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(api.friendlyError(e))),
      );
    }
  }

  Future<void> _openComments(Map<String, dynamic> project) async {
    final api = context.read<AuthController>().api;
    final projectId = _text(project['id']);
    if (projectId.isEmpty) return;

    final data = await api.projectComments(projectId).catchError((_) => <String, dynamic>{});
    final initialComments = (data['comments'] as List<dynamic>? ?? [])
        .map(_map)
        .where((entry) => entry.isNotEmpty)
        .toList();
    final controller = TextEditingController();
    var comments = initialComments;
    var sending = false;

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            top: 12,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 12,
          ),
          child: CraftHubPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Project Comments',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 260,
                  child: comments.isEmpty
                      ? const Center(
                          child: Text('No comments yet. Start the conversation.'),
                        )
                      : ListView.separated(
                          itemCount: comments.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final comment = comments[index];
                            final user = _map(comment['user']);
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: CraftHubPalette.of(ctx)
                                      .panelAlt,
                                  child: Text(
                                    _text(user['name'], 'U').substring(0, 1).toUpperCase(),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _text(user['name'], _text(user['username'], 'User')),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: CraftHubPalette.of(ctx).text,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(_text(comment['text'])),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Write a comment...',
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: sending
                      ? null
                      : () async {
                          final text = controller.text.trim();
                          if (text.isEmpty) return;
                          setSheet(() => sending = true);
                          try {
                            final res = await api.commentProject(projectId, text);
                            final comment = _map(res['comment']);
                            final nextCount = (res['commentCount'] as num?)?.toInt() ?? (comments.length + 1);
                            if (comment.isNotEmpty) {
                              setSheet(() {
                                comments = [comment, ...comments];
                                controller.clear();
                              });
                            }
                            _patchProject(projectId, {'commentCount': nextCount});
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text(api.friendlyError(e))),
                              );
                            }
                          } finally {
                            if (ctx.mounted) setSheet(() => sending = false);
                          }
                        },
                  child: Text(sending ? 'Sending...' : 'Post comment'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    controller.dispose();
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    Color? iconColor,
  }) {
    final palette = CraftHubPalette.of(context);
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.panel.withValues(alpha: 0.82),
              border: Border.all(color: palette.border),
            ),
            child: Icon(icon, color: iconColor ?? palette.text, size: 28),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: 72,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.text,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _techPill(ProjectTechOption tech) {
    final palette = CraftHubPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: palette.panel.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tech.icon, size: 18, color: tech.color),
          const SizedBox(width: 8),
          Text(
            tech.label.toUpperCase(),
            style: TextStyle(
              color: palette.text,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final me = _text(auth.user?['id']);
    final palette = CraftHubPalette.of(context);
    final navLift = MediaQuery.paddingOf(context).bottom + 14;

    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return PageView.builder(
      controller: _controller,
      scrollDirection: Axis.vertical,
      itemCount: _items.length,
      onPageChanged: (index) {
        if (_cursor != null && index >= _items.length - 2) {
          _fetch(append: true);
        }
      },
      itemBuilder: (context, index) {
        final project = _items[index];
        final owner = _map(project['owner']);
        final images = (project['imageUrls'] as List<dynamic>? ?? [])
            .map((entry) => entry.toString())
            .where((entry) => entry.trim().isNotEmpty)
            .toList();
        final cover = images.isEmpty ? '' : images.first;
        final projectId = _text(project['id']);
        final title = _text(project['title'], 'Project');
        final description = _text(project['description']);
        final techStack = projectTechForIds(project['techStack'] as List? ?? const []);
        final fallbackGenres = (project['genres'] as List<dynamic>? ?? [])
            .map((entry) => '$entry')
            .take(3)
            .toList();
        final isOwner = _text(owner['id']) == me;
        final isCollaborator = ((project['collaborators'] as List<dynamic>? ?? const [])
            .map(_map)
            .any((user) => _text(user['id']) == me));
        final likeCount = (project['likeCount'] as num?)?.toInt() ?? 0;
        final commentCount = (project['commentCount'] as num?)?.toInt() ?? 0;
        final likedByMe = project['likedByMe'] == true;
        final activityTime = _relativeTime(_text(project['updatedAt'], _text(project['createdAt'])));
        final detailChips = <Widget>[
          ...techStack.take(3).map(_techPill),
          ...fallbackGenres.take(3).map((genre) => CraftHubTag(label: genre)),
        ];

        return Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _openProject(projectId),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (cover.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: cover,
                        fit: BoxFit.cover,
                      )
                    else
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF101828), Color(0xFF110E18)],
                          ),
                        ),
                      ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.86),
                            Colors.black.withValues(alpha: 0.18),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(18, 18, 18, 26 + navLift),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Spacer(),
                          if (activityTime.isNotEmpty)
                            Text(
                              activityTime,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: palette.text.withValues(alpha: 0.78),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: MediaQuery.sizeOf(context).width * 0.7,
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                    color: palette.text,
                                    fontSize: 36,
                                    height: 1.05,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: MediaQuery.sizeOf(context).width * 0.68,
                            child: Text(
                              description.isEmpty
                                  ? 'Open this project to explore the full collaboration details.'
                                  : description,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: palette.text.withValues(alpha: 0.78),
                                    fontSize: 18,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: detailChips,
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 92 + navLift,
                      child: Column(
                        children: [
                          _actionButton(
                            icon: likedByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            iconColor: likedByMe ? CraftHubColors.lavender : palette.text,
                            label: _compactCount(likeCount),
                            onTap: () => _toggleLike(project),
                          ),
                          const SizedBox(height: 18),
                          _actionButton(
                            icon: Icons.mode_comment_outlined,
                            label: _compactCount(commentCount),
                            onTap: () => _openComments(project),
                          ),
                          const SizedBox(height: 18),
                          _actionButton(
                            icon: Icons.group_add_outlined,
                            label: isOwner || isCollaborator ? 'TEAM' : 'JOIN',
                            onTap: isOwner || isCollaborator
                                ? () => _openProject(projectId)
                                : () => _requestJoin(project),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

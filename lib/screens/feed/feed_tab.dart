import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/craft_hub_theme.dart';
import '../../providers/auth_controller.dart';
import '../../services/craft_api.dart';
import '../../services/realtime_sync_bus.dart';
import '../../widgets/user_avatar.dart';
import '../profile/user_profile_screen.dart';

class FeedTab extends StatefulWidget {
  const FeedTab({super.key});

  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> {
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _suggestions = [];
  bool _loading = true;
  Timer? _feedRefreshTimer;
  StreamSubscription<Map<String, dynamic>>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _load();
    _syncSubscription = RealtimeSyncBus.events.listen((event) {
      if (event['entity'] == 'post' || event['entity'] == 'follow') {
        _refreshFeed();
      }
    });
    // Slow recovery check for missed events after a temporary disconnect.
    _feedRefreshTimer = Timer.periodic(
      const Duration(seconds: 90),
      (_) => _refreshFeed(),
    );
  }

  @override
  void dispose() {
    _feedRefreshTimer?.cancel();
    _syncSubscription?.cancel();
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

  String _relativeTime(String raw) {
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  String _compactCount(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return '$value';
  }

  Future<void> _load() async {
    final api = context.read<AuthController>().api;
    setState(() => _loading = true);
    try {
      final results = await Future.wait<dynamic>([
        api.feedPosts(),
        api.userSuggestions().catchError((_) => <String, dynamic>{}),
      ]);
      final data = results[0] as Map<String, dynamic>;
      final suggestionsData = results[1] as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _posts = (data['posts'] as List<dynamic>? ?? [])
            .map(_map)
            .where((entry) => entry.isNotEmpty)
            .toList();
        _suggestions = (suggestionsData['users'] as List<dynamic>? ?? [])
            .map(_map)
            .where((entry) => entry.isNotEmpty)
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _refreshFeed() async {
    if (!mounted) return;
    try {
      final data = await context.read<AuthController>().api.feedPosts();
      if (!mounted) return;
      setState(() {
        _posts = (data['posts'] as List<dynamic>? ?? [])
            .map(_map)
            .where((entry) => entry.isNotEmpty)
            .toList();
      });
    } catch (_) {
      // Keep the current feed visible if the background refresh fails.
    }
  }

  void _patchPost(String postId, Map<String, dynamic> patch) {
    final index = _posts.indexWhere((post) => _text(post['id']) == postId);
    if (index == -1 || !mounted) return;
    final next = Map<String, dynamic>.from(_posts[index])..addAll(patch);
    setState(() => _posts[index] = next);
  }

  void _patchPostsByAuthor(String authorId, Map<String, dynamic> patch) {
    if (authorId.isEmpty || !mounted) return;
    setState(() {
      _posts = _posts.map((post) {
        final author = _map(post['author']);
        if (_text(author['id']) != authorId) return post;
        final next = Map<String, dynamic>.from(post)..addAll(patch);
        return next;
      }).toList();
    });
  }

  void _removeSuggestion(String userId) {
    if (userId.isEmpty || !mounted) return;
    setState(() {
      _suggestions.removeWhere((user) => _text(user['id']) == userId);
    });
  }

  Future<void> _toggleLike(CraftApi api, Map<String, dynamic> post) async {
    final id = _text(post['id']);
    final liked = post['likedByMe'] == true;
    final current = (post['likeCount'] as num?)?.toInt() ?? 0;
    _patchPost(id, {
      'likedByMe': !liked,
      'likeCount': liked ? (current > 0 ? current - 1 : 0) : current + 1,
    });
    try {
      if (liked) {
        await api.unlikePost(id);
      } else {
        await api.likePost(id);
      }
    } catch (e) {
      _patchPost(id, {'likedByMe': liked, 'likeCount': current});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(api.friendlyError(e))),
      );
    }
  }

  Future<void> _toggleFollow(
    CraftApi api,
    Map<String, dynamic> post,
    String me,
  ) async {
    final author = _map(post['author']);
    final uid = _text(author['id']);
    if (uid.isEmpty || uid == me) return;
    final followed = post['authorFollowedByMe'] == true;
    _patchPostsByAuthor(uid, {'authorFollowedByMe': !followed});
    try {
      if (followed) {
        await api.unfollow(uid);
      } else {
        await api.follow(uid);
        _removeSuggestion(uid);
      }
    } catch (e) {
      _patchPostsByAuthor(uid, {'authorFollowedByMe': followed});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(api.friendlyError(e))),
      );
    }
  }

  Future<void> _sharePost(CraftApi api, Map<String, dynamic> post) async {
    final id = _text(post['id']);
    final current = (post['sharesCount'] as num?)?.toInt() ?? 0;
    _patchPost(id, {'sharesCount': current + 1});
    try {
      await api.sharePost(id);
      await Share.share(
        _text(post['text'], 'Check this out on Craft Hub'),
      );
    } catch (e) {
      _patchPost(id, {'sharesCount': current});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(api.friendlyError(e))),
      );
    }
  }

  Future<void> _deletePost(CraftApi api, Map<String, dynamic> post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text(
          'This post will be permanently removed from your feed and profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final id = _text(post['id']);
    try {
      await api.deletePost(id);
      if (!mounted) return;
      setState(() {
        _posts.removeWhere((entry) => _text(entry['id']) == id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post deleted.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(api.friendlyError(e))),
      );
    }
  }

  Future<void> _openComments(CraftApi api, Map<String, dynamic> post) async {
    final postId = _text(post['id']);
    final data = await api.postComments(postId).catchError((_) => <String, dynamic>{});
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
          child: Container(
            decoration: BoxDecoration(
              color: CraftHubPalette.of(ctx).panel,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: CraftHubPalette.of(ctx).border),
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Comments',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 280,
                  child: comments.isEmpty
                      ? const Center(
                          child: Text('No comments yet. Start the conversation.'),
                        )
                      : ListView.separated(
                          itemCount: comments.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final comment = comments[index];
                            final author = _map(comment['author']);
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                UserAvatar(
                                  imageUrl: api.assetUrl(author['avatarUrl'] as String?),
                                  radius: 16,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _text(author['name'], 'User'),
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
                    hintText: 'Add a comment...',
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
                            final res = await api.commentPost(postId, text);
                            final nextComment = _map(res['comment']);
                            if (nextComment.isNotEmpty) {
                              setSheet(() {
                                comments = [...comments, nextComment];
                                controller.clear();
                              });
                            }
                            final nextCount = comments.length;
                            _patchPost(postId, {'commentCount': nextCount});
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
                  child: Text(sending ? 'Posting...' : 'Post comment'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    controller.dispose();
  }

  Future<void> _followSuggestedUser(Map<String, dynamic> user) async {
    final api = context.read<AuthController>().api;
    final userId = _text(user['id']);
    if (userId.isEmpty) return;
    try {
      await api.follow(userId);
      _removeSuggestion(userId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(api.friendlyError(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final api = auth.api;
    final me = _text(auth.user?['id']);
    final palette = CraftHubPalette.of(context);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 110),
        children: [
          if (_suggestions.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Text(
                'Suggestions',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: palette.muted,
                      letterSpacing: 0.3,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            SizedBox(
              height: 128,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                scrollDirection: Axis.horizontal,
                itemCount: _suggestions.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final user = _suggestions[index];
                  final userId = _text(user['id']);
                  final sharedGenres = (user['sharedGenres'] as List<dynamic>? ?? [])
                      .map((entry) => '$entry')
                      .take(1)
                      .join(', ');
                  final openProfile = userId.isEmpty || userId == me
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UserProfileScreen(userId: userId),
                            ),
                          );
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: openProfile,
                      child: Container(
                        width: 146,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: palette.panel.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: palette.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                UserAvatar(
                                  imageUrl: api.assetUrl(user['avatarUrl'] as String?),
                                  radius: 18,
                                ),
                                const Spacer(),
                                InkWell(
                                  borderRadius: BorderRadius.circular(999),
                                  onTap: () => _followSuggestedUser(user),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: CraftHubColors.lavender,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      'Follow',
                                      style: TextStyle(
                                        color: Color(0xFF220A30),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _text(user['name'], 'User'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: palette.text,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  sharedGenres.isEmpty ? '@${_text(user['username'])}' : sharedGenres,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        letterSpacing: 0.1,
                                        fontSize: 11,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(height: 1, color: palette.border.withValues(alpha: 0.6)),
          ],
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 120),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_posts.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 32, 18, 0),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: palette.panel.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: palette.border),
                ),
                child: const Text(
                  'Follow people or share your first update to bring the home feed to life.',
                ),
              ),
            )
          else
            ..._posts.map((post) {
              final author = _map(post['author']);
              final images = (post['imageUrls'] as List<dynamic>? ?? [])
                  .map((entry) => entry.toString())
                  .where((entry) => entry.trim().isNotEmpty)
                  .toList();
              final likedByMe = post['likedByMe'] == true;
              final isMine = _text(author['id']) == me;
              final followLabel = post['authorFollowedByMe'] == true ? 'Following' : 'Follow';
              final likeCount = (post['likeCount'] as num?)?.toInt() ?? 0;
              final commentCount = (post['commentCount'] as num?)?.toInt() ?? 0;
              final shareCount = (post['sharesCount'] as num?)?.toInt() ?? 0;
              final text = _text(post['text']);
              final time = _relativeTime(_text(post['createdAt']));

              return Container(
                margin: const EdgeInsets.only(bottom: 18),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: CraftHubColors.border),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Row(
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: isMine
                                ? null
                                : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => UserProfileScreen(
                                          userId: _text(author['id']),
                                        ),
                                      ),
                                    ),
                            child: Row(
                              children: [
                                UserAvatar(
                                  imageUrl: api.assetUrl(author['avatarUrl'] as String?),
                                  radius: 18,
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _text(author['name'], 'User'),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: palette.text,
                                        fontSize: 15,
                                      ),
                                    ),
                                    if (time.isNotEmpty)
                                      Text(
                                        '$time ago',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              letterSpacing: 0,
                                              fontSize: 11,
                                            ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          if (!isMine)
                            OutlinedButton(
                              onPressed: () => _toggleFollow(api, post, me),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                backgroundColor: palette.panelAlt.withValues(alpha: 0.92),
                              ),
                              child: Text(followLabel),
                            ),
                          PopupMenuButton<String>(
                            color: palette.panel,
                            onSelected: (value) {
                              if (value == 'delete') {
                                _deletePost(api, post);
                              } else if (value == 'profile' && !isMine) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => UserProfileScreen(
                                      userId: _text(author['id']),
                                    ),
                                  ),
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              if (!isMine)
                                const PopupMenuItem(
                                  value: 'profile',
                                  child: Text('View profile'),
                                ),
                              if (isMine)
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete post'),
                                ),
                            ],
                            icon: const Icon(Icons.more_vert_rounded),
                          ),
                        ],
                      ),
                    ),
                    if (images.isNotEmpty)
                      _FeedMediaCarousel(images: images)
                    else
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 14),
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: palette.panel.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: palette.border),
                        ),
                        child: Text(
                          text.isEmpty ? 'Shared an update on Craft Hub.' : text,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: palette.text,
                              ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => _toggleLike(api, post),
                            icon: Icon(
                              likedByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: likedByMe ? CraftHubColors.lavender : palette.text,
                            ),
                          ),
                          Text(
                            _compactCount(likeCount),
                            style: TextStyle(color: palette.text, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            onPressed: () => _openComments(api, post),
                            icon: const Icon(Icons.mode_comment_outlined),
                          ),
                          Text(
                            _compactCount(commentCount),
                            style: TextStyle(color: palette.text, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            onPressed: () => _sharePost(api, post),
                            icon: const Icon(Icons.send_outlined),
                          ),
                          Text(
                            _compactCount(shareCount),
                            style: TextStyle(color: palette.text, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    if (text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '${_text(author['name'], 'User')} ',
                                style: TextStyle(
                                  color: palette.text,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              TextSpan(
                                text: text,
                                style: TextStyle(
                                  color: palette.text.withValues(alpha: 0.78),
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _FeedMediaCarousel extends StatefulWidget {
  const _FeedMediaCarousel({required this.images});

  final List<String> images;

  @override
  State<_FeedMediaCarousel> createState() => _FeedMediaCarouselState();
}

class _FeedMediaCarouselState extends State<_FeedMediaCarousel> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final palette = CraftHubPalette.of(context);
    if (widget.images.length == 1) {
      return CachedNetworkImage(
        imageUrl: widget.images.first,
        width: double.infinity,
        height: 430,
        fit: BoxFit.cover,
      );
    }

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        SizedBox(
          height: 430,
          child: PageView.builder(
            itemCount: widget.images.length,
            onPageChanged: (value) => setState(() => _index = value),
            itemBuilder: (context, index) => CachedNetworkImage(
              imageUrl: widget.images[index],
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: palette.bg.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${_index + 1}/${widget.images.length}',
              style: TextStyle(
                color: palette.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 14,
          child: Row(
            children: List.generate(
              widget.images.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _index == index ? 18 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: _index == index
                      ? palette.text
                      : palette.text.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

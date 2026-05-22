import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/craft_hub_theme.dart';
import '../../providers/auth_controller.dart';
import '../../widgets/craft_hub_ui.dart';
import '../../widgets/user_avatar.dart';
import '../messages/chat_room_screen.dart';
import '../posts/post_detail_screen.dart';
import '../projects/project_detail_screen.dart';
import 'network_screen.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  static const _projectsSection = 'projects';
  static const _postsSection = 'posts';
  static const _collabsSection = 'collabs';
  static const _commitsSection = 'commits';
  static const _repositoriesSection = 'repositories';

  Map<String, dynamic>? _user;
  List<dynamic> _posts = [];
  List<dynamic> _projects = [];
  List<dynamic> _collabWith = [];
  Map<String, dynamic>? _githubActivity;
  bool _following = false;
  int _followers = 0;
  int _followingCount = 0;
  bool _connected = false;
  bool _loading = true;
  String _section = _projectsSection;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthController>();
    final api = auth.api;
    setState(() => _loading = true);
    try {
      final prof = await api.profileById(widget.userId);
      final user = prof['user'] as Map<String, dynamic>?;
      final futures = <Future<dynamic>>[
        api.userPosts(widget.userId),
        api.userProjects(widget.userId),
        if (user?['githubConnected'] == true)
          api.githubActivityForUser(widget.userId).catchError((_) => <String, dynamic>{}),
      ];
      final results = await Future.wait<dynamic>(futures);
      final posts = results[0] as Map<String, dynamic>;
      final proj = results[1] as Map<String, dynamic>;
      final githubActivity = results.length > 2
          ? results[2] as Map<String, dynamic>
          : null;
      if (!mounted) return;
      setState(() {
        _user = user;
        _following = prof['isFollowing'] == true;
        _followers = (prof['followerCount'] as num?)?.toInt() ?? 0;
        _followingCount = (prof['followingCount'] as num?)?.toInt() ?? 0;
        _collabWith = prof['collabWith'] as List<dynamic>? ?? [];
        _connected = _collabWith
            .whereType<Map<String, dynamic>>()
            .any((c) => c['id'] == auth.user?['id']);
        _posts = posts['posts'] as List<dynamic>? ?? [];
        _projects = proj['projects'] as List<dynamic>? ?? [];
        _githubActivity = (githubActivity == null || githubActivity.isEmpty)
            ? null
            : githubActivity;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow() async {
    final api = context.read<AuthController>().api;
    try {
      if (_following) {
        await api.unfollow(widget.userId);
      } else {
        await api.follow(widget.userId);
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(api.friendlyError(e))));
      }
    }
  }

  Future<void> _dm() async {
    final api = context.read<AuthController>().api;
    try {
      final data = await api.openDm(widget.userId);
      final id = data['id'] as String?;
      if (id != null && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatRoomScreen(
              conversationId: id,
              title: _user?['name'] as String? ?? 'Chat',
              projectId: null,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(api.friendlyError(e))));
      }
    }
  }

  Future<void> _showAvatarPreview(String imageUrl) async {
    if (imageUrl.trim().isEmpty) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Center(
                    child: Hero(
                      tag: 'public-profile-avatar-${widget.userId}',
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white70,
                          size: 52,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: SafeArea(
                child: IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.45),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Future<void> _launchExternal(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _sectionTab(String value, String label) {
    final selected = _section == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _section = value),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            children: [
              Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10.5,
                  color: selected ? CraftHubColors.text : CraftHubColors.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                height: 2,
                color: selected ? CraftHubColors.lavender : Colors.transparent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(String value, String label, {VoidCallback? onTap}) {
    final child = Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: CraftHubColors.panelAlt.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: CraftHubColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(letterSpacing: 1.1),
          ),
        ],
      ),
    );
    return onTap == null
        ? child
        : InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: child,
          );
  }

  Widget _heatmap() {
    final contributionSeries =
        (_githubActivity?['contributionSeries'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
    final values = contributionSeries.isEmpty
        ? List<int>.filled(42, 0)
        : contributionSeries
            .map((entry) => ((entry['count'] as num?)?.toInt() ?? 0).clamp(0, 5))
            .toList();

    Color colorFor(int value) {
      switch (value) {
        case 0:
          return CraftHubColors.panelAlt;
        case 1:
          return const Color(0xFF4A3657);
        case 2:
          return const Color(0xFF6E4A7F);
        case 3:
          return const Color(0xFF9364B3);
        case 4:
          return const Color(0xFFC18AEC);
        default:
          return const Color(0xFFE5A7FF);
      }
    }

    return CraftHubPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'GitHub Commit Activity',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              Text('Less', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 8),
              ...[0, 1, 2, 3, 4].map(
                (index) => Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colorFor(index),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
              Text('More', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: values
                .map(
                  (value) => Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: colorFor(value),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          Text(
            'Showing actual recent GitHub push activity for @${_githubActivity?['username'] ?? ''}.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _projectCard(Map<String, dynamic> project) {
    final api = context.read<AuthController>().api;
    final images =
        (project['imageUrls'] as List<dynamic>? ?? []).map((e) => '$e').toList();
    final genres =
        (project['genres'] as List<dynamic>? ?? []).map((e) => '$e').toList();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: CraftHubPanel(
        padding: const EdgeInsets.all(0),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ProjectDetailScreen(projectId: project['id'] as String),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (images.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: api.assetUrl(images.first),
                    height: 190,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    placeholder: (context, url) => Container(
                      height: 190,
                      color: CraftHubColors.panelAlt,
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 190,
                      color: CraftHubColors.panelAlt,
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_not_supported_outlined),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project['title'] as String? ?? 'Project',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      (project['description'] as String? ?? '').trim(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      genres.take(2).join(' • '),
                      style: Theme.of(context).textTheme.bodySmall,
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

  Widget _postCard(Map<String, dynamic> post) {
    final api = context.read<AuthController>().api;
    final text = (post['text'] as String? ?? '').trim();
    final images =
        (post['imageUrls'] as List<dynamic>? ?? []).map((e) => '$e').toList();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: CraftHubPanel(
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PostDetailScreen(postId: post['id'] as String),
              ),
            );
            if (mounted) await _load();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('POST', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 10),
              Text(
                text.isEmpty ? 'Image post' : text,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (images.isNotEmpty) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: CachedNetworkImage(
                    imageUrl: api.assetUrl(images.first),
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    placeholder: (context, url) => Container(
                      height: 180,
                      color: CraftHubColors.panelAlt,
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 180,
                      color: CraftHubColors.panelAlt,
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_not_supported_outlined),
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

  Widget _githubCommitsPanel() {
    final activity = _githubActivity;
    if (activity == null) {
      return const CraftHubPanel(
        child: Text('GitHub commit activity is not available for this user.'),
      );
    }

    final recentCommits =
        (activity['recentCommits'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();

    return CraftHubPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Recent GitHub Commits',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              if ((activity['username'] as String? ?? '').isNotEmpty)
                CraftHubTag(
                  label: '@${activity['username']}',
                  highlight: true,
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (recentCommits.isEmpty)
            const Text(
              'No recent GitHub push activity was found on this connected account yet.',
            )
          else
            ...recentCommits.take(6).map((commit) {
              final messages =
                  (commit['messages'] as List<dynamic>? ?? [])
                      .map((entry) => '$entry')
                      .where((entry) => entry.trim().isNotEmpty)
                      .toList();
              final message = messages.isEmpty
                  ? '${(commit['commitCount'] as num?)?.toInt() ?? 1} commit pushed'
                  : messages.first;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CraftHubIconBubble(
                      icon: Icons.commit_rounded,
                      size: 40,
                      active: true,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            commit['repoName'] as String? ?? 'Repository',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: CraftHubColors.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(commit['commitCount'] as num?)?.toInt() ?? 1} commit(s) • ${_relativeTime(commit['createdAt'] as String? ?? '')}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
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

  Widget _githubRepositoriesPanel() {
    final activity = _githubActivity;
    if (activity == null) {
      return const CraftHubPanel(
        child: Text('GitHub repositories are not available for this user.'),
      );
    }

    final repositories =
        (activity['repositories'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();

    return CraftHubPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GitHub Repositories',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 14),
          if (repositories.isEmpty)
            const Text(
              'No public GitHub repositories were returned for this user yet.',
            )
          else
            ...repositories.take(6).map((repo) {
              final description = (repo['description'] as String? ?? '').trim();
              final language = (repo['language'] as String? ?? '').trim();
              final url = (repo['htmlUrl'] as String? ?? '').trim();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: url.isEmpty ? null : () => _launchExternal(url),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: CraftHubColors.panelAlt.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: CraftHubColors.border),
                    ),
                    child: Row(
                      children: [
                        const CraftHubIconBubble(
                          icon: Icons.folder_open_rounded,
                          size: 42,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                repo['name'] as String? ?? 'Repo',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: CraftHubColors.text,
                                ),
                              ),
                              if (description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 6),
                              Text(
                                '${language.isEmpty ? 'Codebase' : language} • ${_compactCount((repo['stars'] as num?)?.toInt() ?? 0)} stars',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.open_in_new_rounded),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  List<Widget> _sectionContent() {
    if (_section == _commitsSection) {
      return [_githubCommitsPanel()];
    }
    if (_section == _repositoriesSection) {
      return [_githubRepositoriesPanel()];
    }
    if (_section == _postsSection) {
      if (_posts.isEmpty) {
        return const [
          CraftHubPanel(
            child: Text('No posts yet. Their public posts will appear here.'),
          ),
        ];
      }
      return _posts.whereType<Map<String, dynamic>>().map(_postCard).toList();
    }
    if (_section == _collabsSection) {
      final collabs = _collabWith.whereType<Map<String, dynamic>>().toList();
      if (collabs.isEmpty) {
        return const [
          CraftHubPanel(
            child: Text('No collaborators are visible on this profile yet.'),
          ),
        ];
      }
      return collabs.map((person) {
        final api = context.read<AuthController>().api;
        final id = person['id'] as String?;
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: CraftHubPanel(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: UserAvatar(
                imageUrl: api.assetUrl(person['avatarUrl'] as String?),
                radius: 24,
              ),
              title: Text(person['name'] as String? ?? ''),
              subtitle: Text('@${person['username'] ?? ''}'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: id == null || id == widget.userId
                  ? null
                  : () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserProfileScreen(userId: id),
                      ),
                    ),
            ),
          ),
        );
      }).toList();
    }
    final projects = _projects.whereType<Map<String, dynamic>>().toList();
    if (projects.isEmpty) {
      return const [
        CraftHubPanel(
          child: Text('No projects yet. Public projects will appear here.'),
        ),
      ];
    }
    return projects.map(_projectCard).toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final api = auth.api;
    final me = auth.user?['id'] as String?;

    if (_loading || _user == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final user = _user!;
    final avatar = api.assetUrl(user['avatarUrl'] as String?);
    final isMe = user['id'] == me;
    final bio = (user['bio'] as String? ?? '').trim();
    final genres =
        (user['genres'] as List<dynamic>? ?? []).map((e) => '$e').toList();
    final role = genres.take(2).join(' / ').toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: Text(user['username'] as String? ?? 'Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () =>
                Share.share('Craft Hub profile: @${user['username']}'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 120),
          children: [
            CraftHubPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Icon(
                      Icons.auto_awesome,
                      color: CraftHubColors.lavender.withValues(alpha: 0.35),
                    ),
                  ),
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: avatar.isEmpty ? null : () => _showAvatarPreview(avatar),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(36),
                              border: Border.all(color: CraftHubColors.lavender),
                              boxShadow: [
                                BoxShadow(
                                  color: CraftHubColors.purple.withValues(alpha: 0.24),
                                  blurRadius: 22,
                                ),
                              ],
                            ),
                            child: Hero(
                              tag: 'public-profile-avatar-${widget.userId}',
                              child: UserAvatar(imageUrl: avatar, radius: 52),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          user['name'] as String? ?? '',
                          style: Theme.of(context).textTheme.headlineMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          role.isEmpty ? 'CREATIVE BUILDER' : role,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: CraftHubColors.cyan,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          bio.isEmpty
                              ? 'Building projects, sharing work, and collaborating inside Craft Hub.'
                              : bio,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: genres.take(3).map((genre) => CraftHubTag(label: genre)).toList(),
                        ),
                        if (!isMe) ...[
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: [
                              FilledButton.icon(
                                onPressed: _toggleFollow,
                                icon: Icon(
                                  _following
                                      ? Icons.person_remove_alt_1_rounded
                                      : Icons.person_add_alt_1_rounded,
                                ),
                                label: Text(_following ? 'Following' : 'Follow'),
                              ),
                              if (_connected)
                                FilledButton.tonalIcon(
                                  onPressed: _dm,
                                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                                  label: const Text('Message'),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    _followers.toString(),
                    'Followers',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NetworkScreen(
                          userId: user['id'] as String,
                          initialTab: 0,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statCard(
                    _followingCount.toString(),
                    'Following',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NetworkScreen(
                          userId: user['id'] as String,
                          initialTab: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statCard(
                    _projects.length.toString(),
                    'Projects',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_collabWith.isNotEmpty)
              CraftHubPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Collaborated With',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      children: [
                        ..._collabWith
                            .whereType<Map<String, dynamic>>()
                            .take(4)
                            .map(
                              (person) => UserAvatar(
                                imageUrl: api.assetUrl(person['avatarUrl'] as String?),
                                radius: 18,
                              ),
                            ),
                        if (_collabWith.length > 4)
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: CraftHubColors.panelAlt,
                            child: Text('+${_collabWith.length - 4}'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            if (_githubActivity != null) ...[
              const SizedBox(height: 16),
              _heatmap(),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                _sectionTab(_projectsSection, 'Projects'),
                _sectionTab(_postsSection, 'Posts'),
                _sectionTab(_collabsSection, 'Collabs'),
                if (_githubActivity != null) ...[
                  _sectionTab(_commitsSection, 'Commits'),
                  _sectionTab(_repositoriesSection, 'Repos'),
                ],
              ],
            ),
            ..._sectionContent(),
          ],
        ),
      ),
    );
  }
}

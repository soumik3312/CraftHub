import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/craft_hub_theme.dart';
import '../../core/genres.dart';
import '../../providers/auth_controller.dart';
import '../../services/realtime_sync_bus.dart';
import '../../widgets/craft_hub_ui.dart';
import '../../widgets/user_avatar.dart';
import '../posts/post_compose_screen.dart';
import '../posts/post_detail_screen.dart';
import '../projects/project_create_screen.dart';
import '../projects/project_detail_screen.dart';
import 'github_connect_screen.dart';
import 'network_screen.dart';
import 'settings_screen.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  static const _projectsSection = 'projects';
  static const _postsSection = 'posts';
  static const _collabsSection = 'collabs';
  static const _commitsSection = 'commits';
  static const _repositoriesSection = 'repositories';

  List<dynamic> _posts = [];
  List<dynamic> _owned = [];
  List<dynamic> _collab = [];
  List<dynamic> _collabWith = [];
  Map<String, dynamic>? _githubActivity;
  int _followers = 0;
  int _following = 0;
  String _section = _projectsSection;
  bool _loading = true;
  StreamSubscription<Map<String, dynamic>>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _load();
    _syncSubscription = RealtimeSyncBus.events.listen((event) {
      if (['profile', 'settings', 'follow', 'post', 'project', 'workspace', 'collaboration'].contains(event['entity'])) {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final auth = context.read<AuthController>();
    final uid = auth.user?['id'] as String?;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final results = await Future.wait<dynamic>([
        auth.api.profileById(uid),
        auth.api.userPosts(uid),
        auth.api.myProjects(),
        if (auth.user?['githubConnected'] == true)
          auth.api.githubActivity().catchError((_) => <String, dynamic>{}),
      ]);
      final profile = results[0] as Map<String, dynamic>;
      final posts = results[1] as Map<String, dynamic>;
      final projects = results[2] as Map<String, dynamic>;
      final githubActivity = results.length > 3
          ? results[3] as Map<String, dynamic>
          : null;
      if (!mounted) return;
      setState(() {
        _posts = posts['posts'] as List<dynamic>? ?? [];
        _owned = projects['owned'] as List<dynamic>? ?? [];
        _collab = projects['collaborating'] as List<dynamic>? ?? [];
        _followers = (profile['followerCount'] as num?)?.toInt() ?? 0;
        _following = (profile['followingCount'] as num?)?.toInt() ?? 0;
        _collabWith = profile['collabWith'] as List<dynamic>? ?? [];
        _githubActivity = (githubActivity == null || githubActivity.isEmpty)
            ? null
            : githubActivity;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit() async {
    final auth = context.read<AuthController>();
    final api = auth.api;
    final user = auth.user!;
    final name = TextEditingController(text: user['name'] as String? ?? '');
    final username = TextEditingController(
      text: user['username'] as String? ?? '',
    );
    final bio = TextEditingController(text: user['bio'] as String? ?? '');
    final selected = Set<String>.from(
      (user['genres'] as List<dynamic>? ?? []).map((e) => '$e'),
    );
    final existingAvatarUrl = api.assetUrl(user['avatarUrl'] as String?);
    File? pendingAvatar;
    var removeAvatar = false;
    var saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(ctx).bottom + 18,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: StatefulBuilder(
          builder: (ctx, setSheet) {
            Future<void> pickAvatar() async {
              final picked = await ImagePicker().pickImage(
                source: ImageSource.gallery,
                imageQuality: 90,
              );
              if (picked == null) return;
              setSheet(() {
                pendingAvatar = File(picked.path);
                removeAvatar = false;
              });
            }

            Future<void> saveProfile() async {
              if (saving) return;
              setSheet(() => saving = true);
              try {
                await auth.api.updateMe(
                  name: name.text.trim(),
                  username: username.text.trim(),
                  bio: bio.text.trim(),
                  genres: selected.toList(),
                  avatar: pendingAvatar,
                  removeAvatar: removeAvatar,
                );
                await auth.refreshMe();
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) await _load();
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(auth.api.friendlyError(e))),
                  );
                }
              } finally {
                if (ctx.mounted) setSheet(() => saving = false);
              }
            }

            final previewUrl = pendingAvatar == null && !removeAvatar
                ? existingAvatarUrl
                : '';
            final canRemoveAvatar =
                pendingAvatar != null || existingAvatarUrl.isNotEmpty;
            return CraftHubPanel(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Edit profile',
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: UserAvatar(
                        imageUrl: previewUrl,
                        imageFile: pendingAvatar,
                        radius: 44,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: saving ? null : pickAvatar,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: Text(
                            existingAvatarUrl.isEmpty && pendingAvatar == null
                                ? 'Add photo'
                                : 'Change photo',
                          ),
                        ),
                        if (canRemoveAvatar)
                          OutlinedButton.icon(
                            onPressed: saving
                                ? null
                                : () => setSheet(() {
                                    pendingAvatar = null;
                                    removeAvatar = existingAvatarUrl.isNotEmpty;
                                  }),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Remove photo'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: username,
                      decoration: const InputDecoration(labelText: 'Username'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: bio,
                      decoration: const InputDecoration(labelText: 'Bio'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: kProjectGenres.map((genre) {
                        final enabled = selected.contains(genre);
                        return FilterChip(
                          label: Text(genre),
                          selected: enabled,
                          onSelected: (next) => setSheet(() {
                            if (next) {
                              selected.add(genre);
                            } else {
                              selected.remove(genre);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: saving ? null : saveProfile,
                      child: saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );

    name.dispose();
    username.dispose();
    bio.dispose();
  }

  Future<void> _connectGithub() async {
    final auth = context.read<AuthController>();
    try {
      final data = await auth.api.githubConnectStart();
      final authorizeUrl = data['authorizeUrl'] as String? ?? '';
      final completeUrl = data['completeUrl'] as String? ?? '';
      final flowToken = data['flowToken'] as String? ?? '';
      if (!mounted) {
        return;
      }
      if (authorizeUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'GitHub connect could not start because the server did not return an authorization link.',
            ),
          ),
        );
        return;
      }
      final result = await Navigator.push<GitHubConnectResult>(
        context,
        MaterialPageRoute(
          builder: (_) => GitHubConnectScreen(
            authorizeUrl: authorizeUrl,
            completeUrl: completeUrl,
            flowToken: flowToken,
          ),
        ),
      );
      if (!mounted || result == null) return;
      if (result.success) {
        await auth.refreshMe();
        await _load();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(auth.api.friendlyError(e))));
      }
    }
  }

  Future<void> _disconnectGithub() async {
    final auth = context.read<AuthController>();
    try {
      await auth.api.githubDisconnect();
      await auth.refreshMe();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GitHub account disconnected.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(auth.api.friendlyError(e))));
      }
    }
  }

  int _projectCount() => _projects().length;

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
                      tag: 'profile-avatar-preview',
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
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

  int _projectContributions(Map<String, dynamic> project) {
    final workspace = project['workspace'] as Map<String, dynamic>? ?? const {};
    return (workspace['totalContributionCount'] as num?)?.toInt() ?? 0;
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

  List<Map<String, dynamic>> _projects() =>
      _owned.whereType<Map<String, dynamic>>().toList();
  List<Map<String, dynamic>> _collabs() =>
      _collab.whereType<Map<String, dynamic>>().toList();

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

  Widget _statPill(String value, String label, {VoidCallback? onTap}) {
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
              .map(
                (entry) => ((entry['count'] as num?)?.toInt() ?? 0).clamp(0, 5),
              )
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
                _githubActivity == null
                    ? 'Contribution Frequency'
                    : 'GitHub Commit Activity',
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
          if (_githubActivity != null) ...[
            const SizedBox(height: 14),
            Text(
              'Showing actual recent GitHub push activity for @${_githubActivity!['username'] ?? ''}.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _githubRecentActivity() {
    final activity = _githubActivity;
    if (activity == null) {
      return const SizedBox.shrink();
    }

    final recentCommits = (activity['recentCommits'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final repositories = (activity['repositories'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();

    return Column(
      children: [
        CraftHubPanel(
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
                ...recentCommits.take(4).map((commit) {
                  final messages = (commit['messages'] as List<dynamic>? ?? [])
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
                                '${(commit['commitCount'] as num?)?.toInt() ?? 1} commit(s)  •  ${_relativeTime(commit['createdAt'] as String? ?? '')}',
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
        ),
        const SizedBox(height: 16),
        CraftHubPanel(
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
                  'Connected repositories will appear here after GitHub sync loads them.',
                )
              else
                ...repositories.take(4).map((repo) {
                  final description = (repo['description'] as String? ?? '')
                      .trim();
                  final language = (repo['language'] as String? ?? '').trim();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () =>
                          _launchExternal(repo['htmlUrl'] as String? ?? ''),
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
                                    '${language.isEmpty ? 'Codebase' : language}  •  ${_compactCount((repo['stars'] as num?)?.toInt() ?? 0)} stars',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
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
        ),
      ],
    );
  }

  Widget _githubCommitsPanel() {
    final activity = _githubActivity;
    if (activity == null) {
      return const CraftHubPanel(
        child: Text('Connect GitHub to see your recent commit activity here.'),
      );
    }

    final recentCommits = (activity['recentCommits'] as List<dynamic>? ?? [])
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
                CraftHubTag(label: '@${activity['username']}', highlight: true),
            ],
          ),
          const SizedBox(height: 14),
          if (recentCommits.isEmpty)
            const Text(
              'No recent GitHub push activity was found on this connected account yet.',
            )
          else
            ...recentCommits.take(6).map((commit) {
              final messages = (commit['messages'] as List<dynamic>? ?? [])
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
        child: Text(
          'Connect GitHub to see repositories linked to your account here.',
        ),
      );
    }

    final repositories = (activity['repositories'] as List<dynamic>? ?? [])
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
              'Connected repositories will appear here after GitHub sync loads them.',
            )
          else
            ...repositories.take(6).map((repo) {
              final description = (repo['description'] as String? ?? '').trim();
              final language = (repo['language'] as String? ?? '').trim();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () =>
                      _launchExternal(repo['htmlUrl'] as String? ?? ''),
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

  Widget _projectCard(Map<String, dynamic> project, {required String action}) {
    final images = (project['imageUrls'] as List<dynamic>? ?? [])
        .map((e) => '$e')
        .toList();
    final genres = (project['genres'] as List<dynamic>? ?? [])
        .map((e) => '$e')
        .toList();
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
                    imageUrl: images.first,
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            project['title'] as String? ?? 'Project',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Icon(
                          Icons.star_rounded,
                          color: _projectContributions(project) > 0
                              ? CraftHubColors.cyan
                              : CraftHubColors.muted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      (project['description'] as String? ?? '').trim(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${genres.take(2).join(' • ')}  •  ${_projectContributions(project)} contributions',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        action.toUpperCase(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: CraftHubColors.lavender,
                          fontWeight: FontWeight.w800,
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

  Widget _postCard(Map<String, dynamic> post) {
    final text = (post['text'] as String? ?? '').trim();
    final images = (post['imageUrls'] as List<dynamic>? ?? [])
        .map((e) => '$e')
        .toList();
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
                    imageUrl: images.first,
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
            child: Text(
              'No posts yet. Share updates and they will appear here.',
            ),
          ),
        ];
      }
      return _posts.whereType<Map<String, dynamic>>().map(_postCard).toList();
    }
    if (_section == _collabsSection) {
      final collabs = _collabs();
      if (collabs.isEmpty) {
        return const [
          CraftHubPanel(
            child: Text(
              'No collaborative projects yet. Accepted collabs will show here.',
            ),
          ),
        ];
      }
      return collabs
          .map((project) => _projectCard(project, action: 'Join Group'))
          .toList();
    }
    final projects = _projects();
    if (projects.isEmpty) {
      return const [
        CraftHubPanel(
          child: Text(
            'No projects yet. Create a project to build your profile.',
          ),
        ),
      ];
    }
    return projects
        .map((project) => _projectCard(project, action: 'View Demo'))
        .toList();
  }

  Widget _githubCard(Map<String, dynamic> user) {
    final connected = user['githubConnected'] == true;
    final githubUsername = (user['githubUsername'] as String? ?? '').trim();
    final githubProfileUrl = (user['githubProfileUrl'] as String? ?? '').trim();
    return CraftHubPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'GitHub Connection',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              if (connected && githubUsername.isNotEmpty)
                CraftHubTag(label: '@$githubUsername', highlight: true),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            connected
                ? 'Connected as @$githubUsername. Real commit activity and repositories are shown below, and shared project repos will use this account.'
                : 'Connect GitHub so your collaborations can auto-create shared repos and open the Monaco workspace.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: connected ? null : _connectGithub,
                icon: const Icon(Icons.link),
                label: Text(connected ? 'GitHub Connected' : 'Connect GitHub'),
              ),
              if (connected)
                OutlinedButton.icon(
                  onPressed: _disconnectGithub,
                  icon: const Icon(Icons.link_off_outlined),
                  label: const Text('Disconnect'),
                ),
              if (connected && githubProfileUrl.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _launchExternal(githubProfileUrl),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Open GitHub'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final api = auth.api;
    final user = auth.user;
    if (user == null) return const SizedBox.shrink();

    final avatar = api.assetUrl(user['avatarUrl'] as String?);
    final bio = (user['bio'] as String? ?? '').trim();
    final genres = (user['genres'] as List<dynamic>? ?? [])
        .map((e) => '$e')
        .toList();
    final role = genres.take(2).join(' / ').toUpperCase();

    return RefreshIndicator(
      onRefresh: _load,
      child: _loading
          ? ListView(
              children: const [
                SizedBox(
                  height: 240,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            )
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 120),
              children: [
                CraftHubPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              color: CraftHubColors.lavender.withValues(
                                alpha: 0.35,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SettingsScreen(),
                                ),
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: CraftHubColors.panelAlt
                                    .withValues(alpha: 0.9),
                                side: const BorderSide(
                                  color: CraftHubColors.border,
                                ),
                              ),
                              icon: const Icon(Icons.settings_outlined),
                            ),
                          ],
                        ),
                      ),
                      Center(
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: avatar.isEmpty
                                  ? null
                                  : () => _showAvatarPreview(avatar),
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(36),
                                  border: Border.all(
                                    color: CraftHubColors.lavender,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: CraftHubColors.purple.withValues(
                                        alpha: 0.24,
                                      ),
                                      blurRadius: 22,
                                    ),
                                  ],
                                ),
                                child: Hero(
                                  tag: 'profile-avatar-preview',
                                  child: UserAvatar(
                                    imageUrl: avatar,
                                    radius: 52,
                                  ),
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
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(color: CraftHubColors.cyan),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              bio.isEmpty
                                  ? 'Build your public profile, publish projects, and grow your collaborative network.'
                                  : bio,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: genres
                                  .take(3)
                                  .map((genre) => CraftHubTag(label: genre))
                                  .toList(),
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              alignment: WrapAlignment.center,
                              children: [
                                FilledButton.icon(
                                  onPressed: _edit,
                                  icon: const Icon(Icons.flash_on_rounded),
                                  label: const Text('Manage Profile'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const SettingsScreen(),
                                    ),
                                  ),
                                  icon: const Icon(Icons.settings_outlined),
                                  label: const Text('Settings'),
                                ),
                              ],
                            ),
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
                      child: _statPill(
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
                      child: _statPill(
                        _following.toString(),
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
                      child: _statPill(_projectCount().toString(), 'Projects'),
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
                                    imageUrl: api.assetUrl(
                                      person['avatarUrl'] as String?,
                                    ),
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
                const SizedBox(height: 16),
                _heatmap(),
                const SizedBox(height: 16),
                _githubCard(user),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _sectionTab(_projectsSection, 'Projects'),
                    _sectionTab(_postsSection, 'Posts'),
                    _sectionTab(_collabsSection, 'Collabs'),
                    _sectionTab(_commitsSection, 'Commits'),
                    _sectionTab(_repositoriesSection, 'Repos'),
                  ],
                ),
                ..._sectionContent(),
                if (_collabs().isNotEmpty) ...[
                  const SizedBox(height: 18),
                  CraftHubPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Latest Collab',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _collabs().first['title'] as String? ??
                              'Collaboration',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          (_collabs().first['description'] as String? ?? '')
                              .trim(),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            OutlinedButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProjectDetailScreen(
                                    projectId: _collabs().first['id'] as String,
                                  ),
                                ),
                              ),
                              child: const Text('Join Group'),
                            ),
                            const Spacer(),
                            Text(
                              'Starting soon',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProjectCreateScreen(),
                            ),
                          );
                          if (mounted) await _load();
                        },
                        icon: const Icon(Icons.folder_open_outlined),
                        label: const Text('New Project'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PostComposeScreen(),
                            ),
                          );
                          if (mounted) await _load();
                        },
                        icon: const Icon(Icons.post_add_outlined),
                        label: const Text('New Post'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () async => auth.logout(),
                  child: const Text('Log out'),
                ),
              ],
            ),
    );
  }
}

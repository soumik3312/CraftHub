import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/craft_hub_theme.dart';
import '../../providers/auth_controller.dart';
import '../../widgets/craft_hub_ui.dart';
import '../../widgets/user_avatar.dart';
import 'user_profile_screen.dart';

class NetworkScreen extends StatefulWidget {
  const NetworkScreen({super.key, required this.userId, this.initialTab = 0});

  final String userId;
  final int initialTab;

  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen>
    with SingleTickerProviderStateMixin {
  late TabController _controller;
  List<Map<String, dynamic>> _followers = [];
  List<Map<String, dynamic>> _following = [];
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = context.read<AuthController>().api;
    setState(() => _loading = true);
    try {
      final results = await Future.wait<dynamic>([
        api.followers(widget.userId),
        api.following(widget.userId),
      ]);
      setState(() {
        _followers = (results[0]['users'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        _following = (results[1]['users'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow(Map<String, dynamic> user, bool following) async {
    final api = context.read<AuthController>().api;
    final userId = user['id'] as String?;
    if (userId == null) return;
    try {
      if (following) {
        await api.unfollow(userId);
      } else {
        await api.follow(userId);
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      final message = api.friendlyError(e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> users) {
    if (_query.trim().isEmpty) return users;
    final q = _query.toLowerCase();
    return users.where((user) {
      final name = (user['name'] as String? ?? '').toLowerCase();
      final username = (user['username'] as String? ?? '').toLowerCase();
      return name.contains(q) || username.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredFollowers = _filter(_followers);
    final filteredFollowing = _filter(_following);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CraftHubBackground(
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const BackButton(),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Network',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.headlineMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              CraftHubStatChip(
                                label: 'Followers',
                                value: _followers.length.toString(),
                                highlight: _followers.isNotEmpty,
                                icon: Icons.people_alt_rounded,
                              ),
                              CraftHubStatChip(
                                label: 'Following',
                                value: _following.length.toString(),
                                highlight: _following.isNotEmpty,
                                icon: Icons.favorite_outline_rounded,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            decoration: const InputDecoration(
                              hintText: 'Search people in your network',
                              prefixIcon: Icon(Icons.search_rounded),
                            ),
                            onChanged: (value) =>
                                setState(() => _query = value),
                          ),
                          const SizedBox(height: 16),
                          CraftHubSegmentedTabBar(
                            controller: _controller,
                            tabs: [
                              Tab(
                                child: _NetworkTabLabel(
                                  label: 'Followers',
                                  count: filteredFollowers.length,
                                ),
                              ),
                              Tab(
                                child: _NetworkTabLabel(
                                  label: 'Following',
                                  count: filteredFollowing.length,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: TabBarView(
                        controller: _controller,
                        children: [
                          _NetworkTabContent(
                            users: filteredFollowers,
                            following: false,
                            emptyTitle: 'No followers yet',
                            emptySubtitle:
                                'When people start following this profile, they will show up here.',
                            onToggleFollow: _toggleFollow,
                          ),
                          _NetworkTabContent(
                            users: filteredFollowing,
                            following: true,
                            emptyTitle: 'Not following anyone yet',
                            emptySubtitle:
                                'Profiles you follow will appear here in a tighter, easier-to-scan list.',
                            onToggleFollow: _toggleFollow,
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

class _NetworkTabContent extends StatelessWidget {
  const _NetworkTabContent({
    required this.users,
    required this.following,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onToggleFollow,
  });

  final List<Map<String, dynamic>> users;
  final bool following;
  final String emptyTitle;
  final String emptySubtitle;
  final Future<void> Function(Map<String, dynamic>, bool) onToggleFollow;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
      children: [
        if (users.isEmpty)
          CraftHubEmptyState(
            icon: Icons.people_outline_rounded,
            title: emptyTitle,
            subtitle: emptySubtitle,
          )
        else
          ...users.map(
            (user) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _NetworkUserCard(
                user: user,
                following: following,
                onToggleFollow: onToggleFollow,
              ),
            ),
          ),
      ],
    );
  }
}

class _NetworkUserCard extends StatelessWidget {
  const _NetworkUserCard({
    required this.user,
    required this.following,
    required this.onToggleFollow,
  });

  final Map<String, dynamic> user;
  final bool following;
  final Future<void> Function(Map<String, dynamic>, bool) onToggleFollow;

  @override
  Widget build(BuildContext context) {
    final api = context.read<AuthController>().api;
    final bio = (user['bio'] as String? ?? '').trim();

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserProfileScreen(userId: user['id'] as String),
        ),
      ),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: [
              CraftHubColors.panel.withValues(alpha: 0.97),
              CraftHubColors.panelAlt.withValues(alpha: 0.92),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: CraftHubColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserAvatar(
                imageUrl: api.assetUrl(user['avatarUrl'] as String?),
                radius: 24,
                borderColor: CraftHubColors.border,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user['name'] as String? ?? 'User',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium?.copyWith(fontSize: 17),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: CraftHubColors.panelAlt.withValues(
                              alpha: 0.9,
                            ),
                            border: Border.all(color: CraftHubColors.border),
                          ),
                          child: Text(
                            following ? 'Following' : 'Follower',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: CraftHubColors.text,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${user['username'] ?? ''}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        bio,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: CraftHubColors.text.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UserProfileScreen(
                                userId: user['id'] as String,
                              ),
                            ),
                          ),
                          child: const Text('View'),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.tonal(
                          onPressed: () => onToggleFollow(user, following),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            backgroundColor: following
                                ? CraftHubColors.panelAlt
                                : CraftHubColors.lavender.withValues(
                                    alpha: 0.18,
                                  ),
                            foregroundColor: following
                                ? CraftHubColors.text
                                : CraftHubColors.lavender,
                            side: BorderSide(
                              color: following
                                  ? CraftHubColors.border
                                  : CraftHubColors.lavender,
                            ),
                          ),
                          child: Text(following ? 'Unfollow' : 'Follow'),
                        ),
                      ],
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

class _NetworkTabLabel extends StatelessWidget {
  const _NetworkTabLabel({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: Colors.black.withValues(alpha: 0.14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

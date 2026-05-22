import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/craft_hub_theme.dart';
import '../../widgets/craft_hub_ui.dart';
import '../../widgets/user_avatar.dart';
import '../../providers/auth_controller.dart';
import '../profile/user_profile_screen.dart';
import '../projects/project_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _q = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _projects = [];
  bool _loading = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final q = _q.text.trim();
    if (q.isEmpty) {
      setState(() {
        _hasSearched = false;
        _users = [];
        _projects = [];
      });
      return;
    }
    setState(() {
      _loading = true;
      _hasSearched = true;
    });
    try {
      final data = await context.read<AuthController>().api.search(q);
      if (!mounted) return;
      setState(() {
        _users = (data['users'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        _projects = (data['projects'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<AuthController>().api;
    final totalResults = _users.length + _projects.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CraftHubBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    const BackButton(),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Search',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    _SearchHero(
                      resultCount: totalResults,
                      hasSearched: _hasSearched,
                    ),
                    const SizedBox(height: 16),
                    CraftHubPanel(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SearchSectionHeader(
                            label: 'Search Users & Projects',
                            subtitle:
                                'Look for creators, teammates, project titles, and tags in one cleaner search space.',
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _q,
                            textInputAction: TextInputAction.search,
                            decoration: const InputDecoration(
                              hintText:
                                  'Search people, projects, tech, genres...',
                              prefixIcon: Icon(Icons.search_rounded),
                            ),
                            onSubmitted: (_) => _run(),
                            onChanged: (value) {
                              if (value.trim().isEmpty && _hasSearched) {
                                setState(() {
                                  _hasSearched = false;
                                  _users = [];
                                  _projects = [];
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _loading ? null : _run,
                                  icon: _loading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.travel_explore_rounded,
                                        ),
                                  label: Text(
                                    _loading ? 'Searching...' : 'Search now',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.only(top: 34),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (!_hasSearched)
                      const _SearchEmptyState(
                        icon: Icons.manage_search_rounded,
                        title: 'Start with a keyword',
                        subtitle:
                            'Try a name, project title, technology, or genre to search across people and projects.',
                      )
                    else if (totalResults == 0)
                      const _SearchEmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No results found',
                        subtitle:
                            'Try a broader keyword or search with a project title, username, or technology.',
                      )
                    else ...[
                      if (_users.isNotEmpty) ...[
                        _ResultSectionTitle(
                          title: 'Users',
                          count: _users.length,
                        ),
                        const SizedBox(height: 12),
                        ..._users.map(
                          (user) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _UserSearchCard(
                              user: user,
                              imageUrl: api.assetUrl(
                                user['avatarUrl'] as String?,
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (_projects.isNotEmpty) ...[
                        if (_users.isNotEmpty) const SizedBox(height: 10),
                        _ResultSectionTitle(
                          title: 'Projects',
                          count: _projects.length,
                        ),
                        const SizedBox(height: 12),
                        ..._projects.map(
                          (project) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ProjectSearchCard(project: project),
                          ),
                        ),
                      ],
                    ],
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

class _SearchHero extends StatelessWidget {
  const _SearchHero({required this.resultCount, required this.hasSearched});

  final int resultCount;
  final bool hasSearched;

  @override
  Widget build(BuildContext context) {
    final palette = CraftHubPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            palette.panel.withValues(alpha: 0.98),
            palette.panelAlt.withValues(alpha: 0.94),
            CraftHubColors.cyan.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DISCOVER',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: CraftHubColors.cyan,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Find People And Projects Faster',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(fontSize: 30),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: hasSearched
                  ? CraftHubColors.cyan.withValues(alpha: 0.16)
                  : palette.panelAlt.withValues(alpha: 0.92),
              border: Border.all(
                color: hasSearched ? CraftHubColors.cyan : palette.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$resultCount',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 2),
                Text('RESULTS', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchSectionHeader extends StatelessWidget {
  const _SearchSectionHeader({required this.label, required this.subtitle});

  final String label;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = CraftHubPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: CraftHubColors.lavender,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: palette.text.withValues(alpha: 0.76),
          ),
        ),
      ],
    );
  }
}

class _ResultSectionTitle extends StatelessWidget {
  const _ResultSectionTitle({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: CraftHubColors.panelAlt.withValues(alpha: 0.9),
            border: Border.all(color: CraftHubColors.border),
          ),
          child: Text(
            '$count',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: CraftHubColors.text,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _UserSearchCard extends StatelessWidget {
  const _UserSearchCard({required this.user, required this.imageUrl});

  final Map<String, dynamic> user;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final bio = (user['bio'] as String? ?? '').trim();
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () {
        final id = user['id'] as String?;
        if (id != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => UserProfileScreen(userId: id)),
          );
        }
      },
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
                imageUrl: imageUrl,
                radius: 24,
                borderColor: CraftHubColors.border,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['name'] as String? ?? 'User',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(fontSize: 17),
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
                          color: CraftHubColors.text.withValues(alpha: 0.78),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: CraftHubColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectSearchCard extends StatelessWidget {
  const _ProjectSearchCard({required this.project});

  final Map<String, dynamic> project;

  @override
  Widget build(BuildContext context) {
    final genres = (project['genres'] as List<dynamic>? ?? [])
        .map((entry) => entry.toString())
        .where((entry) => entry.trim().isNotEmpty)
        .take(3)
        .toList();
    final description = (project['description'] as String? ?? '').trim();

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () {
        final id = project['id'] as String?;
        if (id != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProjectDetailScreen(projectId: id),
            ),
          );
        }
      },
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
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: CraftHubColors.lavender.withValues(alpha: 0.14),
                  border: Border.all(
                    color: CraftHubColors.lavender.withValues(alpha: 0.2),
                  ),
                ),
                child: const Icon(
                  Icons.folder_open_rounded,
                  color: CraftHubColors.lavender,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project['title'] as String? ?? 'Project',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(fontSize: 17),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: CraftHubColors.text.withValues(alpha: 0.78),
                        ),
                      ),
                    ],
                    if (genres.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: genres
                            .map((genre) => CraftHubTag(label: genre))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: CraftHubColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: CraftHubEmptyState(icon: icon, title: title, subtitle: subtitle),
    );
  }
}

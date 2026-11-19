import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/genres.dart';
import '../../core/craft_hub_theme.dart';
import '../../providers/auth_controller.dart';
import '../../services/realtime_sync_bus.dart';
import '../../widgets/craft_hub_ui.dart';
import '../../widgets/user_avatar.dart';
import '../profile/user_profile_screen.dart';
import '../projects/project_detail_screen.dart';

class CollabTab extends StatefulWidget {
  const CollabTab({super.key, this.onRequestsChanged});

  final VoidCallback? onRequestsChanged;

  @override
  State<CollabTab> createState() => _CollabTabState();
}

class _CollabTabState extends State<CollabTab>
    with SingleTickerProviderStateMixin {
  late TabController _controller;
  List<Map<String, dynamic>> _matches = [];
  List<Map<String, dynamic>> _incoming = [];
  List<Map<String, dynamic>> _outgoing = [];
  List<Map<String, dynamic>> _collaborationProjects = [];
  List<Map<String, dynamic>> _aiUsers = [];
  List<Map<String, dynamic>> _aiProjects = [];
  String _aiDomain = '';
  String _aiSummary = '';
  bool _aiScanning = false;
  bool _loading = true;
  StreamSubscription<Map<String, dynamic>>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 4, vsync: this);
    _load();
    _syncSubscription = RealtimeSyncBus.events.listen((event) {
      if (event['entity'] == 'collaboration' || event['entity'] == 'project') {
        _load();
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

  List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value.map(_map).where((entry) => entry.isNotEmpty).toList();
  }

  Future<Map<String, dynamic>> _safeJson(
    Future<Map<String, dynamic>> future,
  ) async {
    try {
      return await future;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  List<Map<String, dynamic>> _mergeCollaborationProjects(
    Map<String, dynamic> projects,
  ) {
    final merged = <String, Map<String, dynamic>>{};
    final owned = _mapList(projects['owned']).where((project) {
      final collaborators = _mapList(project['collaborators']).length;
      final memberCount = (project['memberCount'] as num?)?.toInt() ?? 1;
      return collaborators > 0 || memberCount > 1;
    });
    final collaborating = _mapList(projects['collaborating']);

    for (final project in [...owned, ...collaborating]) {
      final id = _text(project['id']);
      if (id.isEmpty) continue;
      merged[id] = project;
    }

    final list = merged.values.toList();
    list.sort((a, b) {
      final left = DateTime.tryParse(_text(a['updatedAt']));
      final right = DateTime.tryParse(_text(b['updatedAt']));
      if (left == null && right == null) return 0;
      if (left == null) return 1;
      if (right == null) return -1;
      return right.compareTo(left);
    });
    return list;
  }

  Future<void> _load() async {
    final api = context.read<AuthController>().api;
    setState(() => _loading = true);
    final results = await Future.wait<Map<String, dynamic>>([
      _safeJson(api.matchUsers()),
      _safeJson(api.incomingCollab()),
      _safeJson(api.outgoingCollab()),
      _safeJson(api.myProjects()),
    ]);
    if (!mounted) return;

    final match = results[0];
    final incoming = results[1];
    final outgoing = results[2];
    final projects = results[3];
    setState(() {
      _matches = _mapList(match['users']);
      _incoming = _mapList(incoming['requests']);
      _outgoing = _mapList(outgoing['requests']);
      _collaborationProjects = _mergeCollaborationProjects(projects);
      _loading = false;
    });
    widget.onRequestsChanged?.call();
  }

  Future<void> _accept(String id) async {
    try {
      final res = await context.read<AuthController>().api.acceptCollab(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_text(res['message'], 'Updated'))),
        );
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      final message = context.read<AuthController>().api.friendlyError(e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _reject(String id) async {
    try {
      await context.read<AuthController>().api.rejectCollab(id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Request declined')));
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      final message = context.read<AuthController>().api.friendlyError(e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _openProject(String projectId) async {
    if (projectId.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectDetailScreen(projectId: projectId),
      ),
    );
    await _load();
  }

  String _requestSummary(
    Map<String, dynamic> request, {
    required bool waiting,
  }) {
    final project = _map(request['project']);
    final type = _text(request['type']);
    final projectTitle = _text(project['title']);

    if (waiting) {
      return 'Accepted earlier. Finish connecting this collaboration.';
    }
    if (projectTitle.isNotEmpty) {
      if (type == 'project_request') return 'Wants to join "$projectTitle".';
      return 'Invited you to collaborate on "$projectTitle".';
    }
    return 'Collaboration request';
  }

  List<String> _sharedCategories(Map<String, dynamic> user) {
    final shared = user['sharedCategories'];
    if (shared is! List) return const [];
    return shared
        .map((entry) => entry.toString().trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
  }

  int _matchPercent(Map<String, dynamic> user) {
    final shared = _sharedCategories(user).length;
    if (shared >= 3) return 96;
    if (shared == 2) return 93;
    if (shared == 1) return 89;
    return 84;
  }

  String _roleLabel(Map<String, dynamic> user) {
    final shared = _sharedCategories(user);
    if (shared.isNotEmpty) return shared.take(2).join(' • ').toUpperCase();
    return 'POTENTIAL COLLABORATOR';
  }

  Future<void> _promptAiScan() async {
    final auth = context.read<AuthController>();
    final userGenres = (auth.user?['genres'] as List<dynamic>? ?? const [])
        .map((entry) => '$entry')
        .where((entry) => entry.trim().isNotEmpty)
        .toList();
    final initial = userGenres.isEmpty ? '' : userGenres.first;
    final controller = TextEditingController(
      text: _aiDomain.isNotEmpty ? _aiDomain : initial,
    );
    String selected = controller.text;

    final domain = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16,
        ),
        child: SafeArea(
          top: false,
          child: StatefulBuilder(
            builder: (ctx, setSheet) => ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.78,
              ),
              child: CraftHubPanel(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Scan',
                        style: Theme.of(ctx).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Choose the project domain you want the AI to scan for.',
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          hintText:
                              'Enter a domain like AI / ML, Flutter, Cybersecurity',
                        ),
                        onChanged: (value) => selected = value,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: kProjectGenres
                            .map(
                              (genre) => ActionChip(
                                label: Text(genre),
                                onPressed: () {
                                  controller.text = genre;
                                  selected = genre;
                                  setSheet(() {});
                                },
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(ctx, selected.trim()),
                          child: const Text('Scan Now'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    controller.dispose();
    if (!mounted || domain == null || domain.trim().isEmpty) return;
    await _runAiScan(domain.trim());
  }

  Future<void> _runAiScan(String domain) async {
    setState(() {
      _aiScanning = true;
      _aiDomain = domain;
    });
    try {
      final data = await context.read<AuthController>().api.aiMatchScan(domain);
      if (!mounted) return;
      setState(() {
        _aiUsers = (data['users'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        _aiProjects = (data['projects'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        _aiSummary = (data['summary'] as String? ?? '').trim();
        _aiScanning = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _aiScanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.read<AuthController>().api.friendlyError(e)),
        ),
      );
    }
  }

  void _openUser(dynamic rawId) {
    final userId = _text(rawId);
    if (userId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserProfileScreen(userId: userId)),
    );
  }

  // ignore: unused_element
  Widget _buildFeaturedMatch() {
    if (_matches.isEmpty) {
      return const CraftHubPanel(
        child: Text(
          'Add more genres and projects to improve your match results.',
        ),
      );
    }

    final user = _matches.first;
    final shared = _sharedCategories(user);
    final percent = _matchPercent(user);

    return CraftHubPanel(
      padding: const EdgeInsets.all(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  CraftHubColors.cyan.withValues(alpha: 0.18),
                  CraftHubColors.purple.withValues(alpha: 0.24),
                  CraftHubColors.panelAlt.withValues(alpha: 0.98),
                ],
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatar(
                  imageUrl: context.read<AuthController>().api.assetUrl(
                    user['avatarUrl'] as String?,
                  ),
                  radius: 40,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CraftHubTag(label: '$percent% AI MATCH', highlight: true),
                      const SizedBox(height: 10),
                      Text(
                        _text(user['name'], 'Creator'),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _roleLabel(user),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: CraftHubColors.cyan,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('@${_text(user['username'])}'),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _openUser(user['id']),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _text(
                    user['bio'],
                    'Potential collaborator with overlapping categories and active project interests.',
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (shared.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final value in shared.take(3))
                        CraftHubTag(label: value),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _openUser(user['id']),
                        icon: const Icon(Icons.favorite_rounded),
                        label: const Text('View Match'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    CraftHubIconBubble(
                      icon: Icons.group_add_outlined,
                      active: true,
                      onTap: () => _openUser(user['id']),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingList() {
    if (_incoming.isEmpty) {
      return const CraftHubPanel(
        child: Text('No incoming collaboration requests right now.'),
      );
    }
    final api = context.read<AuthController>().api;
    return Column(
      children: _incoming.map((request) {
        final from = _map(request['fromUserId']);
        final waiting = _text(request['status']) == 'accepted';
        final requestId = _text(request['id']);
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: CraftHubPanel(
            child: Row(
              children: [
                UserAvatar(
                  imageUrl: api.assetUrl(from['avatarUrl'] as String?),
                  radius: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_text(from['name'], 'User')),
                      const SizedBox(height: 4),
                      Text(_requestSummary(request, waiting: waiting)),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!waiting)
                      IconButton(
                        onPressed: requestId.isEmpty
                            ? null
                            : () => _reject(requestId),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    FilledButton(
                      onPressed: requestId.isEmpty
                          ? null
                          : () => _accept(requestId),
                      child: Text(waiting ? 'Complete' : 'Accept'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOutgoingList() {
    if (_outgoing.isEmpty) {
      return const CraftHubPanel(
        child: Text('No outgoing collaboration requests at the moment.'),
      );
    }
    final api = context.read<AuthController>().api;
    return Column(
      children: _outgoing.map((request) {
        final to = _map(request['toUserId']);
        final needsConfirm = _text(request['status']) == 'accepted';
        final requestId = _text(request['id']);
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: CraftHubPanel(
            child: Row(
              children: [
                UserAvatar(
                  imageUrl: api.assetUrl(to['avatarUrl'] as String?),
                  radius: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_text(to['name'], 'User')),
                      const SizedBox(height: 4),
                      Text(
                        needsConfirm
                            ? 'They accepted earlier. Finish connecting this collaboration.'
                            : 'Waiting for their response.',
                      ),
                    ],
                  ),
                ),
                needsConfirm
                    ? FilledButton(
                        onPressed: requestId.isEmpty
                            ? null
                            : () => _accept(requestId),
                        child: const Text('Complete'),
                      )
                    : const CraftHubTag(label: 'PENDING'),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCollaborationProjects() {
    if (_collaborationProjects.isEmpty) {
      return const CraftHubPanel(
        child: Text('Connected project collaborations will appear here.'),
      );
    }
    return Column(
      children: _collaborationProjects.map((project) {
        final workspace = _map(project['workspace']);
        final projectId = _text(project['id']);
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: CraftHubPanel(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_text(project['title'], 'Project')),
              subtitle: Text(
                '${(workspace['totalContributionCount'] as num?)?.toInt() ?? 0} contributions • ${(project['memberCount'] as num?)?.toInt() ?? 1}/4 members',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: projectId.isEmpty ? null : () => _openProject(projectId),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMatchesList() {
    if (_matches.isEmpty) {
      return const CraftHubPanel(
        child: Text('No match profiles are available right now.'),
      );
    }
    final api = context.read<AuthController>().api;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: _matches.map((user) {
        final shared = _sharedCategories(user);
        final userId = _text(user['id']);
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: CraftHubPanel(
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: userId.isEmpty ? null : () => _openUser(userId),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      UserAvatar(
                        imageUrl: api.assetUrl(user['avatarUrl'] as String?),
                        radius: 26,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _text(user['name'], 'User'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _roleLabel(user),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: CraftHubColors.cyan,
                                    letterSpacing: 0.9,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      CraftHubTag(
                        label: '${_matchPercent(user)}%',
                        highlight: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _text(
                      user['bio'],
                      'Open to collaborations and shared project building.',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (shared.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: shared
                          .take(3)
                          .map((value) => CraftHubTag(label: value))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAiResults() {
    if (_aiScanning) {
      return const CraftHubPanel(
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text('CraftBro AI is scanning profiles and projects...'),
            ),
          ],
        ),
      );
    }

    if (_aiDomain.isEmpty) return const SizedBox.shrink();

    final hasResults = _aiUsers.isNotEmpty || _aiProjects.isNotEmpty;
    return CraftHubPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('AI Scan', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              CraftHubTag(label: _aiDomain, highlight: true),
            ],
          ),
          if (_aiSummary.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(_aiSummary),
          ],
          const SizedBox(height: 14),
          if (!hasResults)
            const Text('No strong AI matches were found for this domain yet.')
          else ...[
            if (_aiUsers.isNotEmpty) ...[
              Text('Profiles', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 10),
              ..._aiUsers
                  .take(3)
                  .map(
                    (user) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AiResultCard(
                        title: _text(user['name'], 'User'),
                        subtitle: '@${_text(user['username'])}',
                        percent: (user['matchPercent'] as num?)?.toInt() ?? 0,
                        reason: _text(user['matchReason']),
                        onTap: () => _openUser(user['id']),
                      ),
                    ),
                  ),
            ],
            if (_aiProjects.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Projects', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 10),
              ..._aiProjects
                  .take(3)
                  .map(
                    (project) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AiResultCard(
                        title: _text(project['title'], 'Project'),
                        subtitle: _text(project['description']),
                        percent:
                            (project['matchPercent'] as num?)?.toInt() ?? 0,
                        reason: _text(project['matchReason']),
                        onTap: () => _openProject(_text(project['id'])),
                      ),
                    ),
                  ),
            ],
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = CraftHubPalette.of(context);
    try {
      if (_loading) {
        return const Center(child: CircularProgressIndicator());
      }

      return DefaultTabController(
        length: 4,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.panelAlt.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Matchmaking',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _aiDomain.isEmpty
                              ? 'Scan by domain or browse live matches.'
                              : 'Showing AI scan context for $_aiDomain.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _aiScanning ? null : _promptAiScan,
                        icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                        label: const Text('AI Scan'),
                      ),
                      const SizedBox(height: 8),
                      CraftHubTag(
                        label: '${_matches.length} Matches',
                        highlight: _matches.isNotEmpty,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              transitionBuilder: (child, animation) {
                final offset = Tween<Offset>(
                  begin: const Offset(0, 0.06),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: offset, child: child),
                );
              },
              child: (_aiScanning || _aiDomain.isNotEmpty)
                  ? KeyedSubtree(
                      key: ValueKey(
                        'ai-$_aiDomain-${_aiScanning ? 'loading' : 'ready'}',
                      ),
                      child: _buildAiResults(),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: palette.panelAlt.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: palette.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: Theme.of(context).brightness == Brightness.dark
                          ? 0.14
                          : 0.06,
                    ),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: TabBar(
                controller: _controller,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                unselectedLabelStyle: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: CraftHubColors.accent,
                  boxShadow: [
                    BoxShadow(
                      color: CraftHubColors.lavender.withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                labelColor: const Color(0xFF220A30),
                unselectedLabelColor: palette.muted,
                tabs: const [
                  Tab(text: 'Matches'),
                  Tab(text: 'Inbox'),
                  Tab(text: 'Sent'),
                  Tab(text: 'Collabs'),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 480,
              child: TabBarView(
                controller: _controller,
                children: [
                  _buildMatchesList(),
                  ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [_buildIncomingList()],
                  ),
                  ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [_buildOutgoingList()],
                  ),
                  ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [_buildCollaborationProjects()],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          Text(
            'Matchmaking',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          CraftHubPanel(child: Text('The match screen hit a data issue: $e')),
        ],
      );
    }
  }
}

class _AiResultCard extends StatelessWidget {
  const _AiResultCard({
    required this.title,
    required this.subtitle,
    required this.percent,
    required this.reason,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final int percent;
  final String reason;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CraftHubColors.panelAlt.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: CraftHubColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                CraftHubTag(label: '$percent%', highlight: true),
              ],
            ),
            if (subtitle.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            if (reason.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(reason, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

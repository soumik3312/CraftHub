import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/craft_hub_theme.dart';
import '../../providers/auth_controller.dart';
import '../../widgets/craft_hub_ui.dart';
import '../../widgets/user_avatar.dart';
import '../projects/project_detail_screen.dart';

class CollabHubTab extends StatefulWidget {
  const CollabHubTab({
    super.key,
    required this.unreadCount,
    required this.onOpenChats,
    required this.onOpenMatch,
  });

  final int unreadCount;
  final VoidCallback onOpenChats;
  final VoidCallback onOpenMatch;

  @override
  State<CollabHubTab> createState() => _CollabHubTabState();
}

class _CollabHubTabState extends State<CollabHubTab> {
  List<Map<String, dynamic>> _projects = [];
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _matches = [];
  List<Map<String, dynamic>> _incoming = [];
  List<Map<String, dynamic>> _outgoing = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
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

  Future<void> _load() async {
    final api = context.read<AuthController>().api;
    setState(() => _loading = true);
    final results = await Future.wait<Map<String, dynamic>>([
      _safeJson(api.myProjects()),
      _safeJson(api.conversations()),
      _safeJson(api.matchUsers()),
      _safeJson(api.incomingCollab()),
      _safeJson(api.outgoingCollab()),
    ]);
    if (!mounted) return;

    final projectData = results[0];
    final conversationsData = results[1];
    final matchesData = results[2];
    final incomingData = results[3];
    final outgoingData = results[4];
    final merged = <Map<String, dynamic>>[
      ..._mapList(projectData['owned']),
      ..._mapList(projectData['collaborating']),
    ];
    final seen = <String>{};
    final collaborations = merged.where((project) {
      final id = project['id'] as String?;
      if (id == null || seen.contains(id)) return false;
      seen.add(id);
      return ((project['memberCount'] as num?)?.toInt() ?? 1) > 1 ||
          (project['collaborators'] as List<dynamic>? ?? []).isNotEmpty;
    }).toList();

    setState(() {
      _projects = collaborations;
      _conversations = _mapList(conversationsData['conversations']);
      _matches = _mapList(matchesData['users']);
      _incoming = _mapList(incomingData['requests']);
      _outgoing = _mapList(outgoingData['requests']);
      _loading = false;
    });
  }

  Future<void> _openRepo(Map<String, dynamic> project) async {
    final workspace = _map(project['workspace']);
    final url = _text(workspace['repoUrl']);
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openProject(Map<String, dynamic> project) async {
    final projectId = _text(project['id']);
    if (projectId.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectDetailScreen(projectId: projectId),
      ),
    );
    await _load();
  }

  Future<void> _accept(String id) async {
    try {
      final res = await context.read<AuthController>().api.acceptCollab(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] as String? ?? 'Updated')),
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

  List<Map<String, dynamic>> _recentActivities() {
    final activities = <Map<String, dynamic>>[];
    for (final project in _projects.take(3)) {
      final workspace = _map(project['workspace']);
      final contributions = _mapList(workspace['contributions']);
      for (final entry in contributions.take(2)) {
        final userId = _text(entry['userId']);
        String name = 'A collaborator';
        final owner = _map(project['owner']);
        final collaborators = _mapList(project['collaborators']);
        if (_text(owner['id']) == userId) {
          name = _text(owner['name'], name);
        } else {
          for (final collaborator in collaborators) {
            if (_text(collaborator['id']) == userId) {
              name = _text(collaborator['name'], name);
            }
          }
        }
        activities.add({
          'title':
              '$name pushed ${(entry['commitCount'] as num?)?.toInt() ?? 0} contributions',
          'subtitle': _text(project['title'], 'Project'),
          'time': _text(entry['lastSavedAt']),
        });
      }
    }
    if (activities.isEmpty) {
      for (final conversation in _conversations.take(3)) {
        activities.add({
          'title': _text(
            conversation['lastMessageText'],
            'Conversation is ready',
          ),
          'subtitle': _text(conversation['name'], 'Chat'),
          'time': _text(conversation['lastMessageAt']),
        });
      }
    }
    return activities.take(4).toList();
  }

  String _timeAgo(String raw) {
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes} mins ago';
    if (diff.inDays < 1) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }

  int _teamPulseValue() {
    return _projects.fold<int>(0, (sum, project) {
      final workspace = _map(project['workspace']);
      return sum +
          ((workspace['totalContributionCount'] as num?)?.toInt() ?? 0);
    });
  }

  Widget _teamPulseSection() {
    final total = _teamPulseValue();
    final bars = List<double>.generate(7, (index) {
      final seed = (total + (index * 5)) % 24;
      return 0.22 + (seed / 40);
    });
    return CraftHubPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Team Pulse', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              Text(
                total == 0 ? '+0%' : '+${(total / 10).toStringAsFixed(1)}%',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xFFA9F27F)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (int index = 0; index < bars.length; index++)
                  Container(
                    width: 18,
                    height: 110 * bars[index],
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: index == 3
                          ? CraftHubColors.lavender
                          : CraftHubColors.lavender.withValues(alpha: 0.38),
                      boxShadow: index == 3
                          ? [
                              BoxShadow(
                                color: CraftHubColors.purple.withValues(
                                  alpha: 0.35,
                                ),
                                blurRadius: 18,
                              ),
                            ]
                          : null,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Column(
              children: [
                Text(
                  '$total',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  'PRS REVIEWED THIS WEEK',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _requestSection() {
    if (_incoming.isEmpty && _outgoing.isEmpty) {
      return const SizedBox.shrink();
    }
    return CraftHubPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Collab Requests',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 14),
          ..._incoming.take(2).map((request) {
            final from = _map(request['fromUserId']);
            final waiting = _text(request['status']) == 'accepted';
            final project = _map(request['project']);
            final requestId = _text(request['id']);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  UserAvatar(
                    imageUrl: context.read<AuthController>().api.assetUrl(
                      from['avatarUrl'] as String?,
                    ),
                    radius: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _text(from['name'], 'User'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(_text(project['title'], 'Collaboration request')),
                      ],
                    ),
                  ),
                  ...[
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
                ],
              ),
            );
          }),
          ..._outgoing
              .where((request) => _text(request['status']) == 'accepted')
              .take(1)
              .map((request) {
                final to = _map(request['toUserId']);
                final requestId = _text(request['id']);
                return Row(
                  children: [
                    UserAvatar(
                      imageUrl: context.read<AuthController>().api.assetUrl(
                        to['avatarUrl'] as String?,
                      ),
                      radius: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${_text(to['name'], 'User')} accepted earlier. Complete the connection to finish setup.',
                      ),
                    ),
                    FilledButton(
                      onPressed: requestId.isEmpty
                          ? null
                          : () => _accept(requestId),
                      child: const Text('Complete'),
                    ),
                  ],
                );
              }),
        ],
      ),
    );
  }

  Widget _matchSection() {
    if (_matches.isEmpty) return const SizedBox.shrink();
    return CraftHubPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recommended Matches',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 14),
          ..._matches.take(3).map((user) {
            final shared =
                (user['sharedCategories'] is List
                        ? user['sharedCategories'] as List
                        : const [])
                    .map((e) => '$e')
                    .take(2)
                    .join(', ');
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: UserAvatar(
                  imageUrl: context.read<AuthController>().api.assetUrl(
                    user['avatarUrl'] as String?,
                  ),
                  radius: 22,
                ),
                title: Text(_text(user['name'], 'User')),
                subtitle: Text(
                  shared.isEmpty
                      ? '@${_text(user['username'])}'
                      : '$shared\n@${_text(user['username'])}',
                ),
                isThreeLine: shared.isNotEmpty,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: widget.onOpenMatch,
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    try {
      final activities = _recentActivities();
      if (_loading) {
        return const Center(child: CircularProgressIndicator());
      }

      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            const CraftHubSectionTitle(
              eyebrow: 'Collaboration Hub',
              title: 'Building the future, together.',
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Text(
                  'Your Ongoing Collaborations',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: CraftHubColors.lavender,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: widget.onOpenMatch,
                  child: const Text('VIEW ALL'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_projects.isEmpty)
              const CraftHubPanel(
                child: Text(
                  'Accepted collaborations and shared workspaces will appear here.',
                ),
              )
            else
              ..._projects.take(3).map((project) {
                final workspace = _map(project['workspace']);
                final repoReady = _text(workspace['repoUrl']).isNotEmpty;
                final memberCount =
                    (project['memberCount'] as num?)?.toInt() ?? 1;
                final totalContributions =
                    (workspace['totalContributionCount'] as num?)?.toInt() ?? 0;
                final collaborators = [
                  if (_map(project['owner']).isNotEmpty) _map(project['owner']),
                  ..._mapList(project['collaborators']),
                ];
                final progress = memberCount <= 1
                    ? 0.24
                    : (memberCount / 4).clamp(0.25, 1.0);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: CraftHubPanel(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(28),
                      onTap: () => _openProject(project),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CraftHubTag(
                                label: repoReady ? 'ACTIVE' : 'SETUP',
                                highlight: repoReady,
                              ),
                              const Spacer(),
                              Icon(
                                repoReady
                                    ? Icons.rocket_launch_outlined
                                    : Icons.code_off_outlined,
                                color: CraftHubColors.muted,
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            _text(project['title'], 'Project'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _text(
                              project['description'],
                              'Shared workspace for your collaboration team.',
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              SizedBox(
                                height: 28,
                                child: Stack(
                                  children: [
                                    for (
                                      int index = 0;
                                      index < collaborators.take(3).length;
                                      index++
                                    )
                                      Positioned(
                                        left: index * 20,
                                        child: UserAvatar(
                                          imageUrl: context
                                              .read<AuthController>()
                                              .api
                                              .assetUrl(
                                                collaborators[index]['avatarUrl']
                                                    as String?,
                                              ),
                                          radius: 14,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 70),
                              Text('$memberCount/4 members'),
                              const Spacer(),
                              Text('$totalContributions contributions'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              backgroundColor: CraftHubColors.border,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                CraftHubColors.lavender,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 16),
            _requestSection(),
            if (_incoming.isNotEmpty || _outgoing.isNotEmpty)
              const SizedBox(height: 16),
            const SizedBox(height: 12),
            Text(
              'Recent Activities',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            CraftHubPanel(
              child: Column(
                children: [
                  if (activities.isEmpty)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'New collaboration activity will appear here.',
                      ),
                    )
                  else
                    for (final activity in activities)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CraftHubIconBubble(
                              icon: Icons.auto_awesome_rounded,
                              size: 42,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _text(activity['title']),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: CraftHubColors.text,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(_text(activity['subtitle'])),
                                  if (_text(activity['time']).isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        _timeAgo(_text(activity['time'])),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _matchSection(),
            if (_matches.isNotEmpty) const SizedBox(height: 20),
            Text(
              'Quick Access',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            CraftHubPanel(
              child: Column(
                children: [
                  _QuickTile(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: widget.unreadCount > 0
                        ? 'Chat (${widget.unreadCount})'
                        : 'Chat',
                    subtitle: 'Open direct messages and workspaces',
                    onTap: widget.onOpenChats,
                  ),
                  const SizedBox(height: 12),
                  _QuickTile(
                    icon: Icons.open_in_new_rounded,
                    title: 'GitHub',
                    subtitle:
                        'Open the shared repo for your latest collaboration',
                    onTap: _projects.isEmpty
                        ? null
                        : () => _openRepo(_projects.first),
                  ),
                  const SizedBox(height: 12),
                  _QuickTile(
                    icon: Icons.code_rounded,
                    title: 'Workspace',
                    subtitle: 'Jump into the shared project topic and editor',
                    onTap: _projects.isEmpty
                        ? null
                        : () => _openProject(_projects.first),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _teamPulseSection(),
          ],
        ),
      );
    } catch (e) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            const CraftHubSectionTitle(
              eyebrow: 'Collaboration Hub',
              title: 'Building the future, together.',
            ),
            const SizedBox(height: 18),
            CraftHubPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'The collaboration screen hit a data issue, but the tab is still available now.',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Details: $e',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton(
                        onPressed: _load,
                        child: const Text('Reload'),
                      ),
                      OutlinedButton(
                        onPressed: widget.onOpenMatch,
                        child: const Text('Open Match'),
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
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CraftHubColors.panelAlt.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: CraftHubColors.border),
        ),
        child: Row(
          children: [
            CraftHubIconBubble(icon: icon, active: onTap != null),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: CraftHubColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

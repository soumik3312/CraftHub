import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_controller.dart';
import '../../widgets/user_avatar.dart';

class SendProjectInviteSheet extends StatefulWidget {
  const SendProjectInviteSheet({super.key, required this.projectId});

  final String projectId;

  @override
  State<SendProjectInviteSheet> createState() => _SendProjectInviteSheetState();
}

class _SendProjectInviteSheetState extends State<SendProjectInviteSheet> {
  List<dynamic> _users = [];
  final _msg = TextEditingController();
  final _repoName = TextEditingController();
  bool _loading = true;
  String _projectTitle = 'this project';
  int _memberCount = 1;
  int _slotsLeft = 3;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _msg.dispose();
    _repoName.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<AuthController>().api;
      final results = await Future.wait<dynamic>([
        api.matchUsers(),
        api.project(widget.projectId),
      ]);
      final users = results[0] as Map<String, dynamic>;
      final projectResponse = results[1] as Map<String, dynamic>;
      final project =
          projectResponse['project'] as Map<String, dynamic>? ??
          const <String, dynamic>{};
      final workspace =
          project['workspace'] as Map<String, dynamic>? ??
          const <String, dynamic>{};

      if (!mounted) return;
      _repoName.text = (workspace['requestedRepoName'] as String? ?? '').trim();
      setState(() {
        _users = users['users'] as List<dynamic>? ?? [];
        _projectTitle = (project['title'] as String? ?? 'this project').trim();
        _memberCount =
            (project['memberCount'] as num?)?.toInt() ??
            ((project['collaborators'] as List<dynamic>? ?? []).length + 1);
        _slotsLeft =
            (project['slotsLeft'] as num?)?.toInt() ?? (4 - _memberCount);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _invite(String toId) async {
    if (_slotsLeft <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This project already has the maximum 4 members.'),
        ),
      );
      return;
    }

    final api = context.read<AuthController>().api;
    try {
      final repoName = _repoName.text.trim();
      if (repoName.isNotEmpty) {
        await api.setWorkspaceRepoName(widget.projectId, repoName);
      }
      await api.sendCollabRequest(
        toUserId: toId,
        type: 'project_invite',
        projectId: widget.projectId,
        message: _msg.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Invite sent for $_projectTitle. Once they accept, the collaboration will connect and workspace setup will begin.',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      final message = api.friendlyError(e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final api = context.watch<AuthController>().api;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: pad.bottom + 16,
      ),
      child: _loading
          ? const SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Invite collaborator',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '$_memberCount/4 members in this project',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _repoName,
                  decoration: InputDecoration(
                    labelText: 'Shared repository name',
                    hintText: _projectTitle.isEmpty
                        ? 'repo name'
                        : _projectTitle,
                  ),
                ),
                TextField(
                  controller: _msg,
                  decoration: const InputDecoration(
                    labelText: 'Message (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                if (_slotsLeft <= 0)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'This project is full. A maximum of 4 people can collaborate in one shared repository.',
                    ),
                  ),
                SizedBox(
                  height: 280,
                  child: ListView.builder(
                    itemCount: _users.length,
                    itemBuilder: (ctx, i) {
                      final u = _users[i] as Map<String, dynamic>;
                      final shared =
                          (u['sharedCategories'] as List<dynamic>? ?? [])
                              .map((e) => '$e')
                              .where((e) => e.isNotEmpty)
                              .toList();
                      return ListTile(
                        leading: UserAvatar(
                          imageUrl: api.assetUrl(u['avatarUrl'] as String?),
                          radius: 20,
                        ),
                        title: Text(u['name'] as String? ?? ''),
                        subtitle: Text(
                          shared.isEmpty
                              ? '@${u['username'] ?? ''}'
                              : '${shared.join(', ')}\n@${u['username'] ?? ''}',
                        ),
                        isThreeLine: shared.isNotEmpty,
                        trailing: FilledButton(
                          onPressed: _slotsLeft <= 0
                              ? null
                              : () => _invite(u['id'] as String),
                          child: const Text('Invite'),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_config.dart';
import '../../core/craft_hub_theme.dart';
import '../../core/project_tech_stack.dart';
import '../../core/url_utils.dart';
import '../../providers/auth_controller.dart';
import '../../widgets/craft_hub_ui.dart';
import '../../widgets/user_avatar.dart';
import '../collab/send_project_invite_sheet.dart';
import '../messages/chat_room_screen.dart';
import '../profile/github_connect_screen.dart';
import '../profile/user_profile_screen.dart';
import 'github_workspace_screen.dart';

class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({
    super.key,
    required this.projectId,
    this.openInviteOnLoad = false,
  });

  final String projectId;
  final bool openInviteOnLoad;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  Map<String, dynamic>? _p;
  bool _loading = true;
  bool _inviteOpened = false;
  bool _uploadingImages = false;
  bool _creatingWorkspace = false;
  String _lastWorkspaceAutoCreateKey = '';
  final PageController _coverController = PageController();
  int _coverIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _coverController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = context.read<AuthController>().api;
    setState(() => _loading = true);
    try {
      final d = await api.project(widget.projectId);
      setState(() {
        _p = d['project'] as Map<String, dynamic>?;
        _loading = false;
      });
      _maybeOpenInviteSheet();
      _maybeAutoCreateWorkspace();
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _maybeOpenInviteSheet() {
    if (!widget.openInviteOnLoad || _inviteOpened || _p == null) return;
    final me = context.read<AuthController>().user?['id'] as String?;
    final owner = _p!['owner'] as Map<String, dynamic>? ?? {};
    if (owner['id'] != me) return;
    _inviteOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => SendProjectInviteSheet(projectId: widget.projectId),
      );
    });
  }

  Future<void> _launchExternalLink(Uri? uri, String failureLabel) async {
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$failureLabel link is invalid.')));
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the $failureLabel link.')),
      );
    }
  }

  Future<void> _requestCollabForProject() async {
    final owner = _p?['owner'] as Map<String, dynamic>? ?? {};
    final ownerId = owner['id'] as String?;
    final title = _p?['title'] as String? ?? 'this project';
    if (ownerId == null) return;
    try {
      await context.read<AuthController>().api.sendCollabRequest(
        toUserId: ownerId,
        type: 'project_request',
        projectId: widget.projectId,
        message: 'I would like to collaborate on "$title".',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Project collab request sent. Workspace setup begins once the other side accepts.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = context.read<AuthController>().api.friendlyError(e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
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

      if (result == null || !mounted) return;
      if (result.success) {
        await auth.refreshMe();
        await _load();
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.message)));
      }
    } catch (e) {
      if (!mounted) return;
      final message = auth.api.friendlyError(e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _createWorkspace() async {
    if (_creatingWorkspace) return;
    _creatingWorkspace = true;
    try {
      final data = await context
          .read<AuthController>()
          .api
          .createProjectWorkspace(widget.projectId);
      if (!mounted) return;
      final project = data['project'] as Map<String, dynamic>?;
      if (project != null) {
        setState(() => _p = project);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GitHub workspace created for this project.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = context.read<AuthController>().api.friendlyError(e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      _creatingWorkspace = false;
    }
  }

  Future<void> _maybeAutoCreateWorkspace() async {
    final project = _p;
    final me = context.read<AuthController>().user?['id'] as String?;
    if (project == null || me == null || _creatingWorkspace) return;

    final owner = project['owner'] as Map<String, dynamic>? ?? const {};
    final isOwner = owner['id'] == me;
    if (!isOwner) return;

    final collaborators = (project['collaborators'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    if (collaborators.isEmpty) return;

    final workspace =
        project['workspace'] as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final workspaceRepoUrl = (workspace['repoUrl'] as String? ?? '').trim();
    if (workspaceRepoUrl.isNotEmpty) return;

    final githubConnected =
        context.read<AuthController>().user?['githubConnected'] == true;
    if (!githubConnected) return;

    final missingGithubCollaborators = collaborators
        .where(
          (c) =>
              c['githubConnected'] != true ||
              (c['githubUsername'] as String? ?? '').trim().isEmpty,
        )
        .length;
    if (missingGithubCollaborators > 0) return;

    final autoCreateKey =
        '${project['id']}:${workspace['conversationId'] ?? ''}:${collaborators.length}:${workspace['requestedRepoName'] ?? ''}';
    if (_lastWorkspaceAutoCreateKey == autoCreateKey) return;
    _lastWorkspaceAutoCreateKey = autoCreateKey;

    _creatingWorkspace = true;
    try {
      final data = await context
          .read<AuthController>()
          .api
          .createProjectWorkspace(widget.projectId);
      if (!mounted) return;
      final updatedProject = data['project'] as Map<String, dynamic>?;
      if (updatedProject != null) {
        setState(() => _p = updatedProject);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shared repo and workspace are ready.')),
      );
    } catch (_) {
      // Leave the manual action visible if auto-creation does not succeed.
    } finally {
      _creatingWorkspace = false;
    }
  }

  Future<void> _deleteProject() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete project?'),
        content: const Text(
          'This will permanently remove the project from Craft Hub. This action cannot be undone.',
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

    if (confirmed != true || !mounted) return;

    final api = context.read<AuthController>().api;
    try {
      await api.deleteProject(widget.projectId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Project deleted.')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      final message = api.friendlyError(e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _openWorkspace(String url, String title) async {
    final token = context.read<AuthController>().token;
    if (!mounted || url.isEmpty || token == null || token.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GitHubWorkspaceScreen(
          title: title,
          projectId: widget.projectId,
          repoUrl: url,
          apiBaseUrl: ApiConfig.baseUrl,
          authToken: token,
        ),
      ),
    );
  }

  Future<void> _openImageGallery(
    List<String> images, {
    int initialIndex = 0,
  }) async {
    if (images.isEmpty) return;
    final controller = PageController(initialPage: initialIndex);
    var currentIndex = initialIndex;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.96),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialog) => Dialog.fullscreen(
            backgroundColor: Colors.transparent,
            child: Stack(
              children: [
                Positioned.fill(
                  child: PageView.builder(
                    controller: controller,
                    itemCount: images.length,
                    onPageChanged: (value) {
                      setDialog(() => currentIndex = value);
                    },
                    itemBuilder: (context, index) {
                      return InteractiveViewer(
                        minScale: 0.9,
                        maxScale: 4,
                        child: Center(
                          child: CachedNetworkImage(
                            imageUrl: images[index],
                            fit: BoxFit.contain,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            errorWidget: (context, url, error) => const Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white70,
                              size: 54,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: SafeArea(
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withValues(
                              alpha: 0.44,
                            ),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.42),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${currentIndex + 1}/${images.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    controller.dispose();
  }

  Future<void> _setWorkspaceRepoName(String currentValue) async {
    final api = context.read<AuthController>().api;
    final controller = TextEditingController(text: currentValue);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Shared repository name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'same name used for the shared repo',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;

    try {
      final data = await api.setWorkspaceRepoName(widget.projectId, value);
      final project = data['project'] as Map<String, dynamic>?;
      if (!mounted) return;
      if (project != null) {
        setState(() => _p = project);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Shared repository name set to "$value".')),
      );
    } catch (e) {
      if (!mounted) return;
      final message = api.friendlyError(e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _openProjectChat(String conversationId, String title) async {
    if (!mounted || conversationId.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          conversationId: conversationId,
          title: title,
          projectId: widget.projectId,
        ),
      ),
    );
  }

  Future<void> _addProjectPhotos() async {
    final picks = await ImagePicker().pickMultiImage(imageQuality: 90);
    if (picks.isEmpty || !mounted) return;

    setState(() => _uploadingImages = true);
    final files = picks.map((file) => File(file.path)).toList();
    final api = context.read<AuthController>().api;
    try {
      final data = await api.updateProject(widget.projectId, newImages: files);
      final project = data['project'] as Map<String, dynamic>?;
      if (!mounted) return;
      if (project != null) {
        setState(() => _p = project);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            files.length == 1
                ? 'Project photo added.'
                : '${files.length} project photos added.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = api.friendlyError(e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _uploadingImages = false);
      }
    }
  }

  int _contributionCountFor(
    List<Map<String, dynamic>> contributions,
    String? userId,
  ) {
    if (userId == null || userId.isEmpty) return 0;
    for (final entry in contributions) {
      if ((entry['userId'] as String? ?? '') == userId) {
        return (entry['commitCount'] as num?)?.toInt() ?? 0;
      }
    }
    return 0;
  }

  List<Map<String, String>> _activityFeed(
    Map<String, dynamic> owner,
    List<Map<String, dynamic>> collabs,
    List<Map<String, dynamic>> contributions,
  ) {
    String userName(String? userId) {
      if (userId == null || userId.isEmpty) return 'collaborator';
      if ((owner['id'] as String? ?? '') == userId) {
        return owner['username'] as String? ??
            owner['name'] as String? ??
            'owner';
      }
      for (final user in collabs) {
        if ((user['id'] as String? ?? '') == userId) {
          return user['username'] as String? ??
              user['name'] as String? ??
              'collaborator';
        }
      }
      return 'collaborator';
    }

    final items = contributions.take(3).map((entry) {
      final filePath = (entry['lastFilePath'] as String? ?? '').trim();
      final commitCount = (entry['commitCount'] as num?)?.toInt() ?? 0;
      final savedAt = (entry['lastSavedAt'] as String? ?? '').trim();
      return {
        'title': userName(entry['userId'] as String?),
        'subtitle': commitCount == 1
            ? 'Saved 1 contribution${filePath.isEmpty ? '' : ' in $filePath'}'
            : 'Saved $commitCount contributions${filePath.isEmpty ? '' : ' in $filePath'}',
        'time': savedAt,
      };
    }).toList();

    if (items.isNotEmpty) return items;
    return [
      {
        'title': owner['username'] as String? ?? 'owner',
        'subtitle':
            'Project workspace is ready for your first collaboration update.',
        'time': '',
      },
      {
        'title': 'system',
        'subtitle':
            'Invite collaborators or connect GitHub to unlock the shared repo flow.',
        'time': '',
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final api = auth.api;
    final me = auth.user?['id'] as String?;
    final palette = CraftHubPalette.of(context);

    if (_loading || _p == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final p = _p!;
    final owner = p['owner'] as Map<String, dynamic>? ?? {};
    final collabs = (p['collaborators'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final imgs =
        (p['imageUrls'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final src = p['sourceFile'] as Map<String, dynamic>?;
    final url = src?['url'] as String?;
    final githubUrl = (p['githubUrl'] as String? ?? '').trim();
    final workspace =
        p['workspace'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final workspaceRepoUrl = (workspace['repoUrl'] as String? ?? '').trim();
    final workspaceConversationId =
        (workspace['conversationId'] as String? ?? '').trim();
    final workspaceFullName = (workspace['repoFullName'] as String? ?? '')
        .trim();
    final workspaceRequestedRepoName =
        (workspace['requestedRepoName'] as String? ?? '').trim();
    final workspaceContributions =
        (workspace['contributions'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
    final totalContributionCount =
        (workspace['totalContributionCount'] as num?)?.toInt() ?? 0;

    final isOwner = owner['id'] == me;
    final isCollab = collabs.any((c) => c['id'] == me);
    final memberCount =
        (p['memberCount'] as num?)?.toInt() ?? (collabs.length + 1);
    final teamFull = memberCount >= 4;
    final myContributionCount = _contributionCountFor(
      workspaceContributions,
      me,
    );
    final githubConnected = auth.user?['githubConnected'] == true;
    final missingGithubCollaborators = collabs
        .where(
          (c) =>
              c['githubConnected'] != true ||
              (c['githubUsername'] as String? ?? '').trim().isEmpty,
        )
        .map((c) => c['name'] as String? ?? 'Collaborator')
        .toList();

    final activityFeed = _activityFeed(owner, collabs, workspaceContributions);
    final techStack = projectTechForIds(p['techStack'] as List? ?? const []);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CraftHubBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 40),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      const BackButton(),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: CraftHubGradientText(
                          'Craft Hub',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (isOwner)
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded),
                          tooltip: 'Delete project',
                          onPressed: _deleteProject,
                        ),
                      if ((isOwner || isCollab) && !teamFull)
                        IconButton(
                          icon: const Icon(Icons.person_add_alt_1),
                          onPressed: () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (ctx) => SendProjectInviteSheet(
                              projectId: widget.projectId,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                CraftHubPanel(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (imgs.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: SizedBox(
                            height: 260,
                            child: Stack(
                              children: [
                                PageView.builder(
                                  controller: _coverController,
                                  itemCount: imgs.length,
                                  onPageChanged: (value) {
                                    if (!mounted) return;
                                    setState(() => _coverIndex = value);
                                  },
                                  itemBuilder: (context, index) {
                                    return GestureDetector(
                                      onTap: () => _openImageGallery(
                                        imgs,
                                        initialIndex: index,
                                      ),
                                      child: CachedNetworkImage(
                                        imageUrl: imgs[index],
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            Container(
                                              color: palette.panelAlt,
                                              alignment: Alignment.center,
                                              child: const SizedBox(
                                                width: 22,
                                                height: 22,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2.2,
                                                    ),
                                              ),
                                            ),
                                        errorWidget: (context, url, error) =>
                                            Container(
                                              color: palette.panelAlt,
                                              alignment: Alignment.center,
                                              child: const Icon(
                                                Icons.broken_image_outlined,
                                              ),
                                            ),
                                      ),
                                    );
                                  },
                                ),
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.42,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '${_coverIndex.clamp(0, imgs.length - 1) + 1}/${imgs.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 12,
                                  bottom: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.4,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.open_in_full_rounded,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Tap to expand',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (imgs.length > 1) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 64,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: imgs.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, index) {
                                final selected = index == _coverIndex;
                                return GestureDetector(
                                  onTap: () {
                                    _coverController.animateToPage(
                                      index,
                                      duration: const Duration(
                                        milliseconds: 240,
                                      ),
                                      curve: Curves.easeOutCubic,
                                    );
                                    setState(() => _coverIndex = index);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: 72,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: selected
                                            ? CraftHubColors.cyan
                                            : palette.border,
                                        width: selected ? 2 : 1,
                                      ),
                                      boxShadow: selected
                                          ? [
                                              BoxShadow(
                                                color: CraftHubColors.cyan
                                                    .withValues(alpha: 0.18),
                                                blurRadius: 16,
                                                offset: const Offset(0, 8),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(17),
                                      child: CachedNetworkImage(
                                        imageUrl: imgs[index],
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ] else
                        ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Container(
                            height: 220,
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF0B3A4D), Color(0xFF191125)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.photo_library_outlined,
                                  size: 34,
                                  color: Colors.white70,
                                ),
                                SizedBox(height: 10),
                                Text(
                                  'No project images yet',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 18),
                      Text(
                        p['title'] as String? ?? 'Project',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: palette.text,
                              fontWeight: FontWeight.w900,
                              height: 1.08,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        (p['description'] as String? ?? '').trim(),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: palette.text.withValues(alpha: 0.82),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: (!isOwner && !isCollab && !teamFull)
                                ? _requestCollabForProject
                                : null,
                            icon: Icon(
                              isOwner || isCollab
                                  ? Icons.groups_rounded
                                  : Icons.person_add_alt_1_rounded,
                            ),
                            label: Text(
                              teamFull
                                  ? 'Project Full'
                                  : isOwner || isCollab
                                  ? 'Collaboration Active'
                                  : 'Request to Join',
                            ),
                          ),
                          if (workspaceRepoUrl.isNotEmpty ||
                              githubUrl.isNotEmpty)
                            OutlinedButton.icon(
                              onPressed: () => _launchExternalLink(
                                parseGithubUrl(
                                  workspaceRepoUrl.isNotEmpty
                                      ? workspaceRepoUrl
                                      : githubUrl,
                                ),
                                'GitHub repository',
                              ),
                              icon: const Icon(Icons.open_in_new_rounded),
                              label: const Text('Open GitHub'),
                            ),
                          if (isOwner || isCollab)
                            OutlinedButton.icon(
                              onPressed: workspaceRepoUrl.isNotEmpty
                                  ? () => _openWorkspace(
                                      workspaceRepoUrl,
                                      '${p['title'] ?? 'Project'} IDE',
                                    )
                                  : null,
                              icon: const Icon(Icons.code_rounded),
                              label: const Text('Add Contributions'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                CraftHubPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tech Stack',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: techStack.isNotEmpty
                            ? techStack
                                  .map(
                                    (tech) => CraftHubTag(
                                      label: tech.label,
                                      icon: tech.icon,
                                    ),
                                  )
                                  .toList()
                            : (p['genres'] as List? ?? [])
                                  .map((genre) => CraftHubTag(label: '$genre'))
                                  .toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                CraftHubPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Activity Feed',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 14),
                      ...activityFeed.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const CraftHubIconBubble(
                                icon: Icons.adjust_rounded,
                                size: 34,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['title']!,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: CraftHubColors.cyan,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(item['subtitle']!),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                CraftHubPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stats & Impact',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 14),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.9,
                        children: [
                          _StatBox(
                            value: '$totalContributionCount',
                            label: 'COMMITS',
                            color: CraftHubColors.lavender,
                          ),
                          _StatBox(
                            value: '$memberCount',
                            label: 'CONTRIBUTORS',
                            color: CraftHubColors.cyan,
                          ),
                          _StatBox(
                            value:
                                '${_followersLikeCount(collabs, workspaceContributions)}',
                            label: 'STARS',
                            color: CraftHubColors.lime,
                          ),
                          _StatBox(
                            value: '${workspaceRepoUrl.isEmpty ? 0 : 1}',
                            label: 'OPEN PRS',
                            color: palette.text,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                CraftHubPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Active Collaborators',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const Spacer(),
                          Text(
                            memberCount > 1 ? 'View All' : '',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: CraftHubColors.lavender),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: UserAvatar(
                          imageUrl: api.assetUrl(owner['avatarUrl'] as String?),
                          radius: 22,
                        ),
                        title: Text(owner['name'] as String? ?? 'Owner'),
                        subtitle: Text(
                          owner['username'] as String? ?? 'lead architect',
                        ),
                        onTap: () {
                          final id = owner['id'] as String?;
                          if (id != null && id != me) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UserProfileScreen(userId: id),
                              ),
                            );
                          }
                        },
                      ),
                      ...collabs.map(
                        (user) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: UserAvatar(
                            imageUrl: api.assetUrl(
                              user['avatarUrl'] as String?,
                            ),
                            radius: 22,
                          ),
                          title: Text(
                            user['name'] as String? ?? 'Collaborator',
                          ),
                          subtitle: Text(
                            user['username'] as String? ?? 'collaborator',
                          ),
                          onTap: () {
                            final id = user['id'] as String?;
                            if (id != null && id != me) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => UserProfileScreen(userId: id),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                CraftHubPanel(
                  child: Column(
                    children: [
                      _metaRow(
                        context,
                        'License',
                        workspaceRepoUrl.isNotEmpty
                            ? 'GitHub Shared Repo'
                            : 'Not Connected',
                      ),
                      _metaRow(
                        context,
                        'Visibility',
                        workspaceRepoUrl.isNotEmpty
                            ? 'Collaborators Only'
                            : 'Project Only',
                      ),
                      _metaRow(
                        context,
                        'Created',
                        p['createdAt'] as String? ?? 'Unknown',
                      ),
                    ],
                  ),
                ),
                if (isOwner || isCollab) ...[
                  const SizedBox(height: 16),
                  CraftHubPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Workspace Controls',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 14),
                        if (workspaceRepoUrl.isNotEmpty) ...[
                          Text(
                            workspaceFullName.isEmpty
                                ? workspaceRepoUrl
                                : workspaceFullName,
                          ),
                          if (myContributionCount > 0) ...[
                            const SizedBox(height: 8),
                            Text(
                              'You have $myContributionCount saved contributions in this project.',
                            ),
                          ],
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              FilledButton.icon(
                                onPressed: () => _launchExternalLink(
                                  parseGithubUrl(workspaceRepoUrl),
                                  'GitHub workspace repository',
                                ),
                                icon: const Icon(Icons.open_in_new),
                                label: const Text('Open GitHub'),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: () => _openWorkspace(
                                  workspaceRepoUrl,
                                  '${p['title'] ?? 'Project'} IDE',
                                ),
                                icon: const Icon(Icons.code),
                                label: const Text('Open Workspace'),
                              ),
                              if (workspaceConversationId.isNotEmpty)
                                OutlinedButton.icon(
                                  onPressed: () => _openProjectChat(
                                    workspaceConversationId,
                                    '${p['title'] ?? 'Project'} chat',
                                  ),
                                  icon: const Icon(Icons.chat_bubble_outline),
                                  label: const Text('Project Chat'),
                                ),
                            ],
                          ),
                        ] else ...[
                          Text(
                            isOwner
                                ? 'Workspace chat is available as soon as collaboration connects. The shared repo appears automatically once everyone has GitHub connected.'
                                : 'Workspace chat is available now, and the shared repo appears once everyone has GitHub connected.',
                          ),
                          const SizedBox(height: 12),
                          if (workspaceConversationId.isNotEmpty) ...[
                            OutlinedButton.icon(
                              onPressed: () => _openProjectChat(
                                workspaceConversationId,
                                '${p['title'] ?? 'Project'} chat',
                              ),
                              icon: const Icon(Icons.chat_bubble_outline),
                              label: const Text('Project Chat'),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (workspaceRequestedRepoName.isNotEmpty)
                            Text(
                              'Repository name: $workspaceRequestedRepoName',
                            ),
                          const SizedBox(height: 12),
                          if (!githubConnected)
                            FilledButton.tonalIcon(
                              onPressed: _connectGithub,
                              icon: const Icon(Icons.link),
                              label: const Text('Connect my GitHub'),
                            )
                          else
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _setWorkspaceRepoName(
                                    workspaceRequestedRepoName,
                                  ),
                                  icon: const Icon(
                                    Icons.drive_file_rename_outline,
                                  ),
                                  label: Text(
                                    workspaceRequestedRepoName.isEmpty
                                        ? 'Set Repo Name'
                                        : 'Change Repo Name',
                                  ),
                                ),
                                if (isOwner &&
                                    collabs.isNotEmpty &&
                                    missingGithubCollaborators.isEmpty)
                                  FilledButton.icon(
                                    onPressed: _creatingWorkspace
                                        ? null
                                        : _createWorkspace,
                                    icon: const Icon(
                                      Icons.rocket_launch_outlined,
                                    ),
                                    label: Text(
                                      _creatingWorkspace
                                          ? 'Creating...'
                                          : 'Create Shared Repo',
                                    ),
                                  ),
                              ],
                            ),
                          if (missingGithubCollaborators.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Waiting for GitHub connection from: ${missingGithubCollaborators.join(', ')}',
                            ),
                          ],
                        ],
                        if (isOwner || isCollab) ...[
                          const SizedBox(height: 12),
                          FilledButton.tonalIcon(
                            onPressed: _uploadingImages
                                ? null
                                : _addProjectPhotos,
                            icon: const Icon(
                              Icons.add_photo_alternate_outlined,
                            ),
                            label: Text(
                              _uploadingImages
                                  ? 'Uploading...'
                                  : imgs.isEmpty
                                  ? 'Add project photos'
                                  : 'Add more photos',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                if (url != null && url.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () =>
                        _launchExternalLink(parseWebUrl(url), 'source file'),
                    child: const Text('Download / open source file'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

int _followersLikeCount(
  List<Map<String, dynamic>> collabs,
  List<Map<String, dynamic>> contributions,
) {
  final base = collabs.length * 2 + contributions.length * 3;
  return base == 0 ? 0 : base * 7;
}

Widget _metaRow(BuildContext context, String label, String value) {
  final palette = CraftHubPalette.of(context);
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label.toUpperCase(),
            style: TextStyle(color: palette.muted, letterSpacing: 1.2),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = CraftHubPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.panelAlt.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: color),
          ),
          const SizedBox(height: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

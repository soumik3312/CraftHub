import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/craft_hub_theme.dart';
import '../../core/genres.dart';
import '../../core/project_tech_stack.dart';
import '../../core/url_utils.dart';
import '../../providers/auth_controller.dart';
import '../../widgets/craft_hub_ui.dart';
import 'project_detail_screen.dart';

class ProjectCreateScreen extends StatefulWidget {
  const ProjectCreateScreen({super.key});

  @override
  State<ProjectCreateScreen> createState() => _ProjectCreateScreenState();
}

class _ProjectCreateScreenState extends State<ProjectCreateScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _github = TextEditingController();
  final _workspaceRepo = TextEditingController();
  final Set<String> _genres = {};
  final Set<String> _techStack = {};
  final List<File> _images = [];
  File? _source;
  bool _busy = false;

  bool get _canPublish => !_busy && _title.text.trim().isNotEmpty;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _github.dispose();
    _workspaceRepo.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await ImagePicker().pickMultiImage();
    if (picked.isEmpty) return;
    setState(() => _images.addAll(picked.map((entry) => File(entry.path))));
  }

  Future<void> _pickSource() async {
    final result = await FilePicker.platform.pickFiles();
    if (result?.files.single.path != null) {
      setState(() => _source = File(result!.files.single.path!));
    }
  }

  Future<void> _save() async {
    final normalizedGithubUrl = normalizeGithubUrl(_github.text);
    if (_github.text.trim().isNotEmpty && normalizedGithubUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid GitHub repository link.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final data = await context.read<AuthController>().api.createProject(
        title: _title.text.trim(),
        description: _desc.text.trim(),
        githubUrl: normalizedGithubUrl,
        workspaceRepoName: _workspaceRepo.text.trim(),
        genres: _genres.toList(),
        techStack: _techStack.toList(),
        images: _images,
        source: _source,
      );
      final project = data['project'] as Map<String, dynamic>?;
      final projectId = project?['id'] as String?;
      if (mounted && projectId != null) {
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ProjectDetailScreen(
              projectId: projectId,
              openInviteOnLoad: true,
            ),
          ),
        );
      } else if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      final message = context.read<AuthController>().api.friendlyError(e);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = CraftHubPalette.of(context);
    final selectedTech = kProjectTechOptions
        .where((tech) => _techStack.contains(tech.id))
        .toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CraftHubBackground(
        child: SafeArea(
          bottom: false,
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
                        'New project',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                  children: [
                    _ProjectComposeHero(
                      selectedGenres: _genres.length,
                      selectedTech: _techStack.length,
                    ),
                    const SizedBox(height: 16),
                    CraftHubPanel(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _ComposeSectionHeader(
                            label: 'Project Basics',
                            subtitle:
                                'Give people a strong first impression with a clear title and a concise build summary.',
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _title,
                            decoration: const InputDecoration(
                              labelText: 'Project title',
                              hintText: 'CraftHub mobile redesign',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _desc,
                            maxLines: 5,
                            decoration: const InputDecoration(
                              labelText: 'Description',
                              hintText:
                                  'What are you building, what stage is it in, and what kind of collaborators are you looking for?',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    CraftHubPanel(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _ComposeSectionHeader(
                            label: 'Repo & Workspace',
                            subtitle:
                                'Attach an existing GitHub repository or prepare the shared repo name your team will use.',
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _github,
                            decoration: const InputDecoration(
                              labelText: 'GitHub repo URL',
                              hintText:
                                  'https://github.com/username/repo or username/repo',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _workspaceRepo,
                            decoration: const InputDecoration(
                              labelText: 'Shared repo name',
                              hintText:
                                  'Leave blank to use the project title automatically',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    CraftHubPanel(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ComposeSectionHeader(
                            label: 'Genres',
                            subtitle: _genres.isEmpty
                                ? 'Choose the creative spaces this project belongs in.'
                                : '${_genres.length} genres selected',
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: kProjectGenres.map((genre) {
                              final selected = _genres.contains(genre);
                              return FilterChip(
                                label: Text(
                                  genre,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                selected: selected,
                                onSelected: (value) => setState(() {
                                  if (value) {
                                    _genres.add(genre);
                                  } else {
                                    _genres.remove(genre);
                                  }
                                }),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    CraftHubPanel(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ComposeSectionHeader(
                            label: 'Languages & Technology',
                            subtitle: selectedTech.isEmpty
                                ? 'Tell collaborators what tools this project is built with.'
                                : '${selectedTech.length} stack items selected',
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: kProjectTechOptions.map((tech) {
                              final selected = _techStack.contains(tech.id);
                              return FilterChip(
                                avatar: Icon(
                                  tech.icon,
                                  size: 16,
                                  color: tech.color,
                                ),
                                label: Text(
                                  tech.label,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                selected: selected,
                                onSelected: (value) => setState(() {
                                  if (value) {
                                    _techStack.add(tech.id);
                                  } else {
                                    _techStack.remove(tech.id);
                                  }
                                }),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    CraftHubPanel(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _ComposeSectionHeader(
                            label: 'Media & Files',
                            subtitle:
                                'Add visuals and supporting files so the project feels more complete and more trustworthy.',
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: _pickImages,
                                icon: const Icon(
                                  Icons.add_photo_alternate_outlined,
                                ),
                                label: const Text('Add images'),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: _pickSource,
                                icon: const Icon(Icons.attach_file_rounded),
                                label: Text(
                                  _source == null
                                      ? 'Attach source'
                                      : 'Source added',
                                ),
                              ),
                            ],
                          ),
                          if (_source != null) ...[
                            const SizedBox(height: 14),
                            _AttachmentCard(
                              icon: Icons.description_outlined,
                              title: _source!.path
                                  .split(Platform.pathSeparator)
                                  .last,
                              subtitle: 'Source file attached',
                            ),
                          ],
                          if (_images.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            SizedBox(
                              height: 98,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _images.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 10),
                                itemBuilder: (context, index) {
                                  final file = _images[index];
                                  return Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: Image.file(
                                          file,
                                          width: 114,
                                          height: 98,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          onTap: () => setState(() {
                                            _images.removeAt(index);
                                          }),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(
                                                alpha: 0.58,
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close_rounded,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 110),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  decoration: BoxDecoration(
                    color: palette.bg.withValues(alpha: 0.78),
                    border: Border(
                      top: BorderSide(
                        color: palette.border.withValues(alpha: 0.72),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _title.text.trim().isEmpty
                              ? 'Add a project title to unlock publishing.'
                              : 'Ready to publish "${_title.text.trim()}"',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: palette.text.withValues(alpha: 0.86),
                              ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _canPublish ? _save : null,
                        icon: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.rocket_launch_rounded),
                        label: Text(_busy ? 'Publishing...' : 'Publish'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectComposeHero extends StatelessWidget {
  const _ProjectComposeHero({
    required this.selectedGenres,
    required this.selectedTech,
  });

  final int selectedGenres;
  final int selectedTech;

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
                  'PROJECT',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: CraftHubColors.cyan,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Create Something Worth Joining',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _HeroMetric(label: 'Genres', value: '$selectedGenres'),
              const SizedBox(height: 8),
              _HeroMetric(
                label: 'Stack',
                value: '$selectedTech',
                highlight: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ComposeSectionHeader extends StatelessWidget {
  const _ComposeSectionHeader({required this.label, required this.subtitle});

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

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final palette = CraftHubPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: highlight
            ? CraftHubColors.lavender.withValues(alpha: 0.16)
            : palette.panelAlt.withValues(alpha: 0.88),
        border: Border.all(
          color: highlight ? CraftHubColors.lavender : palette.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = CraftHubPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: palette.panelAlt.withValues(alpha: 0.94),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          CraftHubIconBubble(icon: icon, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

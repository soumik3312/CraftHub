import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/craft_hub_theme.dart';
import '../../providers/auth_controller.dart';
import '../../widgets/craft_hub_ui.dart';

class PostComposeScreen extends StatefulWidget {
  const PostComposeScreen({super.key});

  @override
  State<PostComposeScreen> createState() => _PostComposeScreenState();
}

class _PostComposeScreenState extends State<PostComposeScreen> {
  final _text = TextEditingController();
  final List<File> _imgs = [];
  bool _busy = false;

  bool get _canPost => !_busy && _text.text.trim().isNotEmpty;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await ImagePicker().pickMultiImage();
    if (picked.isEmpty) return;
    setState(() => _imgs.addAll(picked.map((entry) => File(entry.path))));
  }

  Future<void> _post() async {
    setState(() => _busy = true);
    try {
      await context.read<AuthController>().api.createPost(
        text: _text.text.trim(),
        images: _imgs,
      );
      if (mounted) Navigator.pop(context);
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
                        'New post',
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
                    const _PostComposeHero(),
                    const SizedBox(height: 16),
                    CraftHubPanel(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _PostSectionHeader(
                            label: 'Your Update',
                            subtitle:
                                'Share progress, ideas, a launch note, or something visual your network should see.',
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _text,
                            maxLines: 8,
                            decoration: const InputDecoration(
                              hintText:
                                  'What are you building right now? What changed, what shipped, or what do you want feedback on?',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${_text.text.trim().length} characters',
                              style: Theme.of(context).textTheme.bodySmall,
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
                          _PostSectionHeader(
                            label: 'Media',
                            subtitle: _imgs.isEmpty
                                ? 'Add images to make the post more polished and more scroll-stopping.'
                                : '${_imgs.length} image${_imgs.length == 1 ? '' : 's'} attached',
                          ),
                          const SizedBox(height: 14),
                          FilledButton.tonalIcon(
                            onPressed: _pick,
                            icon: const Icon(Icons.image_outlined),
                            label: const Text('Add images'),
                          ),
                          if (_imgs.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            SizedBox(
                              height: 108,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _imgs.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: 10),
                                itemBuilder: (context, index) {
                                  final file = _imgs[index];
                                  return Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: Image.file(
                                          file,
                                          width: 118,
                                          height: 108,
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
                                            _imgs.removeAt(index);
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
                    const SizedBox(height: 14),
                    CraftHubPanel(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _PostSectionHeader(
                            label: 'Posting Style',
                            subtitle:
                                'Short, clear updates usually perform better than long dense paragraphs.',
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: const [
                              CraftHubTag(
                                label: 'Show progress',
                                icon: Icons.bolt_rounded,
                              ),
                              CraftHubTag(
                                label: 'Ask for feedback',
                                icon: Icons.chat_bubble_outline_rounded,
                              ),
                              CraftHubTag(
                                label: 'Share visuals',
                                icon: Icons.collections_outlined,
                              ),
                            ],
                          ),
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
                          _text.text.trim().isEmpty
                              ? 'Write something worth sharing.'
                              : 'Ready to publish this update',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: palette.text.withValues(alpha: 0.86),
                              ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _canPost ? _post : null,
                        icon: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                        label: Text(_busy ? 'Posting...' : 'Post'),
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

class _PostComposeHero extends StatelessWidget {
  const _PostComposeHero();

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
            CraftHubColors.lavender.withValues(alpha: 0.1),
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
                  'POST',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: CraftHubColors.lavender,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Share Something That Looks Intentional',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 28,
                    height: 1.08,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const CraftHubIconBubble(
            icon: Icons.edit_note_rounded,
            active: true,
            size: 54,
          ),
        ],
      ),
    );
  }
}

class _PostSectionHeader extends StatelessWidget {
  const _PostSectionHeader({required this.label, required this.subtitle});

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
            color: CraftHubColors.cyan,
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

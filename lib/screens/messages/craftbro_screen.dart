import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/craft_hub_theme.dart';
import '../../providers/auth_controller.dart';
import '../../widgets/craft_hub_ui.dart';

class CraftBroScreen extends StatefulWidget {
  const CraftBroScreen({super.key});

  @override
  State<CraftBroScreen> createState() => _CraftBroScreenState();
}

class _CraftBroScreenState extends State<CraftBroScreen> {
  final TextEditingController _text = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<Map<String, String>> _messages = [
    {
      'role': 'assistant',
      'content':
          'I am CraftBro. Ask me about the app, matching, GitHub workspaces, collaborations, projects, or coding help.',
    },
  ];
  bool _loading = false;

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? seeded]) async {
    final prompt = (seeded ?? _text.text).trim();
    if (prompt.isEmpty || _loading) return;
    _text.clear();
    final history = _messages
        .skip(1)
        .map(
          (entry) => {
            'role': entry['role'] ?? 'user',
            'content': entry['content'] ?? '',
          },
        )
        .toList();
    setState(() {
      _loading = true;
      _messages.add({'role': 'user', 'content': prompt});
    });
    _scrollBottom();

    try {
      final api = context.read<AuthController>().api;
      final response = await api.craftbroChat(
        message: prompt,
        history: history,
      );
      if (!mounted) return;
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': (response['reply'] as String? ?? '').trim().isEmpty
              ? 'I could not generate a reply just now.'
              : (response['reply'] as String),
        });
        _loading = false;
      });
      _scrollBottom();
    } catch (e) {
      if (!mounted) return;
      final message = context.read<AuthController>().api.friendlyError(e);
      setState(() {
        _messages.add({'role': 'assistant', 'content': message});
        _loading = false;
      });
      _scrollBottom();
    }
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const suggestions = ['Explain Code', 'Debug Flow', 'Suggest Fix'];
    final palette = CraftHubPalette.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CraftHubBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: palette.border),
                        gradient: LinearGradient(
                          colors: [
                            CraftHubColors.lavender.withValues(alpha: 0.35),
                            palette.panelAlt,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: CraftHubColors.lavender,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Craftbro',
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium?.copyWith(fontSize: 20),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'AI command channel',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: CraftHubColors.lime),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.settings_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: suggestions
                        .map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _PromptChip(
                              label: entry,
                              onTap: () => _send(entry),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
                  itemCount: _messages.length + (_loading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_loading && index == _messages.length) {
                      return const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(left: 10, top: 8),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }
                    final message = _messages[index];
                    return _CraftBroMessageCard(
                      mine: message['role'] == 'user',
                      text: message['content'] ?? '',
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  decoration: BoxDecoration(
                    color: palette.bg.withValues(alpha: 0.9),
                    border: Border(
                      top: BorderSide(color: palette.border),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: palette.panelAlt,
                          border: Border.all(color: palette.border),
                        ),
                        child: Icon(
                          Icons.image_outlined,
                          color: palette.text,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            color: palette.panel.withValues(alpha: 0.96),
                            border: Border.all(color: palette.border),
                          ),
                          child: TextField(
                            controller: _text,
                            minLines: 1,
                            maxLines: 5,
                            decoration: const InputDecoration(
                              hintText: 'Command Craftbro... (Shift + Enter)',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              fillColor: Colors.transparent,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 15,
                              ),
                            ),
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: CraftHubColors.accent,
                          boxShadow: [
                            BoxShadow(
                              color: CraftHubColors.purple.withValues(
                                alpha: 0.35,
                              ),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: _loading ? null : () => _send(),
                          icon: const Icon(Icons.arrow_upward_rounded),
                          color: const Color(0xFF22082E),
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
    );
  }
}

class _PromptChip extends StatelessWidget {
  const _PromptChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = CraftHubPalette.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: palette.panelAlt.withValues(alpha: 0.96),
          border: Border.all(color: palette.border),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: palette.text,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

class _CraftBroMessageCard extends StatelessWidget {
  const _CraftBroMessageCard({required this.mine, required this.text});

  final bool mine;
  final String text;

  bool get _looksLikeCode {
    final trimmed = text.trim();
    return trimmed.contains('```') ||
        (trimmed.contains('\n') &&
            (trimmed.contains('{') ||
                trimmed.contains('class ') ||
                trimmed.contains('struct ') ||
                trimmed.contains('return ') ||
                trimmed.contains(';')));
  }

  @override
  Widget build(BuildContext context) {
    final palette = CraftHubPalette.of(context);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: mine
              ? palette.panelAlt.withValues(alpha: 0.92)
              : palette.panel.withValues(alpha: 0.96),
          border: Border.all(
            color: mine
                ? palette.border
                : CraftHubColors.lavender.withValues(alpha: 0.32),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: CraftHubColors.lavender.withValues(alpha: 0.18),
                        border: Border.all(color: CraftHubColors.lavender),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        size: 12,
                        color: CraftHubColors.lavender,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'CraftBro',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: CraftHubColors.cyan,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            if (_looksLikeCode)
              _CraftBroCodeBlock(text: text)
            else
              Text(
                text,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 14,
                  color: palette.text.withValues(alpha: 0.92),
                ),
              ),
            if (!mine) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  _MiniTag(label: 'MEMORY MANAGEMENT'),
                  _MiniTag(label: 'PERFORMANCE'),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CraftBroCodeBlock extends StatelessWidget {
  const _CraftBroCodeBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cleaned = text.replaceAll('```', '').trim();
    final palette = CraftHubPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: palette.bgSoft.withValues(alpha: 0.92),
        border: Border.all(color: palette.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(
          cleaned,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12.5,
            height: 1.45,
            color: palette.text,
          ),
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = CraftHubPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: palette.panelAlt.withValues(alpha: 0.96),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: palette.muted,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

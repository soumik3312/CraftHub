import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_controller.dart';
import '../../widgets/user_avatar.dart';
import '../profile/user_profile_screen.dart';

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Map<String, dynamic>? _post;
  List<dynamic> _comments = [];
  List<dynamic> _suggestions = [];
  final _c = TextEditingController();
  final _s = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _c.dispose();
    _s.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = context.read<AuthController>().api;
    setState(() => _loading = true);
    try {
      final d = await api.getPost(widget.postId);
      final post = d['post'] as Map<String, dynamic>;
      final c = await api.postComments(widget.postId);
      setState(() {
        _post = post;
        _comments = c['comments'] as List<dynamic>? ?? [];
        _suggestions = c['suggestions'] as List<dynamic>? ?? [];
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final api = auth.api;
    final me = auth.user?['id'] as String?;

    if (_loading || _post == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    final p = _post!;
    final author = p['author'] as Map<String, dynamic>? ?? {};
    final imgs = (p['imageUrls'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final av = api.assetUrl(author['avatarUrl'] as String?);

    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                ListTile(
                  leading: UserAvatar(imageUrl: av, radius: 20),
                  title: Text(author['name'] as String? ?? ''),
                  subtitle: Text('@${author['username'] ?? ''}'),
                  onTap: () {
                    final id = author['id'] as String?;
                    if (id != null && id != me) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfileScreen(userId: id)));
                    }
                  },
                ),
                Text(p['text'] as String? ?? ''),
                ...imgs.map((u) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: CachedNetworkImage(imageUrl: u),
                    )),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(p['likedByMe'] == true ? Icons.favorite : Icons.favorite_border),
                      onPressed: () async {
                        if (p['likedByMe'] == true) {
                          await api.unlikePost(widget.postId);
                        } else {
                          await api.likePost(widget.postId);
                        }
                        _load();
                      },
                    ),
                    Text('${p['likeCount'] ?? 0}'),
                    const SizedBox(width: 16),
                    Text('Shares: ${p['sharesCount'] ?? 0}'),
                  ],
                ),
                const Divider(),
                Text('Suggestions', style: Theme.of(context).textTheme.titleSmall),
                ..._suggestions.map((x) {
                  final m = x as Map<String, dynamic>;
                  final a = m['author'] as Map<String, dynamic>? ?? {};
                  return ListTile(
                    dense: true,
                    title: Text(m['text'] as String? ?? ''),
                    subtitle: Text(a['name'] as String? ?? ''),
                  );
                }),
                TextField(
                  controller: _s,
                  decoration: const InputDecoration(labelText: 'Suggest improvement'),
                  onSubmitted: (_) => _sendSuggest(),
                ),
                TextButton(onPressed: _sendSuggest, child: const Text('Send suggestion')),
                const Divider(),
                Text('Comments', style: Theme.of(context).textTheme.titleSmall),
                ..._comments.map((x) {
                  final m = x as Map<String, dynamic>;
                  final a = m['author'] as Map<String, dynamic>? ?? {};
                  return ListTile(
                    title: Text(m['text'] as String? ?? ''),
                    subtitle: Text(a['name'] as String? ?? ''),
                  );
                }),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(child: TextField(controller: _c, decoration: const InputDecoration(hintText: 'Comment'))),
                  IconButton(
                    onPressed: () async {
                      final t = _c.text.trim();
                      if (t.isEmpty) return;
                      await api.commentPost(widget.postId, t);
                      _c.clear();
                      _load();
                    },
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendSuggest() async {
    final t = _s.text.trim();
    if (t.isEmpty) return;
    await context.read<AuthController>().api.suggestPost(widget.postId, t);
    _s.clear();
    _load();
  }
}

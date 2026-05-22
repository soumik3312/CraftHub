import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_controller.dart';
import 'project_create_screen.dart';
import 'project_detail_screen.dart';

class ProjectsTab extends StatefulWidget {
  const ProjectsTab({super.key});

  @override
  State<ProjectsTab> createState() => _ProjectsTabState();
}

class _ProjectsTabState extends State<ProjectsTab> {
  List<dynamic> _owned = [];
  List<dynamic> _collab = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<AuthController>().api;
    setState(() => _loading = true);
    try {
      final d = await api.myProjects();
      setState(() {
        _owned = d['owned'] as List<dynamic>? ?? [];
        _collab = d['collaborating'] as List<dynamic>? ?? [];
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProjectCreateScreen()));
          _load();
        },
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Text('My projects', style: Theme.of(context).textTheme.titleMedium),
                  ..._owned.map((p) => _tile(context, p as Map<String, dynamic>)),
                  const SizedBox(height: 16),
                  Text('Collaborating', style: Theme.of(context).textTheme.titleMedium),
                  if (_collab.isEmpty) const Text('No shared projects yet'),
                  ..._collab.map((p) => _tile(context, p as Map<String, dynamic>)),
                ],
              ),
            ),
    );
  }

  Widget _tile(BuildContext context, Map<String, dynamic> p) {
    return Card(
      child: ListTile(
        title: Text(p['title'] as String? ?? ''),
        subtitle: Text((p['genres'] as List?)?.join(', ') ?? ''),
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectDetailScreen(projectId: p['id'] as String)));
          _load();
        },
      ),
    );
  }
}

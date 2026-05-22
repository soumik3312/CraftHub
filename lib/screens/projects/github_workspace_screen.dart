import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class GitHubWorkspaceScreen extends StatefulWidget {
  const GitHubWorkspaceScreen({
    super.key,
    required this.title,
    required this.projectId,
    required this.repoUrl,
    required this.apiBaseUrl,
    required this.authToken,
  });

  final String title;
  final String projectId;
  final String repoUrl;
  final String apiBaseUrl;
  final String authToken;

  @override
  State<GitHubWorkspaceScreen> createState() => _GitHubWorkspaceScreenState();
}

class _GitHubWorkspaceScreenState extends State<GitHubWorkspaceScreen> {
  WebViewController? _controller;
  bool _loading = true;
  String _lastFilePath = '';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  String get _prefsKey => 'craft_hub_workspace_last_file_${widget.projectId}';

  Future<void> _rememberLastFile(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, path);
    if (mounted) {
      setState(() => _lastFilePath = path);
    }
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _lastFilePath = prefs.getString(_prefsKey) ?? '';
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'CraftHub',
        onMessageReceived: (message) {
          if (message.message.startsWith('state:lastFile:')) {
            _rememberLastFile(message.message.substring('state:lastFile:'.length));
            return;
          }
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message.message)),
          );
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadHtmlString(_html());
    if (!mounted) return;
    setState(() {
      _controller = controller;
    });
  }

  String _html() {
    final projectId = jsonEncode(widget.projectId);
    final apiBase = jsonEncode(widget.apiBaseUrl.replaceAll(RegExp(r'/$'), ''));
    final token = jsonEncode(widget.authToken);
    final repoUrl = jsonEncode(widget.repoUrl);
    final initialFile = jsonEncode(_lastFilePath);

    return r'''
<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Craft Hub Monaco</title>
    <style>
      html, body { margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; font-family: Arial, sans-serif; background: #111; color: #f5f5f5; }
      .app { display: flex; flex-direction: column; width: 100%; height: 100%; }
      .toolbar { display: flex; gap: 8px; align-items: center; padding: 10px 12px; background: #171717; border-bottom: 1px solid #2c2c2c; }
      .toolbar button { background: #0f9d84; color: white; border: 0; border-radius: 10px; padding: 8px 12px; font-size: 13px; }
      .toolbar button.secondary { background: #2a2a2a; }
      .toolbar .title { flex: 1; min-width: 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; font-size: 13px; color: #ddd; }
      .content { display: flex; flex: 1; min-height: 0; }
      .sidebar { width: 220px; background: #151515; border-right: 1px solid #2c2c2c; overflow: auto; }
      .sidebar-header { padding: 10px 12px; font-size: 12px; color: #bbb; border-bottom: 1px solid #242424; }
      .entry { padding: 10px 12px; border-bottom: 1px solid #1d1d1d; font-size: 13px; cursor: pointer; word-break: break-word; }
      .entry.folder { color: #9fdcff; }
      .entry.file { color: #f4f4f4; }
      .entry.active { background: #1f3c38; }
      .editor-pane { flex: 1; display: flex; flex-direction: column; min-width: 0; }
      .pathbar { padding: 10px 12px; font-size: 12px; color: #bdbdbd; background: #121212; border-bottom: 1px solid #242424; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
      #editor { flex: 1; min-height: 0; }
      .empty { padding: 18px; color: #aaa; font-size: 13px; }
    </style>
  </head>
  <body>
    <div class="app">
      <div class="toolbar">
        <button onclick="saveFile()">Save</button>
        <button class="secondary" onclick="newFile()">New File</button>
        <button class="secondary" onclick="goUp()">Up</button>
        <button class="secondary" onclick="openRepo()">Repo</button>
        <div class="title" id="status">Loading workspace...</div>
      </div>
      <div class="content">
        <div class="sidebar">
          <div class="sidebar-header" id="folderLabel">Files</div>
          <div id="tree"></div>
        </div>
        <div class="editor-pane">
          <div class="pathbar" id="fileLabel">No file selected</div>
          <div id="editor"></div>
        </div>
      </div>
    </div>

    <script src="https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.52.2/min/vs/loader.min.js"></script>
    <script>
      const PROJECT_ID = $projectId;
      const API_BASE = $apiBase;
      const TOKEN = $token;
      const REPO_URL = $repoUrl;
      const INITIAL_FILE = $initialFile;
      let editor;
      let currentDir = '';
      let currentFile = '';
      let currentSha = '';
      let treeEntries = [];
      let initialFileLoaded = false;

      function notify(message) {
        if (window.CraftHub && window.CraftHub.postMessage) {
          window.CraftHub.postMessage(String(message));
        }
      }

      function setStatus(value) {
        document.getElementById('status').textContent = value;
      }

      function setFileLabel(value) {
        document.getElementById('fileLabel').textContent = value || 'No file selected';
      }

      function rememberFile(path) {
        notify(`state:lastFile:${path || ''}`);
      }

      async function apiCall(method, suffix, body) {
        const response = await fetch(`${API_BASE}/api/projects/${PROJECT_ID}/workspace${suffix}`, {
          method,
          headers: {
            'Authorization': `Bearer ${TOKEN}`,
            'Content-Type': 'application/json',
          },
          body: body ? JSON.stringify(body) : undefined,
        });
        const text = await response.text();
        let data = {};
        try {
          data = text ? JSON.parse(text) : {};
        } catch (_) {
          data = { error: text };
        }
        if (!response.ok) {
          throw new Error(data.error || 'Workspace request failed');
        }
        return data;
      }

      function renderTree() {
        const tree = document.getElementById('tree');
        tree.innerHTML = '';
        document.getElementById('folderLabel').textContent = currentDir || 'Repository root';

        const entries = [...treeEntries].sort((a, b) => {
          if (a.type === b.type) return a.name.localeCompare(b.name);
          return a.type === 'dir' ? -1 : 1;
        });

        for (const entry of entries) {
          const item = document.createElement('div');
          item.className = `entry ${entry.type === 'dir' ? 'folder' : 'file'} ${entry.path === currentFile ? 'active' : ''}`;
          item.textContent = `${entry.type === 'dir' ? '📁' : '📄'} ${entry.name}`;
          item.onclick = () => {
            if (entry.type === 'dir') {
              loadTree(entry.path);
            } else {
              loadFile(entry.path);
            }
          };
          tree.appendChild(item);
        }
      }

      async function loadTree(path) {
        try {
          setStatus('Loading files...');
          const data = await apiCall('GET', `/tree?path=${encodeURIComponent(path || '')}`);
          currentDir = data.path || '';
          treeEntries = data.entries || [];
          renderTree();
          if (!initialFileLoaded && INITIAL_FILE) {
            initialFileLoaded = true;
            loadFile(INITIAL_FILE);
            return;
          }
          setStatus(currentFile ? `Editing ${currentFile}` : 'Workspace ready');
        } catch (error) {
          notify(error.message);
          setStatus(error.message);
        }
      }

      async function loadFile(path) {
        try {
          setStatus(`Opening ${path}...`);
          const data = await apiCall('GET', `/file?path=${encodeURIComponent(path)}`);
          currentFile = data.path || path;
          currentSha = data.sha || '';
          editor.setValue(data.content || '');
          setFileLabel(currentFile);
          rememberFile(currentFile);
          renderTree();
          setStatus(`Editing ${currentFile}`);
        } catch (error) {
          notify(error.message);
          setStatus(error.message);
        }
      }

      async function saveFile() {
        try {
          if (!currentFile) {
            notify('Create or open a file first.');
            return;
          }
          setStatus(`Saving ${currentFile}...`);
          const data = await apiCall('PUT', '/file', {
            path: currentFile,
            content: editor.getValue(),
            sha: currentSha,
            message: `Update ${currentFile} from Craft Hub Monaco`,
          });
          currentSha = data.sha || currentSha;
          setStatus(`Saved ${currentFile}`);
          rememberFile(currentFile);
          notify(`Saved ${currentFile} to GitHub.`);
          await loadTree(currentDir);
        } catch (error) {
          notify(error.message);
          setStatus(error.message);
        }
      }

      function newFile() {
        const name = window.prompt('Enter new file path', currentDir ? `${currentDir}/main.dart` : 'main.dart');
        if (!name) return;
        currentFile = name.replace(/^\/+/, '');
        currentSha = '';
        editor.setValue('');
        setFileLabel(currentFile);
        rememberFile(currentFile);
        renderTree();
        setStatus(`New file ${currentFile}`);
      }

      function goUp() {
        if (!currentDir) return;
        const parts = currentDir.split('/').filter(Boolean);
        parts.pop();
        loadTree(parts.join('/'));
      }

      function openRepo() {
        window.location.href = REPO_URL;
      }

      require.config({ paths: { vs: 'https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.52.2/min/vs' } });
      require(['vs/editor/editor.main'], function () {
        editor = monaco.editor.create(document.getElementById('editor'), {
          value: '',
          language: 'javascript',
          automaticLayout: true,
          theme: 'vs-dark',
          minimap: { enabled: false },
          fontSize: 14,
        });
        loadTree('');
        setStatus('Workspace ready');
      }, function (error) {
        notify('Could not load Monaco editor.');
        setStatus('Could not load Monaco editor.');
      });
    </script>
  </body>
</html>
'''
        .replaceAll(r'$projectId', projectId)
        .replaceAll(r'$apiBase', apiBase)
        .replaceAll(r'$token', token)
        .replaceAll(r'$repoUrl', repoUrl)
        .replaceAll(r'$initialFile', initialFile);
  }

  Future<void> _openExternally() async {
    final uri = Uri.tryParse(widget.repoUrl);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the repository in browser.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            onPressed: _openExternally,
            icon: const Icon(Icons.open_in_browser_outlined),
          ),
        ],
      ),
          body: Stack(
        children: [
          if (_controller != null)
            WebViewWidget(controller: _controller!)
          else
            const Center(child: CircularProgressIndicator()),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }
}

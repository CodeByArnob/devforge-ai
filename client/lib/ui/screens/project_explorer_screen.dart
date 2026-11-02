import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../../core/services/api_service.dart';

class ProjectExplorerScreen extends StatefulWidget {
  final Function(ProjectModel)? onSelectProject;
  const ProjectExplorerScreen({super.key, this.onSelectProject});

  @override
  State<ProjectExplorerScreen> createState() => _ProjectExplorerScreenState();
}

class _ProjectExplorerScreenState extends State<ProjectExplorerScreen> {
  final ApiService _api = ApiService();
  List<ProjectModel> _projects = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await _api.listProjects();
      setState(() => _projects = list);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showImportGitHubDialog() {
    final ownerCtrl = TextEditingController(text: 'flutter');
    final repoCtrl = TextEditingController(text: 'samples');
    final refCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Public GitHub Repository'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: ownerCtrl, decoration: const InputDecoration(labelText: 'Owner / Organization')),
            const SizedBox(height: 10),
            TextField(controller: repoCtrl, decoration: const InputDecoration(labelText: 'Repository Name')),
            const SizedBox(height: 10),
            TextField(controller: refCtrl, decoration: const InputDecoration(labelText: 'Branch / Tag / Ref (optional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Importing repository...')));
              try {
                await _api.importGitHub(
                  ownerCtrl.text.trim(),
                  repoCtrl.text.trim(),
                  ref: refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim(),
                );
                _loadProjects();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Repository imported successfully!')));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
                }
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  void _showClaimDialog() {
    final projIdCtrl = TextEditingController();
    final secretCtrl = TextEditingController(text: 'devforge-legacy-claim-secret-2026');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Claim Legacy Project'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: projIdCtrl, decoration: const InputDecoration(labelText: 'Legacy Project ID')),
            const SizedBox(height: 10),
            TextField(controller: secretCtrl, decoration: const InputDecoration(labelText: 'Claim Secret Key')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.claimProject(projIdCtrl.text.trim(), secretCtrl.text.trim());
                _loadProjects();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Project claimed successfully!')));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Claim failed: $e')));
                }
              }
            },
            child: const Text('Claim'),
          ),
        ],
      ),
    );
  }

  void _showInventory(ProjectModel project) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollCtrl) => FutureBuilder<Map<String, dynamic>>(
          future: _api.getProjectInventory(project.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final items = (snapshot.data?['items'] as List<dynamic>?) ?? [];
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${project.name} Inventory', style: Theme.of(context).textTheme.titleLarge),
                      Text('${items.length} items', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollCtrl,
                      itemCount: items.length,
                      itemBuilder: (context, idx) {
                        final item = items[idx];
                        final isDir = item['type'] == 'directory';
                        return ListTile(
                          dense: true,
                          leading: Icon(isDir ? Icons.folder : Icons.insert_drive_file, color: isDir ? Colors.amber : Colors.blue),
                          title: Text(item['path']),
                          subtitle: isDir ? null : Text('${item['size']} bytes • SHA: ${item['sha256']?.substring(0, 12)}...'),
                          onTap: isDir
                              ? null
                              : () async {
                                  try {
                                    final fileData = await _api.inspectFile(project.id, item['path']);
                                    if (context.mounted) {
                                      showDialog(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: Text(item['path']),
                                          content: SizedBox(
                                            width: 600,
                                            height: 400,
                                            child: SingleChildScrollView(
                                              child: SelectableText(
                                                fileData['content'] ?? '[Binary Content]',
                                                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                                              ),
                                            ),
                                          ),
                                          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Inspect failed: $e')));
                                    }
                                  }
                                },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects Explorer'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadProjects),
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'github') _showImportGitHubDialog();
              if (val == 'claim') _showClaimDialog();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'github', child: Row(children: [Icon(Icons.cloud_download), SizedBox(width: 8), Text('Import GitHub Repo')])),
              const PopupMenuItem(value: 'claim', child: Row(children: [Icon(Icons.verified_user), SizedBox(width: 8), Text('Claim Legacy Project')])),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _projects.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.folder_open, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text('No projects found in this account.', style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _showImportGitHubDialog,
                            icon: const Icon(Icons.cloud_download),
                            label: const Text('Import GitHub Repo'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadProjects,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _projects.length,
                        itemBuilder: (context, index) {
                          final p = _projects[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Icon(p.sourceType == 'github' ? Icons.code : Icons.folder_zip),
                              ),
                              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${p.fileCount} files • ${p.sourceType.toUpperCase()}'),
                                  if (p.languages.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Wrap(
                                        spacing: 4,
                                        children: p.languages
                                            .map((l) => Chip(
                                                  label: Text(l['display_name'] ?? l.toString(), style: const TextStyle(fontSize: 10)),
                                                  padding: EdgeInsets.zero,
                                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                ))
                                            .toList(),
                                      ),
                                    ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.list_alt),
                                tooltip: 'View Inventory',
                                onPressed: () => _showInventory(p),
                              ),
                              onTap: () {
                                if (widget.onSelectProject != null) {
                                  widget.onSelectProject!(p);
                                } else {
                                  _showInventory(p);
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

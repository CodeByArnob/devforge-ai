import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../../core/services/api_service.dart';

class ProjectsScreen extends StatefulWidget {
  final Function(ProjectModel)? onSelectProject;
  const ProjectsScreen({super.key, this.onSelectProject});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final ApiService _api = ApiService();
  List<ProjectModel> _projects = [];
  bool _isLoading = true;
  final bool _isConnectedGitHub = true; // Connected via DevForgeAI-CodeByArnob

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoading = true);
    try {
      final list = await _api.listProjects();
      setState(() => _projects = list);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  void _showConnectDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF121A29),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF1E293B)),
        ),
        title: const Row(
          children: [
            Icon(Icons.link, color: Color(0xFF5A77F6), size: 22),
            SizedBox(width: 8),
            Text('GitHub App Authorization', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connected GitHub App:',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
            SizedBox(height: 6),
            Text(
              'DevForgeAI-CodeByArnob (Active)',
              style: TextStyle(color: Color(0xFF34D399), fontSize: 14, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              'Device flow authorization token is saved in hardware-backed secure storage. You can browse, sync, and dispatch CI workflows for authorized repositories.',
              style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12.5, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _loadProjects();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Synchronized repositories with GitHub!'),
                  backgroundColor: Color(0xFF1E293B),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5A77F6),
              foregroundColor: Colors.white,
            ),
            child: const Text('Sync Repositories'),
          ),
        ],
      ),
    );
  }

  void _showImportDialog() {
    final ownerCtrl = TextEditingController(text: 'CodeByArnob');
    final repoCtrl = TextEditingController(text: 'devforge-ai');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF121A29),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF1E293B)),
        ),
        title: const Row(
          children: [
            Icon(Icons.add_circle_outline, color: Color(0xFF34D399), size: 22),
            SizedBox(width: 8),
            Text('Import GitHub Repo', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter owner and repository name to clone into isolated workspace:',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ownerCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Owner / Organization',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: repoCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Repository Name',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Cloning and importing ${ownerCtrl.text}/${repoCtrl.text}...'),
                  backgroundColor: const Color(0xFF1E293B),
                ),
              );
              try {
                await _api.importGitHub(ownerCtrl.text.trim(), repoCtrl.text.trim());
                await _loadProjects();
              } catch (_) {}
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF34D399),
              foregroundColor: Colors.black,
            ),
            child: const Text('Import Project', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showInventory(ProjectModel project) async {
    try {
      final inv = await _api.getProjectInventory(project.id);
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF121A29),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, color: Color(0xFF38BDF8), size: 20),
                  const SizedBox(width: 8),
                  Text(project.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Text('Total files: ${inv['total_files'] ?? project.fileCount}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
              const Divider(color: Color(0xFF1E293B), height: 24),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: (inv['entries'] as List<dynamic>?)?.length ?? 0,
                  itemBuilder: (c, i) {
                    final e = (inv['entries'] as List<dynamic>)[i];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.description_outlined, color: Color(0xFF94A3B8), size: 18),
                      title: Text(e['path'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13)),
                      trailing: Text('${e['size_bytes'] ?? 0} B', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Projects',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: Color(0xFF34D399)),
                  tooltip: 'Import Repository',
                  onPressed: _showImportDialog,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Connect GitHub to browse repositories, review changes and run cloud builds.',
              style: TextStyle(
                fontSize: 13.5,
                color: Color(0xFF94A3B8),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // GitHub App connection card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF121A29),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.code_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'GitHub App connection',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'DevForgeAI-CodeByArnob',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.link, color: Color(0xFF94A3B8), size: 20),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Authorize using GitHub Device Flow. Your token is stored in Android secure storage.',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showConnectDialog,
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: Text(
                        _isConnectedGitHub ? 'Connected to GitHub (CodeByArnob)' : 'Connect GitHub',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5A77F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section: Your repositories
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Your repositories',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: _showImportDialog,
                  icon: const Icon(Icons.add, size: 16, color: Color(0xFF38BDF8)),
                  label: const Text('Add Repo', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Connect GitHub to load your repositories.\nOnly repositories granted to the DevForge GitHub App can be used for private project operations.',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(color: Color(0xFF5A77F6)),
                ),
              )
            else
              ..._projects.map((proj) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF121A29),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            proj.sourceType == 'github' ? Icons.folder_outlined : Icons.devices,
                            color: const Color(0xFF34D399),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                proj.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    '${proj.fileCount} files',
                                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      proj.sourceType.toUpperCase(),
                                      style: const TextStyle(
                                        color: Color(0xFF38BDF8),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF94A3B8)),
                          onPressed: () => _showInventory(proj),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

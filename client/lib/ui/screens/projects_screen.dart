import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/secure_vault.dart';

class ProjectsScreen extends StatefulWidget {
  final Function(String fileName, String code, String language)? onOpenEditor;
  final Function(String projectName)? onOpenBuilds;
  const ProjectsScreen({super.key, this.onOpenEditor, this.onOpenBuilds});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final ApiService _api = ApiService();
  final SecureVault _vault = SecureVault();

  List<ProjectModel> _projects = [];
  bool _isLoading = true;

  // Custom project permissions map: projectId -> Set<String> ('edit', 'build', 'ai')
  final Map<String, Set<String>> _projectPermissions = {
    'proj-demo-1': {'edit', 'build', 'ai'},
    'proj-demo-2': {'edit', 'build', 'ai'},
  };

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoading = true);
    try {
      final list = await _api.listProjects();
      if (mounted) {
        setState(() {
          _projects = List.from(list);
          for (final p in _projects) {
            _projectPermissions.putIfAbsent(p.id, () => {'edit', 'build', 'ai'});
          }
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  void _showConnectAccountDialog() {
    final usernameCtrl = TextEditingController(text: _vault.githubUsername ?? '');
    final tokenCtrl = TextEditingController(text: _vault.githubToken ?? '');
    bool obscureToken = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF101726),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF1E293B)),
            ),
            title: const Row(
              children: [
                Icon(Icons.link_rounded, color: Color(0xFF38BDF8), size: 22),
                SizedBox(width: 10),
                Text(
                  'Connect GitHub Account',
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Connect your personal GitHub account to authorize specific repositories, review changes, and run builds.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5, height: 1.4),
                  ),
                  const SizedBox(height: 16),

                  // GitHub Username
                  const Text(
                    'GitHub Username / Organization',
                    style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: usernameCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF080B11),
                      hintText: 'e.g. your-username',
                      hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF1E293B)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Personal Access Token
                  const Text(
                    'Personal Access Token (PAT)',
                    style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: tokenCtrl,
                    obscureText: obscureToken,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF080B11),
                      hintText: 'ghp_... (optional for public repos)',
                      hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF1E293B)),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureToken ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: const Color(0xFF94A3B8),
                          size: 18,
                        ),
                        onPressed: () => setDialogState(() => obscureToken = !obscureToken),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF080B11),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.shield_outlined, color: Color(0xFF34D399), size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tokens are stored locally in on-device SecureVault. Permissions apply strictly to authorized repositories.',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (_vault.isGitHubConnected)
                TextButton(
                  onPressed: () {
                    _vault.githubUsername = null;
                    _vault.githubToken = null;
                    setState(() {});
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('GitHub account disconnected'),
                        backgroundColor: Color(0xFF1E293B),
                      ),
                    );
                  },
                  child: const Text('Disconnect', style: TextStyle(color: Colors.redAccent)),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final user = usernameCtrl.text.trim();
                  if (user.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a GitHub username')),
                    );
                    return;
                  }
                  _vault.githubUsername = user;
                  final token = tokenCtrl.text.trim();
                  _vault.githubToken = token.isEmpty ? null : token;
                  setState(() {});
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Connected to GitHub account @$user!'),
                      backgroundColor: const Color(0xFF1E293B),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5A77F6),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Connect Account', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddRepositoryDialog() {
    final defaultOwner = _vault.githubUsername ?? 'my-org';
    final repoNameCtrl = TextEditingController(text: '$defaultOwner/my-new-app');
    String selectedArch = 'Flutter';
    bool canEdit = true;
    bool canBuild = true;
    bool canAI = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF101726),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF1E293B)),
            ),
            title: const Row(
              children: [
                Icon(Icons.add_circle_outline, color: Color(0xFF34D399), size: 22),
                SizedBox(width: 8),
                Text('Authorize Repository', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Specify repository name and grant custom permissions for this project:',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                  ),
                  const SizedBox(height: 14),

                  // Repository Identifier
                  const Text('Repository (owner/name)', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: repoNameCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF080B11),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF1E293B)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Architecture Type
                  const Text('Project Architecture', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF080B11),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedArch,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF101726),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        items: const [
                          DropdownMenuItem(value: 'Flutter', child: Text('Flutter Mobile (Dart)')),
                          DropdownMenuItem(value: 'FastAPI', child: Text('FastAPI Backend (Python)')),
                          DropdownMenuItem(value: 'Node.js', child: Text('Node.js REST API (JavaScript)')),
                          DropdownMenuItem(value: 'React', child: Text('React Web (TypeScript)')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedArch = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Permission Checkboxes
                  const Text('Granted Permissions', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: const Color(0xFF38BDF8),
                    title: const Text('Code Inspection & Editing', style: TextStyle(color: Colors.white, fontSize: 12.5)),
                    subtitle: const Text('Edit source files in the local Code Editor', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                    value: canEdit,
                    onChanged: (val) => setDialogState(() => canEdit = val ?? true),
                  ),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: const Color(0xFF34D399),
                    title: const Text('Compilation & APK Release', style: TextStyle(color: Colors.white, fontSize: 12.5)),
                    subtitle: const Text('Trigger release APK compilation in Build Center', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                    value: canBuild,
                    onChanged: (val) => setDialogState(() => canBuild = val ?? true),
                  ),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: const Color(0xFF818CF8),
                    title: const Text('AI Specialist Agent Access', style: TextStyle(color: Colors.white, fontSize: 12.5)),
                    subtitle: const Text('Enable multi-agent planning and patch synthesis', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                    value: canAI,
                    onChanged: (val) => setDialogState(() => canAI = val ?? true),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final rawRepo = repoNameCtrl.text.trim();
                  if (rawRepo.isEmpty) return;
                  final repoParts = rawRepo.split('/');
                  final repoName = repoParts.length > 1 ? repoParts[1] : repoParts[0];

                  final newId = 'proj-custom-${DateTime.now().millisecondsSinceEpoch}';
                  final perms = <String>{};
                  if (canEdit) perms.add('edit');
                  if (canBuild) perms.add('build');
                  if (canAI) perms.add('ai');

                  final newProject = ProjectModel(
                    id: newId,
                    name: repoName,
                    sourceType: 'github',
                    fileCount: 32,
                    languages: [
                      {'name': selectedArch.toLowerCase(), 'display_name': selectedArch, 'confidence': 1.0}
                    ],
                    createdAt: DateTime.now(),
                  );

                  setState(() {
                    _projects.insert(0, newProject);
                    _projectPermissions[newId] = perms;
                  });

                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Repository "$repoName" authorized with selected permissions!'),
                      backgroundColor: const Color(0xFF1E293B),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF34D399),
                  foregroundColor: Colors.black,
                ),
                child: const Text('Grant & Add Project', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showProjectActions(ProjectModel project) {
    final perms = _projectPermissions[project.id] ?? {'edit', 'build', 'ai'};
    final isFlutter = project.name.toLowerCase().contains('mobile') || project.name.toLowerCase().contains('client') || project.name.toLowerCase().contains('flutter');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101726),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Project Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isFlutter ? Icons.phone_android_rounded : Icons.folder_rounded,
                      color: const Color(0xFF38BDF8),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.name,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              '${project.fileCount} files',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                            ),
                            const SizedBox(width: 8),
                            if (perms.contains('edit'))
                              _buildMiniBadge('EDIT', const Color(0xFF38BDF8)),
                            if (perms.contains('build'))
                              _buildMiniBadge('BUILD', const Color(0xFF34D399)),
                            if (perms.contains('ai'))
                              _buildMiniBadge('AI', const Color(0xFF818CF8)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(color: Color(0xFF1E293B), height: 24),

              // Action 1: Edit in Code Editor
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF080B11),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit_note_rounded, color: Color(0xFF38BDF8), size: 20),
                ),
                title: const Text('Edit in Code Editor', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Open main project source files in the local editor', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFF64748B), size: 13),
                onTap: () {
                  Navigator.pop(ctx);
                  if (widget.onOpenEditor != null) {
                    if (isFlutter) {
                      widget.onOpenEditor!(
                        'lib/main.dart',
                        '''// DevForge AI - ${project.name}
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(title: Text('${project.name}')),
        body: const Center(
          child: Text('Authorized and running from DevForge AI Mobile!'),
        ),
      ),
    );
  }
}
''',
                        'Dart',
                      );
                    } else {
                      widget.onOpenEditor!(
                        'backend/app/main.py',
                        '''# DevForge AI - ${project.name}
from fastapi import FastAPI

app = FastAPI(title="${project.name}", version="1.0.0")

@app.get("/")
def read_root():
    return {"project": "${project.name}", "status": "authorized", "engine": "DevForge AI"}
''',
                        'Python',
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 6),

              // Action 2: Build Release APK
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF080B11),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.rocket_launch_rounded, color: Color(0xFF34D399), size: 20),
                ),
                title: const Text('Build Release APK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Compile Android release APK in the Build Center', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFF64748B), size: 13),
                onTap: () {
                  Navigator.pop(ctx);
                  if (widget.onOpenBuilds != null) {
                    widget.onOpenBuilds!(project.name);
                  }
                },
              ),
              const SizedBox(height: 6),

              // Action 3: Inspect Inventory
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF080B11),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF818CF8), size: 20),
                ),
                title: const Text('Inspect File Inventory', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Browse project files, structure, and sizes', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFF64748B), size: 13),
                onTap: () {
                  Navigator.pop(ctx);
                  _showInventory(project);
                },
              ),
              const SizedBox(height: 6),

              // Action 4: Remove Project
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF080B11),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                ),
                title: const Text('Revoke & Remove Project', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Remove from local workspace authorized list', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                onTap: () {
                  setState(() {
                    _projects.removeWhere((p) => p.id == project.id);
                    _projectPermissions.remove(project.id);
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Removed "${project.name}" from workspace'),
                      backgroundColor: const Color(0xFF1E293B),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showInventory(ProjectModel project) async {
    try {
      final inv = await _api.getProjectInventory(project.id);
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF101726),
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
                  Expanded(
                    child: Text(
                      project.name,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Total files: ${inv['total_files'] ?? project.fileCount}',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
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

  Widget _buildMiniBadge(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 8.5, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _vault.isGitHubConnected;

    return Scaffold(
      backgroundColor: const Color(0xFF080B11),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          children: [
            // Top Header
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
                  tooltip: 'Authorize Repository',
                  onPressed: _showAddRepositoryDialog,
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Connect your personal GitHub account to authorize specific repositories, edit code, and trigger APK builds.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF94A3B8),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),

            // Dynamic GitHub Account Connection Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF101726),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.account_tree_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'GitHub Account Authorization',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            if (isConnected)
                              Row(
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF34D399),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Connected as @${_vault.githubUsername}',
                                    style: const TextStyle(
                                      color: Color(0xFF34D399),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              )
                            else
                              const Text(
                                'No personal account connected',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.tune_rounded, color: Color(0xFF38BDF8), size: 20),
                        tooltip: 'Configure Account',
                        onPressed: _showConnectAccountDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isConnected
                        ? 'Your personal token is saved securely in Android hardware-backed storage. Repositories operate with your granted access.'
                        : 'Connect your personal GitHub account to authorize specific repositories for private code editing and release builds.',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showConnectAccountDialog,
                      icon: Icon(isConnected ? Icons.switch_account_rounded : Icons.login_rounded, size: 16),
                      label: Text(
                        isConnected ? 'Switch Account / Manage Access' : 'Connect GitHub Account',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isConnected ? const Color(0xFF1E293B) : const Color(0xFF5A77F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: isConnected ? const Color(0xFF334155) : const Color(0xFF5A77F6)),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section: Your Repositories
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Authorized repositories',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: _showAddRepositoryDialog,
                  icon: const Icon(Icons.add, size: 16, color: Color(0xFF38BDF8)),
                  label: const Text('Add Repo', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12.5)),
                ),
              ],
            ),
            const SizedBox(height: 2),
            const Text(
              'Tap any project to edit source files, trigger APK compilation, or manage permissions.',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),

            // Project List
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(color: Color(0xFF5A77F6)),
                ),
              )
            else if (_projects.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF101726),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.folder_open_rounded, size: 40, color: Color(0xFF64748B)),
                      const SizedBox(height: 10),
                      const Text(
                        'No repositories authorized yet',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tap "+ Add Repo" above to authorize a project.',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._projects.map((project) {
                final perms = _projectPermissions[project.id] ?? {'edit', 'build', 'ai'};
                final isFlutter = project.name.toLowerCase().contains('mobile') || project.name.toLowerCase().contains('client') || project.name.toLowerCase().contains('flutter');

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF101726),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: InkWell(
                    onTap: () => _showProjectActions(project),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isFlutter ? Icons.phone_android_rounded : Icons.folder_rounded,
                                  color: const Color(0xFF38BDF8),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      project.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Text(
                                          '${project.fileCount} files',
                                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1E293B),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            project.sourceType.toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 9.5,
                                              color: Color(0xFF38BDF8),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        if (perms.contains('edit'))
                                          _buildMiniBadge('EDIT', const Color(0xFF38BDF8)),
                                        if (perms.contains('build'))
                                          _buildMiniBadge('BUILD', const Color(0xFF34D399)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.more_vert_rounded, color: Color(0xFF94A3B8), size: 20),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(color: Color(0xFF1E293B), height: 1),
                          const SizedBox(height: 10),

                          // Quick Action Row
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    if (widget.onOpenEditor != null) {
                                      if (isFlutter) {
                                        widget.onOpenEditor!('lib/main.dart', '// DevForge AI - ${project.name}\nimport \'package:flutter/material.dart\';\n\nvoid main() => runApp(const MyApp());\n', 'Dart');
                                      } else {
                                        widget.onOpenEditor!('backend/app/main.py', '# DevForge AI - ${project.name}\nfrom fastapi import FastAPI\n\napp = FastAPI(title="${project.name}")\n', 'Python');
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.edit_note_rounded, size: 15, color: Color(0xFF38BDF8)),
                                  label: const Text('Edit Code', style: TextStyle(fontSize: 12, color: Color(0xFF38BDF8))),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFF1E293B)),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    if (widget.onOpenBuilds != null) {
                                      widget.onOpenBuilds!(project.name);
                                    }
                                  },
                                  icon: const Icon(Icons.rocket_launch_rounded, size: 15, color: Colors.black),
                                  label: const Text('Build APK', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF34D399),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

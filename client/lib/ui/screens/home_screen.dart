import 'package:flutter/material.dart';
import 'ai_studio_screen.dart';
import 'builds_screen.dart';
import 'editor_screen.dart';
import 'local_models_screen.dart';
import 'projects_screen.dart';
import 'vault_settings_screen.dart';
import 'native_workspace_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const HomeScreen({super.key, required this.onLogout});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String? _editorFileName;
  String? _editorCode;
  String? _editorLanguage;
  String? _buildTargetProject;

  void _switchTab(int index) {
    setState(() => _currentIndex = index);
  }

  void _openProjectInEditor(String fileName, String code, String language) {
    setState(() {
      _editorFileName = fileName;
      _editorCode = code;
      _editorLanguage = language;
      _currentIndex = 3;
    });
  }

  void _openProjectInBuilds(String projectName) {
    setState(() {
      _buildTargetProject = projectName;
      _currentIndex = 4;
    });
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => VaultSettingsScreen(onLogout: widget.onLogout),
      ),
    );
  }

  void _openLocalModels() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => const LocalModelsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _HomeDashboardTab(
        onNavigate: _switchTab,
        onOpenSettings: _openSettings,
        onOpenLocalModels: _openLocalModels,
      ),
      ProjectsScreen(
        onOpenEditor: _openProjectInEditor,
        onOpenBuilds: _openProjectInBuilds,
      ),
      AIStudioScreen(onOpenLocalModels: _openLocalModels),
      EditorScreen(
        initialFileName: _editorFileName,
        initialCode: _editorCode,
        initialLanguage: _editorLanguage,
        onNavigateToBuilds: () => _switchTab(4),
      ),
      BuildsScreen(
        targetProjectName: _buildTargetProject,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _switchTab,
        backgroundColor: const Color(0xFF0A0D15),
        indicatorColor: const Color(0xFF25314C),
        elevation: 8,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded, size: 22),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_rounded, size: 22),
            label: 'Projects',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_rounded, size: 22),
            label: 'AI Studio',
          ),
          NavigationDestination(
            icon: Icon(Icons.code_rounded, size: 22),
            label: 'Editor',
          ),
          NavigationDestination(
            icon: Icon(Icons.rocket_launch_rounded, size: 22),
            label: 'Builds',
          ),
        ],
      ),
    );
  }
}

class _HomeDashboardTab extends StatelessWidget {
  final Function(int) onNavigate;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenLocalModels;

  const _HomeDashboardTab({
    required this.onNavigate,
    required this.onOpenSettings,
    required this.onOpenLocalModels,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0E14),
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Color(0xFF34D399), size: 22),
            const SizedBox(width: 8),
            RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                children: [
                  TextSpan(text: 'DevForge ', style: TextStyle(color: Colors.white)),
                  TextSpan(text: 'AI', style: TextStyle(color: Color(0xFF34D399))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            tooltip: 'Settings & Key Vault',
            onPressed: onOpenSettings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        children: [
          // Hero Gradient Card
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF132238), Color(0xFF0D3238)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF1E3A4B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOUR AI DEVELOPMENT WORKSPACE',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: Color(0xFF38BDF8),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Build something\nremarkable.',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Plan, code, review and ship from your phone.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: () => onNavigate(2), // Switch to AI Studio
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text(
                    'Start with AI',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5A77F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Offline AI model Card
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onOpenLocalModels,
              borderRadius: BorderRadius.circular(16),
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
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF132B3A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.memory_rounded, color: Color(0xFF34D399), size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Offline AI model',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Download or manage your on-device Qwen model',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Color(0xFF64748B), size: 20),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Workspace Section Header
          const Text(
            'Workspace',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),

          // 2x2 Workspace Grid
          Row(
            children: [
              Expanded(
                child: _buildWorkspaceCard(
                  icon: Icons.folder_outlined,
                  title: 'Projects',
                  subtitle: 'Your repositories',
                  onTap: () => onNavigate(1), // Switch to Projects
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildWorkspaceCard(
                  icon: Icons.code_rounded,
                  title: 'Code Editor',
                  subtitle: 'Edit project files',
                  onTap: () => onNavigate(3), // Switch to Editor
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildWorkspaceCard(
                  icon: Icons.smart_toy_outlined,
                  title: 'AI Studio',
                  subtitle: 'Multi-provider agent',
                  onTap: () => onNavigate(2), // Switch to AI Studio
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildWorkspaceCard(
                  icon: Icons.rocket_launch_outlined,
                  title: 'Build Center',
                  subtitle: 'APK, AAB & Web',
                  onTap: () => onNavigate(4), // Switch to Builds
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildWorkspaceCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF121A29),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: const Color(0xFF34D399), size: 24),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

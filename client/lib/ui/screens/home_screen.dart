import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import 'local_models_screen.dart';
import 'project_explorer_screen.dart';
import 'task_chat_screen.dart';
import 'vault_settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const HomeScreen({super.key, required this.onLogout});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  ProjectModel? _activeProject;

  void _onProjectSelected(ProjectModel project) {
    setState(() {
      _activeProject = project;
      _currentIndex = 1; // Switch to Tasks tab
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      ProjectExplorerScreen(onSelectProject: _onProjectSelected),
      TaskChatScreen(initialProject: _activeProject),
      const LocalModelsScreen(),
      VaultSettingsScreen(onLogout: widget.onLogout),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder), label: 'Projects'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Agent Tasks'),
          NavigationDestination(icon: Icon(Icons.memory_outlined), selectedIcon: Icon(Icons.memory), label: 'Local GGUF'),
          NavigationDestination(icon: Icon(Icons.vpn_key_outlined), selectedIcon: Icon(Icons.vpn_key), label: 'Vault'),
        ],
      ),
    );
  }
}

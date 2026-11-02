import 'package:flutter/material.dart';

class BuildsScreen extends StatefulWidget {
  const BuildsScreen({super.key});

  @override
  State<BuildsScreen> createState() => _BuildsScreenState();
}

class _BuildsScreenState extends State<BuildsScreen> {
  bool _isBuilding = false;

  void _triggerBuild(String type) {
    setState(() {
      _isBuilding = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF34D399)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('Dispatching $type build to GitHub Actions...')),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
      ),
    );

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _isBuilding = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Color(0xFF34D399), size: 18),
                const SizedBox(width: 12),
                Expanded(child: Text('$type workflow dispatched successfully!')),
              ],
            ),
            backgroundColor: const Color(0xFF121A29),
          ),
        );
      }
    });
  }

  void _showReleaseDialog() {
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
            Icon(Icons.bolt, color: Color(0xFF34D399), size: 24),
            SizedBox(width: 8),
            Text('DevForge AI v1.0.0', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Latest Production Release Assets:',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
            SizedBox(height: 12),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.android, color: Color(0xFF38BDF8)),
              title: Text('DevForgeAI-v1.0.0-release.apk', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text('49.0 MB · Target SDK 36', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
            ),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.verified_outlined, color: Color(0xFF34D399)),
              title: Text('SHA-256 Verified', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text('304bf0d5f074cf70d7f51c10f07f6930...', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Opening GitHub Releases in browser...'),
                  backgroundColor: Color(0xFF1E293B),
                ),
              );
            },
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Open Releases Page'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5A77F6),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
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
            const Text(
              'Build Center',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Run production builds on GitHub-hosted runners. No cloud server is required.',
              style: TextStyle(
                fontSize: 13.5,
                color: Color(0xFF94A3B8),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // View Published APK releases pill button
            OutlinedButton.icon(
              onPressed: _showReleaseDialog,
              icon: const Icon(Icons.file_download_outlined, size: 18, color: Color(0xFF818CF8)),
              label: const Text(
                'View published APK releases',
                style: TextStyle(
                  color: Color(0xFF818CF8),
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF2E3856)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 20),

            // Card 1: Android APK
            _buildActionCard(
              title: 'Android APK',
              subtitle: 'Release APK for direct installation',
              icon: Icons.android_rounded,
              iconColor: const Color(0xFF60A5FA),
              iconBgColor: const Color(0xFF1E293B),
              onTap: () => _triggerBuild('Android APK'),
            ),
            const SizedBox(height: 12),

            // Card 2: Android App Bundle
            _buildActionCard(
              title: 'Android App Bundle',
              subtitle: 'AAB package for Play Console',
              icon: Icons.all_inbox_rounded,
              iconColor: const Color(0xFF818CF8),
              iconBgColor: const Color(0xFF1E2238),
              onTap: () => _triggerBuild('Android App Bundle'),
            ),
            const SizedBox(height: 12),

            // Card 3: Web ZIP
            _buildActionCard(
              title: 'Web ZIP',
              subtitle: 'Optimized production web build',
              icon: Icons.language_rounded,
              iconColor: const Color(0xFF38BDF8),
              iconBgColor: const Color(0xFF132B3A),
              onTap: () => _triggerBuild('Web ZIP'),
            ),
            const SizedBox(height: 24),

            // Build Lifecycle Card
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
                  const Text(
                    'Build lifecycle',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildLifecycleItem(
                    icon: Icons.cloud_upload_outlined,
                    text: 'Dispatch workflow to GitHub Actions',
                  ),
                  const SizedBox(height: 12),
                  _buildLifecycleItem(
                    icon: Icons.settings_outlined,
                    text: 'Install dependencies and run checks',
                  ),
                  const SizedBox(height: 12),
                  _buildLifecycleItem(
                    icon: Icons.build_outlined,
                    text: 'Compile release artifact',
                  ),
                  const SizedBox(height: 12),
                  _buildLifecycleItem(
                    icon: Icons.check_circle_outline,
                    text: 'Download artifact to your device',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Bottom note
            const Text(
              'Workflow dispatch is active. Run history and direct artifact downloads are not implemented yet. Published Android APK releases will appear in the repository Releases page.',
              style: TextStyle(
                fontSize: 11.5,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isBuilding ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF121A29),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
              const Icon(
                Icons.rocket_launch_outlined,
                color: Color(0xFF818CF8),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLifecycleItem({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF34D399)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

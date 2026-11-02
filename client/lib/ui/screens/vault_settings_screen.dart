import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/secure_vault.dart';

class VaultSettingsScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const VaultSettingsScreen({super.key, required this.onLogout});

  @override
  State<VaultSettingsScreen> createState() => _VaultSettingsScreenState();
}

class _VaultSettingsScreenState extends State<VaultSettingsScreen> {
  final SecureVault _vault = SecureVault();
  final ApiService _api = ApiService();

  final _keyController = TextEditingController();
  final _urlController = TextEditingController();
  UserModel? _currentUser;
  bool _isLoadingUser = true;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _keyController.text = _vault.openRouterApiKey ?? '';
    _urlController.text = _vault.baseUrl;
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final user = await _api.getMe();
      setState(() => _currentUser = user);
    } catch (_) {}
    if (mounted) setState(() => _isLoadingUser = false);
  }

  void _saveSettings() {
    _vault.openRouterApiKey = _keyController.text.trim().isEmpty ? null : _keyController.text.trim();
    _vault.baseUrl = _urlController.text.trim();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vault settings saved securely!')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Secure Key Vault & Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User Card
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(_currentUser?.email ?? 'Authenticated User', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(_isLoadingUser ? 'Loading profile...' : 'User ID: ${_currentUser?.id ?? "..."}'),
            ),
          ),
          const SizedBox(height: 16),
          // Vault Settings Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.vpn_key, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('Secure Model Credentials', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your OpenRouter API Key is stored only in client secure storage and transmitted via request header. It is never logged or persisted in the database.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _keyController,
                    obscureText: _obscureKey,
                    decoration: InputDecoration(
                      labelText: 'OpenRouter API Key (sk-or-v1-...)',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureKey ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscureKey = !_obscureKey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'API Control Plane Base URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _saveSettings,
                        icon: const Icon(Icons.save),
                        label: const Text('Save to Secure Vault'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Logout Button
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sign Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              subtitle: const Text('Revokes session tokens and clears cached credentials.'),
              onTap: () async {
                await _api.logout();
                widget.onLogout();
              },
            ),
          ),
        ],
      ),
    );
  }
}

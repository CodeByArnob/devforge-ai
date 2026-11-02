import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../../core/services/secure_vault.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final ApiService _api = ApiService();
  final SecureVault _vault = SecureVault();

  final _emailController = TextEditingController(text: 'admin@devforge.ai');
  final _passwordController = TextEditingController(text: 'Password1234!');
  final _urlController = TextEditingController();

  bool _isRegister = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _recoveryTokenNotice;

  @override
  void initState() {
    super.initState();
    _urlController.text = _vault.baseUrl;
  }

  void _selectPresetUrl(String url) {
    setState(() {
      _urlController.text = url;
      _vault.baseUrl = url;
      _errorMessage = null;
    });
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _recoveryTokenNotice = null;
    });
    _vault.baseUrl = _urlController.text.trim();

    try {
      if (_isRegister) {
        await _api.register(_emailController.text.trim(), _passwordController.text);
      } else {
        await _api.login(_emailController.text.trim(), _passwordController.text);
      }
      widget.onLoginSuccess();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('ApiException', '').trim();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _enterDemo() {
    _vault.enterDemoMode();
    widget.onLoginSuccess();
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email above first')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final token = await _api.requestPasswordRecovery(email);
      setState(() {
        _recoveryTokenNotice = token != null
            ? 'Recovery token generated: $token\n(Use this token to reset your password)'
            : 'Password recovery request sent to your email.';
      });
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.bolt, color: theme.colorScheme.primary, size: 30),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'DevForge AI',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isRegister ? 'Create your platform account' : 'Sign in to access your autonomous workspace',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ExpansionTile(
                      title: const Text('Server Configuration', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        _urlController.text.isEmpty ? 'http://10.0.2.2:8000' : _urlController.text,
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                          child: TextField(
                            controller: _urlController,
                            decoration: const InputDecoration(
                              labelText: 'API Control Plane URL',
                              helperText: 'e.g. http://192.168.110.215:8000 for mobile over Wi-Fi',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              ActionChip(
                                avatar: const Icon(Icons.wifi, size: 14),
                                label: const Text('PC Wi-Fi (192.168.110.215)'),
                                onPressed: () => _selectPresetUrl('http://192.168.110.215:8000'),
                              ),
                              ActionChip(
                                avatar: const Icon(Icons.android, size: 14),
                                label: const Text('Emulator (10.0.2.2)'),
                                onPressed: () => _selectPresetUrl('http://10.0.2.2:8000'),
                              ),
                              ActionChip(
                                avatar: const Icon(Icons.computer, size: 14),
                                label: const Text('Localhost (127.0.0.1)'),
                                onPressed: () => _selectPresetUrl('http://127.0.0.1:8000'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade400.withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: Colors.redAccent, fontSize: 13, height: 1.35),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: _enterDemo,
                              icon: const Icon(Icons.play_circle_outline, size: 18),
                              label: const Text('Switch to Offline Demo Workspace'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.amberAccent,
                                side: BorderSide(color: Colors.amberAccent.withValues(alpha: 0.6)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_recoveryTokenNotice != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade400),
                        ),
                        child: SelectableText(
                          _recoveryTokenNotice!,
                          style: const TextStyle(color: Colors.green, fontSize: 13),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(_isRegister ? 'Register & Launch' : 'Sign In', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _enterDemo,
                      icon: const Icon(Icons.explore_outlined, size: 18),
                      label: const Text(
                        'Explore in Offline Demo Mode',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: 4,
                      children: [
                        TextButton(
                          onPressed: () => setState(() {
                            _isRegister = !_isRegister;
                            _errorMessage = null;
                          }),
                          child: Text(_isRegister ? 'Already have an account? Sign In' : 'Create Account'),
                        ),
                        if (!_isRegister)
                          TextButton(
                            onPressed: _isLoading ? null : _forgotPassword,
                            child: const Text('Forgot Password?'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

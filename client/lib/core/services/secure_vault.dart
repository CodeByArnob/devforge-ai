import 'dart:async';

class SecureVault {
  static final SecureVault _instance = SecureVault._internal();
  factory SecureVault() => _instance;
  SecureVault._internal();

  final Map<String, String> _storage = {};
  final StreamController<String> _vaultUpdates =
      StreamController<String>.broadcast();

  Stream<String> get onVaultUpdated => _vaultUpdates.stream;

  String _baseUrl = '';
  String _providerBaseUrl = 'https://openrouter.ai/api/v1';
  String? _accessToken;
  String? _refreshToken;
  String? _openRouterApiKey;
  String? _githubUsername;
  String? _githubToken;

  bool get isDemoMode => _storage['isDemoMode'] == 'true';
  set isDemoMode(bool value) {
    _storage['isDemoMode'] = value.toString();
    _vaultUpdates.add('isDemoMode');
  }

  void enterDemoMode() {
    isDemoMode = true;
    accessToken = 'devforge-demo-session-token';
    refreshToken = 'devforge-demo-refresh-token';
    // Never insert a fake provider key: live chat requires a real user key.
  }

  String get baseUrl => _baseUrl;
  set baseUrl(String url) {
    _baseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    _storage['baseUrl'] = _baseUrl;
    _vaultUpdates.add('baseUrl');
  }

  String get providerBaseUrl => _providerBaseUrl;
  set providerBaseUrl(String url) {
    _providerBaseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    _storage['providerBaseUrl'] = _providerBaseUrl;
    _vaultUpdates.add('providerBaseUrl');
  }

  String? get accessToken => _accessToken;
  set accessToken(String? token) {
    _accessToken = token;
    if (token == null) {
      _storage.remove('accessToken');
    } else {
      _storage['accessToken'] = token;
    }
    _vaultUpdates.add('accessToken');
  }

  String? get refreshToken => _refreshToken;
  set refreshToken(String? token) {
    _refreshToken = token;
    if (token == null) {
      _storage.remove('refreshToken');
    } else {
      _storage['refreshToken'] = token;
    }
    _vaultUpdates.add('refreshToken');
  }

  String? get openRouterApiKey => _openRouterApiKey;
  set openRouterApiKey(String? key) {
    _openRouterApiKey = key;
    if (key == null || key.isEmpty) {
      _storage.remove('openRouterApiKey');
    } else {
      _storage['openRouterApiKey'] = key;
    }
    _vaultUpdates.add('openRouterApiKey');
  }

  String? get githubUsername => _githubUsername;
  set githubUsername(String? username) {
    _githubUsername = username;
    if (username == null) {
      _storage.remove('githubUsername');
    } else {
      _storage['githubUsername'] = username;
    }
    _vaultUpdates.add('githubUsername');
  }

  String? get githubToken => _githubToken;
  set githubToken(String? token) {
    _githubToken = token;
    if (token == null) {
      _storage.remove('githubToken');
    } else {
      _storage['githubToken'] = token;
    }
    _vaultUpdates.add('githubToken');
  }

  bool get isAuthenticated => _accessToken != null && _accessToken!.isNotEmpty;
  bool get hasOpenRouterKey =>
      _openRouterApiKey != null && _openRouterApiKey!.isNotEmpty;
  bool get isGitHubConnected =>
      _githubUsername != null && _githubUsername!.isNotEmpty;

  void clearSession() {
    _accessToken = null;
    _refreshToken = null;
    _storage.remove('accessToken');
    _storage.remove('refreshToken');
    _vaultUpdates.add('session_cleared');
  }

  void clearAll() {
    _storage.clear();
    _baseUrl = '';
    _providerBaseUrl = 'https://openrouter.ai/api/v1';
    _accessToken = null;
    _refreshToken = null;
    _openRouterApiKey = null;
    _githubUsername = null;
    _githubToken = null;
    _vaultUpdates.add('all_cleared');
  }
}

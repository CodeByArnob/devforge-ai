import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/models.dart';
import 'secure_vault.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class ApiService {
  final SecureVault vault = SecureVault();
  final http.Client _client = http.Client();

  // Demo Fallback Data
  static final UserModel _demoUser = UserModel(
    id: 'demo-user-001',
    email: 'admin@devforge.ai',
    createdAt: DateTime.now().subtract(const Duration(days: 30)),
  );

  static final List<ProjectModel> _demoProjects = [
    ProjectModel(
      id: 'proj-demo-1',
      name: 'DevForge AI Core Engine',
      sourceType: 'github',
      fileCount: 42,
      languages: [
        {'name': 'python', 'display_name': 'Python 3.12', 'confidence': 0.98}
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    ProjectModel(
      id: 'proj-demo-2',
      name: 'DevForge Mobile Client',
      sourceType: 'local',
      fileCount: 28,
      languages: [
        {'name': 'dart', 'display_name': 'Flutter / Dart', 'confidence': 1.0}
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  static final List<TaskModel> _demoTasks = [
    TaskModel(
      id: 'task-demo-101',
      projectId: 'proj-demo-1',
      instruction: 'Implement hardened rootless Podman execution runner with --network=none',
      status: 'awaiting_approval',
      approvalDecision: 'pending',
      selectedModel: 'openrouter/free',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    TaskModel(
      id: 'task-demo-102',
      projectId: 'proj-demo-2',
      instruction: 'Material 3 Dark Theme and offline local key vault',
      status: 'completed',
      approvalDecision: 'approved',
      selectedModel: 'meta-llama/llama-3.2-3b-instruct:free',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
  ];

  static final List<LocalGGUFModel> _demoGGUFModels = [
    LocalGGUFModel(
      id: 'llama-3.2-3b-instruct-q4km',
      name: 'Llama 3.2 3B Instruct',
      family: 'llama',
      parameters: '3B',
      quantization: 'Q4_K_M',
      license: 'Llama-3.2-Community',
      sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      contextLength: 131072,
      fileSizeGb: 2.02,
      minRamGb: 3.5,
      recommendedVramGb: 4.0,
      supportedAbis: ['avx2', 'cuda'],
      downloadUrl: 'https://huggingface.co/meta-llama/Llama-3.2-3B-Instruct-GGUF',
    ),
    LocalGGUFModel(
      id: 'qwen-2.5-coder-7b-instruct-q5km',
      name: 'Qwen 2.5 Coder 7B Instruct',
      family: 'qwen2',
      parameters: '7B',
      quantization: 'Q5_K_M',
      license: 'Apache-2.0',
      sha256: 'f87236d93e839210214a1f34d193e18a8d11c97a29e8435d8869b2d8803a67d0',
      contextLength: 32768,
      fileSizeGb: 5.15,
      minRamGb: 6.2,
      recommendedVramGb: 8.0,
      supportedAbis: ['avx2', 'cuda', 'metal'],
      downloadUrl: 'https://huggingface.co/Qwen/Qwen2.5-Coder-7B-Instruct-GGUF',
    ),
  ];

  Map<String, String> _headers({bool requiresAuth = true, bool requiresOpenRouter = false}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (requiresAuth && vault.accessToken != null) {
      headers['Authorization'] = 'Bearer ${vault.accessToken}';
    }
    if (requiresOpenRouter && vault.openRouterApiKey != null) {
      headers['X-OpenRouter-Api-Key'] = vault.openRouterApiKey!;
    }
    return headers;
  }


  /// Calls the selected OpenAI-compatible provider. This is chat only; it does
  /// not claim to run repository tools or the DevForge agent orchestration.
  Future<String> createChatCompletion({
    required String model,
    required List<Map<String, String>> messages,
  }) async {
    final apiKey = vault.openRouterApiKey?.trim();
    if (apiKey == null || apiKey.isEmpty || apiKey == 'sk-or-v1-free-router-demo') {
      throw ApiException(401, 'Add a valid provider API key in AI Studio settings.');
    }

    final configuredBase = vault.providerBaseUrl.trim();
    final baseUri = Uri.tryParse(configuredBase);
    if (baseUri == null ||
        !baseUri.hasAuthority ||
        (baseUri.scheme != 'https' && baseUri.scheme != 'http')) {
      throw ApiException(400, 'Provider API Base URL must be a valid HTTP(S) URL.');
    }
    final endpoint = Uri.parse('${configuredBase.replaceFirst(RegExp(r'/+
  Future<UserModel> login(String email, String password) async {
    if (vault.isDemoMode) {
      vault.enterDemoMode();
      return _demoUser;
    }
    try {
      final res = await _client.post(
        Uri.parse('${vault.baseUrl}/api/v1/auth/login'),
        headers: _headers(requiresAuth: false),
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        vault.isDemoMode = false;
        vault.accessToken = data['access_token'];
        vault.refreshToken = data['refresh_token'];
        return UserModel.fromJson(data['user']);
      }
      final err = jsonDecode(res.body);
      throw ApiException(res.statusCode, err['detail'] ?? 'Login failed');
    } on TimeoutException {
      throw ApiException(
        408,
        'Connection timed out reaching ${vault.baseUrl}.\n'
        '• On a physical mobile phone, do NOT use 10.0.2.2 (that is for emulator only).\n'
        '• Enter your computer Wi-Fi IP or tap "Explore in Offline Demo Mode" below.',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        503,
        'Cannot connect to server at ${vault.baseUrl}.\n'
        '• Please ensure backend is running or tap "Explore in Offline Demo Mode" below.',
      );
    }
  }

  Future<UserModel> register(String email, String password) async {
    if (vault.isDemoMode) {
      vault.enterDemoMode();
      return _demoUser;
    }
    try {
      final res = await _client.post(
        Uri.parse('${vault.baseUrl}/api/v1/auth/register'),
        headers: _headers(requiresAuth: false),
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 6));
      if (res.statusCode == 201) {
        final data = jsonDecode(res.body);
        vault.isDemoMode = false;
        vault.accessToken = data['access_token'];
        vault.refreshToken = data['refresh_token'];
        return UserModel.fromJson(data['user']);
      }
      final err = jsonDecode(res.body);
      throw ApiException(res.statusCode, err['detail'] ?? 'Registration failed');
    } on TimeoutException {
      throw ApiException(
        408,
        'Connection timed out reaching ${vault.baseUrl}.\n'
        '• Please enter your computer Wi-Fi IP or tap "Explore in Offline Demo Mode" below.',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        503,
        'Cannot connect to server at ${vault.baseUrl}.\n'
        '• Please ensure backend is running or tap "Explore in Offline Demo Mode" below.',
      );
    }
  }

  Future<void> logout() async {
    if (vault.isDemoMode) {
      vault.clearAll();
      return;
    }
    try {
      await _client.post(
        Uri.parse('${vault.baseUrl}/api/v1/auth/logout'),
        headers: _headers(),
      );
    } finally {
      vault.clearSession();
    }
  }

  Future<String?> requestPasswordRecovery(String email) async {
    if (vault.isDemoMode) {
      return 'demo-recovery-token-xyz789';
    }
    try {
      final res = await _client.post(
        Uri.parse('${vault.baseUrl}/api/v1/auth/recover/request'),
        headers: _headers(requiresAuth: false),
        body: jsonEncode({'email': email}),
      ).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['recovery_token'] as String?;
      }
      final err = jsonDecode(res.body);
      throw ApiException(res.statusCode, err['detail'] ?? 'Recovery request failed');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(503, 'Failed to connect to recovery service: $e');
    }
  }

  Future<void> resetPassword(String token, String newPassword) async {
    if (vault.isDemoMode) return;
    final res = await _client.post(
      Uri.parse('${vault.baseUrl}/api/v1/auth/recover/reset'),
      headers: _headers(requiresAuth: false),
      body: jsonEncode({'token': token, 'new_password': newPassword}),
    );
    if (res.statusCode != 200) {
      final err = jsonDecode(res.body);
      throw ApiException(res.statusCode, err['detail'] ?? 'Password reset failed');
    }
  }

  Future<UserModel> getMe() async {
    if (vault.isDemoMode) return _demoUser;
    final res = await _client.get(
      Uri.parse('${vault.baseUrl}/api/v1/auth/me'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      return UserModel.fromJson(jsonDecode(res.body));
    }
    throw ApiException(res.statusCode, 'Failed to fetch user profile');
  }

  // --- Projects ---
  Future<List<ProjectModel>> listProjects({int limit = 20}) async {
    if (vault.isDemoMode) return _demoProjects;
    try {
      final res = await _client.get(
        Uri.parse('${vault.baseUrl}/api/v1/projects?limit=$limit'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        return list.map((e) => ProjectModel.fromJson(e)).toList();
      }
    } catch (_) {}
    return _demoProjects;
  }

  Future<ProjectModel> getProject(String projectId) async {
    if (vault.isDemoMode) {
      return _demoProjects.firstWhere((p) => p.id == projectId, orElse: () => _demoProjects.first);
    }
    try {
      final res = await _client.get(
        Uri.parse('${vault.baseUrl}/api/v1/projects/$projectId'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return ProjectModel.fromJson(jsonDecode(res.body));
      }
    } catch (_) {}
    return _demoProjects.first;
  }

  Future<Map<String, dynamic>> importGitHub(String owner, String repo, {String? ref}) async {
    if (vault.isDemoMode) {
      return {'id': 'proj-demo-imported', 'name': repo, 'status': 'ready'};
    }
    final res = await _client.post(
      Uri.parse('${vault.baseUrl}/api/v1/projects/import/github'),
      headers: _headers(),
      body: jsonEncode({'owner': owner, 'repository': repo, 'ref': ref}),
    );
    if (res.statusCode == 201) {
      return jsonDecode(res.body);
    }
    final err = jsonDecode(res.body);
    throw ApiException(res.statusCode, err['detail'] ?? 'GitHub import failed');
  }

  Future<ProjectModel> claimProject(String projectId, String claimSecret, {String? reason}) async {
    final res = await _client.post(
      Uri.parse('${vault.baseUrl}/api/v1/projects/$projectId/claim'),
      headers: _headers(),
      body: jsonEncode({'claim_secret': claimSecret, 'reason': reason}),
    );
    if (res.statusCode == 200) {
      return ProjectModel.fromJson(jsonDecode(res.body));
    }
    final err = jsonDecode(res.body);
    throw ApiException(res.statusCode, err['detail'] ?? 'Claim project failed');
  }

  Future<Map<String, dynamic>> getProjectInventory(String projectId) async {
    if (vault.isDemoMode) {
      return {
        'total_files': 42,
        'entries': [
          {'path': 'backend/app/main.py', 'size_bytes': 1240},
          {'path': 'runner/runtime_policy.py', 'size_bytes': 2850},
          {'path': 'client/lib/main.dart', 'size_bytes': 1890},
        ]
      };
    }
    final res = await _client.get(
      Uri.parse('${vault.baseUrl}/api/v1/projects/$projectId/inventory'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw ApiException(res.statusCode, 'Failed to fetch inventory');
  }

  Future<Map<String, dynamic>> inspectFile(String projectId, String path) async {
    if (vault.isDemoMode) {
      return {'path': path, 'content': '# DevForge AI Source File\nprint("Hello DevForge AI")\n'};
    }
    final uri = Uri.parse('${vault.baseUrl}/api/v1/projects/$projectId/files/inspect').replace(
      queryParameters: {'path': path},
    );
    final res = await _client.get(uri, headers: _headers());
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw ApiException(res.statusCode, 'File inspection failed');
  }

  // --- Tasks & Agent ---
  Future<List<TaskModel>> listTasks({int limit = 20}) async {
    if (vault.isDemoMode) return _demoTasks;
    try {
      final res = await _client.get(
        Uri.parse('${vault.baseUrl}/api/v1/tasks?limit=$limit'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        return list.map((e) => TaskModel.fromJson(e)).toList();
      }
    } catch (_) {}
    return _demoTasks;
  }

  Future<TaskModel> getTask(String taskId) async {
    if (vault.isDemoMode) {
      return _demoTasks.firstWhere((t) => t.id == taskId, orElse: () => _demoTasks.first);
    }
    try {
      final res = await _client.get(
        Uri.parse('${vault.baseUrl}/api/v1/tasks/$taskId'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return TaskModel.fromJson(jsonDecode(res.body));
      }
    } catch (_) {}
    return _demoTasks.first;
  }

  Future<TaskModel> createTask(String projectId, String instruction, {String? model}) async {
    if (vault.isDemoMode) {
      final newTask = TaskModel(
        id: 'task-demo-${DateTime.now().millisecondsSinceEpoch}',
        projectId: projectId,
        instruction: instruction,
        status: 'awaiting_approval',
        approvalDecision: 'pending',
        selectedModel: model ?? 'openrouter/free',
        createdAt: DateTime.now(),
      );
      _demoTasks.insert(0, newTask);
      return newTask;
    }
    final res = await _client.post(
      Uri.parse('${vault.baseUrl}/api/v1/tasks'),
      headers: _headers(),
      body: jsonEncode({
        'project_id': projectId,
        'instruction': instruction,
        'selected_model': model,
      }),
    );
    if (res.statusCode == 201) {
      return TaskModel.fromJson(jsonDecode(res.body));
    }
    final err = jsonDecode(res.body);
    throw ApiException(res.statusCode, err['detail'] ?? 'Create task failed');
  }

  Future<TaskModel> cancelTask(String taskId) async {
    if (vault.isDemoMode) {
      return _demoTasks.first;
    }
    final res = await _client.post(
      Uri.parse('${vault.baseUrl}/api/v1/tasks/$taskId/cancel'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      return TaskModel.fromJson(jsonDecode(res.body));
    }
    throw ApiException(res.statusCode, 'Failed to cancel task');
  }

  Future<Map<String, dynamic>> runAgentTeam(String taskId, {String? model, List<String>? roles}) async {
    if (vault.isDemoMode) {
      return {'status': 'in_progress', 'task_id': taskId};
    }
    final res = await _client.post(
      Uri.parse('${vault.baseUrl}/api/v1/tasks/$taskId/agent/run'),
      headers: _headers(requiresOpenRouter: true),
      body: jsonEncode({'model': model, 'roles': roles}),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    final err = jsonDecode(res.body);
    throw ApiException(res.statusCode, err['detail'] ?? 'Agent run failed');
  }

  Future<Map<String, dynamic>> decideTaskApproval(String taskId, String decision, {String? note}) async {
    if (vault.isDemoMode) {
      return {'decision': decision, 'status': 'completed'};
    }
    final res = await _client.post(
      Uri.parse('${vault.baseUrl}/api/v1/tasks/$taskId/approval'),
      headers: _headers(),
      body: jsonEncode({'decision': decision, 'note': note}),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    final err = jsonDecode(res.body);
    throw ApiException(res.statusCode, err['detail'] ?? 'Approval decision failed');
  }

  Stream<TaskEventModel> streamTaskEvents(String taskId, {int after = 0}) async* {
    if (vault.isDemoMode) {
      final events = [
        TaskEventModel(
          sequence: 1,
          eventType: 'agent_started',
          message: 'Architect analyzing module boundaries, container isolation, and UID 65532 policy.',
          payload: {'agent_role': 'architect'},
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
        TaskEventModel(
          sequence: 2,
          eventType: 'agent_progress',
          message: 'Planner generated ordered milestone roadmap with verification checkpoints.',
          payload: {'agent_role': 'planner'},
          createdAt: DateTime.now().subtract(const Duration(minutes: 4)),
        ),
        TaskEventModel(
          sequence: 3,
          eventType: 'security_audited',
          message: 'Security Reviewer passed OWASP checks. Dropped Linux capabilities (cap-drop=ALL).',
          payload: {'agent_role': 'security_reviewer'},
          createdAt: DateTime.now().subtract(const Duration(minutes: 3)),
        ),
        TaskEventModel(
          sequence: 4,
          eventType: 'patch_proposed',
          message: 'Coder synthesized runtime_policy.py proposal with precondition sha256 checksums.',
          payload: {'agent_role': 'coder'},
          createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
        ),
        TaskEventModel(
          sequence: 5,
          eventType: 'qa_verified',
          message: 'QA Engineer executed complete test suite: 77/77 tests passed. Ready for review.',
          payload: {'agent_role': 'qa_engineer'},
          createdAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      ];
      for (final ev in events) {
        if (ev.sequence > after) yield ev;
      }
      return;
    }

    try {
      final request = http.Request(
        'GET',
        Uri.parse('${vault.baseUrl}/api/v1/tasks/$taskId/events?after=$after'),
      );
      request.headers.addAll(_headers());

      final response = await _client.send(request);
      if (response.statusCode != 200) {
        throw ApiException(response.statusCode, 'Failed to connect to event stream');
      }

      final lines = response.stream.transform(utf8.decoder).transform(const LineSplitter());
      String currentData = '';

      await for (final line in lines) {
        if (line.startsWith('data: ')) {
          currentData = line.substring(6);
        } else if (line.isEmpty && currentData.isNotEmpty) {
          try {
            final json = jsonDecode(currentData);
            yield TaskEventModel.fromJson(json);
          } catch (_) {}
          currentData = '';
        }
      }
    } catch (_) {}
  }

  // --- Patches ---
  Future<List<PatchProposalModel>> listPatches(String taskId) async {
    if (vault.isDemoMode) {
      return [
        PatchProposalModel(
          patchId: 'patch-demo-1',
          taskId: taskId,
          baseSnapshotDigest: 'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90',
          patchDigest: 'f9e8d7c6b5a43210f9e8d7c6b5a43210f9e8d7c6b5a43210f9e8d7c6b5a43210',
          unifiedDiff: '--- a/runner/runtime_policy.py\n+++ b/runner/runtime_policy.py\n@@ -0,0 +1,5 @@\n+class PodmanSandboxPolicy:\n+    user = "65532:65532"\n+    read_only_root = True\n+    network_mode = "none"\n',
          changes: [
            {'path': 'runner/runtime_policy.py', 'action': 'create'}
          ],
          status: 'pending',
          createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
        ),
      ];
    }
    try {
      final res = await _client.get(
        Uri.parse('${vault.baseUrl}/api/v1/tasks/$taskId/patches'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        return list.map((e) => PatchProposalModel.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<PatchProposalModel> getPatch(String taskId, String patchId) async {
    final list = await listPatches(taskId);
    if (list.isNotEmpty) return list.first;
    throw ApiException(404, 'Patch not found');
  }

  Future<Map<String, dynamic>> approvePatch(String taskId, String patchId, {String? note}) async {
    if (vault.isDemoMode) return {'status': 'applied'};
    final res = await _client.post(
      Uri.parse('${vault.baseUrl}/api/v1/tasks/$taskId/patches/$patchId/approve'),
      headers: _headers(),
      body: jsonEncode({'note': note}),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    final err = jsonDecode(res.body);
    throw ApiException(res.statusCode, err['detail'] ?? 'Approve patch failed');
  }

  Future<Map<String, dynamic>> rejectPatch(String taskId, String patchId, {String? note}) async {
    if (vault.isDemoMode) return {'status': 'rejected'};
    final res = await _client.post(
      Uri.parse('${vault.baseUrl}/api/v1/tasks/$taskId/patches/$patchId/reject'),
      headers: _headers(),
      body: jsonEncode({'note': note}),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    final err = jsonDecode(res.body);
    throw ApiException(res.statusCode, err['detail'] ?? 'Reject patch failed');
  }

  Future<Map<String, dynamic>> rollbackPatch(String taskId, String patchId) async {
    if (vault.isDemoMode) return {'status': 'rolled_back'};
    final res = await _client.post(
      Uri.parse('${vault.baseUrl}/api/v1/tasks/$taskId/patches/$patchId/rollback'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    final err = jsonDecode(res.body);
    throw ApiException(res.statusCode, err['detail'] ?? 'Rollback patch failed');
  }

  // --- Local GGUF Models ---
  Future<List<LocalGGUFModel>> listLocalModels() async {
    if (vault.isDemoMode) return _demoGGUFModels;
    try {
      final res = await _client.get(
        Uri.parse('${vault.baseUrl}/api/v1/ai/local/catalogue'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        return list.map((e) => LocalGGUFModel.fromJson(e)).toList();
      }
    } catch (_) {}
    return _demoGGUFModels;
  }

  Future<Map<String, dynamic>> validateGGUF(String filePath, {String? expectedSha256}) async {
    if (vault.isDemoMode) {
      return {'valid': true, 'sha256': expectedSha256 ?? 'verified-sha256-hash', 'file_path': filePath};
    }
    final res = await _client.post(
      Uri.parse('${vault.baseUrl}/api/v1/ai/local/validate'),
      headers: _headers(),
      body: jsonEncode({'file_path': filePath, 'expected_sha256': expectedSha256}),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    final err = jsonDecode(res.body);
    throw ApiException(res.statusCode, err['detail'] ?? 'GGUF validation failed');
  }
}
), '')}/chat/completions');

    try {
      final response = await _client.post(
        endpoint,
        headers: <String, String>{
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          if (baseUri.host == 'openrouter.ai') ...{
            'HTTP-Referer': 'https://github.com/CodeByArnob/devforge-ai',
            'X-Title': 'DevForge AI',
          },
        },
        body: jsonEncode({
          'model': model,
          'messages': messages,
          'stream': false,
        }),
      ).timeout(const Duration(seconds: 90));

      final decoded = jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = decoded is Map
            ? (decoded['error'] is Map
                ? decoded['error']['message']?.toString()
                : decoded['message']?.toString())
            : null;
        throw ApiException(response.statusCode, detail ?? 'Provider request failed.');
      }
      if (decoded is! Map || decoded['choices'] is! List || (decoded['choices'] as List).isEmpty) {
        throw ApiException(502, 'Provider returned an unexpected chat-completion response.');
      }
      final choice = (decoded['choices'] as List).first;
      final message = choice is Map ? choice['message'] : null;
      final content = message is Map ? message['content'] : null;
      if (content is String && content.trim().isNotEmpty) return content.trim();
      if (content is List) {
        final text = content
            .whereType<Map>()
            .where((part) => part['type'] == 'text')
            .map((part) => part['text']?.toString() ?? '')
            .join();
        if (text.trim().isNotEmpty) return text.trim();
      }
      throw ApiException(502, 'Provider returned an empty assistant response.');
    } on TimeoutException {
      throw ApiException(408, 'Provider request timed out. Please try again.');
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(503, 'Unable to reach the configured AI provider: $error');
    }
  }

  // --- Auth ---
  Future<UserModel> login(String email, String password) async {
    if (vault.isDemoMode) {
      vault.enterDemoMode();
      return _demoUser;
    }
    try {
      final res = await _client.post(
        Uri.parse('${vault.baseUrl}/api/v1/auth/login'),
        headers: _headers(requiresAuth: false),
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        vault.isDemoMode = false;
        vault.accessToken = data['access_token'];
        vault.refreshToken = data['refresh_token'];
        return UserModel.fromJson(data['user']);
      }
      final err = jsonDecode(res.body);
      throw ApiException(res.statusCode, err['detail'] ?? 'Login failed');
    } on TimeoutException {
      throw ApiException(
        408,
        'Connection timed out reaching ${vault.baseUrl}.\n'
        '• On a physical mobile phone, do NOT use 10.0.2.2 (that is for emulator only).\n'
        '• Enter your computer Wi-Fi IP or tap "Explore in Offline Demo Mode" below.',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        503,
        'Cannot connect to server at ${vault.baseUrl}.\n'
        '• Please ensure backend is running or tap "Explore in Offline Demo Mode" below.',
      );
    }
  }

  Future<UserModel> register(String email, String password) async {
    if (vault.isDemoMode) {
      vault.enterDemoMode();
      return _demoUser;
    }
    try {
      final res = await _client.post(
        Uri.parse('${vault.baseUrl}/api/v1/auth/register'),
        headers: _headers(requiresAuth: false),
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 6));
      if (res.statusCode == 201) {
        final data = jsonDecode(res.body);
        vault.isDemoMode = false;
        vault.accessToken = data['access_token'];
        vault.refreshToken = data['refresh_token'];
        return UserModel.fromJson(data['user']);
      }
      final err = jsonDecode(res.body);
      throw ApiException(res.statusCode, err['detail'] ?? 'Registration failed');
    } on TimeoutException {
      throw ApiException(
        408,
        'Connection timed out reaching ${vault.baseUrl}.\n'
        '• Please enter your computer Wi-Fi IP or tap "Explore in Offline Demo Mode" below.',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        503,
        'Cannot connect to server at ${vault.baseUrl}.\n'
        '• Please ensure backend is running or tap "Explore in Offline Demo Mode" below.',
      );
    }
  }

  Future<void> logout() async {
    if (vault.isDemoMode) {
      vault.clearAll();
      return;
    }
    try {
      await _client.post(
        Uri.parse('${vault.baseUrl}/api/v1/auth/logout'),
        headers: _headers(),
      );
    } finally {
      vault.clearSession();
    }
  }

  Future<String?> requestPasswordRecovery(String email) async {
    if (vault.isDemoMode) {
      return 'demo-recovery-token-xyz789';
    }
    try {
      final res = await _client.post(
        Uri.parse('${vault.baseUrl}/api/v1/auth/recover/request'),
        headers: _headers(requiresAuth: false),
        body: jsonEncode({'email': email}),
      ).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['recovery_token'] as String?;
      }
      final err = jsonDecode(res.body);
      throw ApiException(res.statusCode, err['detail'] ?? 'Recovery request failed');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(503, 'Failed to connect to recovery service: $e');
    }
  }

  Future<void> resetPassword(String token, String newPassword) async {
    if (vault.isDemoMode) return;
    final res = await _client.post(
      Uri.parse('${vault.baseUrl}/api/v1/auth/recover/reset'),
      headers: _headers(requiresAuth: false),
      body: jsonEncode({'token': token, 'new_password': newPassword}),
    );
    if (res.statusCode != 200) {
      final err = jsonDecode(res.body);
      throw ApiException(res.statusCode, err['detail'] ?? 'Password reset failed');
    }
  }

  Future<UserModel> getMe() async {
    if (vault.isDemoMode) return _demoUser;
    final res = await _client.get(
      Uri.parse('${vault.baseUrl}/api/v1/auth/me'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      return UserModel.fromJson(jsonDecode(res.body));
    }
    throw ApiException(res.statusCode, 'Failed to fetch user profile');
  }

  // --- Projects ---
  Future<List<ProjectModel>> listProjects({int limit = 20}) async {
    if (vault.isDemoMode) return _demoProjects;
    try {
      final res = await _client.get(
        Uri.parse('${vault.baseUrl}/api/v1/projects?limit=$limit'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        return list.map((e) => ProjectModel.fromJson(e)).toList();
      }
    } catch (_) {}
    return _demoProjects;
  }

  Future<ProjectModel> getProject(String projectId) async {
    if (vault.isDemoMode) {
      return _demoProjects.firstWhere((p) => p.id == projectId, orElse: () => _demoProjects.first);
    }
    try {
      final res = await _client.get(
        Uri.parse('${vault.baseUrl}/api/v1/projects/$projectId'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return ProjectModel.fromJson(jsonDecode(res.body));
      }
    } catch (_) {}
    return _demoProjects.first;
  }

  Future<Map<String, dynamic>> importGitHub(String owner, String repo, {String? ref}) async {
    if (vault.isDemoMode) {
      return {'id': 'proj-demo-imported', 'name': repo, 'status': 'ready'};
    }
    final res = await _client.post(
      Uri.parse('${vault.baseUrl}/api/v1/projects/import/github'),
      headers: _headers(),
      body: jsonEncode({'owner': owner, 'repository': repo, 'ref': ref}),
    );
    if (res.statusCode == 201) {
      return jsonDecode(res.body);
    }
    final err = jsonDecode(res.body);
    throw ApiException(res.statusCode, err['detail'] ?? 'GitHub import failed');
  }

  Future<ProjectModel> claimProject(String projectId, String claimSecret, {String? reason}) async {
    final res = await _client.post(
      Uri.parse('${vault.baseUrl}/api/v1/projects/$projectId/claim'),
      headers: _headers(),
      body: jsonEncode({'claim_secret': claimSecret, 'reason': reason}),
    );
    if (res.statusCode == 200) {
      return ProjectModel.fromJson(jsonDecode(res.body));
    }
    final err = jsonDecode(res.body);
    throw ApiException(res.statusCode, err['detail'] ?? 'Claim project failed');
  }

  Future<Map<String, dynamic>> getProjectInventory(String projectId) async {
    if (vault.isDemoMode) {
      return {
        'total_files': 42,
        'entries': [
          {'path': 'backend/app/main.py', 'size_bytes': 1240},
          {'path': 'runner/runtime_policy.py', 'size_bytes': 2850},
          {'path': 'client/lib/main.dart', 'size_bytes': 1890},
        ]
      };
    }
    final res = await _client.get(
      Uri.parse('${vault.baseUrl}/api/v1/projects/$projectId/inventory'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw ApiException(res.statusCode, 'Failed to fetch inventory');
  }

  Future<Map<String, dynamic>> inspectFile(String projectId, String path) async {
    if (vault.isDemoMode) {
      return {'path': path, 'content': '# DevForge AI Source File\nprint("Hello DevForge AI")\n'};
    }
    final uri = Uri.parse('${vault.baseUrl}/api/v1/projects/$projectId/files/inspect').replace(
      queryParameters: {'path': path},
    );
    final res = await _client.get(uri, headers: _headers());
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw ApiException(res.statusCode, 'File inspection failed');
  }

  // --- Tasks & Agent ---
  Future<List<TaskModel>> listTasks({int limit = 20}) async {
    if (vault.isDemoMode) return _demoTasks;
    try {
      final res = await _client.get(
        Uri.parse('${vault.baseUrl}/api/v1/tasks?limit=$limit'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        return list.map((e) => TaskModel.fromJson(e)).toList();
      }
    } catch (_) {}
    return _demoTasks;
  }

  Future<TaskModel> getTask(String taskId) async {
    if (vault.isDemoMode) {
      return _demoTasks.firstWhere((t) => t.id == taskId, orElse: () => _demoTasks.first);
    }
    try {
      final res = await _client.get(
        Uri.parse('${vault.baseUrl}/api/v1/tasks/$taskId'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return TaskModel.fromJson(jsonDecode(res.body));
      }
    } catch (_) {}
    return _demoTasks.first;
  }

  Future<TaskModel> createTask(String projectId, String instruction, {String? model}) async {
    if (vault.isDemoMode) {
      final newTask = TaskModel(
        id: 'task-demo-${DateTime.now().millisecondsSinceEpoch}',
        projectId: projectId,
        instruction: instruction,
        status: 'awaiting_approval',
        approvalDecision: 'pending',
        selectedModel: model ?? 'openrouter/free',
        createdAt: DateTime.now(),
      );
      _demoTasks.insert(0, newTask);
      return newTask;
    }
    final res = await _client.post(
      Uri.parse('${vault.baseUrl}/api/v1/tasks'),
      headers: _headers(),
      body: jsonEncode({
        'project_id': projectId,
        'instruction': instruction,
        'selected_model': model,
      }),
    );
    if (res.statusCode == 201) {
      return TaskModel.fromJson(jsonDecode(res.body));
    }
    final err = jsonDecode(res.body);
    throw ApiException(res.statusCode, err['detail'] ?? 'Create task failed');
  }

  Future<TaskModel> cancelTask(String taskId) async {
    if (vault.isDemoMode) {
      return _demoTasks.first;
    }
    final res = await _client.post(
      Uri.parse('${vault.baseUrl}/api/v1/tasks/$taskId/cancel'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      return TaskModel.fromJson(jsonDecode(res.body));
    }
    throw ApiException(res.statusCode, 'Failed to cancel task');
  }

  Future<Map<String, dynamic>> runAgentTeam(String taskId, {String? model, List<String>? roles}) async {
    if (vault.isDemoMode) {
      return {'status': 'in_progress', 'task_id': taskId};
    }
    final res = await _client.post(
      Uri.parse('${vault.baseUrl}/api/v1/tasks/$taskId/agent/run'),
      headers: _headers(requiresOpenRouter: true),
      body: jsonEncode({'model': model, 'roles': roles}),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    final err = jsonDecode(res.body);
    throw ApiException(res.statusCode, err['detail'] ?? 'Agent run failed');
  }

  Future<Map<String, dynamic>> decideTaskApproval(String taskId, String decision, {String? note}) async {
    if (vault.isDemoMode) {
      return {'decision': decision, 'status': 'completed'};
    }
    final res = await _client.post(
      Uri.parse('${vault.baseUrl}/api/v1/tasks/$taskId/approval'),
      headers: _headers(),
      body: jsonEncode({'decision': decision, 'note': note}),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    final err = jsonDecode(res.body);
    throw ApiException(res.statusCode, err['detail'] ?? 'Approval decision failed');
  }

  Stream<TaskEventModel> streamTaskEvents(String taskId, {int after = 0}) async* {
    if (vault.isDemoMode) {
      final events = [
        TaskEventModel(
          sequence: 1,
          eventType: 'agent_started',
          message: 'Architect analyzing module boundaries, container isolation, and UID 65532 policy.',
          payload: {'agent_role': 'architect'},
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
        TaskEventModel(
          sequence: 2,
          eventType: 'agent_progress',
          message: 'Planner generated ordered milestone roadmap with verification checkpoints.',
          payload: {'agent_role': 'planner'},
          createdAt: DateTime.now().subtract(const Duration(minutes: 4)),
        ),
        TaskEventModel(
          sequence: 3,
          eventType: 'security_audited',
          message: 'Security Reviewer passed OWASP checks. Dropped Linux capabilities (cap-drop=ALL).',
          payload: {'agent_role': 'security_reviewer'},
          createdAt: DateTime.now().subtract(const Duration(minutes: 3)),
        ),
        TaskEventModel(
          sequence: 4,
          eventType: 'patch_proposed',
          message: 'Coder synthesized runtime_policy.py proposal with precondition sha256 checksums.',
          payload: {'agent_role': 'coder'},
          createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
        ),
        TaskEventModel(
          sequence: 5,
          eventType: 'qa_verified',
          message: 'QA Engineer executed complete test suite: 77/77 tests passed. Ready for review.',
          payload: {'agent_role': 'qa_engineer'},
          createdAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      ];
      for (final ev in events) {
        if (ev.sequence > after) yield ev;
      }
      return;
    }

    try {
      final request = http.Request(
        'GET',
        Uri.parse('${vault.baseUrl}/api/v1/tasks/$taskId/events?after=$after'),
      );
      request.headers.addAll(_headers());

      final response = await _client.send(request);
      if (response.statusCode != 200) {
        throw ApiException(response.statusCode, 'Failed to connect to event stream');
      }

      final lines = response.stream.transform(utf8.decoder).transform(const LineSplitter());
      String currentData = '';

      await for (final line in lines) {
        if (line.startsWith('data: ')) {
          currentData = line.substring(6);
        } else if (line.isEmpty && currentData.isNotEmpty) {
          try {
            final json = jsonDecode(currentData);
            yield TaskEventModel.fromJson(json);
          } catch (_) {}
          currentData = '';
        }
      }
    } catch (_) {}
  }

  // --- Patches ---
  Future<List<PatchProposalModel>> listPatches(String taskId) async {
    if (vault.isDemoMode) {
      return [
        PatchProposalModel(
          patchId: 'patch-demo-1',
          taskId: taskId,
          baseSnapshotDigest: 'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90',
          patchDigest: 'f9e8d7c6b5a43210f9e8d7c6b5a43210f9e8d7c6b5a43210f9e8d7c6b5a43210',
          unifiedDiff: '--- a/runner/runtime_policy.py\n+++ b/runner/runtime_policy.py\n@@ -0,0 +1,5 @@\n+class PodmanSandboxPolicy:\n+    user = "65532:65532"\n+    read_only_root = True\n+    network_mode = "none"\n',
          changes: [
            {'path': 'runner/runtime_policy.py', 'action': 'create'}
          ],
          status: 'pending',
          createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
        ),
      ];
    }
    try {
      final res = await _client.get(
        Uri.parse('${vault.baseUrl}/api/v1/tasks/$taskId/patches'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        return list.map((e) => PatchProposalModel.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<PatchProposalModel> getPatch(String taskId, String patchId) async {
    final list = await listPatches(taskId);
    if (list.isNotEmpty) return list.first;
    throw ApiException(404, 'Patch not found');
  }

  Future<Map<String, dynamic>> approvePatch(String taskId, String patchId, {String? note}) async {
    if (vault.isDemoMode) return {'status': 'applied'};
    final res = await _client.post(
      Uri.parse('${vault.baseUrl}/api/v1/tasks/$taskId/patches/$patchId/approve'),
      headers: _headers(),
      body: jsonEncode({'note': note}),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    final err = jsonDecode(res.body);
    throw ApiException(res.statusCode, err['detail'] ?? 'Approve patch failed');
  }

  Future<Map<String, dynamic>> rejectPatch(String taskId, String patchId, {String? note}) async {
    if (vault.isDemoMode) return {'status': 'rejected'};
    final res = await _client.post(
      Uri.parse('${vault.baseUrl}/api/v1/tasks/$taskId/patches/$patchId/reject'),
      headers: _headers(),
      body: jsonEncode({'note': note}),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    final err = jsonDecode(res.body);
    throw ApiException(res.statusCode, err['detail'] ?? 'Reject patch failed');
  }

  Future<Map<String, dynamic>> rollbackPatch(String taskId, String patchId) async {
    if (vault.isDemoMode) return {'status': 'rolled_back'};
    final res = await _client.post(
      Uri.parse('${vault.baseUrl}/api/v1/tasks/$taskId/patches/$patchId/rollback'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    final err = jsonDecode(res.body);
    throw ApiException(res.statusCode, err['detail'] ?? 'Rollback patch failed');
  }

  // --- Local GGUF Models ---
  Future<List<LocalGGUFModel>> listLocalModels() async {
    if (vault.isDemoMode) return _demoGGUFModels;
    try {
      final res = await _client.get(
        Uri.parse('${vault.baseUrl}/api/v1/ai/local/catalogue'),
        headers: _headers(),
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        return list.map((e) => LocalGGUFModel.fromJson(e)).toList();
      }
    } catch (_) {}
    return _demoGGUFModels;
  }

  Future<Map<String, dynamic>> validateGGUF(String filePath, {String? expectedSha256}) async {
    if (vault.isDemoMode) {
      return {'valid': true, 'sha256': expectedSha256 ?? 'verified-sha256-hash', 'file_path': filePath};
    }
    final res = await _client.post(
      Uri.parse('${vault.baseUrl}/api/v1/ai/local/validate'),
      headers: _headers(),
      body: jsonEncode({'file_path': filePath, 'expected_sha256': expectedSha256}),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    final err = jsonDecode(res.body);
    throw ApiException(res.statusCode, err['detail'] ?? 'GGUF validation failed');
  }
}

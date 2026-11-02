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
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  final SecureVault vault = SecureVault();
  final http.Client _client = http.Client();

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

  // --- Auth ---
  Future<UserModel> login(String email, String password) async {
    final res = await _client.post(
      Uri.parse('${vault.baseUrl}/api/v1/auth/login'),
      headers: _headers(requiresAuth: false),
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      vault.accessToken = data['access_token'];
      vault.refreshToken = data['refresh_token'];
      return UserModel.fromJson(data['user']);
    }
    final err = jsonDecode(res.body);
    throw ApiException(res.statusCode, err['detail'] ?? 'Login failed');
  }

  Future<UserModel> register(String email, String password) async {
    final res = await _client.post(
      Uri.parse('${vault.baseUrl}/api/v1/auth/register'),
      headers: _headers(requiresAuth: false),
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (res.statusCode == 201) {
      final data = jsonDecode(res.body);
      vault.accessToken = data['access_token'];
      vault.refreshToken = data['refresh_token'];
      return UserModel.fromJson(data['user']);
    }
    final err = jsonDecode(res.body);
    throw ApiException(res.statusCode, err['detail'] ?? 'Registration failed');
  }

  Future<void> logout() async {
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
    final res = await _client.post(
      Uri.parse('${vault.baseUrl}/api/v1/auth/recover/request'),
      headers: _headers(requiresAuth: false),
      body: jsonEncode({'email': email}),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['recovery_token'] as String?;
    }
    final err = jsonDecode(res.body);
    throw ApiException(res.statusCode, err['detail'] ?? 'Recovery request failed');
  }

  Future<void> resetPassword(String token, String newPassword) async {
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
    final res = await _client.get(
      Uri.parse('${vault.baseUrl}/api/v1/projects?limit=$limit'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List<dynamic>;
      return list.map((e) => ProjectModel.fromJson(e)).toList();
    }
    throw ApiException(res.statusCode, 'Failed to list projects');
  }

  Future<ProjectModel> getProject(String projectId) async {
    final res = await _client.get(
      Uri.parse('${vault.baseUrl}/api/v1/projects/$projectId'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      return ProjectModel.fromJson(jsonDecode(res.body));
    }
    throw ApiException(res.statusCode, 'Project not found');
  }

  Future<Map<String, dynamic>> importGitHub(String owner, String repo, {String? ref}) async {
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
    final res = await _client.get(
      Uri.parse('${vault.baseUrl}/api/v1/tasks?limit=$limit'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List<dynamic>;
      return list.map((e) => TaskModel.fromJson(e)).toList();
    }
    throw ApiException(res.statusCode, 'Failed to list tasks');
  }

  Future<TaskModel> getTask(String taskId) async {
    final res = await _client.get(
      Uri.parse('${vault.baseUrl}/api/v1/tasks/$taskId'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      return TaskModel.fromJson(jsonDecode(res.body));
    }
    throw ApiException(res.statusCode, 'Task not found');
  }

  Future<TaskModel> createTask(String projectId, String instruction, {String? model}) async {
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
  }

  // --- Patches ---
  Future<List<PatchProposalModel>> listPatches(String taskId) async {
    final res = await _client.get(
      Uri.parse('${vault.baseUrl}/api/v1/tasks/$taskId/patches'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List<dynamic>;
      return list.map((e) => PatchProposalModel.fromJson(e)).toList();
    }
    throw ApiException(res.statusCode, 'Failed to list patches');
  }

  Future<PatchProposalModel> getPatch(String taskId, String patchId) async {
    final res = await _client.get(
      Uri.parse('${vault.baseUrl}/api/v1/tasks/$taskId/patches/$patchId'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      return PatchProposalModel.fromJson(jsonDecode(res.body));
    }
    throw ApiException(res.statusCode, 'Failed to get patch details');
  }

  Future<Map<String, dynamic>> approvePatch(String taskId, String patchId, {String? note}) async {
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
    final res = await _client.get(
      Uri.parse('${vault.baseUrl}/api/v1/ai/local/catalogue'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List<dynamic>;
      return list.map((e) => LocalGGUFModel.fromJson(e)).toList();
    }
    throw ApiException(res.statusCode, 'Failed to load local GGUF catalogue');
  }

  Future<Map<String, dynamic>> validateGGUF(String filePath, {String? expectedSha256}) async {
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

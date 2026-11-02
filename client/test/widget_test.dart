import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:client/core/models/models.dart';
import 'package:client/core/services/secure_vault.dart';
import 'package:client/main.dart';
import 'package:client/ui/screens/login_screen.dart';

void main() {
  test('SecureVault stores credentials safely and emits updates', () async {
    final vault = SecureVault();
    vault.clearAll();

    expect(vault.isAuthenticated, isFalse);
    expect(vault.hasOpenRouterKey, isFalse);

    vault.accessToken = 'jwt-access-token-123';
    vault.refreshToken = 'jwt-refresh-token-456';
    vault.openRouterApiKey = 'sk-or-v1-testkey';

    expect(vault.isAuthenticated, isTrue);
    expect(vault.hasOpenRouterKey, isTrue);
    expect(vault.accessToken, equals('jwt-access-token-123'));
    expect(vault.openRouterApiKey, equals('sk-or-v1-testkey'));

    vault.clearSession();
    expect(vault.isAuthenticated, isFalse);
    expect(vault.hasOpenRouterKey, isTrue); // API key remains in vault
  });

  test('Models deserialize correctly from API JSON payloads', () {
    final projectJson = {
      'id': 'proj-1',
      'name': 'DevForge Core',
      'source_type': 'github',
      'file_count': 42,
      'languages': [{'display_name': 'Flutter / Dart'}],
      'created_at': '2026-11-02T12:00:00Z',
    };
    final proj = ProjectModel.fromJson(projectJson);
    expect(proj.id, equals('proj-1'));
    expect(proj.fileCount, equals(42));
    expect(proj.sourceType, equals('github'));

    final taskJson = {
      'id': 'task-100',
      'project_id': 'proj-1',
      'instruction': 'Build flutter app',
      'status': 'planning',
      'approval_decision': 'approved',
      'created_at': '2026-11-02T12:05:00Z',
    };
    final task = TaskModel.fromJson(taskJson);
    expect(task.id, equals('task-100'));
    expect(task.approvalDecision, equals('approved'));

    final ggufJson = {
      'id': 'llama-3.2-3b-instruct-q4km',
      'name': 'Llama 3.2 3B Instruct',
      'family': 'llama',
      'parameters': '3B',
      'quantization': 'Q4_K_M',
      'license': 'Llama-3.2-Community',
      'sha256': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      'context_length': 131072,
      'file_size_gb': 2.02,
      'min_ram_gb': 3.5,
      'recommended_vram_gb': 4.0,
      'supported_abis': ['avx2', 'cuda'],
      'download_url': 'https://example.com',
    };
    final gguf = LocalGGUFModel.fromJson(ggufJson);
    expect(gguf.id, equals('llama-3.2-3b-instruct-q4km'));
    expect(gguf.minRamGb, equals(3.5));
  });

  testWidgets('App renders DevForge AI login screen on startup', (WidgetTester tester) async {
    final vault = SecureVault();
    vault.clearAll();

    await tester.pumpWidget(const DevForgeApp());
    await tester.pumpAndSettle();

    expect(find.text('DevForge AI'), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2)); // Email & Password
  });
}

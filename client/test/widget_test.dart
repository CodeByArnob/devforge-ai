import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:client/core/models/models.dart';
import 'package:client/core/services/secure_vault.dart';
import 'package:client/main.dart';
import 'package:client/ui/screens/ai_studio_screen.dart';
import 'package:client/ui/screens/home_screen.dart';
import 'package:client/ui/screens/login_screen.dart';
import 'package:client/ui/screens/projects_screen.dart';

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

  testWidgets('HomeScreen renders 5-tab developer navigation bar', (WidgetTester tester) async {
    final vault = SecureVault();
    vault.enterDemoMode();

    await tester.pumpWidget(MaterialApp(
      home: HomeScreen(onLogout: () {}),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Build something\nremarkable.'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Projects'), findsWidgets);
    expect(find.text('AI Studio'), findsWidgets);
    expect(find.text('Editor'), findsOneWidget);
    expect(find.text('Builds'), findsOneWidget);
  });

  testWidgets('AIStudioScreen renders conversational chat interface and provider settings modal', (WidgetTester tester) async {
    final vault = SecureVault();
    vault.enterDemoMode();

    await tester.pumpWidget(const MaterialApp(
      home: AIStudioScreen(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('AI Studio'), findsOneWidget);
    expect(find.text('What should we build?'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();

    expect(find.text('AI & Engine Settings'), findsOneWidget);
    expect(find.text('Apply Provider Settings'), findsOneWidget);
    expect(find.text('Provider API Base URL'), findsOneWidget);
    expect(find.text('DevForge Backend URL (optional)'), findsOneWidget);
  });

  testWidgets('ProjectsScreen allows custom GitHub account connection and repository permission management', (WidgetTester tester) async {
    final vault = SecureVault();
    vault.clearAll();

    await tester.pumpWidget(const MaterialApp(
      home: ProjectsScreen(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Projects'), findsOneWidget);
    expect(find.text('Connect GitHub Account'), findsOneWidget);

    // Tap connect GitHub account
    await tester.tap(find.text('Connect GitHub Account'));
    await tester.pumpAndSettle();

    expect(find.text('GitHub Username / Organization'), findsOneWidget);
    expect(find.text('Personal Access Token (PAT)'), findsOneWidget);
    expect(find.text('Connect Account'), findsOneWidget);
  });
}

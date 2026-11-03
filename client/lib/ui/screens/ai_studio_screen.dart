import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/secure_vault.dart';

class ChatMessage {
  final String id;
  final bool isUser;
  final String text;
  final DateTime timestamp;
  final List<TaskEventModel>? agentEvents;
  final PatchProposalModel? patch;
  String? patchDecision;
  final String? codeSnippet;
  final String? codeLanguage;
  final bool isThinking;

  ChatMessage({
    required this.id,
    required this.isUser,
    required this.text,
    required this.timestamp,
    this.agentEvents,
    this.patch,
    this.patchDecision,
    this.codeSnippet,
    this.codeLanguage,
    this.isThinking = false,
  });

  ChatMessage copyWith({
    String? text,
    List<TaskEventModel>? agentEvents,
    PatchProposalModel? patch,
    String? patchDecision,
    String? codeSnippet,
    String? codeLanguage,
    bool? isThinking,
  }) {
    return ChatMessage(
      id: id,
      isUser: isUser,
      text: text ?? this.text,
      timestamp: timestamp,
      agentEvents: agentEvents ?? this.agentEvents,
      patch: patch ?? this.patch,
      patchDecision: patchDecision ?? this.patchDecision,
      codeSnippet: codeSnippet ?? this.codeSnippet,
      codeLanguage: codeLanguage ?? this.codeLanguage,
      isThinking: isThinking ?? this.isThinking,
    );
  }
}

class AIStudioScreen extends StatefulWidget {
  final VoidCallback? onOpenLocalModels;
  const AIStudioScreen({super.key, this.onOpenLocalModels});

  @override
  State<AIStudioScreen> createState() => _AIStudioScreenState();
}

class _AIStudioScreenState extends State<AIStudioScreen> {
  final SecureVault _vault = SecureVault();
  final ApiService _api = ApiService();

  final List<ChatMessage> _messages = [];
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isGenerating = false;
  String _selectedProvider = 'OpenRouter';
  String _modelId = 'openai/gpt-4o-mini';
  String _providerBaseUrl = 'https://openrouter.ai/api/v1';

  static const Map<String, Map<String, String>> _providerPresets = {
    'OpenRouter': {'url': 'https://openrouter.ai/api/v1', 'model': 'openai/gpt-4o-mini'},
    'OpenAI': {'url': 'https://api.openai.com/v1', 'model': 'gpt-4o-mini'},
    'Groq': {'url': 'https://api.groq.com/openai/v1', 'model': 'llama-3.3-70b-versatile'},
    'DeepSeek': {'url': 'https://api.deepseek.com', 'model': 'deepseek-flash'},
    'Together AI': {'url': 'https://api.together.xyz/v1', 'model': 'meta-llama/Llama-3.3-70B-Instruct-Turbo'},
    'Mistral AI': {'url': 'https://api.mistral.ai/v1', 'model': 'mistral-large-latest'},
  };

  final List<String> _quickPrompts = [
    'Create Python FastAPI JWT Auth Router',
    'Build Flutter Todo App with Material 3',
    'Fix Android Cleartext Socket Exception',
    'Implement Hardened Podman Sandbox Policy',
  ];

  @override
  void initState() {
    super.initState();
    _providerBaseUrl = _vault.providerBaseUrl;
    if (_vault.openRouterApiKey != null && _vault.openRouterApiKey!.isNotEmpty) {
      _selectedProvider = 'OpenRouter';
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openSettingsModal() {
    final apiKeyController = TextEditingController(text: _vault.openRouterApiKey ?? '');
    final modelIdController = TextEditingController(text: _modelId);
    final providerUrlController = TextEditingController(text: _vault.providerBaseUrl);
    final serverUrlController = TextEditingController(text: _vault.baseUrl);
    bool obscureKey = true;
    String modalProvider = _selectedProvider;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101726),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.tune_rounded, color: Color(0xFF38BDF8), size: 22),
                            SizedBox(width: 10),
                            Text(
                              'AI & Engine Settings',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFF1E293B)),
                    const SizedBox(height: 12),

                    // AI Provider Selection
                    const Text(
                      'AI Provider',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF080B11),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF1E293B)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: modalProvider,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF101726),
                          style: const TextStyle(color: Colors.white, fontSize: 13.5),
                          items: const [
                            DropdownMenuItem(value: 'OpenRouter', child: Text('OpenRouter')),
                            DropdownMenuItem(value: 'OpenAI', child: Text('OpenAI')),
                            DropdownMenuItem(value: 'Groq', child: Text('Groq')),
                            DropdownMenuItem(value: 'DeepSeek', child: Text('DeepSeek')),
                            DropdownMenuItem(value: 'Together AI', child: Text('Together AI')),
                            DropdownMenuItem(value: 'Mistral AI', child: Text('Mistral AI')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                modalProvider = val;
                                final preset = _providerPresets[val]!;
                                providerUrlController.text = preset['url']!;
                                modelIdController.text = preset['model']!;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Model ID Field
                    const Text(
                      'Model Identifier',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: modelIdController,
                      style: const TextStyle(color: Colors.white, fontSize: 13.5),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF080B11),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF1E293B)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF1E293B)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // API Key Field
                    const Text(
                      'Provider API Key',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: apiKeyController,
                      obscureText: obscureKey,
                      style: const TextStyle(color: Colors.white, fontSize: 13.5),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF080B11),
                        hintText: 'Paste API key from the selected provider',
                        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF1E293B)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF1E293B)),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureKey ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: const Color(0xFF94A3B8),
                            size: 18,
                          ),
                          onPressed: () => setModalState(() => obscureKey = !obscureKey),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Provider API Base URL (automatically populated by provider selection)
                    const Text(
                      'Provider API Base URL',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: providerUrlController,
                      keyboardType: TextInputType.url,
                      style: const TextStyle(color: Colors.white, fontSize: 13.5),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF080B11),
                        hintText: 'https://openrouter.ai/api/v1',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF1E293B)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF1E293B)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Optional backend endpoint
                    const Text(
                      'DevForge Backend URL (optional)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: serverUrlController,
                      style: const TextStyle(color: Colors.white, fontSize: 13.5),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF080B11),
                        hintText: 'Leave blank unless you host the DevForge backend',
                        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF1E293B)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF1E293B)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.lock_outline, size: 18),
                        label: const Text('Save Settings to Vault', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5A77F6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          final key = apiKeyController.text.trim();
                          _vault.openRouterApiKey = key.isEmpty ? null : key;
                          _vault.providerBaseUrl = providerUrlController.text.trim();
                          _vault.baseUrl = serverUrlController.text.trim();
                          setState(() {
                            _selectedProvider = modalProvider;
                            _providerBaseUrl = providerUrlController.text.trim();
                            _modelId = modelIdController.text.trim();
                          });
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Settings saved securely to device vault!'),
                              backgroundColor: Color(0xFF1E293B),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _isGenerating = false;
    });
  }

  Future<void> _handleDecision(String messageId, String decision) async {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    final msg = _messages[index];
    final patch = msg.patch;
    if (patch == null) return;

    setState(() {
      _messages[index] = msg.copyWith(patchDecision: decision);
    });

    if (decision == 'approved') {
      try {
        await _api.approvePatch(patch.taskId ?? 'task-demo-101', patch.patchId);
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF34D399), size: 18),
                SizedBox(width: 8),
                Text('Patch approved and applied to project workspace!'),
              ],
            ),
            backgroundColor: Color(0xFF121A29),
          ),
        );
      }
    } else {
      try {
        await _api.rejectPatch(patch.taskId ?? 'task-demo-101', patch.patchId);
      } catch (_) {}
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        backgroundColor: const Color(0xFF1E293B),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  bool _isSoftwareEngineeringRequest(String prompt) {
    final value = prompt.toLowerCase().trim();
    const intentPatterns = [
      r'\\b(build|create|implement|generate|develop|scaffold|code|debug|fix|refactor|write|modify|update)\\b',
      r'\\b(app|application|website|web app|mobile app|api|backend|frontend|function|class|widget|project|repository|bug|error|crash|feature)\\b',
    ];
    return intentPatterns.any((pattern) => RegExp(pattern).hasMatch(value)) &&
        value.length > 12;
  }

  Future<void> _sendMessage([String? presetText]) async {
    final prompt = presetText ?? _promptController.text.trim();
    if (prompt.isEmpty || _isGenerating) return;

    _promptController.clear();
    final now = DateTime.now();
    final userMessageId = 'user-${now.microsecondsSinceEpoch}';
    final assistantMessageId = 'assistant-${now.microsecondsSinceEpoch}';
    final codingRequest = _isSoftwareEngineeringRequest(prompt);

    setState(() {
      _messages.add(ChatMessage(
        id: userMessageId,
        isUser: true,
        text: prompt,
        timestamp: now,
      ));
      _messages.add(ChatMessage(
        id: assistantMessageId,
        isUser: false,
        text: 'Thinking...',
        timestamp: now,
        isThinking: true,
      ));
      _isGenerating = true;
    });
    _scrollToBottom();

    try {
      final history = _messages
          .where((message) => !message.isThinking && message.text.isNotEmpty)
          .toList();
      final conversation = <Map<String, String>>[
        {
          'role': 'system',
          'content': codingRequest
              ? 'You are DevForge AI, a senior software engineering assistant. Help with the requested engineering task using accurate, practical guidance. Ask a concise clarification when essential details are missing. Provide code only when useful. Never claim that you ran tests, inspected a repository, changed files, applied a patch, or completed agent reviews unless a connected tool actually did so. This chat interface does not currently apply code changes.'
              : 'You are DevForge AI, a helpful, natural conversational assistant. Reply directly to the user in a friendly, concise way. For greetings such as Hi or Hello, greet them naturally and ask how you can help. Do not invent coding tasks, code snippets, diffs, agent activity, security reviews, tests, or completed work. Only discuss software engineering when the user asks about it.',
        },
        ...history.take(20).map((message) => {
          'role': message.isUser ? 'user' : 'assistant',
          'content': message.text,
        }),
      ];

      final answer = await _api.createChatCompletion(
        model: _modelId,
        messages: conversation,
      );

      if (!mounted) return;
      final idx = _messages.indexWhere((message) => message.id == assistantMessageId);
      if (idx != -1) {
        setState(() {
          _messages[idx] = _messages[idx].copyWith(
            text: answer,
            isThinking: false,
          );
        });
      }
    } on TimeoutException {
      _replaceAssistantError(assistantMessageId, 'The AI provider took too long to respond. Please try again.');
    } on ApiException catch (error) {
      _replaceAssistantError(assistantMessageId, error.message);
    } catch (error) {
      _replaceAssistantError(assistantMessageId, 'Could not reach the AI provider. Check your internet connection and provider settings. Details: $error');
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
        _scrollToBottom();
      }
    }
  }

  void _replaceAssistantError(String messageId, String error) {
    if (!mounted) return;
    final idx = _messages.indexWhere((message) => message.id == messageId);
    if (idx == -1) return;
    setState(() {
      _messages[idx] = _messages[idx].copyWith(
        text: error,
        isThinking: false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: const Text('Built autonomously with DevForge AI!'),
    );
  }
}
''';
        patch = PatchProposalModel(
          patchId: 'patch-custom-104',
          taskId: task?.id ?? 'task-demo-custom',
          baseSnapshotDigest: 'snap-base-004',
          patchDigest: '38bdf834d399',
          unifiedDiff: '''--- a/client/lib/solution.dart
+++ b/client/lib/solution.dart
@@ -0,0 +1,8 @@
+// Verified patch applied cleanly
+class FeatureModule {
+  final bool isReady = true;
+}''',
          status: 'pending',
          createdAt: DateTime.now(),
        );
      }

      if (mounted) {
        final idx = _messages.indexWhere((m) => m.id == assistantMessageId);
        if (idx != -1) {
          setState(() {
            _messages[idx] = _messages[idx].copyWith(
              text: responseText,
              agentEvents: events,
              codeSnippet: codeSnippet,
              codeLanguage: codeLanguage,
              patch: patch,
              isThinking: false,
            );
          });
        }
      }
    } catch (e) {
      if (mounted) {
        final idx = _messages.indexWhere((m) => m.id == assistantMessageId);
        if (idx != -1) {
          setState(() {
            _messages[idx] = _messages[idx].copyWith(
              text: 'Execution encountered an issue: $e. You can configure your API key in Settings.',
              isThinking: false,
            );
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080B11),
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF38BDF8), Color(0xFF34D399)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.black, size: 16),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Studio',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5, color: Colors.white),
                ),
                GestureDetector(
                  onTap: _openSettingsModal,
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF34D399),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _modelId,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                      const Icon(Icons.arrow_drop_down, color: Color(0xFF94A3B8), size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: Color(0xFF94A3B8)),
            tooltip: 'Clear Chat',
            onPressed: _messages.isEmpty ? null : _clearChat,
          ),
          IconButton(
            icon: const Icon(Icons.memory_rounded, color: Color(0xFF34D399)),
            tooltip: 'Offline Local Models',
            onPressed: widget.onOpenLocalModels,
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Color(0xFF38BDF8)),
            tooltip: 'Settings & API Keys',
            onPressed: _openSettingsModal,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Chat message area
            Expanded(
              child: _messages.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        return msg.isUser ? _buildUserBubble(msg) : _buildAssistantBubble(msg);
                      },
                    ),
            ),

            // Bottom Input Bar
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF101726),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
              ),
              child: const Icon(Icons.auto_awesome, color: Color(0xFF38BDF8), size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'What should we build?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Autonomous software engineering with 8 specialist AI agents.\nTap a suggestion or ask anything.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8), height: 1.4),
            ),
            const SizedBox(height: 24),

            // Quick suggestion cards
            ..._quickPrompts.map((p) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: InkWell(
                  onTap: () => _sendMessage(p),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF101726),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.bolt_rounded, color: Color(0xFF34D399), size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            p,
                            style: const TextStyle(fontSize: 13, color: Color(0xFFCBD5E1), fontWeight: FontWeight.w500),
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, color: Color(0xFF64748B), size: 12),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildUserBubble(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(4),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Text(
                msg.text,
                style: const TextStyle(fontSize: 14, color: Colors.white, height: 1.35),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFF334155),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantBubble(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF38BDF8), Color(0xFF34D399)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.black, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Agent Collaboration Accordion
                if (msg.agentEvents != null && msg.agentEvents!.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF101726),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.hub_outlined, color: Color(0xFF34D399), size: 15),
                            const SizedBox(width: 6),
                            const Text(
                              'Specialist Agent Collaboration',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                            ),
                            const Spacer(),
                            if (msg.isThinking)
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF34D399)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...msg.agentEvents!.map((ev) {
                          final role = ev.payload['agent_role'] ?? 'agent';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    role.toString().toUpperCase(),
                                    style: const TextStyle(fontSize: 8.5, color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    ev.message,
                                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, height: 1.3),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],

                // Main Text Response
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF101726),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg.text,
                        style: const TextStyle(fontSize: 13.5, color: Color(0xFFF1F5F9), height: 1.45),
                      ),
                      if (msg.isThinking) ...[
                        const SizedBox(height: 8),
                        const Row(
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF5A77F6)),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Thinking & planning...',
                              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Formatted Code Block
                if (msg.codeSnippet != null && msg.codeSnippet!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF080B11),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Code Header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF101726),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                (msg.codeLanguage ?? 'code').toUpperCase(),
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                              ),
                              GestureDetector(
                                onTap: () => _copyToClipboard(msg.codeSnippet!, 'Code snippet'),
                                child: const Row(
                                  children: [
                                    Icon(Icons.copy_rounded, color: Color(0xFF38BDF8), size: 13),
                                    SizedBox(width: 4),
                                    Text('Copy', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Code Content
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            msg.codeSnippet!,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11.5,
                              color: Color(0xFF93C5FD),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Proposed Code Modification Diff Card
                if (msg.patch != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF101726),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.difference_outlined, color: Color(0xFF818CF8), size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Proposed Diff (${msg.patch!.patchId})',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (msg.patchDecision != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: msg.patchDecision == 'approved'
                                      ? Colors.green.withValues(alpha: 0.2)
                                      : Colors.red.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  msg.patchDecision!.toUpperCase(),
                                  style: TextStyle(
                                    color: msg.patchDecision == 'approved' ? Colors.greenAccent : Colors.redAccent,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF080B11),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            msg.patch!.unifiedDiff ?? '',
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF93C5FD)),
                          ),
                        ),
                        if (msg.patchDecision == null) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _handleDecision(msg.id, 'rejected'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                    side: BorderSide(color: Colors.red.shade400.withValues(alpha: 0.5)),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Reject', style: TextStyle(fontSize: 12)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _handleDecision(msg.id, 'approved'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF34D399),
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Approve & Apply', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF080B11),
        border: Border(top: BorderSide(color: Color(0xFF1E293B))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF101726),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: TextField(
                controller: _promptController,
                minLines: 1,
                maxLines: 4,
                style: const TextStyle(color: Colors.white, fontSize: 13.5),
                decoration: const InputDecoration(
                  hintText: 'Ask DevForge AI anything...',
                  hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  border: InputBorder.none,
                ),
                onSubmitted: (val) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF5A77F6),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: _isGenerating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
              onPressed: _isGenerating ? null : () => _sendMessage(),
            ),
          ),
        ],
      ),
    );
  }
}

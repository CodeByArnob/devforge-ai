import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/secure_vault.dart';

class AIStudioScreen extends StatefulWidget {
  final VoidCallback? onOpenLocalModels;
  const AIStudioScreen({super.key, this.onOpenLocalModels});

  @override
  State<AIStudioScreen> createState() => _AIStudioScreenState();
}

class _AIStudioScreenState extends State<AIStudioScreen> {
  final SecureVault _vault = SecureVault();
  final ApiService _api = ApiService();

  String _selectedProvider = 'OpenRouter';
  final List<String> _providers = [
    'OpenRouter',
    'Qwen 2.5 Coder 7B (Offline Local)',
    'Anthropic Claude 3.5',
    'OpenAI GPT-4o Mini',
  ];

  final _modelIdController = TextEditingController(text: 'openai/gpt-4o-mini');
  final _apiKeyController = TextEditingController();
  final _promptController = TextEditingController();

  bool _obscureKey = true;
  bool _isProcessing = false;
  List<TaskEventModel> _events = [];
  PatchProposalModel? _proposedPatch;
  String? _patchDecision;

  final List<String> _quickPrompts = [
    'Build Flutter Todo App with Material 3',
    'Fix Android Cleartext Socket Exception',
    'Implement Hardened Podman Sandbox Policy',
    'Create Python FastAPI JWT Auth Router',
  ];

  @override
  void initState() {
    super.initState();
    _apiKeyController.text = _vault.openRouterApiKey ?? '';
  }

  @override
  void dispose() {
    _modelIdController.dispose();
    _apiKeyController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  void _saveApiKey() {
    final key = _apiKeyController.text.trim();
    _vault.openRouterApiKey = key.isEmpty ? null : key;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('API key saved securely to device vault!'),
        backgroundColor: Color(0xFF1E293B),
      ),
    );
  }

  Future<void> _sendToAI() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe what you want to build')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _events = [];
      _proposedPatch = null;
      _patchDecision = null;
    });

    try {
      final task = await _api.createTask('proj-demo-1', prompt, model: _modelIdController.text.trim());
      await _api.runAgentTeam(task.id, model: _modelIdController.text.trim());

      await for (final event in _api.streamTaskEvents(task.id)) {
        if (!mounted) break;
        setState(() => _events.add(event));
        await Future.delayed(const Duration(milliseconds: 250));
      }

      final patches = await _api.listPatches(task.id);
      if (mounted && patches.isNotEmpty) {
        setState(() => _proposedPatch = patches.first);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Agent execution: $e'), backgroundColor: Colors.red.shade900),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleDecision(String decision) async {
    if (_proposedPatch == null) return;
    setState(() => _patchDecision = decision);
    if (decision == 'approved') {
      await _api.approvePatch(_proposedPatch!.taskId ?? 'task-demo-101', _proposedPatch!.patchId);
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
      await _api.rejectPatch(_proposedPatch!.taskId ?? 'task-demo-101', _proposedPatch!.patchId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0E14),
        elevation: 0,
        title: const Text(
          'AI Studio',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.memory_rounded, color: Color(0xFF34D399)),
            tooltip: 'Offline Local Models',
            onPressed: widget.onOpenLocalModels,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
        children: [
          // Development Agent Hero Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF132238), Color(0xFF0D3238)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E3A4B)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DEVELOPMENT AGENT',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Color(0xFF38BDF8),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Think. Build. Improve.',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Use your cloud model or run Qwen locally on this device.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // AI Model Field
          const Text('AI model', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF121A29),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedProvider,
                isExpanded: true,
                dropdownColor: const Color(0xFF121A29),
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF94A3B8)),
                items: _providers.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedProvider = val;
                      if (val.contains('Qwen')) {
                        _modelIdController.text = 'qwen-2.5-coder-7b-instruct-q5km';
                      } else if (val.contains('Claude')) {
                        _modelIdController.text = 'anthropic/claude-3.5-sonnet';
                      } else if (val.contains('GPT')) {
                        _modelIdController.text = 'openai/gpt-4o-mini';
                      } else {
                        _modelIdController.text = 'openai/gpt-4o-mini';
                      }
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Model ID Field
          const Text('Model ID', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 8),
          TextField(
            controller: _modelIdController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF121A29),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1E293B)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1E293B)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),

          // API Key Field
          const Text('API key', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 8),
          TextField(
            controller: _apiKeyController,
            obscureText: _obscureKey,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF121A29),
              hintText: 'sk-or-v1-... (optional for local/demo)',
              hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1E293B)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1E293B)),
              ),
              suffixIcon: IconButton(
                icon: Icon(_obscureKey ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: const Color(0xFF94A3B8)),
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _saveApiKey,
              icon: const Icon(Icons.lock_outline, size: 14, color: Color(0xFF818CF8)),
              label: const Text('Save securely', style: TextStyle(color: Color(0xFF818CF8), fontSize: 12)),
            ),
          ),
          const SizedBox(height: 12),

          // Quick prompt chips
          const Text('Quick Suggestions', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _quickPrompts.map((p) {
              return ActionChip(
                backgroundColor: const Color(0xFF121A29),
                side: const BorderSide(color: Color(0xFF1E293B)),
                label: Text(p, style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1))),
                onPressed: () => setState(() => _promptController.text = p),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // What should we build?
          const Text('What should we build?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 8),
          TextField(
            controller: _promptController,
            minLines: 3,
            maxLines: 6,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Describe a feature, paste an error or ask for a technical plan...',
              hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
              filled: true,
              fillColor: const Color(0xFF121A29),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1E293B)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1E293B)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Send to AI Button
          ElevatedButton.icon(
            onPressed: _isProcessing ? null : _sendToAI,
            icon: _isProcessing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.auto_awesome, size: 18),
            label: Text(
              _isProcessing ? 'Synthesizing Solution...' : 'Send to AI',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5A77F6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
          const SizedBox(height: 24),

          // Assistant Response Section
          const Text('Assistant response', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 10),

          if (_events.isEmpty && _proposedPatch == null && !_isProcessing)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF121A29),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: const Text(
                'Choose a provider or load the offline Qwen model to start...',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
              ),
            ),

          if (_events.isNotEmpty || _isProcessing) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF121A29),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.hub_outlined, color: Color(0xFF34D399), size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'Specialist Agent Collaboration',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const Spacer(),
                      if (_isProcessing)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF34D399)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._events.map((ev) {
                    final role = ev.payload['agent_role'] ?? 'agent';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              role.toString().toUpperCase(),
                              style: const TextStyle(fontSize: 9.5, color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ev.message,
                              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12.5, height: 1.3),
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

          if (_proposedPatch != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF121A29),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.difference_outlined, color: Color(0xFF818CF8), size: 18),
                      const SizedBox(width: 8),
                      const Text('Proposed Code Modification', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      const Spacer(),
                      if (_patchDecision != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _patchDecision == 'approved' ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _patchDecision!.toUpperCase(),
                            style: TextStyle(
                              color: _patchDecision == 'approved' ? Colors.greenAccent : Colors.redAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D121D),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _proposedPatch!.unifiedDiff ?? '',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFF93C5FD)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_patchDecision == null)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _handleDecision('rejected'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: BorderSide(color: Colors.red.shade400.withValues(alpha: 0.5)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _handleDecision('approved'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF34D399),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Approve & Apply', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

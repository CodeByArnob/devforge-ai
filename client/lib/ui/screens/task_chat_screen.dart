import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/secure_vault.dart';
import 'diff_viewer_screen.dart';

class TaskChatScreen extends StatefulWidget {
  final ProjectModel? initialProject;
  const TaskChatScreen({super.key, this.initialProject});

  @override
  State<TaskChatScreen> createState() => _TaskChatScreenState();
}

class _TaskChatScreenState extends State<TaskChatScreen> {
  final ApiService _api = ApiService();
  final SecureVault _vault = SecureVault();

  List<TaskModel> _tasks = [];
  TaskModel? _selectedTask;
  final List<TaskEventModel> _events = [];
  StreamSubscription<TaskEventModel>? _eventSub;

  bool _isLoadingTasks = true;
  bool _isStreaming = false;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoadingTasks = true);
    try {
      final list = await _api.listTasks();
      setState(() {
        _tasks = list;
        if (_tasks.isNotEmpty && _selectedTask == null) {
          _selectTask(_tasks.first);
        }
      });
    } catch (_) {}
    if (mounted) setState(() => _isLoadingTasks = false);
  }

  void _selectTask(TaskModel task) {
    _eventSub?.cancel();
    setState(() {
      _selectedTask = task;
      _events.clear();
      _isStreaming = true;
    });

    _eventSub = _api.streamTaskEvents(task.id).listen(
      (event) {
        if (mounted) {
          setState(() {
            _events.add(event);
          });
        }
      },
      onError: (_) {
        if (mounted) setState(() => _isStreaming = false);
      },
      onDone: () {
        if (mounted) setState(() => _isStreaming = false);
      },
    );
  }

  void _showCreateTaskDialog() async {
    final projects = await _api.listProjects();
    if (projects.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please import a project first!')));
      }
      return;
    }

    String selectedProjId = widget.initialProject?.id ?? projects.first.id;
    final instructionCtrl = TextEditingController(text: 'Add comprehensive unit tests and fix linter errors.');
    String selectedModel = 'openrouter/free';

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Autonomous Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedProjId,
                  decoration: const InputDecoration(labelText: 'Project'),
                  items: projects
                      .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (val) => setDialogState(() => selectedProjId = val!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedModel,
                  decoration: const InputDecoration(labelText: 'Model'),
                  items: const [
                    DropdownMenuItem(value: 'openrouter/free', child: Text('openrouter/free (Default Router)')),
                    DropdownMenuItem(value: 'meta-llama/llama-3.2-3b-instruct:free', child: Text('Llama 3.2 3B (:free)')),
                    DropdownMenuItem(value: 'qwen/qwen-2.5-coder-32b-instruct:free', child: Text('Qwen 2.5 Coder (:free)')),
                  ],
                  onChanged: (val) => setDialogState(() => selectedModel = val!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: instructionCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Task Instruction',
                    hintText: 'Describe feature, bugfix, or tests...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final task = await _api.createTask(selectedProjId, instructionCtrl.text.trim(), model: selectedModel);
                  _loadTasks();
                  _selectTask(task);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                  }
                }
              },
              child: const Text('Create Task'),
            ),
          ],
        ),
      ),
    );
  }

  void _runTeam({bool fullTeam = false}) async {
    if (_selectedTask == null) return;
    if (!_vault.hasOpenRouterKey) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please configure your OpenRouter API Key in Vault Settings first!')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(fullTeam ? 'Running 8-Agent Autonomous Specialist Team...' : 'Running 4-Agent Planning Team...')),
    );

    try {
      final roles = fullTeam
          ? [
              'architect',
              'planner',
              'coder',
              'security_reviewer',
              'qa_engineer',
              'build_engineer',
              'repair_engineer',
              'integration_engineer'
            ]
          : null;
      await _api.runAgentTeam(_selectedTask!.id, roles: roles);
      final updated = await _api.getTask(_selectedTask!.id);
      setState(() => _selectedTask = updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Team Run failed: $e')));
      }
    }
  }

  void _showApprovalDialog() {
    if (_selectedTask == null) return;
    final noteCtrl = TextEditingController(text: 'Approved for automated execution and verification.');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Human Approval Gate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Explicit owner approval is required before the isolated runner executes project code.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Review Note', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _api.decideTaskApproval(_selectedTask!.id, 'rejected', note: 'Rejected by owner');
              final updated = await _api.getTask(_selectedTask!.id);
              setState(() => _selectedTask = updated);
            },
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _api.decideTaskApproval(_selectedTask!.id, 'approved', note: noteCtrl.text.trim());
              final updated = await _api.getTask(_selectedTask!.id);
              setState(() => _selectedTask = updated);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plan Approved! Task entered the worker queue.')));
              }
            },
            child: const Text('Approve Plan'),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'awaiting_approval':
        return Colors.amber.shade700;
      case 'planning':
      case 'editing':
      case 'validating':
      case 'building':
        return Colors.blue;
      case 'failed':
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multi-Agent Workspace'),
        actions: [
          IconButton(icon: const Icon(Icons.add_task), tooltip: 'New Task', onPressed: _showCreateTaskDialog),
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh', onPressed: _loadTasks),
        ],
      ),
      body: _isLoadingTasks
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.task_alt, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('No active tasks.', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _showCreateTaskDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Create New Task'),
                      ),
                    ],
                  ),
                )
              : Row(
                  children: [
                    // Tasks sidebar
                    SizedBox(
                      width: 280,
                      child: ListView.builder(
                        itemCount: _tasks.length,
                        itemBuilder: (context, idx) {
                          final t = _tasks[idx];
                          final isSelected = t.id == _selectedTask?.id;
                          return ListTile(
                            selected: isSelected,
                            selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                            title: Text(t.instruction, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: _statusColor(t.status)),
                                ),
                                const SizedBox(width: 6),
                                Text(t.status.toUpperCase(), style: TextStyle(fontSize: 10, color: _statusColor(t.status))),
                              ],
                            ),
                            onTap: () => _selectTask(t),
                          );
                        },
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    // Timeline & Workspace
                    Expanded(
                      child: _selectedTask == null
                          ? const Center(child: Text('Select a task to view timeline'))
                          : Column(
                              children: [
                                // Task Header
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(_selectedTask!.instruction, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                            const SizedBox(height: 4),
                                            Text('Task ID: ${_selectedTask!.id} • Status: ${_selectedTask!.status.toUpperCase()}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          ],
                                        ),
                                      ),
                                      if (_selectedTask!.status == 'awaiting_approval')
                                        ElevatedButton.icon(
                                          onPressed: _showApprovalDialog,
                                          icon: const Icon(Icons.approval),
                                          label: const Text('Decide Approval'),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800, foregroundColor: Colors.white),
                                        ),
                                      const SizedBox(width: 8),
                                      PopupMenuButton<String>(
                                        onSelected: (val) {
                                          if (val == 'plan') _runTeam(fullTeam: false);
                                          if (val == 'full') _runTeam(fullTeam: true);
                                          if (val == 'diff') {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (_) => DiffViewerScreen(taskId: _selectedTask!.id)),
                                            );
                                          }
                                        },
                                        itemBuilder: (ctx) => [
                                          const PopupMenuItem(value: 'plan', child: Text('Run 4 Planning Agents')),
                                          const PopupMenuItem(value: 'full', child: Text('Run All 8 Specialist Agents')),
                                          const PopupMenuItem(value: 'diff', child: Text('View Patch Protests & Diffs')),
                                        ],
                                        child: ElevatedButton.icon(
                                          onPressed: null,
                                          icon: const Icon(Icons.play_arrow),
                                          label: const Text('Run Agents'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                // Live Timeline
                                Expanded(
                                  child: _events.isEmpty
                                      ? Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(_isStreaming ? Icons.sync : Icons.timeline, size: 48, color: Colors.grey),
                                              const SizedBox(height: 12),
                                              Text(_isStreaming ? 'Listening to real-time event stream...' : 'No events logged for this task.'),
                                            ],
                                          ),
                                        )
                                      : ListView.builder(
                                          padding: const EdgeInsets.all(12),
                                          itemCount: _events.length,
                                          itemBuilder: (context, idx) {
                                            final ev = _events[idx];
                                            return Card(
                                              margin: const EdgeInsets.symmetric(vertical: 4),
                                              child: ListTile(
                                                leading: CircleAvatar(
                                                  radius: 14,
                                                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                                                  child: Text('${ev.sequence}', style: const TextStyle(fontSize: 11)),
                                                ),
                                                title: Text(ev.message, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                                subtitle: Text('${ev.eventType} • ${ev.createdAt.toIso8601String().substring(11, 19)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
    );
  }
}

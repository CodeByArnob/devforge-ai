import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../../core/services/api_service.dart';

class DiffViewerScreen extends StatefulWidget {
  final String taskId;
  const DiffViewerScreen({super.key, required this.taskId});

  @override
  State<DiffViewerScreen> createState() => _DiffViewerScreenState();
}

class _DiffViewerScreenState extends State<DiffViewerScreen> {
  final ApiService _api = ApiService();
  List<PatchProposalModel> _patches = [];
  PatchProposalModel? _selectedPatch;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPatches();
  }

  Future<void> _loadPatches() async {
    setState(() => _isLoading = true);
    try {
      final list = await _api.listPatches(widget.taskId);
      setState(() {
        _patches = list;
        if (_patches.isNotEmpty) {
          _selectPatch(_patches.first.patchId);
        }
      });
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _selectPatch(String patchId) async {
    try {
      final detailed = await _api.getPatch(widget.taskId, patchId);
      setState(() => _selectedPatch = detailed);
    } catch (_) {}
  }

  Widget _buildDiffLine(String line) {
    Color bg = Colors.transparent;
    Color fg = Colors.white70;

    if (line.startsWith('+') && !line.startsWith('+++')) {
      bg = Colors.green.withValues(alpha: 0.15);
      fg = Colors.greenAccent;
    } else if (line.startsWith('-') && !line.startsWith('---')) {
      bg = Colors.red.withValues(alpha: 0.15);
      fg = Colors.redAccent;
    } else if (line.startsWith('@@')) {
      bg = Colors.blue.withValues(alpha: 0.1);
      fg = Colors.lightBlueAccent;
    }

    return Container(
      color: bg,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Text(
        line,
        style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: fg),
      ),
    );
  }

  void _approvePatch() async {
    if (_selectedPatch == null) return;
    try {
      await _api.approvePatch(widget.taskId, _selectedPatch!.patchId, note: 'Approved via Diff Viewer');
      _loadPatches();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Patch applied successfully to immutable snapshot!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Approval failed: $e')));
      }
    }
  }

  void _rejectPatch() async {
    if (_selectedPatch == null) return;
    try {
      await _api.rejectPatch(widget.taskId, _selectedPatch!.patchId, note: 'Rejected via Diff Viewer');
      _loadPatches();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Patch rejected.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reject failed: $e')));
      }
    }
  }

  void _rollbackPatch() async {
    if (_selectedPatch == null) return;
    try {
      await _api.rollbackPatch(widget.taskId, _selectedPatch!.patchId);
      _loadPatches();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Patch rolled back! Restored to base snapshot.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rollback failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unified Diff & Patch Approvals'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadPatches),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _patches.isEmpty
              ? const Center(child: Text('No patch proposals generated for this task yet.'))
              : Row(
                  children: [
                    // Proposal selector
                    SizedBox(
                      width: 260,
                      child: ListView.builder(
                        itemCount: _patches.length,
                        itemBuilder: (ctx, idx) {
                          final p = _patches[idx];
                          final isSelected = p.patchId == _selectedPatch?.patchId;
                          return ListTile(
                            selected: isSelected,
                            title: Text('Patch #${p.patchId.substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Status: ${p.status.toUpperCase()}'),
                            onTap: () => _selectPatch(p.patchId),
                          );
                        },
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    // Diff Viewer
                    Expanded(
                      child: _selectedPatch == null
                          ? const Center(child: Text('Select a patch proposal'))
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Action Bar
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  color: Colors.black26,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Base: ${_selectedPatch!.baseSnapshotDigest.substring(0, 16)}... • Status: ${_selectedPatch!.status.toUpperCase()}'),
                                            if (_selectedPatch!.appliedSnapshotDigest != null)
                                              Text('Applied Digest: ${_selectedPatch!.appliedSnapshotDigest!.substring(0, 16)}...', style: const TextStyle(fontSize: 11, color: Colors.green)),
                                          ],
                                        ),
                                      ),
                                      if (_selectedPatch!.status == 'proposed') ...[
                                        ElevatedButton.icon(
                                          onPressed: _approvePatch,
                                          icon: const Icon(Icons.check),
                                          label: const Text('Approve & Apply'),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                                        ),
                                        const SizedBox(width: 8),
                                        TextButton.icon(
                                          onPressed: _rejectPatch,
                                          icon: const Icon(Icons.close),
                                          label: const Text('Reject', style: TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                      if (_selectedPatch!.status == 'applied') ...[
                                        ElevatedButton.icon(
                                          onPressed: _rollbackPatch,
                                          icon: const Icon(Icons.undo),
                                          label: const Text('Rollback Patch'),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                // Diff Content
                                Expanded(
                                  child: Container(
                                    color: const Color(0xFF1E1E1E),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: SizedBox(
                                        width: 900,
                                        child: ListView(
                                          children: (_selectedPatch!.unifiedDiff ?? 'No unified diff generated.')
                                              .split('\n')
                                              .map((line) => _buildDiffLine(line))
                                              .toList(),
                                        ),
                                      ),
                                    ),
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

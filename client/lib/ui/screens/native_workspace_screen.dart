import 'package:flutter/material.dart';
import '../../core/services/native_workspace_service.dart';

class NativeWorkspaceScreen extends StatefulWidget {
  const NativeWorkspaceScreen({super.key});

  @override
  State<NativeWorkspaceScreen> createState() => _NativeWorkspaceScreenState();
}

class _NativeWorkspaceScreenState extends State<NativeWorkspaceScreen> {
  final NativeWorkspaceService _workspace = NativeWorkspaceService();
  List<Map<String, dynamic>> _entries = [];
  Map<String, dynamic> _runtime = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final runtime = await _workspace.runtimeInfo();
      final entries = await _workspace.listEntries();
      if (!mounted) return;
      setState(() {
        _runtime = runtime;
        _entries = entries;
      });
    } on MissingPluginException {
      if (!mounted) return;
      setState(() => _error = 'Native workspace is available only in the Android application.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openFile(Map<String, dynamic> entry) async {
    try {
      final content = await _workspace.readFile(entry['path'] as String);
      if (!mounted) return;
      final controller = TextEditingController(text: content);
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => _WorkspaceFileEditor(
            path: entry['path'] as String,
            controller: controller,
            onSave: () => _workspace.writeFile(entry['path'] as String, controller.text),
          ),
        ),
      );
      controller.dispose();
      if (saved == true) _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to open file: $error')));
    }
  }

  Future<void> _createFolder() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Folder name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || name.contains('/') || name == '.' || name == '..') return;
    try {
      await _workspace.createDirectory(name);
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to create folder: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final runtimeInstalled = _runtime['linuxRuntimeInstalled'] == true;\n    final abis = _runtime['supportedAbis'] as List?;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Workspace'),
        actions: [
          IconButton(onPressed: _createFolder, icon: const Icon(Icons.create_new_folder_outlined), tooltip: 'New folder'),
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(runtimeInstalled ? Icons.check_circle : Icons.info_outline,
                            color: runtimeInstalled ? Colors.greenAccent : Colors.orangeAccent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            runtimeInstalled ? 'Linux runtime detected' : 'Linux runtime not installed',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      runtimeInstalled
                          ? 'A local Linux runtime was detected. Runtime compatibility checks are still required before execution.'
                          : 'The private Android workspace is ready. Linux/PRoot execution is not installed yet; no shell commands will be run from this screen.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoChip(label: 'Android API ${_runtime['sdkInt'] ?? '—'}'),
                        _InfoChip(label: 'ABI ${(abis != null && abis.isNotEmpty ? abis.first : '—')}'),
                        const _InfoChip(label: 'Private storage'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Text('Workspace files', style: Theme.of(context).textTheme.titleMedium)),
                Text('${_entries.length} items', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            if (!_loading && _error == null && _entries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text('Your private workspace is empty. Create a folder or add files to get started.')),
              ),
            ..._entries.map((entry) {
              final isDirectory = entry['type'] == 'directory';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(isDirectory ? Icons.folder_outlined : Icons.description_outlined,
                    color: isDirectory ? Colors.amber : Theme.of(context).colorScheme.primary),
                title: Text(entry['name'] as String),
                subtitle: Text(entry['path'] as String),
                trailing: isDirectory
                    ? null
                    : Text('${entry['size']} B', style: Theme.of(context).textTheme.labelSmall),
                onTap: isDirectory ? null : () => _openFile(entry),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) => Chip(label: Text(label));
}

class _WorkspaceFileEditor extends StatefulWidget {
  final String path;
  final TextEditingController controller;
  final Future<void> Function() onSave;

  const _WorkspaceFileEditor({
    required this.path,
    required this.controller,
    required this.onSave,
  });

  @override
  State<_WorkspaceFileEditor> createState() => _WorkspaceFileEditorState();
}

class _WorkspaceFileEditorState extends State<_WorkspaceFileEditor> {
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.onSave();
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.path, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            onPressed: _saving ? null : _save,
            icon: _saving ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
            tooltip: 'Save file',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: widget.controller,
          expands: true,
          minLines: null,
          maxLines: null,
          textAlignVertical: TextAlignVertical.top,
          autocorrect: false,
          enableSuggestions: false,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          decoration: const InputDecoration(
            hintText: 'File content',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
      ),
    );
  }
}

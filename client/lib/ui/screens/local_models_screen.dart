import 'package:flutter/material.dart';
import '../../core/models/models.dart';
import '../../core/services/api_service.dart';

class LocalModelsScreen extends StatefulWidget {
  const LocalModelsScreen({super.key});

  @override
  State<LocalModelsScreen> createState() => _LocalModelsScreenState();
}

class _LocalModelsScreenState extends State<LocalModelsScreen> {
  final ApiService _api = ApiService();
  List<LocalGGUFModel> _models = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    setState(() => _isLoading = true);
    try {
      final list = await _api.listLocalModels();
      setState(() => _models = list);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  void _showValidateDialog(LocalGGUFModel? model) {
    final pathCtrl = TextEditingController(text: '/models/${model?.family ?? "model"}.gguf');
    final shaCtrl = TextEditingController(text: model?.sha256 ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Validate Local GGUF File'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: pathCtrl, decoration: const InputDecoration(labelText: 'Local File Path', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: shaCtrl, decoration: const InputDecoration(labelText: 'Expected SHA-256 (optional)', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final result = await _api.validateGGUF(pathCtrl.text.trim(), expectedSha256: shaCtrl.text.trim().isEmpty ? null : shaCtrl.text.trim());
                if (mounted) {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Validation Passed'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Magic: Valid GGUF', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                          Text('Size: ${result['file_size_gb']} GB'),
                          Text('SHA-256: ${result['sha256']}'),
                          const Divider(),
                          Text('Estimated RAM: ${result['ram_requirement']?['total_min_ram_gb']} GB'),
                        ],
                      ),
                      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Validation failed: $e')));
                }
              }
            },
            child: const Text('Validate'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local GGUF Models & Hardware Validation'),
        actions: [
          IconButton(icon: const Icon(Icons.verified), tooltip: 'Validate File', onPressed: () => _showValidateDialog(null)),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadModels),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _models.length,
              itemBuilder: (context, idx) {
                final m = _models[idx];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Chip(label: Text(m.quantization, style: const TextStyle(fontSize: 11)), padding: EdgeInsets.zero),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Family: ${m.family.toUpperCase()} • Parameters: ${m.parameters} • Context: ${m.contextLength}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                              child: Text('RAM: ${m.minRamGb} GB', style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                              child: Text('VRAM: ${m.recommendedVramGb} GB', style: const TextStyle(color: Colors.purpleAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                              child: Text('License: ${m.license}', style: TextStyle(color: Colors.amber.shade400, fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 4,
                          children: m.supportedAbis
                              .map((abi) => Chip(
                                    label: Text(abi, style: const TextStyle(fontSize: 10)),
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _showValidateDialog(m),
                              icon: const Icon(Icons.check_circle_outline, size: 16),
                              label: const Text('Verify Local File'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

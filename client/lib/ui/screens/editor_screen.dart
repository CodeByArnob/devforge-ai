import 'package:flutter/material.dart';

class EditorScreen extends StatefulWidget {
  final VoidCallback? onNavigateToBuilds;
  const EditorScreen({super.key, this.onNavigateToBuilds});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  String _selectedLanguage = 'Dart';
  final List<String> _languages = ['Dart', 'Python', 'JavaScript', 'TypeScript', 'Rust', 'Go', 'HTML', 'SQL'];

  late final TextEditingController _codeController;
  bool _isSaved = true;

  static const Map<String, String> _templates = {
    'Dart': '''// DevForge AI — Flutter / Dart Mobile Entrypoint
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(title: const Text('DevForge AI App')),
        body: const Center(
          child: Text('Built directly from Android with DevForge AI!'),
        ),
      ),
    );
  }
}
''',
    'Python': '''# DevForge AI — Python FastAPI Microservice
from fastapi import FastAPI

app = FastAPI(title="DevForge AI API", version="1.0.0")

@app.get("/")
def read_root():
    return {"status": "healthy", "engine": "DevForge AI Sandbox"}

@app.get("/items/{item_id}")
def read_item(item_id: int):
    return {"item_id": item_id, "active": True}
''',
    'JavaScript': '''// DevForge AI — Node.js REST API
const http = require('http');

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({
    service: 'DevForge AI Runner',
    timestamp: new Date().toISOString(),
    sandbox: 'podman-rootless'
  }));
});

server.listen(3000, () => console.log('Server running on :3000'));
''',
  };

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: _templates['Dart'] ?? '');
    _codeController.addListener(() {
      if (_isSaved) {
        setState(() => _isSaved = false);
      }
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _loadTemplate(String lang) {
    setState(() {
      _selectedLanguage = lang;
      if (_templates.containsKey(lang)) {
        _codeController.text = _templates[lang]!;
      }
      _isSaved = true;
    });
  }

  void _saveCode() {
    setState(() => _isSaved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Color(0xFF34D399), size: 18),
            const SizedBox(width: 8),
            Text('Saved $_selectedLanguage file locally to device'),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showTemplatesModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121A29),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.dashboard_customize_outlined, color: Color(0xFF38BDF8), size: 20),
                SizedBox(width: 8),
                Text('Starter Project Templates', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Choose a template to quickly scaffold and build your mobile project:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.flutter_dash, color: Color(0xFF38BDF8)),
              title: const Text('Flutter Material 3 App', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: const Text('Mobile UI with dark theme & widgets', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5)),
              onTap: () {
                Navigator.pop(ctx);
                _loadTemplate('Dart');
              },
            ),
            ListTile(
              leading: const Icon(Icons.data_object, color: Color(0xFF34D399)),
              title: const Text('Python FastAPI Service', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: const Text('Microservice endpoints with Swagger UI', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5)),
              onTap: () {
                Navigator.pop(ctx);
                _loadTemplate('Python');
              },
            ),
            ListTile(
              leading: const Icon(Icons.javascript, color: Color(0xFFFBBF24)),
              title: const Text('Node.js Backend API', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: const Text('Lightweight HTTP server container', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5)),
              onTap: () {
                Navigator.pop(ctx);
                _loadTemplate('JavaScript');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0E14),
        elevation: 0,
        title: const Text(
          'Code Editor',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_stories_outlined, color: Color(0xFF818CF8)),
            tooltip: 'Starter Templates',
            onPressed: _showTemplatesModal,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFF94A3B8)),
            tooltip: 'Reset editor',
            onPressed: () => _loadTemplate(_selectedLanguage),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14.0, top: 8.0, bottom: 8.0),
            child: ElevatedButton.icon(
              onPressed: _saveCode,
              icon: const Icon(Icons.save_outlined, size: 16),
              label: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Color(0xFF334155)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Sub-bar with LOCAL DRAFT tag & Language dropdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.code_rounded, size: 16, color: Color(0xFF34D399)),
                    const SizedBox(width: 6),
                    Text(
                      'LOCAL DRAFT',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF34D399),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121A29),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedLanguage,
                      isDense: true,
                      dropdownColor: const Color(0xFF121A29),
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF94A3B8), size: 18),
                      items: _languages.map((lang) {
                        return DropdownMenuItem<String>(
                          value: lang,
                          child: Text(lang),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) _loadTemplate(val);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Code Text Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D121D),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _codeController,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13.5,
                    color: Color(0xFFE2E8F0),
                    height: 1.5,
                  ),
                  cursorColor: const Color(0xFF34D399),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          ),

          // Bottom status bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _isSaved ? Icons.check_circle_outline : Icons.edit_note,
                      size: 15,
                      color: _isSaved ? const Color(0xFF34D399) : Colors.amberAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isSaved ? 'Saved locally' : 'Unsaved changes',
                      style: TextStyle(
                        fontSize: 12,
                        color: _isSaved ? const Color(0xFF34D399) : Colors.amberAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Text(
                  _selectedLanguage,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

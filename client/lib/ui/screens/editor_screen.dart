import 'package:flutter/material.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  String _selectedLanguage = 'Dart';
  final List<String> _languages = ['Dart', 'Python', 'JavaScript', 'TypeScript', 'Rust', 'Go', 'HTML', 'SQL'];

  late final TextEditingController _codeController;
  bool _isSaved = true;

  static const String _defaultCode = '''// Welcome to DevForge AI
// This is an offline-ready local scratch file.
// Connect a GitHub repository to enable repository editing.

void main() {
  print('Build something remarkable.');
}
''';

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: _defaultCode);
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

  void _saveCode() {
    setState(() => _isSaved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Color(0xFF34D399), size: 18),
            const SizedBox(width: 8),
            Text('Saved $_selectedLanguage scratch file locally'),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _clearEditor() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF121A29),
        title: const Text('Reset Editor?', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text('Do you want to reset to the default starter code?', style: TextStyle(color: Color(0xFF94A3B8))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _codeController.text = _defaultCode;
                _isSaved = true;
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900),
            child: const Text('Reset'),
          ),
        ],
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
            icon: const Icon(Icons.delete_outline, color: Color(0xFF94A3B8)),
            tooltip: 'Reset editor',
            onPressed: _clearEditor,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 8.0, bottom: 8.0),
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
                        if (val != null) setState(() => _selectedLanguage = val);
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

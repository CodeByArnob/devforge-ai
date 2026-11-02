import 'package:flutter/material.dart';
import 'core/services/secure_vault.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DevForgeApp());
}

class DevForgeApp extends StatefulWidget {
  const DevForgeApp({super.key});

  @override
  State<DevForgeApp> createState() => _DevForgeAppState();
}

class _DevForgeAppState extends State<DevForgeApp> {
  final SecureVault _vault = SecureVault();
  bool _authenticated = false;

  @override
  void initState() {
    super.initState();
    _authenticated = _vault.isAuthenticated;
    _vault.onVaultUpdated.listen((_) {
      if (mounted) {
        setState(() {
          _authenticated = _vault.isAuthenticated;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DevForge AI',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF4F80E2),
          secondary: const Color(0xFF26C6DA),
          surface: const Color(0xFF1E2024),
          error: Colors.red.shade400,
        ),
        scaffoldBackgroundColor: const Color(0xFF121316),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E2024),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1C20),
          elevation: 0,
          centerTitle: false,
        ),
      ),
      home: _authenticated
          ? HomeScreen(onLogout: () => setState(() => _authenticated = false))
          : LoginScreen(onLoginSuccess: () => setState(() => _authenticated = true)),
    );
  }
}

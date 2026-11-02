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
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF5A77F6),
          secondary: Color(0xFF34D399),
          surface: Color(0xFF121A29),
          onSurface: Colors.white,
          error: Color(0xFFEF4444),
        ),
        scaffoldBackgroundColor: const Color(0xFF0B0E14),
        cardTheme: CardThemeData(
          color: const Color(0xFF121A29),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF1E293B), width: 1),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF0A0D15),
          indicatorColor: const Color(0xFF25314C),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: Colors.white);
            }
            return const IconThemeData(color: Color(0xFF94A3B8));
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11);
            }
            return const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.normal, fontSize: 11);
          }),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0B0E14),
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

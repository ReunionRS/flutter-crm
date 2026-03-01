import 'package:flutter/material.dart';

import '../../models/session_models.dart';
import '../../services/auth_service.dart';
import '../home/home_screen.dart';
import 'login_screen.dart';
import 'startup_splash.dart';

class AppEntryPoint extends StatefulWidget {
  const AppEntryPoint({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  @override
  State<AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<AppEntryPoint> {
  final _auth = AuthService();
  bool _loading = true;
  AppSession? _session;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final session = await _auth.getSession();
    if (!mounted) return;
    setState(() {
      _session = session;
      _loading = false;
    });
  }

  Future<void> _logout() async {
    await _auth.clearSession();
    if (!mounted) return;
    setState(() => _session = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const StartupSplash();
    }

    if (_session != null) {
      return HomeScreen(
        auth: _auth,
        session: _session!,
        isDarkMode: widget.isDarkMode,
        onToggleTheme: widget.onToggleTheme,
        onLogout: _logout,
      );
    }

    return LoginScreen(
      auth: _auth,
      onLoginSuccess: (session) => setState(() => _session = session),
    );
  }
}

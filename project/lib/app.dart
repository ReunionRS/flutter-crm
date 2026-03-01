import 'package:flutter/material.dart';

import 'features/auth/app_entry_point.dart';

class MartStroyApp extends StatefulWidget {
  const MartStroyApp({super.key});

  @override
  State<MartStroyApp> createState() => _MartStroyAppState();
}

class _MartStroyAppState extends State<MartStroyApp> {
  ThemeMode _themeMode = ThemeMode.system;

  bool get _isDark => _themeMode == ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode = _isDark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  ThemeData _buildLightTheme() {
    const primary = Color(0xFFE0AC00);
    final scheme = ColorScheme.fromSeed(seedColor: primary, brightness: Brightness.light);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(primary: primary, secondary: primary),
      scaffoldBackgroundColor: const Color(0xFFF5F6F8),
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Colors.black.withOpacity(0.06)),
        ),
      ),
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      dividerColor: Colors.black.withOpacity(0.08),
    );
  }

  ThemeData _buildDarkTheme() {
    const primary = Color(0xFFE0AC00);
    final scheme = ColorScheme.fromSeed(seedColor: primary, brightness: Brightness.dark);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(
        primary: primary,
        secondary: primary,
        surface: const Color(0xFF17181D),
      ),
      scaffoldBackgroundColor: const Color(0xFF0E0F13),
      cardTheme: CardTheme(
        color: const Color(0xFF1A1C22),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Color(0xFF17181D),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF12141A),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      dividerColor: Colors.white.withOpacity(0.10),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Март Строй',
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: _themeMode,
      home: AppEntryPoint(
        isDarkMode: _isDark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Март Строй',
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFE0AC00),
          secondary: Color(0xFFE0AC00),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE0AC00),
          secondary: Color(0xFFE0AC00),
          surface: Color(0xFF17181D),
        ),
      ),
      themeMode: _themeMode,
      home: AppEntryPoint(
        isDarkMode: _isDark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

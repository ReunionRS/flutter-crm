import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MartStroyApp());
}

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

class ApiConfig {
  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;

    if (kIsWeb) return 'http://localhost:4000';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:4000';
      default:
        return 'http://localhost:4000';
    }
  }
}

class AppSession {
  const AppSession({
    required this.token,
    required this.email,
    required this.fio,
    required this.role,
  });

  final String token;
  final String email;
  final String fio;
  final String role;
}

class UnauthorizedException implements Exception {
  const UnauthorizedException();
}

class ProjectSummary {
  ProjectSummary({
    required this.id,
    required this.clientFio,
    required this.constructionAddress,
    required this.status,
    required this.startDate,
    required this.plannedEndDate,
    required this.progress,
  });

  final String id;
  final String clientFio;
  final String constructionAddress;
  final String status;
  final String startDate;
  final String plannedEndDate;
  final int progress;

  static ProjectSummary fromJson(Map<String, dynamic> json) {
    final stages = (json['stages'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    final total = stages.length;
    final done = stages
        .where((s) => (s['status'] ?? '').toString().toLowerCase() == 'завершён')
        .length;

    return ProjectSummary(
      id: (json['id'] ?? '').toString(),
      clientFio: (json['clientFio'] ?? '—').toString(),
      constructionAddress: (json['constructionAddress'] ?? '—').toString(),
      status: (json['status'] ?? '—').toString(),
      startDate: (json['startDate'] ?? '').toString(),
      plannedEndDate: (json['plannedEndDate'] ?? '').toString(),
      progress: total == 0 ? 0 : ((done / total) * 100).round(),
    );
  }
}

class AuthService {
  static const _tokenKey = 'auth_token';
  static const _rememberEmailKey = 'remember_email';
  static const _userEmailKey = 'user_email';
  static const _userFioKey = 'user_fio';
  static const _userRoleKey = 'user_role';

  Future<AppSession?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null || token.isEmpty) return null;
    return AppSession(
      token: token,
      email: prefs.getString(_userEmailKey) ?? '',
      fio: prefs.getString(_userFioKey) ?? '',
      role: prefs.getString(_userRoleKey) ?? 'client',
    );
  }

  Future<String> getRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_rememberEmailKey) ?? '';
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userFioKey);
    await prefs.remove(_userRoleKey);
  }

  Future<void> saveRememberedEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rememberEmailKey, email);
  }

  Future<void> clearRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rememberEmailKey);
  }

  Future<AppSession> login({
    required String email,
    required String password,
    required bool rememberEmail,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/auth/login');

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      String message = 'Ошибка входа';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final apiMessage = body['error'];
        if (apiMessage is String && apiMessage.isNotEmpty) {
          message = apiMessage;
        }
      } catch (_) {}
      throw Exception(message);
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final token = body['token'];
    final user = body['user'];
    if (token is! String || token.isEmpty || user is! Map<String, dynamic>) {
      throw Exception('Некорректный ответ сервера');
    }

    final session = AppSession(
      token: token,
      email: (user['email'] ?? '').toString(),
      fio: (user['fio'] ?? '').toString(),
      role: (user['role'] ?? 'client').toString(),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, session.token);
    await prefs.setString(_userEmailKey, session.email);
    await prefs.setString(_userFioKey, session.fio);
    await prefs.setString(_userRoleKey, session.role);

    if (rememberEmail) {
      await saveRememberedEmail(email);
    } else {
      await clearRememberedEmail();
    }

    return session;
  }

  Future<List<ProjectSummary>> fetchProjects() async {
    final session = await getSession();
    if (session == null) {
      throw const UnauthorizedException();
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}/api/projects');
    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer ${session.token}',
      },
    );

    if (response.statusCode == 401) {
      throw const UnauthorizedException();
    }
    if (response.statusCode != 200) {
      throw Exception('Не удалось загрузить объекты');
    }

    final decoded = jsonDecode(response.body);
    final rawList = switch (decoded) {
      List<dynamic> l => l,
      Map<String, dynamic> m when m['items'] is List<dynamic> => m['items'] as List<dynamic>,
      Map<String, dynamic> m when m['projects'] is List<dynamic> => m['projects'] as List<dynamic>,
      _ => <dynamic>[],
    };

    return rawList
        .whereType<Map<String, dynamic>>()
        .map(ProjectSummary.fromJson)
        .toList(growable: false);
  }
}

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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.auth,
    required this.onLoginSuccess,
  });

  final AuthService auth;
  final ValueChanged<AppSession> onLoginSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _rememberEmail = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
  }

  Future<void> _loadRememberedEmail() async {
    final email = await widget.auth.getRememberedEmail();
    if (!mounted) return;
    setState(() {
      _emailController.text = email;
      _rememberEmail = email.isNotEmpty;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final session = await widget.auth.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        rememberEmail: _rememberEmail,
      );
      if (!mounted) return;
      widget.onLoginSuccess(session);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Март Строй',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE0AC00),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Почта'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Введите почту';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Пароль'),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Введите пароль';
                        return null;
                      },
                    ),
                    CheckboxListTile(
                      value: _rememberEmail,
                      onChanged: (v) => setState(() => _rememberEmail = v ?? false),
                      title: const Text('Запомнить данные для входа'),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE0AC00),
                        foregroundColor: Colors.white,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Войти'),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'API: ${ApiConfig.baseUrl}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum AppSection {
  projects,
  documents,
  support,
  notifications,
  calendar,
  reports,
  users,
}

class MenuItemData {
  const MenuItemData({
    required this.section,
    required this.group,
    required this.label,
    required this.icon,
    this.visibleForClient = true,
    this.adminOnly = false,
  });

  final AppSection section;
  final String group;
  final String label;
  final IconData icon;
  final bool visibleForClient;
  final bool adminOnly;
}

const _menuItems = <MenuItemData>[
  MenuItemData(
    section: AppSection.projects,
    group: 'Объекты строительства',
    label: 'Объекты',
    icon: Icons.home_outlined,
  ),
  MenuItemData(
    section: AppSection.documents,
    group: 'Документооборот',
    label: 'Документы',
    icon: Icons.description_outlined,
  ),
  MenuItemData(
    section: AppSection.support,
    group: 'Поддержка',
    label: 'Чат поддержки',
    icon: Icons.chat_bubble_outline,
  ),
  MenuItemData(
    section: AppSection.notifications,
    group: 'Уведомления',
    label: 'Уведомления',
    icon: Icons.notifications_none,
  ),
  MenuItemData(
    section: AppSection.calendar,
    group: 'Планирование',
    label: 'Календарь',
    icon: Icons.calendar_month_outlined,
    visibleForClient: false,
  ),
  MenuItemData(
    section: AppSection.reports,
    group: 'Планирование',
    label: 'Отчёты',
    icon: Icons.bar_chart_outlined,
    visibleForClient: false,
  ),
  MenuItemData(
    section: AppSection.users,
    group: 'Управление',
    label: 'Пользователи',
    icon: Icons.group_outlined,
    visibleForClient: false,
    adminOnly: true,
  ),
];

const _roleLabels = <String, String>{
  'admin': 'Администратор',
  'director': 'Руководитель',
  'foreman': 'Прораб',
  'manager': 'Менеджер по продажам',
  'accountant': 'Бухгалтер',
  'client': 'Клиент',
};

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.auth,
    required this.session,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.onLogout,
  });

  final AuthService auth;
  final AppSession session;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final Future<void> Function() onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  List<ProjectSummary> _projects = const [];
  bool _loading = true;
  String? _error;
  AppSection _section = AppSection.projects;

  bool get _canSeeUsers => widget.session.role == 'admin' || widget.session.role == 'director';

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final projects = await widget.auth.fetchProjects();
      if (!mounted) return;
      setState(() => _projects = projects);
    } on UnauthorizedException {
      await widget.onLogout();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String get _title {
    return switch (_section) {
      AppSection.projects => 'Объекты',
      AppSection.documents => 'Документы',
      AppSection.support => 'Поддержка',
      AppSection.notifications => 'Уведомления',
      AppSection.calendar => 'Календарь',
      AppSection.reports => 'Отчёты',
      AppSection.users => 'Пользователи',
    };
  }

  Widget _placeholder(String title) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          '$title\n(экран переносим следующим шагом)',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildProjectsContent() {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _projects.where((p) {
      if (query.isEmpty) return true;
      return p.clientFio.toLowerCase().contains(query) ||
          p.constructionAddress.toLowerCase().contains(query);
    }).toList(growable: false);

    return RefreshIndicator(
      onRefresh: _loadProjects,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Поиск по ФИО или адресу',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ),
          if (!_loading && _error == null && filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('Объекты не найдены')),
            ),
          for (final project in filtered) _ProjectCard(project: project),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return switch (_section) {
      AppSection.projects => _buildProjectsContent(),
      AppSection.documents => _placeholder('Документы'),
      AppSection.support => _placeholder('Поддержка'),
      AppSection.notifications => _placeholder('Уведомления'),
      AppSection.calendar => _placeholder('Календарь'),
      AppSection.reports => _placeholder('Отчёты'),
      AppSection.users => _placeholder('Пользователи'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1100;

    final sidebar = AppSidebar(
      role: widget.session.role,
      isDarkMode: widget.isDarkMode,
      selectedSection: _section,
      onSelect: (section) {
        if (section == AppSection.users && !_canSeeUsers) return;
        setState(() => _section = section);
      },
      onToggleTheme: widget.onToggleTheme,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        leading: isDesktop ? null : null,
        actions: [
          TextButton(
            onPressed: () => widget.onLogout(),
            child: const Text('Выйти'),
          ),
        ],
      ),
      drawer: isDesktop
          ? null
          : Drawer(
              width: 320,
              child: sidebar,
            ),
      body: isDesktop
          ? Row(
              children: [
                SizedBox(width: 320, child: sidebar),
                const VerticalDivider(width: 1),
                Expanded(child: _buildBody()),
              ],
            )
          : _buildBody(),
    );
  }
}

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.role,
    required this.isDarkMode,
    required this.selectedSection,
    required this.onSelect,
    required this.onToggleTheme,
  });

  final String role;
  final bool isDarkMode;
  final AppSection selectedSection;
  final ValueChanged<AppSection> onSelect;
  final VoidCallback onToggleTheme;

  bool get _isClient => role == 'client';
  bool get _canSeeUsers => role == 'admin' || role == 'director';

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<MenuItemData>>{};
    for (final item in _menuItems) {
      if (_isClient && !item.visibleForClient) continue;
      groups.putIfAbsent(item.group, () => <MenuItemData>[]).add(item);
    }

    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Март Строй',
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          _roleLabels[role] ?? role,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 6, bottom: 8),
                children: groups.entries.expand((entry) {
                  final widgets = <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ];

                  for (final item in entry.value) {
                    final disabled = item.adminOnly && !_canSeeUsers;
                    final selected = selectedSection == item.section;
                    widgets.add(
                      ListTile(
                        dense: true,
                        selected: selected,
                        enabled: !disabled,
                        leading: Icon(item.icon, color: const Color(0xFFE0B300)),
                        title: Text(
                          disabled ? '${item.label} (нет доступа)' : item.label,
                          style: TextStyle(
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        onTap: disabled ? null : () => onSelect(item.section),
                      ),
                    );
                  }

                  return widgets;
                }).toList(growable: false),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
                color: isDarkMode
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.04),
              ),
              child: FilledButton.icon(
                onPressed: onToggleTheme,
                icon: Icon(isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
                label: Text(isDarkMode ? 'Светлая тема' : 'Тёмная тема'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE0B300),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});

  final ProjectSummary project;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              project.clientFio,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(project.constructionAddress),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _Meta(label: 'Статус', value: project.status),
                _Meta(label: 'Начало', value: _fmtDate(project.startDate)),
                _Meta(label: 'План сдачи', value: _fmtDate(project.plannedEndDate)),
                _Meta(label: 'Готовность', value: '${project.progress}%'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.bodyMedium,
        children: [
          TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          TextSpan(text: value),
        ],
      ),
    );
  }
}

String _fmtDate(String iso) {
  if (iso.isEmpty) return '—';
  final parts = iso.split('-');
  if (parts.length != 3) return iso;
  return '${parts[2]}.${parts[1]}.${parts[0]}';
}

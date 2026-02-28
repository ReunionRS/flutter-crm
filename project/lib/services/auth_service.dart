import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_config.dart';
import '../models/project_models.dart';
import '../models/session_models.dart';

class AuthService {
  static const _tokenKey = 'auth_token';
  static const _rememberEmailKey = 'remember_email';
  static const _userEmailKey = 'user_email';
  static const _userFioKey = 'user_fio';
  static const _userRoleKey = 'user_role';

  Future<Map<String, String>> _authHeaders() async {
    final session = await getSession();
    if (session == null) throw const UnauthorizedException();
    return <String, String>{
      'Authorization': 'Bearer ${session.token}',
      'Content-Type': 'application/json',
    };
  }

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
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/projects');
    final headers = await _authHeaders();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) throw Exception('Не удалось загрузить объекты');

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

  Future<ProjectDetails> fetchProjectById(String projectId) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/projects/$projectId'),
      headers: headers,
    );

    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) throw Exception('Не удалось загрузить объект');

    return ProjectDetails.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> createProject(Map<String, dynamic> payload) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/projects'),
      headers: headers,
      body: jsonEncode(payload),
    );
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 201) throw Exception('Не удалось создать объект');
  }

  Future<void> updateProject(String projectId, Map<String, dynamic> payload) async {
    final headers = await _authHeaders();
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/api/projects/$projectId'),
      headers: headers,
      body: jsonEncode(payload),
    );
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) throw Exception('Не удалось обновить объект');
  }

  Future<void> deleteProject(String projectId) async {
    final headers = await _authHeaders();
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/projects/$projectId'),
      headers: headers,
    );
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) throw Exception('Не удалось удалить объект');
  }

  Future<List<ClientOption>> fetchClients() async {
    final headers = await _authHeaders();
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/users'), headers: headers);
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) throw Exception('Не удалось загрузить клиентов');
    final raw = (jsonDecode(response.body) as List<dynamic>).whereType<Map<String, dynamic>>();
    return raw
        .where((u) => (u['role'] ?? '').toString() == 'client')
        .map(
          (u) => ClientOption(
            id: (u['id'] ?? '').toString(),
            fio: (u['fio'] ?? u['email'] ?? 'Клиент').toString(),
            email: (u['email'] ?? '').toString(),
          ),
        )
        .toList(growable: false);
  }
}

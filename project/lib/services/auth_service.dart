import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_config.dart';
import '../models/project_models.dart';
import '../models/session_models.dart';
import '../models/notification_models.dart';
import '../models/support_models.dart';
import '../models/user_models.dart';

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

  Future<String> _token() async {
    final session = await getSession();
    if (session == null) throw const UnauthorizedException();
    return session.token;
  }

  String resolveFileUrl(String storagePath) {
    if (storagePath.isEmpty) return storagePath;
    if (storagePath.startsWith('http://') ||
        storagePath.startsWith('https://')) {
      return storagePath;
    }
    final normalized =
        storagePath.startsWith('/') ? storagePath : '/$storagePath';
    return '${ApiConfig.baseUrl}$normalized';
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
    if (response.statusCode != 200)
      throw Exception('Не удалось загрузить объекты');

    final decoded = jsonDecode(response.body);
    final rawList = switch (decoded) {
      List<dynamic> l => l,
      Map<String, dynamic> m when m['items'] is List<dynamic> =>
        m['items'] as List<dynamic>,
      Map<String, dynamic> m when m['projects'] is List<dynamic> =>
        m['projects'] as List<dynamic>,
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
    if (response.statusCode != 200)
      throw Exception('Не удалось загрузить объект');

    return ProjectDetails.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> createProject(Map<String, dynamic> payload) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/projects'),
      headers: headers,
      body: jsonEncode(payload),
    );
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 201)
      throw Exception('Не удалось создать объект');
  }

  Future<void> updateProject(
      String projectId, Map<String, dynamic> payload) async {
    final headers = await _authHeaders();
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/api/projects/$projectId'),
      headers: headers,
      body: jsonEncode(payload),
    );
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200)
      throw Exception('Не удалось обновить объект');
  }

  Future<void> deleteProject(String projectId) async {
    final headers = await _authHeaders();
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/projects/$projectId'),
      headers: headers,
    );
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200)
      throw Exception('Не удалось удалить объект');
  }

  Future<List<ClientOption>> fetchClients() async {
    final headers = await _authHeaders();
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/users'),
        headers: headers);
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200)
      throw Exception('Не удалось загрузить клиентов');
    final raw = (jsonDecode(response.body) as List<dynamic>)
        .whereType<Map<String, dynamic>>();
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

  Future<ProjectDetails> uploadStagePhotos({
    String? projectId,
    required int stageIndex,
    required List<PlatformFile> files,
  }) async {
    if (files.isEmpty) throw Exception('Файлы не выбраны');
    final token = await _token();
    final req = http.MultipartRequest(
      'POST',
      Uri.parse(
          '${ApiConfig.baseUrl}/api/projects/$projectId/stages/$stageIndex/photos'),
    );
    req.headers['Authorization'] = 'Bearer $token';

    for (final file in files) {
      final name = file.name;
      if (file.bytes != null) {
        req.files.add(
          http.MultipartFile.fromBytes(
            'files',
            file.bytes!,
            filename: name,
            contentType: _guessMediaType(name),
          ),
        );
      } else if (file.path != null) {
        req.files.add(
          await http.MultipartFile.fromPath(
            'files',
            file.path!,
            filename: name,
            contentType: _guessMediaType(name),
          ),
        );
      }
    }

    final streamed = await req.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body,
          fallback: 'Не удалось загрузить фото этапа'));
    }
    return ProjectDetails.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<ProjectDetails> deleteStagePhoto({
    required String projectId,
    required int stageIndex,
    required String photoUrl,
  }) async {
    final headers = await _authHeaders();
    final response = await http.delete(
      Uri.parse(
          '${ApiConfig.baseUrl}/api/projects/$projectId/stages/$stageIndex/photos'),
      headers: headers,
      body: jsonEncode({'photoUrl': photoUrl}),
    );

    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body,
          fallback: 'Не удалось удалить фото этапа'));
    }

    return ProjectDetails.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<ProjectDocument>> fetchDocuments(
      {String? projectId, String? clientUserId}) async {
    final headers = await _authHeaders();
    final query = <String, String>{};
    if (projectId != null && projectId.isNotEmpty) {
      query['projectId'] = projectId;
    }
    if (clientUserId != null && clientUserId.isNotEmpty) {
      query['clientUserId'] = clientUserId;
    }
    final uri = Uri.parse(ApiConfig.baseUrl + '/api/documents')
        .replace(queryParameters: query.isEmpty ? null : query);

    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body,
          fallback: 'Не удалось загрузить документы'));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(ProjectDocument.fromJson)
        .toList(growable: false);
  }

  Future<ProjectDocument> uploadProjectDocument({
    String? projectId,
    required String docType,
    required PlatformFile file,
    String? clientUserId,
  }) async {
    final token = await _token();
    final req = http.MultipartRequest(
      'POST',
      Uri.parse(ApiConfig.baseUrl + '/api/documents'),
    );
    req.headers['Authorization'] = 'Bearer ' + token;
    if (projectId != null && projectId.isNotEmpty) {
      req.fields['projectId'] = projectId;
    }
    req.fields['docType'] = docType;
    if (clientUserId != null && clientUserId.isNotEmpty) {
      req.fields['clientUserId'] = clientUserId;
    }

    if (file.bytes != null) {
      req.files.add(
        http.MultipartFile.fromBytes(
          'file',
          file.bytes!,
          filename: file.name,
          contentType: _guessMediaType(file.name),
        ),
      );
    } else if (file.path != null) {
      req.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path!,
          filename: file.name,
          contentType: _guessMediaType(file.name),
        ),
      );
    } else {
      throw Exception('Не удалось прочитать выбранный файл');
    }

    final streamed = await req.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 201) {
      throw Exception(_extractError(response.body,
          fallback: 'Не удалось загрузить документ'));
    }

    return ProjectDocument.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteDocument(String documentId) async {
    final headers = await _authHeaders();
    final response = await http.delete(
      Uri.parse(ApiConfig.baseUrl + '/api/documents/' + documentId),
      headers: headers,
    );
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_extractError(response.body,
          fallback: 'Не удалось удалить документ'));
    }
  }

  String documentDownloadUrl(String documentId) {
    return ApiConfig.baseUrl + '/api/documents/' + documentId + '/download';
  }

  Future<List<AppNotification>> fetchNotifications() async {
    final headers = await _authHeaders();
    var response = await http.get(
      Uri.parse(ApiConfig.baseUrl + '/api/notifications/feed'),
      headers: headers,
    );
    if (response.statusCode == 404) {
      response = await http.get(
        Uri.parse(ApiConfig.baseUrl + '/api/notifications'),
        headers: headers,
      );
    }

    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode == 404) return const <AppNotification>[];
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body,
          fallback: 'Не удалось загрузить уведомления'));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const <AppNotification>[];

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .toList(growable: false);
  }

  Future<void> markAllNotificationsRead() async {
    final headers = await _authHeaders();
    final response = await http.patch(
      Uri.parse(ApiConfig.baseUrl + '/api/notifications/read-all'),
      headers: headers,
    );

    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode == 404) return;
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_extractError(response.body,
          fallback: 'Не удалось отметить уведомления'));
    }
  }

  Future<void> clearNotifications() async {
    final headers = await _authHeaders();
    final response = await http.delete(
      Uri.parse(ApiConfig.baseUrl + '/api/notifications/clear-all'),
      headers: headers,
      body: '{}',
    );

    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode == 404) return;
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_extractError(response.body,
          fallback: 'Не удалось очистить уведомления'));
    }
  }

  Future<List<AppUser>> fetchUsers() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/users'),
      headers: headers,
    );

    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body,
          fallback: 'Не удалось загрузить пользователей'));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const <AppUser>[];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(AppUser.fromJson)
        .toList(growable: false);
  }

  Future<AppUser> createUser({
    required String fio,
    required String email,
    required String password,
    required String role,
  }) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/users'),
      headers: headers,
      body: jsonEncode(<String, dynamic>{
        'fio': fio,
        'email': email,
        'password': password,
        'role': role,
      }),
    );

    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 201) {
      throw Exception(_extractError(response.body,
          fallback: 'Не удалось создать пользователя'));
    }

    return AppUser.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteUser(String userId) async {
    final headers = await _authHeaders();
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/users/$userId'),
      headers: headers,
    );

    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_extractError(response.body,
          fallback: 'Не удалось удалить пользователя'));
    }
  }

  Future<List<SupportMessage>> fetchSupportMessages(
      {String? clientUserId}) async {
    final headers = await _authHeaders();
    final query = <String, String>{};
    if (clientUserId != null && clientUserId.isNotEmpty) {
      query['clientUserId'] = clientUserId;
    }
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/support/messages')
        .replace(queryParameters: query.isEmpty ? null : query);

    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body,
          fallback: 'Не удалось загрузить сообщения'));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const <SupportMessage>[];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(SupportMessage.fromJson)
        .toList(growable: false);
  }

  Future<SupportMessage> sendSupportMessage({
    required String messageText,
    String? clientUserId,
  }) async {
    final headers = await _authHeaders();
    final body = <String, dynamic>{
      'messageText': messageText,
    };
    if (clientUserId != null && clientUserId.isNotEmpty) {
      body['clientUserId'] = clientUserId;
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/support/messages'),
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 201) {
      throw Exception(_extractError(response.body,
          fallback: 'Не удалось отправить сообщение'));
    }

    return SupportMessage.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> markSupportChatRead(String clientUserId) async {
    final headers = await _authHeaders();
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/api/support/chats/$clientUserId/read'),
      headers: headers,
    );

    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_extractError(response.body,
          fallback: 'Не удалось отметить чат как прочитанный'));
    }
  }

  Future<void> deleteSupportChat(String clientUserId) async {
    final headers = await _authHeaders();
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/support/chats/$clientUserId'),
      headers: headers,
    );

    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(
          _extractError(response.body, fallback: 'Не удалось удалить чат'));
    }
  }

  String _extractError(String body, {required String fallback}) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is String && error.isNotEmpty) return error;
      }
    } catch (_) {}
    return fallback;
  }

  MediaType _guessMediaType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg'))
      return MediaType('image', 'jpeg');
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    if (lower.endsWith('.gif')) return MediaType('image', 'gif');
    if (lower.endsWith('.pdf')) return MediaType('application', 'pdf');
    if (lower.endsWith('.docx')) {
      return MediaType('application',
          'vnd.openxmlformats-officedocument.wordprocessingml.document');
    }
    if (lower.endsWith('.doc')) return MediaType('application', 'msword');
    return MediaType('application', 'octet-stream');
  }
}

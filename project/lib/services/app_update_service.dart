import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdateInfo {
  AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    required this.releasePageUrl,
    required this.tagName,
    required this.hasUpdate,
  });

  final String currentVersion;
  final String latestVersion;
  final String downloadUrl;
  final String releasePageUrl;
  final String tagName;
  final bool hasUpdate;
}

class AppUpdateService {
  AppUpdateService({
    this.owner = 'ReunionRS',
    this.repo = 'flutter-crm',
  });

  final String owner;
  final String repo;

  Future<AppUpdateInfo> checkForUpdate() async {
    final package = await PackageInfo.fromPlatform();
    final currentVersion = _normalizeVersion(package.version);

    final latestUri =
        Uri.parse('https://api.github.com/repos/$owner/$repo/releases/latest');
    final response = await http.get(latestUri, headers: const {
      'Accept': 'application/vnd.github+json',
      'User-Agent': 'martstroy-flutter-client',
    });

    if (response.statusCode == 404) {
      return _checkByTags(currentVersion);
    }
    if (response.statusCode != 200) {
      throw Exception(
          'Не удалось проверить обновления (HTTP ${response.statusCode})');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final tagName = (json['tag_name'] ?? '').toString().trim();
    final releasePageUrl = (json['html_url'] ?? '').toString().trim();
    final latestVersion = _normalizeVersion(tagName.isNotEmpty
        ? tagName
        : (json['name'] ?? '').toString().trim());

    final assets = (json['assets'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);

    String downloadUrl = releasePageUrl;
    for (final asset in assets) {
      final name = (asset['name'] ?? '').toString().toLowerCase();
      final url = (asset['browser_download_url'] ?? '').toString();
      if (name.endsWith('.apk') && url.isNotEmpty) {
        downloadUrl = url;
        break;
      }
    }

    final hasUpdate = _compareSemVer(latestVersion, currentVersion) > 0;
    return AppUpdateInfo(
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      downloadUrl: downloadUrl,
      releasePageUrl: releasePageUrl,
      tagName: tagName,
      hasUpdate: hasUpdate,
    );
  }

  Future<AppUpdateInfo> _checkByTags(String currentVersion) async {
    final tagsUri = Uri.parse('https://api.github.com/repos/$owner/$repo/tags');
    final response = await http.get(tagsUri, headers: const {
      'Accept': 'application/vnd.github+json',
      'User-Agent': 'martstroy-flutter-client',
    });
    if (response.statusCode != 200) {
      throw Exception(
          'Не удалось проверить обновления (HTTP ${response.statusCode})');
    }

    final items = (jsonDecode(response.body) as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    if (items.isEmpty) {
      throw Exception('Релизы или теги не найдены в GitHub репозитории');
    }

    final tagName = (items.first['name'] ?? '').toString().trim();
    final latestVersion = _normalizeVersion(tagName);
    final pageUrl = 'https://github.com/$owner/$repo/releases';
    final hasUpdate = _compareSemVer(latestVersion, currentVersion) > 0;

    return AppUpdateInfo(
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      downloadUrl: pageUrl,
      releasePageUrl: pageUrl,
      tagName: tagName,
      hasUpdate: hasUpdate,
    );
  }

  String _normalizeVersion(String value) {
    var v = value.trim();
    if (v.startsWith('v') || v.startsWith('V')) {
      v = v.substring(1);
    }
    final m = RegExp(r'(\d+)\.(\d+)\.(\d+)').firstMatch(v);
    if (m == null) return '0.0.0';
    return '${m.group(1)}.${m.group(2)}.${m.group(3)}';
  }

  int _compareSemVer(String a, String b) {
    final av = a.split('.').map(int.tryParse).toList(growable: false);
    final bv = b.split('.').map(int.tryParse).toList(growable: false);
    for (var i = 0; i < 3; i++) {
      final ai = (i < av.length ? av[i] : null) ?? 0;
      final bi = (i < bv.length ? bv[i] : null) ?? 0;
      if (ai > bi) return 1;
      if (ai < bi) return -1;
    }
    return 0;
  }
}

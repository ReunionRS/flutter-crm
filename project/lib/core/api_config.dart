import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _prodBaseUrl = 'https://martstroyizhevskcrm.ru';

  static String _normalized(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;

  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (fromEnv.isNotEmpty) return _normalized(fromEnv);

    if (kReleaseMode) return _prodBaseUrl;

    if (kIsWeb) return Uri.base.origin;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:4000';
      default:
        return 'http://localhost:4000';
    }
  }
}

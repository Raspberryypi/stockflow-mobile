import 'package:flutter/foundation.dart' show kIsWeb;

class AppConfig {
  AppConfig._();

  static const String _envApiUrl = String.fromEnvironment('API_URL');

  static String get apiUrl {
    if (_envApiUrl.isNotEmpty) return _envApiUrl;
    return kIsWeb ? 'http://localhost:5000/api' : 'http://10.0.2.2:5000/api';
  }

  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue:
        '541056263803-o2paqm4doqch53iidsp19g869s9esfhh.apps.googleusercontent.com',
  );

  static const String brandName = 'StockFlow';
  static const String tagline = 'Inventory Management';

  static const bool showSocialLogin = true;
  static const bool requireTerms = true;
}

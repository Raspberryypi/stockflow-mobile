import 'package:flutter/foundation.dart' show kIsWeb;

/// Build-time configuration. Override with --dart-define, e.g.
///   flutter run --dart-define=API_URL=http://192.168.1.10:5000/api
class AppConfig {
  AppConfig._();

  static const String _envApiUrl = String.fromEnvironment('API_URL');

  /// Resolution order:
  ///  1. --dart-define=API_URL=...  (always wins)
  ///  2. Browser (Edge/Chrome): http://localhost:5000/api
  ///  3. Android emulator reaches your PC's localhost through 10.0.2.2.
  /// A real phone needs your PC's LAN IP (same Wi-Fi) or your deployed URL.
  static String get apiUrl {
    if (_envApiUrl.isNotEmpty) return _envApiUrl;
    return kIsWeb ? 'http://localhost:5000/api' : 'http://10.0.2.2:5000/api';
  }

  /// Same value as VITE_GOOGLE_CLIENT_ID / GOOGLE_CLIENT_ID on the server.
  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue:
        '541056263803-o2paqm4doqch53iidsp19g869s9esfhh.apps.googleusercontent.com',
  );

  static const String brandName = 'StockFlow';
  static const String tagline = 'Inventory Management';

  // Mirrors src/config/authConfig.js
  static const bool showSocialLogin = true;
  static const bool requireTerms = true;
}

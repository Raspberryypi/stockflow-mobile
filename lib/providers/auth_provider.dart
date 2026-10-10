import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/network/api_client.dart';
import '../core/storage/token_storage.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';

/// Port of AuthContext.jsx.
class AuthProvider extends ChangeNotifier {
  AuthProvider() {
    // Global 401 handling (the axios response interceptor on the web).
    ApiClient.instance.onUnauthorized = _handleUnauthorized;
  }

  AppUser? _user;
  bool _loading = true;

  AppUser? get user => _user;
  bool get loading => _loading;
  bool get isAuthenticated => _user != null;

  /// On launch, if a token exists, verify it against the backend and
  /// restore the session instead of trusting stale stored data.
  Future<void> bootstrap() async {
    final token = await TokenStorage.getToken();
    if (token == null || token.isEmpty) {
      _loading = false;
      notifyListeners();
      return;
    }
    try {
      final res = await AuthService.getCurrentUser();
      _user = AppUser(Map<String, dynamic>.from(res['data'] as Map));
    } catch (_) {
      await TokenStorage.clear();
      _user = null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _handleUnauthorized() {
    if (_user == null) return;
    TokenStorage.clear();
    _user = null;
    notifyListeners();
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await AuthService.login(email, password);
    await _startSession(res);
    return res;
  }

  Future<Map<String, dynamic>> loginWithGoogle(String accessToken) async {
    final res = await AuthService.googleLogin(accessToken);
    await _startSession(res);
    return res;
  }

  Future<void> _startSession(Map<String, dynamic> res) async {
    final data = Map<String, dynamic>.from(res['data'] as Map);
    await TokenStorage.save(res['token'] as String, data);
    _user = AppUser(data);
    notifyListeners();
  }

  /// Merge changes (e.g. a new avatar) into the logged-in user so the whole
  /// app updates immediately.
  void updateCurrentUser(Map<String, dynamic> changes) {
    if (_user == null) return;
    _user = _user!.merge(changes);
    TokenStorage.saveUser(_user!.raw);
    notifyListeners();
  }

  Future<Map<String, dynamic>> register(String name, String email, String password, String confirmPassword) =>
      AuthService.register(name, email, password, confirmPassword);

  Future<Map<String, dynamic>> verifyRegistrationOtp(String email, String otp) =>
      AuthService.verifyOtp(email, otp);

  Future<Map<String, dynamic>> resendRegistrationOtp(String email) =>
      AuthService.resendOtp(email);

  Future<Map<String, dynamic>> forgotPassword(String email) =>
      AuthService.forgotPassword(email);

  Future<Map<String, dynamic>> resetPassword(String email, String otp, String newPassword, String confirmNewPassword) =>
      AuthService.resetPassword(email, otp, newPassword, confirmNewPassword);

  Future<void> logout() async {
    try {
      await AuthService.logout();
    } catch (_) {
      // Even if the server call fails we still sign out locally.
    } finally {
      try {
        if (!kIsWeb) await GoogleSignIn().signOut();
      } catch (_) {}
      await TokenStorage.clear();
      _user = null;
      notifyListeners();
    }
  }
}

import '../core/network/api_client.dart';

class AuthService {
  AuthService._();
  static final _api = ApiClient.instance;

  // Step 1: validates the form and emails a 6-digit code (no account yet).
  static Future<Map<String, dynamic>> register(
          String name, String email, String password, String confirmPassword) =>
      _api.post('/auth/register', {
        'name': name,
        'email': email,
        'password': password,
        'confirmPassword': confirmPassword,
      });

  static Future<Map<String, dynamic>> verifyOtp(String email, String otp) =>
      _api.post('/auth/verify-otp', {'email': email, 'otp': otp});

  static Future<Map<String, dynamic>> resendOtp(String email) =>
      _api.post('/auth/resend-otp', {'email': email});

  static Future<Map<String, dynamic>> forgotPassword(String email) =>
      _api.post('/auth/forgot-password', {'email': email});

  static Future<Map<String, dynamic>> resetPassword(String email, String otp,
          String newPassword, String confirmNewPassword) =>
      _api.post('/auth/reset-password', {
        'email': email,
        'otp': otp,
        'newPassword': newPassword,
        'confirmNewPassword': confirmNewPassword,
      });

  static Future<Map<String, dynamic>> requestEmailChange(String newEmail) =>
      _api.post('/auth/email-change/request', {'newEmail': newEmail});

  static Future<Map<String, dynamic>> confirmEmailChange(
          String currentOtp, String newOtp) =>
      _api.post('/auth/email-change/confirm',
          {'currentOtp': currentOtp, 'newOtp': newOtp});

  static Future<Map<String, dynamic>> login(String email, String password) =>
      _api.post('/auth/login', {'email': email, 'password': password});

  static Future<Map<String, dynamic>> googleLogin(String accessToken) =>
      _api.post('/auth/google', {'accessToken': accessToken});

  static Future<Map<String, dynamic>> logout() => _api.post('/auth/logout');

  static Future<Map<String, dynamic>> getCurrentUser() => _api.get('/auth/me');

  static Future<Map<String, dynamic>> getAvatarUploadSignature() =>
      _api.post('/auth/avatar/signature');

  static Future<Map<String, dynamic>> updateAvatar(String avatar) =>
      _api.put('/auth/avatar', {'avatar': avatar});

  static Future<Map<String, dynamic>> removeAvatar() => _api.delete('/auth/avatar');

  static Future<Map<String, dynamic>> changePassword(String currentPassword,
          String newPassword, String confirmNewPassword) =>
      _api.put('/auth/change-password', {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
        'confirmNewPassword': confirmNewPassword,
      });
}

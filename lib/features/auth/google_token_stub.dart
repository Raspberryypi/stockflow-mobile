// Non-web stub. On Android/iOS the google_sign_in plugin is used instead,
// so these are never called there.

/// Thrown when the user closes the Google popup (a cancel, not an error).
class GoogleCancelled implements Exception {
  const GoogleCancelled();
}

Future<void> loadGoogleScript() async {}

Future<String> requestGoogleAccessToken(String clientId) async =>
    throw UnsupportedError('Browser Google sign-in is only available on web.');

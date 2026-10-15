class GoogleCancelled implements Exception {
  const GoogleCancelled();
}

Future<void> loadGoogleScript() async {}

Future<String> requestGoogleAccessToken(String clientId) async =>
    throw UnsupportedError('Browser Google sign-in is only available on web.');

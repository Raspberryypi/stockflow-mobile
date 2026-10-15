// ignore_for_file: non_constant_identifier_names
import 'dart:async';
import 'dart:js_interop';

class GoogleCancelled implements Exception {
  const GoogleCancelled();
}

const _gsiSrc = 'https://accounts.google.com/gsi/client';

extension type _Element._(JSObject _) implements JSObject {
  external set src(String value);
  @JS('async')
  external set asyncLoad(bool value);
  external void appendChild(_Element child);
  external void addEventListener(String type, JSFunction listener);
}

extension type _Document._(JSObject _) implements JSObject {
  external _Element createElement(String tag);
  external _Element get head;
}

@JS('document')
external _Document get _document;

extension type _TokenResponse._(JSObject _) implements JSObject {
  external String? get access_token;
  external String? get error;
  external String? get error_description;
}

extension type _TokenError._(JSObject _) implements JSObject {
  external String? get type;
}

extension type _TokenClientConfig._(JSObject _) implements JSObject {
  external factory _TokenClientConfig({
    required String client_id,
    required String scope,
    required JSFunction callback,
    required JSFunction error_callback,
  });
}

extension type _TokenClient._(JSObject _) implements JSObject {
  external void requestAccessToken();
}

@JS('google.accounts.oauth2.initTokenClient')
external _TokenClient _initTokenClient(_TokenClientConfig config);

Completer<void>? _loading;

Future<void> loadGoogleScript() {
  final existing = _loading;
  if (existing != null) return existing.future;

  final completer = Completer<void>();
  _loading = completer;

  final script = _document.createElement('script');
  script.src = _gsiSrc;
  script.asyncLoad = true;
  script.addEventListener(
    'load',
    ((JSAny? _) {
      if (!completer.isCompleted) completer.complete();
    }).toJS,
  );
  script.addEventListener(
    'error',
    ((JSAny? _) {
      _loading = null;
      if (!completer.isCompleted) {
        completer.completeError(Exception('Could not load Google sign-in.'));
      }
    }).toJS,
  );
  _document.head.appendChild(script);
  return completer.future;
}

Future<String> requestGoogleAccessToken(String clientId) async {
  await loadGoogleScript();

  final result = Completer<String>();

  final config = _TokenClientConfig(
    client_id: clientId,
    scope: 'openid email profile',
    callback: ((_TokenResponse r) {
      if (result.isCompleted) return;
      final token = r.access_token;
      if (r.error != null || token == null || token.isEmpty) {
        result.completeError(
            Exception(r.error_description ?? 'Google sign-in failed.'));
      } else {
        result.complete(token);
      }
    }).toJS,
    error_callback: ((_TokenError e) {
      if (result.isCompleted) return;
      if (e.type == 'popup_failed_to_open') {
        result.completeError(
            Exception('Your browser blocked the Google sign-in popup.'));
      } else {
        result.completeError(const GoogleCancelled());
      }
    }).toJS,
  );

  final _TokenClient client;
  try {
    client = _initTokenClient(config);
  } catch (_) {
    throw Exception('Google sign-in is still loading. Please try again.');
  }
  client.requestAccessToken();
  return result.future;
}

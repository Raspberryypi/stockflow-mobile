// Chooses the implementation at compile time:
//  - browser (Edge/Chrome): google_token_web.dart  (Google Identity Services)
//  - Android / iOS:         google_token_stub.dart (not used; the
//                            google_sign_in plugin handles mobile)
export 'google_token_stub.dart'
    if (dart.library.js_interop) 'google_token_web.dart';

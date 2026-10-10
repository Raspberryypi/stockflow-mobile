import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/palette.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_alert.dart';
import 'google_token.dart';

const _googleSvg = '''
<svg width="20" height="20" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
<path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
<path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
<path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>
<path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
</svg>
''';

/// "Or" divider + "Continue with Google" (SocialLogin.jsx).
class SocialLogin extends StatefulWidget {
  const SocialLogin({super.key});

  @override
  State<SocialLogin> createState() => _SocialLoginState();
}

class _SocialLoginState extends State<SocialLogin> {
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Web only: preload Google's script so the popup can open straight from
    // the click (browsers block popups that are opened after a delay).
    if (kIsWeb) {
      loadGoogleScript().catchError((_) {});
    }
  }

  Future<void> _handleGoogle() async {
    setState(() => _error = null);
    final auth = context.read<AuthProvider>();
    final router = GoRouter.of(context);
    setState(() => _busy = true);
    try {
      if (kIsWeb) {
        // Browser: Google Identity Services popup (same as the website).
        final accessToken = await requestGoogleAccessToken(AppConfig.googleClientId);
        await auth.loginWithGoogle(accessToken);
        router.go('/dashboard');
        return;
      }
      // serverClientId = the *web* client id; this is what lets the server
      // verify the token the same way it does for the website.
      final google = GoogleSignIn(
        scopes: const ['email', 'profile'],
        serverClientId: AppConfig.googleClientId,
      );
      final account = await google.signIn();
      if (account == null) return; // user closed the picker = cancel, not an error
      final tokens = await account.authentication;
      final accessToken = tokens.accessToken;
      if (accessToken == null) throw Exception('Google did not return an access token.');
      await auth.loginWithGoogle(accessToken);
      router.go('/dashboard');
    } on GoogleCancelled {
      return; // popup closed = cancel, not an error
    } on PlatformException catch (e) {
      if (e.code == 'sign_in_canceled') return;
      if (mounted) setState(() => _error = 'Google sign-in failed (${e.code}). Check the Google setup.');
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e, 'Google sign-in failed. Please try again.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.showSocialLogin) return const SizedBox.shrink();
    final p = AppPalette.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            children: [
              Expanded(child: Divider(color: p.divider)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('Or', style: TextStyle(fontSize: 12, color: p.textSecondary)),
              ),
              Expanded(child: Divider(color: p.divider)),
            ],
          ),
        ),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _handleGoogle,
            style: OutlinedButton.styleFrom(
              backgroundColor: p.paper,
              foregroundColor: p.textPrimary,
              side: BorderSide(color: p.authInputBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : SvgPicture.string(_googleSvg, width: 20, height: 20),
            label: const Text('Continue with Google'),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: AppAlert(_error!, onClose: () => setState(() => _error = null)),
          ),
      ],
    );
  }
}

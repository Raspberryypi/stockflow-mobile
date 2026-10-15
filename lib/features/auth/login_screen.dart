import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/palette.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_alert.dart';
import 'auth_button.dart';
import 'auth_field.dart';
import 'auth_layout.dart';
import 'social_login.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.verified = false, this.passwordReset = false, this.email});

  final bool verified;
  final bool passwordReset;
  final String? email;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final _email = TextEditingController(text: widget.email ?? '');
  final _password = TextEditingController();
  String _error = '';
  bool _submitting = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _error = '';
      _submitting = true;
    });
    final auth = context.read<AuthProvider>();
    try {
      await auth.login(_email.text, _password.text);
      if (mounted) context.go('/dashboard');
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e, 'Login failed. Please try again.'));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AuthLayout(
      title: 'Log in to your account',
      subtitle: 'Welcome back — enter your details to continue.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.verified && _error.isEmpty)
            const AppAlert('Email verified! Your account is ready — log in to continue.',
                severity: AlertSeverity.success),
          if (widget.passwordReset && _error.isEmpty)
            const AppAlert('Password reset successful — log in with your new password.',
                severity: AlertSeverity.success),
          if (_error.isNotEmpty) AppAlert(_error),
          AuthField(
            label: 'Email',
            hint: 'Enter your email',
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
          ),
          AuthField(
            label: 'Password',
            hint: 'Enter your password',
            controller: _password,
            isPassword: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _submitting ? null : _submit(),
            bottomSpacing: 8,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: AuthLink('Forgot password?', fontSize: 13, onTap: () => context.push('/forgot-password')),
          ),
          const SizedBox(height: 12),
          AuthButton(label: _submitting ? 'Signing in…' : 'Log in', onPressed: _submitting ? null : _submit),
          const SocialLogin(),
          const SizedBox(height: 24),
          Center(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text("Don't have an account? ", style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
                AuthLink('Register', onTap: () => context.push('/register')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/password_strength.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_alert.dart';
import 'auth_button.dart';
import 'auth_field.dart';
import 'auth_layout.dart';
import 'otp_verification.dart';
import 'password_strength_meter.dart';

final _emailRegex = RegExp(r'^\S+@\S+\.\S+$');

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _resetStep = false;
  String _email = '';
  int _resendCooldown = 60;
  String _error = '';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_newPassword, _confirmPassword]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  bool get _mismatch =>
      _confirmPassword.text.isNotEmpty && _newPassword.text != _confirmPassword.text;

  bool get _passwordsValid =>
      evaluatePassword(_newPassword.text).isValid && _newPassword.text == _confirmPassword.text;

  Future<void> _sendCode() async {
    FocusScope.of(context).unfocus();
    final trimmed = _emailCtrl.text.trim().toLowerCase();
    if (!_emailRegex.hasMatch(trimmed)) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    setState(() {
      _error = '';
      _submitting = true;
    });
    final auth = context.read<AuthProvider>();
    try {
      final res = await auth.forgotPassword(trimmed);
      final data = res['data'] is Map ? res['data'] as Map : const {};
      if (!mounted) return;
      setState(() {
        _email = trimmed;
        _resendCooldown = (data['resendAfterSeconds'] as num?)?.toInt() ?? 60;
        _resetStep = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _reset(String otp) async {
    await context
        .read<AuthProvider>()
        .resetPassword(_email, otp, _newPassword.text, _confirmPassword.text);
    if (mounted) context.go('/login', extra: {'passwordReset': true, 'email': _email});
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    if (_resetStep) {
      final auth = context.read<AuthProvider>();
      return AuthLayout(
        title: 'Reset your password',
        child: OtpVerification(
          email: _email,
          initialCooldown: _resendCooldown,
          submitLabel: 'Reset password',
          submitDisabled: !_passwordsValid,
          onVerify: _reset,
          onResend: () => auth.forgotPassword(_email),
          onBack: () => setState(() {
            _resetStep = false;
            _error = '';
          }),
          children: [
            AuthField(
              label: 'New password',
              hint: 'Enter a new password',
              controller: _newPassword,
              isPassword: true,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
            ),
            PasswordStrengthMeter(password: _newPassword.text),
            AuthField(
              label: 'Confirm new password',
              hint: 'Re-enter your new password',
              controller: _confirmPassword,
              isPassword: true,
              errorText: _mismatch ? 'Passwords do not match' : null,
            ),
          ],
        ),
      );
    }

    return AuthLayout(
      title: 'Forgot your password?',
      subtitle: "Enter your email and we'll send you a 6-digit code to reset it.",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error.isNotEmpty) AppAlert(_error),
          AuthField(
            label: 'Email',
            hint: 'Enter your email',
            controller: _emailCtrl,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            onSubmitted: (_) => _submitting ? null : _sendCode(),
          ),
          const SizedBox(height: 4),
          AuthButton(
            label: _submitting ? 'Sending code…' : 'Send reset code',
            onPressed: _submitting ? null : _sendCode,
          ),
          const SizedBox(height: 24),
          Center(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Remembered it? ', style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
                AuthLink('Back to log in', onTap: () => context.go('/login')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

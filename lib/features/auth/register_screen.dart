import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/config/app_config.dart';
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
import 'social_login.dart';
import 'terms_dialog.dart';

final _nameDisallowed = RegExp(r"[^\p{L}\p{M}\s.'’-]", unicode: true);
final _nameValid = RegExp(r"^[\p{L}\p{M}][\p{L}\p{M}\s.'’-]*$", unicode: true);

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _otpStep = false;
  String _pendingEmail = '';
  int _resendCooldown = 60;
  bool _agreed = false;
  bool _termsOpened = false;
  String _error = '';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_password, _confirm]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _mismatch => _confirm.text.isNotEmpty && _password.text != _confirm.text;

  String _validate() {
    if (_name.text.isEmpty || _email.text.isEmpty || _password.text.isEmpty || _confirm.text.isEmpty) {
      return 'All fields are required.';
    }
    if (!_nameValid.hasMatch(_name.text.trim())) {
      return 'Name can only contain letters, spaces, apostrophes, periods and hyphens.';
    }
    if (!evaluatePassword(_password.text).isValid) {
      return 'Password does not meet all the requirements below.';
    }
    if (_password.text != _confirm.text) return 'Passwords do not match.';
    if (AppConfig.requireTerms && !_termsOpened) {
      return 'Please open and read the Terms & Conditions first.';
    }
    if (AppConfig.requireTerms && !_agreed) return 'Please agree to the Terms & Conditions.';
    return '';
  }

  Future<void> _openTerms() async {
    setState(() => _termsOpened = true);
    final agreed = await showTermsDialog(context);
    if (agreed && mounted) {
      setState(() {
        _agreed = true;
        _error = '';
      });
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final problem = _validate();
    if (problem.isNotEmpty) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _error = '';
      _submitting = true;
    });
    final auth = context.read<AuthProvider>();
    try {
      final res = await auth.register(_name.text, _email.text, _password.text, _confirm.text);
      final data = res['data'] is Map ? res['data'] as Map : const {};
      if (!mounted) return;
      setState(() {
        _pendingEmail = (data['email'] as String?) ?? _email.text.trim().toLowerCase();
        _resendCooldown = (data['resendAfterSeconds'] as num?)?.toInt() ?? 60;
        _otpStep = true;
      });
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e, 'Registration failed. Please try again.'));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _verify(String otp) async {
    await context.read<AuthProvider>().verifyRegistrationOtp(_pendingEmail, otp);
    if (mounted) {
      context.go('/login', extra: {'verified': true, 'email': _pendingEmail});
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    if (_otpStep) {
      final auth = context.read<AuthProvider>();
      return AuthLayout(
        title: 'Verify your email',
        child: OtpVerification(
          email: _pendingEmail,
          initialCooldown: _resendCooldown,
          onVerify: _verify,
          onResend: () => auth.resendRegistrationOtp(_pendingEmail),
          onBack: () => setState(() {
            _otpStep = false;
            _error = '';
          }),
        ),
      );
    }

    return AuthLayout(
      title: 'Create an account',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error.isNotEmpty) AppAlert(_error),
          AuthField(
            label: 'Name',
            hint: 'Enter your name',
            controller: _name,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            inputFormatters: [FilteringTextInputFormatter.deny(_nameDisallowed)],
          ),
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
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
          ),
          PasswordStrengthMeter(password: _password.text),
          AuthField(
            label: 'Confirm password',
            hint: 'Re-enter your password',
            controller: _confirm,
            isPassword: true,
            textInputAction: TextInputAction.done,
            errorText: _mismatch ? 'Passwords do not match' : null,
          ),
          if (AppConfig.requireTerms) ...[
            Row(
              children: [
                Checkbox(
                  value: _agreed,
                  activeColor: p.authAccent,
                  side: BorderSide(color: p.authInputBorder, width: 1.5),
                  onChanged: _termsOpened ? (v) => setState(() => _agreed = v ?? false) : null,
                ),
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('I agree to all the ', style: TextStyle(fontSize: 13.5, color: p.textPrimary)),
                      GestureDetector(
                        onTap: _openTerms,
                        child: Text(
                          'Terms & Conditions',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: p.authLink,
                            decoration: TextDecoration.underline,
                            decorationColor: p.authLink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!_termsOpened)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text('Open the Terms & Conditions to enable this checkbox.',
                    style: TextStyle(fontSize: 12, color: p.textSecondary)),
              ),
            const SizedBox(height: 12),
          ],
          AuthButton(label: _submitting ? 'Sending code…' : 'Sign up', onPressed: _submitting ? null : _submit),
          const SocialLogin(),
          const SizedBox(height: 24),
          Center(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Already have an account? ', style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
                AuthLink('Log in', onTap: () => context.go('/login')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

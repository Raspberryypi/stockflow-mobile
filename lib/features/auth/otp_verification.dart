import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/palette.dart';
import '../../widgets/app_alert.dart';
import 'auth_button.dart';

const _otpLength = 6;

/// Second step of sign-up / reset: type the 6-digit code that was emailed.
/// Port of OtpVerification.jsx.
class OtpVerification extends StatefulWidget {
  const OtpVerification({
    super.key,
    required this.email,
    required this.onVerify,
    required this.onResend,
    required this.onBack,
    this.children = const [],
    this.submitLabel = 'Verify & create account',
    this.submitDisabled = false,
    this.initialCooldown = 60,
  });

  final String email;

  /// Should throw (DioException) on a wrong code.
  final Future<void> Function(String otp) onVerify;

  /// Resolves with the server response ({data: {resendAfterSeconds}}).
  final Future<Map<String, dynamic>> Function() onResend;
  final VoidCallback onBack;

  /// Extra fields rendered under the code box (reset-password puts the
  /// new-password fields here).
  final List<Widget> children;
  final String submitLabel;
  final bool submitDisabled;
  final int initialCooldown;

  @override
  State<OtpVerification> createState() => _OtpVerificationState();
}

class _OtpVerificationState extends State<OtpVerification> {
  final _controller = TextEditingController();
  Timer? _timer;
  String _error = '';
  String _info = '';
  bool _submitting = false;
  bool _resending = false;
  late int _cooldown = widget.initialCooldown;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_cooldown <= 0) {
        t.cancel();
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final otp = _controller.text;
    if (otp.length != _otpLength) {
      setState(() => _error = 'Enter the $_otpLength-digit code.');
      return;
    }
    setState(() {
      _error = '';
      _info = '';
      _submitting = true;
    });
    try {
      await widget.onVerify(otp);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = apiErrorMessage(e, 'Verification failed. Please try again.');
          _submitting = false;
        });
      }
    }
  }

  Future<void> _resend() async {
    setState(() {
      _error = '';
      _info = '';
      _resending = true;
    });
    try {
      final res = await widget.onResend();
      final after = (res['data'] is Map ? (res['data'] as Map)['resendAfterSeconds'] : null) as num?;
      if (!mounted) return;
      setState(() {
        _controller.clear();
        _cooldown = after?.toInt() ?? 60;
        _info = 'A new code has been sent to your email.';
      });
      _startTimer();
    } catch (e) {
      final retry = apiErrorData(e)?['retryAfter'];
      if (!mounted) return;
      setState(() {
        if (retry is num) _cooldown = retry.toInt();
        _error = apiErrorMessage(e, 'Could not resend the code. Please try again.');
      });
      _startTimer();
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Text.rich(TextSpan(
            style: TextStyle(fontSize: 14, color: p.textSecondary, height: 1.4),
            children: [
              const TextSpan(text: 'We sent a 6-digit code to '),
              TextSpan(
                text: widget.email,
                style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary),
              ),
              const TextSpan(text: '. It expires in 10 minutes.'),
            ],
          )),
        ),
        if (_error.isNotEmpty) AppAlert(_error),
        if (_info.isNotEmpty) AppAlert(_info, severity: AlertSeverity.success),
        Text('Verification code',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: p.textPrimary)),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          autofocus: true,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(_otpLength),
          ],
          style: const TextStyle(letterSpacing: 8, fontSize: 22, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: '000000',
            counterText: '',
            filled: true,
            fillColor: p.authInputBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            enabledBorder: border(p.authInputBorder),
            border: border(p.authInputBorder),
            focusedBorder: border(p.authAccent),
          ),
        ),
        const SizedBox(height: 24),
        ...widget.children,
        AuthButton(
          label: _submitting ? 'Verifying…' : widget.submitLabel,
          onPressed: (_submitting || _controller.text.length != _otpLength || widget.submitDisabled)
              ? null
              : _submit,
        ),
        const SizedBox(height: 24),
        Center(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text("Didn't get it? ", style: TextStyle(fontSize: 13, color: p.textSecondary)),
              if (_cooldown > 0)
                Text('Resend in ${_cooldown}s', style: TextStyle(fontSize: 13, color: p.textSecondary))
              else
                AuthLink(_resending ? 'Sending…' : 'Resend code',
                    fontSize: 13, onTap: _resending ? null : _resend),
            ],
          ),
        ),
        Center(child: AuthLink('Use a different email', onTap: widget.onBack)),
      ],
    );
  }
}

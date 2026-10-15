import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/palette.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_alert.dart';

const _otpLength = 6;

/// Port of components/users/ChangeEmailDialog.jsx: asks for the two codes
/// needed to change the account email, one sent to the CURRENT address and
/// one to the NEW address. Pops with the confirmed email, or null.
Future<String?> showChangeEmailDialog(
  BuildContext context, {
  required String newEmail,
  required String currentEmailMasked,
  int initialCooldown = 60,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ChangeEmailDialog(
      newEmail: newEmail,
      currentEmailMasked: currentEmailMasked,
      initialCooldown: initialCooldown,
    ),
  );
}

class _ChangeEmailDialog extends StatefulWidget {
  const _ChangeEmailDialog({
    required this.newEmail,
    required this.currentEmailMasked,
    required this.initialCooldown,
  });
  final String newEmail;
  final String currentEmailMasked;
  final int initialCooldown;

  @override
  State<_ChangeEmailDialog> createState() => _ChangeEmailDialogState();
}

class _ChangeEmailDialogState extends State<_ChangeEmailDialog> {
  final _currentOtp = TextEditingController();
  final _newOtp = TextEditingController();
  String _error = '';
  String _info = '';
  bool _submitting = false;
  bool _resending = false;
  late int _cooldown = widget.initialCooldown;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _currentOtp.dispose();
    _newOtp.dispose();
    super.dispose();
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

  bool get _canSubmit =>
      _currentOtp.text.length == _otpLength && _newOtp.text.length == _otpLength && !_submitting;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _error = '';
      _info = '';
      _submitting = true;
    });
    try {
      final res = await AuthService.confirmEmailChange(_currentOtp.text, _newOtp.text);
      final data = res['data'] is Map ? res['data'] as Map : const {};
      if (mounted) Navigator.of(context).pop('${data['email'] ?? widget.newEmail}');
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
      final res = await AuthService.requestEmailChange(widget.newEmail);
      final data = res['data'] is Map ? res['data'] as Map : const {};
      if (!mounted) return;
      _currentOtp.clear();
      _newOtp.clear();
      setState(() {
        _cooldown = (data['resendAfterSeconds'] as num?)?.toInt() ?? 60;
        _info = 'New codes have been sent to both addresses.';
      });
      _startTimer();
    } catch (e) {
      if (!mounted) return;
      final retry = apiErrorData(e)?['retryAfter'];
      setState(() {
        if (retry is num) _cooldown = retry.toInt();
        _error = apiErrorMessage(e, 'Could not resend the codes. Please try again.');
      });
      _startTimer();
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Widget _codeField(String label, TextEditingController c, {bool autofocus = false}) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: TextField(
          controller: c,
          autofocus: autofocus,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(_otpLength),
          ],
          onChanged: (_) => setState(() {}),
          style: const TextStyle(letterSpacing: 6, fontWeight: FontWeight.w600),
          decoration: InputDecoration(labelText: label, hintText: '000000'),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final secondary = TextStyle(color: p.textSecondary, fontSize: 14);
    return AlertDialog(
      title: const Text('Verify email change', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(style: secondary, children: [
                const TextSpan(text: 'To protect your account we sent a 6-digit code to '),
                TextSpan(text: widget.currentEmailMasked, style: const TextStyle(fontWeight: FontWeight.w700)),
                const TextSpan(text: ' (your current email) and a different code to '),
                TextSpan(text: widget.newEmail, style: const TextStyle(fontWeight: FontWeight.w700)),
                const TextSpan(text: ' (your new email). Enter both to confirm. They expire in 10 minutes.'),
              ]),
            ),
            const SizedBox(height: 12),
            if (_error.isNotEmpty) AppAlert(_error),
            if (_info.isNotEmpty) AppAlert(_info, severity: AlertSeverity.success),
            _codeField('Code from your current email', _currentOtp, autofocus: true),
            _codeField('Code from your new email', _newOtp),
            const SizedBox(height: 14),
            Row(
              children: [
                Text("Didn't get them? ", style: secondary),
                if (_cooldown > 0)
                  Text('Resend in ${_cooldown}s', style: secondary)
                else
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: _resending ? null : _resend,
                    child: Text(_resending ? 'Sending…' : 'Resend codes',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canSubmit ? _submit : null,
          child: Text(_submitting ? 'Verifying…' : 'Confirm change'),
        ),
      ],
    );
  }
}

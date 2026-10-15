import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/palette.dart';

class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.isPassword = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.errorText,
    this.autofocus = false,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.bottomSpacing = 20,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool isPassword;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final String? errorText;
  final bool autofocus;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final double bottomSpacing;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c, width: w),
        );

    return Padding(
      padding: EdgeInsets.only(bottom: widget.bottomSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: p.textPrimary)),
          const SizedBox(height: 8),
          TextField(
            controller: widget.controller,
            obscureText: widget.isPassword && !_visible,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            autofillHints: widget.autofillHints,
            autofocus: widget.autofocus,
            inputFormatters: widget.inputFormatters,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            autocorrect: !widget.isPassword && widget.keyboardType != TextInputType.emailAddress,
            enableSuggestions: !widget.isPassword,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(fontSize: 14, color: p.textSecondary.withValues(alpha: 0.7)),
              errorText: widget.errorText,
              errorStyle: const TextStyle(fontSize: 12.5),
              filled: true,
              fillColor: p.authInputBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              enabledBorder: border(p.authInputBorder),
              border: border(p.authInputBorder),
              focusedBorder: border(p.authAccent),
              errorBorder: border(AppPalette.error),
              focusedErrorBorder: border(AppPalette.error),
              suffixIcon: widget.isPassword
                  ? IconButton(
                      tooltip: _visible ? 'Hide password' : 'Show password',
                      icon: Icon(
                        _visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 20,
                        color: p.textSecondary,
                      ),
                      onPressed: () => setState(() => _visible = !_visible),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

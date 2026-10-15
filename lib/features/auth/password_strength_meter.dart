import 'package:flutter/material.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/password_strength.dart';

class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.password});
  final String password;

  Color _barColor(int bars) => switch (bars) {
        1 => AppPalette.error,
        2 => AppPalette.warning,
        3 => const Color(0xFF81C784),
        4 => AppPalette.success,
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final eval = evaluatePassword(password);
    final active = eval.bars == 0 ? p.textSecondary : _barColor(eval.bars);

    Widget ruleTile(PasswordRule r) => Row(
          children: [
            r.met
                ? const Icon(Icons.check_rounded, size: 16, color: AppPalette.success)
                : Padding(
                    padding: const EdgeInsets.all(1),
                    child: Icon(Icons.radio_button_unchecked_rounded,
                        size: 14, color: p.textSecondary.withValues(alpha: 0.6)),
                  ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(r.label,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: r.met ? AppPalette.success : p.textSecondary,
                  )),
            ),
          ],
        );

    final half = (eval.rules.length / 2).ceil();
    final left = eval.rules.take(half).toList();
    final right = eval.rules.skip(half).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Password strength', style: TextStyle(fontSize: 13, color: p.textSecondary)),
              Text(eval.label,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: active)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 1; i <= 4; i++) ...[
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= eval.bars ? active : p.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (i < 4) const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(children: [
                  for (final r in left) Padding(padding: const EdgeInsets.only(bottom: 4), child: ruleTile(r)),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(children: [
                  for (final r in right) Padding(padding: const EdgeInsets.only(bottom: 4), child: ruleTile(r)),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

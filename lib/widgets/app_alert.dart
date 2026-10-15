import 'package:flutter/material.dart';
import '../core/theme/palette.dart';

enum AlertSeverity { error, success, info, warning }

class AppAlert extends StatelessWidget {
  const AppAlert(this.message, {super.key, this.severity = AlertSeverity.error, this.onClose});

  final String message;
  final AlertSeverity severity;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final (Color bg, Color accent, Color dark, IconData icon) = switch (severity) {
      AlertSeverity.error => (p.errorLight, AppPalette.error, AppPalette.errorDark, Icons.error_outline_rounded),
      AlertSeverity.success => (p.successLight, AppPalette.success, AppPalette.successDark, Icons.check_circle_outline_rounded),
      AlertSeverity.info => (p.infoLight, AppPalette.info, AppPalette.infoDark, Icons.info_outline_rounded),
      AlertSeverity.warning => (p.warningLight, AppPalette.warning, AppPalette.warningDark, Icons.warning_amber_rounded),
    };
    final textColor = p.dark ? p.textPrimary : dark;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(message, style: TextStyle(color: textColor, fontSize: 14, height: 1.35)),
            ),
          ),
          if (onClose != null)
            InkWell(
              onTap: onClose,
              child: Icon(Icons.close_rounded, size: 18, color: textColor),
            ),
        ],
      ),
    );
  }
}

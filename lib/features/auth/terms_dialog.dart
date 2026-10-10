import 'package:flutter/material.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/terms_content.dart';

/// Scrollable Terms & Conditions. Returns true if the user pressed "I agree".
Future<bool> showTermsDialog(BuildContext context) async {
  final agreed = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final p = AppPalette.of(ctx);
      return AlertDialog(
        title: const Text('Terms & Conditions',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Last updated: $termsLastUpdated',
                    style: TextStyle(fontSize: 12, color: p.textSecondary)),
                const SizedBox(height: 16),
                for (final s in termsSections)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.title,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(s.body,
                            style: TextStyle(fontSize: 13.5, height: 1.6, color: p.textSecondary)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(foregroundColor: p.textSecondary),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: p.authAccent),
            child: const Text('I agree'),
          ),
        ],
      );
    },
  );
  return agreed ?? false;
}

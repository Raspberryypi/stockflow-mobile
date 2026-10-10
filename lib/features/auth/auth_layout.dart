import 'package:flutter/material.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/palette.dart';

/// Phone version of AuthLayout.jsx. On the web the teal promo panel is
/// hidden below 768px, so the phone layout is just the form column.
class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(
      backgroundColor: p.paper,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppPalette.authPanel,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.warehouse_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        AppConfig.brandName,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          color: p.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  Text(title,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500, color: p.textPrimary)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(subtitle!, style: TextStyle(fontSize: 13, color: p.textSecondary)),
                  ],
                  const SizedBox(height: 20),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

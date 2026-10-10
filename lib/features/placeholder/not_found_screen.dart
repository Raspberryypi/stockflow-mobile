import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/palette.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('404',
                  style: TextStyle(fontSize: 64, fontWeight: FontWeight.w800, color: p.textSecondary)),
              const SizedBox(height: 8),
              Text('Page not found', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 20),
              FilledButton(onPressed: () => context.go('/dashboard'), child: const Text('Go to Dashboard')),
            ],
          ),
        ),
      ),
    );
  }
}

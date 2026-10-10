import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/palette.dart';
import '../../providers/auth_provider.dart';

/// "Wednesday, October 7, 2026 / Welcome back, Kief!" block from the web header.
class GreetingHeader extends StatelessWidget {
  const GreetingHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final first = context.watch<AuthProvider>().user?.firstName ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(DateFormat('EEEE, MMMM d, y').format(DateTime.now()),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.textSecondary)),
        const SizedBox(height: 2),
        Text('Welcome back${first.isNotEmpty ? ', $first' : ''}!',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20)),
      ],
    );
  }
}

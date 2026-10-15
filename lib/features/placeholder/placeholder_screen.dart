import 'package:flutter/material.dart';
import '../../core/theme/palette.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen(this.title, {super.key, this.icon = Icons.construction_rounded});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: p.textSecondary),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Coming in the next batch', style: TextStyle(color: p.textSecondary)),
        ],
      ),
    );
  }
}

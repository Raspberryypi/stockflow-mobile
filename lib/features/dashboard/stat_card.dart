import 'package:flutter/material.dart';
import '../../core/theme/palette.dart';

/// Which palette color a stat card uses (the web passes a MUI palette key).
enum StatTone { primary, info, success, warning, error }

/// Port of components/dashboard/StatCard.jsx.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
    this.loading = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final StatTone tone;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final (Color bg, Color accent, Color deep) = switch (tone) {
      StatTone.primary => (p.primaryLight, AppPalette.primary, AppPalette.primaryDark),
      StatTone.info => (p.infoLight, AppPalette.info, AppPalette.infoDark),
      StatTone.success => (p.successLight, AppPalette.success, AppPalette.successDark),
      StatTone.warning => (p.warningLight, AppPalette.warning, AppPalette.warningDark),
      StatTone.error => (p.errorLight, AppPalette.error, AppPalette.errorDark),
    };

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, size: 24, color: p.dark ? accent : deep),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600, color: p.textSecondary)),
                  const SizedBox(height: 2),
                  if (loading)
                    Container(
                      width: 56,
                      height: 22,
                      margin: const EdgeInsets.only(top: 3),
                      decoration: BoxDecoration(
                          color: p.divider, borderRadius: BorderRadius.circular(6)),
                    )
                  else
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(value,
                          maxLines: 1,
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700, color: p.textPrimary)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lays stat cards out in 2 / 3 / 5 columns depending on width
/// (web: sm:grid-cols-2 lg:grid-cols-5). With 2 columns the odd last card
/// spans the full width.
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.cards});
  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final cols = w >= 760 ? 5 : (w >= 520 ? 3 : 2);
      const gap = 12.0;
      final itemWidth = (w - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (var i = 0; i < cards.length; i++)
            SizedBox(
              width: (cols == 2 && i == cards.length - 1 && cards.length.isOdd) ? w : itemWidth,
              child: cards[i],
            ),
        ],
      );
    });
  }
}

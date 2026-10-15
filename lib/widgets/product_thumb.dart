import 'package:flutter/material.dart';
import '../core/theme/palette.dart';

class ProductThumb extends StatelessWidget {
  const ProductThumb({super.key, this.url, this.size = 48, this.radius = 10});
  final String? url;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final placeholder = Center(
      child: Icon(Icons.inventory_2_outlined, size: size * 0.45, color: p.textSecondary),
    );
    final hasUrl = url != null && url!.isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: ColoredBox(
          color: p.dark ? const Color(0xFF1E3336) : const Color(0xFFEEF4F6),
          child: hasUrl
              ? Image.network(
                  url!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => placeholder,
                  loadingBuilder: (context, child, progress) =>
                      progress == null ? child : placeholder,
                )
              : placeholder,
        ),
      ),
    );
  }
}

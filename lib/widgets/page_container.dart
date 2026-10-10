import 'package:flutter/material.dart';

/// Keeps content readable on wide screens (Edge/desktop/tablet) by capping
/// its width and centering it. On a phone it is a no-op.
class PageContainer extends StatelessWidget {
  const PageContainer({super.key, required this.child, this.maxWidth = 900});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
}

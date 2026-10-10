import 'package:flutter/material.dart';
import '../core/theme/palette.dart';
import '../models/app_user.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar(this.user, {super.key, this.radius = 20, this.background = AppPalette.primary});

  final AppUser? user;
  final double radius;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final u = user;
    return CircleAvatar(
      radius: radius,
      backgroundColor: background,
      foregroundImage: (u?.avatar != null) ? NetworkImage(u!.avatar!) : null,
      child: Text(
        u?.initials ?? '?',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.7,
        ),
      ),
    );
  }
}

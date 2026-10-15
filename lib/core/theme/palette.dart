import 'package:flutter/material.dart';

class AppPalette {
  const AppPalette._(this.dark);
  final bool dark;

  factory AppPalette.of(BuildContext context) =>
      AppPalette._(Theme.of(context).brightness == Brightness.dark);
  factory AppPalette.forBrightness(Brightness b) =>
      AppPalette._(b == Brightness.dark);

  static const primary = Color(0xFF2F6F6B);
  static const primaryDark = Color(0xFF1D4E4A);
  static const secondary = Color(0xFF3D5A80);
  static const secondaryDark = Color(0xFF28405C);
  static const success = Color(0xFF4CAF7D);
  static const successDark = Color(0xFF2E7D5B);
  static const warning = Color(0xFFE8A33D);
  static const warningDark = Color(0xFFB9791F);
  static const error = Color(0xFFE1614D);
  static const errorDark = Color(0xFFB8402E);
  static const info = Color(0xFF3E8FB0);
  static const infoDark = Color(0xFF286E8A);

  static const sidebarBg = Color(0xFF153033);
  static const sidebarBgActive = Color(0xFF28565C);
  static const sidebarText = Color(0xB3FFFFFF);

  static const authPanel = Color(0xFF043E50);

  Color get primaryLight => dark ? const Color(0xFF25423F) : const Color(0xFFDCEEEA);
  Color get secondaryLight => dark ? const Color(0xFF28374A) : const Color(0xFFE1E7F0);
  Color get successLight => dark ? const Color(0xFF25402F) : const Color(0xFFE1F3E8);
  Color get warningLight => dark ? const Color(0xFF453620) : const Color(0xFFFCEFD9);
  Color get errorLight => dark ? const Color(0xFF472822) : const Color(0xFFFBE1DC);
  Color get infoLight => dark ? const Color(0xFF213C44) : const Color(0xFFDCEEF5);

  Color get background => dark ? const Color(0xFF0F1E21) : const Color(0xFFEEF4F6);
  Color get paper => dark ? const Color(0xFF17282B) : Colors.white;
  Color get textPrimary => dark ? const Color(0xFFEAF2F3) : const Color(0xFF1F3A3D);
  Color get textSecondary => dark ? const Color(0xFF9DB4B6) : const Color(0xFF6E8A8D);
  Color get divider => dark ? const Color(0xFF25393C) : const Color(0xFFE4EDEF);
  Color get tableDivider => dark ? const Color(0xFF233639) : const Color(0xFFE9F0F1);
  Color get shadow => dark ? const Color(0x40000000) : const Color(0x0F0F2D30);

  Color get authAccent => dark ? const Color(0xFF0E6A85) : authPanel;
  Color get authAccentHover => dark ? const Color(0xFF12809F) : const Color(0xFF03303E);
  Color get authLink => dark ? const Color(0xFF7CC4D6) : authPanel;
  Color get authInputBg => dark ? const Color(0x0FFFFFFF) : const Color(0xFFF5F9FB);
  Color get authInputBorder => dark ? const Color(0x1FFFFFFF) : const Color(0xFFE6EEF2);
}

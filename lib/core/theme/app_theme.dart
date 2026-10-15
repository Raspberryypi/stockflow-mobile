import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'palette.dart';

ThemeData buildTheme(Brightness brightness) {
  final p = AppPalette.forBrightness(brightness);

  final scheme = ColorScheme(
    brightness: brightness,
    primary: AppPalette.primary,
    onPrimary: Colors.white,
    primaryContainer: p.primaryLight,
    onPrimaryContainer: p.textPrimary,
    secondary: AppPalette.secondary,
    onSecondary: Colors.white,
    secondaryContainer: p.secondaryLight,
    onSecondaryContainer: p.textPrimary,
    error: AppPalette.error,
    onError: Colors.white,
    errorContainer: p.errorLight,
    onErrorContainer: p.textPrimary,
    surface: p.paper,
    onSurface: p.textPrimary,
    onSurfaceVariant: p.textSecondary,
    outline: p.divider,
    outlineVariant: p.divider,
  );

  final base = ThemeData(brightness: brightness, useMaterial3: true);
  var text = GoogleFonts.interTextTheme(base.textTheme)
      .apply(bodyColor: p.textPrimary, displayColor: p.textPrimary);
  text = text.copyWith(
    headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
    headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
    titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
  );

  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c, width: w),
      );

  final buttonShape =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
  final buttonText = text.labelLarge?.copyWith(fontWeight: FontWeight.w600);
  final inputBorderColor =
      p.dark ? const Color(0x3BFFFFFF) : const Color(0x3B000000);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.background,
    canvasColor: p.paper,
    dividerColor: p.divider,
    textTheme: text,
    primaryTextTheme: text,
    dividerTheme: DividerThemeData(color: p.divider, thickness: 1, space: 1),
    cardTheme: CardThemeData(
      color: p.paper,
      elevation: 2,
      shadowColor: p.shadow,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: p.divider),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppPalette.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(64, 44),
        shape: buttonShape,
        textStyle: buttonText,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppPalette.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(64, 44),
        shape: buttonShape,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppPalette.primary,
        minimumSize: const Size(64, 44),
        side: BorderSide(color: p.divider),
        shape: buttonShape,
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppPalette.primary,
        shape: buttonShape,
        textStyle: buttonText,
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      labelStyle: text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      side: BorderSide.none,
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: TextStyle(color: p.textSecondary.withValues(alpha: 0.8)),
      labelStyle: TextStyle(color: p.textSecondary),
      enabledBorder: border(inputBorderColor),
      border: border(inputBorderColor),
      focusedBorder: border(AppPalette.primary, 2),
      errorBorder: border(AppPalette.error),
      focusedErrorBorder: border(AppPalette.error, 2),
    ),
    dataTableTheme: DataTableThemeData(
      headingTextStyle: TextStyle(
        color: p.textSecondary,
        fontWeight: FontWeight.w700,
        fontSize: 12,
        letterSpacing: 0.4,
      ),
      dividerThickness: 1,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.paper,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.paper,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: AppPalette.sidebarBg,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
  );
}

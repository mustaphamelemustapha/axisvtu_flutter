import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const _seed = Color(0xFF1E88E5);
  static const _secondary = Color(0xFF0FB5AE);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
      secondary: _secondary,
    );
    final baseText = GoogleFonts.plusJakartaSansTextTheme()
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? const Color(0xFF0C1118) : const Color(0xFFF4F7FB),
      textTheme: baseText.copyWith(
        headlineSmall: baseText.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        titleTextStyle: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF141B24) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF141B24) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.35)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.4)),
          textStyle: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.primary.withValues(alpha: 0.08),
        labelStyle: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? const Color(0xFF1A2230) : const Color(0xFF0F172A),
        contentTextStyle: baseText.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF0F141C) : Colors.white,
        height: 70,
        labelTextStyle: WidgetStateProperty.all(
          baseText.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        indicatorColor: scheme.primary.withValues(alpha: 0.12),
      ),
      dividerColor: scheme.outline.withValues(alpha: 0.2),
      extensions: const [AxisPalette()],
    );
  }
}

class AxisPalette extends ThemeExtension<AxisPalette> {
  const AxisPalette();

  static const gradient = LinearGradient(
    colors: [
      Color(0xFF1E88E5),
      Color(0xFF0FB5AE),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const warmGradient = LinearGradient(
    colors: [
      Color(0xFFFFB020),
      Color(0xFFFF7A59),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  ThemeExtension<AxisPalette> copyWith() => this;

  @override
  ThemeExtension<AxisPalette> lerp(ThemeExtension<AxisPalette>? other, double t) => this;
}

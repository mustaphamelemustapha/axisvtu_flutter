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
    final baseText = GoogleFonts.manropeTextTheme().apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    final textTheme = baseText.copyWith(
      displayLarge: baseText.displayLarge?.copyWith(
        fontSize: 36,
        height: 1.08,
        fontWeight: FontWeight.w800,
      ),
      displayMedium: baseText.displayMedium?.copyWith(
        fontSize: 32,
        height: 1.1,
        fontWeight: FontWeight.w700,
      ),
      displaySmall: baseText.displaySmall?.copyWith(
        fontSize: 28,
        height: 1.12,
        fontWeight: FontWeight.w700,
      ),
      headlineLarge: baseText.headlineLarge?.copyWith(
        fontSize: 24,
        height: 1.16,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: baseText.headlineMedium?.copyWith(
        fontSize: 22,
        height: 1.18,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: baseText.headlineSmall?.copyWith(
        fontSize: 20,
        height: 1.2,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: baseText.titleLarge?.copyWith(
        fontSize: 18,
        height: 1.24,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: baseText.titleMedium?.copyWith(
        fontSize: 16,
        height: 1.26,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: baseText.titleSmall?.copyWith(
        fontSize: 14,
        height: 1.3,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: baseText.bodyLarge?.copyWith(
        fontSize: 16,
        height: 1.45,
        fontWeight: FontWeight.w500,
      ),
      bodyMedium: baseText.bodyMedium?.copyWith(
        fontSize: 15,
        height: 1.42,
        fontWeight: FontWeight.w500,
      ),
      bodySmall: baseText.bodySmall?.copyWith(
        fontSize: 13,
        height: 1.38,
        fontWeight: FontWeight.w500,
      ),
      labelLarge: baseText.labelLarge?.copyWith(
        fontSize: 14,
        height: 1.2,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: baseText.labelMedium?.copyWith(
        fontSize: 12,
        height: 1.2,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: baseText.labelSmall?.copyWith(
        fontSize: 11,
        height: 1.2,
        fontWeight: FontWeight.w600,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF0C1118)
          : const Color(0xFFF4F7FB),
      textTheme: textTheme,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface.withValues(alpha: 0.6),
        ),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurface.withValues(alpha: 0.74),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.35)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.labelLarge,
          animationDuration: const Duration(milliseconds: 160),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.4)),
          textStyle: textTheme.labelLarge,
          animationDuration: const Duration(milliseconds: 160),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.primary.withValues(alpha: 0.08),
        labelStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark
            ? const Color(0xFF1A2230)
            : const Color(0xFF0F172A),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF0F141C) : Colors.white,
        height: 70,
        labelTextStyle: WidgetStateProperty.all(textTheme.labelMedium),
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
    colors: [Color(0xFF1E88E5), Color(0xFF0FB5AE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const warmGradient = LinearGradient(
    colors: [Color(0xFFFFB020), Color(0xFFFF7A59)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  ThemeExtension<AxisPalette> copyWith() => this;

  @override
  ThemeExtension<AxisPalette> lerp(
    ThemeExtension<AxisPalette>? other,
    double t,
  ) => this;
}

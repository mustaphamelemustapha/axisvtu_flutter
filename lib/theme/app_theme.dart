import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'axis_tokens.dart';

class AppTheme {
  static const _seed = Color(0xFF2457F5);
  static const _secondary = Color(0xFF14B8A6);
  static const _lightBg = Color(0xFFF8FAFC);
  static const _darkBg = Color(0xFF0F172A);
  static const _darkSurface = Color(0xFF152033);
  static const _lightSurfaceElevated = Colors.white;
  static const _darkSurfaceSoft = Color(0xFF1E293B);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: brightness,
          secondary: _secondary,
        ).copyWith(
          primary: _seed,
          secondary: _secondary,
          surface: isDark ? _darkBg : _lightBg,
          onSurface: isDark ? const Color(0xFFE7EEF9) : const Color(0xFF0B1220),
          onSurfaceVariant: isDark ? const Color(0xFFB8C4D6) : const Color(0xFF475569),
          outline: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          outlineVariant: isDark ? const Color(0xFF152033) : const Color(0xFFF1F5F9),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onError: Colors.white,
          error: const Color(0xFFE11D48),
          tertiary: const Color(0xFFF59E0B),
          onTertiary: Colors.white,
          surfaceTint: Colors.transparent,
          surfaceContainerHighest: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          shadow: Colors.black,
        );

    final baseText = GoogleFonts.poppinsTextTheme().apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    final textTheme = _applyTabularNumbers(
      baseText.copyWith(
        displayLarge: baseText.displayLarge?.copyWith(
          fontSize: 28,
          height: 1.18,
          letterSpacing: -0.7,
          fontWeight: FontWeight.w700,
        ),
        displayMedium: baseText.displayMedium?.copyWith(
          fontSize: 26,
          height: 1.2,
          letterSpacing: -0.55,
          fontWeight: FontWeight.w700,
        ),
        displaySmall: baseText.displaySmall?.copyWith(
          fontSize: 24,
          height: 1.22,
          letterSpacing: -0.45,
          fontWeight: FontWeight.w700,
        ),
        headlineLarge: baseText.headlineLarge?.copyWith(
          fontSize: 22,
          height: 1.25,
          letterSpacing: -0.35,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: baseText.headlineMedium?.copyWith(
          fontSize: 20,
          height: 1.28,
          letterSpacing: -0.2,
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: baseText.headlineSmall?.copyWith(
          fontSize: 18,
          height: 1.3,
          letterSpacing: -0.1,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: baseText.titleLarge?.copyWith(
          fontSize: 18,
          height: 1.3,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: baseText.titleMedium?.copyWith(
          fontSize: 16,
          height: 1.35,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: baseText.titleSmall?.copyWith(
          fontSize: 14,
          height: 1.35,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: baseText.bodyLarge?.copyWith(
          fontSize: 16,
          height: 1.5,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: baseText.bodyMedium?.copyWith(
          fontSize: 14,
          height: 1.45,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: baseText.bodySmall?.copyWith(
          fontSize: 12,
          height: 1.35,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: baseText.labelLarge?.copyWith(
          fontSize: 14,
          height: 1.3,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: baseText.labelMedium?.copyWith(
          fontSize: 12,
          height: 1.25,
          fontWeight: FontWeight.w600,
        ),
        labelSmall: baseText.labelSmall?.copyWith(
          fontSize: 11,
          height: 1.25,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: GoogleFonts.poppins().fontFamily,
      visualDensity: VisualDensity.standard,
      scaffoldBackgroundColor: isDark ? _darkBg : _lightBg,
      textTheme: textTheme,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
      splashFactory: InkRipple.splashFactory,
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
        toolbarHeight: 72,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? _darkSurface : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: isDark ? 0 : 2,
        shadowColor: Colors.black.withOpacity(0.05),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: isDark ? const BorderSide(color: Color(0xFF333333)) : BorderSide.none,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? _darkSurfaceSoft : _lightSurfaceElevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface.withValues(alpha: isDark ? 0.58 : 0.48),
        ),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurface.withValues(alpha: isDark ? 0.76 : 0.64),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AxisRadii.lg),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: isDark ? 0.9 : 0.95)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AxisRadii.lg),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: isDark ? 0.9 : 0.95)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AxisRadii.lg),
          borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.92), width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AxisRadii.lg),
          borderSide: BorderSide(color: scheme.error.withValues(alpha: 0.9)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AxisRadii.lg),
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AxisRadii.lg),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontSize: 16,
            letterSpacing: 0.35,
            fontWeight: FontWeight.w600,
          ),
          animationDuration: AxisDurations.normal,
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AxisRadii.lg),
          ),
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.9)),
          textStyle: textTheme.labelLarge?.copyWith(
            fontSize: 16,
            letterSpacing: 0.35,
            fontWeight: FontWeight.w600,
          ),
          animationDuration: AxisDurations.normal,
          foregroundColor: scheme.onSurface,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark
            ? scheme.primary.withValues(alpha: 0.12)
            : const Color(0xFFF0F5FF),
        labelStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        side: BorderSide(color: scheme.outline.withValues(alpha: isDark ? 0.35 : 0.9)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark
            ? const Color(0xFF101826)
            : const Color(0xFF0F172A),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AxisRadii.lg),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? _darkSurface : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AxisRadii.xl),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? _darkBg : _lightBg,
        modalBackgroundColor: isDark ? _darkBg : _lightBg,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(32),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        indicatorColor: Colors.transparent,
        backgroundColor: isDark ? _darkSurface : Colors.white,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return textTheme.labelMedium?.copyWith(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
      ),
      dividerColor: scheme.outline.withValues(alpha: isDark ? 0.65 : 0.9),
      iconTheme: IconThemeData(
        color: scheme.onSurface.withValues(alpha: isDark ? 0.82 : 0.88),
        size: 22,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: 0.2),
        selectionHandleColor: scheme.primary,
      ),
      extensions: const [AxisPalette()],
    );
  }

  static TextTheme _applyTabularNumbers(TextTheme base) {
    TextStyle? withFigures(TextStyle? style) {
      return style?.copyWith(
        fontFeatures: const [ui.FontFeature.tabularFigures()],
      );
    }

    return base.copyWith(
      displayLarge: withFigures(base.displayLarge),
      displayMedium: withFigures(base.displayMedium),
      displaySmall: withFigures(base.displaySmall),
      headlineLarge: withFigures(base.headlineLarge),
      headlineMedium: withFigures(base.headlineMedium),
      headlineSmall: withFigures(base.headlineSmall),
      titleLarge: withFigures(base.titleLarge),
      titleMedium: withFigures(base.titleMedium),
      titleSmall: withFigures(base.titleSmall),
      bodyLarge: withFigures(base.bodyLarge),
      bodyMedium: withFigures(base.bodyMedium),
      bodySmall: withFigures(base.bodySmall),
      labelLarge: withFigures(base.labelLarge),
      labelMedium: withFigures(base.labelMedium),
      labelSmall: withFigures(base.labelSmall),
    );
  }
}

class AxisPalette extends ThemeExtension<AxisPalette> {
  const AxisPalette();

  static const gradient = LinearGradient(
    colors: [Color(0xFF2457F5), Color(0xFF14B8A6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const warmGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const softBackgroundGradient = LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const lightWashGradient = LinearGradient(
    colors: [Color(0xFFF5F9FF), Color(0xFFEAF2FF), Color(0xFFF7FBFF)],
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

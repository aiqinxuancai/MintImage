import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppThemeTokens {
  static const canvas = Color(0xFFF8FAFF);
  static const canvasTint = Color(0xFFEFF7FF);
  static const surface = Colors.white;
  static const surfaceSoft = Color(0xFFF0F9FF);
  static const surfaceMuted = Color(0xFFE5F2FF);
  static const primary = Color(0xFF0E7490);
  static const primaryStrong = Color(0xFF005A71);
  static const primarySoft = Color(0xFFB9EAFF);
  static const textPrimary = Color(0xFF0B1C30);
  static const textSecondary = Color(0xFF5C7386);
  static const border = Color(0xFFD7E7F7);
  static const warningSurface = Color(0xFFFFF3D9);
  static const warningText = Color(0xFF9A6400);
  static const dangerSurface = Color(0xFFFFE7E7);
  static const dangerText = Color(0xFFAA2E2E);
}

class AppDecorations {
  const AppDecorations._();

  static List<BoxShadow> get softShadow => const [
    BoxShadow(
      color: Color(0x140E7490),
      blurRadius: 24,
      spreadRadius: -6,
      offset: Offset(0, 12),
    ),
  ];

  static List<BoxShadow> get floatingShadow => const [
    BoxShadow(
      color: Color(0x140E7490),
      blurRadius: 28,
      spreadRadius: -8,
      offset: Offset(0, 14),
    ),
  ];

  static BoxDecoration card({
    double radius = 24,
    Color color = AppThemeTokens.surface,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withValues(alpha: 0.92)),
      boxShadow: softShadow,
    );
  }

  static BoxDecoration glass({double radius = 28}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.88),
          Colors.white.withValues(alpha: 0.72),
        ],
      ),
      border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
      boxShadow: floatingShadow,
    );
  }
}

ThemeData buildAppTheme() {
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: AppThemeTokens.primary,
        brightness: Brightness.light,
      ).copyWith(
        primary: AppThemeTokens.primary,
        onPrimary: Colors.white,
        secondary: AppThemeTokens.primarySoft,
        onSecondary: AppThemeTokens.primaryStrong,
        surface: AppThemeTokens.surface,
        onSurface: AppThemeTokens.textPrimary,
        surfaceContainerHighest: AppThemeTokens.surfaceMuted,
        outline: AppThemeTokens.border,
        error: const Color(0xFFBA1A1A),
        onError: Colors.white,
      );

  final baseTextTheme = GoogleFonts.manropeTextTheme().copyWith(
    headlineLarge: GoogleFonts.manrope(
      fontSize: 30,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.6,
      color: AppThemeTokens.textPrimary,
    ),
    headlineMedium: GoogleFonts.manrope(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: AppThemeTokens.textPrimary,
    ),
    titleLarge: GoogleFonts.manrope(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: AppThemeTokens.textPrimary,
    ),
    titleMedium: GoogleFonts.manrope(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: AppThemeTokens.textPrimary,
    ),
    bodyLarge: GoogleFonts.manrope(
      fontSize: 16,
      height: 1.45,
      color: AppThemeTokens.textPrimary,
    ),
    bodyMedium: GoogleFonts.manrope(
      fontSize: 14,
      height: 1.45,
      color: AppThemeTokens.textPrimary,
    ),
    bodySmall: GoogleFonts.manrope(
      fontSize: 12,
      height: 1.4,
      color: AppThemeTokens.textSecondary,
    ),
    labelLarge: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      color: AppThemeTokens.primaryStrong,
    ),
    labelMedium: GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
      color: AppThemeTokens.primaryStrong,
    ),
    labelSmall: GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.4,
      color: AppThemeTokens.primaryStrong,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppThemeTokens.canvas,
    cardColor: AppThemeTokens.surface,
    textTheme: baseTextTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      // A transparent background makes Flutter assume a dark bar and pick
      // white status bar icons, which vanish on the light canvas.
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      foregroundColor: AppThemeTokens.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: baseTextTheme.titleLarge,
    ),
    dividerTheme: const DividerThemeData(
      color: AppThemeTokens.border,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppThemeTokens.primaryStrong,
      contentTextStyle: GoogleFonts.manrope(color: Colors.white),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppThemeTokens.surfaceSoft,
      labelStyle: GoogleFonts.inter(
        fontSize: 12,
        color: AppThemeTokens.primaryStrong,
        fontWeight: FontWeight.w700,
      ),
      selectedColor: AppThemeTokens.primarySoft,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: baseTextTheme.bodyMedium?.copyWith(
        color: AppThemeTokens.textSecondary.withValues(alpha: 0.9),
      ),
      labelStyle: baseTextTheme.labelMedium,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppThemeTokens.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppThemeTokens.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppThemeTokens.primary, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppThemeTokens.primary,
        foregroundColor: Colors.white,
        textStyle: baseTextTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: AppThemeTokens.primary,
        foregroundColor: Colors.white,
        textStyle: baseTextTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppThemeTokens.primary,
        textStyle: baseTextTheme.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      textStyle: baseTextTheme.bodyMedium,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      modalBackgroundColor: Colors.white,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppThemeTokens.primaryStrong,
        backgroundColor: Colors.white.withValues(alpha: 0.7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
    ),
  );
}

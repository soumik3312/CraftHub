import 'package:flutter/material.dart';

class CraftHubColors {
  static const Color bg = Color(0xFF09090C);
  static const Color bgSoft = Color(0xFF111114);
  static const Color panel = Color(0xFF17171B);
  static const Color panelAlt = Color(0xFF1F1F25);
  static const Color border = Color(0xFF2C2C33);
  static const Color text = Color(0xFFF4F0F8);
  static const Color muted = Color(0xFFB4AFC4);
  static const Color lavender = Color(0xFFD89AFB);
  static const Color purple = Color(0xFFBE5BFF);
  static const Color cyan = Color(0xFF8FD8FF);
  static const Color lime = Color(0xFFA9E34B);
  static const Color danger = Color(0xFFFF6B9E);

  static const Color lightBg = Color(0xFFF5F2FA);
  static const Color lightBgSoft = Color(0xFFECE5F3);
  static const Color lightPanel = Color(0xFFFFFFFF);
  static const Color lightPanelAlt = Color(0xFFF3EDF8);
  static const Color lightBorder = Color(0xFFD9CEE6);
  static const Color lightText = Color(0xFF22172D);
  static const Color lightMuted = Color(0xFF6B5D7B);

  static const LinearGradient accent = LinearGradient(
    colors: [lavender, purple],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient accentAlt = LinearGradient(
    colors: [cyan, lavender, purple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

@immutable
class CraftHubPalette extends ThemeExtension<CraftHubPalette> {
  const CraftHubPalette({
    required this.bg,
    required this.bgSoft,
    required this.panel,
    required this.panelAlt,
    required this.border,
    required this.text,
    required this.muted,
  });

  final Color bg;
  final Color bgSoft;
  final Color panel;
  final Color panelAlt;
  final Color border;
  final Color text;
  final Color muted;

  static const dark = CraftHubPalette(
    bg: CraftHubColors.bg,
    bgSoft: CraftHubColors.bgSoft,
    panel: CraftHubColors.panel,
    panelAlt: CraftHubColors.panelAlt,
    border: CraftHubColors.border,
    text: CraftHubColors.text,
    muted: CraftHubColors.muted,
  );

  static const light = CraftHubPalette(
    bg: CraftHubColors.lightBg,
    bgSoft: CraftHubColors.lightBgSoft,
    panel: CraftHubColors.lightPanel,
    panelAlt: CraftHubColors.lightPanelAlt,
    border: CraftHubColors.lightBorder,
    text: CraftHubColors.lightText,
    muted: CraftHubColors.lightMuted,
  );

  static CraftHubPalette of(BuildContext context) {
    return Theme.of(context).extension<CraftHubPalette>() ?? dark;
  }

  @override
  CraftHubPalette copyWith({
    Color? bg,
    Color? bgSoft,
    Color? panel,
    Color? panelAlt,
    Color? border,
    Color? text,
    Color? muted,
  }) {
    return CraftHubPalette(
      bg: bg ?? this.bg,
      bgSoft: bgSoft ?? this.bgSoft,
      panel: panel ?? this.panel,
      panelAlt: panelAlt ?? this.panelAlt,
      border: border ?? this.border,
      text: text ?? this.text,
      muted: muted ?? this.muted,
    );
  }

  @override
  CraftHubPalette lerp(ThemeExtension<CraftHubPalette>? other, double t) {
    if (other is! CraftHubPalette) return this;
    return CraftHubPalette(
      bg: Color.lerp(bg, other.bg, t) ?? bg,
      bgSoft: Color.lerp(bgSoft, other.bgSoft, t) ?? bgSoft,
      panel: Color.lerp(panel, other.panel, t) ?? panel,
      panelAlt: Color.lerp(panelAlt, other.panelAlt, t) ?? panelAlt,
      border: Color.lerp(border, other.border, t) ?? border,
      text: Color.lerp(text, other.text, t) ?? text,
      muted: Color.lerp(muted, other.muted, t) ?? muted,
    );
  }
}

class CraftHubTheme {
  static ThemeData get darkTheme => _buildTheme(brightness: Brightness.dark);
  static ThemeData get lightTheme => _buildTheme(brightness: Brightness.light);

  static ThemeData _buildTheme({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;
    final palette = isDark ? CraftHubPalette.dark : CraftHubPalette.light;
    final base = ThemeData(useMaterial3: true, brightness: brightness);

    return base.copyWith(
      scaffoldBackgroundColor: palette.bg,
      extensions: <ThemeExtension<dynamic>>[palette],
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: CraftHubColors.purple,
        onPrimary: const Color(0xFF1A0824),
        secondary: CraftHubColors.cyan,
        onSecondary: Colors.black,
        error: CraftHubColors.danger,
        onError: Colors.white,
        surface: palette.panel,
        onSurface: palette.text,
      ),
      textTheme: base.textTheme.copyWith(
        headlineLarge: TextStyle(
          fontSize: 38,
          height: 1.04,
          fontWeight: FontWeight.w900,
          color: palette.text,
          letterSpacing: -1.3,
        ),
        headlineMedium: TextStyle(
          fontSize: 30,
          height: 1.06,
          fontWeight: FontWeight.w900,
          color: palette.text,
          letterSpacing: -1.0,
        ),
        titleLarge: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: palette.text,
          letterSpacing: -0.5,
        ),
        titleMedium: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          color: palette.text,
          letterSpacing: -0.25,
        ),
        titleSmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: palette.muted,
          letterSpacing: 1.8,
        ),
        bodyLarge: TextStyle(fontSize: 16, height: 1.45, color: palette.text),
        bodyMedium: TextStyle(fontSize: 14, height: 1.42, color: palette.muted),
        bodySmall: TextStyle(
          fontSize: 11,
          height: 1.35,
          color: palette.muted,
          letterSpacing: 0.9,
        ),
        labelLarge: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: palette.text,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: palette.panel.withValues(alpha: isDark ? 0.92 : 0.97),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: palette.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.panelAlt.withValues(alpha: isDark ? 0.7 : 0.95),
        hintStyle: TextStyle(color: palette.muted),
        labelStyle: TextStyle(color: palette.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: CraftHubColors.lavender),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 15,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: const Color(0xFF230A34),
          backgroundColor: CraftHubColors.lavender,
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.text,
          side: BorderSide(color: palette.border),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: palette.panelAlt,
        disabledColor: palette.panelAlt,
        selectedColor: CraftHubColors.cyan.withValues(alpha: 0.18),
        secondarySelectedColor: CraftHubColors.lavender.withValues(alpha: 0.2),
        labelStyle: TextStyle(color: palette.text, fontWeight: FontWeight.w600),
        side: BorderSide(color: palette.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.panel,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: palette.text),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: palette.border),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.panel,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: palette.border),
        ),
      ),
      dividerColor: palette.border,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.panelAlt,
        contentTextStyle: TextStyle(color: palette.text),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

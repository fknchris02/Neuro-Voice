import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'liquid_glass.dart';

/// Tokens de color del diseño de Stitch (design/stitch/*/code.html).
class AppColors {
  AppColors._();

  static const primary = Color(0xFF7A0014);
  static const primaryContainer = Color(0xFF9E1B26);
  static const onPrimaryContainer = Color(0xFFFFAFAC);
  static const primaryFixed = Color(0xFFFFDAD8);
  static const secondary = Color(0xFFB71032);
  static const secondaryContainer = Color(0xFFDA3148);
  static const secondaryFixed = Color(0xFFFFDAD9);
  static const secondaryFixedDim = Color(0xFFFFB3B4);
  static const tertiary = Color(0xFF79001E);
  static const tertiaryFixed = Color(0xFFFFDADA);
  static const inversePrimary = Color(0xFFFFB3B0);

  static const surface = Color(0xFFFFF8F8);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFFCF1F2);
  static const surfaceContainer = Color(0xFFF6EBEC);
  static const surfaceContainerHigh = Color(0xFFF1E6E7);
  static const surfaceContainerHighest = Color(0xFFEBE0E1);
  static const onSurface = Color(0xFF1F1A1B);
  static const onSurfaceVariant = Color(0xFF594140);
  static const outline = Color(0xFF8D706F);
  static const outlineVariant = Color(0xFFE1BFBD);
  static const neutralDark = Color(0xFF1F1A1B);

  /// Sombra suave carmesí de las tarjetas: rgba(128,0,32,0.06).
  static const cardShadow = Color(0x0F800020);

  // Semáforo de riesgo: usar SOLO para resultados clínicos,
  // nunca como color decorativo.
  static const riskLow = Color(0xFF2E7D32);
  static const riskModerate = Color(0xFFD97706);
  static const riskHigh = Color(0xFFC62828);
}

/// Radios: más amplios que los de Stitch para el estilo liquid glass.
class AppRadius {
  AppRadius._();
  static const lg = 12.0;
  static const xl = 20.0;
}

/// Espaciados de Stitch.
class AppSpacing {
  AppSpacing._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;

  /// Margen lateral de pantalla.
  static const margin = 20.0;
}

/// Sombras reutilizables del diseño.
class AppShadows {
  AppShadows._();

  static const card = [
    BoxShadow(color: AppColors.cardShadow, blurRadius: 24, offset: Offset(0, 8)),
  ];

  static const small = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 1)),
  ];

  static List<BoxShadow> hero(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.22),
          blurRadius: 32,
          offset: const Offset(0, 12),
        ),
      ];
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(_lightScheme);

  static ThemeData dark() => _build(ColorScheme.fromSeed(
        seedColor: AppColors.primaryContainer,
        brightness: Brightness.dark,
        surface: AppColors.neutralDark,
      ));

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryContainer: AppColors.primaryContainer,
    onPrimaryContainer: AppColors.onPrimaryContainer,
    primaryFixed: AppColors.primaryFixed,
    primaryFixedDim: Color(0xFFFFB3B0),
    onPrimaryFixed: Color(0xFF410006),
    onPrimaryFixedVariant: Color(0xFF8F0D1D),
    secondary: AppColors.secondary,
    onSecondary: Colors.white,
    secondaryContainer: AppColors.secondaryContainer,
    onSecondaryContainer: Color(0xFFFFFBFF),
    secondaryFixed: AppColors.secondaryFixed,
    secondaryFixedDim: AppColors.secondaryFixedDim,
    onSecondaryFixed: Color(0xFF40000A),
    onSecondaryFixedVariant: Color(0xFF920023),
    tertiary: AppColors.tertiary,
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFF9C1C31),
    onTertiaryContainer: Color(0xFFFFAEB1),
    tertiaryFixed: AppColors.tertiaryFixed,
    tertiaryFixedDim: Color(0xFFFFB3B5),
    onTertiaryFixed: Color(0xFF40000B),
    onTertiaryFixedVariant: Color(0xFF8E0F28),
    error: Color(0xFFBA1A1A),
    onError: Colors.white,
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF93000A),
    surface: AppColors.surface,
    onSurface: AppColors.onSurface,
    onSurfaceVariant: AppColors.onSurfaceVariant,
    surfaceDim: Color(0xFFE2D7D8),
    surfaceBright: AppColors.surface,
    surfaceContainerLowest: AppColors.surfaceContainerLowest,
    surfaceContainerLow: AppColors.surfaceContainerLow,
    surfaceContainer: AppColors.surfaceContainer,
    surfaceContainerHigh: AppColors.surfaceContainerHigh,
    surfaceContainerHighest: AppColors.surfaceContainerHighest,
    outline: AppColors.outline,
    outlineVariant: AppColors.outlineVariant,
    inverseSurface: Color(0xFF352F30),
    onInverseSurface: Color(0xFFF9EEEF),
    inversePrimary: AppColors.inversePrimary,
    surfaceTint: Color(0xFFB12A32),
  );

  /// Escala tipográfica de Stitch (Plus Jakarta Sans):
  /// label-sm 11/16 w600 · label-md 13/18 w600 · body-md 14/20 ·
  /// body-lg 16/24 · headline-md 20/28 w600 · headline-lg 24/32 w700 ·
  /// headline-xl-mobile 28/36 w700 · headline-xl 36/44 w700.
  static TextTheme _textTheme(Color color) {
    TextStyle s(double size, double lineHeight, FontWeight weight) =>
        GoogleFonts.plusJakartaSans(
          fontSize: size,
          height: lineHeight / size,
          fontWeight: weight,
          color: color,
        );

    return TextTheme(
      displaySmall: s(36, 44, FontWeight.w700),
      headlineMedium: s(28, 36, FontWeight.w700),
      headlineSmall: s(24, 32, FontWeight.w700),
      titleLarge: s(20, 28, FontWeight.w600),
      titleMedium: s(16, 24, FontWeight.w600),
      titleSmall: s(14, 20, FontWeight.w600),
      bodyLarge: s(16, 24, FontWeight.w400),
      bodyMedium: s(14, 20, FontWeight.w400),
      bodySmall: s(12, 16, FontWeight.w400),
      labelLarge: s(14, 20, FontWeight.w600),
      labelMedium: s(13, 18, FontWeight.w600),
      labelSmall: s(11, 16, FontWeight.w600),
    );
  }

  static ThemeData _build(ColorScheme scheme) {
    final textTheme = _textTheme(scheme.onSurface);
    const minButtonSize = Size(64, 52);
    final buttonText = textTheme.labelLarge!.copyWith(fontSize: 15);

    final dark = scheme.brightness == Brightness.dark;
    // Cristal de tarjetas, hojas y diálogos.
    final glassColor = dark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.72);
    final glassSide = BorderSide(
      color: Colors.white.withValues(alpha: dark ? 0.14 : 0.85),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      // Transparente: cada ruta pinta el fondo ambiental (LiquidBackdrop).
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: textTheme,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: LiquidPageTransitionsBuilder(),
          TargetPlatform.iOS: LiquidPageTransitionsBuilder(),
          TargetPlatform.macOS: LiquidPageTransitionsBuilder(),
          TargetPlatform.windows: LiquidPageTransitionsBuilder(),
          TargetPlatform.linux: LiquidPageTransitionsBuilder(),
          TargetPlatform.fuchsia: LiquidPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        // Se funde con el fondo y se vuelve cristal al hacer scroll debajo.
        backgroundColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.scrolledUnder)
              ? scheme.surface.withValues(alpha: 0.82)
              : Colors.transparent,
        ),
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: glassColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: glassSide,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: dark
            ? const Color(0xFF241A1D).withValues(alpha: 0.97)
            : scheme.surface.withValues(alpha: 0.97),
        surfaceTintColor: Colors.transparent,
        dragHandleColor: scheme.outlineVariant,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dark ? const Color(0xFF241A1D) : scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: glassSide,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: glassColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg + 4),
          borderSide: glassSide,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg + 4),
          borderSide: glassSide,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg + 4),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: minButtonSize,
          shape: const StadiumBorder(),
          textStyle: buttonText,
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimary,
          elevation: 3,
          shadowColor: AppColors.primary.withValues(alpha: 0.45),
          animationDuration: const Duration(milliseconds: 220),
        ).copyWith(
          // Brillo de cristal encima del color: respeta los botones que
          // cambian el color (p. ej. los de acciones destructivas).
          backgroundBuilder: (context, states, child) =>
              states.contains(WidgetState.disabled)
                  ? child!
                  : DecoratedBox(
                      decoration: const ShapeDecoration(
                        shape: StadiumBorder(),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x47FFFFFF),
                            Color(0x0AFFFFFF),
                            Color(0x00000000),
                            Color(0x1A000000),
                          ],
                          stops: [0, 0.45, 0.6, 1],
                        ),
                      ),
                      child: child,
                    ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: minButtonSize,
          shape: const StadiumBorder(),
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: minButtonSize,
          shape: const StadiumBorder(),
          textStyle: buttonText,
          backgroundColor: glassColor,
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.6)),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide.none,
        labelStyle: textTheme.labelMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg + 4),
        ),
      ),
    );
  }
}

/// Tarjeta estándar de la app, en cristal (ver [GlassCard]).
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Tinte opcional del cristal.
  final Color? color;
  final VoidCallback? onTap;
  final List<BoxShadow>? shadow;

  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.color,
    this.onTap,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: padding,
      tint: color,
      onTap: onTap,
      shadows: shadow,
      child: child,
    );
  }
}

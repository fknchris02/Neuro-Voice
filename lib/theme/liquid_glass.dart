import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Lenguaje visual "liquid glass": superficies translúcidas con borde de luz
/// sobre un fondo ambiental carmesí.
///
/// Rendimiento: el desenfoque real (BackdropFilter) sólo se usa en piezas
/// flotantes y fijas (barra de navegación). Las tarjetas de las listas
/// simulan el cristal con degradados, que no cuestan nada al hacer scroll.
class Glass {
  Glass._();

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Relleno translúcido. Con [tint] se tiñe el cristal de ese color.
  static Gradient fill(BuildContext context, {Color? tint}) {
    if (tint != null) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color.lerp(tint, Colors.white, 0.14)!, tint],
      );
    }
    final dark = isDark(context);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: dark
          ? [
              Colors.white.withValues(alpha: 0.12),
              Colors.white.withValues(alpha: 0.04),
            ]
          : [
              Colors.white.withValues(alpha: 0.86),
              Colors.white.withValues(alpha: 0.58),
            ],
    );
  }

  /// Sombra difusa teñida de carmesí (negra en modo oscuro).
  static List<BoxShadow> shadow(BuildContext context, {double depth = 1}) {
    final dark = isDark(context);
    return [
      BoxShadow(
        color: (dark ? Colors.black : AppColors.primary)
            .withValues(alpha: (dark ? 0.32 : 0.09) * depth.clamp(0, 2)),
        blurRadius: 12 + 18 * depth,
        offset: Offset(0, 4 + 8 * depth),
      ),
    ];
  }

  /// Degradado carmesí de los elementos principales (paneles, botón de
  /// micrófono, barra seleccionada).
  static const crimson = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.secondaryContainer,
      AppColors.primaryContainer,
      AppColors.primary,
    ],
    stops: [0, 0.55, 1],
  );
}

/// Borde de luz del cristal: brillante arriba a la izquierda y casi
/// invisible abajo, como el reflejo en un vidrio curvo.
class GlassRimPainter extends CustomPainter {
  final double radius;
  final double strength;
  final bool dark;

  const GlassRimPainter({
    required this.radius,
    this.strength = 1,
    this.dark = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final r = math.min(radius, size.shortestSide / 2);
    final a = (dark ? 0.30 : 0.95) * strength;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: a),
          Colors.white.withValues(alpha: a * 0.12),
          Colors.white.withValues(alpha: a * 0.45),
        ],
        stops: const [0, 0.55, 1],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(0.6), Radius.circular(r)),
      paint,
    );
  }

  @override
  bool shouldRepaint(GlassRimPainter old) =>
      old.radius != radius || old.strength != strength || old.dark != dark;
}

/// Superficie de cristal: relleno translúcido, borde de luz y sombra suave.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? tint;
  final VoidCallback? onTap;

  /// Desenfoque real del fondo. Sólo para piezas flotantes: es costoso.
  final bool blur;
  final List<BoxShadow>? shadows;
  final double rim;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.radius = AppRadius.xl,
    this.tint,
    this.onTap,
    this.blur = false,
    this.shadows,
    this.rim = 1,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    final dark = Glass.isDark(context);

    Widget surface = CustomPaint(
      foregroundPainter: GlassRimPainter(
        radius: radius,
        strength: tint != null ? rim * 0.5 : rim,
        dark: dark,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: r,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: Glass.fill(context, tint: tint),
      ),
      child: surface,
    );

    if (blur) {
      surface = ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: surface,
        ),
      );
    }

    surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: shadows ?? Glass.shadow(context),
      ),
      child: surface,
    );

    return onTap == null ? surface : PressableScale(child: surface);
  }
}

/// Encoge ligeramente su contenido mientras se presiona y lo suelta con un
/// pequeño rebote. No compite con los gestos del hijo (InkWell, scroll).
class PressableScale extends StatefulWidget {
  final Widget child;
  final double scale;
  final bool enabled;

  const PressableScale({
    super.key,
    required this.child,
    this.scale = 0.97,
    this.enabled = true,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;
  Offset? _origin;

  void _set(bool down) {
    if (_down != down && mounted) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Listener(
      onPointerDown: (e) {
        _origin = e.position;
        _set(true);
      },
      // Si el dedo se desplaza es un scroll, no una pulsación.
      onPointerMove: (e) {
        if (_origin != null && (e.position - _origin!).distance > 12) _set(false);
      },
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: Duration(milliseconds: _down ? 110 : 420),
        curve: _down ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

/// Entrada suave: aparece y sube unos píxeles. [delay] escalona listas.
class Reveal extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final double offset;

  const Reveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 18,
  });

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );
  late final Animation<double> _t =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return FadeTransition(
      opacity: _t,
      child: AnimatedBuilder(
        animation: _t,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, widget.offset * (1 - _t.value)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Fondo ambiental: degradado claro con manchas de luz carmesí.
/// Se pinta una sola vez (RepaintBoundary) y queda en caché.
class LiquidBackdrop extends StatelessWidget {
  final Widget child;

  const LiquidBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(painter: _AmbientPainter(dark: Glass.isDark(context))),
        ),
        child,
      ],
    );
  }
}

class _AmbientPainter extends CustomPainter {
  final bool dark;

  const _AmbientPainter({required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [Color(0xFF1C1316), Color(0xFF110B0D)]
              : const [Color(0xFFFFF8F8), Color(0xFFFBEEF0)],
        ).createShader(rect),
    );

    final w = size.width;
    final blobs = dark
        ? const [
            (Offset(1.05, -0.05), 0.95, Color(0x599E1B26)),
            (Offset(-0.2, 0.45), 0.85, Color(0x665A0016)),
            (Offset(0.9, 0.95), 0.9, Color(0x2EB71032)),
          ]
        : const [
            (Offset(1.05, -0.05), 0.95, Color(0x2EDA3148)),
            (Offset(-0.2, 0.40), 0.85, Color(0xE6FFDAD8)),
            (Offset(0.95, 0.90), 0.90, Color(0x66FFB3B4)),
            (Offset(0.10, -0.05), 0.60, Color(0x80FFE7DC)),
          ];

    for (final (at, r, color) in blobs) {
      final center = Offset(at.dx * w, at.dy * size.height);
      final radius = r * w;
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(_AmbientPainter old) => old.dark != dark;
}

/// Transición de página que pone el fondo ambiental detrás de cada ruta y
/// delega el movimiento en la transición nativa de cada plataforma
/// (en iOS conserva el gesto de deslizar para volver).
class LiquidPageTransitionsBuilder extends PageTransitionsBuilder {
  const LiquidPageTransitionsBuilder();

  static PageTransitionsBuilder get _inner => switch (defaultTargetPlatform) {
        TargetPlatform.iOS ||
        TargetPlatform.macOS =>
          const CupertinoPageTransitionsBuilder(),
        _ => const FadeForwardsPageTransitionsBuilder(),
      };

  @override
  Duration get transitionDuration => _inner.transitionDuration;

  @override
  Duration get reverseTransitionDuration => _inner.reverseTransitionDuration;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      _inner.delegatedTransition;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _inner.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      LiquidBackdrop(child: child),
    );
  }
}

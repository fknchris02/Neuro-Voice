import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';
import '../models/voice_prediction.dart';
import '../services/database_helper.dart';
import '../theme/app_theme.dart';
import '../theme/liquid_glass.dart';
import '../utils/formatters.dart';
import '../widgets/neuro_app_bar.dart';
import '../widgets/supervisor_card.dart';

/// Reporte de resultados (design/stitch/reporte).
class BiomarkerReportScreen extends StatefulWidget {
  final VoicePrediction prediction;
  final DateTime timestamp;
  final int? resultId;
  final bool saveFailed;

  /// Abierto desde el historial: el PDF del servidor solo cubre el último
  /// análisis, así que no se ofrece la descarga.
  final bool fromHistory;

  const BiomarkerReportScreen({
    super.key,
    required this.prediction,
    required this.timestamp,
    this.resultId,
    this.saveFailed = false,
    this.fromHistory = false,
  });

  @override
  State<BiomarkerReportScreen> createState() => _BiomarkerReportScreenState();
}

class _BiomarkerReportScreenState extends State<BiomarkerReportScreen> {
  final _biomarkersKey = GlobalKey();
  bool _isDownloading = false;
  bool _isSaving = false;
  late int? _resultId = widget.resultId;

  bool get _saved => _resultId != null;

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// Marcador: indica que el reporte está en el historial o reintenta
  /// guardarlo si falló.
  Future<void> _onBookmark() async {
    if (_saved) {
      _snack('Este reporte ya está guardado en tu historial.');
      return;
    }
    setState(() => _isSaving = true);
    try {
      final saved = await DatabaseHelper.instance
          .insertTestResult(widget.prediction.toTestResult(widget.timestamp));
      if (!mounted) return;
      setState(() => _resultId = saved.id);
      _snack('Reporte guardado en tu historial.');
    } catch (_) {
      if (mounted) _snack('No se pudo guardar el reporte. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _downloadReport() async {
    setState(() => _isDownloading = true);
    try {
      final ok = await launchUrl(
        ApiConfig.exportPdf,
        mode: LaunchMode.externalApplication,
      );
      if (!ok) throw Exception();
    } catch (_) {
      if (mounted) {
        _snack('No se pudo abrir el reporte PDF. Verifica la conexión con el servidor.');
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  void _scrollToBiomarkers() {
    final ctx = _biomarkersKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = widget.prediction;
    final risk = p.risk;

    return Scaffold(
      appBar: const NeuroAppBar(title: 'Detalle De Reporte Biomarcador'),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.margin, AppSpacing.xs, AppSpacing.margin, 40),
          children: [
            // Subencabezado: fecha · ID · guardado
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 18, color: scheme.primary),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    formatLongDate(widget.timestamp),
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                if (_resultId != null) ...[
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      'ID: PVD-${_resultId.toString().padLeft(6, '0')}',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.outline,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                IconButton(
                  tooltip: _saved ? 'Guardado en historial' : 'Guardar en historial',
                  onPressed: _isSaving ? null : _onBookmark,
                  style: IconButton.styleFrom(
                    backgroundColor: _saved
                        ? scheme.primaryFixed
                        : Colors.white.withValues(alpha: 0.7),
                    foregroundColor:
                        _saved ? scheme.onPrimaryFixedVariant : scheme.primary,
                  ),
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, a) =>
                        ScaleTransition(scale: a, child: child),
                    child: Icon(
                      _saved ? Icons.bookmark : Icons.bookmark_border,
                      key: ValueKey(_saved),
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Título y estado
            Row(
              children: [
                Expanded(
                  child: Text(
                    'EVALUACIÓN DIGITAL',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.secondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                GlassCard(
                  radius: 99,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  shadows: Glass.shadow(context, depth: 0.3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: risk.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        risk.label,
                        style: theme.textTheme.labelSmall?.copyWith(color: risk.color),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Reporte Biomarcador de Parkinson',
              style: theme.textTheme.headlineMedium?.copyWith(letterSpacing: -0.4),
            ),
            const SizedBox(height: AppSpacing.md),

            const Reveal(
              delay: Duration(milliseconds: 60),
              child: SupervisorCard(
                avatarRadius: 28,
                verified: true,
                status: 'Revisión médica pendiente',
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            const Reveal(
              delay: Duration(milliseconds: 120),
              child: _PipelineCard(),
            ),
            const SizedBox(height: AppSpacing.md),

            Reveal(
              delay: const Duration(milliseconds: 180),
              child: _ResultHero(
                  prediction: p, onShowBiomarkers: _scrollToBiomarkers),
            ),
            const SizedBox(height: 20),

            // Biomarcadores
            Row(
              key: _biomarkersKey,
              children: [
                Expanded(
                  child: Text('Biomarcadores Analizados',
                      style: theme.textTheme.titleLarge),
                ),
                Text(
                  '${biomarkerSpecs.length} Métricas clave',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Toca cada uno para ver qué significa.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final (i, spec) in biomarkerSpecs.indexed) ...[
              Reveal(
                delay: Duration(milliseconds: 260 + 50 * i),
                child: _BiomarkerTile(spec: spec, value: p.biomarkers[spec.key]),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            const SizedBox(height: AppSpacing.sm),

            Reveal(
              delay: const Duration(milliseconds: 560),
              child: _ConclusionCard(prediction: p),
            ),
            const SizedBox(height: 12),
            const _Disclaimer(),
            const SizedBox(height: 20),

            if (!widget.fromHistory)
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.secondary.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: FilledButton.icon(
                  onPressed: _isDownloading ? null : _downloadReport,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor: scheme.secondary,
                    foregroundColor: scheme.onSecondary,
                    textStyle: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  icon: _isDownloading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined, size: 22),
                  label: Text(
                    _isDownloading
                        ? 'Generando PDF…'
                        : 'Descargar Reporte PDF / Compartir con Médico',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Canal de Procesamiento Neuronal": 3 etapas automáticas completadas y
/// la revisión médica pendiente.
class _PipelineCard extends StatelessWidget {
  const _PipelineCard();

  static const _nodeWidth = 64.0;

  static const _steps = [
    (Icons.mic, 'Captura', true),
    (Icons.graphic_eq, 'MFCC', true),
    (Icons.memory, 'Inferencia IA', true),
    (Icons.schedule, 'Revisión médica', false),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final done = _steps.where((s) => s.$3).length;

    return GlassCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Canal de Procesamiento Neuronal',
                    style: theme.textTheme.labelMedium),
              ),
              Text(
                '$done de ${_steps.length} etapas',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            // Distancia entre centros del primer y último nodo.
            const inset = _nodeWidth / 2;
            final span = constraints.maxWidth - _nodeWidth;
            final progress = span * (done - 1) / (_steps.length - 1);
            return Stack(
              children: [
                Positioned(
                  left: inset,
                  right: inset,
                  top: 13,
                  child: Container(height: 2, color: scheme.primaryFixed),
                ),
                Positioned(
                  left: inset,
                  top: 13,
                  // La línea se llena al aparecer la tarjeta.
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 1100),
                    curve: Curves.easeOutCubic,
                    builder: (_, width, _) => Container(
                      height: 2,
                      width: width,
                      decoration: const BoxDecoration(gradient: Glass.crimson),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (icon, label, isDone) in _steps)
                      SizedBox(
                        width: _nodeWidth,
                        child: Column(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                gradient: isDone ? Glass.crimson : null,
                                color: isDone
                                    ? null
                                    : scheme.surfaceContainerHighest,
                                shape: BoxShape.circle,
                                border: isDone
                                    ? null
                                    : Border.all(color: scheme.surface, width: 2),
                                boxShadow: AppShadows.small,
                              ),
                              child: Icon(
                                icon,
                                size: 14,
                                color: isDone ? scheme.onPrimary : scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                height: 1.2,
                                fontWeight: isDone ? FontWeight.w500 : FontWeight.w700,
                                color: isDone ? scheme.onSurfaceVariant : scheme.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _ResultHero extends StatelessWidget {
  final VoicePrediction prediction;
  final VoidCallback onShowBiomarkers;

  const _ResultHero({required this.prediction, required this.onShowBiomarkers});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final risk = prediction.risk;
    final prob = prediction.probability.clamp(0, 100).round();
    final riskShort = switch (risk) {
      RiskLevel.low => 'Bajo',
      RiskLevel.moderate => 'Moderado',
      RiskLevel.high => 'Alto',
    };

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB8202F), AppColors.primaryContainer, AppColors.primary],
          stops: [0, 0.5, 1],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl + 4),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Brillos con degradados radiales (sin desenfoque costoso).
          const Positioned(
            right: -40,
            bottom: -40,
            child: _RadialGlow(size: 200, color: Color(0x80570010)),
          ),
          const Positioned(
            left: -50,
            top: -60,
            child: _RadialGlow(size: 180, color: Color(0x40FF6B81)),
          ),
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: GlassRimPainter(radius: AppRadius.xl + 4, strength: 0.55),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.record_voice_over,
                                    size: 14, color: AppColors.primaryFixed),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Prueba Vocal Sostenida',
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall
                                        ?.copyWith(color: AppColors.primaryFixed),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Análisis Fonatorio Acústico Completo',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Vocal /a/ sostenida · ${prediction.samples} muestras × 5 s',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: AppColors.onPrimaryContainer),
                          ),
                        ],
                      ),
                    ),
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      child: const Icon(Icons.auto_graph, color: Colors.white, size: 22),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      // El porcentaje cuenta desde 0 al abrir el reporte.
                      child: TweenAnimationBuilder<int>(
                        tween: IntTween(begin: 0, end: prob),
                        duration: const Duration(milliseconds: 1200),
                        curve: Curves.easeOutCubic,
                        builder: (_, value, _) => _HeroMetric(
                          label: 'Probabilidad estimada',
                          value: '$value%',
                          footnote: 'Calculada por el modelo de IA',
                          semantics: 'Probabilidad estimada $prob por ciento',
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _HeroMetric(
                        label: 'Nivel de riesgo',
                        value: riskShort,
                        badge: CircleAvatar(
                          radius: 8,
                          backgroundColor: risk.color,
                          child: Icon(risk.icon, size: 11, color: Colors.white),
                        ),
                        footnote: '${prediction.alertCount} de '
                            '${biomarkerSpecs.length} biomarcadores en atención',
                        semantics: risk.label,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Material(
                  color: Colors.white,
                  shape: const StadiumBorder(),
                  elevation: 4,
                  shadowColor: Colors.black26,
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: onShowBiomarkers,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 10, 10, 10),
                      child: Row(
                        children: [
                          const Icon(Icons.equalizer, size: 18, color: AppColors.primary),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Ver Biomarcadores Detallados',
                              style: theme.textTheme.labelMedium
                                  ?.copyWith(color: AppColors.primary),
                            ),
                          ),
                          const CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.primary,
                            child: Icon(Icons.arrow_downward, size: 16, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;
  final String footnote;
  final String semantics;
  final Widget? badge;

  const _HeroMetric({
    required this.label,
    required this.value,
    required this.footnote,
    required this.semantics,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$label: $semantics. $footnote',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm + 2),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.14),
              Colors.white.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: AppColors.onPrimaryContainer),
                  ),
                ),
                badge ??
                    const Icon(Icons.verified_outlined,
                        size: 14, color: AppColors.primaryFixed),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              footnote,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.primaryFixed,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BiomarkerTile extends StatelessWidget {
  final BiomarkerSpec spec;
  final double? value;

  const _BiomarkerTile({required this.spec, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final v = value;
    final alert = v != null && spec.isAlert(v);

    final (String tag, Color tagColor, Color tagBg) = v == null
        ? ('Sin dato', scheme.onSurfaceVariant, scheme.surfaceContainerHigh)
        : alert
            ? ('Atención', AppColors.riskModerate,
                AppColors.riskModerate.withValues(alpha: 0.12))
            : ('Normal', scheme.secondary, scheme.surfaceContainerHigh);

    return GlassCard(
      padding: EdgeInsets.zero,
      shadows: Glass.shadow(context, depth: 0.5),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          // Quita las líneas divisorias por defecto del ExpansionTile.
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.fromLTRB(AppSpacing.md, 6, 12, 6),
            childrenPadding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
            leading: CircleAvatar(
              radius: 22,
              backgroundColor: scheme.surfaceContainer,
              child: Icon(spec.icon, color: scheme.primary, size: 22),
            ),
            title: Text(spec.name, style: theme.textTheme.labelMedium),
            subtitle: Text(
              spec.shortDescription,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  v == null ? '—' : spec.format(v),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: tagBg,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: tagColor,
                    ),
                  ),
                ),
              ],
            ),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                spec.explanation,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
              const SizedBox(height: 8),
              Text(
                'Valor de referencia: ${spec.reference}',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Conclusión Asistida": mensaje del modelo, guía y observaciones.
class _ConclusionCard extends StatelessWidget {
  final VoicePrediction prediction;

  const _ConclusionCard({required this.prediction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final body = theme.textTheme.bodyMedium
        ?.copyWith(color: scheme.onSurfaceVariant, height: 1.45);

    return GlassCard(
      shadows: Glass.shadow(context, depth: 0.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: scheme.secondaryContainer,
            child: Icon(Icons.health_and_safety,
                size: 20, color: scheme.onSecondaryContainer),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Conclusión Asistida por IA', style: theme.textTheme.labelMedium),
                const SizedBox(height: 2),
                if (prediction.message.isNotEmpty)
                  Text(
                    prediction.message,
                    style: body?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                Text(prediction.risk.guidance, style: body),
                if (prediction.alerts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Observaciones:', style: theme.textTheme.labelMedium),
                  for (final a in prediction.alerts)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('•  $a', style: body),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 18, color: scheme.outline),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Este resultado es una herramienta de apoyo generada por un modelo '
            'de inteligencia artificial y no constituye un diagnóstico. Solo un '
            'profesional de la salud puede diagnosticar la enfermedad de Parkinson.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.outline, height: 1.4),
          ),
        ),
      ],
    );
  }
}

class _RadialGlow extends StatelessWidget {
  final double size;
  final Color color;

  const _RadialGlow({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
          ),
        ),
      ),
    );
  }
}

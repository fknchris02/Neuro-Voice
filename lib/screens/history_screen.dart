import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/test_result.dart';
import '../models/voice_prediction.dart';
import '../services/database_helper.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/neuro_app_bar.dart';
import 'biomarker_report_screen.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<TestResult>? _results;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await DatabaseHelper.instance.getAllTestResults();
      if (mounted) setState(() => _results = results);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<bool> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar evaluación?'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _delete(TestResult r) async {
    setState(() => _results!.remove(r));
    if (r.id != null) await DatabaseHelper.instance.deleteTestResult(r.id!);
  }

  void _openReport(TestResult r) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BiomarkerReportScreen(
          prediction: VoicePrediction.fromTestResult(r),
          timestamp: r.timestamp,
          resultId: r.id,
          fromHistory: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const NeuroAppBar(title: 'Historial'),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error) {
      return const _EmptyState(
        icon: Icons.error_outline,
        title: 'No se pudo cargar el historial',
        message: 'Cierra y vuelve a abrir la app para intentarlo de nuevo.',
      );
    }
    final results = _results;
    if (results == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (results.isEmpty) {
      return const _EmptyState(
        icon: Icons.insights_outlined,
        title: 'Aún no hay evaluaciones',
        message: 'Cuando completes una prueba, su resultado aparecerá aquí '
            'y podrás ver cómo evoluciona con el tiempo.',
      );
    }

    final voice = results.where((r) => r.testType == 'voice').toList();
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          if (voice.length >= 2) ...[
            _VoiceTrendCard(results: voice),
            const SizedBox(height: 24),
          ],
          Text(
            'Evaluaciones',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Desliza hacia la izquierda para eliminar.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          for (final r in results)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Dismissible(
                key: ValueKey(r.id ?? r.timestamp),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => _confirmDelete(),
                onDismissed: (_) => _delete(r),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.delete_outline,
                      color: theme.colorScheme.onError),
                ),
                child: _HistoryTile(
                  result: r,
                  onTap: r.testType == 'voice' ? () => _openReport(r) : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final TestResult result;
  final VoidCallback? onTap;

  const _HistoryTile({required this.result, this.onTap});

  static IconData _iconFor(String type) => switch (type) {
        'voice' => Icons.mic_none,
        'spiral' => Icons.draw_outlined,
        'gait' => Icons.directions_walk,
        'tapping' => Icons.touch_app_outlined,
        _ => Icons.analytics_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isVoice = result.testType == 'voice';
    final prediction =
        isVoice ? VoicePrediction.fromTestResult(result) : null;
    final accent = prediction?.risk.color ?? scheme.primary;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: accent.withValues(alpha: 0.12),
                child: Icon(_iconFor(result.testType), color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVoice ? 'Prueba de voz' : result.getTestName(),
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      formatRelativeDateTime(result.timestamp),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    prediction != null
                        ? '${prediction.probability.round()}%'
                        : '${result.overallScore.round()}/100',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                  Text(
                    prediction?.risk.label ?? 'Puntaje',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: prediction != null
                          ? accent
                          : scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Evolución de la probabilidad estimada en las últimas pruebas de voz.
class _VoiceTrendCard extends StatelessWidget {
  /// Resultados de voz ordenados del más reciente al más antiguo.
  final List<TestResult> results;

  const _VoiceTrendCard({required this.results});

  static const _maxPoints = 12;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final points = results
        .take(_maxPoints)
        .toList()
        .reversed
        .map((r) => (r, VoicePrediction.fromTestResult(r)))
        .toList();
    final last = points.last.$2.probability;
    final prev = points[points.length - 2].$2.probability;
    final delta = (last - prev).round();
    final improved = delta <= 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 20, 12),
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
                      Text(
                        'Tendencia de tu voz',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Probabilidad estimada en tus últimas '
                        '${points.length} pruebas',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (improved
                            ? AppColors.riskLow
                            : AppColors.riskModerate)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    delta == 0
                        ? 'Sin cambios'
                        : '${delta > 0 ? '▲' : '▼'} ${delta.abs()} pts',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color:
                          improved ? AppColors.riskLow : AppColors.riskModerate,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 100,
                  minX: 0,
                  maxX: (points.length - 1).toDouble(),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: 25,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: scheme.outlineVariant.withValues(alpha: 0.5),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  extraLinesData: ExtraLinesData(horizontalLines: [
                    HorizontalLine(
                      y: 50,
                      color: AppColors.riskHigh.withValues(alpha: 0.5),
                      strokeWidth: 1,
                      dashArray: [6, 4],
                    ),
                  ]),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 50,
                        reservedSize: 40,
                        getTitlesWidget: (value, _) => Text(
                          '${value.round()}%',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        reservedSize: 28,
                        getTitlesWidget: (value, _) {
                          final i = value.toInt();
                          if (i != value || i < 0 || i >= points.length) {
                            return const SizedBox.shrink();
                          }
                          // Con muchos puntos, mostrar solo algunas fechas.
                          if (points.length > 6 &&
                              i % 2 == 1 &&
                              i != points.length - 1) {
                            return const SizedBox.shrink();
                          }
                          final d = points[i].$1.timestamp;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${d.day}/${d.month}',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => spots
                          .map((s) => LineTooltipItem(
                                '${s.y.round()}%\n'
                                '${formatDate(points[s.x.toInt()].$1.timestamp)}',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < points.length; i++)
                          FlSpot(i.toDouble(),
                              points[i].$2.probability.clamp(0, 100).toDouble()),
                      ],
                      isCurved: true,
                      preventCurveOverShooting: true,
                      color: scheme.primary,
                      barWidth: 3,
                      belowBarData: BarAreaData(
                        show: true,
                        color: scheme.primary.withValues(alpha: 0.08),
                      ),
                      dotData: FlDotData(
                        getDotPainter: (spot, _, _, index) =>
                            FlDotCirclePainter(
                          radius: 5,
                          color: points[index].$2.risk.color,
                          strokeWidth: 2,
                          strokeColor: scheme.surface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 16,
                  height: 2,
                  color: AppColors.riskHigh.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 6),
                Text(
                  'Umbral de riesgo alto (50%)',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

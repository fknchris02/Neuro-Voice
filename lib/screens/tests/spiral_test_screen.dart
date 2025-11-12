import 'package:flutter/material.dart';
import 'dart:math' as math;

class SpiralTestScreen extends StatefulWidget {
  const SpiralTestScreen({super.key});

  @override
  State<SpiralTestScreen> createState() => _SpiralTestScreenState();
}

class _SpiralTestScreenState extends State<SpiralTestScreen> {
  final List<Offset> _points = [];
  bool _isDrawing = false;
  bool _testCompleted = false;
  double _tremor = 0.0;
  double _accuracy = 0.0;

  void _startTest() {
    setState(() {
      _points.clear();
      _isDrawing = true;
      _testCompleted = false;
    });
  }

  void _finishTest() {
    setState(() {
      _isDrawing = false;
      _testCompleted = true;
      _calculateResults();
    });
  }

  void _calculateResults() {
    // Algoritmo simple de análisis
    if (_points.length < 10) {
      _tremor = 0.0;
      _accuracy = 0.0;
      return;
    }

    // Calcular variaciones en la velocidad (simula detección de temblor)
    double totalVariation = 0.0;
    for (int i = 1; i < _points.length - 1; i++) {
      double dist1 = (_points[i] - _points[i - 1]).distance;
      double dist2 = (_points[i + 1] - _points[i]).distance;
      totalVariation += (dist1 - dist2).abs();
    }

    _tremor = (totalVariation / _points.length).clamp(0.0, 10.0);
    _accuracy = (100 - (_tremor * 10)).clamp(0.0, 100.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test de Espiral'),
        actions: [
          if (_isDrawing)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _finishTest,
              tooltip: 'Finalizar Test',
            ),
        ],
      ),
      body: Column(
        children: [
          // Instrucciones
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Column(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  _isDrawing
                      ? 'Dibuja una espiral desde el centro hacia afuera'
                      : 'Presiona "Iniciar Test" para comenzar',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),

          // Área de dibujo
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                  width: 2,
                ),
              ),
              child: GestureDetector(
                onPanStart: _isDrawing
                    ? (details) {
                  setState(() {
                    _points.add(details.localPosition);
                  });
                }
                    : null,
                onPanUpdate: _isDrawing
                    ? (details) {
                  setState(() {
                    _points.add(details.localPosition);
                  });
                }
                    : null,
                child: CustomPaint(
                  painter: SpiralPainter(
                    points: _points,
                    showGuide: !_isDrawing && !_testCompleted,
                  ),
                  child: Container(),
                ),
              ),
            ),
          ),

          // Resultados o botón de inicio
          if (_testCompleted)
            _ResultsPanel(
              tremor: _tremor,
              accuracy: _accuracy,
              onRetry: _startTest,
              onSave: () {
                // Guardar resultados
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Resultados guardados exitosamente'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                Navigator.pop(context);
              },
            )
          else if (!_isDrawing)
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: _startTest,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Iniciar Test'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Puntos registrados: ${_points.length}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _finishTest,
                    icon: const Icon(Icons.check),
                    label: const Text('Finalizar y Analizar'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
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

class SpiralPainter extends CustomPainter {
  final List<Offset> points;
  final bool showGuide;

  SpiralPainter({
    required this.points,
    required this.showGuide,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Dibujar guía de espiral
    if (showGuide) {
      final guidePaint = Paint()
        ..color = Colors.grey.withOpacity(0.3)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      final center = Offset(size.width / 2, size.height / 2);
      final path = Path();

      for (double t = 0; t < 6 * math.pi; t += 0.1) {
        final radius = t * 15;
        final x = center.dx + radius * math.cos(t);
        final y = center.dy + radius * math.sin(t);

        if (t == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(path, guidePaint);
    }

    // Dibujar el trazo del usuario
    if (points.isNotEmpty) {
      final paint = Paint()
        ..color = Colors.blue
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      path.moveTo(points[0].dx, points[0].dy);

      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _ResultsPanel extends StatelessWidget {
  final double tremor;
  final double accuracy;
  final VoidCallback onRetry;
  final VoidCallback onSave;

  const _ResultsPanel({
    required this.tremor,
    required this.accuracy,
    required this.onRetry,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Resultados del Test',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  title: 'Temblor',
                  value: tremor.toStringAsFixed(1),
                  unit: 'Hz',
                  icon: Icons.show_chart,
                  color: tremor < 3 ? Colors.green : tremor < 6 ? Colors.orange : Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  title: 'Precisión',
                  value: accuracy.toStringAsFixed(0),
                  unit: '%',
                  icon: Icons.track_changes,
                  color: accuracy > 70 ? Colors.green : accuracy > 50 ? Colors.orange : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _AssessmentCard(
            tremor: tremor,
            accuracy: accuracy,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AssessmentCard extends StatelessWidget {
  final double tremor;
  final double accuracy;

  const _AssessmentCard({
    required this.tremor,
    required this.accuracy,
  });

  @override
  Widget build(BuildContext context) {
    String assessment;
    IconData icon;
    Color color;

    if (tremor < 3 && accuracy > 70) {
      assessment = 'Bajo riesgo de temblor. Resultados dentro de los parámetros normales.';
      icon = Icons.check_circle;
      color = Colors.green;
    } else if (tremor < 6 && accuracy > 50) {
      assessment = 'Temblor leve detectado. Se recomienda seguimiento periódico.';
      icon = Icons.warning;
      color = Colors.orange;
    } else {
      assessment = 'Temblor significativo detectado. Consulte con su médico.';
      icon = Icons.error;
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Evaluación',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  assessment,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
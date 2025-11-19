import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;

class TappingTestScreen extends StatefulWidget {
  const TappingTestScreen({super.key});

  @override
  State<TappingTestScreen> createState() => _TappingTestScreenState();
}

class _TappingTestScreenState extends State<TappingTestScreen> with TickerProviderStateMixin {
  // Estados del test
  bool _isTestActive = false;
  bool _testCompleted = false;
  bool _isAnalyzing = false;

  // Timer del test
  Timer? _testTimer;
  int _remainingSeconds = 10; // Test de 10 segundos
  static const int _testDuration = 10;

  // Datos de tapping
  int _tapCount = 0;
  List<DateTime> _tapTimestamps = [];
  List<Offset> _tapPositions = [];

  // Métricas calculadas
  double _tapsPerSecond = 0.0;
  double _rhythm = 0.0;          // Regularidad del ritmo (0-100)
  double _precision = 0.0;       // Precisión de posición (0-100)
  double _fatigue = 0.0;         // Fatiga detectada (0-100)
  double _coordination = 0.0;    // Coordinación general (0-100)

  // Análisis de intervalos
  List<double> _tapIntervals = [];
  double _avgInterval = 0.0;
  double _intervalVariation = 0.0;

  // Área de tapping
  final GlobalKey _tappingAreaKey = GlobalKey();
  Offset? _targetCenter;
  static const double targetRadius = 40.0;

  // Animaciones
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _tapAnimationController;

  // Feedback visual
  List<TapFeedback> _tapFeedbacks = [];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateTargetCenter();
    });
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _tapAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  void _calculateTargetCenter() {
    final RenderBox? renderBox = _tappingAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      setState(() {
        _targetCenter = Offset(
          renderBox.size.width / 2,
          renderBox.size.height / 2,
        );
      });
    }
  }

  void _startTest() {
    setState(() {
      _isTestActive = true;
      _testCompleted = false;
      _remainingSeconds = _testDuration;
      _tapCount = 0;
      _tapTimestamps.clear();
      _tapPositions.clear();
      _tapFeedbacks.clear();
      _tapIntervals.clear();
    });

    _startTimer();
  }

  void _startTimer() {
    _testTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _remainingSeconds--;
        });

        if (_remainingSeconds <= 0) {
          _stopTest();
        }
      }
    });
  }

  void _stopTest() {
    _testTimer?.cancel();

    setState(() {
      _isTestActive = false;
    });

    _analyzeData();
  }

  void _handleTap(TapDownDetails details) {
    if (!_isTestActive) return;

    final now = DateTime.now();
    final position = details.localPosition;

    setState(() {
      _tapCount++;
      _tapTimestamps.add(now);
      _tapPositions.add(position);

      // Agregar feedback visual
      _tapFeedbacks.add(TapFeedback(
        position: position,
        timestamp: now,
      ));

      // Limpiar feedbacks antiguos
      _tapFeedbacks.removeWhere((feedback) {
        return now.difference(feedback.timestamp).inMilliseconds > 500;
      });
    });

    // Calcular intervalo con el tap anterior
    if (_tapTimestamps.length > 1) {
      final interval = now.difference(_tapTimestamps[_tapTimestamps.length - 2]).inMilliseconds;
      _tapIntervals.add(interval.toDouble());
    }

    // Vibración/feedback
    _tapAnimationController.forward(from: 0);
  }

  Future<void> _analyzeData() async {
    setState(() {
      _isAnalyzing = true;
    });

    await Future.delayed(const Duration(seconds: 2));

    _calculateMetrics();

    setState(() {
      _isAnalyzing = false;
      _testCompleted = true;
    });
  }

  void _calculateMetrics() {
    if (_tapTimestamps.isEmpty) return;

    // 1. TAPS POR SEGUNDO
    _tapsPerSecond = _tapCount / _testDuration;

    // 2. RITMO (regularidad de intervalos)
    if (_tapIntervals.length > 1) {
      _avgInterval = _tapIntervals.reduce((a, b) => a + b) / _tapIntervals.length;

      double sumSquaredDiff = 0;
      for (var interval in _tapIntervals) {
        sumSquaredDiff += math.pow(interval - _avgInterval, 2);
      }
      double variance = sumSquaredDiff / _tapIntervals.length;
      double stdDev = math.sqrt(variance);

      // Menor desviación = mejor ritmo
      _intervalVariation = stdDev;
      _rhythm = (100 - (stdDev / _avgInterval * 100)).clamp(0.0, 100.0);
    } else {
      _rhythm = 0.0;
    }

    // 3. PRECISIÓN (cercanía al centro)
    if (_tapPositions.isNotEmpty && _targetCenter != null) {
      List<double> distances = _tapPositions.map((pos) {
        return (pos - _targetCenter!).distance;
      }).toList();

      double avgDistance = distances.reduce((a, b) => a + b) / distances.length;

      // Normalizar: 0 distancia = 100%, radio completo = 0%
      _precision = (100 - (avgDistance / targetRadius * 50)).clamp(0.0, 100.0);
    } else {
      _precision = 0.0;
    }

    // 4. FATIGA (degradación del rendimiento)
    if (_tapIntervals.length >= 4) {
      // Comparar primera mitad vs segunda mitad
      int midPoint = _tapIntervals.length ~/ 2;
      List<double> firstHalf = _tapIntervals.sublist(0, midPoint);
      List<double> secondHalf = _tapIntervals.sublist(midPoint);

      double avgFirstHalf = firstHalf.reduce((a, b) => a + b) / firstHalf.length;
      double avgSecondHalf = secondHalf.reduce((a, b) => a + b) / secondHalf.length;

      // Si la segunda mitad es más lenta, hay fatiga
      double slowdown = ((avgSecondHalf - avgFirstHalf) / avgFirstHalf * 100).clamp(-100.0, 100.0);
      _fatigue = slowdown.clamp(0.0, 100.0);
    } else {
      _fatigue = 0.0;
    }

    // 5. COORDINACIÓN GENERAL (promedio de métricas)
    double speedScore = (_tapsPerSecond / 5 * 100).clamp(0.0, 100.0); // 5 taps/seg = 100%
    double rhythmScore = _rhythm;
    double precisionScore = _precision;
    double fatigueScore = 100 - _fatigue; // Invertir: menos fatiga = mejor

    _coordination = ((speedScore + rhythmScore + precisionScore + fatigueScore) / 4)
        .clamp(0.0, 100.0);
  }

  void _resetTest() {
    setState(() {
      _isTestActive = false;
      _testCompleted = false;
      _isAnalyzing = false;
      _remainingSeconds = _testDuration;
      _tapCount = 0;
      _tapTimestamps.clear();
      _tapPositions.clear();
      _tapFeedbacks.clear();
      _tapIntervals.clear();
      _tapsPerSecond = 0.0;
      _rhythm = 0.0;
      _precision = 0.0;
      _fatigue = 0.0;
      _coordination = 0.0;
    });
  }

  @override
  void dispose() {
    _testTimer?.cancel();
    _pulseController.dispose();
    _tapAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test de Tapping'),
        actions: [
          if (_testCompleted)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetTest,
              tooltip: 'Reiniciar',
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
                  Icons.touch_app,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  _getInstructionText(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (!_testCompleted)
                    _buildTestArea()
                  else
                    _buildResults(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getInstructionText() {
    if (_isTestActive) {
      return 'Toca el círculo lo más rápido posible - $_remainingSeconds segundos';
    } else if (_testCompleted) {
      return 'Test completado';
    } else {
      return 'Toca el círculo naranja lo más rápido y preciso posible durante 10 segundos';
    }
  }

  Widget _buildTestArea() {
    return Column(
      children: [
        // Contador/Timer
        if (_isTestActive)
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      _remainingSeconds.toString(),
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Text(
                      'segundos',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                Container(
                  width: 2,
                  height: 60,
                  color: Theme.of(context).colorScheme.outline,
                ),
                Column(
                  children: [
                    Text(
                      _tapCount.toString(),
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                    Text(
                      'toques',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
            ),
          ),

        // Área de tapping
        if (_isTestActive)
          GestureDetector(
            onTapDown: _handleTap,
            child: Container(
              key: _tappingAreaKey,
              height: 400,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFF59E0B),
                  width: 3,
                ),
              ),
              child: Stack(
                children: [
                  // Círculo objetivo
                  if (_targetCenter != null)
                    Positioned(
                      left: _targetCenter!.dx - targetRadius,
                      top: _targetCenter!.dy - targetRadius,
                      child: ScaleTransition(
                        scale: _pulseAnimation,
                        child: Container(
                          width: targetRadius * 2,
                          height: targetRadius * 2,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFFF59E0B),
                                const Color(0xFFF59E0B).withOpacity(0.6),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF59E0B).withOpacity(0.5),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.touch_app,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Efectos de tap
                  ..._tapFeedbacks.map((feedback) => _TapEffect(
                    position: feedback.position,
                    timestamp: feedback.timestamp,
                  )),
                ],
              ),
            ),
          ),

        // Botón de inicio
        if (!_isTestActive && !_isAnalyzing)
          Container(
            margin: const EdgeInsets.only(top: 24),
            child: ScaleTransition(
              scale: _pulseAnimation,
              child: GestureDetector(
                onTap: _startTest,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFF59E0B),
                        Color(0xFFF97316),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_arrow, size: 48, color: Colors.white),
                      SizedBox(height: 8),
                      Text(
                        'INICIAR',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Analizando
        if (_isAnalyzing)
          Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Analizando coordinación motora...',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildResults() {
    return Column(
      children: [
        // Puntuación general
        _buildOverallScore(),

        const SizedBox(height: 24),

        // Métricas en grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: [
            _MetricCard(
              title: 'Velocidad',
              value: _tapsPerSecond.toStringAsFixed(1),
              unit: 'tap/s',
              icon: Icons.speed,
              color: _getSpeedColor(),
              normalRange: '4-6',
            ),
            _MetricCard(
              title: 'Ritmo',
              value: _rhythm.toStringAsFixed(0),
              unit: '%',
              icon: Icons.graphic_eq,
              color: _getRhythmColor(),
              normalRange: '> 70%',
            ),
            _MetricCard(
              title: 'Precisión',
              value: _precision.toStringAsFixed(0),
              unit: '%',
              icon: Icons.my_location,
              color: _getPrecisionColor(),
              normalRange: '> 60%',
            ),
            _MetricCard(
              title: 'Fatiga',
              value: _fatigue.toStringAsFixed(0),
              unit: '%',
              icon: Icons.trending_down,
              color: _getFatigueColor(),
              normalRange: '< 30%',
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Detalles adicionales
        _buildDetailsCard(),

        const SizedBox(height: 24),

        // Evaluación
        _buildAssessment(),

        const SizedBox(height: 24),

        // Botones
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _resetTest,
                icon: const Icon(Icons.refresh),
                label: const Text('Repetir'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _saveResults,
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
    );
  }

  Widget _buildOverallScore() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getCoordinationColor(),
            _getCoordinationColor().withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _getCoordinationColor().withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Coordinación Motora',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${_coordination.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 64,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getCoordinationLabel(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.touch_app, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                '$_tapCount toques en $_testDuration segundos',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detalles del Análisis',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _DetailRow(
            label: 'Total de toques',
            value: '$_tapCount',
          ),
          _DetailRow(
            label: 'Intervalo promedio',
            value: '${_avgInterval.toStringAsFixed(0)} ms',
          ),
          _DetailRow(
            label: 'Variación de intervalo',
            value: '${_intervalVariation.toStringAsFixed(0)} ms',
          ),
          _DetailRow(
            label: 'Toques por segundo',
            value: _tapsPerSecond.toStringAsFixed(2),
          ),
        ],
      ),
    );
  }

  Widget _buildAssessment() {
    String assessment;
    IconData icon;
    Color color;

    if (_coordination >= 75) {
      assessment = 'Excelente coordinación motora fina. No se detectan anomalías en la velocidad ni precisión.';
      icon = Icons.check_circle;
      color = Colors.green;
    } else if (_coordination >= 50) {
      assessment = 'Coordinación motora adecuada con algunas irregularidades. Se recomienda seguimiento.';
      icon = Icons.warning;
      color = Colors.orange;
    } else {
      assessment = 'Coordinación motora reducida detectada. Se recomienda consultar con un especialista.';
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

  Color _getSpeedColor() {
    if (_tapsPerSecond >= 4 && _tapsPerSecond <= 6) return Colors.green;
    if (_tapsPerSecond >= 3 && _tapsPerSecond <= 7) return Colors.orange;
    return Colors.red;
  }

  Color _getRhythmColor() {
    if (_rhythm >= 70) return Colors.green;
    if (_rhythm >= 50) return Colors.orange;
    return Colors.red;
  }

  Color _getPrecisionColor() {
    if (_precision >= 60) return Colors.green;
    if (_precision >= 40) return Colors.orange;
    return Colors.red;
  }

  Color _getFatigueColor() {
    if (_fatigue < 30) return Colors.green;
    if (_fatigue < 50) return Colors.orange;
    return Colors.red;
  }

  Color _getCoordinationColor() {
    if (_coordination >= 75) return Colors.green;
    if (_coordination >= 50) return Colors.orange;
    return Colors.red;
  }

  String _getCoordinationLabel() {
    if (_coordination >= 75) return 'Excelente';
    if (_coordination >= 50) return 'Moderado';
    return 'Requiere atención';
  }

  void _saveResults() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Resultados guardados exitosamente'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context);
  }
}

// Clase para feedback de tap
class TapFeedback {
  final Offset position;
  final DateTime timestamp;

  TapFeedback({
    required this.position,
    required this.timestamp,
  });
}

// Widget de efecto visual de tap
class _TapEffect extends StatefulWidget {
  final Offset position;
  final DateTime timestamp;

  const _TapEffect({
    required this.position,
    required this.timestamp,
  });

  @override
  State<_TapEffect> createState() => _TapEffectState();
}

class _TapEffectState extends State<_TapEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 2.0).animate(_controller);
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: widget.position.dx - 20,
          top: widget.position.dy - 20,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFF59E0B),
                    width: 3,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Widget de tarjeta de métrica
class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final String normalRange;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    required this.normalRange,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Row(
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
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color,
                  ),
                ),
              ],
            ],
          ),
          Text(
            'Normal: $normalRange',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// Widget de fila de detalle
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
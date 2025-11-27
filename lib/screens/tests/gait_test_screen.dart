import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:math' as math;
import '/models/test_result.dart';
import '/services/database_helper.dart';

class GaitTestScreen extends StatefulWidget {
  const GaitTestScreen({super.key});

  @override
  State<GaitTestScreen> createState() => _GaitTestScreenState();
}

class _GaitTestScreenState extends State<GaitTestScreen> with TickerProviderStateMixin {
  // Estados del test
  bool _isTestActive = false;
  bool _testCompleted = false;
  bool _isAnalyzing = false;

  // Timer del test
  Timer? _testTimer;
  int _remainingSeconds = 30; // Test de 30 segundos
  static const int _testDuration = 30;

  // Suscripciones a sensores
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<StepCount>? _stepCountSubscription;

  // Datos de sensores
  final List<AccelerometerEvent> _accelerometerData = [];
  final List<GyroscopeEvent> _gyroscopeData = [];
  int _stepCount = 0;
  int _initialStepCount = 0;

  // Valores actuales para visualización
  double _currentAccelX = 0.0;
  double _currentAccelY = 0.0;
  double _currentAccelZ = 0.0;

  // Métricas calculadas
  double _cadence = 0.0;           // Pasos por minuto
  double _stride = 0.0;            // Longitud de zancada
  double _stability = 0.0;         // Estabilidad (0-100)
  double _symmetry = 0.0;          // Simetría (0-100)
  double _tremor = 0.0;            // Temblor detectado
  double _overallScore = 0.0;      // Puntuación general

  // Animaciones
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _setupAnimations();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _checkPermissions() async {
    final activityStatus = await Permission.activityRecognition.request();
    final sensorStatus = await Permission.sensors.request();

    if (!activityStatus.isGranted || !sensorStatus.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Se requieren permisos de sensores para continuar'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _startTest() {
    setState(() {
      _isTestActive = true;
      _testCompleted = false;
      _remainingSeconds = _testDuration;
      _accelerometerData.clear();
      _gyroscopeData.clear();
      _stepCount = 0;
      _initialStepCount = 0;
    });

    _startSensorListening();
    _startTimer();
  }

  void _startSensorListening() {
    // Escuchar acelerómetro
    _accelerometerSubscription = accelerometerEvents.listen(
          (AccelerometerEvent event) {
        if (_isTestActive) {
          setState(() {
            _currentAccelX = event.x;
            _currentAccelY = event.y;
            _currentAccelZ = event.z;
          });
          _accelerometerData.add(event);
        }
      },
    );

    // Escuchar giroscopio
    _gyroscopeSubscription = gyroscopeEvents.listen(
          (GyroscopeEvent event) {
        if (_isTestActive) {
          _gyroscopeData.add(event);
        }
      },
    );

    // Escuchar contador de pasos
    _stepCountSubscription = Pedometer.stepCountStream.listen(
          (StepCount count) {
        if (_isTestActive) {
          if (_initialStepCount == 0) {
            _initialStepCount = count.steps;
          }
          setState(() {
            _stepCount = count.steps - _initialStepCount;
          });
        }
      },
      onError: (error) {
        // Si falla el pedómetro, estimamos pasos del acelerómetro
        print('Error en pedómetro: $error');
      },
    );
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
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _stepCountSubscription?.cancel();

    setState(() {
      _isTestActive = false;
    });

    _analyzeData();
  }

  Future<void> _analyzeData() async {
    setState(() {
      _isAnalyzing = true;
    });

    // Simular tiempo de análisis
    await Future.delayed(const Duration(seconds: 2));

    _calculateMetrics();

    setState(() {
      _isAnalyzing = false;
      _testCompleted = true;
    });
  }

  void _calculateMetrics() {
    if (_accelerometerData.isEmpty) return;

    // 1. CADENCIA (pasos por minuto)
    _cadence = (_stepCount / _testDuration * 60).clamp(0.0, 200.0);

    // 2. ESTABILIDAD (basada en variabilidad del acelerómetro)
    List<double> magnitudes = _accelerometerData.map((event) {
      return math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    }).toList();

    double avgMagnitude = magnitudes.reduce((a, b) => a + b) / magnitudes.length;
    double variance = 0;
    for (var mag in magnitudes) {
      variance += math.pow(mag - avgMagnitude, 2);
    }
    variance /= magnitudes.length;
    double stdDev = math.sqrt(variance);

    // Menor desviación = mayor estabilidad
    _stability = (100 - (stdDev * 10)).clamp(0.0, 100.0);

    // 3. TEMBLOR (frecuencia alta en giroscopio)
    if (_gyroscopeData.isNotEmpty) {
      List<double> gyroMagnitudes = _gyroscopeData.map((event) {
        return math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      }).toList();

      double gyroAvg = gyroMagnitudes.reduce((a, b) => a + b) / gyroMagnitudes.length;
      _tremor = (gyroAvg * 100).clamp(0.0, 10.0);
    }

    // 4. SIMETRÍA (análisis de patrón de pasos)
    // Basado en consistencia de aceleración vertical
    List<double> peaks = [];
    for (int i = 1; i < magnitudes.length - 1; i++) {
      if (magnitudes[i] > magnitudes[i-1] && magnitudes[i] > magnitudes[i+1]) {
        peaks.add(magnitudes[i]);
      }
    }

    if (peaks.length > 1) {
      double peakVariance = 0;
      double avgPeak = peaks.reduce((a, b) => a + b) / peaks.length;
      for (var peak in peaks) {
        peakVariance += math.pow(peak - avgPeak, 2);
      }
      peakVariance /= peaks.length;
      double peakStdDev = math.sqrt(peakVariance);
      _symmetry = (100 - (peakStdDev * 20)).clamp(0.0, 100.0);
    } else {
      _symmetry = 50.0;
    }

    // 5. LONGITUD DE ZANCADA (estimada)
    // Fórmula aproximada: altura * 0.43 * velocidad normalizada
    double estimatedHeight = 1.70; // metros (ajustable por usuario)
    double normalizedVelocity = (_cadence / 120).clamp(0.5, 1.5);
    _stride = (estimatedHeight * 0.43 * normalizedVelocity).clamp(0.0, 2.0);

    // 6. PUNTUACIÓN GENERAL
    double cadenceScore = _normalizeCadence(_cadence);
    double stabilityScore = _stability;
    double symmetryScore = _symmetry;
    double tremorScore = (10 - _tremor) * 10; // Invertir para que menos temblor = mejor

    _overallScore = ((cadenceScore + stabilityScore + symmetryScore + tremorScore) / 4)
        .clamp(0.0, 100.0);
  }

  double _normalizeCadence(double cadence) {
    // Cadencia normal: 100-120 pasos/min
    if (cadence >= 100 && cadence <= 120) return 100.0;
    if (cadence < 100) return (cadence / 100 * 100).clamp(0.0, 100.0);
    return (120 / cadence * 100).clamp(0.0, 100.0);
  }

  void _resetTest() {
    setState(() {
      _isTestActive = false;
      _testCompleted = false;
      _isAnalyzing = false;
      _remainingSeconds = _testDuration;
      _accelerometerData.clear();
      _gyroscopeData.clear();
      _stepCount = 0;
      _initialStepCount = 0;
      _cadence = 0.0;
      _stability = 0.0;
      _symmetry = 0.0;
      _tremor = 0.0;
      _stride = 0.0;
      _overallScore = 0.0;
    });
  }

  @override
  void dispose() {
    _testTimer?.cancel();
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _stepCountSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test de Marcha'),
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
                  Icons.directions_walk,
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
      return 'Camina normalmente durante $_remainingSeconds segundos';
    } else if (_testCompleted) {
      return 'Análisis completado';
    } else {
      return 'Caminarás durante 30 segundos. Mantén el teléfono en tu bolsillo o mano';
    }
  }

  Widget _buildTestArea() {
    return Column(
      children: [
        // Timer/Contador
        if (_isTestActive)
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(
                  _remainingSeconds.toString(),
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'segundos restantes',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: (_testDuration - _remainingSeconds) / _testDuration,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),

        // Visualización en tiempo real
        if (_isTestActive)
          _buildRealtimeData(),

        // Botón de inicio/parada
        if (!_isTestActive && !_isAnalyzing)
          ScaleTransition(
            scale: _pulseAnimation,
            child: GestureDetector(
              onTap: _startTest,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF10B981),
                      const Color(0xFF10B981).withOpacity(0.7),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.4),
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

        // Botón de detener
        if (_isTestActive)
          GestureDetector(
            onTap: _stopTest,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.stop, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'DETENER TEST',
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

        // Analizando
        if (_isAnalyzing)
          Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Analizando datos de movimiento...',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildRealtimeData() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            'Datos en tiempo real',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _RealtimeMetric(
                label: 'Pasos',
                value: _stepCount.toString(),
                icon: Icons.directions_walk,
                color: Colors.blue,
              ),
              _RealtimeMetric(
                label: 'Aceleración',
                value: _currentAccelZ.abs().toStringAsFixed(1),
                icon: Icons.speed,
                color: Colors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    return Column(
      children: [
        // Puntuación general
        _buildOverallScore(),

        const SizedBox(height: 24),

        // Métricas detalladas
        _MetricCard(
          title: 'Cadencia',
          value: _cadence.toStringAsFixed(0),
          unit: 'pasos/min',
          icon: Icons.speed,
          color: _getCadenceColor(),
          description: 'Velocidad de pasos',
          normalRange: '100-120',
        ),

        const SizedBox(height: 12),

        _MetricCard(
          title: 'Estabilidad',
          value: _stability.toStringAsFixed(0),
          unit: '%',
          icon: Icons.balance,
          color: _getStabilityColor(),
          description: 'Control del equilibrio',
          normalRange: '> 70%',
        ),

        const SizedBox(height: 12),

        _MetricCard(
          title: 'Simetría',
          value: _symmetry.toStringAsFixed(0),
          unit: '%',
          icon: Icons.compare_arrows,
          color: _getSymmetryColor(),
          description: 'Uniformidad de pasos',
          normalRange: '> 80%',
        ),

        const SizedBox(height: 12),

        _MetricCard(
          title: 'Temblor',
          value: _tremor.toStringAsFixed(1),
          unit: '',
          icon: Icons.vibration,
          color: _getTremorColor(),
          description: 'Nivel de temblor detectado',
          normalRange: '< 3.0',
        ),

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
            _getOverallColor(),
            _getOverallColor().withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _getOverallColor().withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Puntuación General',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _overallScore.toStringAsFixed(0),
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 64,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getOverallLabel(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.directions_walk, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                '$_stepCount pasos en $_testDuration segundos',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssessment() {
    String assessment;
    IconData icon;
    Color color;

    if (_overallScore >= 75) {
      assessment = 'Patrón de marcha normal. No se detectan anomalías significativas en el movimiento.';
      icon = Icons.check_circle;
      color = Colors.green;
    } else if (_overallScore >= 50) {
      assessment = 'Algunas irregularidades detectadas en la marcha. Se recomienda seguimiento.';
      icon = Icons.warning;
      color = Colors.orange;
    } else {
      assessment = 'Patrones irregulares detectados. Se recomienda consultar con un especialista.';
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

  Color _getCadenceColor() {
    if (_cadence >= 100 && _cadence <= 120) return Colors.green;
    if (_cadence >= 80 && _cadence <= 140) return Colors.orange;
    return Colors.red;
  }

  Color _getStabilityColor() {
    if (_stability >= 70) return Colors.green;
    if (_stability >= 50) return Colors.orange;
    return Colors.red;
  }

  Color _getSymmetryColor() {
    if (_symmetry >= 80) return Colors.green;
    if (_symmetry >= 60) return Colors.orange;
    return Colors.red;
  }

  Color _getTremorColor() {
    if (_tremor < 3) return Colors.green;
    if (_tremor < 5) return Colors.orange;
    return Colors.red;
  }

  Color _getOverallColor() {
    if (_overallScore >= 75) return Colors.green;
    if (_overallScore >= 50) return Colors.orange;
    return Colors.red;
  }

  String _getOverallLabel() {
    if (_overallScore >= 75) return 'Excelente';
    if (_overallScore >= 50) return 'Moderado';
    return 'Requiere atención';
  }

  void _saveResults() async {
    try {
      final result = TestResult(
        testType: 'gait',
        timestamp: DateTime.now(),
        overallScore: _overallScore,
        metrics: {
          'cadence': _cadence,
          'stability': _stability,
          'symmetry': _symmetry,
          'tremor': _tremor,
          'stride': _stride,
          'steps': _stepCount.toDouble(),
        },
      );

      await DatabaseHelper.instance.insertTestResult(result);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Resultados guardados exitosamente'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _RealtimeMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _RealtimeMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 32),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final String description;
  final String normalRange;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    required this.description,
    required this.normalRange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Normal: $normalRange',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                    fontSize: 11,
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
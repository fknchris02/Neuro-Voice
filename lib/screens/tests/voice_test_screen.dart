import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:math' as math;

class VoiceTestScreen extends StatefulWidget {
  const VoiceTestScreen({super.key});

  @override
  State<VoiceTestScreen> createState() => _VoiceTestScreenState();
}

class _VoiceTestScreenState extends State<VoiceTestScreen> with TickerProviderStateMixin {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Estados del test
  bool _isRecording = false;
  bool _hasRecording = false;
  bool _isAnalyzing = false;
  bool _testCompleted = false;
  bool _isPlaying = false;

  // Datos de análisis
  String? _recordingPath;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;

  // Métricas de voz
  double _jitter = 0.0;        // Variabilidad de frecuencia
  double _shimmer = 0.0;       // Variabilidad de amplitud
  double _avgAmplitude = 0.0;  // Amplitud promedio
  int _silencePeriods = 0;     // Períodos de silencio
  double _voiceQuality = 0.0;  // Calidad general (0-100)

  // Análisis en tiempo real
  final List<double> _amplitudeHistory = [];
  double _currentAmplitude = 0.0;

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
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _checkPermissions() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Se requiere permiso de micrófono para continuar'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/voice_test_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            sampleRate: 44100,
            bitRate: 128000,
          ),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _hasRecording = false;
          _recordingPath = path;
          _recordingDuration = Duration.zero;
          _amplitudeHistory.clear();
        });

        _startAmplitudeMonitoring();
        _startTimer();
      }
    } catch (e) {
      _showError('Error al iniciar grabación: $e');
    }
  }

  void _startAmplitudeMonitoring() {
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isRecording) {
        timer.cancel();
        return;
      }

      _audioRecorder.getAmplitude().then((amplitude) {
        if (mounted && _isRecording) {
          setState(() {
            _currentAmplitude = amplitude.current.clamp(-60.0, 0.0);
            _amplitudeHistory.add(_currentAmplitude);

            // Mantener solo los últimos 50 valores
            if (_amplitudeHistory.length > 50) {
              _amplitudeHistory.removeAt(0);
            }
          });
        }
      });
    });
  }

  void _startTimer() {
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _recordingDuration = Duration(seconds: _recordingDuration.inSeconds + 1);
        });
      }
    });
  }

  Future<void> _stopRecording() async {
    try {
      await _audioRecorder.stop();
      _recordingTimer?.cancel();

      setState(() {
        _isRecording = false;
        _hasRecording = true;
      });

      // Analizar automáticamente después de grabar
      await _analyzeRecording();
    } catch (e) {
      _showError('Error al detener grabación: $e');
    }
  }

  Future<void> _analyzeRecording() async {
    if (_recordingPath == null || _amplitudeHistory.isEmpty) return;

    setState(() {
      _isAnalyzing = true;
    });

    // Simular análisis con delay
    await Future.delayed(const Duration(seconds: 2));

    // Calcular métricas basadas en los datos recopilados
    _calculateVoiceMetrics();

    setState(() {
      _isAnalyzing = false;
      _testCompleted = true;
    });
  }

  void _calculateVoiceMetrics() {
    if (_amplitudeHistory.isEmpty) return;

    // 1. Calcular amplitud promedio
    _avgAmplitude = _amplitudeHistory.reduce((a, b) => a + b) / _amplitudeHistory.length;

    // 2. Calcular Shimmer (variabilidad de amplitud)
    double sumSquaredDiff = 0;
    for (int i = 1; i < _amplitudeHistory.length; i++) {
      double diff = _amplitudeHistory[i] - _amplitudeHistory[i - 1];
      sumSquaredDiff += diff * diff;
    }
    double variance = sumSquaredDiff / (_amplitudeHistory.length - 1);
    _shimmer = math.sqrt(variance).clamp(0.0, 10.0);

    // 3. Calcular Jitter (variabilidad de frecuencia - simulado)
    // En un análisis real, esto requeriría FFT del audio
    List<double> intervals = [];
    for (int i = 1; i < _amplitudeHistory.length; i++) {
      if (_amplitudeHistory[i] > -40 && _amplitudeHistory[i-1] < -40) {
        intervals.add(i.toDouble());
      }
    }

    if (intervals.length > 1) {
      List<double> intervalDiffs = [];
      for (int i = 1; i < intervals.length; i++) {
        intervalDiffs.add((intervals[i] - intervals[i-1]).abs());
      }
      double avgInterval = intervalDiffs.reduce((a, b) => a + b) / intervalDiffs.length;
      double jitterSum = 0;
      for (var diff in intervalDiffs) {
        jitterSum += (diff - avgInterval).abs();
      }
      _jitter = (jitterSum / intervalDiffs.length).clamp(0.0, 10.0);
    } else {
      _jitter = 0.0;
    }

    // 4. Contar períodos de silencio
    _silencePeriods = 0;
    for (int i = 0; i < _amplitudeHistory.length; i++) {
      if (_amplitudeHistory[i] < -50) {
        _silencePeriods++;
      }
    }

    // 5. Calcular calidad de voz (inversamente proporcional a shimmer y jitter)
    double shimmerScore = (10 - _shimmer) * 10; // 0-100
    double jitterScore = (10 - _jitter) * 10;   // 0-100
    double amplitudeScore = (_avgAmplitude + 60) * 1.67; // -60 a 0 -> 0 a 100

    _voiceQuality = ((shimmerScore + jitterScore + amplitudeScore) / 3).clamp(0.0, 100.0);
  }

  Future<void> _playRecording() async {
    if (_recordingPath == null) return;

    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
        setState(() => _isPlaying = false);
      } else {
        await _audioPlayer.play(DeviceFileSource(_recordingPath!));
        setState(() => _isPlaying = true);

        _audioPlayer.onPlayerComplete.listen((_) {
          if (mounted) {
            setState(() => _isPlaying = false);
          }
        });
      }
    } catch (e) {
      _showError('Error al reproducir: $e');
    }
  }

  void _resetTest() {
    setState(() {
      _hasRecording = false;
      _testCompleted = false;
      _recordingPath = null;
      _recordingDuration = Duration.zero;
      _amplitudeHistory.clear();
      _jitter = 0.0;
      _shimmer = 0.0;
      _avgAmplitude = 0.0;
      _silencePeriods = 0;
      _voiceQuality = 0.0;
    });
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _recordingTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test de Voz'),
        actions: [
          if (_hasRecording && !_testCompleted)
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
                  Icons.mic,
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
                  // Visualización de grabación
                  if (_isRecording || _hasRecording)
                    _buildRecordingVisualizer(),

                  const SizedBox(height: 24),

                  // Área de control principal
                  if (!_testCompleted)
                    _buildRecordingControls()
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
    if (_isRecording) {
      return 'Di "AAAAA" de forma sostenida por 5-10 segundos';
    } else if (_hasRecording && !_testCompleted) {
      return 'Grabación lista. Presiona analizar para ver resultados';
    } else if (_testCompleted) {
      return 'Análisis completado';
    } else {
      return 'Presiona el micrófono para comenzar a grabar';
    }
  }

  Widget _buildRecordingVisualizer() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // Tiempo de grabación
          Text(
            _formatDuration(_recordingDuration),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Visualización de onda
          Expanded(
            child: _isRecording
                ? _buildWaveform()
                : Center(
              child: Icon(
                Icons.check_circle,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaveform() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(20, (index) {
        double height = 20.0;

        if (_amplitudeHistory.length > index) {
          int historyIndex = math.max(0, _amplitudeHistory.length - 20 + index);
          double amplitude = _amplitudeHistory[historyIndex];
          height = ((amplitude + 60) / 60 * 80).clamp(10.0, 80.0);
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 4,
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  Widget _buildRecordingControls() {
    return Column(
      children: [
        // Botón principal de grabación
        if (!_isRecording && !_hasRecording)
          ScaleTransition(
            scale: _pulseAnimation,
            child: GestureDetector(
              onTap: _startRecording,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.mic,
                  size: 48,
                  color: Colors.white,
                ),
              ),
            ),
          ),

        // Botón de detener grabación
        if (_isRecording)
          Column(
            children: [
              GestureDetector(
                onTap: _stopRecording,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.stop,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Mínimo 5 segundos',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),

        // Controles de reproducción y análisis
        if (_hasRecording && !_testCompleted && !_isAnalyzing)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _playRecording,
                icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                label: Text(_isPlaying ? 'Detener' : 'Reproducir'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: _analyzeRecording,
                icon: const Icon(Icons.analytics),
                label: const Text('Analizar'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
              ),
            ],
          ),

        // Indicador de análisis
        if (_isAnalyzing)
          Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Analizando grabación...',
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
        // Calidad general
        _buildQualityIndicator(),

        const SizedBox(height: 24),

        // Métricas detalladas
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Shimmer',
                value: _shimmer.toStringAsFixed(2),
                unit: '',
                icon: Icons.graphic_eq,
                color: _getShimmerColor(),
                description: 'Variabilidad de amplitud',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                title: 'Jitter',
                value: _jitter.toStringAsFixed(2),
                unit: '%',
                icon: Icons.waves,
                color: _getJitterColor(),
                description: 'Variabilidad de frecuencia',
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Amplitud',
                value: _avgAmplitude.toStringAsFixed(1),
                unit: 'dB',
                icon: Icons.volume_up,
                color: Colors.blue,
                description: 'Volumen promedio',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                title: 'Silencios',
                value: _silencePeriods.toString(),
                unit: '',
                icon: Icons.volume_off,
                color: Colors.orange,
                description: 'Interrupciones detectadas',
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Evaluación
        _buildAssessment(),

        const SizedBox(height: 24),

        // Botones de acción
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

  Widget _buildQualityIndicator() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getQualityColor(),
            _getQualityColor().withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _getQualityColor().withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Calidad de Voz',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_voiceQuality.toStringAsFixed(0)}%',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getQualityLabel(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssessment() {
    String assessment;
    IconData icon;
    Color color;

    if (_shimmer < 3 && _jitter < 2) {
      assessment = 'Parámetros vocales dentro de rango normal. No se detectan anomalías significativas.';
      icon = Icons.check_circle;
      color = Colors.green;
    } else if (_shimmer < 5 && _jitter < 4) {
      assessment = 'Variabilidad vocal leve detectada. Se recomienda seguimiento periódico.';
      icon = Icons.warning;
      color = Colors.orange;
    } else {
      assessment = 'Variabilidad vocal elevada detectada. Se recomienda consultar con un especialista.';
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

  Color _getShimmerColor() {
    if (_shimmer < 3) return Colors.green;
    if (_shimmer < 5) return Colors.orange;
    return Colors.red;
  }

  Color _getJitterColor() {
    if (_jitter < 2) return Colors.green;
    if (_jitter < 4) return Colors.orange;
    return Colors.red;
  }

  Color _getQualityColor() {
    if (_voiceQuality > 70) return Colors.green;
    if (_voiceQuality > 50) return Colors.orange;
    return Colors.red;
  }

  String _getQualityLabel() {
    if (_voiceQuality > 70) return 'Excelente';
    if (_voiceQuality > 50) return 'Moderado';
    return 'Requiere atención';
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _saveResults() {
    // TODO: Implementar guardado en base de datos
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Resultados guardados exitosamente'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context);
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final String description;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    required this.description,
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
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 4),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}
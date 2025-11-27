import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '/models/test_result.dart';
import '/services/database_helper.dart';

class VoiceTestScreen extends StatefulWidget {
  const VoiceTestScreen({super.key});

  @override
  State<VoiceTestScreen> createState() => _VoiceTestScreenState();
}

class _VoiceTestScreenState extends State<VoiceTestScreen> with TickerProviderStateMixin {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // URL de la API
  static const String apiUrl = 'http://192.168.0.2:5001/predict_parkinson';

  // Estados del test
  bool _isRecording = false;
  bool _hasRecording = false;
  bool _isAnalyzing = false;
  bool _testCompleted = false;
  bool _isPlaying = false;

  // Datos de grabación
  String? _recordingPath;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;

  // Resultado del servidor
  double? _probabilidad;
  String? _mensaje;
  String? _color;
  bool? _alertaBiomarcadores;
  List<dynamic>? _detalles;

  // Animación
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
    if (!status.isGranted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Se requiere permiso de micrófono'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/voice_test_${DateTime.now().millisecondsSinceEpoch}.wav';

        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 44100,
            numChannels: 1,
          ),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _hasRecording = false;
          _recordingPath = path;
          _recordingDuration = Duration.zero;
        });

        _startTimer();
      }
    } catch (e) {
      _showError('Error al iniciar grabación: $e');
    }
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

      // Enviar a la API automáticamente
      await _sendToAPI();
    } catch (e) {
      _showError('Error al detener grabación: $e');
    }
  }

  Future<void> _sendToAPI() async {
    if (_recordingPath == null) {
      _showError('No hay grabación disponible');
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      final file = File(_recordingPath!);
      if (!await file.exists()) {
        throw Exception('El archivo de audio no existe');
      }

      // Crear petición
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          _recordingPath!,
          filename: 'voice_test.wav',
        ),
      );

      print('📤 Enviando audio a: $apiUrl');

      // Enviar
      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw TimeoutException('Timeout'),
      );

      var response = await http.Response.fromStream(streamedResponse);

      print('📥 Código: ${response.statusCode}');
      print('📥 Respuesta: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        setState(() {
          _probabilidad = (jsonResponse['probabilidad'] ?? 0.0).toDouble();
          _mensaje = jsonResponse['mensaje'] ?? 'Análisis completado';
          _color = jsonResponse['color'] ?? 'verde';
          _alertaBiomarcadores = jsonResponse['alerta_biomarcadores'] ?? false;
          _detalles = jsonResponse['detalles'] ?? [];

          _isAnalyzing = false;
          _testCompleted = true;
        });

        print('✅ Resultado procesado correctamente');
      } else {
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }
    } on TimeoutException {
      _showError('Tiempo de espera agotado');
      setState(() => _isAnalyzing = false);
    } catch (e) {
      print('❌ Error: $e');
      _showError('Error: $e');
      setState(() => _isAnalyzing = false);
    }
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
          if (mounted) setState(() => _isPlaying = false);
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
      _probabilidad = null;
      _mensaje = null;
      _color = null;
      _alertaBiomarcadores = null;
      _detalles = null;
    });
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
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
        title: const Text('Test de Voz IA'),
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
                  if (_isRecording || _hasRecording)
                    _buildTimer(),

                  const SizedBox(height: 24),

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
      return 'Di "AAAAA" sostenido por 5-10 segundos';
    } else if (_isAnalyzing) {
      return 'Analizando con Inteligencia Artificial...';
    } else if (_testCompleted) {
      return 'Análisis completado';
    } else {
      return 'Presiona el micrófono para comenzar';
    }
  }

  Widget _buildTimer() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            _formatDuration(_recordingDuration),
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isRecording ? 'Grabando...' : 'Grabación completada',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingControls() {
    return Column(
      children: [
        // Botón de grabar
        if (!_isRecording && !_hasRecording)
          ScaleTransition(
            scale: _pulseAnimation,
            child: GestureDetector(
              onTap: _startRecording,
              child: Container(
                width: 140,
                height: 140,
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
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.mic, size: 56, color: Colors.white),
                    SizedBox(height: 8),
                    Text(
                      'GRABAR',
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
        if (_isRecording)
          GestureDetector(
            onTap: _stopRecording,
            child: Container(
              width: 140,
              height: 140,
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
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.stop, size: 56, color: Colors.white),
                  SizedBox(height: 8),
                  Text(
                    'DETENER',
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

        const SizedBox(height: 16),

        // Botón de reproducir
        if (_hasRecording && !_testCompleted && !_isAnalyzing)
          OutlinedButton.icon(
            onPressed: _playRecording,
            icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
            label: Text(_isPlaying ? 'Detener' : 'Reproducir'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),

        // Indicador de análisis
        if (_isAnalyzing)
          Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Analizando con IA...',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Procesando biomarcadores vocales',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildResults() {
    final color = _getColorFromString(_color ?? 'verde');
    final hasParkinson = (_probabilidad ?? 0) > 50 || (_alertaBiomarcadores ?? false);

    return Column(
      children: [
        // Resultado principal
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, color.withOpacity(0.7)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                hasParkinson ? Icons.warning_rounded : Icons.check_circle_rounded,
                size: 80,
                color: Colors.white,
              ),
              const SizedBox(height: 16),
              Text(
                _mensaje ?? 'Análisis completado',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Probabilidad: ${_probabilidad?.toStringAsFixed(1) ?? '0'}%',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Detalles biomarcadores
        if (_detalles != null && _detalles!.isNotEmpty)
          Container(
            width: double.infinity,
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
                    Icon(Icons.info_outline, color: color),
                    const SizedBox(width: 8),
                    Text(
                      'Biomarcadores Detectados',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._detalles!.map((detalle) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.arrow_right, size: 20, color: color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          detalle.toString(),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),

        const SizedBox(height: 24),

        // Recomendación
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recomendación',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hasParkinson
                    ? 'Se detectaron posibles signos. Se recomienda consultar con un especialista para evaluación profesional.'
                    : 'No se detectaron signos evidentes. Continúa con seguimiento periódico.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Botones
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _resetTest,
                icon: const Icon(Icons.refresh),
                label: const Text('Repetir Test'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 50),
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
                  minimumSize: const Size(0, 50),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getColorFromString(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'rojo':
        return Colors.red;
      case 'naranja':
        return Colors.orange;
      case 'verde':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(duration.inMinutes)}:${twoDigits(duration.inSeconds.remainder(60))}';
  }

  void _saveResults() async {
    try {
      final result = TestResult(
        testType: 'voice',
        timestamp: DateTime.now(),
        overallScore: 100 - (_probabilidad ?? 0),
        metrics: {
          'probabilidad': _probabilidad ?? 0.0,
          'alerta_biomarcadores': (_alertaBiomarcadores ?? false) ? 1.0 : 0.0,
        },
        notes: _mensaje,
      );

      await DatabaseHelper.instance.insertTestResult(result);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Resultados guardados'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
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
  bool _isAnalyzing = false;
  bool _testCompleted = false;
  bool _isPlaying = false;

  // Control de grabaciones múltiples
  int _currentRecording = 0; // 0, 1, 2 (para 3 grabaciones)
  static const int _totalRecordings = 3;
  List<String> _recordingPaths = [];
  List<Duration> _recordingDurations = [];

  Duration _currentDuration = Duration.zero;
  Timer? _recordingTimer;

  // Resultados individuales y promedio
  List<Map<String, dynamic>> _resultadosIndividuales = [];
  double? _probabilidadPromedio;
  String? _mensajeFinal;
  String? _colorFinal;
  bool? _alertaBiomarcadoresGlobal;
  List<String> _detallesGlobales = [];

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
        final path = '${directory.path}/voice_test_${_currentRecording + 1}_${DateTime.now().millisecondsSinceEpoch}.wav';

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
          _currentDuration = Duration.zero;
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
          _currentDuration = Duration(seconds: _currentDuration.inSeconds + 1);
        });
      }
    });
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      _recordingTimer?.cancel();

      if (path != null) {
        setState(() {
          _recordingPaths.add(path);
          _recordingDurations.add(_currentDuration);
          _isRecording = false;
        });

        // Si ya tenemos las 3 grabaciones, analizamos
        if (_recordingPaths.length >= _totalRecordings) {
          await _analyzeAllRecordings();
        } else {
          // Preparar para la siguiente grabación
          setState(() {
            _currentRecording++;
          });

          // Pequeña pausa antes de la siguiente grabación
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    } catch (e) {
      _showError('Error al detener grabación: $e');
    }
  }

  Future<void> _analyzeAllRecordings() async {
    setState(() => _isAnalyzing = true);

    try {
      print('📤 Enviando 3 audios juntos al servidor...');

      // Enviar TODOS los audios en UNA SOLA petición
      final resultado = await _sendMultipleAudiosToAPI(_recordingPaths);

      if (resultado != null) {
        // Procesar el resultado único que ya contiene los promedios
        setState(() {
          _probabilidadPromedio = (resultado['probabilidad'] ?? 0.0).toDouble();
          _mensajeFinal = resultado['mensaje'] ?? 'Análisis completado';
          _colorFinal = resultado['color'] ?? 'verde';
          _alertaBiomarcadoresGlobal = resultado['alerta_biomarcadores'] ?? false;

          // Extraer detalles
          if (resultado['detalles'] != null) {
            _detallesGlobales = List<String>.from(resultado['detalles']);
          }

          // Guardar resultado completo para referencia
          _resultadosIndividuales = [resultado];

          _isAnalyzing = false;
          _testCompleted = true;
        });

        print('✅ Análisis completado exitosamente');
      } else {
        throw Exception('No se pudo analizar las grabaciones');
      }

    } catch (e) {
      print('❌ Error en análisis: $e');
      _showError('Error: $e');
      setState(() => _isAnalyzing = false);
    }
  }

  Future<Map<String, dynamic>?> _sendMultipleAudiosToAPI(List<String> filePaths) async {
    try {
      // Verificar que todos los archivos existen
      for (var path in filePaths) {
        final file = File(path);
        if (!await file.exists()) {
          throw Exception('Archivo no existe: $path');
        }
      }

      // Crear petición con MÚLTIPLES archivos
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));

      // Agregar cada archivo con el MISMO nombre de campo 'file'
      for (int i = 0; i < filePaths.length; i++) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'file', // Mismo nombre para todos
            filePaths[i],
            filename: 'voice_test_${i + 1}.wav',
          ),
        );
        print('  📎 Agregado: voice_test_${i + 1}.wav');
      }

      print('📤 Enviando ${filePaths.length} archivos al servidor...');

      // Aumentar timeout porque son 3 archivos
      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 120), // 2 minutos para procesar 3 audios
        onTimeout: () => throw TimeoutException('Timeout procesando múltiples audios'),
      );

      var response = await http.Response.fromStream(streamedResponse);

      print('📥 Código: ${response.statusCode}');
      print('📥 Respuesta: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        print('✅ Análisis completado por el servidor');
        return jsonResponse;
      } else {
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ Error enviando audios: $e');
      return null;
    }
  }

  void _calculateFinalResult() {
    // Ya no es necesario porque el servidor hace los cálculos
    // Solo se usa si queremos mostrar datos adicionales
    if (_resultadosIndividuales.isEmpty) return;

    final resultado = _resultadosIndividuales[0];
    print('📊 Resultado del servidor:');
    print('   Probabilidad: ${resultado['probabilidad']}%');
    print('   Mensaje: ${resultado['mensaje']}');
    print('   Detalles: ${resultado['detalles']}');
  }

  Future<void> _playRecording(int index) async {
    if (index >= _recordingPaths.length) return;

    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
        setState(() => _isPlaying = false);
      } else {
        await _audioPlayer.play(DeviceFileSource(_recordingPaths[index]));
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
      _currentRecording = 0;
      _recordingPaths.clear();
      _recordingDurations.clear();
      _resultadosIndividuales.clear();
      _isRecording = false;
      _isAnalyzing = false;
      _testCompleted = false;
      _currentDuration = Duration.zero;
      _probabilidadPromedio = null;
      _mensajeFinal = null;
      _colorFinal = null;
      _alertaBiomarcadoresGlobal = null;
      _detallesGlobales.clear();
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
        title: const Text('Test de Voz IA - Triple Análisis'),
        actions: [
          if (_recordingPaths.isNotEmpty && !_testCompleted && !_isAnalyzing)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetTest,
              tooltip: 'Reiniciar',
            ),
        ],
      ),
      body: Column(
        children: [
          // Indicador de progreso
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_totalRecordings, (index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: index < _recordingPaths.length
                            ? Colors.green
                            : index == _currentRecording && _isRecording
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade300,
                        child: index < _recordingPaths.length
                            ? const Icon(Icons.check, color: Colors.white, size: 16)
                            : Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: index == _currentRecording && _isRecording
                                ? Colors.white
                                : Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
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
                  if (_isRecording)
                    _buildTimer(),

                  if (_recordingPaths.isNotEmpty && !_testCompleted)
                    _buildRecordingsList(),

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
    if (_isAnalyzing) {
      return 'Analizando ${_totalRecordings} grabaciones con IA...';
    } else if (_testCompleted) {
      return 'Análisis completado - Resultados de $_totalRecordings muestras';
    } else if (_isRecording) {
      return 'Grabación ${_currentRecording + 1} de $_totalRecordings: Di "AAAAA" sostenido';
    } else if (_recordingPaths.length < _totalRecordings) {
      return 'Grabación ${_currentRecording + 1} de $_totalRecordings';
    } else {
      return 'Listo para analizar';
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
            'Grabación ${_currentRecording + 1}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _formatDuration(_currentDuration),
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingsList() {
    return Column(
      children: [
        Text(
          'Grabaciones completadas',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(_recordingPaths.length, (index) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green,
                child: Text('${index + 1}'),
              ),
              title: Text('Grabación ${index + 1}'),
              subtitle: Text(_formatDuration(_recordingDurations[index])),
              trailing: IconButton(
                icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                onPressed: () => _playRecording(index),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRecordingControls() {
    return Column(
      children: [
        // Botón principal
        if (!_isRecording && _recordingPaths.length < _totalRecordings)
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.mic, size: 56, color: Colors.white),
                    const SizedBox(height: 8),
                    Text(
                      'GRABAR ${_currentRecording + 1}',
                      style: const TextStyle(
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

        const SizedBox(height: 24),

        if (_isAnalyzing)
          Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Analizando $_totalRecordings grabaciones...',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Procesando ${_resultadosIndividuales.length + 1} de $_totalRecordings',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildResults() {
    final color = _getColorFromString(_colorFinal ?? 'verde');
    final hasParkinson = (_probabilidadPromedio ?? 0) > 50 || (_alertaBiomarcadoresGlobal ?? false);

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
                _mensajeFinal ?? 'Análisis completado',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Análisis de $_totalRecordings muestras',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Probabilidad Promedio: ${_probabilidadPromedio?.toStringAsFixed(1) ?? '0'}%',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Resultados individuales
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
              Row(
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Análisis Consolidado',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _InfoRow(
                label: 'Muestras analizadas',
                value: '$_totalRecordings grabaciones',
                icon: Icons.mic,
              ),
              _InfoRow(
                label: 'Duración total',
                value: _formatDuration(_recordingDurations.fold(
                  Duration.zero,
                      (sum, duration) => sum + duration,
                )),
                icon: Icons.timer,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Biomarcadores
        if (_detallesGlobales.isNotEmpty)
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
                    Icon(Icons.science_outlined, color: color, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Biomarcadores Vocales Detectados',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Análisis de Jitter, Shimmer y HNR',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 16),
                ..._detallesGlobales.map((detalle) {
                  // Determinar el ícono según el tipo de biomarcador
                  IconData biomarkerIcon;
                  String descripcion;

                  // Convertir a minúsculas para comparación case-insensitive
                  final detalleLower = detalle.toLowerCase();

                  if (detalleLower.contains('jitter')) {
                    biomarkerIcon = Icons.graphic_eq;
                    descripcion = 'Variabilidad de frecuencia vocal';
                  } else if (detalleLower.contains('shimmer')) {
                    biomarkerIcon = Icons.show_chart;
                    descripcion = 'Variabilidad de amplitud';
                  } else if (detalleLower.contains('hnr')) {
                    biomarkerIcon = Icons.waves;
                    descripcion = 'Relación armónico-ruido';
                  } else {
                    biomarkerIcon = Icons.circle;
                    descripcion = 'Parámetro vocal alterado';
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: color.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            biomarkerIcon,
                            size: 24,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                detalle,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                descripcion,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.black87,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

        const SizedBox(height: 16),

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
                    ? 'Se detectaron signos en múltiples muestras. Se recomienda consultar con un especialista para evaluación profesional completa.'
                    : 'No se detectaron signos evidentes en las $_totalRecordings muestras analizadas. Continúa con seguimiento periódico.',
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
        overallScore: 100 - (_probabilidadPromedio ?? 0),
        metrics: {
          'probabilidad_promedio': _probabilidadPromedio ?? 0.0,
          'total_muestras': _totalRecordings.toDouble(),
          'alerta_biomarcadores': (_alertaBiomarcadoresGlobal ?? false) ? 1.0 : 0.0,
          'resultado_1': _resultadosIndividuales.isNotEmpty ? (_resultadosIndividuales[0]['probabilidad'] ?? 0.0).toDouble() : 0.0,
          'resultado_2': _resultadosIndividuales.length > 1 ? (_resultadosIndividuales[1]['probabilidad'] ?? 0.0).toDouble() : 0.0,
          'resultado_3': _resultadosIndividuales.length > 2 ? (_resultadosIndividuales[2]['probabilidad'] ?? 0.0).toDouble() : 0.0,
        },
        notes: '$_mensajeFinal - Análisis de $_totalRecordings muestras',
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

// Widget helper para mostrar información
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
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
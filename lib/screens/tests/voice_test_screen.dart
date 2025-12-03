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

  // URL DE LA API: Asegúrate de que el puerto sea el mismo que el del servidor (5001 según tu código Python)
  static const String apiUrl = 'http://192.168.0.2:5001/predict_parkinson';

  // Estados del test
  bool _isRecording = false;
  bool _isAnalyzing = false;
  bool _testCompleted = false;
  bool _isPlaying = false;

  // Control de grabaciones múltiples
  int _currentRecording = 0;
  static const int _totalRecordings = 3;
  List<String> _recordingPaths = [];
  List<Duration> _recordingDurations = [];

  Duration _currentDuration = Duration.zero;
  Timer? _recordingTimer;

  // --- VARIABLES PARA RESULTADOS ---
  List<Map<String, dynamic>> _resultadosIndividuales = [];
  double? _probabilidadPromedio;

  // Nuevas variables para Jitter, Shimmer y HNR
  double? _jitterPromedio;
  double? _shimmerPromedio;
  double? _hnrPromedio;

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

        if (_recordingPaths.length >= _totalRecordings) {
          await _analyzeAllRecordings();
        } else {
          setState(() {
            _currentRecording++;
          });
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

      final resultado = await _sendMultipleAudiosToAPI(_recordingPaths);

      if (resultado != null) {
        setState(() {
          // 1. Extraer Probabilidad y Mensajes
          _probabilidadPromedio = (resultado['probabilidad_promedio'] ?? 0.0).toDouble();
          _mensajeFinal = resultado['mensaje'] ?? 'Análisis completado';
          _colorFinal = resultado['color'] ?? 'verde';
          _alertaBiomarcadoresGlobal = resultado['alerta_biomarcadores_global'] ?? false;

          // 2. Extraer DATOS TÉCNICOS (Jitter, Shimmer, HNR)
          // El servidor devuelve estos nombres exactos según tu código Python
          _jitterPromedio = (resultado['jitter_promedio'] ?? 0.0).toDouble();
          _shimmerPromedio = (resultado['shimmer_promedio'] ?? 0.0).toDouble();
          _hnrPromedio = (resultado['hnr_promedio'] ?? 0.0).toDouble();

          // 3. Extraer Detalles (El servidor usa 'detalles_alertas_totales')
          if (resultado['detalles_alertas_totales'] != null) {
            _detallesGlobales = List<String>.from(resultado['detalles_alertas_totales']);
          }

          // 4. Guardar muestras individuales si las necesitas
          if (resultado['muestras_individuales'] != null) {
            _resultadosIndividuales = List<Map<String, dynamic>>.from(resultado['muestras_individuales']);
          }

          _isAnalyzing = false;
          _testCompleted = true;
        });

        print('✅ Análisis completado. Jitter: $_jitterPromedio, Shimmer: $_shimmerPromedio');
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
      for (var path in filePaths) {
        final file = File(path);
        if (!await file.exists()) {
          throw Exception('Archivo no existe: $path');
        }
      }

      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));

      for (int i = 0; i < filePaths.length; i++) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            filePaths[i],
            filename: 'voice_test_${i + 1}.wav',
          ),
        );
      }

      // Timeout aumentado a 300 segundos (5 minutos) para evitar errores
      var streamedResponse = await request.send().timeout(
        const Duration(seconds: 300),
        onTimeout: () => throw TimeoutException('El servidor tardó demasiado.'),
      );

      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return jsonResponse;
      } else {
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ Error enviando audios: $e');
      return null;
    }
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
      _jitterPromedio = null;
      _shimmerPromedio = null;
      _hnrPromedio = null;
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
          if (_recordingPaths.isNotEmpty && !_testCompleted && !_isAnalyzing)
            IconButton(icon: const Icon(Icons.refresh), onPressed: _resetTest),
        ],
      ),
      body: Column(
        children: [
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
                        child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                  if (_isRecording) _buildTimer(),
                  if (_recordingPaths.isNotEmpty && !_testCompleted) _buildRecordingsList(),
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
    if (_isAnalyzing) return 'Analizando grabaciones...';
    if (_testCompleted) return 'Resultados de $_totalRecordings muestras';
    if (_isRecording) return 'Di "AAAAA" sostenido';
    return 'Listo para iniciar';
  }

  Widget _buildTimer() {
    return Column(
      children: [
        Text('Grabando...', style: Theme.of(context).textTheme.titleLarge),
        Text(
          _formatDuration(_currentDuration),
          style: Theme.of(context).textTheme.displayLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.red),
        ),
      ],
    );
  }

  Widget _buildRecordingsList() {
    return Column(
      children: List.generate(_recordingPaths.length, (index) {
        return Card(
          child: ListTile(
            leading: const Icon(Icons.mic, color: Colors.green),
            title: Text('Grabación ${index + 1}'),
            trailing: IconButton(
              icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
              onPressed: () => _playRecording(index),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildRecordingControls() {
    final size = MediaQuery.of(context).size;
    final buttonSize = (size.width * 0.35).clamp(100.0, 140.0);

    return Column(
      children: [
        if (!_isRecording && _recordingPaths.length < _totalRecordings)
          ScaleTransition(
            scale: _pulseAnimation,
            child: GestureDetector(
              onTap: _startRecording,
              child: Container(
                width: buttonSize,
                height: buttonSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primary,
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 5))
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.mic, size: 40, color: Colors.white),
                    const Text('GRABAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),

        if (_isRecording)
          GestureDetector(
            onTap: _stopRecording,
            child: Container(
              width: buttonSize,
              height: buttonSize,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.red),
              child: const Icon(Icons.stop, size: 50, color: Colors.white),
            ),
          ),

        if (_isAnalyzing)
          const Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 10),
              Text("Procesando datos en el servidor..."),
            ],
          ),
      ],
    );
  }

  // --- AQUÍ ESTÁ LA NUEVA SECCIÓN DE RESULTADOS CON LOS DATOS TÉCNICOS ---
  Widget _buildResults() {
    final color = _getColorFromString(_colorFinal ?? 'verde');
    final hasParkinson = (_probabilidadPromedio ?? 0) > 50;

    return Column(
      children: [
        // 1. Tarjeta Principal
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color, width: 2),
          ),
          child: Column(
            children: [
              Icon(hasParkinson ? Icons.warning : Icons.check_circle, size: 60, color: color),
              const SizedBox(height: 10),
              Text(
                _mensajeFinal ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
              ),
              Text(
                'Probabilidad: ${_probabilidadPromedio?.toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 18),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 2. Tarjeta de Datos Técnicos (Jitter, Shimmer, HNR)
        Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Métricas Vocales (Promedio)",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Divider(),
                const SizedBox(height: 8),

                // Jitter
                _buildTechnicalRow(
                    "Jitter (Frecuencia)",
                    "${_jitterPromedio?.toStringAsFixed(5) ?? '0.0'}",
                    "Normal < 0.01",
                    (_jitterPromedio ?? 0) > 0.01
                ),

                // Shimmer
                _buildTechnicalRow(
                    "Shimmer (Amplitud)",
                    "${_shimmerPromedio?.toStringAsFixed(5) ?? '0.0'}",
                    "Normal < 0.038",
                    (_shimmerPromedio ?? 0) > 0.038
                ),

                // HNR
                _buildTechnicalRow(
                    "HNR (Ruido)",
                    "${_hnrPromedio?.toStringAsFixed(2) ?? '0.0'} dB",
                    "Normal > 20 dB",
                    (_hnrPromedio ?? 20) < 20
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // 3. Detalles de Alertas (Si existen)
        if (_detallesGlobales.isNotEmpty)
          Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text("Alertas Detectadas", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ..._detallesGlobales.map((e) => Text("• $e", style: const TextStyle(color: Colors.redAccent))),
                ],
              ),
            ),
          ),

        const SizedBox(height: 20),

        // Botones
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            OutlinedButton(onPressed: _resetTest, child: const Text("Repetir")),
            FilledButton(onPressed: _saveResults, child: const Text("Guardar")),
          ],
        )
      ],
    );
  }

  Widget _buildTechnicalRow(String label, String value, String ref, bool isAlert) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(ref, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            ],
          ),
          Text(
            value,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isAlert ? Colors.red : Colors.green
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorFromString(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'rojo': return Colors.red;
      case 'naranja': return Colors.orange;
      case 'verde': return Colors.green;
      default: return Colors.blue;
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
          // Guardamos las nuevas métricas en la base de datos local también
          'jitter': _jitterPromedio ?? 0.0,
          'shimmer': _shimmerPromedio ?? 0.0,
          'hnr': _hnrPromedio ?? 0.0,
        },
        notes: '$_mensajeFinal',
      );

      await DatabaseHelper.instance.insertTestResult(result);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardado correctamente')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
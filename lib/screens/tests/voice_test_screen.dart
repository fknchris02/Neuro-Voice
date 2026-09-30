import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../services/database_helper.dart';
import '../../services/parkinson_api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neuro_app_bar.dart';
import '../../widgets/supervisor_card.dart';
import '../biomarker_report_screen.dart';

const _totalSamples = 3;
const _sampleDuration = Duration(seconds: 5);
const _countdownSeconds = 3;
const _amplitudeInterval = Duration(milliseconds: 100);

/// Puntos de la curva para una muestra completa (5 s / 100 ms).
final _tracePoints =
    _sampleDuration.inMilliseconds ~/ _amplitudeInterval.inMilliseconds;

/// Nivel normalizado (0–1) por debajo del cual la muestra se considera baja.
const _quietLevel = 0.3;
const _loudLevel = 0.9;

enum _Phase { idle, countdown, recording, analyzing, error }

class _Sample {
  final String path;
  final double avgLevel;

  const _Sample(this.path, this.avgLevel);

  bool get isQuiet => avgLevel < _quietLevel;
}

class VoiceTestScreen extends StatefulWidget {
  const VoiceTestScreen({super.key});

  @override
  State<VoiceTestScreen> createState() => _VoiceTestScreenState();
}

class _VoiceTestScreenState extends State<VoiceTestScreen>
    with SingleTickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  _Phase _phase = _Phase.idle;
  final List<_Sample?> _samples = List.filled(_totalSamples, null);
  int? _recordingSlot;
  int? _playingSlot;
  String _patientName = '';

  /// null = comprobando conexión.
  bool? _serverOnline;
  String? _errorMessage;

  int _countdown = _countdownSeconds;
  Duration _elapsed = Duration.zero;
  Duration _analysisElapsed = Duration.zero;
  Timer? _tickTimer;
  StreamSubscription<Amplitude>? _ampSub;
  StreamSubscription<void>? _playerSub;

  /// Historial de volumen de la muestra en curso (0–1).
  List<double> _trace = [];
  double _level = 0;
  double _levelSum = 0;
  int _levelCount = 0;

  late final AnimationController _pulse;

  int? get _nextSlot {
    final i = _samples.indexOf(null);
    return i == -1 ? null : i;
  }

  int get _doneCount => _samples.whereType<_Sample>().length;
  bool get _allDone => _doneCount == _totalSamples;
  bool get _isBusy =>
      _phase == _Phase.countdown ||
      _phase == _Phase.recording ||
      _phase == _Phase.analyzing;

  int? get _lastDoneSlot {
    for (var i = _totalSamples - 1; i >= 0; i--) {
      if (_samples[i] != null) return i;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _playerSub = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingSlot = null);
    });
    DatabaseHelper.instance.getUserProfile().then((p) {
      if (mounted && p != null) setState(() => _patientName = p.name);
    }, onError: (_) {});
    _checkServer();
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _ampSub?.cancel();
    _playerSub?.cancel();
    _recorder.dispose();
    _player.dispose();
    _pulse.dispose();
    super.dispose();
  }

  // ───────────────────────────── Servidor / permisos

  Future<void> _checkServer() async {
    setState(() => _serverOnline = null);
    final ok = await ParkinsonApi.isReachable();
    if (mounted) setState(() => _serverOnline = ok);
  }

  Future<bool> _ensureMicPermission() async {
    if (await Permission.microphone.request().isGranted) return true;
    if (!mounted) return false;

    final openSettings = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.mic_off_outlined),
        title: const Text('Se necesita el micrófono'),
        content: const Text(
          'Para analizar tu voz la app debe grabar audio. '
          'Activa el permiso de micrófono en los ajustes del teléfono.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Abrir ajustes'),
          ),
        ],
      ),
    );
    if (openSettings == true) await openAppSettings();
    return false;
  }

  // ───────────────────────────── Grabación

  Future<void> _onRecordPressed() async {
    if (_phase == _Phase.countdown || _phase == _Phase.recording) {
      await _cancelRecording();
      return;
    }
    final slot = _nextSlot;
    if (slot == null || _phase == _Phase.analyzing) return;
    if (!await _ensureMicPermission()) return;
    await _stopPlayback();
    if (!mounted) return;

    setState(() {
      _phase = _Phase.countdown;
      _countdown = _countdownSeconds;
      _recordingSlot = slot;
      _errorMessage = null;
      _trace = [];
    });
    _pulse.repeat();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_countdown <= 1) {
        t.cancel();
        _startRecording();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  Future<void> _startRecording() async {
    final slot = _recordingSlot!;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/voice_test_${slot + 1}_'
          '${DateTime.now().millisecondsSinceEpoch}.wav';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: path,
      );
      if (!mounted || _phase != _Phase.countdown) return;

      setState(() {
        _phase = _Phase.recording;
        _elapsed = Duration.zero;
        _trace = [];
        _level = 0;
        _levelSum = 0;
        _levelCount = 0;
      });
      _ampSub =
          _recorder.onAmplitudeChanged(_amplitudeInterval).listen(_onAmplitude);

      final startedAt = DateTime.now();
      _tickTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        final e = DateTime.now().difference(startedAt);
        if (e >= _sampleDuration) {
          _finishRecording();
        } else if (mounted) {
          setState(() => _elapsed = e);
        }
      });
    } catch (_) {
      _stopTimers();
      if (!mounted) return;
      setState(() {
        _phase = _Phase.idle;
        _recordingSlot = null;
      });
      _showSnack('No se pudo iniciar la grabación. Inténtalo de nuevo.',
          error: true);
    }
  }

  void _onAmplitude(Amplitude amp) {
    if (!mounted) return;
    // Rango típico: -60 dBFS (silencio) a 0 dBFS (máximo).
    final normalized = ((amp.current + 60) / 60).clamp(0.0, 1.0);
    setState(() {
      _level = normalized;
      _levelSum += normalized;
      _levelCount++;
      if (_trace.length < _tracePoints) _trace = [..._trace, normalized];
    });
  }

  Future<void> _finishRecording() async {
    if (_phase != _Phase.recording) return;
    _phase = _Phase.idle;
    final slot = _recordingSlot!;
    final avg = _levelCount == 0 ? 0.0 : _levelSum / _levelCount;
    _stopTimers();

    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}
    if (!mounted) return;

    setState(() {
      _recordingSlot = null;
      _elapsed = Duration.zero;
      _level = 0;
      if (path != null) _samples[slot] = _Sample(path, avg);
    });

    if (path == null) {
      _showSnack('No se pudo guardar la muestra. Inténtalo de nuevo.',
          error: true);
    } else if (avg < _quietLevel) {
      _showSnack(
        'La muestra ${slot + 1} tiene volumen bajo. '
        'Puedes repetirla acercándote al micrófono.',
      );
    }
  }

  Future<void> _cancelRecording() async {
    final wasRecording = _phase == _Phase.recording;
    _stopTimers();
    setState(() {
      _phase = _Phase.idle;
      _recordingSlot = null;
      _elapsed = Duration.zero;
      _level = 0;
      _trace = [];
    });
    if (wasRecording) {
      try {
        await _recorder.cancel();
      } catch (_) {}
    }
  }

  void _stopTimers() {
    _tickTimer?.cancel();
    _tickTimer = null;
    _ampSub?.cancel();
    _ampSub = null;
    _pulse
      ..stop()
      ..value = 0;
  }

  // ───────────────────────────── Muestras

  Future<void> _togglePlayback(int slot) async {
    final sample = _samples[slot];
    if (sample == null || _isBusy) return;
    if (_playingSlot == slot) {
      await _stopPlayback();
      return;
    }
    await _player.stop();
    await _player.play(DeviceFileSource(sample.path));
    if (mounted) setState(() => _playingSlot = slot);
  }

  Future<void> _stopPlayback() async {
    if (_playingSlot == null) return;
    await _player.stop();
    if (mounted) setState(() => _playingSlot = null);
  }

  Future<void> _redoSample(int slot) async {
    if (_isBusy) return;
    if (_playingSlot == slot) await _stopPlayback();
    final sample = _samples[slot];
    setState(() {
      _samples[slot] = null;
      if (_phase == _Phase.error) _phase = _Phase.idle;
    });
    await _deleteFile(sample?.path);
  }

  Future<void> _resetAll() async {
    if (_isBusy || _doneCount == 0) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Reiniciar la prueba?'),
        content: const Text('Se borrarán las muestras que grabaste.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reiniciar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _stopPlayback();
    await _discardAllSamples();
    setState(() {
      for (var i = 0; i < _totalSamples; i++) {
        _samples[i] = null;
      }
      _trace = [];
      if (_phase == _Phase.error) _phase = _Phase.idle;
    });
  }

  Future<void> _deleteFile(String? path) async {
    if (path == null) return;
    try {
      await File(path).delete();
    } catch (_) {}
  }

  Future<void> _discardAllSamples() async {
    for (final s in _samples) {
      await _deleteFile(s?.path);
    }
  }

  // ───────────────────────────── Análisis

  Future<void> _analyze() async {
    if (!_allDone || _isBusy) return;
    await _stopPlayback();
    setState(() {
      _phase = _Phase.analyzing;
      _errorMessage = null;
      _analysisElapsed = Duration.zero;
    });

    final startedAt = DateTime.now();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _analysisElapsed = DateTime.now().difference(startedAt));
      }
    });

    try {
      final prediction = await ParkinsonApi.predict(
        _samples.map((s) => s!.path).toList(),
      );
      _tickTimer?.cancel();

      // Guardado automático en el historial.
      final timestamp = DateTime.now();
      int? resultId;
      try {
        final saved = await DatabaseHelper.instance
            .insertTestResult(prediction.toTestResult(timestamp));
        resultId = saved.id;
      } catch (_) {}

      await _discardAllSamples();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BiomarkerReportScreen(
            prediction: prediction,
            timestamp: timestamp,
            resultId: resultId,
            saveFailed: resultId == null,
          ),
        ),
      );
    } catch (e) {
      _tickTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _errorMessage = e is ApiException
            ? e.message
            : 'Ocurrió un error inesperado durante el análisis.';
      });
      _checkServer();
    }
  }

  // ───────────────────────────── Navegación / ayuda

  Future<void> _onPopBlocked() async {
    if (_phase == _Phase.analyzing) {
      _showSnack('Espera a que termine el análisis.');
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Salir de la prueba?'),
        content: const Text('Se descartarán las muestras que grabaste.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Seguir grabando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (leave != true || !mounted) return;
    await _cancelRecording();
    await _stopPlayback();
    await _discardAllSamples();
    if (mounted) Navigator.pop(context);
  }

  void _showHelp() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => const _HelpSheet(),
    );
  }

  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ));
  }

  // ───────────────────────────── UI (design/stitch/analisis_de_voz)

  @override
  Widget build(BuildContext context) {
    final canPop =
        (_phase == _Phase.idle || _phase == _Phase.error) && _doneCount == 0;

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onPopBlocked();
      },
      child: Scaffold(
        appBar: const NeuroAppBar(title: 'Grabación De Prueba Activa'),
        body: _phase == _Phase.analyzing
            ? _AnalyzingView(elapsed: _analysisElapsed)
            : _buildRecorder(),
      ),
    );
  }

  Widget _buildRecorder() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final slot = _recordingSlot ?? _nextSlot;
    final lastDone = _lastDoneSlot;

    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.margin, AppSpacing.sm, AppSpacing.margin, AppSpacing.xl),
        children: [
          _StatusRow(
            patientName: _patientName,
            sampleLabel: slot == null
                ? 'Muestras completas'
                : 'Muestra ${slot + 1} de $_totalSamples',
            live: _phase == _Phase.recording,
            onHelp: _showHelp,
          ),
          const SizedBox(height: 12),
          SupervisorCard(
            caption: 'Supervisión clínica',
            trailing: _ServerChip(online: _serverOnline, onRetry: _checkServer),
          ),
          if (_phase == _Phase.error && _errorMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            _ErrorCard(message: _errorMessage!, onRetry: _analyze),
          ],
          const SizedBox(height: AppSpacing.md),
          _CapturePanel(
            phase: _phase,
            countdown: _countdown,
            elapsed: _elapsed,
            trace: _trace,
            level: _level,
            doneCount: _doneCount,
            allDone: slot == null,
          ),
          const SizedBox(height: AppSpacing.md),
          const _InstructionCard(),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'MUESTRAS GRABADAS',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: scheme.secondary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '$_doneCount de $_totalSamples',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: scheme.secondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < _totalSamples; i++) ...[
            _SampleTile(
              index: i,
              sample: _samples[i],
              isRecording: _recordingSlot == i,
              isPlaying: _playingSlot == i,
              enabled: !_isBusy,
              onPlay: () => _togglePlayback(i),
              onRedo: () => _redoSample(i),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 14),
          _ControlsCard(
            busy: _phase == _Phase.recording || _phase == _Phase.countdown,
            canRecord: slot != null,
            canListen: lastDone != null && !_isBusy,
            isListening: lastDone != null && _playingSlot == lastDone,
            canReset: _doneCount > 0 && !_isBusy,
            canAnalyze: _allDone && !_isBusy,
            remaining: _totalSamples - _doneCount,
            pulse: _pulse,
            onRecord: _onRecordPressed,
            onListen: () {
              if (lastDone != null) _togglePlayback(lastDone);
            },
            onReset: _resetAll,
            onAnalyze: _analyze,
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════ Widgets privados

class _StatusRow extends StatelessWidget {
  final String patientName;
  final String sampleLabel;
  final bool live;
  final VoidCallback onHelp;

  const _StatusRow({
    required this.patientName,
    required this.sampleLabel,
    required this.live,
    required this.onHelp,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = theme.textTheme.labelSmall;

    return Row(
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(99),
              boxShadow: AppShadows.small,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: live ? scheme.secondary : scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (patientName.isNotEmpty) ...[
                  Flexible(
                    child: Text(
                      'Paciente: $patientName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: label?.copyWith(color: scheme.primary),
                    ),
                  ),
                  Text('  •  ', style: label?.copyWith(color: scheme.outlineVariant)),
                ],
                Text(
                  sampleLabel,
                  style: label?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Cómo hacer la prueba',
          onPressed: onHelp,
          style: IconButton.styleFrom(
            backgroundColor: scheme.surfaceContainer,
            foregroundColor: scheme.onSurfaceVariant,
          ),
          icon: const Icon(Icons.help_outline, size: 20),
        ),
      ],
    );
  }
}

/// Chip del diseño ("En Línea") mostrando el estado real del servidor.
class _ServerChip extends StatelessWidget {
  final bool? online;
  final VoidCallback onRetry;

  const _ServerChip({required this.online, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (IconData icon, String text, Color color) = switch (online) {
      null => (Icons.sync, 'Conectando', scheme.onSurfaceVariant),
      true => (Icons.sensors, 'En Línea', scheme.secondary),
      false => (Icons.sensors_off, 'Sin conexión', AppColors.riskModerate),
    };

    return Tooltip(
      message: online == false
          ? 'Servidor de análisis no disponible. Toca para reintentar.'
          : 'Estado del servidor de análisis',
      child: Material(
        color: scheme.surfaceContainer,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: online == false ? onRetry : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Text(text, style: theme.textTheme.labelSmall?.copyWith(color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Panel carmesí "Captura Acústica IA".
class _CapturePanel extends StatelessWidget {
  final _Phase phase;
  final int countdown;
  final Duration elapsed;
  final List<double> trace;
  final double level;
  final int doneCount;
  final bool allDone;

  const _CapturePanel({
    required this.phase,
    required this.countdown,
    required this.elapsed,
    required this.trace,
    required this.level,
    required this.doneCount,
    required this.allDone,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRecording = phase == _Phase.recording;
    final isCountdown = phase == _Phase.countdown;
    final seconds = elapsed.inSeconds.toString().padLeft(2, '0');

    final (String levelLabel, Color levelColor) = !isRecording
        ? ('En espera', AppColors.onPrimaryContainer)
        : level < _quietLevel
            ? ('Bajo', Colors.amberAccent)
            : level > _loudLevel
                ? ('Alto', Colors.amberAccent)
                : ('Óptimo', const Color(0xFF6EE7B7));

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: const [
          BoxShadow(color: Color(0x40000000), blurRadius: 25, offset: Offset(0, 20)),
        ],
      ),
      child: Stack(
        children: [
          // Brillos ambientales difusos.
          Positioned(
            right: -64,
            top: -64,
            child: _Glow(size: 192, color: AppColors.secondaryContainer.withValues(alpha: 0.2)),
          ),
          Positioned(
            left: -48,
            bottom: -48,
            child: _Glow(size: 176, color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _PanelChip(
                      background: Colors.black.withValues(alpha: 0.25),
                      leading: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isRecording
                              ? AppColors.inversePrimary
                              : Colors.white38,
                          shape: BoxShape.circle,
                        ),
                      ),
                      child: Text(
                        'CAPTURA ACÚSTICA IA',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    _PanelChip(
                      background: Colors.black.withValues(alpha: 0.3),
                      leading: const Icon(Icons.timer_outlined,
                          size: 16, color: AppColors.onPrimaryContainer),
                      child: Text(
                        '00:$seconds / 00:${_sampleDuration.inSeconds.toString().padLeft(2, '0')}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontFamily: 'monospace',
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 144,
                  child: isCountdown
                      ? _CountdownDisplay(value: countdown)
                      : allDone && !isRecording
                          ? const _PanelMessage(
                              icon: Icons.check_circle_outline,
                              text: 'Tienes las 3 muestras. Escúchalas si '
                                  'quieres y luego analízalas con IA.',
                            )
                          : Column(
                              children: [
                                Expanded(
                                  child: ExcludeSemantics(
                                    child: CustomPaint(
                                      size: Size.infinite,
                                      painter: _TracePainter(trace),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      for (final t in const ['0 s', '2.5 s', '5 s'])
                                        Text(
                                          t,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            letterSpacing: 0.6,
                                            color: AppColors.onPrimaryContainer,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _MiniMetric(
                        label: 'Volumen',
                        value: isRecording ? '${(level * 100).round()}%' : '—',
                        status: levelLabel,
                        statusColor: levelColor,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _MiniMetric(
                        label: 'Duración',
                        value: '${(elapsed.inMilliseconds / 1000).toStringAsFixed(1)} s',
                        status: 'de ${_sampleDuration.inSeconds} s',
                        statusColor: AppColors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _MiniMetric(
                        label: 'Muestras',
                        value: '$doneCount/$_totalSamples',
                        status: doneCount == _totalSamples
                            ? 'Completas'
                            : 'Faltan ${_totalSamples - doneCount}',
                        statusColor: doneCount == _totalSamples
                            ? const Color(0xFF6EE7B7)
                            : AppColors.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final double size;
  final Color color;

  const _Glow({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [BoxShadow(color: color, blurRadius: 40, spreadRadius: 10)],
        ),
      ),
    );
  }
}

/// Curva del volumen real a lo largo de la muestra, con el degradado
/// y la línea brillante del diseño.
class _TracePainter extends CustomPainter {
  final List<double> levels;

  _TracePainter(this.levels);

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = size.width;
    double yFor(double v) => h - 10 - v * (h - 24);

    // Sin datos: línea base tenue.
    final points = <Offset>[
      for (var i = 0; i < levels.length; i++)
        Offset(w * i / (_tracePoints - 1), yFor(levels[i])),
    ];
    if (points.length < 2) {
      final base = Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(0, yFor(0.05)), Offset(w, yFor(0.05)), base);
      return;
    }

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      line.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
    }
    line.lineTo(points.last.dx, points.last.dy);

    final fill = Path.from(line)
      ..lineTo(points.last.dx, h)
      ..lineTo(points.first.dx, h)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCCFFB3B0), Color(0x66DA3148), Color(0x009E1B26)],
          stops: [0, 0.5, 1],
        ).createShader(Offset.zero & size)
        ..color = Colors.white.withValues(alpha: 0.65),
    );

    canvas.drawPath(
      line,
      Paint()
        ..shader = const LinearGradient(
          colors: [AppColors.primaryFixed, Colors.white, AppColors.primaryFixed],
        ).createShader(Offset.zero & size)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.75
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Punto brillante en la posición actual.
    final head = points.last;
    canvas.drawCircle(
      head,
      8,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(head, 3.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _TracePainter old) => old.levels != levels;
}

class _PanelChip extends StatelessWidget {
  final Widget child;
  final Widget leading;
  final Color background;

  const _PanelChip({
    required this.child,
    required this.leading,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [leading, const SizedBox(width: 6), child],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final String status;
  final Color statusColor;

  const _MiniMetric({
    required this.label,
    required this.value,
    required this.status,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$label: $value, $status',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: AppColors.onPrimaryContainer),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            Text(
              status,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: statusColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountdownDisplay extends StatelessWidget {
  final int value;

  const _CountdownDisplay({required this.value});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Comienza en $value',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Text(
              '$value',
              key: ValueKey(value),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 72,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Inhala profundo…',
            style: TextStyle(color: AppColors.primaryFixed, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _PanelMessage extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PanelMessage({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white, size: 40),
        const SizedBox(height: 8),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ],
    );
  }
}

/// Fila de muestra con el estilo de "Telemetría" del diseño.
class _SampleTile extends StatelessWidget {
  final int index;
  final _Sample? sample;
  final bool isRecording;
  final bool isPlaying;
  final bool enabled;
  final VoidCallback onPlay;
  final VoidCallback onRedo;

  const _SampleTile({
    required this.index,
    required this.sample,
    required this.isRecording,
    required this.isPlaying,
    required this.enabled,
    required this.onPlay,
    required this.onRedo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final done = sample != null;
    final quiet = sample?.isQuiet ?? false;

    final (String subtitle, String status, Color statusColor) = isRecording
        ? ('Captura en curso', 'Grabando…', scheme.secondary)
        : !done
            ? ('Vocal /a/ sostenida', 'Pendiente', scheme.onSurfaceVariant)
            : quiet
                ? ('Considera repetirla', 'Volumen bajo', AppColors.riskModerate)
                : ('Volumen adecuado', 'Lista', AppColors.riskLow);

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      shadow: AppShadows.small,
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: scheme.surfaceContainerLow,
            child: Icon(
              done
                  ? (quiet ? Icons.priority_high : Icons.check)
                  : isRecording
                      ? Icons.mic
                      : Icons.graphic_eq,
              size: 22,
              color: done ? statusColor : scheme.secondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Muestra ${index + 1}', style: theme.textTheme.titleSmall),
                Text(
                  subtitle,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                done ? '${(sample!.avgLevel * 100).round()}%' : '—',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(status,
                  style: theme.textTheme.labelSmall?.copyWith(color: statusColor)),
            ],
          ),
          if (done) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: isPlaying ? 'Detener' : 'Escuchar muestra ${index + 1}',
              onPressed: enabled ? onPlay : null,
              color: scheme.primary,
              icon: Icon(isPlaying
                  ? Icons.stop_circle_outlined
                  : Icons.play_circle_outline),
            ),
            IconButton(
              tooltip: 'Repetir muestra ${index + 1}',
              onPressed: enabled ? onRedo : null,
              color: scheme.onSurfaceVariant,
              icon: const Icon(Icons.refresh),
            ),
          ] else
            const SizedBox(width: 10),
        ],
      ),
    );
  }
}

/// Tarjeta inferior de controles: Escuchar · Micrófono · Reiniciar + Analizar.
class _ControlsCard extends StatelessWidget {
  final bool busy;
  final bool canRecord;
  final bool canListen;
  final bool isListening;
  final bool canReset;
  final bool canAnalyze;
  final int remaining;
  final Animation<double> pulse;
  final VoidCallback onRecord;
  final VoidCallback onListen;
  final VoidCallback onReset;
  final VoidCallback onAnalyze;

  const _ControlsCard({
    required this.busy,
    required this.canRecord,
    required this.canListen,
    required this.isListening,
    required this.canReset,
    required this.canAnalyze,
    required this.remaining,
    required this.pulse,
    required this.onRecord,
    required this.onListen,
    required this.onReset,
    required this.onAnalyze,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SoftCard(
      shadow: const [
        BoxShadow(color: Color(0x1A000000), blurRadius: 15, offset: Offset(0, 10)),
      ],
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SideButton(
                icon: isListening ? Icons.stop : Icons.play_arrow,
                label: isListening ? 'Detener' : 'Escuchar',
                onTap: canListen ? onListen : null,
              ),
              _MicButton(
                busy: busy,
                enabled: canRecord || busy,
                pulse: pulse,
                onPressed: onRecord,
              ),
              _SideButton(
                icon: Icons.replay,
                label: 'Reiniciar',
                onTap: canReset ? onReset : null,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            button: true,
            enabled: canAnalyze,
            child: Opacity(
              opacity: canAnalyze ? 1 : 0.45,
              child: Material(
                color: scheme.primaryContainer,
                shape: const StadiumBorder(),
                elevation: canAnalyze ? 3 : 0,
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: canAnalyze ? onAnalyze : null,
                  child: SizedBox(
                    height: 52,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: Row(
                        children: [
                          Icon(Icons.psychology_outlined, color: scheme.onPrimary, size: 22),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              canAnalyze
                                  ? 'Finalizar y Analizar con IA'
                                  : 'Faltan $remaining '
                                      '${remaining == 1 ? 'muestra' : 'muestras'}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: scheme.onPrimary,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: scheme.onPrimary,
                            child: Icon(Icons.arrow_forward,
                                size: 18, color: scheme.primaryContainer),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SideButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _SideButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = onTap != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainer,
                    shape: BoxShape.circle,
                    boxShadow: AppShadows.small,
                  ),
                  child: Icon(icon, color: scheme.onSurface),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  final bool busy;
  final bool enabled;
  final Animation<double> pulse;
  final VoidCallback onPressed;

  const _MicButton({
    required this.busy,
    required this.enabled,
    required this.pulse,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      enabled: enabled,
      label: busy ? 'Cancelar grabación' : 'Iniciar grabación',
      excludeSemantics: true,
      child: SizedBox(
        width: 104,
        height: 104,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Anillos de pulso mientras se graba.
            if (busy)
              AnimatedBuilder(
                animation: pulse,
                builder: (_, _) {
                  final t = pulse.value;
                  return Container(
                    width: 72 + 32 * t,
                    height: 72 + 32 * t,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.secondaryContainer
                          .withValues(alpha: 0.25 * (1 - t)),
                    ),
                  );
                },
              ),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondaryFixedDim
                    .withValues(alpha: enabled ? 0.4 : 0.15),
              ),
            ),
            Material(
              color: enabled
                  ? scheme.secondaryContainer
                  : scheme.surfaceContainerHighest,
              shape: const CircleBorder(),
              elevation: enabled ? 8 : 0,
              shadowColor: scheme.secondaryContainer,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: enabled ? onPressed : null,
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: Icon(
                    busy ? Icons.stop_rounded : Icons.mic,
                    size: 36,
                    color: enabled
                        ? scheme.onSecondaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: scheme.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No se pudo completar el análisis',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: scheme.onErrorContainer),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$message\nTus muestras se conservaron.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: scheme.onErrorContainer),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar análisis'),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta "Consigna Clínica".
class _InstructionCard extends StatelessWidget {
  const _InstructionCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.small,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: scheme.secondaryFixed,
            child: Icon(Icons.record_voice_over, color: scheme.primary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'CONSIGNA CLÍNICA',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.secondary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    Text(
                      'Prueba Fonatoria',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'Tras la cuenta regresiva, pronuncie la vocal '),
                    TextSpan(
                      text: '“AAAA”',
                      style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const TextSpan(
                      text: ' de forma sostenida a un volumen constante y '
                          'natural durante 5 segundos.',
                    ),
                  ]),
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(Icons.straighten, size: 16, color: scheme.primary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Mantenga el móvil a 15-20 cm de su boca',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyzingView extends StatelessWidget {
  final Duration elapsed;

  const _AnalyzingView({required this.elapsed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mm = elapsed.inMinutes;
    final ss = (elapsed.inSeconds % 60).toString().padLeft(2, '0');

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              SizedBox(
                width: 88,
                height: 88,
                child: CircularProgressIndicator(
                  strokeWidth: 6,
                  color: scheme.primaryContainer,
                  backgroundColor: scheme.primaryFixed,
                ),
              ),
              const SizedBox(height: 28),
              Text('Analizando tu voz', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Enviamos tus $_totalSamples muestras al servidor de análisis. '
                'Esto puede tardar hasta un minuto; no cierres la app.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Semantics(
                label: 'Tiempo transcurrido $mm minutos $ss segundos',
                excludeSemantics: true,
                child: Text(
                  'Tiempo transcurrido: $mm:$ss',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.primary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'QUÉ SE ESTÁ EVALUANDO',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.secondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final item in const [
                      'Estabilidad del tono y del volumen (Jitter, Shimmer)',
                      'Claridad de la voz (HNR)',
                      'Regularidad de la vibración vocal (PPE, RPDE)',
                    ])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.graphic_eq, size: 18, color: scheme.secondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(item, style: theme.textTheme.bodyMedium),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpSheet extends StatelessWidget {
  const _HelpSheet();

  static const _tips = [
    (Icons.volume_off_outlined,
        'Busca un lugar silencioso, sin TV, música ni ventiladores.'),
    (Icons.chair_outlined,
        'Siéntate con la espalda recta y los hombros relajados.'),
    (Icons.timer_outlined,
        'Tras la cuenta regresiva, di "Aaaa" sin parar durante 5 segundos.'),
    (Icons.replay,
        'Graba 3 muestras. Puedes escuchar y repetir cualquiera de ellas.'),
    (Icons.medication_outlined,
        'Si tomas medicación, haz la prueba siempre a la misma hora '
            'respecto a tu dosis para comparar resultados.'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cómo hacer la prueba', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 16),
            for (final (icon, text) in _tips)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: theme.colorScheme.secondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(text, style: theme.textTheme.bodyLarge),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

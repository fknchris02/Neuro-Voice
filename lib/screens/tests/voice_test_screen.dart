import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../services/database_helper.dart';
import '../../services/parkinson_api.dart';
import '../../theme/app_theme.dart';
import '../../theme/liquid_glass.dart';
import '../../widgets/neuro_app_bar.dart';
import '../../widgets/supervisor_card.dart';
import '../biomarker_report_screen.dart';

const _totalSamples = 3;
const _sampleDuration = Duration(seconds: 5);
const _countdownSeconds = 3;
const _amplitudeInterval = Duration(milliseconds: 100);

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
    with TickerProviderStateMixin {
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
  Timer? _tickTimer;
  StreamSubscription<Amplitude>? _ampSub;
  StreamSubscription<void>? _playerSub;

  /// Volumen de la muestra en curso. Cambia sin setState: sólo se repintan
  /// la curva y los indicadores que lo escuchan, no toda la pantalla.
  final _live = _LiveTrace();
  double _levelSum = 0;
  int _levelCount = 0;

  late final AnimationController _pulse;

  /// Avance de la muestra (0 → 1 en [_sampleDuration]); mueve la curva a 60 fps.
  late final AnimationController _progress;

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
    _progress = AnimationController(vsync: this, duration: _sampleDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _finishRecording();
      });
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
    _progress.dispose();
    _live.dispose();
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
    });
    _live.clear();
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

      _live.clear();
      _levelSum = 0;
      _levelCount = 0;
      setState(() => _phase = _Phase.recording);
      _ampSub =
          _recorder.onAmplitudeChanged(_amplitudeInterval).listen(_onAmplitude);
      // Al completarse, el listener de _progress cierra la muestra.
      _progress.forward(from: 0);
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
    _levelSum += normalized;
    _levelCount++;
    _live.add(_progress.value, normalized);
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

    _progress.value = 0;
    setState(() {
      _recordingSlot = null;
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
    _progress.value = 0;
    _live.clear();
    setState(() {
      _phase = _Phase.idle;
      _recordingSlot = null;
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
    _progress.stop();
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
      if (_phase == _Phase.error) _phase = _Phase.idle;
    });
    _live.clear();
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
    });

    try {
      final patient = await DatabaseHelper.instance.getUserProfile();
      if (patient?.folio == null) {
        throw const ApiException(
          'Este teléfono no tiene un folio vinculado. '
          'Ve a Perfil → Cambiar folio e ingrésalo.',
        );
      }
      final prediction = await ParkinsonApi.predict(
        _samples.map((s) => s!.path).toList(),
        patient: patient!,
      );

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
        // Grabación ⇄ análisis con un fundido suave en lugar de un corte.
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          switchInCurve: const Interval(0.35, 1, curve: Curves.easeOutCubic),
          switchOutCurve: const Interval(0.35, 1, curve: Curves.easeInCubic),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween(begin: 0.97, end: 1.0).animate(animation),
              child: child,
            ),
          ),
          child: _phase == _Phase.analyzing
              ? const _AnalyzingView(key: ValueKey('analyzing'))
              : KeyedSubtree(
                  key: const ValueKey('recorder'),
                  child: _buildRecorder(),
                ),
        ),
      ),
    );
  }

  Widget _buildRecorder() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final slot = _recordingSlot ?? _nextSlot;
    final lastDone = _lastDoneSlot;

    // Entrada escalonada de las secciones la primera vez que se abre.
    var order = 0;
    Widget reveal(String key, Widget child) => Reveal(
          key: ValueKey(key),
          delay: Duration(milliseconds: 50 * order++),
          child: child,
        );

    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.margin, AppSpacing.sm, AppSpacing.margin, AppSpacing.xl),
        children: [
          reveal(
            'status',
            _StatusRow(
              patientName: _patientName,
              sampleLabel: slot == null
                  ? 'Muestras completas'
                  : 'Muestra ${slot + 1} de $_totalSamples',
              live: _phase == _Phase.recording,
              onHelp: _showHelp,
            ),
          ),
          const SizedBox(height: 12),
          reveal(
            'supervisor',
            SupervisorCard(
              caption: 'Supervisión clínica',
              trailing:
                  _ServerChip(online: _serverOnline, onRetry: _checkServer),
            ),
          ),
          if (_phase == _Phase.error && _errorMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            Reveal(
              key: const ValueKey('error'),
              child: _ErrorCard(message: _errorMessage!, onRetry: _analyze),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          reveal(
            'panel',
            _CapturePanel(
              phase: _phase,
              countdown: _countdown,
              progress: _progress,
              live: _live,
              doneCount: _doneCount,
              allDone: slot == null,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          reveal('instructions', const _InstructionCard()),
          const SizedBox(height: 20),
          reveal(
            'samples-header',
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
                  _Dots(done: _doneCount),
                  const SizedBox(width: 6),
                  Text(
                    '$_doneCount de $_totalSamples',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: scheme.secondary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < _totalSamples; i++) ...[
            reveal(
              'sample-$i',
              _SampleTile(
                index: i,
                sample: _samples[i],
                isRecording: _recordingSlot == i,
                isPlaying: _playingSlot == i,
                enabled: !_isBusy,
                onPlay: () => _togglePlayback(i),
                onRedo: () => _redoSample(i),
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 10),
          reveal(
            'controls',
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
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════ Estado en vivo

/// Lecturas del micrófono de la muestra en curso: (avance 0–1, nivel 0–1).
class _LiveTrace extends ChangeNotifier {
  final List<Offset> points = [];

  double get level => points.isEmpty ? 0 : points.last.dy;

  void add(double at, double level) {
    if (points.length >= 120) return;
    points.add(Offset(at, level));
    notifyListeners();
  }

  void clear() {
    if (points.isEmpty) return;
    points.clear();
    notifyListeners();
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
          child: GlassCard(
            radius: 99,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shadows: Glass.shadow(context, depth: 0.35),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: live ? scheme.secondary : scheme.primaryContainer,
                    shape: BoxShape.circle,
                    boxShadow: live
                        ? [
                            BoxShadow(
                              color: scheme.secondary.withValues(alpha: 0.6),
                              blurRadius: 8,
                            ),
                          ]
                        : const [],
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
                  Text('  •  ',
                      style: label?.copyWith(color: scheme.outlineVariant)),
                ],
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    sampleLabel,
                    key: ValueKey(sampleLabel),
                    style: label?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        _GlassIconButton(
          icon: Icons.help_outline_rounded,
          tooltip: 'Cómo hacer la prueba',
          onTap: onHelp,
        ),
      ],
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _GlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: 40,
        child: GlassCard(
          radius: 20,
          padding: EdgeInsets.zero,
          shadows: Glass.shadow(context, depth: 0.35),
          onTap: onTap,
          child: Center(
            child: Icon(icon,
                size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      ),
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
      child: GlassCard(
        radius: 99,
        tint: color.withValues(alpha: 0.10),
        shadows: const [],
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        onTap: online == false ? onRetry : null,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Row(
            key: ValueKey(online),
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(text,
                  style: theme.textTheme.labelSmall?.copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Indicador de 3 puntos: se rellenan conforme hay muestras.
class _Dots extends StatelessWidget {
  final int done;

  const _Dots({required this.done});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var i = 0; i < _totalSamples; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            margin: const EdgeInsets.only(left: 3),
            width: i < done ? 14 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i < done ? scheme.secondary : scheme.outlineVariant,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

/// Panel carmesí de cristal "Captura Acústica IA".
class _CapturePanel extends StatelessWidget {
  final _Phase phase;
  final int countdown;
  final Animation<double> progress;
  final _LiveTrace live;
  final int doneCount;
  final bool allDone;

  const _CapturePanel({
    required this.phase,
    required this.countdown,
    required this.progress,
    required this.live,
    required this.doneCount,
    required this.allDone,
  });

  static const _radius = AppRadius.xl + 4;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRecording = phase == _Phase.recording;
    final isCountdown = phase == _Phase.countdown;
    final total = _sampleDuration.inSeconds;

    final Widget stage = isCountdown
        ? _CountdownDisplay(key: const ValueKey('countdown'), value: countdown)
        : allDone && !isRecording
            ? const _PanelMessage(
                key: ValueKey('done'),
                icon: Icons.check_circle_outline_rounded,
                text: 'Tienes las 3 muestras. Escúchalas si '
                    'quieres y luego analízalas con IA.',
              )
            : Column(
                key: const ValueKey('trace'),
                children: [
                  Expanded(
                    child: ExcludeSemantics(
                      // Sólo la curva se repinta a 60 fps.
                      child: RepaintBoundary(
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: _TracePainter(
                            live: live,
                            progress: progress,
                            playing: isRecording,
                          ),
                        ),
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
              );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.38),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFB8202F),
                AppColors.primaryContainer,
                AppColors.primary,
              ],
              stops: [0, 0.5, 1],
            ),
          ),
          child: CustomPaint(
            foregroundPainter:
                const GlassRimPainter(radius: _radius, strength: 0.55),
            child: Stack(
              children: [
                // Brillos ambientales con degradados radiales: se ven igual
                // que una sombra desenfocada pero no cuestan al repintar.
                const Positioned(
                  right: -70,
                  top: -70,
                  child: _Glow(size: 220, color: Color(0x55FF6B81)),
                ),
                const Positioned(
                  left: -60,
                  bottom: -60,
                  child: _Glow(size: 200, color: Color(0x66570010)),
                ),
                // Reflejo superior del cristal.
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 64,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.12),
                            Colors.white.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // El chip se encoge si no cabe (pantalla angosta o
                          // letra grande) en vez de desbordarse.
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: _PanelChip(
                                leading: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: isRecording
                                        ? AppColors.inversePrimary
                                        : Colors.white38,
                                    shape: BoxShape.circle,
                                    boxShadow: isRecording
                                        ? const [
                                            BoxShadow(
                                              color: AppColors.inversePrimary,
                                              blurRadius: 6,
                                            ),
                                          ]
                                        : const [],
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
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          RepaintBoundary(
                            child: _PanelChip(
                              leading: const Icon(Icons.timer_outlined,
                                  size: 16, color: AppColors.onPrimaryContainer),
                              child: AnimatedBuilder(
                                animation: progress,
                                builder: (_, _) {
                                  final s = (progress.value * total)
                                      .floor()
                                      .toString()
                                      .padLeft(2, '0');
                                  return Text(
                                    '00:$s / 00:${total.toString().padLeft(2, '0')}',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: Colors.white,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures()
                                      ],
                                      letterSpacing: 0.8,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        height: 144,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 380),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(
                              scale: Tween(begin: 0.94, end: 1.0)
                                  .animate(animation),
                              child: child,
                            ),
                          ),
                          child: stage,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: RepaintBoundary(
                              child: ListenableBuilder(
                                listenable: live,
                                builder: (_, _) {
                                  final level = live.level;
                                  final (String status, Color color) =
                                      !isRecording
                                          ? ('En espera',
                                              AppColors.onPrimaryContainer)
                                          : level < _quietLevel
                                              ? ('Bajo', Colors.amberAccent)
                                              : level > _loudLevel
                                                  ? ('Alto', Colors.amberAccent)
                                                  : ('Óptimo',
                                                      const Color(0xFF6EE7B7));
                                  return _MiniMetric(
                                    label: 'Volumen',
                                    value: isRecording
                                        ? '${(level * 100).round()}%'
                                        : '—',
                                    status: status,
                                    statusColor: color,
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: RepaintBoundary(
                              child: AnimatedBuilder(
                                animation: progress,
                                builder: (_, _) => _MiniMetric(
                                  label: 'Duración',
                                  value:
                                      '${(progress.value * total).toStringAsFixed(1)} s',
                                  status: 'de $total s',
                                  statusColor: AppColors.onPrimaryContainer,
                                ),
                              ),
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
          ),
        ),
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
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
  }
}

/// Curva del volumen real. Mientras se graba, la punta avanza a 60 fps
/// interpolando entre lecturas del micrófono (llegan cada 100 ms) con el
/// retraso de una lectura, así nunca da saltos.
class _TracePainter extends CustomPainter {
  final _LiveTrace live;
  final Animation<double> progress;
  final bool playing;

  _TracePainter({
    required this.live,
    required this.progress,
    required this.playing,
  }) : super(repaint: Listenable.merge([live, progress]));

  static final _lag =
      _amplitudeInterval.inMilliseconds / _sampleDuration.inMilliseconds;

  List<Offset> _visiblePoints() {
    final src = live.points;
    if (!playing) return src;

    final at = progress.value - _lag;
    final out = <Offset>[];
    for (final p in src) {
      if (p.dx <= at) {
        out.add(p);
        continue;
      }
      if (out.isNotEmpty) {
        final a = out.last;
        final t = ((at - a.dx) / (p.dx - a.dx)).clamp(0.0, 1.0);
        out.add(Offset(at, a.dy + (p.dy - a.dy) * Curves.easeInOut.transform(t)));
      }
      return out;
    }
    // Sin lectura nueva todavía: la punta sigue avanzando al último nivel.
    if (out.isNotEmpty && at > out.last.dx) out.add(Offset(at, out.last.dy));
    return out;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = size.width;
    double yFor(double v) => h - 10 - v * (h - 24);

    final points = [
      for (final p in _visiblePoints())
        Offset(p.dx.clamp(0.0, 1.0) * w, yFor(p.dy)),
    ];

    // Sin datos: línea base tenue.
    if (points.length < 2) {
      canvas.drawLine(
        Offset(0, yFor(0.05)),
        Offset(w, yFor(0.05)),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
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

    final bounds = Offset.zero & size;
    canvas.drawPath(
      fill,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x99FFB3B0), Color(0x40DA3148), Color(0x009E1B26)],
          stops: [0, 0.55, 1],
        ).createShader(bounds),
    );

    canvas.drawPath(
      line,
      Paint()
        ..shader = const LinearGradient(
          colors: [AppColors.primaryFixed, Colors.white, AppColors.primaryFixed],
        ).createShader(bounds)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.75
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    if (!playing) return;
    // Punta luminosa en la posición actual.
    final head = points.last;
    canvas.drawCircle(
      head,
      12,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: head, radius: 12)),
    );
    canvas.drawCircle(head, 3.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _TracePainter old) =>
      old.live != live || old.progress != progress || old.playing != playing;
}

class _PanelChip extends StatelessWidget {
  final Widget child;
  final Widget leading;

  const _PanelChip({required this.child, required this.leading});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
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
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.12),
              Colors.white.withValues(alpha: 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
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
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
              child: Text(status),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountdownDisplay extends StatelessWidget {
  final int value;

  const _CountdownDisplay({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Comienza en $value',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            // Cada número "cae" con un pequeño rebote.
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 420),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(
                  scale: Tween(begin: 1.6, end: 1.0).animate(anim),
                  child: child,
                ),
              ),
              child: Text(
                '$value',
                key: ValueKey(value),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Inhala profundo…',
            style: TextStyle(color: AppColors.primaryFixed, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _PanelMessage extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PanelMessage({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: Icon(icon, color: Colors.white, size: 32),
        ),
        const SizedBox(height: 10),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.35),
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

    final icon = done
        ? (quiet ? Icons.priority_high_rounded : Icons.check_rounded)
        : isRecording
            ? Icons.mic_rounded
            : Icons.graphic_eq_rounded;

    return SoftCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      shadow: Glass.shadow(context, depth: 0.5),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (done || isRecording ? statusColor : scheme.secondary)
                  .withValues(alpha: isRecording ? 0.18 : 0.10),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, a) =>
                  ScaleTransition(scale: a, child: child),
              child: Icon(
                icon,
                key: ValueKey(icon),
                size: 22,
                color: done ? statusColor : scheme.secondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Muestra ${index + 1}', style: theme.textTheme.titleSmall),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    subtitle,
                    key: ValueKey(subtitle),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w400,
                    ),
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
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                style: theme.textTheme.labelSmall!.copyWith(color: statusColor),
                child: Text(status),
              ),
            ],
          ),
          // Los botones aparecen deslizándose al terminar la muestra.
          AnimatedSize(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            child: done
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: isPlaying
                            ? 'Detener'
                            : 'Escuchar muestra ${index + 1}',
                        onPressed: enabled ? onPlay : null,
                        color: scheme.primary,
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            isPlaying
                                ? Icons.stop_circle_outlined
                                : Icons.play_circle_outline,
                            key: ValueKey(isPlaying),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Repetir muestra ${index + 1}',
                        onPressed: enabled ? onRedo : null,
                        color: scheme.onSurfaceVariant,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  )
                : const SizedBox(width: 10),
          ),
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
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md),
      shadows: Glass.shadow(context, depth: 1.2),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SideButton(
                icon: isListening ? Icons.stop_rounded : Icons.play_arrow_rounded,
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
                icon: Icons.replay_rounded,
                label: 'Reiniciar',
                onTap: canReset ? onReset : null,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _AnalyzeButton(
            enabled: canAnalyze,
            remaining: remaining,
            onTap: onAnalyze,
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
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.4,
        duration: const Duration(milliseconds: 250),
        child: Column(
          children: [
            SizedBox.square(
              dimension: 50,
              child: GlassCard(
                radius: 25,
                padding: EdgeInsets.zero,
                shadows: Glass.shadow(context, depth: 0.45),
                onTap: onTap,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, a) =>
                        ScaleTransition(scale: a, child: child),
                    child: Icon(icon, key: ValueKey(icon), color: scheme.onSurface),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
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
        width: 112,
        height: 112,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ondas mientras se graba: pintadas, sin reconstruir widgets.
            if (busy)
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _RipplePainter(pulse, color: scheme.secondaryContainer),
                  ),
                ),
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondaryFixedDim
                    .withValues(alpha: enabled ? 0.35 : 0.12),
              ),
            ),
            PressableScale(
              scale: 0.9,
              enabled: enabled,
              child: AnimatedOpacity(
                opacity: enabled ? 1 : 0.45,
                duration: const Duration(milliseconds: 250),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: enabled ? Glass.crimson : null,
                    color: enabled ? null : scheme.surfaceContainerHighest,
                    boxShadow: enabled
                        ? [
                            BoxShadow(
                              color: AppColors.secondaryContainer
                                  .withValues(alpha: 0.5),
                              blurRadius: 22,
                              offset: const Offset(0, 10),
                            ),
                          ]
                        : const [],
                  ),
                  child: CustomPaint(
                    foregroundPainter:
                        const GlassRimPainter(radius: 38, strength: 0.6),
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: enabled ? onPressed : null,
                        child: SizedBox.square(
                          dimension: 76,
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 280),
                              transitionBuilder: (child, a) => RotationTransition(
                                turns: Tween(begin: 0.75, end: 1.0).animate(a),
                                child: ScaleTransition(scale: a, child: child),
                              ),
                              child: Icon(
                                busy ? Icons.stop_rounded : Icons.mic_rounded,
                                key: ValueKey(busy),
                                size: 36,
                                color: enabled
                                    ? Colors.white
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
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

/// Dos ondas desfasadas que salen del botón del micrófono.
class _RipplePainter extends CustomPainter {
  final Animation<double> t;
  final Color color;

  _RipplePainter(this.t, {required this.color}) : super(repaint: t);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;
    for (final phase in const [0.0, 0.5]) {
      final v = (t.value + phase) % 1;
      final r = 38 + (maxR - 38) * Curves.easeOut.transform(v);
      canvas.drawCircle(
        center,
        r,
        Paint()..color = color.withValues(alpha: 0.28 * (1 - v)),
      );
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.t != t || old.color != color;
}

class _AnalyzeButton extends StatelessWidget {
  final bool enabled;
  final int remaining;
  final VoidCallback onTap;

  const _AnalyzeButton({
    required this.enabled,
    required this.remaining,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = enabled ? Colors.white : scheme.onSurfaceVariant;
    final label = enabled
        ? 'Finalizar y Analizar con IA'
        : 'Faltan $remaining ${remaining == 1 ? 'muestra' : 'muestras'}';

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: PressableScale(
        enabled: enabled,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            gradient: enabled ? Glass.crimson : null,
            color: enabled ? null : scheme.onSurface.withValues(alpha: 0.07),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : const [],
          ),
          child: CustomPaint(
            foregroundPainter: enabled
                ? const GlassRimPainter(radius: 28, strength: 0.55)
                : null,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: enabled ? onTap : null,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, 12, 0),
                  child: Row(
                    children: [
                      Icon(Icons.psychology_outlined, color: fg, size: 22),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          layoutBuilder: (current, previous) => Stack(
                            alignment: Alignment.centerLeft,
                            children: [...previous, ?current],
                          ),
                          child: Text(
                            label,
                            key: ValueKey(label),
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: fg,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: enabled
                              ? Colors.white
                              : scheme.onSurface.withValues(alpha: 0.10),
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: enabled
                              ? AppColors.primaryContainer
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
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
    return GlassCard(
      tint: scheme.errorContainer.withValues(alpha: 0.9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer),
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
            icon: const Icon(Icons.refresh_rounded),
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
    return GlassCard(
      shadows: Glass.shadow(context, depth: 0.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: scheme.secondaryFixed,
            child: Icon(Icons.record_voice_over, color: scheme.primary),
          ),
          const SizedBox(width: 12),
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
                    const TextSpan(
                        text: 'Tras la cuenta regresiva, pronuncie la vocal '),
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

/// Pantalla de espera del análisis. Lleva su propio cronómetro para no
/// reconstruir toda la pantalla de grabación cada segundo.
class _AnalyzingView extends StatefulWidget {
  const _AnalyzingView({super.key});

  @override
  State<_AnalyzingView> createState() => _AnalyzingViewState();
}

class _AnalyzingViewState extends State<_AnalyzingView> {
  static const _steps = [
    'Limpiando el ruido de fondo…',
    'Extrayendo biomarcadores acústicos…',
    'Calculando la probabilidad con IA…',
  ];

  static const _evaluated = [
    'Estabilidad del tono y del volumen (Jitter, Shimmer)',
    'Claridad de la voz (HNR)',
    'Regularidad de la vibración vocal (PPE, RPDE, DFA)',
  ];

  final _startedAt = DateTime.now();
  Timer? _timer;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _seconds = DateTime.now().difference(_startedAt).inSeconds);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mm = _seconds ~/ 60;
    final ss = (_seconds % 60).toString().padLeft(2, '0');
    final step = _steps[(_seconds ~/ 4) % _steps.length];

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              const _AnalysisOrb(),
              const SizedBox(height: 24),
              Text('Analizando tu voz', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 6),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, 0.4),
                      end: Offset.zero,
                    ).animate(a),
                    child: child,
                  ),
                ),
                child: Text(
                  step,
                  key: ValueKey(step),
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: scheme.primary),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Enviamos tus $_totalSamples muestras al servidor de análisis. '
                'Esto puede tardar hasta un minuto; no cierres la app.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              Semantics(
                label: 'Tiempo transcurrido $mm minutos $ss segundos',
                excludeSemantics: true,
                child: GlassCard(
                  radius: 99,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  shadows: Glass.shadow(context, depth: 0.35),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_outlined, size: 16, color: scheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        '$mm:$ss',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.primary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Reveal(
                delay: const Duration(milliseconds: 200),
                child: SoftCard(
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
                      for (final (i, item) in _evaluated.indexed)
                        Reveal(
                          delay: Duration(milliseconds: 350 + 120 * i),
                          offset: 10,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.graphic_eq,
                                    size: 18, color: scheme.secondary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(item,
                                      style: theme.textTheme.bodyMedium),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Orbe animado del análisis: ondas que se expanden, un arco que gira y un
/// núcleo que "respira". Un solo controlador y todo pintado en su capa.
class _AnalysisOrb extends StatefulWidget {
  const _AnalysisOrb();

  @override
  State<_AnalysisOrb> createState() => _AnalysisOrbState();
}

class _AnalysisOrbState extends State<_AnalysisOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: 180,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(painter: _OrbPainter(_c)),
              ),
            ),
            AnimatedBuilder(
              animation: _c,
              builder: (_, child) => Transform.scale(
                scale: 1 + 0.045 * math.sin(_c.value * 4 * math.pi),
                child: child,
              ),
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: Glass.crimson,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.45),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: const CustomPaint(
                  foregroundPainter: GlassRimPainter(radius: 42, strength: 0.6),
                  child: Center(
                    child: Icon(Icons.graphic_eq_rounded,
                        color: Colors.white, size: 38),
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

class _OrbPainter extends CustomPainter {
  final Animation<double> t;

  _OrbPainter(this.t) : super(repaint: t);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;

    // Ondas que se expanden desde el núcleo.
    for (var i = 0; i < 3; i++) {
      final v = (t.value + i / 3) % 1;
      canvas.drawCircle(
        c,
        46 + (maxR - 46) * Curves.easeOut.transform(v),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppColors.secondaryContainer.withValues(alpha: 0.35 * (1 - v)),
      );
    }

    // Pista y arco giratorio con estela.
    const ringR = 60.0;
    final rect = Rect.fromCircle(center: c, radius: ringR);
    canvas.drawCircle(
      c,
      ringR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = AppColors.primaryFixed.withValues(alpha: 0.55),
    );
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(t.value * 2 * math.pi);
    canvas.translate(-c.dx, -c.dy);
    const sweep = math.pi * 1.2;
    canvas.drawArc(
      rect,
      0,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          endAngle: sweep,
          colors: [
            AppColors.secondaryContainer.withValues(alpha: 0),
            AppColors.secondaryContainer,
            AppColors.primaryContainer,
          ],
          stops: const [0, 0.7, 1],
        ).createShader(rect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OrbPainter old) => old.t != t;
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

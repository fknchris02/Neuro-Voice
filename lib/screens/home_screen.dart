import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';

import '../models/test_result.dart';
import '../models/voice_prediction.dart';
import '../services/database_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/home_widgets.dart';
import '../widgets/neuro_app_bar.dart';
import 'biomarker_report_screen.dart';
import 'tests/voice_test_screen.dart';

class HomePage extends StatefulWidget {
  /// Cambia a la pestaña de Perfil del dashboard.
  final VoidCallback? onOpenProfile;

  const HomePage({super.key, this.onOpenProfile});

  @override
  State<HomePage> createState() => _HomePageState();
}

enum _Category { fonacion, diadococinesia, lectura, temblor }

class _HomePageState extends State<HomePage> {
  static const _chips = [
    'Todas',
    'Fonación /a:/',
    'Diadococinesia',
    'Lectura de Texto',
    'Temblor Vocal',
  ];

  String _userName = '';
  TestResult? _lastVoice;
  bool _loading = true;

  /// 0 = Todas; 1..n = índice en [_Category] + 1.
  int _filter = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseHelper.instance;
    final profile = await db.getUserProfile();
    final voice = await db.getTestResultsByType('voice');
    if (!mounted) return;
    setState(() {
      _userName = profile?.name ?? '';
      _lastVoice = voice.isEmpty ? null : voice.first;
      _loading = false;
    });
  }

  bool _visible(_Category c) => _filter == 0 || _filter == c.index + 1;

  Future<void> _openVoiceTest() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VoiceTestScreen()),
    );
    _load();
  }

  void _openLastReport() {
    final r = _lastVoice;
    if (r == null) return;
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

  void _comingSoon(String name) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('$name estará disponible próximamente.'),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final cards = <Widget>[
      if (_visible(_Category.fonacion))
        HeroTestCard(
          title: 'Prueba Fonatoria Sostenida (/a:/)',
          description: 'Evaluación acústica de estabilidad, jitter, shimmer '
              'y razón armónico-ruido para detección precoz.',
          duration: '15 seg',
          onTap: _openVoiceTest,
        ),
      if (_visible(_Category.diadococinesia))
        SecondaryTestCard(
          icon: Icons.graphic_eq,
          iconColor: scheme.secondary,
          title: 'Diadococinesia Oral',
          tag: '/pa-ta-ka/',
          description: 'Coordinación motora rápida y agilidad articulatoria lingual',
          meta: const [
            TestMeta(Icons.timer_outlined, 'Duración: 30 seg'),
            TestMeta(Icons.show_chart, '2 Métricas clínicas', highlight: true),
          ],
          comingSoon: true,
          onTap: () => _comingSoon('Diadococinesia Oral'),
        ),
      if (_visible(_Category.lectura))
        SecondaryTestCard(
          icon: Icons.psychology_outlined,
          iconColor: scheme.primary,
          title: 'Lectura de Prosa Fonética',
          description: 'Prosodia, cadencia respiratoria y modulación del tono',
          meta: const [
            TestMeta(Icons.timer_outlined, 'Duración: 45 seg'),
            TestMeta(Icons.record_voice_over_outlined, 'Texto fonológico'),
          ],
          comingSoon: true,
          onTap: () => _comingSoon('Lectura de Prosa Fonética'),
        ),
      if (_visible(_Category.temblor))
        SecondaryTestCard(
          icon: Icons.monitor_heart_outlined,
          iconColor: scheme.secondaryContainer,
          title: 'Temblor Vocal de Reposo',
          description: 'Micro-oscilaciones neurológicas involuntarias en frecuencias bajas',
          meta: const [
            TestMeta(Icons.timer_outlined, 'Duración: 20 seg'),
            TestMeta(Icons.waves, '4-7 Hz análisis', highlight: true),
          ],
          comingSoon: true,
          onTap: () => _comingSoon('Temblor Vocal de Reposo'),
        ),
    ];

    return Scaffold(
      appBar: NeuroAppBar(
        overline: 'NeuroVoice AI',
        title: 'Inicio',
        onAvatarTap: widget.onOpenProfile,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          // Espacio inferior para la barra de navegación flotante.
          padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: 120),
          children: [
            _padded(FadeInDown(
              duration: const Duration(milliseconds: 400),
              child: GreetingHeader(userName: _userName),
            )),
            const SizedBox(height: AppSpacing.lg),
            _padded(FadeInUp(
              duration: const Duration(milliseconds: 500),
              child: _loading
                  ? const SizedBox(height: 72)
                  : StabilityBanner(
                      prediction: _lastVoice == null
                          ? null
                          : VoicePrediction.fromTestResult(_lastVoice!),
                      timestamp: _lastVoice?.timestamp,
                      onTap: _openLastReport,
                    ),
            )),
            const SizedBox(height: AppSpacing.lg),
            _padded(FadeInUp(
              duration: const Duration(milliseconds: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Evaluaciones y Pruebas Vocales',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(letterSpacing: -0.3),
                  ),
                  Text(
                    'Monitoreo biométrico laríngeo y neurológico asistido por IA',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            )),
            const SizedBox(height: AppSpacing.md),
            FadeInUp(
              duration: const Duration(milliseconds: 650),
              child: TestFilterChips(
                categories: _chips,
                selected: _filter,
                totalCount: _Category.values.length,
                onSelected: (i) => setState(() => _filter = i),
              ),
            ),
            const SizedBox(height: 20),
            for (final (i, card) in cards.indexed) ...[
              _padded(FadeInUp(
                duration: Duration(milliseconds: 700 + i * 80),
                child: card,
              )),
              const SizedBox(height: AppSpacing.md),
            ],
            const SizedBox(height: AppSpacing.sm),
            _padded(FadeInUp(
              duration: const Duration(milliseconds: 900),
              child: const ClinicalRecommendation(
                title: 'Recomendación',
                text: 'Realiza las pruebas en una habitación silenciosa con '
                    'el micrófono a 15 cm de distancia.',
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _padded(Widget child) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.margin),
        child: child,
      );
}

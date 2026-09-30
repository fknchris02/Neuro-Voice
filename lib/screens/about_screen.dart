import 'package:flutter/material.dart';

import '../models/voice_prediction.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/neuro_app_bar.dart';
import '../widgets/supervisor_card.dart';

/// Información de la app: propósito, funcionamiento, privacidad y aviso
/// médico.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  /// Mantener sincronizado con `version` en pubspec.yaml.
  static const _version = '1.0.0';

  static const _steps = [
    (
      Icons.mic_none,
      'Graba tu voz',
      'Sostén la vocal /a:/ durante 5 segundos, tres veces, en un lugar '
          'silencioso.',
    ),
    (
      Icons.graphic_eq,
      'Análisis acústico',
      'El servidor extrae biomarcadores de tu voz y un modelo de '
          'aprendizaje automático estima la probabilidad de alteraciones '
          'asociadas al Parkinson.',
    ),
    (
      Icons.insights_outlined,
      'Consulta tu reporte',
      'Revisa el resultado y su evolución en el Historial para dar '
          'seguimiento con tu médico.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: const NeuroAppBar(title: 'Acerca de'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ── Encabezado ───────────────────────────
          Center(
            child: Column(
              children: [
                // El logo ya incluye el nombre de la app.
                const AppLogo(size: 180, circular: false),
                const SizedBox(height: 12),
                Text(
                  'Versión $_version',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Qué es ───────────────────────────────
          const _Section(
            title: '¿Qué es NeuroVoice?',
            child: Text(
              'NeuroVoice es una herramienta de apoyo para la detección '
              'temprana y el seguimiento de la enfermedad de Parkinson a '
              'través de la voz. Los cambios sutiles en la estabilidad y '
              'claridad vocal pueden aparecer en etapas tempranas, y la app '
              'te ayuda a medirlos de forma sencilla desde tu teléfono.',
            ),
          ),

          // ── Cómo funciona ────────────────────────
          _Section(
            title: '¿Cómo funciona?',
            child: Column(
              children: [
                for (final (i, (icon, title, text)) in _steps.indexed) ...[
                  if (i > 0) const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: scheme.primary.withValues(alpha: 0.12),
                        child: Icon(icon, size: 20, color: scheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${i + 1}. $title',
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              text,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // ── Biomarcadores ────────────────────────
          _Section(
            title: '¿Qué se analiza?',
            child: Column(
              children: [
                for (final s in biomarkerSpecs)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(s.icon, color: scheme.primary),
                    title: Text(
                      s.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(s.shortDescription),
                  ),
              ],
            ),
          ),

          // ── Supervisión clínica ──────────────────
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: SupervisorCard(
              caption: 'Supervisión clínica',
              verified: true,
            ),
          ),

          // ── Privacidad ───────────────────────────
          const _Section(
            title: 'Privacidad',
            child: Text(
              'Tu historial de resultados se guarda en este teléfono. Para el '
              'análisis, las grabaciones se envían al servidor junto con tu '
              'folio, sexo y edad, y se eliminan del dispositivo al terminar.',
            ),
          ),

          // ── Aviso médico ─────────────────────────
          Card(
            color: AppColors.riskModerate.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.health_and_safety_outlined,
                      color: AppColors.riskModerate),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'NeuroVoice no sustituye el diagnóstico de un '
                      'profesional de la salud. Los resultados son '
                      'orientativos; consulta a tu médico ante cualquier '
                      'duda.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              DefaultTextStyle.merge(
                style: theme.textTheme.bodyMedium,
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

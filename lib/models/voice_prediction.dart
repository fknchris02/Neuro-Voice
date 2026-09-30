import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'test_result.dart';

enum RiskLevel { low, moderate, high }

extension RiskLevelX on RiskLevel {
  String get label => switch (this) {
        RiskLevel.low => 'Riesgo bajo',
        RiskLevel.moderate => 'Riesgo moderado',
        RiskLevel.high => 'Riesgo alto',
      };

  String get guidance => switch (this) {
        RiskLevel.low =>
          'Los patrones de tu voz están dentro de los rangos esperados. '
              'Continúa con tus evaluaciones periódicas.',
        RiskLevel.moderate =>
          'Se detectaron algunas variaciones en tu voz. Tu médico revisará '
              'el resultado; puedes repetir la prueba en otro momento del día.',
        RiskLevel.high =>
          'Se detectaron patrones que conviene revisar. Comparte este '
              'reporte con tu médico para una evaluación clínica completa.',
      };

  Color get color => switch (this) {
        RiskLevel.low => AppColors.riskLow,
        RiskLevel.moderate => AppColors.riskModerate,
        RiskLevel.high => AppColors.riskHigh,
      };

  IconData get icon => switch (this) {
        RiskLevel.low => Icons.check_circle_rounded,
        RiskLevel.moderate => Icons.info_rounded,
        RiskLevel.high => Icons.warning_rounded,
      };

  /// El servidor decide el color; si no lo manda, se usa la probabilidad.
  static RiskLevel resolve(String? serverColor, double probability) {
    switch (serverColor) {
      case 'rojo':
        return RiskLevel.high;
      case 'naranja':
      case 'amarillo':
        return RiskLevel.moderate;
      case 'verde':
        return RiskLevel.low;
    }
    if (probability >= 50) return RiskLevel.high;
    if (probability >= 30) return RiskLevel.moderate;
    return RiskLevel.low;
  }
}

/// Definición de un biomarcador acústico y su valor de referencia.
///
/// Referencias aproximadas del Oxford Parkinson's Disease Detection Dataset
/// (UCI), en la misma escala que devuelve el servidor.
class BiomarkerSpec {
  final String key;
  final String name;
  final String shortDescription;
  final String explanation;
  final IconData icon;
  final double threshold;
  final bool higherIsWorse;
  final int decimals;
  final String unit;

  const BiomarkerSpec({
    required this.key,
    required this.name,
    required this.shortDescription,
    required this.explanation,
    required this.icon,
    required this.threshold,
    required this.higherIsWorse,
    required this.decimals,
    this.unit = '',
  });

  bool isAlert(double value) =>
      higherIsWorse ? value > threshold : value < threshold;

  String format(double value) =>
      '${value.toStringAsFixed(decimals)}${unit.isEmpty ? '' : ' $unit'}';

  String get reference =>
      '${higherIsWorse ? '<' : '>'} ${format(threshold)}';
}

const List<BiomarkerSpec> biomarkerSpecs = [
  BiomarkerSpec(
    key: 'jitter',
    name: 'Jitter',
    shortDescription: 'Estabilidad del tono',
    explanation:
        'Mide cuánto varía el tono de tu voz de una vibración a la siguiente. '
        'Valores altos indican menor control de las cuerdas vocales.',
    icon: Icons.waves,
    threshold: 0.006,
    higherIsWorse: true,
    decimals: 4,
  ),
  BiomarkerSpec(
    key: 'shimmer',
    name: 'Shimmer',
    shortDescription: 'Estabilidad del volumen',
    explanation:
        'Mide cuánto varía la intensidad de tu voz entre vibraciones. '
        'Valores altos suelen asociarse a una voz más temblorosa.',
    icon: Icons.blur_linear,
    threshold: 0.030,
    higherIsWorse: true,
    decimals: 4,
  ),
  BiomarkerSpec(
    key: 'hnr',
    name: 'HNR',
    shortDescription: 'Claridad de la voz',
    explanation:
        'Relación entre la parte "limpia" (armónica) de la voz y el ruido. '
        'Valores bajos indican una voz más ronca o con más aire.',
    icon: Icons.tune,
    threshold: 20,
    higherIsWorse: false,
    decimals: 1,
    unit: 'dB',
  ),
  BiomarkerSpec(
    key: 'ppe',
    name: 'PPE',
    shortDescription: 'Regularidad del tono',
    explanation:
        'Entropía del periodo del tono: qué tan impredecibles son las '
        'variaciones del tono al sostener la vocal.',
    icon: Icons.multiline_chart,
    threshold: 0.25,
    higherIsWorse: true,
    decimals: 3,
  ),
  BiomarkerSpec(
    key: 'rpde',
    name: 'RPDE',
    shortDescription: 'Periodicidad de la vibración',
    explanation:
        'Mide qué tan repetitiva y regular es la vibración de las cuerdas '
        'vocales a lo largo del tiempo.',
    icon: Icons.graphic_eq,
    threshold: 0.5,
    higherIsWorse: true,
    decimals: 3,
  ),
];

/// Resultado del modelo de predicción para una prueba de voz.
class VoicePrediction {
  /// Probabilidad de 0 a 100.
  final double probability;
  final String message;
  final String? serverColor;
  final Map<String, double> biomarkers;
  final List<String> alerts;
  final int samples;

  const VoicePrediction({
    required this.probability,
    required this.message,
    required this.serverColor,
    required this.biomarkers,
    required this.alerts,
    required this.samples,
  });

  RiskLevel get risk => RiskLevelX.resolve(serverColor, probability);

  int get alertCount => biomarkerSpecs
      .where((s) => biomarkers[s.key] != null && s.isAlert(biomarkers[s.key]!))
      .length;

  static double _num(dynamic v) => v is num ? v.toDouble() : 0.0;

  factory VoicePrediction.fromJson(Map<String, dynamic> json, {int samples = 3}) {
    return VoicePrediction(
      probability: _num(json['probabilidad_promedio']),
      message: (json['mensaje'] ?? 'Análisis completado').toString(),
      serverColor: json['color']?.toString(),
      biomarkers: {
        'jitter': _num(json['jitter_promedio']),
        'shimmer': _num(json['shimmer_promedio']),
        'hnr': _num(json['hnr_promedio']),
        'ppe': _num(json['ppe_promedio']),
        'rpde': _num(json['rpde_promedio']),
      },
      alerts: json['detalles_alertas_totales'] is List
          ? List<String>.from(
              (json['detalles_alertas_totales'] as List).map((e) => '$e'))
          : const [],
      samples: samples,
    );
  }

  /// Reconstruye la predicción desde el historial (incluye registros
  /// antiguos que usaban 'probabilidad_promedio').
  factory VoicePrediction.fromTestResult(TestResult r) {
    final m = r.metrics;
    double? read(String key) => m[key] is num ? (m[key] as num).toDouble() : null;
    final lines = (r.notes ?? '').split('\n');
    return VoicePrediction(
      probability: read('probabilidad') ??
          read('probabilidad_promedio') ??
          (100 - r.overallScore),
      message: lines.first,
      serverColor: m['color'] is String ? m['color'] as String : null,
      biomarkers: {
        for (final s in biomarkerSpecs)
          if (read(s.key) != null) s.key: read(s.key)!,
      },
      alerts: lines.skip(1).where((l) => l.trim().isNotEmpty).toList(),
      samples: (read('muestras') ?? read('total_muestras') ?? 3).round(),
    );
  }

  TestResult toTestResult(DateTime timestamp) {
    return TestResult(
      testType: 'voice',
      timestamp: timestamp,
      overallScore: 100 - probability,
      metrics: {
        'probabilidad': probability,
        ...biomarkers,
        'muestras': samples.toDouble(),
        if (serverColor != null) 'color': serverColor,
      },
      // Primera línea: mensaje; siguientes: alertas del servidor.
      notes: [message.replaceAll('\n', ' '), ...alerts].join('\n'),
    );
  }
}

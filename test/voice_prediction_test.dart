import 'package:flutter_test/flutter_test.dart';
import 'package:mi_segunda_app/models/test_result.dart';
import 'package:mi_segunda_app/models/voice_prediction.dart';

void main() {
  final serverJson = {
    'probabilidad_promedio': 62.5,
    'mensaje': 'Se detectaron variaciones',
    'color': 'rojo',
    'jitter_promedio': 0.0071,
    'shimmer_promedio': 0.021,
    'hnr_promedio': 18.4,
    'ppe_promedio': 0.19,
    'rpde_promedio': 0.55,
    'detalles_alertas_totales': ['Jitter elevado', 'HNR bajo'],
  };

  test('fromJson interpreta la respuesta del servidor', () {
    final p = VoicePrediction.fromJson(serverJson);
    expect(p.risk, RiskLevel.high);
    expect(p.biomarkers['hnr'], 18.4);
    // jitter > 0.006, hnr < 20, rpde > 0.5
    expect(p.alertCount, 3);
  });

  test('sobrevive el guardado y lectura en la base de datos', () {
    final original = VoicePrediction.fromJson(serverJson);
    final map = original.toTestResult(DateTime(2026, 9, 29, 8, 30)).toMap();
    final restored = VoicePrediction.fromTestResult(TestResult.fromMap(map));

    expect(restored.probability, original.probability);
    expect(restored.risk, original.risk);
    expect(restored.message, original.message);
    expect(restored.alerts, original.alerts);
    expect(restored.biomarkers, original.biomarkers);
  });

  test('lee registros antiguos guardados con el formato anterior', () {
    final legacy = TestResult(
      testType: 'voice',
      timestamp: DateTime(2026, 1, 1),
      overallScore: 80,
      metrics: {'probabilidad_promedio': 20.0, 'jitter': 0.004},
      notes: 'Voz estable',
    );
    final p = VoicePrediction.fromTestResult(
      TestResult.fromMap(legacy.toMap()),
    );
    expect(p.probability, 20.0);
    expect(p.risk, RiskLevel.low);
    expect(p.biomarkers.containsKey('ppe'), isFalse);
  });

  test('sin color del servidor se usa la probabilidad', () {
    expect(RiskLevelX.resolve(null, 55), RiskLevel.high);
    expect(RiskLevelX.resolve(null, 35), RiskLevel.moderate);
    expect(RiskLevelX.resolve(null, 10), RiskLevel.low);
  });
}

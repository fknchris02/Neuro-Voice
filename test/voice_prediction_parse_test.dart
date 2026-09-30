import 'package:flutter_test/flutter_test.dart';
import 'package:mi_segunda_app/models/voice_prediction.dart';

void main() {
  test('lee PPE, RPDE y DFA desde "otros" (respuesta actual del servidor)', () {
    final p = VoicePrediction.fromJson({
      'probabilidad_promedio': 42.0,
      'color': 'naranja',
      'jitter_promedio': 0.005,
      'shimmer_promedio': 0.02,
      'hnr_promedio': 21.0,
      'otros': {'hnr': 21.0, 'nhr': 0.01, 'ppe': 0.24381, 'rpde': 0.70352, 'dfa': 0.57056},
    });
    expect(p.biomarkers['ppe'], 0.24381);
    expect(p.biomarkers['rpde'], 0.70352);
    expect(p.biomarkers['dfa'], 0.57056);
    final dfa = biomarkerSpecs.firstWhere((s) => s.key == 'dfa');
    final rpde = biomarkerSpecs.firstWhere((s) => s.key == 'rpde');
    expect(dfa.isAlert(0.57056), isFalse); // "✓ OK" en el panel
    expect(rpde.isAlert(0.70352), isTrue); // "↑↑ CRIT" en el panel
  });

  test('sigue leyendo respuestas antiguas y omite lo que no viene', () {
    final p = VoicePrediction.fromJson({'ppe_promedio': 0.2, 'rpde_promedio': 0.4});
    expect(p.biomarkers['ppe'], 0.2);
    expect(p.biomarkers.containsKey('dfa'), isFalse);
  });
}

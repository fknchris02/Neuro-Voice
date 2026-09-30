import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mi_segunda_app/models/voice_prediction.dart';
import 'package:mi_segunda_app/screens/biomarker_report_screen.dart';
import 'package:mi_segunda_app/screens/dashboard_screen.dart';
import 'package:mi_segunda_app/theme/app_theme.dart';
import 'package:mi_segunda_app/widgets/home_widgets.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final prediction = VoicePrediction.fromJson({
    'probabilidad_promedio': 62.5,
    'mensaje': 'Se detectaron variaciones en la estabilidad vocal',
    'color': 'rojo',
    'jitter_promedio': 0.0071,
    'shimmer_promedio': 0.021,
    'hnr_promedio': 18.4,
    'ppe_promedio': 0.19,
    'rpde_promedio': 0.55,
    'detalles_alertas_totales': ['Jitter elevado'],
  });

  Future<void> pumpPhone(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: child));
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('reporte sin desbordes a 360 px', (tester) async {
    await pumpPhone(
      tester,
      BiomarkerReportScreen(
        prediction: prediction,
        timestamp: DateTime(2026, 9, 29, 8, 30),
        resultId: 42,
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('la barra de navegación no ocupa toda la pantalla', (tester) async {
    await pumpPhone(
      tester,
      Scaffold(
        extendBody: true,
        body: const SizedBox.expand(),
        bottomNavigationBar: FloatingNavBar(selectedIndex: 0, onSelected: (_) {}),
      ),
    );
    expect(tester.takeException(), isNull);
    final height = tester.getSize(find.byType(FloatingNavBar)).height;
    // Píldora de ~64 px + 16 px de margen inferior.
    expect(height, lessThan(100));
  });

  testWidgets('tarjetas de inicio sin desbordes a 360 px', (tester) async {
    await pumpPhone(
      tester,
      Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const GreetingHeader(userName: 'Alejandra Morgan Fernández'),
            StabilityBanner(prediction: prediction, timestamp: DateTime.now()),
            const StabilityBanner(prediction: null, timestamp: null),
            HeroTestCard(
              title: 'Prueba Fonatoria Sostenida (/a:/)',
              description: 'Evaluación acústica de estabilidad.',
              duration: '15 seg',
              onTap: () {},
            ),
            SecondaryTestCard(
              icon: Icons.graphic_eq,
              iconColor: Colors.red,
              title: 'Diadococinesia Oral',
              tag: '/pa-ta-ka/',
              description: 'Coordinación motora rápida y agilidad articulatoria',
              meta: const [
                TestMeta(Icons.timer_outlined, 'Duración: 30 seg'),
                TestMeta(Icons.show_chart, '2 Métricas clínicas'),
              ],
              comingSoon: true,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}

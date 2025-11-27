import 'package:flutter/material.dart';

import '../models/test_result.dart';
import 'database_helper.dart';

class StatsService {
  static final StatsService instance = StatsService._init();

  StatsService._init();

  // ========== ESTADO GENERAL ==========

  Future<Map<String, dynamic>> getGeneralStatus() async {
    try {
      final allResults = await DatabaseHelper.instance.getAllTestResults();

      if (allResults.isEmpty) {
        return {
          'status': 'Sin datos',
          'statusColor': 'grey',
          'score': 0.0,
          'lastTest': 'Nunca',
          'testsCount': 0,
        };
      }

      // Obtener últimos 7 días
      final now = DateTime.now();
      final lastWeek = now.subtract(const Duration(days: 7));
      final recentResults = allResults.where((r) =>
          r.timestamp.isAfter(lastWeek)
      ).toList();

      if (recentResults.isEmpty) {
        return {
          'status': 'Datos desactualizados',
          'statusColor': 'orange',
          'score': allResults.first.overallScore,
          'lastTest': allResults.first.getTimeAgo(),
          'testsCount': allResults.length,
        };
      }

      // Calcular promedio de últimos tests
      final avgScore = recentResults
          .map((r) => r.overallScore)
          .reduce((a, b) => a + b) / recentResults.length;

      String status;
      String statusColor;

      if (avgScore >= 75) {
        status = 'Bajo Riesgo';
        statusColor = 'green';
      } else if (avgScore >= 50) {
        status = 'Riesgo Moderado';
        statusColor = 'orange';
      } else {
        status = 'Requiere Atención';
        statusColor = 'red';
      }

      return {
        'status': status,
        'statusColor': statusColor,
        'score': avgScore,
        'lastTest': allResults.first.getTimeAgo(),
        'testsCount': allResults.length,
        'recentTests': recentResults.length,
      };
    } catch (e) {
      print('Error al obtener estado general: $e');
      return {
        'status': 'Error',
        'statusColor': 'grey',
        'score': 0.0,
        'lastTest': 'N/A',
        'testsCount': 0,
      };
    }
  }

  // ========== PROGRESO SEMANAL ==========

  Future<List<Map<String, dynamic>>> getWeeklyProgress() async {
    try {
      final now = DateTime.now();
      final List<Map<String, dynamic>> weekData = [];

      // Generar últimos 7 días
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dayName = _getDayName(date.weekday);

        // Obtener tests de ese día
        final dayResults = await _getResultsForDate(date);

        double avgScore = 0.0;
        if (dayResults.isNotEmpty) {
          avgScore = dayResults
              .map((r) => r.overallScore)
              .reduce((a, b) => a + b) / dayResults.length;
        }

        weekData.add({
          'day': dayName,
          'score': avgScore,
          'count': dayResults.length,
          'date': date,
        });
      }

      return weekData;
    } catch (e) {
      print('Error al obtener progreso semanal: $e');
      return [];
    }
  }

  Future<List<TestResult>> _getResultsForDate(DateTime date) async {
    final allResults = await DatabaseHelper.instance.getAllTestResults();

    return allResults.where((result) {
      return result.timestamp.year == date.year &&
          result.timestamp.month == date.month &&
          result.timestamp.day == date.day;
    }).toList();
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'Lun';
      case 2: return 'Mar';
      case 3: return 'Mié';
      case 4: return 'Jue';
      case 5: return 'Vie';
      case 6: return 'Sáb';
      case 7: return 'Dom';
      default: return '';
    }
  }

  // ========== MÉTRICAS RECIENTES ==========

  Future<List<Map<String, dynamic>>> getRecentMetrics() async {
    try {
      final results = await DatabaseHelper.instance.getRecentTestResults(10);

      if (results.isEmpty) {
        return [
          {
            'title': 'Temblor',
            'value': '--',
            'unit': 'Hz',
            'trend': 'stable',
            'percentage': '0%',
          },
          {
            'title': 'Rigidez',
            'value': '--',
            'unit': '',
            'trend': 'stable',
            'percentage': '0%',
          },
          {
            'title': 'Coordinación',
            'value': '--',
            'unit': 'pts',
            'trend': 'stable',
            'percentage': '0%',
          },
        ];
      }

      // Calcular métricas promedio
      double avgTremor = 0.0;
      double avgCoordination = 0.0;
      int tremorCount = 0;
      int coordinationCount = 0;

      for (var result in results) {
        if (result.testType == 'spiral' && result.metrics.containsKey('tremor')) {
          avgTremor += result.metrics['tremor'];
          tremorCount++;
        }
        if (result.testType == 'tapping' && result.metrics.containsKey('coordination')) {
          avgCoordination += result.metrics['coordination'];
          coordinationCount++;
        }
      }

      if (tremorCount > 0) avgTremor /= tremorCount;
      if (coordinationCount > 0) avgCoordination /= coordinationCount;

      // Calcular tendencias
      final trend1 = _calculateTrend(results, 'spiral', 'tremor');
      final trend2 = _calculateTrend(results, 'tapping', 'coordination');

      return [
        {
          'title': 'Temblor',
          'value': tremorCount > 0 ? avgTremor.toStringAsFixed(1) : '--',
          'unit': 'Hz',
          'trend': trend1['direction'],
          'percentage': trend1['percentage'],
        },
        {
          'title': 'Rigidez',
          'value': 'Leve',
          'unit': '',
          'trend': 'stable',
          'percentage': '0%',
        },
        {
          'title': 'Coordinación',
          'value': coordinationCount > 0 ? avgCoordination.toStringAsFixed(0) : '--',
          'unit': 'pts',
          'trend': trend2['direction'],
          'percentage': trend2['percentage'],
        },
      ];
    } catch (e) {
      print('Error al obtener métricas: $e');
      return [];
    }
  }

  Map<String, String> _calculateTrend(List<TestResult> results, String testType, String metricKey) {
    final filtered = results.where((r) =>
    r.testType == testType && r.metrics.containsKey(metricKey)
    ).toList();

    if (filtered.length < 2) {
      return {'direction': 'stable', 'percentage': '0%'};
    }

    final recent = filtered[0].metrics[metricKey];
    final older = filtered[1].metrics[metricKey];

    if (recent == older) {
      return {'direction': 'stable', 'percentage': '0%'};
    }

    final change = ((recent - older) / older * 100).abs();
    final direction = recent < older ? 'down' : 'up';

    return {
      'direction': direction,
      'percentage': '${change.toStringAsFixed(0)}%',
    };
  }

  // ========== NOTIFICACIONES ==========

  Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final List<Map<String, dynamic>> notifications = [];
      final now = DateTime.now();

      // Obtener resultados recientes
      final results = await DatabaseHelper.instance.getAllTestResults();

      if (results.isEmpty) {
        notifications.add({
          'type': 'info',
          'title': 'Comienza tu evaluación',
          'message': 'Realiza tu primer test para comenzar el seguimiento',
          'timestamp': now,
          'icon': Icons.info_outline,
        });
        return notifications;
      }

      final lastResult = results.first;
      final daysSinceLastTest = now.difference(lastResult.timestamp).inDays;

      // Notificación: tiempo sin realizar test
      if (daysSinceLastTest >= 7) {
        notifications.add({
          'type': 'warning',
          'title': 'Test pendiente',
          'message': 'Hace $daysSinceLastTest días que no realizas un test',
          'timestamp': now,
          'icon': Icons.schedule,
        });
      }

      // Notificación: puntuaciones bajas
      final lowScores = results.where((r) => r.overallScore < 50).take(3).toList();
      if (lowScores.isNotEmpty) {
        notifications.add({
          'type': 'alert',
          'title': 'Puntuaciones bajas detectadas',
          'message': 'Se han detectado ${lowScores.length} resultados con puntuación baja',
          'timestamp': lowScores.first.timestamp,
          'icon': Icons.warning_amber,
        });
      }

      // Notificación: mejora detectada
      if (results.length >= 2) {
        final improvement = results[0].overallScore - results[1].overallScore;
        if (improvement > 10) {
          notifications.add({
            'type': 'success',
            'title': '¡Mejora detectada!',
            'message': 'Tu última puntuación mejoró en ${improvement.toStringAsFixed(0)} puntos',
            'timestamp': results[0].timestamp,
            'icon': Icons.trending_up,
          });
        }
      }

      // Notificación: recordatorio semanal
      if (daysSinceLastTest >= 3 && daysSinceLastTest < 7) {
        notifications.add({
          'type': 'info',
          'title': 'Recordatorio semanal',
          'message': 'Es recomendable realizar un test cada 3-5 días',
          'timestamp': now,
          'icon': Icons.notifications_active,
        });
      }

      // Ordenar por timestamp
      notifications.sort((a, b) =>
          (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime)
      );

      return notifications;
    } catch (e) {
      print('Error al obtener notificaciones: $e');
      return [];
    }
  }

  // ========== ESTADÍSTICAS DETALLADAS ==========

  Future<Map<String, dynamic>> getDetailedStats() async {
    try {
      final allResults = await DatabaseHelper.instance.getAllTestResults();

      if (allResults.isEmpty) {
        return {
          'totalTests': 0,
          'averageScore': 0.0,
          'bestScore': 0.0,
          'worstScore': 0.0,
          'testsByType': {},
        };
      }

      final scores = allResults.map((r) => r.overallScore).toList();
      final avgScore = scores.reduce((a, b) => a + b) / scores.length;
      final bestScore = scores.reduce((a, b) => a > b ? a : b);
      final worstScore = scores.reduce((a, b) => a < b ? a : b);

      // Contar por tipo
      final Map<String, int> testsByType = {};
      for (var result in allResults) {
        testsByType[result.testType] = (testsByType[result.testType] ?? 0) + 1;
      }

      return {
        'totalTests': allResults.length,
        'averageScore': avgScore,
        'bestScore': bestScore,
        'worstScore': worstScore,
        'testsByType': testsByType,
        'lastTestDate': allResults.first.timestamp,
      };
    } catch (e) {
      print('Error al obtener estadísticas detalladas: $e');
      return {};
    }
  }

  // ========== LIMPIEZA DE DATOS ANTIGUOS ==========

  Future<int> cleanOldData({int daysToKeep = 90}) async {
    try {
      final allResults = await DatabaseHelper.instance.getAllTestResults();
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));

      int deletedCount = 0;
      for (var result in allResults) {
        if (result.timestamp.isBefore(cutoffDate)) {
          await DatabaseHelper.instance.deleteTestResult(result.id!);
          deletedCount++;
        }
      }

      return deletedCount;
    } catch (e) {
      print('Error al limpiar datos antiguos: $e');
      return 0;
    }
  }
}
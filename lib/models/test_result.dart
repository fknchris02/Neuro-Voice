class TestResult {
  final int? id;
  final String testType; // 'spiral', 'voice', 'gait', 'tapping'
  final DateTime timestamp;
  final double overallScore;
  final Map<String, dynamic> metrics;
  final String? notes;

  TestResult({
    this.id,
    required this.testType,
    required this.timestamp,
    required this.overallScore,
    required this.metrics,
    this.notes,
  });

  // Convertir a Map para guardar en DB
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'testType': testType,
      'timestamp': timestamp.toIso8601String(),
      'overallScore': overallScore,
      'metrics': _encodeMetrics(metrics),
      'notes': notes,
    };
  }

  // Crear desde Map de DB
  factory TestResult.fromMap(Map<String, dynamic> map) {
    return TestResult(
      id: map['id'],
      testType: map['testType'],
      timestamp: DateTime.parse(map['timestamp']),
      overallScore: map['overallScore'],
      metrics: _decodeMetrics(map['metrics']),
      notes: map['notes'],
    );
  }

  // Codificar métricas a String JSON
  static String _encodeMetrics(Map<String, dynamic> metrics) {
    return metrics.entries
        .map((e) => '${e.key}:${e.value}')
        .join(',');
  }

  // Decodificar métricas desde String
  static Map<String, dynamic> _decodeMetrics(String metricsString) {
    final Map<String, dynamic> result = {};
    final pairs = metricsString.split(',');

    for (var pair in pairs) {
      final parts = pair.split(':');
      if (parts.length == 2) {
        final key = parts[0];
        final value = double.tryParse(parts[1]) ?? parts[1];
        result[key] = value;
      }
    }

    return result;
  }

  // Obtener color según puntuación
  String getScoreCategory() {
    if (overallScore >= 75) return 'excelente';
    if (overallScore >= 50) return 'moderado';
    return 'atencion';
  }

  // Obtener tiempo transcurrido
  String getTimeAgo() {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return 'Hace ${years} ${years == 1 ? 'año' : 'años'}';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return 'Hace ${months} ${months == 1 ? 'mes' : 'meses'}';
    } else if (difference.inDays > 0) {
      return 'Hace ${difference.inDays} ${difference.inDays == 1 ? 'día' : 'días'}';
    } else if (difference.inHours > 0) {
      return 'Hace ${difference.inHours} ${difference.inHours == 1 ? 'hora' : 'horas'}';
    } else if (difference.inMinutes > 0) {
      return 'Hace ${difference.inMinutes} ${difference.inMinutes == 1 ? 'minuto' : 'minutos'}';
    } else {
      return 'Ahora';
    }
  }

  // Nombre legible del test
  String getTestName() {
    switch (testType) {
      case 'spiral':
        return 'Test de Espiral';
      case 'voice':
        return 'Test de Voz';
      case 'gait':
        return 'Test de Marcha';
      case 'tapping':
        return 'Test de Tapping';
      default:
        return 'Test Desconocido';
    }
  }

  @override
  String toString() {
    return 'TestResult{id: $id, testType: $testType, score: $overallScore, date: $timestamp}';
  }
}
/// Configuración única del servidor de análisis.
///
/// La IP se puede cambiar sin tocar el código:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.50:5001
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.20.148:5001',
  );

  static Uri get predict => Uri.parse('$baseUrl/predict_parkinson');
  static Uri get exportPdf => Uri.parse('$baseUrl/api/exportar_pdf');

  static const Duration healthTimeout = Duration(seconds: 4);
  static const Duration predictTimeout = Duration(seconds: 300);
}

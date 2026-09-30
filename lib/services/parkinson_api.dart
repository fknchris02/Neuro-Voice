import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/voice_prediction.dart';

/// Error con un mensaje apto para mostrar al usuario.
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

class ParkinsonApi {
  ParkinsonApi._();

  /// Comprueba si el servidor responde. Cualquier respuesta HTTP
  /// (incluso 404) significa que está encendido y alcanzable.
  static Future<bool> isReachable() async {
    try {
      await http
          .get(Uri.parse(ApiConfig.baseUrl))
          .timeout(ApiConfig.healthTimeout);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<VoicePrediction> predict(List<String> filePaths) async {
    try {
      final request = http.MultipartRequest('POST', ApiConfig.predict);
      for (var i = 0; i < filePaths.length; i++) {
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          filePaths[i],
          filename: 'voice_test_${i + 1}.wav',
        ));
      }

      final streamed = await request.send().timeout(ApiConfig.predictTimeout);
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode != 200) {
        throw ApiException(
          'El servidor no pudo procesar las muestras '
          '(código ${response.statusCode}). Intenta grabarlas de nuevo.',
        );
      }

      final data = json.decode(response.body);
      if (data is! Map<String, dynamic>) {
        throw const ApiException('El servidor devolvió una respuesta inesperada.');
      }
      if (data['error'] != null) {
        throw ApiException(data['error'].toString());
      }
      return VoicePrediction.fromJson(data, samples: filePaths.length);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
        'El análisis tardó demasiado. Verifica que el servidor esté activo '
        'e inténtalo de nuevo.',
      );
    } on SocketException {
      throw const ApiException(_unreachableMessage);
    } on http.ClientException {
      throw const ApiException(_unreachableMessage);
    } on FormatException {
      throw const ApiException('El servidor devolvió una respuesta inválida.');
    }
  }

  static const _unreachableMessage =
      'No se pudo conectar con el servidor de análisis. Verifica que tu '
      'teléfono esté en la misma red Wi-Fi que el servidor.';
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/user_profile.dart';
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

  /// Busca en el servidor al paciente dueño de [folio] ("CM26-9HTK57").
  static Future<UserProfile> linkPatient(String folio) async {
    try {
      final response = await http
          .get(ApiConfig.linkPatient(folio))
          .timeout(ApiConfig.linkTimeout);

      if (response.statusCode == 404) {
        throw const ApiException('Ese folio no existe. Revísalo con tu médico.');
      }
      if (response.statusCode != 200) {
        throw ApiException(
          'El servidor no pudo validar el folio (código ${response.statusCode}).',
        );
      }

      // utf8.decode: sin esto los nombres con acentos salen mal
      final data = json.decode(utf8.decode(response.bodyBytes));
      if (data is! Map<String, dynamic>) {
        throw const ApiException('El servidor devolvió una respuesta inesperada.');
      }
      return UserProfile.fromServer({'folio': folio, ...data});
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(_unreachableMessage);
    } on SocketException {
      throw const ApiException(_unreachableMessage);
    } on http.ClientException {
      throw const ApiException(_unreachableMessage);
    } on FormatException {
      throw const ApiException('El servidor devolvió una respuesta inválida.');
    }
  }

  /// El servidor liga el análisis al paciente por su folio ('paciente_id');
  /// sin él responde 400.
  static Future<VoicePrediction> predict(
    List<String> filePaths, {
    required UserProfile patient,
  }) async {
    try {
      final request = http.MultipartRequest('POST', ApiConfig.predict)
        ..fields['paciente_id'] = patient.folio ?? ''
        ..fields['sexo'] = patient.sexLabel;
      if (patient.age > 0) request.fields['edad'] = '${patient.age}';
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
          _serverError(response) ??
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

  /// Mensaje del campo "error" que el servidor manda en el JSON, si lo hay.
  static String? _serverError(http.Response response) {
    try {
      final data = json.decode(utf8.decode(response.bodyBytes));
      if (data is Map && data['error'] != null) return data['error'].toString();
    } on FormatException {
      // Cuerpo vacío o no JSON: se usa el mensaje genérico.
    }
    return null;
  }

  static const _unreachableMessage =
      'No se pudo conectar con el servidor de análisis. Verifica que tu '
      'teléfono esté en la misma red Wi-Fi que el servidor.';
}

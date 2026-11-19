import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

// ============================================================
// CLIENTE HTTP
// Único lugar que habla con la API: agrega el token, convierte JSON
// y transforma los errores del servidor en ApiException con un
// mensaje en español listo para mostrar al usuario.
// ============================================================

class ApiException implements Exception {
  final int status; // 0 = no hubo respuesta (sin conexión / tiempo agotado)
  final String code; // ej. 'email_not_verified', 'no_spots'
  final String message;

  const ApiException(this.status, this.code, this.message);

  @override
  String toString() => message;
}

class ApiClient {
  final http.Client _http;
  final String baseUrl;

  /// Token de sesión (JWT). Lo asigna AppServices al iniciar sesión.
  String? token;

  ApiClient({http.Client? client, String? baseUrl})
      : _http = client ?? http.Client(),
        baseUrl = baseUrl ?? ApiConfig.baseUrl;

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, {Object? body}) =>
      _send('POST', path, body: body);

  Future<dynamic> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(String method, String path,
      {Map<String, String>? query, Object? body}) async {
    var uri = Uri.parse('$baseUrl$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query);
    }
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);

    http.Response response;
    try {
      final streamed = await _http.send(request).timeout(ApiConfig.timeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const ApiException(
          0, 'timeout', 'El servidor tardó demasiado en responder. Intenta de nuevo.');
    } on http.ClientException {
      throw const ApiException(
          0, 'network', 'No se pudo conectar con el servidor. Revisa tu conexión.');
    }

    final text = utf8.decode(response.bodyBytes);
    dynamic data;
    if (text.isNotEmpty) {
      try {
        data = jsonDecode(text);
      } on FormatException {
        data = null;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) return data;

    var code = 'error';
    var message = 'Ocurrió un error (${response.statusCode}).';
    if (data is Map<String, dynamic>) {
      if (data['message'] is String) message = data['message'] as String;
      if (data['code'] is String) code = data['code'] as String;
    }
    throw ApiException(response.statusCode, code, message);
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../auth/auth_service.dart';

const defaultApiBaseUrl = String.fromEnvironment('API_BASE_URL',
    defaultValue: 'https://lapticon-backend.onrender.com');

/// Cliente HTTP compartido por los repositorios de la API de Lapticon.
///
/// Agrega `Authorization: Bearer <idToken>` a las rutas protegidas, renueva el
/// token una sola vez ante un 401, no sigue redirecciones y traduce los
/// errores a [AppFailure] con códigos estables.
class ApiClient {
  ApiClient(this.auth,
      {http.Client? client,
      String baseUrl = defaultApiBaseUrl,
      this.timeout = const Duration(seconds: 20)})
      : _client = client ?? http.Client(),
        _base = Uri.parse(baseUrl.replaceAll(RegExp(r'/+$'), '')) {
    if (_base.scheme != 'https' ||
        _base.host.isEmpty ||
        _base.hasQuery ||
        _base.hasFragment ||
        _base.userInfo.isNotEmpty ||
        (_base.path.isNotEmpty && _base.path != '/')) {
      throw const AppFailure(
          'API_BASE_URL debe ser una dirección HTTPS sin rutas, credenciales ni parámetros.',
          code: 'configuration');
    }
  }
  final AuthService auth;
  final http.Client _client;
  final Uri _base;
  final Duration timeout;

  Uri _uri(String path, Map<String, String>? query) {
    final uri = _base.resolve(path);
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  /// Envía la petición. Con [allowNotFound] un 404 se devuelve para que el
  /// repositorio lo interprete; sin él es un error. Las rutas públicas se
  /// llaman con [authenticated] en `false` y no envían el token.
  Future<http.Response> send(String method, String path,
      {Map<String, Object?>? body,
      Map<String, String>? query,
      bool authenticated = true,
      bool allowNotFound = false,
      String forbiddenMessage =
          'No tienes permiso para realizar esta acción.'}) async {
    try {
      for (var attempt = 0; attempt < 2; attempt++) {
        final headers = <String, String>{
          'Accept': 'application/json',
          if (body != null) 'Content-Type': 'application/json; charset=utf-8'
        };
        if (authenticated) {
          final token = await auth.idToken(forceRefresh: attempt == 1);
          headers['Authorization'] = 'Bearer $token';
        }
        // Sin redirecciones: no reenviar el token a un destino diferente.
        final request = http.Request(method, _uri(path, query))
          ..headers.addAll(headers)
          ..followRedirects = false;
        if (body != null) request.body = jsonEncode(body);
        final response = await (() async =>
                http.Response.fromStream(await _client.send(request)))()
            .timeout(timeout);
        if (response.statusCode == 401 && authenticated && attempt == 0) {
          continue;
        }
        if (response.statusCode == 401) {
          throw const AppFailure(
              'Tu sesión no fue aceptada. Inicia sesión de nuevo. Si continúa, comprueba que la API y Firebase usan el mismo proyecto.',
              code: 'session-expired');
        }
        if (response.statusCode == 403) {
          throw AppFailure(forbiddenMessage, code: 'forbidden');
        }
        if (response.statusCode == 404 && allowNotFound) return response;
        if (response.statusCode == 429) {
          throw const AppFailure(
              'La API recibió demasiadas solicitudes. Inténtalo más tarde.',
              code: 'rate-limit');
        }
        if (response.statusCode >= 500) {
          throw const AppFailure(
              'La API no está disponible. Puedes reintentar en unos segundos.',
              code: 'server');
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw AppFailure(
              _serverMessage(response) ??
                  'La API no pudo completar la solicitud. Revisa los datos e inténtalo de nuevo.',
              code: 'api');
        }
        return response;
      }
      throw StateError('Unreachable');
    } on AppFailure catch (e) {
      if (e.code == 'session-expired') await auth.signOut();
      rethrow;
    } on TimeoutException {
      throw const AppFailure(
          'La API tardó demasiado en responder. Inténtalo de nuevo.',
          code: 'timeout');
    } on http.ClientException {
      throw const AppFailure(
          'No se pudo conectar con la API. Revisa Internet e inténtalo de nuevo.',
          code: 'network');
    }
  }

  /// Mensaje `{ "error": "..." }` de la API para errores 4xx, si es legible.
  String? _serverMessage(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map && decoded['error'] is String) {
        final text = (decoded['error'] as String).trim();
        if (text.isNotEmpty && text.length <= 200) return text;
      }
    } catch (_) {}
    return null;
  }

  /// Decodifica JSON; cualquier fallo es una respuesta inválida.
  Object? decode(http.Response response, String failureMessage) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw AppFailure(failureMessage, code: 'invalid-response');
    }
  }

  void close() => _client.close();
}

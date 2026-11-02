import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../auth/auth_service.dart';

class UserProfile {
  const UserProfile(
      {required this.uid,
      required this.email,
      required this.name,
      required this.surname});
  final String uid;
  final String email;
  final String name;
  final String surname;
  String get fullName => '$name $surname'.trim();

  factory UserProfile.fromJson(Map<String, dynamic> json, AuthUser user) {
    String field(String key) => json[key] is String ? json[key] as String : '';
    final uid = field('uid');
    if (uid.isNotEmpty && uid != user.uid) {
      throw const AppFailure(
          'La API devolvió un perfil que no corresponde a tu sesión.',
          code: 'invalid-response');
    }
    return UserProfile(
        uid: user.uid,
        email: user.email,
        name: field('nombre'),
        surname: field('apellido'));
  }
}

abstract class UserRepository {
  Future<UserProfile?> fetch(AuthUser user);
  Future<UserProfile> create(AuthUser user, String name, String surname);
  void close() {}
}

class ApiUserRepository implements UserRepository {
  ApiUserRepository(this.auth,
      {http.Client? client,
      String baseUrl = const String.fromEnvironment('API_BASE_URL',
          defaultValue: 'https://lapticon-backend.onrender.com'),
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

  Future<http.Response> _request(String method, String path,
      {Map<String, String>? body}) async {
    try {
      for (var attempt = 0; attempt < 2; attempt++) {
        final token = await auth.idToken(forceRefresh: attempt == 1);
        final headers = {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          if (body != null) 'Content-Type': 'application/json; charset=utf-8'
        };
        // Sin redirecciones: no reenviar el token a un destino diferente.
        final request = http.Request(method, _base.resolve(path))
          ..headers.addAll(headers)
          ..followRedirects = false;
        if (body != null) request.body = jsonEncode(body);
        final response = await (() async =>
                http.Response.fromStream(await _client.send(request)))()
            .timeout(timeout);
        if (response.statusCode == 401 && attempt == 0) continue;
        if (response.statusCode == 401) {
          throw const AppFailure(
              'Tu sesión no fue aceptada. Inicia sesión de nuevo. Si continúa, comprueba que la API y Firebase usan el mismo proyecto.',
              code: 'session-expired');
        }
        if (response.statusCode == 403) {
          throw const AppFailure(
              'No tienes permiso para consultar este perfil.',
              code: 'forbidden');
        }
        if (response.statusCode == 404 && method == 'GET') return response;
        if (response.statusCode == 429) {
          throw const AppFailure(
              'La API recibió demasiadas solicitudes. Inténtalo más tarde.',
              code: 'rate-limit');
        }
        if (response.statusCode >= 500) {
          throw const AppFailure(
              'La API no está disponible. Puedes reintentar sin crear otra cuenta.',
              code: 'server');
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw const AppFailure(
              'La API no pudo completar la solicitud. Revisa su configuración e inténtalo de nuevo.',
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

  UserProfile _profile(http.Response response, AuthUser user) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic> ||
          decoded['user'] is! Map<String, dynamic>) {
        throw const FormatException();
      }
      return UserProfile.fromJson(
          decoded['user'] as Map<String, dynamic>, user);
    } on FormatException {
      throw const AppFailure(
          'La respuesta del perfil no tiene el formato esperado.',
          code: 'invalid-response');
    }
  }

  @override
  Future<UserProfile?> fetch(AuthUser user) async {
    final response =
        await _request('GET', '/api/users/${Uri.encodeComponent(user.uid)}');
    return response.statusCode == 404 ? null : _profile(response, user);
  }

  @override
  Future<UserProfile> create(AuthUser user, String name, String surname) async {
    final response = await _request('POST', '/api/users/register', body: {
      'nombre': name.trim(),
      'apellido': surname.trim(),
      'correo': user.email,
    });
    return _profile(response, user);
  }

  @override
  void close() => _client.close();
}

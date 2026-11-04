import 'package:http/http.dart' as http;
import '../auth/auth_service.dart';
import '../roles/user_role.dart';
import 'api_client.dart';

class UserProfile {
  const UserProfile(
      {required this.uid,
      required this.email,
      required this.name,
      required this.surname,
      this.role});
  final String uid;
  final String email;
  final String name;
  final String surname;

  /// Rol guardado en el servidor (`rol`), si el backend lo conserva.
  final UserRole? role;
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
        surname: field('apellido'),
        role: UserRole.parse(json['rol']));
  }
}

abstract class UserRepository {
  Future<UserProfile?> fetch(AuthUser user);
  Future<UserProfile> create(AuthUser user, String name, String surname);

  /// Guarda el rol en el perfil del backend y devuelve el rol que el servidor
  /// confirmó, o `null` si la respuesta no lo incluye (el backend aún no
  /// tiene ese campo en su modelo).
  Future<UserRole?> saveRole(
      AuthUser user, UserProfile profile, UserRole role);
  void close() {}
}

class ApiUserRepository implements UserRepository {
  ApiUserRepository(this.auth,
      {http.Client? client,
      String baseUrl = defaultApiBaseUrl,
      Duration timeout = const Duration(seconds: 20)})
      : _api = ApiClient(auth,
            client: client, baseUrl: baseUrl, timeout: timeout);
  final AuthService auth;
  final ApiClient _api;
  static const _forbidden = 'No tienes permiso para consultar este perfil.';
  static const _invalid =
      'La respuesta del perfil no tiene el formato esperado.';

  Map<String, dynamic> _userJson(http.Response response,
      {bool allowBare = false}) {
    final decoded = _api.decode(response, _invalid);
    if (decoded is Map<String, dynamic>) {
      final user = decoded['user'];
      if (user is Map<String, dynamic>) return user;
      // PUT /api/users/{uid} devuelve el Usuario sin envolver.
      if (allowBare) return decoded;
    }
    throw const AppFailure(_invalid, code: 'invalid-response');
  }

  @override
  Future<UserProfile?> fetch(AuthUser user) async {
    final response = await _api.send(
        'GET', '/api/users/${Uri.encodeComponent(user.uid)}',
        allowNotFound: true, forbiddenMessage: _forbidden);
    if (response.statusCode == 404) return null;
    return UserProfile.fromJson(_userJson(response), user);
  }

  @override
  Future<UserProfile> create(AuthUser user, String name, String surname) async {
    final response = await _api.send('POST', '/api/users/register',
        body: {
          'nombre': name.trim(),
          'apellido': surname.trim(),
          'correo': user.email,
        },
        forbiddenMessage: _forbidden);
    return UserProfile.fromJson(_userJson(response), user);
  }

  @override
  Future<UserRole?> saveRole(
      AuthUser user, UserProfile profile, UserRole role) async {
    // Se reenvían nombre y apellido actuales para no vaciarlos; uid y correo
    // no se envían porque el backend rechaza modificarlos.
    final response = await _api.send(
        'PUT', '/api/users/${Uri.encodeComponent(user.uid)}',
        body: {
          'nombre': profile.name,
          'apellido': profile.surname,
          'rol': role.apiValue,
        },
        forbiddenMessage: 'No tienes permiso para modificar este perfil.');
    return UserProfile.fromJson(_userJson(response, allowBare: true), user)
        .role;
  }

  @override
  void close() => _api.close();
}

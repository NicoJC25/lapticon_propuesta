import 'package:shared_preferences/shared_preferences.dart';
import 'user_role.dart';

/// Caché local del rol. Se guarda por uid para que dos cuentas en el mismo
/// teléfono no compartan rol. La fuente principal es el perfil del backend.
abstract class RoleStore {
  Future<UserRole?> read(String uid);
  Future<void> write(String uid, UserRole role);
  Future<void> clear(String uid);
}

class SharedPreferencesRoleStore implements RoleStore {
  SharedPreferencesRoleStore({Future<SharedPreferences> Function()? open})
      : _open = open ?? SharedPreferences.getInstance;
  final Future<SharedPreferences> Function() _open;
  Future<SharedPreferences>? _cached;
  // Se abre al primer uso para no dejar un error de plataforma sin atender.
  Future<SharedPreferences> get _preferences => _cached ??= _open();
  static String keyFor(String uid) => 'lapticon.rol.$uid';

  @override
  Future<UserRole?> read(String uid) async =>
      UserRole.parse((await _preferences).getString(keyFor(uid)));

  @override
  Future<void> write(String uid, UserRole role) async {
    await (await _preferences).setString(keyFor(uid), role.apiValue);
  }

  @override
  Future<void> clear(String uid) async {
    await (await _preferences).remove(keyFor(uid));
  }
}

/// Caché en memoria: se usa cuando no se inyecta otra (pruebas, vistas).
class MemoryRoleStore implements RoleStore {
  final roles = <String, UserRole>{};
  @override
  Future<UserRole?> read(String uid) async => roles[uid];
  @override
  Future<void> write(String uid, UserRole role) async {
    roles[uid] = role;
  }

  @override
  Future<void> clear(String uid) async {
    roles.remove(uid);
  }
}

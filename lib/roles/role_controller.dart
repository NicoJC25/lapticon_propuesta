import 'dart:async';
import 'package:flutter/material.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_service.dart';
import 'role_store.dart';
import 'user_role.dart';

/// Decide el rol de la sesión actual.
///
/// Orden de lectura: primero el rol del perfil en el backend (sirve en
/// cualquier teléfono); si el servidor no lo tiene, la caché local por uid.
/// Al elegir, se guarda en la caché y se intenta guardar en el servidor.
class RoleController extends ChangeNotifier {
  RoleController(this.auth, this.store) {
    auth.addListener(_sync);
    _sync();
  }
  final AuthController auth;
  final RoleStore store;

  UserRole? role;
  bool loading = false;
  bool saving = false;

  /// Aviso no bloqueante sobre la sincronización con el servidor.
  String? notice;
  String? _uid;
  int _generation = 0;
  bool _disposed = false;

  bool get needsChoice => _uid != null && !loading && role == null;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _sync() {
    final uid = auth.phase == SessionPhase.ready ? auth.user?.uid : null;
    if (uid == _uid) return;
    _uid = uid;
    _generation++;
    role = null;
    notice = null;
    saving = false;
    if (uid == null) {
      loading = false;
      _notify();
      return;
    }
    unawaited(_resolve(uid, _generation));
  }

  Future<void> _resolve(String uid, int generation) async {
    loading = true;
    _notify();
    var found = auth.profile?.role;
    try {
      if (found != null) {
        await store.write(uid, found);
      } else {
        found = await store.read(uid);
      }
    } catch (_) {
      // Sin caché disponible: el usuario vuelve a elegir su rol.
    }
    if (_disposed || generation != _generation) return;
    role = found;
    loading = false;
    _notify();
  }

  Future<void> choose(UserRole next) async {
    final user = auth.user, profile = auth.profile;
    if (_disposed || user == null || profile == null || saving || loading) {
      return;
    }
    final generation = _generation;
    saving = true;
    notice = null;
    _notify();
    String? message;
    try {
      await store.write(user.uid, next);
    } catch (_) {}
    try {
      final confirmed = await auth.users.saveRole(user, profile, next);
      if (confirmed != next) {
        message =
            'Tu rol quedó guardado en este teléfono. El servidor todavía no lo conserva en tu perfil.';
      }
    } on AppFailure catch (e) {
      message =
          'Tu rol quedó guardado en este teléfono, pero no se pudo sincronizar con el servidor. ${e.message}';
    } catch (_) {
      message =
          'Tu rol quedó guardado en este teléfono, pero no se pudo sincronizar con el servidor.';
    }
    if (_disposed || generation != _generation) return;
    saving = false;
    role = next;
    notice = message;
    _notify();
  }

  /// Vuelve a la selección de rol.
  Future<void> change() async {
    final uid = _uid;
    if (_disposed || uid == null || saving) return;
    role = null;
    notice = null;
    _notify();
    try {
      await store.clear(uid);
    } catch (_) {}
  }

  void dismissNotice() {
    notice = null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    auth.removeListener(_sync);
    super.dispose();
  }
}

class RoleScope extends InheritedNotifier<RoleController> {
  const RoleScope(
      {super.key, required RoleController controller, required super.child})
      : super(notifier: controller);
  static RoleController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RoleScope>()!.notifier!;
}

import 'dart:async';
import 'package:flutter/material.dart';
import '../data/user_repository.dart';
import 'auth_service.dart';

enum SessionPhase {
  starting,
  signedOut,
  loadingProfile,
  needsProfile,
  ready,
  profileError
}

class AuthController extends ChangeNotifier {
  AuthController(this.auth, this.users) {
    _subscription = auth.authChanges.listen(_authChanged, onError: (_) {
      _generation++;
      user = null;
      profile = null;
      _draft = null;
      error = 'No se pudo comprobar la sesión. Reinicia la aplicación.';
      phase = SessionPhase.signedOut;
      _notify();
    });
  }
  final AuthService auth;
  final UserRepository users;
  late final StreamSubscription<AuthUser?> _subscription;
  AuthUser? user;
  UserProfile? profile;
  SessionPhase phase = SessionPhase.starting;
  String? error;
  bool busy = false;
  bool _authCommand = false;
  bool _disposed = false;
  int _generation = 0;
  (String, String)? _draft;
  bool get available => auth.configured;
  bool get canSubmit => available && !busy && phase != SessionPhase.starting;
  bool get signedIn => user != null;
  String? get configurationMessage => auth.configurationMessage;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void clearError() {
    error = null;
    _notify();
  }

  void _authChanged(AuthUser? next) {
    if (_disposed) return;
    if (next == null) {
      _generation++;
      user = null;
      profile = null;
      _draft = null;
      phase = SessionPhase.signedOut;
      _notify();
    } else if (!_authCommand && next.uid != user?.uid) {
      user = next;
      unawaited(_loadProfile());
    }
  }

  Future<bool> _action(Future<void> Function() work,
      {bool authCommand = false}) async {
    if (_disposed || !canSubmit) return false;
    busy = true;
    error = null;
    _authCommand = authCommand;
    _notify();
    try {
      await work();
      return true;
    } on AppFailure catch (e) {
      error = e.message;
      return false;
    } catch (_) {
      error = 'No se pudo completar la operación. Inténtalo de nuevo.';
      return false;
    } finally {
      busy = false;
      _authCommand = false;
      _notify();
    }
  }

  Future<bool> signIn(String email, String password) => _action(() async {
        _draft = null;
        user = await auth.signIn(email.trim(), password);
        await _loadProfile();
      }, authCommand: true);

  Future<bool> register(
          String email, String password, String name, String surname) =>
      _action(() async {
        final next = await auth.register(email.trim(), password);
        _draft = (name.trim(), surname.trim());
        user = next;
        await _loadProfile();
      }, authCommand: true);

  Future<bool> google() => _action(() async {
        final next = await auth.signInWithGoogle();
        if (next == null) return;
        _draft = null;
        user = next;
        await _loadProfile();
      }, authCommand: true);

  Future<bool> recover(String email) =>
      _action(() => auth.sendPasswordReset(email.trim()));

  Future<void> _loadProfile() async {
    final current = user;
    if (_disposed || current == null) return;
    final generation = ++_generation;
    phase = SessionPhase.loadingProfile;
    error = null;
    _notify();
    bool active() =>
        !_disposed && generation == _generation && user?.uid == current.uid;
    try {
      var loaded = await users.fetch(current);
      if (!active()) return;
      if (loaded == null && _draft != null) {
        loaded = await users.create(current, _draft!.$1, _draft!.$2);
      }
      if (!active()) return;
      profile = loaded;
      if (loaded != null) _draft = null;
      phase = loaded == null ? SessionPhase.needsProfile : SessionPhase.ready;
    } on AppFailure catch (e) {
      if (!active()) {
        if (!_disposed && e.code == 'session-expired' && user == null) {
          error = e.message;
        }
        return;
      }
      error = e.message;
      phase = SessionPhase.profileError;
    } catch (_) {
      if (!active()) return;
      error =
          'No pudimos cargar tu perfil. Puedes reintentar sin registrarte de nuevo.';
      phase = SessionPhase.profileError;
    } finally {
      _notify();
    }
  }

  Future<bool> retryProfile() => _action(_loadProfile);
  Future<bool> completeProfile(String name, String surname) =>
      _action(() async {
        _draft = (name.trim(), surname.trim());
        await _loadProfile();
      });

  Future<bool> signOut() => _action(() async {
        await auth.signOut();
        _authChanged(null);
      });

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    unawaited(_subscription.cancel());
    users.close();
    super.dispose();
  }
}

class AuthScope extends InheritedNotifier<AuthController> {
  const AuthScope(
      {super.key, required AuthController controller, required super.child})
      : super(notifier: controller);
  static AuthController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AuthScope>()!.notifier!;
}

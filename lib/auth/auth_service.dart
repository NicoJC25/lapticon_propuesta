class AuthUser {
  const AuthUser({required this.uid, required this.email});
  final String uid;
  final String email;
}

class AppFailure implements Exception {
  const AppFailure(this.message, {this.code = 'unknown'});
  final String message;
  final String code;
  @override
  String toString() => message;
}

abstract class AuthService {
  bool get configured;
  String? get configurationMessage;
  Stream<AuthUser?> get authChanges;
  Future<AuthUser> signIn(String email, String password);
  Future<AuthUser> register(String email, String password);
  Future<AuthUser?> signInWithGoogle();
  Future<void> sendPasswordReset(String email);
  Future<String> idToken({bool forceRefresh = false});
  Future<void> signOut();
}

class UnconfiguredAuthService implements AuthService {
  const UnconfiguredAuthService(
      {this.configurationMessage =
          'Falta agregar la configuración del proyecto del profesor. El acceso estará disponible cuando se conecte Firebase.'});
  @override
  final String configurationMessage;
  @override
  bool get configured => false;
  @override
  Stream<AuthUser?> get authChanges => Stream.value(null);
  Never _missing() =>
      throw AppFailure(configurationMessage, code: 'configuration');
  @override
  Future<AuthUser> signIn(String email, String password) async => _missing();
  @override
  Future<AuthUser> register(String email, String password) async => _missing();
  @override
  Future<AuthUser?> signInWithGoogle() async => _missing();
  @override
  Future<void> sendPasswordReset(String email) async => _missing();
  @override
  Future<String> idToken({bool forceRefresh = false}) async => _missing();
  @override
  Future<void> signOut() async {}
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'auth_service.dart';

class FirebaseAuthService implements AuthService {
  FirebaseAuthService(this._auth, this._google);
  final FirebaseAuth _auth;
  final GoogleSignIn _google;

  /// Solo Android. Sin recursos Google válidos se permite abrir las pantallas.
  static Future<AuthService> bootstrap() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const UnconfiguredAuthService(
          configurationMessage:
              'La autenticación de esta entrega está preparada únicamente para Android.');
    }
    try {
      await Firebase.initializeApp();
      return FirebaseAuthService(
          FirebaseAuth.instance, GoogleSignIn(scopes: const ['email']));
    } catch (_) {
      // No revelar valores de configuración ni detalles nativos al usuario.
      return const UnconfiguredAuthService();
    }
  }

  @override
  bool get configured => true;
  @override
  bool get googleAvailable => false;
  @override
  String? get configurationMessage => null;
  static AuthUser _user(User? user) {
    if (user == null) {
      throw const AppFailure('Inicia sesión de nuevo.',
          code: 'session-expired');
    }
    return AuthUser(uid: user.uid, email: user.email ?? '');
  }

  @override
  Stream<AuthUser?> get authChanges =>
      _auth.authStateChanges().map((user) => user == null ? null : _user(user));

  @override
  Future<AuthUser> signIn(String email, String password) async {
    try {
      return _user((await _auth.signInWithEmailAndPassword(
              email: email.trim(), password: password))
          .user);
    } on FirebaseAuthException catch (e) {
      throw _failure(e);
    }
  }

  @override
  Future<AuthUser> register(String email, String password) async {
    try {
      return _user((await _auth.createUserWithEmailAndPassword(
              email: email.trim(), password: password))
          .user);
    } on FirebaseAuthException catch (e) {
      throw _failure(e);
    }
  }

  @override
  Future<AuthUser?> signInWithGoogle() async {
    if (!googleAvailable) {
      throw const AppFailure(
          'Google está pendiente de configurar. Ingresa con correo y contraseña.',
          code: 'google-pending');
    }
    try {
      final account = await _google.signIn();
      if (account == null) return null;
      final tokens = await account.authentication;
      final credential = GoogleAuthProvider.credential(
          accessToken: tokens.accessToken, idToken: tokens.idToken);
      return _user((await _auth.signInWithCredential(credential)).user);
    } on FirebaseAuthException catch (e) {
      throw _failure(e);
    } on PlatformException catch (e) {
      if (e.code == 'sign_in_canceled' || e.code == 'sign_in_cancelled') {
        return null;
      }
      if (e.code == 'network_error') {
        throw const AppFailure(
            'No se pudo conectar con Google. Revisa tu conexión.',
            code: 'network');
      }
      throw const AppFailure(
          'No se pudo iniciar con Google. Revisa el proveedor, el cliente OAuth y la huella SHA-1 en Firebase.',
          code: 'google-configuration');
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      // La respuesta no permite averiguar qué correos tienen cuenta.
      if (e.code != 'user-not-found') throw _failure(e);
    }
  }

  @override
  Future<String> idToken({bool forceRefresh = false}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw const AppFailure('Tu sesión terminó. Inicia sesión de nuevo.',
            code: 'session-expired');
      }
      final token = await user.getIdToken(forceRefresh);
      if (token == null || token.isEmpty) {
        throw const AppFailure('Tu sesión terminó. Inicia sesión de nuevo.',
            code: 'session-expired');
      }
      return token;
    } on FirebaseAuthException catch (e) {
      throw _failure(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      throw _failure(e);
    }
    // No impedir cerrar Firebase si falla la limpieza del selector de Google.
    try {
      await _google.signOut();
    } catch (_) {}
  }

  static AppFailure _failure(FirebaseAuthException error) {
    final message = switch (error.code) {
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' =>
        'El correo o la contraseña no son correctos.',
      'invalid-email' => 'Escribe un correo electrónico válido.',
      'email-already-in-use' =>
        'Este correo ya tiene una cuenta. Inicia sesión o recupera tu contraseña.',
      'weak-password' =>
        'La contraseña no cumple los requisitos del proyecto Firebase.',
      'user-disabled' => 'Esta cuenta está deshabilitada.',
      'network-request-failed' =>
        'No hay conexión con Firebase. Revisa Internet e inténtalo de nuevo.',
      'too-many-requests' =>
        'Se hicieron demasiados intentos. Espera un momento y vuelve a intentar.',
      'operation-not-allowed' =>
        'Este método de acceso no está habilitado en Firebase.',
      'account-exists-with-different-credential' =>
        'Este correo utiliza otro método de acceso. Ingresa con el método original.',
      'user-token-expired' ||
      'invalid-user-token' =>
        'Tu sesión terminó. Inicia sesión de nuevo.',
      'invalid-api-key' ||
      'app-not-authorized' ||
      'configuration-not-found' =>
        'La configuración de Firebase no es válida para esta aplicación Android.',
      _ => 'No se pudo completar la autenticación. Inténtalo de nuevo.',
    };
    return AppFailure(message,
        code: switch (error.code) {
          'user-token-expired' ||
          'invalid-user-token' ||
          'user-disabled' =>
            'session-expired',
          _ => error.code,
        });
  }
}

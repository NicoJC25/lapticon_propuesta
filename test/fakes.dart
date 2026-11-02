import 'dart:async';
import 'package:lapticon/auth/auth_service.dart';
import 'package:lapticon/data/user_repository.dart';

const testUser = AuthUser(uid: 'u-123', email: 'ana@example.com');
const testProfile = UserProfile(
    uid: 'u-123', email: 'ana@example.com', name: 'Ana', surname: 'Gómez');

class FakeAuthService implements AuthService {
  FakeAuthService({this.user});
  AuthUser? user;
  final changes = StreamController<AuthUser?>.broadcast(sync: true);
  int loginCalls = 0,
      registerCalls = 0,
      googleCalls = 0,
      resetCalls = 0,
      logoutCalls = 0;
  AppFailure? failure;
  AppFailure? tokenFailure;
  bool googleCancelled = false;
  Completer<void>? gate;
  final tokenRequests = <bool>[];
  @override
  bool get configured => true;
  @override
  String? get configurationMessage => null;
  @override
  Stream<AuthUser?> get authChanges async* {
    yield user;
    yield* changes.stream;
  }

  Future<AuthUser> _login() async {
    if (gate != null) await gate!.future;
    if (failure != null) throw failure!;
    user = testUser;
    changes.add(user);
    return user!;
  }

  @override
  Future<AuthUser> signIn(String email, String password) {
    loginCalls++;
    return _login();
  }

  @override
  Future<AuthUser> register(String email, String password) {
    registerCalls++;
    return _login();
  }

  @override
  Future<AuthUser?> signInWithGoogle() async {
    googleCalls++;
    if (googleCancelled) return null;
    return _login();
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    resetCalls++;
    if (failure != null) throw failure!;
  }

  @override
  Future<String> idToken({bool forceRefresh = false}) async {
    tokenRequests.add(forceRefresh);
    if (tokenFailure != null) throw tokenFailure!;
    return forceRefresh ? 'renewed-test-token' : 'initial-test-token';
  }

  @override
  Future<void> signOut() async {
    logoutCalls++;
    user = null;
    changes.add(null);
  }

  Future<void> close() => changes.close();
}

class FakeUserRepository extends UserRepository {
  UserProfile? stored;
  AppFailure? fetchFailure, createFailure;
  int reads = 0, writes = 0;
  Completer<void>? gate;
  @override
  Future<UserProfile?> fetch(AuthUser user) async {
    reads++;
    if (gate != null) await gate!.future;
    if (fetchFailure != null) throw fetchFailure!;
    return stored;
  }

  @override
  Future<UserProfile> create(AuthUser user, String name, String surname) async {
    writes++;
    if (createFailure != null) throw createFailure!;
    return stored = UserProfile(
        uid: user.uid, email: user.email, name: name, surname: surname);
  }
}

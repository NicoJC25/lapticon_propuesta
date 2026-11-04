import 'dart:async';
import 'package:lapticon/auth/auth_service.dart';
import 'package:lapticon/data/shipment_repository.dart';
import 'package:lapticon/data/trip_repository.dart';
import 'package:lapticon/data/user_repository.dart';
import 'package:lapticon/roles/user_role.dart';

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

  /// Simula si el backend conserva `rol`: hoy su modelo no lo tiene.
  bool serverKeepsRole = false;
  AppFailure? roleFailure;
  final savedRoles = <UserRole>[];
  @override
  Future<UserRole?> saveRole(
      AuthUser user, UserProfile profile, UserRole role) async {
    savedRoles.add(role);
    if (roleFailure != null) throw roleFailure!;
    if (!serverKeepsRole) return null;
    stored = UserProfile(
        uid: profile.uid,
        email: profile.email,
        name: profile.name,
        surname: profile.surname,
        role: role);
    return role;
  }
}

class FakeShipmentRepository extends ShipmentRepository {
  final places = <String, List<String>>{
    'Colombia': ['Bogotá', 'Medellin', 'Cali'],
    'España': ['Madrid', 'Barcelona'],
  };
  AppFailure? createFailure;
  AppFailure? placesFailure;
  final created = <ShipmentDraft>[];
  Completer<void>? gate;

  @override
  Future<List<String>> countries() async {
    if (placesFailure != null) throw placesFailure!;
    return places.keys.toList();
  }

  @override
  Future<List<String>> cities(String country) async {
    if (placesFailure != null) throw placesFailure!;
    return places[country] ?? const [];
  }

  @override
  Future<Shipment> create(ShipmentDraft draft) async {
    created.add(draft);
    if (gate != null) await gate!.future;
    if (createFailure != null) throw createFailure!;
    return Shipment(
        id: 'enc-${created.length}',
        origin: draft.origin.city,
        destination: draft.destination.city,
        notes: draft.notes.trim(),
        currency: draft.currency,
        value: draft.value,
        status: ShipmentStatus.disponible,
        expiresAt: draft.expiresOn);
  }

  /// Encomiendas del remitente que devuelve `mine()`.
  List<Shipment> mineItems = [];

  /// Resultado de `search()`; se actualiza al tomar una encomienda.
  List<Shipment> available = [];
  List<Shipment> taken = [];
  AppFailure? listFailure, takeFailure;
  final searches = <(String, String)>[];
  final takes = <String>[];

  @override
  Future<List<Shipment>> mine() async {
    if (listFailure != null) throw listFailure!;
    return List.of(mineItems);
  }

  @override
  Future<ShipmentSearch> search(String origin, String destination) async {
    searches.add((origin, destination));
    if (listFailure != null) throw listFailure!;
    return ShipmentSearch(available: List.of(available), taken: List.of(taken));
  }

  @override
  Future<void> take(String id) async {
    takes.add(id);
    if (takeFailure != null) throw takeFailure!;
    final index = available.indexWhere((s) => s.id == id);
    if (index >= 0) taken.add(available.removeAt(index));
  }
}

Shipment shipment(String id,
        {String origin = 'Bogotá',
        String destination = 'Madrid',
        ShipmentStatus status = ShipmentStatus.disponible,
        String notes = 'Dos libros',
        num value = 50000}) =>
    Shipment(
        id: id,
        origin: origin,
        destination: destination,
        notes: notes,
        currency: 'COP',
        value: value,
        status: status,
        ownerName: 'Ana');

class FakeTripRepository extends TripRepository {
  Trip? activeTrip;
  FlightCheck check = const FlightCheck(FlightCheckResult.found,
      summary: 'Avianca · Bogotá → Madrid');
  AppFailure? registerFailure, activeFailure;
  final registered = <TripDraft>[];
  final checks = <(String, DateTime)>[];
  final cancelled = <String>[];

  @override
  Future<Trip?> active() async {
    if (activeFailure != null) throw activeFailure!;
    return activeTrip;
  }

  @override
  Future<List<Trip>> mine() async => [if (activeTrip != null) activeTrip!];

  @override
  Future<FlightCheck> checkFlight(String flightNumber, DateTime date) async {
    checks.add((flightNumber, date));
    return check;
  }

  @override
  Future<Trip> register(TripDraft draft) async {
    registered.add(draft);
    if (registerFailure != null) throw registerFailure!;
    return activeTrip = Trip(
        id: 'viaje-${registered.length}',
        flightNumber: normalizeFlightNumber(draft.flightNumber),
        origin: draft.origin.city,
        destination: draft.destination.city,
        date: DateTime.utc(draft.date.year, draft.date.month, draft.date.day),
        status: TripStatus.disponible);
  }

  @override
  Future<void> cancel(String id) async {
    cancelled.add(id);
    activeTrip = null;
  }
}

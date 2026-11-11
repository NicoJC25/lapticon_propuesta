import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import '../auth/auth_service.dart';
import '../roles/user_role.dart';
import 'api_client.dart';
import 'shipment_repository.dart';
import 'delivered_shipment_store.dart';

class RatingTarget {
  const RatingTarget(this.uid, this.role);
  final String uid;
  final UserRole role;
  static RatingTarget? forShipment(Shipment s, String uid) {
    if (uid.isEmpty ||
        s.id.isEmpty ||
        s.status != ShipmentStatus.recibida ||
        s.ownerId.isEmpty ||
        s.travelerId.isEmpty ||
        s.ownerId == s.travelerId) {
      return null;
    }
    if (s.ownerId == uid) return RatingTarget(s.travelerId, UserRole.viajero);
    if (s.travelerId == uid) return RatingTarget(s.ownerId, UserRole.remitente);
    return null;
  }
}

class UserRating {
  const UserRating(
      {required this.author,
      required this.target,
      required this.role,
      required this.score,
      required this.comment});
  final String author, target, comment;
  final UserRole role;
  final num score;
  factory UserRating.fromJson(Map<String, dynamic> j) {
    final role = UserRole.parse(j['rolDestino']);
    final score = j['calificacion'];
    if (j['usuarioOrigen'] is! String ||
        (j['usuarioOrigen'] as String).isEmpty ||
        j['usuarioDestino'] is! String ||
        (j['usuarioDestino'] as String).isEmpty ||
        role == null ||
        score is! num ||
        !score.isFinite ||
        score < 1 ||
        score > 5 ||
        (j['comentario'] != null && j['comentario'] is! String)) {
      throw const AppFailure(
          'La respuesta de calificaciones no tiene el formato esperado.',
          code: 'invalid-response');
    }
    return UserRating(
        author: j['usuarioOrigen'],
        target: j['usuarioDestino'],
        role: role,
        score: score,
        comment: j['comentario'] ?? '');
  }
}

class RatingReceipt {
  const RatingReceipt(this.rating, {this.alreadyExists = false});
  final UserRating rating;
  final bool alreadyExists;
}

abstract class RatingRepository {
  Future<UserRating?> existing(String author, RatingTarget target);
  Future<RatingReceipt> rate(
      AuthUser author, Shipment shipment, int score, String comment);
  void close() {}
}

class ApiRatingRepository implements RatingRepository {
  ApiRatingRepository(this.auth,
      {http.Client? client, String baseUrl = defaultApiBaseUrl})
      : _api = ApiClient(auth, client: client, baseUrl: baseUrl);
  final AuthService auth;
  final ApiClient _api;
  @override
  Future<UserRating?> existing(String author, RatingTarget target) async {
    final response = await _api.send(
        'GET', '/api/ratings/${Uri.encodeComponent(target.uid)}',
        authenticated: false);
    final json =
        _api.decode(response, 'No se pudieron interpretar las calificaciones.');
    if (json is! Map || json['calificaciones'] is! List) {
      throw const AppFailure(
          'La lista de calificaciones no tiene el formato esperado.',
          code: 'invalid-response');
    }
    for (final item in json['calificaciones']) {
      if (item is! Map<String, dynamic>) {
        throw const AppFailure('Calificación inválida.',
            code: 'invalid-response');
      }
      final rating = UserRating.fromJson(item);
      if (rating.target != target.uid) {
        throw const AppFailure(
            'La API devolvió calificaciones de otro usuario.',
            code: 'invalid-response');
      }
      if (rating.author == author && rating.role == target.role) return rating;
    }
    return null;
  }

  Future<void> _checkSession(AuthUser user) async {
    if ((await auth.authChanges.first)?.uid != user.uid) {
      throw const AppFailure('La sesión cambió. Abre de nuevo la calificación.',
          code: 'session-changed');
    }
  }

  final _pending = <String, Future<RatingReceipt>>{};
  @override
  Future<RatingReceipt> rate(
      AuthUser author, Shipment shipment, int score, String comment) {
    final target = RatingTarget.forShipment(shipment, author.uid);
    final key = '${author.uid}:${target?.uid}:${target?.role.apiValue}';
    return _pending.putIfAbsent(
        key,
        () => _rate(author, shipment, score, comment).whenComplete(() {
              _pending.remove(key);
            }));
  }

  Future<RatingReceipt> _rate(
      AuthUser author, Shipment shipment, int score, String comment) async {
    final target = RatingTarget.forShipment(shipment, author.uid);
    if (target == null) {
      throw const AppFailure(
          'Solo los participantes pueden calificar después de la entrega.',
          code: 'forbidden');
    }
    if (score < 1 || score > 5 || comment.trim().length > 500) {
      throw const AppFailure(
          'Selecciona de 1 a 5 estrellas y escribe hasta 500 caracteres.',
          code: 'validation');
    }
    await _checkSession(author);
    final previous = await existing(author.uid, target);
    if (previous != null) return RatingReceipt(previous, alreadyExists: true);
    await _checkSession(author);
    try {
      final response = await _api.send('POST', '/api/ratings',
          body: {
            'usuarioDestino': target.uid,
            'rolDestino': target.role.apiValue,
            'calificacion': score,
            'comentario': comment.trim()
          },
          forbiddenMessage: 'No tienes permiso para calificar a este usuario.');
      final decoded = _api.decode(response,
          'La API aceptó la solicitud, pero no confirmó la calificación. Vuelve a consultar antes de reenviar.');
      final nested = decoded is Map ? decoded['rating'] : null;
      final data = nested is Map<String, dynamic> ? nested : decoded;
      if (data is Map<String, dynamic>) {
        final rating = UserRating.fromJson(data);
        if (rating.author == author.uid &&
            rating.target == target.uid &&
            rating.role == target.role &&
            rating.score == score) {
          return RatingReceipt(rating);
        }
      }
      throw const AppFailure('La API no confirmó la calificación enviada.',
          code: 'invalid-response');
    } on AppFailure catch (e) {
      // Una respuesta perdida puede haber guardado el POST; no reenviar sin consultar.
      if (const {'api', 'invalid-response', 'network', 'timeout', 'server'}
          .contains(e.code)) {
        final saved = await existing(author.uid, target);
        if (saved != null) return RatingReceipt(saved, alreadyExists: true);
      }
      rethrow;
    }
  }

  @override
  void close() => _api.close();
}

class RatingScope extends InheritedWidget {
  const RatingScope(
      {super.key,
      required this.repository,
      required this.history,
      required super.child});
  final RatingRepository repository;
  final DeliveredShipmentStore history;
  static RatingScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RatingScope>()!;
  @override
  bool updateShouldNotify(RatingScope oldWidget) =>
      repository != oldWidget.repository || history != oldWidget.history;
}

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/auth_service.dart';
import 'shipment_repository.dart';

Shipment receivedCopy(Shipment s) => Shipment(
    id: s.id,
    origin: s.origin,
    destination: s.destination,
    notes: s.notes,
    currency: s.currency,
    value: s.value,
    status: ShipmentStatus.recibida,
    ownerId: s.ownerId,
    travelerId: s.travelerId,
    ownerName: s.ownerName,
    createdAt: s.createdAt,
    expiresAt: s.expiresAt);

abstract class DeliveredShipmentStore {
  Future<List<Shipment>> read(String uid);
  Future<void> remember(String uid, Shipment received);
}

bool _belongs(Shipment s, String uid) =>
    uid.isNotEmpty &&
    s.id.isNotEmpty &&
    s.status == ShipmentStatus.recibida &&
    (s.ownerId == uid || s.travelerId == uid);

class MemoryDeliveredShipmentStore implements DeliveredShipmentStore {
  final _items = <String, Map<String, Shipment>>{};
  @override
  Future<List<Shipment>> read(String uid) async =>
      _items[uid]?.values.toList() ?? [];
  @override
  Future<void> remember(String uid, Shipment received) async {
    if (!_belongs(received, uid)) {
      throw const AppFailure('La entrega no corresponde a la cuenta.',
          code: 'forbidden');
    }
    (_items[uid] ??= {})[received.id] = received;
  }
}

class SharedPreferencesDeliveredShipmentStore
    implements DeliveredShipmentStore {
  SharedPreferencesDeliveredShipmentStore(
      {Future<SharedPreferences> Function()? open})
      : _open = open ?? SharedPreferences.getInstance;
  final Future<SharedPreferences> Function() _open;
  static String keyFor(String uid) => 'lapticon.received.$uid';
  @override
  Future<List<Shipment>> read(String uid) async {
    final raw = (await _open()).getString(keyFor(uid));
    if (raw == null) return [];
    try {
      final json = jsonDecode(raw);
      if (json is! List) throw const FormatException();
      return [
        for (final item in json)
          if (item is Map<String, dynamic>) Shipment.fromJson(item)
      ].where((s) => _belongs(s, uid)).toList();
    } on FormatException {
      throw const AppFailure('No se pudo leer el historial local de entregas.',
          code: 'storage');
    }
  }

  // Serializa escrituras de distintas tarjetas para no perder entregas concurrentes.
  Future<void> _pending = Future.value();
  @override
  Future<void> remember(String uid, Shipment received) {
    final result = _pending.catchError((Object _) {}).then((_) async {
      if (!_belongs(received, uid)) {
        throw const AppFailure('La entrega no corresponde a la cuenta.',
            code: 'forbidden');
      }
      final items = {
        for (final s in await read(uid)) s.id: s,
        received.id: received
      };
      final json = [
        for (final s in items.values)
          {
            '_id': s.id,
            'uid': s.ownerId,
            'viajeroId': s.travelerId,
            'ciudadOrigen': s.origin,
            'ciudadDestino': s.destination,
            'observaciones': s.notes,
            'moneda': s.currency,
            'valor': s.value,
            'estado': 'recibida',
            'nombreRemitente': s.ownerName,
            if (s.createdAt != null)
              'fechaCreacion': s.createdAt!.toIso8601String()
          }
      ];
      if (!await (await _open()).setString(keyFor(uid), jsonEncode(json))) {
        throw const AppFailure(
            'No se pudo conservar la entrega en este dispositivo.',
            code: 'storage');
      }
    });
    _pending = result;
    return result;
  }
}

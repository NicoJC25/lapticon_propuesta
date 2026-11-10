import 'package:flutter/material.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_service.dart';
import '../data/shipment_repository.dart';
import '../data/trip_repository.dart';
import '../widgets/access_components.dart';
import '../widgets/access_shell.dart';
import '../widgets/app_components.dart';
import '../widgets/shipment_card.dart';
import '../widgets/delivery_action.dart';

class MisEntregasScreen extends StatefulWidget {
  const MisEntregasScreen({super.key});
  @override
  State<MisEntregasScreen> createState() => _MisEntregasScreenState();
}

class _MisEntregasScreenState extends State<MisEntregasScreen> {
  List<Shipment>? _items;
  String? _error;
  bool _loading = true;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final auth = AuthScope.of(context);
    final uid = auth.user?.uid;
    final shipments = ShipmentScope.of(context);
    final trips = TripScope.of(context);
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // El API no documenta un listado global de entregas del viajero.
      // Consultar TODAS sus rutas permite entregar sin depender de un viaje activo.
      final history = await trips.mine();
      final routes = {
        for (final trip in history)
          if (trip.origin.isNotEmpty && trip.destination.isNotEmpty)
            (trip.origin, trip.destination)
      };
      final items = <String, Shipment>{};
      for (final route in routes) {
        if (!mounted || auth.user?.uid != uid || request != _request) return;
        final result = await shipments.search(route.$1, route.$2);
        for (final item in result.taken) {
          if (uid != null &&
              item.travelerId == uid &&
              item.status == ShipmentStatus.tomada) {
            items[item.id] = item;
          }
        }
      }
      if (mounted && request == _request && auth.user?.uid == uid) {
        setState(() => _items = items.values.toList());
      }
    } on AppFailure catch (e) {
      if (mounted && request == _request) setState(() => _error = e.message);
    } catch (_) {
      if (mounted && request == _request) {
        setState(() => _error = 'No se pudieron consultar tus entregas.');
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AccessShell(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AccessHeader(
            eyebrow: 'MIS ENTREGAS',
            title: 'Completa tus\nentregas.',
            subtitle:
                'Revisa las encomiendas que tomaste y marca la entrega cuando el paquete haya llegado a destino.'),
        if (_error != null)
          InlineNotice(
              title: 'No se cargaron tus entregas',
              message: _error!,
              error: true),
        OutlinedButton.icon(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Actualizar')),
        const SizedBox(height: 20),
        if (_loading && _items == null) const LoadingBlock(),
        if (!_loading && _error == null && _items?.isEmpty == true)
          const EmptyBlock(
              icon: Icons.task_alt,
              message:
                  'No tienes encomiendas pendientes de entrega en las rutas de tus viajes.'),
        for (final item in _items ?? <Shipment>[])
          ShipmentCard(
              key: ValueKey('delivery-card-${item.id}'),
              shipment: item,
              showOwner: true,
              action: DeliveryAction(
                  key: ValueKey('delivery-action-${item.id}'),
                  shipment: item,
                  onDelivered: _load)),
      ]));
}

import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../data/shipment_repository.dart';
import '../data/trip_repository.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/access_components.dart';
import '../widgets/access_shell.dart';
import '../widgets/app_components.dart';
import '../widgets/shipment_card.dart';
import 'mi_viaje_screen.dart';

/// Viajero: encomiendas de la ruta de su viaje disponible y tomarlas.
///
/// Usa `GET /api/viajes/disponible` para conocer la ruta, luego
/// `GET /api/encomiendas/buscar` y `PUT /api/encomiendas/tomar/{id}`.
class BuscarEncomiendasScreen extends StatefulWidget {
  const BuscarEncomiendasScreen({super.key});
  @override
  State<BuscarEncomiendasScreen> createState() =>
      _BuscarEncomiendasScreenState();
}

class _BuscarEncomiendasScreenState extends State<BuscarEncomiendasScreen> {
  bool _loading = true;
  Trip? _trip;
  bool _checkedTrip = false;
  ShipmentSearch? _result;
  String? _error;
  String? _notice;
  String? _taking;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  /// Con [keepMessages] se conservan los avisos de la última acción.
  Future<void> _load({bool keepMessages = false}) async {
    final trips = TripScope.of(context);
    final shipments = ShipmentScope.of(context);
    setState(() {
      _loading = true;
      if (!keepMessages) {
        _error = null;
        _notice = null;
      }
    });
    try {
      final trip = await trips.active();
      ShipmentSearch? result;
      if (trip != null) {
        result = await shipments.search(trip.origin, trip.destination);
      }
      if (!mounted) return;
      setState(() {
        _trip = trip;
        _checkedTrip = true;
        _result = result;
      });
    } on AppFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudieron buscar encomiendas.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _take(Shipment shipment) async {
    if (_taking != null) return;
    final shipments = ShipmentScope.of(context);
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('¿Tomar esta encomienda?'),
                content: Text(
                    'Te comprometes a llevarla de ${shipment.origin} a ${shipment.destination}${shipment.value == null ? '' : ' por ${formatMoney(shipment.value!, shipment.currency)}'}. El remitente verá que la tomaste.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Volver')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Sí, tomarla')),
                ]));
    if (confirmed != true || !mounted) return;
    setState(() {
      _taking = shipment.id;
      _error = null;
      _notice = null;
    });
    try {
      await shipments.take(shipment.id);
      if (!mounted) return;
      setState(() => _notice =
          'Tomaste la encomienda de ${shipment.origin} a ${shipment.destination}. Coordina la entrega con el remitente.');
    } on AppFailure catch (e) {
      // 400: alguien más la tomó o venció. Se recarga la lista igual.
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo tomar la encomienda.');
    } finally {
      if (mounted) setState(() => _taking = null);
    }
    if (mounted) await _load(keepMessages: true);
  }

  void _openTrip() => Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/viajes/mio'),
          builder: (_) => const MiViajeScreen()));

  @override
  Widget build(BuildContext context) {
    final trip = _trip;
    final result = _result;
    return AccessShell(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AccessHeader(
          eyebrow: 'BUSCAR ENCOMIENDAS',
          title: 'Encomiendas\nde tu ruta.',
          subtitle: trip == null
              ? 'Te mostramos las encomiendas que coinciden con tu viaje disponible.'
              : '${trip.origin} → ${trip.destination} · ${formatOptionalDate(trip.date, 'sin fecha')}'),
      if (_notice != null)
        InlineNotice(
            title: 'Encomienda tomada',
            message: _notice!,
            onClose: () => setState(() => _notice = null)),
      if (_error != null)
        InlineNotice(
            title: 'No se completó la acción', message: _error!, error: true),
      if (_loading && result == null)
        const LoadingBlock()
      else if (_checkedTrip && trip == null)
        EmptyBlock(
            icon: Icons.flight_takeoff_rounded,
            message:
                'Primero registra tu viaje. Buscaremos encomiendas con su mismo origen y destino.',
            action: FilledButton.icon(
                onPressed: _openTrip,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Registrar mi viaje')))
      else if (result != null) ...[
        OutlinedButton.icon(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Actualizar')),
        const SizedBox(height: 20),
        _heading('Disponibles · ${result.available.length}'),
        if (result.available.isEmpty)
          const EmptyBlock(
              icon: Icons.inbox_outlined,
              message:
                  'No hay encomiendas disponibles en tu ruta por ahora. Vuelve a revisar más tarde.')
        else
          for (final shipment in result.available)
            ShipmentCard(
                shipment: shipment,
                showOwner: true,
                action: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                        key: ValueKey('tomar-${shipment.id}'),
                        onPressed: _taking == null && !_loading
                            ? () => _take(shipment)
                            : null,
                        icon: _taking == shipment.id
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.handshake_outlined),
                        label: const Text('Tomar encomienda')))),
        if (result.taken.isNotEmpty) ...[
          const SizedBox(height: 12),
          _heading('Ya las tomaste · ${result.taken.length}'),
          for (final shipment in result.taken)
            ShipmentCard(shipment: shipment, showOwner: true),
        ],
      ] else if (_error != null)
        OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar')),
      const SizedBox(height: 16),
    ]));
  }

  Widget _heading(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Semantics(
          header: true,
          child: Text(text.toUpperCase(),
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: AppColors.muted))));
}

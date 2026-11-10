import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../data/trip_repository.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/access_components.dart';
import '../widgets/access_shell.dart';
import '../widgets/app_components.dart';
import '../widgets/shipment_card.dart';
import 'buscar_encomiendas_screen.dart';
import 'flight_search_screen.dart';

/// Viajero: selecciona un vuelo publicado por ruta y fecha o gestiona el activo.
class MiViajeScreen extends StatefulWidget {
  const MiViajeScreen({super.key, this.today});

  /// Fecha de referencia para el calendario; se inyecta en pruebas.
  final DateTime? today;
  @override
  State<MiViajeScreen> createState() => _MiViajeScreenState();
}

class _MiViajeScreenState extends State<MiViajeScreen> {
  bool _loading = true;
  bool _busy = false;
  Trip? _trip;
  String? _loadError;
  String? _error;

  /// Aviso tras registrar o cancelar.
  String? _notice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final trips = TripScope.of(context);
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final trip = await trips.active();
      if (mounted) setState(() => _trip = trip);
    } on AppFailure catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = 'No se pudo consultar tu viaje.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectFlight(TripDraft draft) async {
    final trips = TripScope.of(context);
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                scrollable: true,
                title: const Text('Confirmar viaje'),
                content: Text(
                    '${draft.flightNumber}\n${draft.origin.city} → ${draft.destination.city}\n${formatDate(draft.date)}'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Volver')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Registrar viaje'))
                ]));
    if (confirmed != true || !mounted) return;
    final trip = await trips.register(draft);
    if (mounted) {
      setState(() {
        _trip = trip;
        _error = null;
        _notice = 'Viaje registrado con el vuelo seleccionado.';
      });
    }
  }

  Future<void> _cancel(Trip trip) async {
    final trips = TripScope.of(context);
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                // Desplazable: con texto grande no cabe en pantallas pequeñas.
                scrollable: true,
                title: const Text('¿Cancelar tu viaje?'),
                content: Text(
                    'El viaje ${trip.flightNumber} de ${trip.origin} a ${trip.destination} dejará de estar disponible.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Volver')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Cancelar viaje')),
                ]));
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await trips.cancel(trip.id);
      if (!mounted) return;
      setState(() {
        _trip = null;
        _notice = 'Cancelaste tu viaje. Puedes registrar otro.';
      });
    } on AppFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo cancelar el viaje.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _search() => Navigator.of(context).push(MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/encomiendas/buscar'),
      builder: (_) => const BuscarEncomiendasScreen()));

  @override
  Widget build(BuildContext context) {
    final trip = _trip;
    if (!_loading && _loadError == null && trip == null) {
      return FlightSearchScreen(
          repository: TripScope.of(context),
          onSelected: _selectFlight,
          initialDate: widget.today,
          notice: _notice);
    }
    return AccessShell(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AccessHeader(
          eyebrow: 'MI VIAJE',
          title:
              trip == null ? 'Registra\ntu viaje.' : 'Tu viaje\nestá activo.',
          subtitle: trip == null
              ? 'Selecciona origen, destino y fecha para ver vuelos disponibles.'
              : 'Los remitentes de esta ruta pueden encontrarte. Busca encomiendas para llevar.'),
      if (_notice != null)
        InlineNotice(
            message: _notice!, onClose: () => setState(() => _notice = null)),
      if (_error != null)
        InlineNotice(title: 'Revisa tu viaje', message: _error!, error: true),
      if (_loading)
        const LoadingBlock()
      else if (_loadError != null) ...[
        InlineNotice(
            title: 'No se pudo consultar tu viaje',
            message: _loadError!,
            error: true),
        OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar')),
      ] else if (trip != null)
        _tripView(trip),
      const SizedBox(height: 16),
    ]));
  }

  Widget _tripView(Trip trip) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.teal, width: 1.5)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Wrap: con texto grande la etiqueta baja a otra línea.
              Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.flight_takeoff_rounded,
                          color: AppColors.teal),
                      const SizedBox(width: 10),
                      Flexible(
                          child: Text(trip.flightNumber,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink))),
                    ]),
                    StatusChip(
                        label: trip.status.label,
                        tone: trip.status == TripStatus.disponible
                            ? ChipTone.teal
                            : ChipTone.grey),
                  ]),
              const SizedBox(height: 12),
              Text('${trip.origin} → ${trip.destination}',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink)),
              const SizedBox(height: 4),
              Text(formatOptionalDate(trip.date, 'Sin fecha'),
                  style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            ])),
        PrimaryAction(
            label: 'Buscar encomiendas de mi ruta',
            icon: Icons.search_rounded,
            onPressed: _busy ? null : _search),
        const SizedBox(height: 8),
        TextButton.icon(
            onPressed: _busy ? null : () => _cancel(trip),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Cancelar viaje')),
      ]);
}

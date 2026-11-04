import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../data/shipment_repository.dart';
import '../data/trip_repository.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/access_components.dart';
import '../widgets/access_shell.dart';
import '../widgets/app_components.dart';
import '../widgets/date_field.dart';
import '../widgets/place_picker.dart';
import '../widgets/shipment_card.dart';
import 'buscar_encomiendas_screen.dart';

/// Viajero: ver su viaje disponible o registrar uno nuevo.
///
/// Flujo del registro: primero se consulta `GET /api/vuelos/{numero}/{fecha}`.
/// Si el vuelo no existe se bloquea; si el servicio de vuelos no responde
/// (hoy el servidor no tiene `RAPIDAPI_KEY`), se permite registrar sin validar
/// tras avisarlo. Luego `POST /api/viajes`.
class MiViajeScreen extends StatefulWidget {
  const MiViajeScreen({super.key, this.today});

  /// Fecha de referencia para el calendario; se inyecta en pruebas.
  final DateTime? today;
  @override
  State<MiViajeScreen> createState() => _MiViajeScreenState();
}

class _MiViajeScreenState extends State<MiViajeScreen> {
  var _form = GlobalKey<FormState>();
  final _flight = TextEditingController();
  Place? _origin;
  Place? _destination;
  DateTime? _date;

  bool _loading = true;
  bool _busy = false;
  Trip? _trip;
  String? _loadError;
  String? _error;

  /// Aviso tras registrar o cancelar.
  String? _notice;

  /// El servicio de vuelos no respondió: se ofrece registrar sin validar.
  String? _unverifiedReason;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _flight.dispose();
    super.dispose();
  }

  DateTime get _today {
    final now = widget.today ?? DateTime.now();
    return DateTime(now.year, now.month, now.day);
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

  String? _validateDestination(Place? place) {
    if (place == null) return 'Elige la ciudad de destino.';
    if (_origin != null &&
        fold(place.city) == fold(_origin!.city) &&
        place.country == _origin!.country) {
      return 'El destino debe ser diferente del origen.';
    }
    return null;
  }

  static String? validateFlight(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Escribe el número de vuelo.';
    if (!isValidFlightNumber(text)) {
      return 'Usa el código de la aerolínea y el número, como AV9361.';
    }
    return null;
  }

  TripDraft _draft() => TripDraft(
      flightNumber: _flight.text,
      origin: _origin!,
      destination: _destination!,
      date: _date!);

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _error = null;
      _notice = null;
      _unverifiedReason = null;
    });
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final trips = TripScope.of(context);
    final draft = _draft();
    setState(() => _busy = true);
    try {
      final check = await trips.checkFlight(draft.flightNumber, draft.date);
      if (!mounted) return;
      switch (check.result) {
        case FlightCheckResult.notFound:
          setState(() => _error =
              'No encontramos el vuelo ${normalizeFlightNumber(draft.flightNumber)} para el ${formatDate(draft.date)}. Revisa el número y la fecha.');
        case FlightCheckResult.unavailable:
          setState(() => _unverifiedReason = check.message ?? '');
        case FlightCheckResult.found:
          await _register(trips, draft,
              notice: check.summary == null
                  ? 'Vuelo validado y viaje registrado.'
                  : 'Vuelo validado: ${check.summary}.');
      }
    } on AppFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo validar el vuelo. Inténtalo de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _registerUnverified() async {
    if (_busy) return;
    final trips = TripScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _register(trips, _draft(),
          notice:
              'Viaje registrado sin validar el vuelo, porque el servicio de vuelos no respondió.');
    } on AppFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo registrar el viaje. Inténtalo de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _register(TripRepository trips, TripDraft draft,
      {required String notice}) async {
    final trip = await trips.register(draft);
    if (!mounted) return;
    setState(() {
      _trip = trip;
      _notice = notice;
      _unverifiedReason = null;
    });
  }

  Future<void> _cancel(Trip trip) async {
    final trips = TripScope.of(context);
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
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
        _form = GlobalKey<FormState>();
        _flight.clear();
        _origin = null;
        _destination = null;
        _date = null;
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
    return AccessShell(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AccessHeader(
          eyebrow: 'MI VIAJE',
          title: trip == null ? 'Registra\ntu viaje.' : 'Tu viaje\nestá activo.',
          subtitle: trip == null
              ? 'Ingresa tu vuelo, la fecha y la ruta. Solo puedes tener un viaje disponible a la vez.'
              : 'Los remitentes de esta ruta pueden encontrarte. Busca encomiendas para llevar.'),
      if (_notice != null)
        InlineNotice(
            message: _notice!,
            onClose: () => setState(() => _notice = null)),
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
        _tripView(trip)
      else
        _formView(),
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
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.muted)),
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

  Widget _formView() {
    final places = ShipmentScope.of(context);
    final enabled = !_busy;
    return Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const FieldLabel('Número de vuelo'),
          Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: TextFormField(
                  key: const ValueKey('campo-vuelo'),
                  controller: _flight,
                  enabled: enabled,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  validator: validateFlight,
                  onChanged: (_) {
                    if (_unverifiedReason != null) {
                      setState(() => _unverifiedReason = null);
                    }
                  },
                  decoration: const InputDecoration(
                      hintText: 'Ej.: AV9361',
                      prefixIcon: Icon(Icons.confirmation_number_outlined,
                          size: 19, color: AppColors.muted)))),
          DateField(
              key: const ValueKey('campo-fecha-viaje'),
              label: 'Fecha del vuelo',
              hint: 'Elige la fecha',
              firstDate: _today,
              lastDate: _today.add(const Duration(days: 365)),
              enabled: enabled,
              validator: (date) =>
                  date == null ? 'Elige la fecha del vuelo.' : null,
              onChanged: (date) => setState(() {
                    _date = date;
                    _unverifiedReason = null;
                  })),
          PlacePickerField(
              key: const ValueKey('campo-origen'),
              label: 'Origen',
              hint: 'Ciudad de salida',
              icon: Icons.trip_origin_rounded,
              repository: places,
              enabled: enabled,
              validator: (place) =>
                  place == null ? 'Elige la ciudad de origen.' : null,
              onChanged: (place) => setState(() => _origin = place)),
          PlacePickerField(
              key: const ValueKey('campo-destino'),
              label: 'Destino',
              hint: 'Ciudad de llegada',
              icon: Icons.place_outlined,
              repository: places,
              enabled: enabled,
              validator: _validateDestination,
              onChanged: (place) => setState(() => _destination = place)),
          const SizedBox(height: 6),
          if (_unverifiedReason != null) ...[
            InlineNotice(
                title: 'No se pudo validar el vuelo',
                message:
                    'El servicio de vuelos del servidor no respondió, así que no sabemos si el vuelo existe. Puedes registrarlo de todas formas.'),
            PrimaryAction(
                label: 'Registrar sin validar',
                icon: Icons.flight_takeoff_rounded,
                busy: _busy,
                onPressed: enabled ? _registerUnverified : null),
            const SizedBox(height: 8),
            TextButton(
                onPressed: enabled ? _submit : null,
                child: const Text('Intentar validar otra vez')),
          ] else
            PrimaryAction(
                label: 'Validar vuelo y registrar',
                icon: Icons.verified_outlined,
                busy: _busy,
                onPressed: enabled ? _submit : null),
        ]));
  }
}

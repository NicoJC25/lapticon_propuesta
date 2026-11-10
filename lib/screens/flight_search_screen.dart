import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../data/flight_catalog.dart';
import '../data/flight_city.dart';
import '../widgets/flight_city_field.dart';
import '../data/trip_repository.dart';
import '../utils/format.dart';
import '../widgets/access_shell.dart';
import '../widgets/access_components.dart';
import '../widgets/app_components.dart';

class FlightSearchScreen extends StatefulWidget {
  const FlightSearchScreen({super.key, required this.repository});
  final TripRepository repository;
  @override
  State<FlightSearchScreen> createState() => _FlightSearchScreenState();
}

class _FlightSearchScreenState extends State<FlightSearchScreen> {
  final _form = GlobalKey<FormState>();
  FlightCity? _origin, _destination;
  late DateTime _date = DateUtils.dateOnly(DateTime.now());
  List<FlightOption>? _flights;
  String? _error;
  bool _busy = false;
  Future<void> _search() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _flights = null;
    });
    try {
      final flights = await widget.repository
          .searchFlights(_origin!.iata, _destination!.iata, isoDate(_date));
      if (mounted) setState(() => _flights = flights);
    } on AppFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudieron consultar los vuelos.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(String label, bool origin) => FlightCityField(
      key: ValueKey(origin ? 'vuelo-origen' : 'vuelo-destino'),
      label: label,
      value: origin ? _origin : _destination,
      enabled: !_busy,
      onChanged: (city) => setState(() {
            if (origin) {
              _origin = city;
            } else {
              _destination = city;
            }
            _flights = null;
            _error = null;
          }),
      validator: (city) {
        if (city == null) {
          return 'Selecciona la ciudad de ${origin ? 'origen' : 'destino'}.';
        }
        if (!origin && city == _origin) {
          return 'El destino debe ser diferente del origen.';
        }
        return null;
      });
  @override
  Widget build(BuildContext context) => AccessShell(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AccessHeader(
            eyebrow: 'VUELOS POR RUTA',
            title: 'Elige tu vuelo.',
            subtitle:
                'Selecciona origen y destino entre las seis ciudades disponibles y elige la fecha. Elige un vuelo publicado para completar automáticamente número, ruta y fecha del viaje.'),
        if (_error != null) InlineNotice(message: _error!, error: true),
        Form(
            key: _form,
            child: Column(children: [
              _field('Origen', true),
              _field('Destino', false),
            ])),
        OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    final now = DateUtils.dateOnly(DateTime.now());
                    final date = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: now,
                        lastDate: now.add(const Duration(days: 180)));
                    if (date != null && mounted) {
                      setState(() {
                        _date = date;
                        _flights = null;
                      });
                    }
                  },
            icon: const Icon(Icons.calendar_today),
            label: Text(formatDate(_date))),
        const SizedBox(height: 20),
        PrimaryAction(
            label: 'Buscar vuelos',
            onPressed: _busy ? null : _search,
            busy: _busy),
        const SizedBox(height: 20),
        if (_flights != null && _flights!.isEmpty)
          const Text(
              'No hay vuelos publicados para esta ruta y fecha dentro de la cobertura del proveedor.'),
        for (final flight in _flights ?? <FlightOption>[])
          Card(
              child: ListTile(
                  isThreeLine: true,
                  title: Text('${flight.number} · ${flight.airline}'),
                  subtitle: Text(
                      '${flight.originCode} → ${flight.destinationCode}\n${flight.departure} (hora local de salida)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _busy
                      ? null
                      : () => Navigator.of(context).pop(flight.draft))),
      ]));
}

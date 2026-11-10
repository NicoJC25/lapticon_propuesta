import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../data/flight_catalog.dart';
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
  final _origin = TextEditingController(),
      _destination = TextEditingController();
  late DateTime _date = DateUtils.dateOnly(DateTime.now());
  List<FlightOption>? _flights;
  String? _error;
  bool _busy = false;
  Future<void> _pickAirport(TextEditingController target) async {
    var query = '';
    List<AirportOption> items = [];
    bool loading = false;
    String? error;
    final chosen = await showDialog<AirportOption>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
                    scrollable: true,
                    title: const Text('Buscar aeropuerto'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          onChanged: (value) => query = value,
                          enabled: !loading,
                          decoration: const InputDecoration(
                              labelText: 'Ciudad o aeropuerto',
                              hintText: 'Bogotá, Madrid, BOG…')),
                      if (error != null) Text(error!),
                      if (loading) const LinearProgressIndicator(),
                      TextButton(
                          onPressed: loading
                              ? null
                              : () async {
                                  if (query.trim().length < 3) {
                                    update(() => error =
                                        'Escribe al menos tres caracteres.');
                                    return;
                                  }
                                  update(() {
                                    loading = true;
                                    error = null;
                                    items = [];
                                  });
                                  try {
                                    final found = await widget.repository
                                        .searchAirports(query.trim());
                                    if (context.mounted) {
                                      update(() {
                                        items = found;
                                        if (found.isEmpty) {
                                          error =
                                              'No se encontraron aeropuertos.';
                                        }
                                      });
                                    }
                                  } on AppFailure catch (e) {
                                    if (context.mounted) {
                                      update(() => error = e.message);
                                    }
                                  } catch (_) {
                                    if (context.mounted) {
                                      update(() => error =
                                          'No se pudo consultar el catálogo.');
                                    }
                                  } finally {
                                    if (context.mounted) {
                                      update(() => loading = false);
                                    }
                                  }
                                },
                          child: const Text('Buscar aeropuertos')),
                      for (final airport in items)
                        ListTile(
                            title: Text(airport.label),
                            onTap: () => Navigator.pop(context, airport)),
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Volver'))
                    ])));
    if (chosen != null && mounted) {
      setState(() {
        target.text = chosen.iata;
        _flights = null;
      });
    }
  }

  @override
  void dispose() {
    _origin.dispose();
    _destination.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _flights = null;
    });
    try {
      final flights = await widget.repository.searchFlights(
          _origin.text.trim().toUpperCase(),
          _destination.text.trim().toUpperCase(),
          isoDate(_date));
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

  Widget _field(String label, String hint, TextEditingController c) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
          controller: c,
          enabled: !_busy,
          textCapitalization: TextCapitalization.characters,
          onChanged: (_) => setState(() => _flights = null),
          decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              suffixIcon: IconButton(
                  tooltip: 'Buscar aeropuerto por ciudad',
                  onPressed: _busy ? null : () => _pickAirport(c),
                  icon: const Icon(Icons.search))),
          validator: (s) {
            if (!RegExp(r'^[A-Z]{3}$')
                .hasMatch((s ?? '').trim().toUpperCase())) {
              return 'Escribe el código IATA de tres letras.';
            }
            if (c == _destination &&
                s!.trim().toUpperCase() == _origin.text.trim().toUpperCase()) {
              return 'El destino debe ser diferente del origen.';
            }
            return null;
          }));
  @override
  Widget build(BuildContext context) => AccessShell(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AccessHeader(
            eyebrow: 'VUELOS POR RUTA',
            title: 'Elige tu vuelo.',
            subtitle:
                'Indica los aeropuertos y la fecha. Elige un vuelo publicado para completar automáticamente número, ruta y fecha del viaje.'),
        if (_error != null) InlineNotice(message: _error!, error: true),
        Form(
            key: _form,
            child: Column(children: [
              _field('Origen (IATA)', 'Ej.: BOG · Bogotá', _origin),
              _field('Destino (IATA)', 'Ej.: MAD · Madrid', _destination),
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

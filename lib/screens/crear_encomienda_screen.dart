import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../auth/auth_service.dart';
import '../data/shipment_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/access_components.dart';
import '../widgets/access_shell.dart';
import '../widgets/app_components.dart';
import '../widgets/place_picker.dart';

/// Formulario del remitente: `POST /api/encomiendas`.
class CrearEncomiendaScreen extends StatefulWidget {
  const CrearEncomiendaScreen({super.key, this.today});

  /// Fecha de referencia para el calendario; se inyecta en pruebas.
  final DateTime? today;
  @override
  State<CrearEncomiendaScreen> createState() => _CrearEncomiendaScreenState();
}

class _CrearEncomiendaScreenState extends State<CrearEncomiendaScreen> {
  static const maxNotes = 300;
  static const maxValue = 100000000;
  var _form = GlobalKey<FormState>();
  final _notes = TextEditingController();
  final _value = TextEditingController();
  Place? _origin;
  Place? _destination;
  String _currency = shipmentCurrencies.first;
  DateTime? _expiresOn;
  bool _submitting = false;
  String? _error;
  Shipment? _created;
  ShipmentDraft? _sent;

  @override
  void dispose() {
    _notes.dispose();
    _value.dispose();
    super.dispose();
  }

  DateTime get _today {
    final now = widget.today ?? DateTime.now();
    return DateTime(now.year, now.month, now.day);
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

  static String? validateValue(String? text) {
    final digits = text?.trim() ?? '';
    if (digits.isEmpty) return 'Escribe el valor que ofreces al viajero.';
    final value = int.tryParse(digits);
    if (value == null) return 'Escribe solo números, sin puntos ni comas.';
    if (value <= 0) return 'El valor debe ser mayor que cero.';
    if (value > maxValue) return 'El valor no puede superar 100.000.000.';
    return null;
  }

  Future<void> _pickDate() async {
    final first = _today.add(const Duration(days: 1));
    final picked = await showDatePicker(
        context: context,
        initialDate: _expiresOn ?? first,
        firstDate: first,
        lastDate: _today.add(const Duration(days: 365)),
        helpText: 'Fecha límite de la encomienda');
    if (picked != null && mounted) setState(() => _expiresOn = picked);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final draft = ShipmentDraft(
        origin: _origin!,
        destination: _destination!,
        notes: _notes.text,
        currency: _currency,
        value: int.parse(_value.text.trim()),
        expiresOn: _expiresOn);
    setState(() => _submitting = true);
    try {
      final created = await ShipmentScope.of(context).create(draft);
      if (!mounted) return;
      setState(() {
        _created = created;
        _sent = draft;
      });
    } on AppFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'No se pudo publicar la encomienda. Inténtalo de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _reset() {
    _notes.clear();
    _value.clear();
    setState(() {
      _form = GlobalKey<FormState>();
      _origin = null;
      _destination = null;
      _currency = shipmentCurrencies.first;
      _expiresOn = null;
      _created = null;
      _sent = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) => AccessShell(
      child: _created == null ? _formView(context) : _successView(context));

  Widget _formView(BuildContext context) {
    final repository = ShipmentScope.of(context);
    final enabled = !_submitting;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const AccessHeader(
          eyebrow: 'NUEVA ENCOMIENDA',
          title: 'Publica tu\nencomienda.',
          subtitle:
              'Cuéntanos qué envías y por qué ruta. Quedará disponible para que un viajero la tome.'),
      if (_error != null)
        InlineNotice(
            title: 'No se publicó la encomienda',
            message: _error!,
            error: true),
      Form(
          key: _form,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            PlacePickerField(
                key: const ValueKey('campo-origen'),
                label: 'Origen',
                hint: 'Ciudad desde donde sale',
                icon: Icons.trip_origin_rounded,
                repository: repository,
                enabled: enabled,
                validator: (place) =>
                    place == null ? 'Elige la ciudad de origen.' : null,
                onChanged: (place) => setState(() => _origin = place)),
            PlacePickerField(
                key: const ValueKey('campo-destino'),
                label: 'Destino',
                hint: 'Ciudad a donde llega',
                icon: Icons.place_outlined,
                repository: repository,
                enabled: enabled,
                validator: _validateDestination,
                onChanged: (place) => setState(() => _destination = place)),
            const FieldLabel('¿Qué envías?'),
            Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: TextFormField(
                    key: const ValueKey('campo-observaciones'),
                    controller: _notes,
                    enabled: enabled,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: maxNotes,
                    textCapitalization: TextCapitalization.sentences,
                    validator: (text) => (text ?? '').trim().isEmpty
                        ? 'Describe qué envías y cualquier cuidado especial.'
                        : null,
                    decoration: const InputDecoration(
                        hintText:
                            'Ej.: dos libros, caja pequeña de 1 kg. No es frágil.'))),
            const FieldLabel('Valor que ofreces al viajero'),
            Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                          width: 128,
                          child: DropdownButtonFormField<String>(
                              key: const ValueKey('campo-moneda'),
                              value: _currency,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                  labelText: 'Moneda'),
                              items: [
                                for (final code in shipmentCurrencies)
                                  DropdownMenuItem(
                                      value: code, child: Text(code))
                              ],
                              onChanged: enabled
                                  ? (code) => setState(
                                      () => _currency = code ?? _currency)
                                  : null)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: TextFormField(
                              key: const ValueKey('campo-valor'),
                              controller: _value,
                              enabled: enabled,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              validator: validateValue,
                              decoration: const InputDecoration(
                                  hintText: 'Ej.: 50000',
                                  prefixIcon: Icon(Icons.payments_outlined,
                                      size: 19, color: AppColors.muted)))),
                    ])),
            const FieldLabel('Fecha límite (opcional)'),
            Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Row(children: [
                  Expanded(
                      child: OutlinedButton.icon(
                          key: const ValueKey('campo-fecha'),
                          onPressed: enabled ? _pickDate : null,
                          icon: const Icon(Icons.event_outlined),
                          label: Text(_expiresOn == null
                              ? 'Elegir fecha'
                              : formatDate(_expiresOn!)))),
                  if (_expiresOn != null)
                    IconButton(
                        tooltip: 'Quitar fecha límite',
                        onPressed: enabled
                            ? () => setState(() => _expiresOn = null)
                            : null,
                        icon: const Icon(Icons.close_rounded)),
                ])),
            PrimaryAction(
                label: 'Publicar encomienda',
                busy: _submitting,
                onPressed: enabled ? _submit : null),
          ])),
      const SizedBox(height: 16),
    ]);
  }

  Widget _successView(BuildContext context) {
    final created = _created!;
    final sent = _sent!;
    final askedDate = sent.expiresOn != null;
    String expiry;
    if (created.expiresAt != null) {
      expiry = formatDate(created.expiresAt!.toLocal());
    } else {
      expiry = askedDate
          ? 'El servidor no confirmó la fecha elegida'
          : 'Sin fecha asignada por el servidor';
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.check_circle_outline_rounded,
          size: 48, color: AppColors.teal),
      const SizedBox(height: 24),
      const AccessHeader(
          back: false,
          eyebrow: 'ENCOMIENDA PUBLICADA',
          title: 'Tu encomienda\nya está disponible.',
          subtitle:
              'Los viajeros de esta ruta podrán verla y tomarla. La seguirás en Mis encomiendas.'),
      Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _SummaryRow(
                label: 'Ruta',
                value:
                    '${created.origin.isNotEmpty ? created.origin : sent.origin.city} → ${created.destination.isNotEmpty ? created.destination : sent.destination.city}'),
            _SummaryRow(
                label: 'Envío',
                value: created.notes.isNotEmpty ? created.notes : sent.notes),
            _SummaryRow(
                label: 'Valor',
                value: formatMoney(created.value ?? sent.value,
                    created.currency.isNotEmpty ? created.currency : sent.currency)),
            _SummaryRow(label: 'Estado', value: created.status.label),
            _SummaryRow(label: 'Fecha límite', value: expiry, last: true),
          ])),
      PrimaryAction(
          label: 'Volver al menú',
          icon: Icons.home_outlined,
          onPressed: () => Navigator.of(context).maybePop()),
      const SizedBox(height: 8),
      TextButton.icon(
          onPressed: _reset,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Crear otra encomienda')),
    ]);
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(
      {required this.label, required this.value, this.last = false});
  final String label;
  final String value;
  final bool last;
  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: AppColors.muted)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
      ]));
}

String formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

/// 50000 COP → "$ 50.000 COP".
String formatMoney(num value, String currency) {
  final whole = value.round().abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buffer.write('.');
    buffer.write(whole[i]);
  }
  final sign = value < 0 ? '-' : '';
  return '$sign\$ ${buffer.toString()} $currency'.trim();
}

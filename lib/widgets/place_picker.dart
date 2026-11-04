import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../data/shipment_repository.dart';
import '../theme/app_theme.dart';
import 'app_components.dart';

/// Campo de formulario que elige país y ciudad con las listas públicas de
/// `/api/ciudades`. La API de encomiendas recibe solo la ciudad.
class PlacePickerField extends FormField<Place> {
  PlacePickerField(
      {super.key,
      required String label,
      required String hint,
      required IconData icon,
      required ShipmentRepository repository,
      super.validator,
      super.enabled,
      ValueChanged<Place>? onChanged})
      : super(builder: (state) {
          final context = state.context;
          Future<void> pick() async {
            final place = await showModalBottomSheet<Place>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                showDragHandle: true,
                backgroundColor: AppColors.paper,
                builder: (_) =>
                    PlaceSheet(title: label, repository: repository));
            if (place != null) {
              state.didChange(place);
              onChanged?.call(place);
            }
          }

          return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FieldLabel(label),
                    Semantics(
                        button: true,
                        label: [
                          label,
                          state.value?.label ?? hint,
                          if (state.errorText != null) state.errorText!,
                        ].join('. '),
                        excludeSemantics: true,
                        child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: state.widget.enabled ? pick : null,
                            child: InputDecorator(
                                isEmpty: state.value == null,
                                decoration: InputDecoration(
                                    enabled: state.widget.enabled,
                                    hintText: hint,
                                    errorText: state.errorText,
                                    prefixIcon: Icon(icon,
                                        size: 19, color: AppColors.muted),
                                    suffixIcon: const Icon(
                                        Icons.expand_more_rounded,
                                        color: AppColors.muted)),
                                child: state.value == null
                                    ? null
                                    : Text(state.value!.label,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: AppColors.ink))))),
                  ]));
        });
}

/// Hoja inferior de dos pasos: país y luego ciudad.
class PlaceSheet extends StatefulWidget {
  const PlaceSheet({super.key, required this.title, required this.repository});
  final String title;
  final ShipmentRepository repository;
  @override
  State<PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends State<PlaceSheet> {
  final _search = TextEditingController();
  String? _country;
  List<String>? _items;
  String? _error;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _load() {
    setState(() {
      _items = null;
      _error = null;
    });
    _fetch();
  }

  Future<void> _fetch() async {
    final request = ++_request;
    final country = _country;
    try {
      final items = country == null
          ? await widget.repository.countries()
          : await widget.repository.cities(country);
      if (!mounted || request != _request) return;
      setState(() => _items = items);
    } on AppFailure catch (e) {
      if (!mounted || request != _request) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() => _error = 'No se pudo cargar la lista. Inténtalo de nuevo.');
    }
  }

  void _select(String item) {
    if (_country == null) {
      _country = item;
      _search.clear();
      _load();
    } else {
      Navigator.of(context).pop(Place(country: _country!, city: item));
    }
  }

  void _backToCountries() {
    _country = null;
    _search.clear();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final query = fold(_search.text);
    final items = _items
        ?.where((item) => query.isEmpty || fold(item).contains(query))
        .toList();
    final choosingCity = _country != null;
    return Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.85,
            child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (choosingCity)
                        TextButton.icon(
                            onPressed: _backToCountries,
                            icon: const Icon(Icons.arrow_back_rounded, size: 17),
                            label: const Text('Cambiar país'),
                            style:
                                TextButton.styleFrom(padding: EdgeInsets.zero)),
                      Semantics(
                          header: true,
                          child: Text(
                              choosingCity
                                  ? '${widget.title}: ciudad en $_country'
                                  : '${widget.title}: país',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink))),
                      const SizedBox(height: 12),
                      TextField(
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                              hintText: choosingCity
                                  ? 'Buscar ciudad'
                                  : 'Buscar país',
                              prefixIcon: const Icon(Icons.search_rounded,
                                  size: 19, color: AppColors.muted))),
                      const SizedBox(height: 12),
                      Expanded(child: _list(items)),
                    ]))));
  }

  Widget _list(List<String>? items) {
    if (_error != null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InlineNotice(message: _error!, error: true),
        OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar')),
      ]);
    }
    if (items == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return const Text('No hay resultados para tu búsqueda.',
          style: TextStyle(color: AppColors.muted));
    }
    return ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) => ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: Text(items[index]),
            trailing: _country == null
                ? const Icon(Icons.chevron_right_rounded,
                    color: AppColors.muted)
                : null,
            onTap: () => _select(items[index])));
  }
}

/// Minúsculas sin tildes, para buscar "bogota" y encontrar "Bogotá".
String fold(String text) {
  const from = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const to = 'aaaaaeeeeiiiiooooouuuunc';
  final lower = text.toLowerCase().trim();
  final buffer = StringBuffer();
  for (final char in lower.split('')) {
    final index = from.indexOf(char);
    buffer.write(index < 0 ? char : to[index]);
  }
  return buffer.toString();
}

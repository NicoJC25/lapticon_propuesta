import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../data/shipment_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/access_components.dart';
import '../widgets/access_shell.dart';
import '../widgets/app_components.dart';
import '../widgets/shipment_card.dart';
import 'crear_encomienda_screen.dart';

/// Remitente: sus encomiendas agrupadas por estado (`GET /api/encomiendas`).
class MisEncomiendasScreen extends StatefulWidget {
  const MisEncomiendasScreen({super.key});
  @override
  State<MisEncomiendasScreen> createState() => _MisEncomiendasScreenState();
}

class _MisEncomiendasScreenState extends State<MisEncomiendasScreen> {
  /// Orden de las secciones: primero lo que requiere atención.
  static const sections = [
    ShipmentStatus.disponible,
    ShipmentStatus.tomada,
    ShipmentStatus.recibida,
    ShipmentStatus.vencida,
  ];
  List<Shipment>? _items;
  String? _error;
  bool _loading = true;
  ShipmentStatus? _filter;

  @override
  void initState() {
    super.initState();
    // La carga necesita el contexto completo: se lanza tras el primer frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final repository = ShipmentScope.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await repository.mine();
      if (!mounted) return;
      setState(() => _items = items);
    } on AppFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'No se pudieron cargar tus encomiendas. Inténtalo de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/encomiendas/nueva'),
        builder: (_) => const CrearEncomiendaScreen()));
    if (mounted) _load();
  }

  int _count(ShipmentStatus status) =>
      _items?.where((s) => s.status == status).length ?? 0;

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return AccessShell(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const AccessHeader(
          eyebrow: 'MIS ENCOMIENDAS',
          title: 'Sigue tus\nencomiendas.',
          subtitle:
              'Las que pasan su fecha límite se marcan como vencidas al actualizar.'),
      if (_error != null)
        InlineNotice(
            title: 'No se cargaron tus encomiendas',
            message: _error!,
            error: true),
      Row(children: [
        Expanded(
            child: OutlinedButton.icon(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Actualizar'))),
        const SizedBox(width: 12),
        Expanded(
            child: FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nueva'))),
      ]),
      const SizedBox(height: 20),
      if (items == null && _loading)
        const LoadingBlock()
      else if (items != null && items.isEmpty)
        const EmptyBlock(
            icon: Icons.inventory_2_outlined,
            message:
                'Todavía no has publicado encomiendas. Crea la primera con el botón Nueva.')
      else if (items != null) ...[
        Wrap(spacing: 8, runSpacing: 8, children: [
          ChoiceChip(
              label: Text('Todas (${items.length})'),
              selected: _filter == null,
              onSelected: (_) => setState(() => _filter = null)),
          for (final status in sections)
            ChoiceChip(
                label: Text('${status.label}s (${_count(status)})'),
                selected: _filter == status,
                onSelected: (_) => setState(() => _filter = status)),
        ]),
        const SizedBox(height: 16),
        for (final status in sections)
          if (_filter == null || _filter == status)
            _Section(
                status: status,
                items: items.where((s) => s.status == status).toList(),
                showEmpty: _filter == status),
      ],
    ]));
  }
}

class _Section extends StatelessWidget {
  const _Section(
      {required this.status, required this.items, required this.showEmpty});
  final ShipmentStatus status;
  final List<Shipment> items;
  final bool showEmpty;
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && !showEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
          padding: const EdgeInsets.only(bottom: 10, top: 4),
          child: Semantics(
              header: true,
              child: Text('${status.label}s · ${items.length}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: AppColors.muted)))),
      if (items.isEmpty)
        EmptyBlock(
            icon: Icons.inbox_outlined,
            message: 'No tienes encomiendas ${status.label.toLowerCase()}s.')
      else
        for (final shipment in items) ShipmentCard(shipment: shipment),
      const SizedBox(height: 8),
    ]);
  }
}

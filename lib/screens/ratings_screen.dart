import 'package:flutter/material.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_service.dart';
import '../data/rating_repository.dart';
import '../data/shipment_repository.dart';
import '../roles/user_role.dart';
import '../widgets/access_components.dart';
import '../widgets/access_shell.dart';
import '../widgets/app_components.dart';
import '../widgets/rating_action.dart';
import '../widgets/shipment_card.dart';

class RatingsScreen extends StatefulWidget {
  const RatingsScreen({super.key, required this.targetRole});
  final UserRole targetRole;
  @override
  State<RatingsScreen> createState() => _RatingsScreenState();
}

class _RatingsScreenState extends State<RatingsScreen> {
  List<Shipment>? _items;
  String? _error;
  bool _loading = true;
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
    if (uid == null) return;
    final shipments = ShipmentScope.of(context);
    final history = RatingScope.of(context).history;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = widget.targetRole == UserRole.viajero
          ? await shipments.mine()
          : await history.read(uid);
      final unique = <String, Shipment>{};
      for (final s in items) {
        final target = RatingTarget.forShipment(s, uid);
        if (target != null && target.role == widget.targetRole) {
          unique[target.uid] = s;
        }
      }
      if (!mounted || auth.user?.uid != uid) return;
      setState(() => _items = unique.values.toList());
    } on AppFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'No se pudieron cargar las entregas para calificar.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AccessShell(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AccessHeader(
            eyebrow: 'CALIFICACIONES',
            title: widget.targetRole == UserRole.viajero
                ? 'Calificar viajeros'
                : 'Calificar remitentes',
            subtitle:
                'Solo puedes calificar a la otra persona después de una entrega recibida.'),
        if (widget.targetRole == UserRole.remitente)
          const InlineNotice(
              message:
                  'Se muestran las entregas que marcaste desde esta cuenta en este dispositivo. Las marcadas desde otro teléfono o por el remitente no aparecen aquí.'),
        if (_error != null) InlineNotice(message: _error!, error: true),
        OutlinedButton.icon(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Actualizar')),
        const SizedBox(height: 16),
        if (_loading)
          const LoadingBlock()
        else if (_items?.isEmpty ?? false)
          const EmptyBlock(
              icon: Icons.star_outline_rounded,
              message: 'Aún no tienes entregas recibidas para calificar.')
        else
          for (final s in _items ?? <Shipment>[])
            ShipmentCard(
                key: ValueKey('rating-shipment-${s.id}'),
                shipment: s,
                action: RatingAction(shipment: s)),
      ]));
}

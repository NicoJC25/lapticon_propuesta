import 'package:flutter/material.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_service.dart';
import '../data/shipment_repository.dart';
import '../data/rating_repository.dart';
import '../data/delivered_shipment_store.dart';
import 'app_components.dart';

bool canMarkDelivered(Shipment shipment, String? uid) =>
    shipment.id.isNotEmpty &&
    uid != null &&
    uid.isNotEmpty &&
    shipment.status == ShipmentStatus.tomada &&
    (shipment.ownerId == uid || shipment.travelerId == uid);

/// No altera el estado local hasta que el servidor acepta el cambio.
class DeliveryAction extends StatefulWidget {
  const DeliveryAction(
      {super.key, required this.shipment, required this.onDelivered});
  final Shipment shipment;
  final Future<void> Function() onDelivered;
  @override
  State<DeliveryAction> createState() => _DeliveryActionState();
}

class _DeliveryActionState extends State<DeliveryAction> {
  bool _busy = false;
  bool _confirming = false;
  bool _done = false;
  String? _error;
  Future<void> _deliver() async {
    if (_busy || _confirming || _done) return;
    final auth = AuthScope.of(context);
    final repository = ShipmentScope.of(context);
    final history = RatingScope.of(context).history;
    final uid = auth.user?.uid;
    if (!canMarkDelivered(widget.shipment, uid)) return;
    setState(() {
      _confirming = true;
      _error = null;
    });
    try {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  scrollable: true,
                  title: const Text('¿Marcar la entrega?'),
                  content: Text(
                      'Confirma que el paquete de ${widget.shipment.origin} a ${widget.shipment.destination} ya fue entregado. La encomienda quedará como recibida.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Volver')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Sí, marcar entrega'))
                  ]));
      if (confirmed != true || !mounted || auth.user?.uid != uid) return;
      if (!canMarkDelivered(widget.shipment, uid)) {
        setState(() =>
            _error = 'El estado de la encomienda cambió. Actualiza la lista.');
        return;
      }
      setState(() => _busy = true);
      await repository.markDelivered(widget.shipment.id);
      if (auth.user?.uid != uid) return;
      if (mounted) setState(() => _done = true);
      var message = 'Entrega marcada como recibida.';
      try {
        await history.remember(uid!, receivedCopy(widget.shipment));
      } catch (_) {
        message =
            'Entrega registrada. No se pudo guardar el historial local para calificar desde este teléfono.';
      }
      if (!mounted || auth.user?.uid != uid) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      await widget.onDelivered();
    } on AppFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'No se pudo marcar la entrega. Actualiza la lista antes de volver a intentar.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _confirming = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!canMarkDelivered(widget.shipment, AuthScope.of(context).user?.uid)) {
      return const SizedBox.shrink();
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_error != null) InlineNotice(message: _error!, error: true),
      FilledButton.icon(
          key: ValueKey('entregar-${widget.shipment.id}'),
          onPressed: _busy || _confirming || _done ? null : _deliver,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.task_alt),
          label: Text(_busy
              ? 'Procesando entrega…'
              : _done
                  ? 'Entrega registrada'
                  : 'Marcar entrega')),
    ]);
  }
}

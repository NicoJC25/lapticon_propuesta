import 'package:flutter/material.dart';
import '../auth/auth_controller.dart';
import '../data/rating_repository.dart';
import '../data/shipment_repository.dart';
import '../screens/rating_form_screen.dart';

class RatingAction extends StatefulWidget {
  const RatingAction({super.key, required this.shipment});
  final Shipment shipment;
  @override
  State<RatingAction> createState() => _RatingActionState();
}

class _RatingActionState extends State<RatingAction> {
  bool _done = false, _opening = false;
  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final uid = auth.user?.uid;
    final target = RatingTarget.forShipment(widget.shipment, uid ?? '');
    if (target == null) return const SizedBox.shrink();
    return OutlinedButton.icon(
        key: ValueKey('calificar-${widget.shipment.id}'),
        icon: const Icon(Icons.star_outline_rounded),
        label: Text(_done
            ? 'Calificación registrada'
            : 'Calificar ${target.role.apiValue}'),
        onPressed: _done || _opening
            ? null
            : () async {
                setState(() => _opening = true);
                final result = await Navigator.of(context).push<RatingReceipt>(
                    MaterialPageRoute(
                        builder: (_) =>
                            RatingFormScreen(shipment: widget.shipment)));
                if (!context.mounted || auth.user?.uid != uid) return;
                setState(() {
                  _opening = false;
                  _done = result != null;
                });
                if (result != null) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(result.alreadyExists
                          ? 'Ya habías calificado a esta persona en ese rol.'
                          : 'Calificación registrada. ¡Gracias por compartir tu experiencia!')));
                }
              });
  }
}

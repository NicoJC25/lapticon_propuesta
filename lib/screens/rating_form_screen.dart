import 'package:flutter/material.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_service.dart';
import '../data/rating_repository.dart';
import '../data/shipment_repository.dart';
import '../widgets/access_components.dart';
import '../widgets/access_shell.dart';
import '../widgets/app_components.dart';
import '../widgets/shipment_card.dart';

class RatingFormScreen extends StatefulWidget {
  const RatingFormScreen({super.key, required this.shipment});
  final Shipment shipment;
  @override
  State<RatingFormScreen> createState() => _RatingFormScreenState();
}

class _RatingFormScreenState extends State<RatingFormScreen> {
  final _comment = TextEditingController();
  int? _score;
  bool _loading = true, _checked = false, _busy = false;
  UserRating? _existing;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _check();
    });
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final auth = AuthScope.of(context);
    final uid = auth.user?.uid;
    final target = RatingTarget.forShipment(widget.shipment, uid ?? '');
    if (target == null) {
      setState(() {
        _loading = false;
        _error = 'Esta entrega no permite una calificación con tu cuenta.';
      });
      return;
    }
    final repo = RatingScope.of(context).repository;
    setState(() {
      _loading = true;
      _error = null;
      _checked = false;
    });
    try {
      final existing = await repo.existing(uid!, target);
      if (!mounted || auth.user?.uid != uid) return;
      setState(() {
        _existing = existing;
        _checked = true;
      });
    } on AppFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'No se pudieron consultar las calificaciones. Inténtalo de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    if (_busy || !_checked || _existing != null) return;
    if (_score == null) {
      setState(() => _error = 'Selecciona de 1 a 5 estrellas.');
      return;
    }
    final auth = AuthScope.of(context);
    final user = auth.user;
    if (user == null) return;
    final repo = RatingScope.of(context).repository;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final receipt =
          await repo.rate(user, widget.shipment, _score!, _comment.text);
      if (!mounted || auth.user?.uid != user.uid) return;
      Navigator.pop(context, receipt);
    } on AppFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'No se pudo confirmar la calificación. Reintenta para consultar si quedó guardada.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = RatingTarget.forShipment(
        widget.shipment, AuthScope.of(context).user?.uid ?? '');
    final role = target?.role.apiValue ?? 'participante';
    return AccessShell(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AccessHeader(
          eyebrow: 'CALIFICACIONES',
          title: 'Tu experiencia\ncuenta.',
          subtitle:
              'Califica al $role de tu entrega ${widget.shipment.origin} → ${widget.shipment.destination}.'),
      if (_error != null) InlineNotice(message: _error!, error: true),
      if (_loading)
        const LoadingBlock()
      else if (!_checked)
        OutlinedButton(
            onPressed: _check, child: const Text('Volver a consultar'))
      else if (_existing case final previous?) ...[
        Text('Ya calificaste a este usuario como $role.',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Text('${previous.score} de 5 estrellas'),
        if (previous.comment.isNotEmpty) Text(previous.comment),
        const SizedBox(height: 16),
        FilledButton(
            onPressed: () => Navigator.pop(
                context, RatingReceipt(previous, alreadyExists: true)),
            child: const Text('Volver a las entregas')),
      ] else ...[
        const Text('¿Cómo fue tu experiencia?'),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 1; i <= 5; i++)
            ChoiceChip(
                key: ValueKey('rating-$i'),
                label: Text('$i ★',
                    semanticsLabel: '$i ${i == 1 ? 'estrella' : 'estrellas'}'),
                selected: _score == i,
                onSelected: _busy ? null : (_) => setState(() => _score = i)),
        ]),
        const SizedBox(height: 20),
        TextField(
            controller: _comment,
            enabled: !_busy,
            maxLength: 500,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
                labelText: 'Comentario (opcional)',
                hintText: 'Comparte una opinión respetuosa sobre la entrega.')),
        const SizedBox(height: 16),
        FilledButton(
            onPressed: _busy ? null : _send,
            child:
                Text(_busy ? 'Enviando calificación…' : 'Enviar calificación')),
        const SizedBox(height: 12),
        const Text(
            'Se registra una calificación por persona y rol. No podrás editarla desde esta app.'),
      ],
    ]));
  }
}

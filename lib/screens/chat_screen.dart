import 'dart:async';
import 'package:flutter/material.dart';
import '../auth/auth_controller.dart';
import '../chat/chat_controller.dart';
import '../chat/chat_repository.dart';
import '../data/shipment_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.shipment});
  final Shipment shipment;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _text = TextEditingController();
  ChatController? _chat;
  Timer? _timer;
  bool _initialized = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final conversation = ChatConversation.forShipment(
        widget.shipment, AuthScope.of(context).user?.uid ?? '');
    if (conversation == null) return;
    _chat = ChatController(ChatScope.of(context), conversation)
      ..addListener(_changed);
    // Se consulta la API, incluso con Firestore pendiente, sin leer ni escribir mensajes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _chat?.refresh();
    });
    if (_chat!.repository.configured) {
      _timer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (WidgetsBinding.instance.lifecycleState ==
            AppLifecycleState.resumed) {
          _chat?.refresh();
        }
      });
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _chat?.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _chat?.removeListener(_changed);
    _chat?.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final chat = _chat!;
    final text = _text.text;
    final sent = await chat.send(text);
    if (mounted &&
        sent &&
        AuthScope.of(context).user?.uid == chat.chat.author) {
      _text.clear();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Mensaje enviado.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _chat;
    final uid = AuthScope.of(context).user?.uid;
    if (c == null || uid != c.chat.author) {
      return Scaffold(
          appBar: AppBar(title: const Text('Chat')),
          body: const Center(
              child: Text(
                  'Esta conversación no está disponible para tu cuenta.')));
    }
    final otherRole = uid == widget.shipment.ownerId ? 'viajero' : 'remitente';
    return Scaffold(
      appBar: AppBar(
          leading: IconButton(
              tooltip: 'Volver',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back)),
          title: Text('Chat con $otherRole'),
          actions: [
            IconButton(
                tooltip: 'Actualizar estado del chat',
                onPressed: c.checking ? null : c.refresh,
                icon: const Icon(Icons.refresh))
          ]),
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(children: [
                    Flexible(
                        flex: 0,
                        child: ConstrainedBox(
                            constraints: BoxConstraints(
                                maxHeight:
                                    MediaQuery.sizeOf(context).height * .3),
                            child: SingleChildScrollView(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                          '${widget.shipment.origin} → ${widget.shipment.destination}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium),
                                      const Text(
                                          'Esta conversación reúne tus entregas con la misma persona. Se muestran los últimos 100 mensajes.'),
                                      if (!c.repository.configured)
                                        const InlineNotice(
                                            message: chatPendingMessage),
                                      if (c.checking)
                                        const Text(
                                            'Consultando estado del chat…'),
                                      if (c.status?.state == ChatState.abierto)
                                        const Text('Chat abierto'),
                                      if (c.status?.state == ChatState.cerrado)
                                        const InlineNotice(
                                            message:
                                                'Chat cerrado. Puedes consultar el historial, pero ya no enviar mensajes.'),
                                      if (c.statusError != null)
                                        InlineNotice(
                                            message: c.statusError!,
                                            error: true),
                                      if (c.messagesError != null)
                                        InlineNotice(
                                            message: c.messagesError!,
                                            error: true),
                                    ])))),
                    Expanded(
                        child: c.loadingMessages
                            ? const Center(child: CircularProgressIndicator())
                            : c.messages.isEmpty
                                ? Center(
                                    child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Text(c.repository.configured
                                            ? 'Aún no hay mensajes disponibles.'
                                            : 'El historial aparecerá cuando se conecte el chat.')))
                                : ListView.builder(
                                    reverse: true,
                                    padding: const EdgeInsets.all(16),
                                    itemCount: c.messages.length,
                                    itemBuilder: (context, i) {
                                      final m = c.messages[i];
                                      final mine = m.author == uid;
                                      final date = m.createdAt.toLocal();
                                      final when =
                                          '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                                      return Semantics(
                                          label:
                                              '${mine ? 'Tú' : otherRole}, $when',
                                          child: Align(
                                              alignment: mine
                                                  ? Alignment.centerRight
                                                  : Alignment.centerLeft,
                                              child: Container(
                                                constraints: BoxConstraints(
                                                    maxWidth: MediaQuery.sizeOf(
                                                                context)
                                                            .width *
                                                        .82),
                                                margin: const EdgeInsets.only(
                                                    bottom: 10),
                                                padding:
                                                    const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                    color: mine
                                                        ? AppColors.mint
                                                        : Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16),
                                                    border: Border.all(
                                                        color:
                                                            AppColors.border)),
                                                child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                          mine
                                                              ? 'Tú'
                                                              : otherRole,
                                                          style: const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700)),
                                                      SelectableText(m.text),
                                                      const SizedBox(height: 4),
                                                      Text(when,
                                                          style:
                                                              const TextStyle(
                                                                  fontSize: 12))
                                                    ]),
                                              )));
                                    })),
                    ConstrainedBox(
                        constraints: BoxConstraints(
                            maxHeight: MediaQuery.sizeOf(context).height * .3),
                        child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (c.sendError != null)
                                    Text(c.sendError!,
                                        style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error)),
                                  TextField(
                                      key: const ValueKey('chat-message'),
                                      controller: _text,
                                      enabled: c.canSend,
                                      minLines: 1,
                                      maxLines: 3,
                                      maxLength: 1000,
                                      textCapitalization:
                                          TextCapitalization.sentences,
                                      decoration: const InputDecoration(
                                          labelText: 'Mensaje',
                                          hintText:
                                              'Coordina los detalles de la entrega')),
                                  FilledButton.icon(
                                      onPressed: c.canSend ? _send : null,
                                      icon: const Icon(Icons.send_outlined),
                                      label: Text(c.sending
                                          ? 'Enviando…'
                                          : 'Enviar mensaje')),
                                ]))),
                  ])))),
    );
  }
}

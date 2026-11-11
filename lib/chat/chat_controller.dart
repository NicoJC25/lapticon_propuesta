import 'dart:async';
import 'package:flutter/foundation.dart';
import '../auth/auth_service.dart';
import 'chat_repository.dart';

class ChatController extends ChangeNotifier {
  ChatController(this.repository, this.chat);
  final ChatRepository repository;
  final ChatConversation chat;
  List<ChatMessage> messages = [];
  ChatStatus? status;
  String? statusError, messagesError, sendError;
  bool checking = false, sending = false, loadingMessages = false;
  bool _disposed = false, _started = false;
  StreamSubscription<List<ChatMessage>>? _subscription;
  String? _attemptText, _attemptId;
  bool get canSend =>
      repository.configured &&
      !checking &&
      !sending &&
      !loadingMessages &&
      statusError == null &&
      messagesError == null &&
      status?.state == ChatState.abierto;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() async {
    if (_disposed || checking) return;
    checking = true;
    statusError = null;
    _notify();
    try {
      final next = await repository.status(chat);
      if (_disposed) return;
      status = next;
      if (repository.configured && (!_started || messagesError != null)) {
        _listen();
      }
    } on AppFailure catch (e) {
      if (!_disposed) {
        status = null;
        statusError = e.message;
        if ({'forbidden', 'session-expired', 'session-changed'}
            .contains(e.code)) {
          _subscription?.cancel();
          _subscription = null;
          _started = false;
          loadingMessages = false;
          messages = [];
        }
      }
    } catch (_) {
      if (!_disposed) {
        status = null;
        statusError =
            'No se pudo consultar el estado del chat. Actualiza para reintentar.';
      }
    } finally {
      if (!_disposed) {
        checking = false;
        _notify();
      }
    }
  }

  void _listen() {
    _subscription?.cancel();
    _started = true;
    loadingMessages = true;
    messagesError = null;
    _subscription = repository.watch(chat).listen((items) {
      if (_disposed) return;
      messages = List.unmodifiable(items);
      loadingMessages = false;
      messagesError = null;
      _notify();
    }, onError: (Object e) {
      if (_disposed) return;
      loadingMessages = false;
      messagesError = e is AppFailure
          ? e.message
          : 'No se pudieron cargar los mensajes. Actualiza para reintentar.';
      _notify();
    }, onDone: () {
      if (_disposed) return;
      loadingMessages = false;
      messagesError =
          'Se interrumpió la conexión del chat. Actualiza para volver a escuchar los mensajes.';
      _notify();
    });
  }

  Future<bool> send(String text) async {
    if (_disposed || !canSend) return false;
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.length > 1000) {
      sendError = 'Escribe un mensaje de 1 a 1000 caracteres.';
      _notify();
      return false;
    }
    if (_attemptText != trimmed) {
      _attemptText = trimmed;
      _attemptId = newChatMessageId();
    }
    sending = true;
    sendError = null;
    _notify();
    try {
      await repository.send(chat, _attemptId!, trimmed);
      if (_disposed) return false;
      _attemptId = null;
      _attemptText = null;
      return true;
    } on AppFailure catch (e) {
      if (!_disposed) {
        sendError = e.message;
        if (e.code == 'chat-closed') {
          status = const ChatStatus(ChatState.cerrado);
        }
        if ({
          'session-changed',
          'session-expired',
          'forbidden',
          'chat-not-found'
        }.contains(e.code)) {
          status = null;
        }
      }
    } catch (_) {
      if (!_disposed) {
        sendError =
            'No se confirmó el envío. Tu mensaje se conserva para reintentar.';
      }
    } finally {
      if (!_disposed) {
        sending = false;
        _notify();
      }
    }
    return false;
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    messages = [];
    _attemptText = null;
    super.dispose();
  }
}

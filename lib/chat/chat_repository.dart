import 'dart:convert';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import '../auth/auth_service.dart';
import '../data/api_client.dart';
import '../data/shipment_repository.dart';

const chatPendingMessage =
    'Conexión del chat pendiente. Podrás conversar cuando se complete la configuración.';

class ChatConversation {
  const ChatConversation._(this.id, this.author, this.other);
  final String id, author, other;
  List<String> get participants => [author, other]..sort();
  static ChatConversation? forShipment(Shipment s, String uid) {
    if (s.id.isEmpty ||
        !{ShipmentStatus.tomada, ShipmentStatus.recibida}.contains(s.status) ||
        uid.isEmpty ||
        s.ownerId.isEmpty ||
        s.travelerId.isEmpty ||
        s.ownerId == s.travelerId ||
        s.ownerId.contains('/') ||
        s.travelerId.contains('/')) {
      return null;
    }
    if (uid != s.ownerId && uid != s.travelerId) return null;
    final ids = [s.ownerId, s.travelerId]..sort();
    return ChatConversation._(
        ids.join('_'), uid, uid == s.ownerId ? s.travelerId : s.ownerId);
  }
}

enum ChatState { abierto, cerrado }

class ChatStatus {
  const ChatStatus(this.state, {this.closedAt});
  final ChatState state;
  final DateTime? closedAt;
  factory ChatStatus.fromJson(Object? json) {
    if (json is! Map || !{'abierto', 'cerrado'}.contains(json['estado'])) {
      throw const AppFailure('No se pudo confirmar si el chat está abierto.',
          code: 'invalid-response');
    }
    final date = json['fechaCierre'];
    if (date != null && (date is! String || DateTime.tryParse(date) == null)) {
      throw const AppFailure('La fecha de cierre del chat no es válida.',
          code: 'invalid-response');
    }
    return ChatStatus(
        json['estado'] == 'abierto' ? ChatState.abierto : ChatState.cerrado,
        closedAt: date is String ? DateTime.parse(date) : null);
  }
}

class ChatMessage {
  const ChatMessage(
      {required this.id,
      required this.author,
      required this.text,
      required this.createdAt});
  final String id, author, text;
  final DateTime createdAt;
}

abstract class ChatTransport {
  bool get configured;
  Stream<List<ChatMessage>> watch(ChatConversation chat);
  Future<void> send(ChatConversation chat, String id, String text);
}

class PendingChatTransport implements ChatTransport {
  const PendingChatTransport();
  @override
  bool get configured => false;
  @override
  Stream<List<ChatMessage>> watch(ChatConversation chat) =>
      Stream.error(const AppFailure(chatPendingMessage, code: 'chat-pending'));
  @override
  Future<void> send(ChatConversation chat, String id, String text) async =>
      throw const AppFailure(chatPendingMessage, code: 'chat-pending');
}

abstract class ChatRepository {
  bool get configured;
  Future<ChatStatus> status(ChatConversation chat);
  Stream<List<ChatMessage>> watch(ChatConversation chat);
  Future<void> send(ChatConversation chat, String id, String text);
  void close();
}

String newChatMessageId() {
  final random = Random.secure();
  return base64UrlEncode(List.generate(24, (_) => random.nextInt(256)))
      .replaceAll('=', '');
}

class ApiChatRepository implements ChatRepository {
  ApiChatRepository(this.auth,
      {this.transport = const PendingChatTransport(),
      http.Client? client,
      String baseUrl = defaultApiBaseUrl})
      : _api = ApiClient(auth, client: client, baseUrl: baseUrl);
  final AuthService auth;
  final ChatTransport transport;
  final ApiClient _api;
  @override
  bool get configured => transport.configured;
  Future<void> _session(ChatConversation chat) async {
    if ((await auth.authChanges.first)?.uid != chat.author) {
      throw const AppFailure('La sesión cambió. Abre de nuevo la conversación.',
          code: 'session-changed');
    }
  }

  @override
  Future<ChatStatus> status(ChatConversation chat) async {
    await _session(chat);
    final response = await _api.send(
        'GET', '/api/chats/estado/${Uri.encodeComponent(chat.id)}',
        allowNotFound: true,
        forbiddenMessage: 'No tienes permiso para abrir esta conversación.');
    if (response.statusCode == 404) {
      throw const AppFailure(
          'El chat todavía no está disponible. No se ha confirmado su apertura.',
          code: 'chat-not-found');
    }
    return ChatStatus.fromJson(
        _api.decode(response, 'No se pudo interpretar el estado del chat.'));
  }

  @override
  Stream<List<ChatMessage>> watch(ChatConversation chat) async* {
    if (!configured) {
      throw const AppFailure(chatPendingMessage, code: 'chat-pending');
    }
    await _session(chat);
    yield* transport.watch(chat);
  }

  @override
  Future<void> send(ChatConversation chat, String id, String text) async {
    if (!configured) {
      throw const AppFailure(chatPendingMessage, code: 'chat-pending');
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty ||
        trimmed.length > 1000 ||
        !RegExp(r'^[A-Za-z0-9_-]{16,128}$').hasMatch(id)) {
      throw const AppFailure('Escribe un mensaje de 1 a 1000 caracteres.',
          code: 'validation');
    }
    if ((await status(chat)).state != ChatState.abierto) {
      throw const AppFailure(
          'El chat está cerrado. Puedes consultar los mensajes, pero ya no enviar.',
          code: 'chat-closed');
    }
    await _session(chat);
    await transport.send(chat, id, trimmed);
  }

  @override
  void close() => _api.close();
}

class ChatScope extends InheritedWidget {
  const ChatScope({super.key, required this.repository, required super.child});
  final ChatRepository repository;
  static ChatRepository of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ChatScope>()!.repository;
  @override
  bool updateShouldNotify(ChatScope oldWidget) =>
      repository != oldWidget.repository;
}

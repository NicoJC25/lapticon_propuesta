import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../auth/auth_service.dart';
import 'chat_repository.dart';

/// PROPUESTA aislada: confirmar estos campos con el profesor ANTES de activarla.
class ChatSchema {
  static const chats = 'chats';
  static const messages = 'mensajes';
  static const participants = 'participantes';
  static const state = 'estado';
  static const author = 'autorId';
  static const text = 'texto';
  static const created = 'fechaCreacion';
}

ChatTransport configuredChatTransport() {
  if (!const bool.fromEnvironment('CHAT_FIRESTORE_ENABLED') ||
      Firebase.apps.isEmpty) {
    return const PendingChatTransport();
  }
  // Sin caché persistente de mensajes compartida entre cuentas del dispositivo.
  final firestore = FirebaseFirestore.instance;
  firestore.settings = const Settings(persistenceEnabled: false);
  return FirestoreChatTransport(
      firestore, () => FirebaseAuth.instance.currentUser?.uid);
}

class FirestoreChatTransport implements ChatTransport {
  FirestoreChatTransport(this.firestore, this.currentUid);
  final FirebaseFirestore firestore;
  final String? Function() currentUid;
  @override
  bool get configured => true;
  DocumentReference<Map<String, dynamic>> _parent(ChatConversation c) =>
      firestore.collection(ChatSchema.chats).doc(c.id);
  void _session(ChatConversation c) {
    if (currentUid() != c.author) {
      throw const AppFailure('Inicia sesión de nuevo para abrir el chat.',
          code: 'session-changed');
    }
  }

  void _validateParent(Map<String, dynamic>? data, ChatConversation c) {
    final members = data?[ChatSchema.participants];
    if (data == null) {
      throw const AppFailure('El chat aún no fue creado por el servicio.',
          code: 'chat-not-found');
    }
    if (members is! List ||
        members.length != 2 ||
        !c.participants.every(members.contains)) {
      throw const AppFailure(
          'No se pudieron confirmar los participantes del chat.',
          code: 'forbidden');
    }
    if (data[ChatSchema.state] != 'abierto') {
      throw const AppFailure(
          'El chat está cerrado o su estado no está confirmado.',
          code: 'chat-closed');
    }
  }

  @override
  Stream<List<ChatMessage>> watch(ChatConversation chat) async* {
    _session(chat);
    try {
      yield* _parent(chat)
          .collection(ChatSchema.messages)
          .orderBy(ChatSchema.created, descending: true)
          .limit(100)
          .snapshots(includeMetadataChanges: true)
          .map((snapshot) {
        _session(chat);
        final items = <ChatMessage>[];
        for (final doc in snapshot.docs) {
          // No presentar escrituras locales todavía no confirmadas como enviadas.
          if (doc.metadata.hasPendingWrites) continue;
          final data = doc.data();
          final author = data[ChatSchema.author],
              text = data[ChatSchema.text],
              date = data[ChatSchema.created];
          if (author is! String ||
              !chat.participants.contains(author) ||
              text is! String ||
              text.trim().isEmpty ||
              text.length > 1000 ||
              date is! Timestamp) {
            throw const AppFailure(
                'Los mensajes no coinciden con el formato configurado.',
                code: 'invalid-response');
          }
          items.add(ChatMessage(
              id: doc.id,
              author: author,
              text: text,
              createdAt: date.toDate()));
        }
        return items;
      });
    } on FirebaseException catch (e) {
      throw _failure(e);
    }
  }

  @override
  Future<void> send(ChatConversation chat, String id, String text) async {
    _session(chat);
    final parent = _parent(chat);
    final message = parent.collection(ChatSchema.messages).doc(id);
    try {
      await firestore.runTransaction((transaction) async {
        _session(chat);
        final room = await transaction.get(parent);
        final previous = await transaction.get(message);
        // Reintentar una respuesta perdida confirma el mismo documento sin duplicarlo.
        if (previous.exists) {
          if (previous.data()?[ChatSchema.author] != chat.author ||
              previous.data()?[ChatSchema.text] != text) {
            throw const AppFailure(
                'El identificador del mensaje ya está en uso.',
                code: 'message-conflict');
          }
          return;
        }
        _validateParent(room.data(), chat);
        _session(chat);
        transaction.set(message, {
          ChatSchema.author: chat.author,
          ChatSchema.text: text,
          ChatSchema.created: FieldValue.serverTimestamp()
        });
        // El cliente nunca crea, reabre ni modifica el documento padre.
      }).timeout(const Duration(seconds: 20));
    } on FirebaseException catch (e) {
      throw _failure(e);
    }
  }

  AppFailure _failure(FirebaseException e) => switch (e.code) {
        'permission-denied' => const AppFailure(
            'No tienes permiso para leer o enviar mensajes en este chat.',
            code: 'forbidden'),
        'unauthenticated' => const AppFailure(
            'Inicia sesión de nuevo para usar el chat.',
            code: 'session-expired'),
        'unavailable' => const AppFailure(
            'No hay conexión con el chat. Tu mensaje se conserva para reintentar.',
            code: 'network'),
        'failed-precondition' => const AppFailure(
            'El chat necesita completar su configuración. Consulta la guía de conexión.',
            code: 'configuration'),
        _ => const AppFailure(
            'No se pudo confirmar la operación del chat. Puedes reintentar.',
            code: 'chat-error'),
      };
}

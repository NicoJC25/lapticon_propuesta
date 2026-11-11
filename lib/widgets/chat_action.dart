import 'package:flutter/material.dart';
import '../auth/auth_controller.dart';
import '../chat/chat_repository.dart';
import '../data/shipment_repository.dart';
import '../screens/chat_screen.dart';

class ChatAction extends StatelessWidget {
  const ChatAction({super.key, required this.shipment});
  final Shipment shipment;
  @override
  Widget build(BuildContext context) {
    if (ChatConversation.forShipment(
            shipment, AuthScope.of(context).user?.uid ?? '') ==
        null) {
      return const SizedBox.shrink();
    }
    return OutlinedButton.icon(
        key: ValueKey('chat-${shipment.id}'),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => ChatScreen(shipment: shipment))),
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text('Abrir chat'));
  }
}

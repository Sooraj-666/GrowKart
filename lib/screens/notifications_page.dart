import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('userId', isEqualTo: currentUserId)
            .snapshots(),
        builder: (context, orderSnap) {
          if (orderSnap.connectionState != ConnectionState.active) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = orderSnap.data?.docs ?? [];
          if (orders.isEmpty) {
            return const Center(child: Text('No chats yet.'));
          }
          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final chatId = order.id;
              return StreamBuilder<int>(
                stream: ChatService.getUnreadCount(chatId, currentUserId),
                builder: (context, snap2) {
                  final unread = snap2.data ?? 0;
                  if (unread == 0) return const SizedBox.shrink();
                  final farmerId = order['farmerId'] as String? ?? '';
                  return ListTile(
                    leading: const Icon(Icons.chat_bubble),
                    title: Text('Message with $farmerId'),
                    subtitle: Text('$unread unread message(s)'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(chatId: chatId),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

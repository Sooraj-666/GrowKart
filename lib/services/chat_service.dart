import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  static Stream<QuerySnapshot> getChatStream(String chatId) {
    return FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  static Future<void> sendMessage(
    String chatId,
    String senderId,
    String text,
  ) {
    return FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add({
      'senderId': senderId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  // Stream of unread message count for this chat
  static Stream<int> getUnreadCount(String chatId, String currentUserId) {
    return FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('senderId', isNotEqualTo: currentUserId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  // Mark messages as read when opening chat
  static Future<void> markAsRead(String chatId, String currentUserId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('senderId', isNotEqualTo: currentUserId)
        .where('isRead', isEqualTo: false)
        .get();
    for (var doc in snapshot.docs) {
      await doc.reference.update({'isRead': true});
    }
  }

  // Total unread messages across all chats for current user
  static Stream<int> getTotalUnread(String currentUserId) {
    return FirebaseFirestore.instance
      .collectionGroup('messages')
      .where('senderId', isNotEqualTo: currentUserId)
      .where('isRead', isEqualTo: false)
      .snapshots()
      .map((snap) => snap.docs.length);
  }

  /// Ensure chat room exists by creating its document if missing
  static Future<void> createChatRoom(String chatId) async {
    final docRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
    final snapshot = await docRef.get();
    if (!snapshot.exists) {
      await docRef.set({'createdAt': FieldValue.serverTimestamp()});
    }
  }
}

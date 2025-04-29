import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/chat_service.dart';
import 'dart:developer' as dev;
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  const ChatScreen({super.key, required this.chatId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
  String? peerName;
  String? peerAvatarUrl;
  bool _loadingPeer = true;

  @override
  void initState() {
    super.initState();
    _loadPeer();
    dev.log('ChatScreen init for chatId=${widget.chatId}');
    // Ensure chat room exists and clear unread messages
    ChatService.createChatRoom(widget.chatId)
      .then((_) => dev.log('createChatRoom success'))
      .catchError((e) => dev.log('createChatRoom error: $e'));
    if (currentUserId != null) {
      ChatService.markAsRead(widget.chatId, currentUserId!)
        .then((_) => dev.log('markAsRead success'))
        .catchError((e) => dev.log('markAsRead error: $e'));
    }
  }

  // Pick a file and send as attachment
  Future<void> _pickAndSendFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.bytes != null) {
      final file = result.files.single;
      try {
        final url = await ChatService.uploadAttachment(widget.chatId, file);
        if (currentUserId != null) ChatService.sendMessage(widget.chatId, currentUserId!, url);
      } catch (e) {
        dev.log('uploadAttachment error: $e');
      }
    }
  }
  // Send text message
  void _sendTextMessage() {
    final text = _textController.text.trim();
    if (text.isNotEmpty && currentUserId != null) {
      ChatService.sendMessage(widget.chatId, currentUserId!, text);
      _textController.clear();
    }
  }

  /// Show message options (reactions & delete)
  void _showMessageOptions(String messageId, bool isMe) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['❤️','👍','😂','👏'].map((emoji) => GestureDetector(
                onTap: () {
                  ChatService.addReaction(widget.chatId, messageId, emoji);
                  Navigator.pop(context);
                },
                child: Text(emoji, style: TextStyle(fontSize: 30)),
              )).toList(),
            ),
          ),
          if (isMe)
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete message', style: TextStyle(color: Colors.red)),
              onTap: () {
                ChatService.deleteMessage(widget.chatId, messageId);
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }

  Future<void> _loadPeer() async {
    try {
      // Find order record to get participant IDs
      final orderSnap = await FirebaseFirestore.instance
          .collectionGroup('orders')
          .where(FieldPath.documentId, isEqualTo: widget.chatId)
          .limit(1)
          .get();
      if (orderSnap.docs.isEmpty) return;
      final data = orderSnap.docs[0].data();
      final userId = data['userId'] as String?;
      final farmerId = data['farmerId'] as String?;
      if (userId == null || farmerId == null) return;
      final peerId = currentUserId == userId ? farmerId : userId;
      final coll = peerId == userId ? 'users' : 'farmers';
      final peerDoc = await FirebaseFirestore.instance.collection(coll).doc(peerId).get();
      final peerData = peerDoc.data();
      setState(() {
        peerName = peerData?['name'] ?? peerData?['farmName'] ?? 'Unknown';
        peerAvatarUrl = peerData?['profileImageUrl'];
        _loadingPeer = false;
      });
    } catch (e) {
      dev.log('Error loading peer: $e');
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.blue.shade400, Colors.purple.shade400]),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: _loadingPeer
                ? const Text('Chat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: peerAvatarUrl != null ? NetworkImage(peerAvatarUrl!) : null,
                      child: peerAvatarUrl == null ? const Icon(Icons.person) : null,
                    ),
                    const SizedBox(width: 8),
                    Text(peerName ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ]),
            centerTitle: true,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.blue.shade50, Colors.blue.shade100]),
        ),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: ChatService.getChatStream(widget.chatId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    dev.log('StreamBuilder error: ${snapshot.error}');
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data?.docs ?? [];
                  return ListView.builder(
                    reverse: true,
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String,dynamic>;
                      final messageId = doc.id;
                      final bool isMe = data['senderId']==currentUserId;
                      final String? imageUrl = data['text']!=null && (data['text'] as String).startsWith('http') ? data['text'] as String : null;
                      final String text = imageUrl==null ? (data['text']??'') : '';
                      final String? reaction = data['reaction'] as String?;
                      final Timestamp? ts = data['timestamp'] as Timestamp?;
                      final String formattedTime = ts!=null ? DateFormat('hh:mm a').format(ts.toDate()) : '';
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal:10,vertical:5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                          children: [
                            if(!isMe) const CircleAvatar(child: Icon(Icons.person)),
                            const SizedBox(width:5),
                            Flexible(
                              child: GestureDetector(
                                onLongPress: ()=>_showMessageOptions(messageId, isMe),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isMe? [Colors.green.shade300, Colors.green.shade200] : [Colors.grey.shade200, Colors.grey.shade100],
                                    ),
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(isMe?16:0),
                                      topRight: Radius.circular(isMe?0:16),
                                      bottomLeft: const Radius.circular(16),
                                      bottomRight: const Radius.circular(16),
                                    ),
                                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if(imageUrl!=null) Padding(
                                        padding: const EdgeInsets.only(bottom:8),
                                        child: Image.network(imageUrl,width:150),
                                      ),
                                      if(text.isNotEmpty) Text(text),
                                      const SizedBox(height:4),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(formattedTime,style:TextStyle(fontSize:10,color:Colors.grey[600])),
                                          if(isMe)...[
                                            const SizedBox(width:4),
                                            Icon(data['isRead']==true?Icons.done_all:Icons.done,size:14,color:data['isRead']==true?Colors.blue:Colors.grey),
                                          ],
                                          if(reaction!=null)...[
                                            const SizedBox(width:4),
                                            Text(reaction,style:const TextStyle(fontSize:16)),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if(isMe) const SizedBox(width:5),
                            if(isMe) const CircleAvatar(child: Icon(Icons.person)),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.attach_file),
                      onPressed: _pickAndSendFile,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        decoration: const InputDecoration(
                          hintText: 'Enter message...',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _sendTextMessage,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

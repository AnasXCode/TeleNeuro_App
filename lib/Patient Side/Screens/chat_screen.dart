import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../services/chat_service.dart';
import '../../services/doctor_availability_service.dart';

// ====================================================
// PART 1: PATIENT MESSAGES LIST
// ====================================================

class PatientChatScreen extends StatelessWidget {
  const PatientChatScreen({super.key});

  void _deleteChat(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat?'),
        content: const Text('This will hide this chat from YOUR history only.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseFirestore.instance
                  .collection('appointments')
                  .doc(docId)
                  .update({'patientDeleted': true});
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatListTime(dynamic ts) {
    if (ts is! Timestamp) return '';
    return DateFormat('MMM d, h:mm a').format(ts.toDate());
  }

  @override
  Widget build(BuildContext context) {
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('My Doctors'),
        backgroundColor: const Color(0xFF1565C0),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<Set<String>>(
        stream: DoctorAvailabilityService.activeDoctorIdsStream(),
        builder: (context, doctorsSnap) {
          final activeDoctorIds = doctorsSnap.data ?? {};

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('appointments')
                .where('patientId', isEqualTo: currentUserId)
                .where('status', whereIn: ['Accepted', 'Completed'])
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                    child: Text('No active chats.',
                        style: TextStyle(color: Colors.grey)));
              }

              var visibleDocs = snapshot.data!.docs.where((doc) {
                var data = doc.data() as Map<String, dynamic>;
                if (data['patientDeleted'] == true) return false;
                return DoctorAvailabilityService.appointmentHasActiveDoctor(
                    data, activeDoctorIds);
              }).toList();

          visibleDocs.sort((a, b) {
            final ta = (a.data() as Map)['lastMessageTime'];
            final tb = (b.data() as Map)['lastMessageTime'];
            if (ta is! Timestamp) return 1;
            if (tb is! Timestamp) return -1;
            return tb.compareTo(ta);
          });

          if (visibleDocs.isEmpty) {
            return const Center(
                child: Text('No active chats.',
                    style: TextStyle(color: Colors.grey)));
          }

              final removedCount =
                  snapshot.data!.docs.length - visibleDocs.length;

              return Column(
                children: [
                  if (removedCount > 0)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.orange.shade800, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$removedCount chat(s) hidden because the doctor account is no longer available.',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.orange.shade900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                itemCount: visibleDocs.length,
                itemBuilder: (context, index) {
                  var data = visibleDocs[index].data() as Map<String, dynamic>;
                  String docId = visibleDocs[index].id;
                  String status = data['status'];
                  bool isCompleted = status == 'Completed';
                  final unread = ChatService.unreadForUser(data, currentUserId ?? '');
                  final lastMsg = (data['lastMessage'] ?? 'Tap to chat').toString();
                  final lastTime = _formatListTime(data['lastMessageTime']);
                  final doctorLabel = DoctorAvailabilityService.doctorDisplayName(
                      data, activeDoctorIds);

                  return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        backgroundColor: isCompleted
                            ? Colors.grey[300]
                            : const Color(0xFFE3F2FD),
                        child: Icon(Icons.medical_services,
                            color: isCompleted
                                ? Colors.grey
                                : const Color(0xFF1565C0)),
                      ),
                      if (unread > 0)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              unread > 9 ? '9+' : '$unread',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Text('Dr. $doctorLabel',
                      style: TextStyle(
                          fontWeight:
                              unread > 0 ? FontWeight.bold : FontWeight.w500,
                          color:
                              isCompleted ? Colors.grey : Colors.black)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lastMsg,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: unread > 0 ? Colors.black87 : Colors.grey,
                          fontWeight:
                              unread > 0 ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      if (lastTime.isNotEmpty)
                        Text(lastTime,
                            style: const TextStyle(fontSize: 11)),
                      Text(
                        isCompleted ? 'Consultation Ended' : 'Active',
                        style: TextStyle(
                            color: isCompleted ? Colors.red : Colors.green,
                            fontSize: 11),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chat_bubble, color: Colors.blue),
                        onPressed: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                        receiverId: data['doctorId'],
                                        receiverName: 'Dr. $doctorLabel',
                                        appointmentId: docId,
                                      )));
                        },
                      ),
                      if (isCompleted)
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.grey),
                          onPressed: () => _deleteChat(context, docId),
                        ),
                    ],
                  ),
                ),
              );
                },
              ),
            ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ====================================================
// PART 2: CHAT ROOM
// ====================================================

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String appointmentId;

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
    required this.appointmentId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isDoctor = false;

  @override
  void initState() {
    super.initState();
    _initUnreadClear();
  }

  Future<void> _initUnreadClear() async {
    final apt = await FirebaseFirestore.instance
        .collection('appointments')
        .doc(widget.appointmentId)
        .get();
    if (!apt.exists) return;
    final data = apt.data()!;
    final uid = _auth.currentUser?.uid ?? '';
    _isDoctor = data['doctorId'] == uid;
    await ChatService.clearUnread(
      appointmentId: widget.appointmentId,
      isDoctor: _isDoctor,
    );
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    return DateFormat('h:mm a').format(timestamp.toDate());
  }

  void _markMessageAsRead(DocumentSnapshot doc) {
    if (doc['senderId'] != _auth.currentUser!.uid &&
        !(doc['isRead'] ?? false)) {
      FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(widget.appointmentId)
          .collection('messages')
          .doc(doc.id)
          .update({'isRead': true});
    }
  }

  void sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    if (widget.appointmentId.isEmpty) return;

    final msg = _messageController.text.trim();
    _messageController.clear();

    await ChatService.sendTextMessage(
      appointmentId: widget.appointmentId,
      receiverId: widget.receiverId,
      message: msg,
      receiverName: widget.receiverName,
    );
  }

  Widget _messageBubble(Map<String, dynamic> data, bool isMe, DocumentSnapshot doc) {
    final type = (data['messageType'] ?? 'text').toString();
    final isReport = type == 'report';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe
              ? const Color(0xFF1565C0)
              : isReport
                  ? const Color(0xFFE8F5E9)
                  : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
          border: isReport
              ? Border.all(color: Colors.green.shade300)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isReport) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.description,
                      size: 18,
                      color: isMe ? Colors.white70 : Colors.green.shade700),
                  const SizedBox(width: 6),
                  Text('Medical Report',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isMe ? Colors.white70 : Colors.green.shade800)),
                ],
              ),
              const SizedBox(height: 6),
            ],
            Text(
              data['message'] ?? '',
              style: TextStyle(
                  color: isMe
                      ? Colors.white
                      : isReport
                          ? Colors.black87
                          : Colors.black),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(data['time']),
                  style: TextStyle(
                      fontSize: 10,
                      color: isMe ? Colors.white70 : Colors.black54),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all,
                    size: 15,
                    color: (data['isRead'] ?? false)
                        ? Colors.lightBlueAccent
                        : Colors.white60,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String currentUserId = _auth.currentUser?.uid ?? '';

    if (widget.appointmentId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
            title: Text(widget.receiverName),
            backgroundColor: const Color(0xFF1565C0)),
        body: const Center(
            child: Text('Start a new appointment to chat.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.receiverName,
                style: const TextStyle(fontSize: 16)),
            const Text('Secure consultation',
                style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        backgroundColor: const Color(0xFF1565C0),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chat_rooms')
                  .doc(widget.appointmentId)
                  .collection('messages')
                  .orderBy('time', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Say Hello! 👋'));
                }
                return ListView.builder(
                  reverse: true,
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    bool isMe = data['senderId'] == currentUserId;
                    _markMessageAsRead(doc);
                    return _messageBubble(data, isMe, doc);
                  },
                );
              },
            ),
          ),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('appointments')
                .doc(widget.appointmentId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              var data = snapshot.data!.data() as Map<String, dynamic>?;
              String status = data?['status'] ?? 'Completed';
              String doctorId = data?['doctorId'] ?? '';
              bool isDoctor = (currentUserId == doctorId);

              if (status == 'Completed') {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  color: Colors.red.withOpacity(0.1),
                  child: Text(
                    isDoctor
                        ? 'This session is marked as Completed.'
                        : 'Consultation Ended. Book a new appointment to chat.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24)),
                        ),
                        onSubmitted: (_) => sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 4),
                    CircleAvatar(
                      backgroundColor: const Color(0xFF1565C0),
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: sendMessage,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

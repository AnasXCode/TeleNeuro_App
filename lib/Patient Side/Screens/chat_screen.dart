import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../Doctor Side/Screens/patient_profile_view_screen.dart';
import '../../services/chat_service.dart';
import '../../services/doctor_availability_service.dart';
import 'doctor_profile_screen.dart';

const Color _chatPrimary = Color(0xFF1565C0);
const Color _chatBg = Color(0xFFF0F4F8);
const Color _bubbleMine = Color(0xFF1565C0);
const Color _bubbleOther = Color(0xFFFFFFFF);

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
      backgroundColor: _chatBg,
      appBar: AppBar(
        title: const Text('My Doctors'),
        backgroundColor: _chatPrimary,
        foregroundColor: Colors.white,
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

                  void openChat() {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          receiverId: data['doctorId'],
                          receiverName: 'Dr. $doctorLabel',
                          appointmentId: docId,
                          isDoctorViewer: false,
                        ),
                      ),
                    );
                  }

                  void openDoctorProfile() {
                    final doctorId = (data['doctorId'] ?? '').toString();
                    if (doctorId.isEmpty) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DoctorProfilePage(doctorId: doctorId),
                      ),
                    );
                  }

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: openChat,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: openDoctorProfile,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    CircleAvatar(
                                      radius: 26,
                                      backgroundColor: isCompleted
                                          ? Colors.grey[300]
                                          : const Color(0xFFE3F2FD),
                                      child: Icon(Icons.medical_services,
                                          color: isCompleted
                                              ? Colors.grey
                                              : _chatPrimary),
                                    ),
                                    if (unread > 0)
                                      Positioned(
                                        right: -2,
                                        top: -2,
                                        child: Container(
                                          padding: const EdgeInsets.all(5),
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          constraints: const BoxConstraints(
                                              minWidth: 18, minHeight: 18),
                                          child: Text(
                                            unread > 9 ? '9+' : '$unread',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: openDoctorProfile,
                                  behavior: HitTestBehavior.opaque,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text('Dr. $doctorLabel',
                                                style: TextStyle(
                                                  fontWeight: unread > 0
                                                      ? FontWeight.bold
                                                      : FontWeight.w600,
                                                  fontSize: 15,
                                                  color: isCompleted
                                                      ? Colors.grey
                                                      : Colors.black87,
                                                )),
                                          ),
                                          if (lastTime.isNotEmpty)
                                            Text(lastTime,
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade600)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        lastMsg,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: unread > 0
                                              ? Colors.black87
                                              : Colors.grey.shade600,
                                          fontWeight: unread > 0
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: (isCompleted
                                                  ? Colors.red
                                                  : Colors.green)
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          isCompleted
                                              ? 'Consultation Ended'
                                              : 'Active',
                                          style: TextStyle(
                                            color: isCompleted
                                                ? Colors.red.shade700
                                                : Colors.green.shade700,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chat_bubble_rounded,
                                    color: _chatPrimary),
                                onPressed: openChat,
                              ),
                              if (isCompleted)
                                IconButton(
                                  icon: Icon(Icons.delete_outline,
                                      color: Colors.grey.shade500),
                                  onPressed: () => _deleteChat(context, docId),
                                ),
                            ],
                          ),
                        ),
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
  final bool? isDoctorViewer;

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
    required this.appointmentId,
    this.isDoctorViewer,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Set<String> _markedReadIds = {};
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
    _isDoctor = widget.isDoctorViewer ?? (data['doctorId'] == uid);
    if (mounted) setState(() {});
    await ChatService.clearUnread(
      appointmentId: widget.appointmentId,
      isDoctor: _isDoctor,
      readerUserId: uid,
      senderId: widget.receiverId,
    );
  }

  void _openReceiverProfile() {
    if (_isDoctor) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PatientProfileViewPage(
            patientId: widget.receiverId,
            fallbackName: widget.receiverName,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DoctorProfilePage(doctorId: widget.receiverId),
        ),
      );
    }
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    return DateFormat('h:mm a').format(timestamp.toDate());
  }

  void _markMessageAsRead(DocumentSnapshot doc) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    if (doc['senderId'] == uid) return;
    if (doc['isRead'] == true) return;
    if (_markedReadIds.contains(doc.id)) return;
    _markedReadIds.add(doc.id);

    FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(widget.appointmentId)
        .collection('messages')
        .doc(doc.id)
        .update({'isRead': true});
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

  Widget _messageBubble(Map<String, dynamic> data, bool isMe) {
    final type = (data['messageType'] ?? 'text').toString();
    final isReport = type == 'report';

    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isMe ? 18 : 4),
      bottomRight: Radius.circular(isMe ? 4 : 18),
    );

    Color bg;
    Color textColor;
    if (isMe) {
      bg = _bubbleMine;
      textColor = Colors.white;
    } else if (isReport) {
      bg = const Color(0xFFE8F5E9);
      textColor = Colors.black87;
    } else {
      bg = _bubbleOther;
      textColor = Colors.black87;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 12),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFFE3F2FD),
              child: Icon(
                _isDoctor ? Icons.person : Icons.medical_services,
                size: 16,
                color: _chatPrimary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: borderRadius,
                border: isReport
                    ? Border.all(color: Colors.green.shade300)
                    : isMe
                        ? null
                        : Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  if (!isMe)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isReport) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.description,
                            size: 16,
                            color: isMe ? Colors.white70 : Colors.green.shade700),
                        const SizedBox(width: 6),
                        Text('Medical Report',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isMe
                                    ? Colors.white70
                                    : Colors.green.shade800)),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    data['message'] ?? '',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(data['time']),
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe ? Colors.white70 : Colors.black45,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all,
                          size: 14,
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
          ),
          if (isMe) const SizedBox(width: 6),
        ],
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
      backgroundColor: _chatBg,
      appBar: AppBar(
        backgroundColor: _chatPrimary,
        foregroundColor: Colors.white,
        title: InkWell(
          onTap: _openReceiverProfile,
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: Icon(
                  _isDoctor ? Icons.person : Icons.medical_services,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.receiverName,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const Text('Tap for profile • Secure chat',
                        style: TextStyle(fontSize: 11, color: Colors.white70)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white70, size: 20),
            ],
          ),
        ),
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
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_outlined,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text('Say hello!',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 16)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    bool isMe = data['senderId'] == currentUserId;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _markMessageAsRead(doc);
                    });
                    return _messageBubble(data, isMe);
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

              return Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            filled: true,
                            fillColor: _chatBg,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(28),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (_) => sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: _chatPrimary,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: sendMessage,
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(Icons.send_rounded,
                                color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

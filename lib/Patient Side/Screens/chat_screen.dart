import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/active_chat_tracker.dart';
import '../../services/notification_service.dart';
import '../../services/chat_deletion_service.dart';
import '../../services/appointment_chat_visibility.dart';
import '../../Widgets/profile_view_screens.dart';
import '../../Widgets/profile_avatar.dart';

// ====================================================
// PART 1: PATIENT MESSAGES LIST
// ====================================================

class PatientChatScreen extends StatelessWidget {
  const PatientChatScreen({super.key});

  // --- DELETE CHAT (UPDATED - "Delete for Me") ---
  void _deleteChat(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete conversation?"),
        content: const Text(
          "All messages in this chat will be permanently deleted from your account. "
          "The appointment record is kept for scheduling history.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ChatDeletionService.deleteConversation(
                  appointmentId: docId,
                  deletedByPatient: true,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Conversation deleted')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not delete: $e'), backgroundColor: Colors.orange),
                  );
                }
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openChat(BuildContext context, Map<String, dynamic> data, String docId) {
    if (!AppointmentChatVisibility.isVisibleForPatient(data)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This conversation is no longer available.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          receiverId: (data['doctorId'] ?? '').toString(),
          receiverName: "Dr. ${data['doctorName']}",
          appointmentId: docId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("My Doctors"),
        backgroundColor: const Color(0xFF1565C0),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('appointments')
            .where('patientId', isEqualTo: currentUserId)
            .where('status', whereIn: ['Accepted', 'Completed'])
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No active chats.", style: TextStyle(color: Colors.grey)));
          }

          var allDocs = snapshot.data!.docs;

          // ✅ FILTERING: Sirf wo chats dikhao jo Patient ne delete NAHI ki hain
          var visibleDocs = allDocs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            return AppointmentChatVisibility.isVisibleForPatient(data);
          }).toList();

          if (visibleDocs.isEmpty) {
            return const Center(child: Text("No active chats.", style: TextStyle(color: Colors.grey)));
          }

          return ListView.builder(
            itemCount: visibleDocs.length,
            itemBuilder: (context, index) {
              var data = visibleDocs[index].data() as Map<String, dynamic>;
              String docId = visibleDocs[index].id;
              String status = data['status'];
              bool isCompleted = status == 'Completed';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  onTap: () => _openChat(context, data, docId),
                  leading: ProfileAvatar(
                    userId: (data['doctorId'] ?? '').toString(),
                    radius: 24,
                    fallbackIcon: Icons.medical_services,
                  ),
                  title: Text(
                      "Dr. ${data['doctorName']}",
                      style: TextStyle(color: isCompleted ? Colors.grey : Colors.black)
                  ),
                  subtitle: Text(
                    isCompleted ? "Consultation Ended" : "Tap to chat",
                    style: TextStyle(color: isCompleted ? Colors.red : Colors.green),
                  ),
                  trailing: isCompleted
                      ? IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.grey),
                          onPressed: () => _deleteChat(context, docId),
                        )
                      : const Icon(Icons.chevron_right, color: Colors.grey),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ====================================================
// PART 2: CHAT ROOM (UPDATED LOGIC)
// ====================================================

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String appointmentId;

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
    required this.appointmentId
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    ActiveChatTracker.setActive(
      widget.appointmentId,
      userId: _auth.currentUser?.uid,
    );
  }

  @override
  void dispose() {
    if (ActiveChatTracker.activeAppointmentId == widget.appointmentId &&
        ActiveChatTracker.activeUserId == _auth.currentUser?.uid) {
      ActiveChatTracker.setActive(null);
    }
    _messageController.dispose();
    super.dispose();
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return "";
    DateTime date = timestamp.toDate();
    String hour = date.hour > 12 ? (date.hour - 12).toString() : date.hour.toString();
    String minute = date.minute.toString().padLeft(2, '0');
    String amPm = date.hour >= 12 ? "PM" : "AM";
    return "$hour:$minute $amPm";
  }

  void _markMessageAsRead(DocumentSnapshot doc) {
    if (doc['senderId'] != _auth.currentUser!.uid && !(doc['isRead'] ?? false)) {
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

    String msg = _messageController.text.trim();
    _messageController.clear();

    String currentUserId = _auth.currentUser!.uid;

    final messageRef = await FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(widget.appointmentId)
        .collection('messages')
        .add({
      "senderId": currentUserId,
      "receiverId": widget.receiverId,
      "message": msg,
      "time": FieldValue.serverTimestamp(),
      "isRead": false,
    });

    final apptDoc = await FirebaseFirestore.instance
        .collection('appointments')
        .doc(widget.appointmentId)
        .get();
    final apptData = apptDoc.data();

    String recipientId = widget.receiverId;
    String senderName = 'User';
    if (apptData != null) {
      final patientId = (apptData['patientId'] ?? '').toString();
      final doctorId = (apptData['doctorId'] ?? '').toString();
      final isPatient = currentUserId == patientId;
      if (isPatient) {
        recipientId = doctorId.isNotEmpty ? doctorId : recipientId;
        senderName = (apptData['patientName'] ?? 'Patient').toString();
      } else {
        recipientId = patientId.isNotEmpty ? patientId : recipientId;
        senderName = 'Dr. ${apptData['doctorName'] ?? 'Doctor'}';
      }
    }

    if (recipientId.isEmpty) return;

    await NotificationService.notifyChatMessage(
      recipientId: recipientId,
      senderId: currentUserId,
      senderName: senderName,
      appointmentId: widget.appointmentId,
      messageId: messageRef.id,
      messagePreview: msg,
    );
  }

  void _openPeerProfile(BuildContext context, Map<String, dynamic>? apptData) {
    if (apptData == null) return;
    final uid = _auth.currentUser?.uid ?? '';
    final patientId = (apptData['patientId'] ?? '').toString();
    final doctorId = (apptData['doctorId'] ?? '').toString();
    if (uid == patientId && doctorId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DoctorProfileViewScreen(doctorId: doctorId),
        ),
      );
    } else if (uid == doctorId && patientId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PatientProfileViewScreen(patientId: patientId),
        ),
      );
    }
  }

  Widget _systemMessageBubble(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.grey.shade700),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade800,
                    fontStyle: FontStyle.italic,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chatMessageBubble(Map<String, dynamic> data, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF1565C0) : Colors.grey[300],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              data['message'] ?? '',
              style: TextStyle(color: isMe ? Colors.white : Colors.black),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(data['time']),
                  style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.black54),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all,
                    size: 15,
                    color: (data['isRead'] ?? false) ? Colors.lightBlueAccent : Colors.white60,
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
    String currentUserId = _auth.currentUser?.uid ?? "";

    // Safety check agar appointmentId na ho
    if (widget.appointmentId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.receiverName), backgroundColor: const Color(0xFF1565C0)),
        body: const Center(child: Text("Start a new appointment to chat.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            FirebaseFirestore.instance
                .collection('appointments')
                .doc(widget.appointmentId)
                .get()
                .then((snap) {
              if (context.mounted) _openPeerProfile(context, snap.data());
            });
          },
          child: Row(
            children: [
              ProfileAvatar(
                userId: widget.receiverId,
                radius: 18,
                fallbackIcon: Icons.person,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(widget.receiverName, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
        backgroundColor: const Color(0xFF1565C0),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('appointments')
            .doc(widget.appointmentId)
            .snapshots(),
        builder: (context, apptSnap) {
          final apptData = apptSnap.data?.data() as Map<String, dynamic>?;
          final status = apptData?['status'] ?? 'Accepted';
          final doctorId = apptData?['doctorId'] ?? '';
          final isDoctor = currentUserId == doctorId;
          final isCompleted = status == 'Completed';

          if (apptData != null) {
            final available = isDoctor
                ? AppointmentChatVisibility.isVisibleForDoctor(apptData)
                : AppointmentChatVisibility.isVisibleForPatient(apptData);
            if (!available) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'This conversation is no longer available.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
              );
            }
          }

          return Column(
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
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty && !isCompleted) {
                      return const Center(child: Text("Say Hello! 👋"));
                    }

                    final itemCount = docs.length + (isCompleted ? 1 : 0);

                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.only(bottom: 8, top: 8),
                      itemCount: itemCount,
                      itemBuilder: (context, index) {
                        if (isCompleted && index == docs.length) {
                          return _systemMessageBubble(
                            isDoctor
                                ? 'This consultation has been marked as completed.'
                                : 'This consultation has ended. Book a new appointment to chat again.',
                          );
                        }

                        var doc = docs[index];
                        var data = doc.data() as Map<String, dynamic>;

                        if (data['type'] == 'system') {
                          return _systemMessageBubble(
                            (data['message'] ?? '').toString(),
                          );
                        }

                        bool isMe = data['senderId'] == currentUserId;
                        if (!isMe) _markMessageAsRead(doc);

                        return _chatMessageBubble(data, isMe);
                      },
                    );
                  },
                ),
              ),
              if (!isCompleted)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: const InputDecoration(
                            hintText: "Type a message...",
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => sendMessage(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send, color: Color(0xFF1565C0)),
                        onPressed: sendMessage,
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
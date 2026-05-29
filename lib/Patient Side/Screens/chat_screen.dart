import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
        title: const Text("Delete Chat?"),
        content: const Text("This will hide this chat from YOUR history only."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);

              // ✅ CHANGE: Sirf Patient ke liye 'Hide' kar rahe hain
              await FirebaseFirestore.instance
                  .collection('appointments')
                  .doc(docId)
                  .update({'patientDeleted': true});
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
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
            return data['patientDeleted'] != true;
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
                  leading: CircleAvatar(
                    backgroundColor: isCompleted ? Colors.grey[300] : const Color(0xFFE3F2FD),
                    child: Icon(Icons.medical_services, color: isCompleted ? Colors.grey : const Color(0xFF1565C0)),
                  ),
                  title: Text(
                      "Dr. ${data['doctorName']}",
                      style: TextStyle(color: isCompleted ? Colors.grey : Colors.black)
                  ),
                  subtitle: Text(
                    isCompleted ? "Consultation Ended" : "Tap to chat",
                    style: TextStyle(color: isCompleted ? Colors.red : Colors.green),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chat_bubble, color: Colors.blue),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
                            receiverId: data['doctorId'],
                            receiverName: "Dr. ${data['doctorName']}",
                            appointmentId: docId,
                          )));
                        },
                      ),
                      if (isCompleted)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.grey),
                          onPressed: () => _deleteChat(context, docId),
                        ),
                    ],
                  ),
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

    await FirebaseFirestore.instance
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
        title: Text(widget.receiverName),
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
                  return const Center(child: Text("Say Hello! 👋"));
                }
                return ListView.builder(
                  reverse: true,
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    bool isMe = data['senderId'] == currentUserId;
                    _markMessageAsRead(doc);

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
                              data['message'],
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
                                  )
                                ]
                              ],
                            )
                          ],
                        ),
                      ),
                    );
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

              // ✅ NEW: Check karo ke user Doctor hai ya Patient
              String doctorId = data?['doctorId'] ?? "";
              bool isDoctor = (currentUserId == doctorId);

              // ✅ Agar Status Completed hai
              if (status == 'Completed') {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  color: Colors.red.withOpacity(0.1),
                  child: Text(
                    // ✅ Agar Doctor hai to alag message, Patient hai to alag
                    isDoctor
                        ? "This session is marked as Completed."
                        : "Consultation Ended. Book a new appointment to chat.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
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
                        decoration: const InputDecoration(
                          hintText: "Type a message...",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, color: Color(0xFF1565C0)),
                      onPressed: sendMessage,
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
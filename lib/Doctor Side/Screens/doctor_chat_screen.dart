import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../Patient Side/Screens/chat_screen.dart';
import '../../services/chat_service.dart';
import '../../services/notification_service.dart';

class DoctorChatScreen extends StatelessWidget {
  const DoctorChatScreen({super.key});

  void _endSession(BuildContext context, String appointmentId, String patientName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Consultation?'),
        content: Text(
            'Mark session with $patientName as Completed? Chat will remain in history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              Navigator.pop(context);
              final apt = await FirebaseFirestore.instance
                  .collection('appointments')
                  .doc(appointmentId)
                  .get();
              final data = apt.data() ?? {};
              await FirebaseFirestore.instance
                  .collection('appointments')
                  .doc(appointmentId)
                  .update({'status': 'Completed'});
              final doctorId = FirebaseAuth.instance.currentUser?.uid ?? '';
              String doctorName = 'Doctor';
              if (doctorId.isNotEmpty) {
                final d = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(doctorId)
                    .get();
                doctorName = d.data()?['name'] ?? 'Doctor';
              }
              await NotificationService.consultationEnded(
                patientId: (data['patientId'] ?? '').toString(),
                doctorName: doctorName,
                appointmentId: appointmentId,
                doctorId: doctorId,
              );
            },
            child: const Text('End Session', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _deleteChat(BuildContext context, String appointmentId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat?'),
        content: const Text('This will hide this chat from YOUR list only.'),
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
                  .doc(appointmentId)
                  .update({'doctorDeleted': true});
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
    final String? currentDoctorId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FC),
      appBar: AppBar(
        title: const Text('My Messages'),
        backgroundColor: const Color(0xFF1565C0),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('appointments')
            .where('doctorId', isEqualTo: currentDoctorId)
            .where('status', whereIn: ['Accepted', 'Completed'])
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No chats history.'));
          }

          var visibleDocs = snapshot.data!.docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            return data['doctorDeleted'] != true;
          }).toList();

          visibleDocs.sort((a, b) {
            final ta = (a.data() as Map)['lastMessageTime'];
            final tb = (b.data() as Map)['lastMessageTime'];
            if (ta is! Timestamp) return 1;
            if (tb is! Timestamp) return -1;
            return tb.compareTo(ta);
          });

          if (visibleDocs.isEmpty) {
            return const Center(child: Text('No chats available.'));
          }

          return ListView.builder(
            itemCount: visibleDocs.length,
            itemBuilder: (context, index) {
              var data = visibleDocs[index].data() as Map<String, dynamic>;
              String docId = visibleDocs[index].id;
              String status = data['status'];
              bool isCompleted = status == 'Completed';
              final unread =
                  ChatService.unreadForUser(data, currentDoctorId ?? '');
              final lastMsg =
                  (data['lastMessage'] ?? 'Tap to chat').toString();
              final lastTime = _formatListTime(data['lastMessageTime']);

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
                        child: Icon(Icons.person,
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
                  title: Text(data['patientName'] ?? 'Unknown',
                      style: TextStyle(
                          fontWeight:
                              unread > 0 ? FontWeight.bold : FontWeight.w500,
                          color:
                              isCompleted ? Colors.grey : Colors.black)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lastMsg,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: unread > 0
                                ? FontWeight.w600
                                : FontWeight.normal,
                          )),
                      if (lastTime.isNotEmpty)
                        Text(lastTime, style: const TextStyle(fontSize: 11)),
                      Text(
                        isCompleted ? 'Session Ended' : 'Active Session',
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
                        icon: const Icon(Icons.chat_bubble_outline,
                            color: Colors.blue),
                        onPressed: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                        receiverId: data['patientId'],
                                        receiverName: data['patientName'],
                                        appointmentId: docId,
                                      )));
                        },
                      ),
                      if (isCompleted)
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () => _deleteChat(context, docId),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.check_circle,
                              color: Colors.green),
                          onPressed: () => _endSession(
                              context, docId, data['patientName']),
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

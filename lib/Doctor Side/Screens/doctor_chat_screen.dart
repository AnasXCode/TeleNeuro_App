import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../Patient Side/Screens/chat_screen.dart';
import '../../services/chat_service.dart';
import '../../services/notification_service.dart';
import 'patient_profile_view_screen.dart';

const Color _chatPrimary = Color(0xFF1565C0);
const Color _chatBg = Color(0xFFF0F4F8);

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
      backgroundColor: _chatBg,
      appBar: AppBar(
        title: const Text('My Messages'),
        backgroundColor: _chatPrimary,
        foregroundColor: Colors.white,
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
            return Center(
              child: Text('No chats yet.',
                  style: TextStyle(color: Colors.grey.shade600)),
            );
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
            padding: const EdgeInsets.symmetric(vertical: 8),
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
              final patientName = (data['patientName'] ?? 'Unknown').toString();
              final patientId = (data['patientId'] ?? '').toString();

              void openChat() {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      receiverId: patientId,
                      receiverName: patientName,
                      appointmentId: docId,
                      isDoctorViewer: true,
                    ),
                  ),
                );
              }

              void openPatientProfile() {
                if (patientId.isEmpty) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PatientProfileViewPage(
                      patientId: patientId,
                      fallbackName: patientName,
                    ),
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
                            onTap: openPatientProfile,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  radius: 26,
                                  backgroundColor: isCompleted
                                      ? Colors.grey[300]
                                      : const Color(0xFFE3F2FD),
                                  child: Icon(Icons.person,
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
                              onTap: openPatientProfile,
                              behavior: HitTestBehavior.opaque,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(patientName,
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
                                  Text(lastMsg,
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
                                      )),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (isCompleted
                                              ? Colors.red
                                              : Colors.green)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isCompleted
                                          ? 'Session Ended'
                                          : 'Active Session',
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
                                  color: Colors.red.shade400),
                              onPressed: () => _deleteChat(context, docId),
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.check_circle,
                                  color: Colors.green),
                              onPressed: () => _endSession(
                                  context, docId, patientName),
                            ),
                        ],
                      ),
                    ),
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

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../Patient Side/Screens/chat_screen.dart';
import '../../services/notification_service.dart';
import '../../services/chat_deletion_service.dart';
import '../../services/appointment_chat_visibility.dart';
import '../../Widgets/profile_view_screens.dart';
import '../../Widgets/profile_avatar.dart';

class DoctorChatScreen extends StatelessWidget {
  const DoctorChatScreen({super.key});

  void _endSession(BuildContext context, String appointmentId, String patientName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("End Consultation?"),
        content: Text(
            "Mark session with $patientName as Completed? Chat will remain in history."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              Navigator.pop(context);
              final apptDoc = await FirebaseFirestore.instance
                  .collection('appointments')
                  .doc(appointmentId)
                  .get();
              final apptData = apptDoc.data();
              final patientId = (apptData?['patientId'] as String?) ?? '';
              final doctorName = (apptData?['doctorName'] as String?) ?? 'Doctor';

              await FirebaseFirestore.instance.collection('appointments').doc(appointmentId).update({
                'status': 'Completed',
                'completedAt': FieldValue.serverTimestamp(),
              });

              await NotificationService.addChatSystemMessage(
                appointmentId: appointmentId,
                message: 'This consultation has been marked as completed by the doctor.',
              );

              if (patientId.isNotEmpty) {
                await NotificationService.notifySessionCompleted(
                  patientId: patientId,
                  doctorId: FirebaseAuth.instance.currentUser?.uid ?? '',
                  doctorName: doctorName,
                  appointmentId: appointmentId,
                );
              }
            },
            child: const Text("End Session", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _deleteChat(BuildContext context, String appointmentId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete conversation?"),
        content: const Text(
          "All messages will be permanently deleted from your inbox. "
          "The appointment record remains for your records.",
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
                  appointmentId: appointmentId,
                  deletedByPatient: false,
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
    if (!AppointmentChatVisibility.isVisibleForDoctor(data)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This conversation is no longer available.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          receiverId: (data['patientId'] ?? '').toString(),
          receiverName: (data['patientName'] ?? 'Patient').toString(),
          appointmentId: docId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? currentDoctorId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FC),
      appBar: AppBar(
        title: const Text("My Messages"),
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
            return const Center(child: Text("No chats history."));
          }

          var allDocs = snapshot.data!.docs;

          var visibleDocs = allDocs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            return AppointmentChatVisibility.isVisibleForDoctor(data);
          }).toList();

          if (visibleDocs.isEmpty) {
            return const Center(child: Text("No chats available."));
          }

          return ListView.builder(
            itemCount: visibleDocs.length,
            itemBuilder: (context, index) {
              var data = visibleDocs[index].data() as Map<String, dynamic>;
              String docId = visibleDocs[index].id;
              String status = data['status'];
              bool isCompleted = status == 'Completed';
              final patientId = (data['patientId'] ?? '').toString();

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  onTap: () => _openChat(context, data, docId),
                  onLongPress: patientId.isNotEmpty
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PatientProfileViewScreen(patientId: patientId),
                            ),
                          );
                        }
                      : null,
                  leading: ProfileAvatar(
                    userId: patientId,
                    radius: 24,
                  ),
                  title: Text(
                      data['patientName'] ?? "Unknown",
                      style: TextStyle(color: isCompleted ? Colors.grey : Colors.black)
                  ),
                  subtitle: Text(
                      isCompleted ? "Session Ended — tap to view" : "Active Session — tap to chat",
                      style: TextStyle(color: isCompleted ? Colors.red : Colors.green, fontSize: 12)
                  ),
                  trailing: isCompleted
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.person_outline, color: Color(0xFF1565C0)),
                              tooltip: 'Patient profile',
                              onPressed: patientId.isEmpty
                                  ? null
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => PatientProfileViewScreen(patientId: patientId),
                                        ),
                                      );
                                    },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _deleteChat(context, docId),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check_circle, color: Colors.green),
                              tooltip: 'End session',
                              onPressed: () => _endSession(context, docId, data['patientName'] ?? 'Patient'),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.grey),
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

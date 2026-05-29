import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Note: Niche wali line check karein ke aapki chat_screen.dart kahan pari hai
import '../../Patient Side/Screens/chat_screen.dart';

class DoctorChatScreen extends StatelessWidget {
  const DoctorChatScreen({super.key});

  // --- FUNCTION 1: END SESSION ---
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
              Navigator.pop(context); // Dialog band
              await FirebaseFirestore.instance
                  .collection('appointments')
                  .doc(appointmentId)
                  .update({'status': 'Completed'}); // Status change
            },
            child: const Text("End Session", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- FUNCTION 2: DELETE CHAT (UPDATED - "Delete for Me") ---
  void _deleteChat(BuildContext context, String appointmentId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Chat?"),
        content: const Text("This will hide this chat from YOUR list only."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context); // Dialog band

              // ✅ CHANGE: Delete nahi kar rahe, sirf Doctor ke liye 'Hide' kar rahe hain
              await FirebaseFirestore.instance
                  .collection('appointments')
                  .doc(appointmentId)
                  .update({'doctorDeleted': true});
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
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

          // ✅ FILTERING: Sirf wo chats dikhao jo Doctor ne delete NAHI ki hain
          var visibleDocs = allDocs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            // Agar 'doctorDeleted' true hai, to list mein mat dikhao
            return data['doctorDeleted'] != true;
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

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isCompleted ? Colors.grey[300] : const Color(0xFFE3F2FD),
                    child: Icon(Icons.person, color: isCompleted ? Colors.grey : const Color(0xFF1565C0)),
                  ),
                  title: Text(
                      data['patientName'] ?? "Unknown",
                      style: TextStyle(color: isCompleted ? Colors.grey : Colors.black)
                  ),
                  subtitle: Text(
                      isCompleted ? "Session Ended" : "Active Session",
                      style: TextStyle(color: isCompleted ? Colors.red : Colors.green, fontSize: 12)
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Chat Button
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline, color: Colors.blue),
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
                      // Actions
                      if (isCompleted)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deleteChat(context, docId),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.check_circle, color: Colors.green),
                          onPressed: () => _endSession(context, docId, data['patientName']),
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
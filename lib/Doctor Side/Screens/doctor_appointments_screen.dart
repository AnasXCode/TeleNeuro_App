import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Ensure correct paths
import '../Widgets/appointment_card.dart';
import '../Widgets/request_card.dart';
import '../../services/notification_service.dart';

class DoctorAppointmentsScreen extends StatefulWidget {
  final VoidCallback onBack; // ✅ Naya callback add kiya gaya hai

  const DoctorAppointmentsScreen({super.key, required this.onBack});

  @override
  State<DoctorAppointmentsScreen> createState() => _DoctorAppointmentsScreenState();
}

class _DoctorAppointmentsScreenState extends State<DoctorAppointmentsScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  // ✅ Status Update Function
  Future<void> _updateStatus(String docId, String newStatus) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final apptSnap = await FirebaseFirestore.instance.collection('appointments').doc(docId).get();
      final apptData = apptSnap.data();

      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(docId)
          .update({'status': newStatus});

      if (newStatus == 'Accepted' && apptData != null && user != null) {
        await NotificationService.notifyAppointmentAccepted(
          patientId: (apptData['patientId'] ?? '').toString(),
          doctorId: user!.uid,
          doctorName: (apptData['doctorName'] ?? 'Doctor').toString(),
          appointmentId: docId,
          date: (apptData['date'] ?? '').toString(),
          time: (apptData['time'] ?? '').toString(),
        );
      }

      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text("Request $newStatus"),
        backgroundColor: newStatus == 'Accepted' ? Colors.green : Colors.red,
      ));
    } catch (e) {
      debugPrint("Error updating status: $e");
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Center(child: Text("Please Login First"));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F9FC),
        appBar: AppBar(
          title: const Text("Appointments", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF1565C0),
          centerTitle: true,
          // ✅ Back Arrow Logic Update (Logout rokne ke liye)
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: widget.onBack,
          ),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: "Pending Requests"),
              Tab(text: "Upcoming (Accepted)"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // TAB 1: PENDING
            _buildList('Pending'),

            // TAB 2: ACCEPTED (Upcoming)
            _buildList('Accepted'),
          ],
        ),
      ),
    );
  }

  Widget _buildList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorId', isEqualTo: user!.uid) // ✅ Doctor ID match
          .where('status', isEqualTo: status)      // ✅ Status match
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Agar data nahi hai
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(status == 'Pending' ? Icons.pending : Icons.check_circle, size: 50, color: Colors.grey),
                const SizedBox(height: 10),
                Text("No $status appointments found", style: const TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        var docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            String docId = docs[index].id;

            // Mapping Data safely
            Map<String, String> cardData = {
              'patientId': (data['patientId'] ?? '').toString(),
              'name': (data['patientName'] ?? 'Unknown').toString(),
              'age': 'N/A',
              'issue': (data['problem'] ?? 'General').toString(),
              'time': (data['time'] ?? '00:00').toString(),
              'date': (data['date'] ?? '').toString(),
              'type': 'Online',
              'image': 'assets/images/patient_placeholder.png',
            };

            if (status == 'Pending') {
              // Pending tab mein Accept/Decline button dikhao
              return RequestCard(
                request: cardData,
                onAccept: () => _updateStatus(docId, 'Accepted'), // ✅ Yahan status 'Accepted' set ho raha hai
                onDecline: () => _updateStatus(docId, 'Declined'),
              );
            } else {
              // Accepted tab mein simple card dikhao
              return AppointmentCard(appointment: cardData);
            }
          },
        );
      },
    );
  }
}
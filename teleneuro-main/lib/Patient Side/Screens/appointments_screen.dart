import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final User? user = FirebaseAuth.instance.currentUser;

  // --- FUNCTION: CLEAR HISTORY ---
  // Ye function sirf Completed/Declined appointments ko list se hatayega
  void _clearHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear History?"),
        content: const Text(
            "Remove all Completed and Declined appointments from your list?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context); // Dialog band

              if (user == null) return;

              // 1. Sirf purani/khatam shuda appointments dhundo
              QuerySnapshot snapshot = await FirebaseFirestore.instance
                  .collection('appointments')
                  .where('patientId', isEqualTo: user!.uid)
                  .where('status', whereIn: ['Completed', 'Declined', 'Cancelled'])
                  .get();

              // 2. Batch Update (Sab ko ek sath 'Hide' karo)
              WriteBatch batch = FirebaseFirestore.instance.batch();

              for (var doc in snapshot.docs) {
                batch.update(doc.reference, {'patientDeleted': true});
              }

              await batch.commit();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("History Cleared!")),
                );
              }
            },
            child: const Text("Clear", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("My Appointments"),
        backgroundColor: const Color(0xFF1565C0),
        automaticallyImplyLeading: false,

        // ✅ NEW: Delete Button in App Bar
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep), // Jhaaroo wala icon
            tooltip: "Clear History",
            onPressed: _clearHistory,
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text("Please Login to view appointments"))
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('appointments')
            .where('patientId', isEqualTo: user!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          // 1. Loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Error
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          // 3. No Data
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No appointments found."));
          }

          // 4. Data Filtering
          var allDocs = snapshot.data!.docs;

          // ✅ FILTER: Sirf wo dikhao jo Patient ne delete NAHI ki
          var visibleDocs = allDocs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            return data['patientDeleted'] != true;
          }).toList();

          if (visibleDocs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_available, size: 60, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("List is empty.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: visibleDocs.length,
            itemBuilder: (context, index) {
              var data = visibleDocs[index].data() as Map<String, dynamic>;
              String status = data['status'] ?? 'Pending';

              // Color Logic
              Color statusColor = Colors.orange; // Default Pending
              if (status == 'Accepted') statusColor = Colors.green;
              if (status == 'Completed') statusColor = Colors.blue;
              if (status == 'Declined' || status == 'Cancelled') statusColor = Colors.red;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: statusColor.withOpacity(0.1),
                    child: Icon(Icons.calendar_month, color: statusColor),
                  ),
                  title: Text("Dr. ${data['doctorName'] ?? 'Unknown'}",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${data['date']} at ${data['time']}"),
                      Text("Issue: ${data['problem'] ?? '-'}",
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(status,
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
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
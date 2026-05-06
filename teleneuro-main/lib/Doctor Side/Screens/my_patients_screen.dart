import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyPatientsScreen extends StatefulWidget {
  const MyPatientsScreen({super.key});

  @override
  State<MyPatientsScreen> createState() => _MyPatientsScreenState();
}

class _MyPatientsScreenState extends State<MyPatientsScreen> {
  final String? currentDoctorId = FirebaseAuth.instance.currentUser?.uid;

  // Time format karne ka helper function
  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "Unknown";
    DateTime date = timestamp.toDate();
    return "${date.day}/${date.month}/${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FC),
      appBar: AppBar(
        title: const Text("My Patients", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1565C0),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: currentDoctorId == null
          ? const Center(child: Text("Please login to see patients"))
          : StreamBuilder<QuerySnapshot>(
        // Firebase Index Error se bachne ke liye yahan se .orderBy() hata diya gaya hai
        stream: FirebaseFirestore.instance
            .collection('appointments')
            .where('doctorId', isEqualTo: currentDoctorId)
            .where('status', whereIn: ['Accepted', 'Completed'])
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_off_outlined, size: 60, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("No patients found in your history.", style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }

          // 1. Data ko Dart ke andar manually sort kar rahe hain (Latest First)
          var docs = snapshot.data!.docs.toList();
          docs.sort((a, b) {
            var dataA = a.data() as Map<String, dynamic>;
            var dataB = b.data() as Map<String, dynamic>;
            Timestamp? timeA = dataA['timestamp'] as Timestamp?;
            Timestamp? timeB = dataB['timestamp'] as Timestamp?;

            if (timeA == null) return 1;
            if (timeB == null) return -1;
            return timeB.compareTo(timeA); // Descending order (Latest upar)
          });

          // 2. Ek patient ki multiple appointments ho sakti hain, is liye unique patients nikalenge
          Map<String, Map<String, dynamic>> uniquePatients = {};

          for (var doc in docs) {
            var data = doc.data() as Map<String, dynamic>;
            String patientId = data['patientId'] ?? 'unknown';

            // Agar patient pehle se list mein nahi hai, toh usko list mein daal do
            if (!uniquePatients.containsKey(patientId)) {
              uniquePatients[patientId] = data;
            }
          }

          var patientList = uniquePatients.values.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: patientList.length,
            itemBuilder: (context, index) {
              final patient = patientList[index];

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE3F2FD),
                    child: Icon(Icons.person, color: Color(0xFF1565C0)),
                  ),
                  title: Text(
                      patient['patientName'] ?? "Unknown Patient",
                      style: const TextStyle(fontWeight: FontWeight.bold)
                  ),
                  subtitle: Text("Issue: ${patient['problem'] ?? 'General'}"),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text("Last Visit", style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text(
                          _formatDate(patient['timestamp'] as Timestamp?),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1565C0))
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
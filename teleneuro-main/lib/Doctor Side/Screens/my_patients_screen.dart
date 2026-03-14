import 'package:flutter/material.dart';
import '../Data/doctor_dummy_data.dart'; // Ensure data import

class MyPatientsScreen extends StatelessWidget {
  const MyPatientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FC),
      appBar: AppBar(
        title: const Text("My Patients"),
        backgroundColor: const Color(0xFF1565C0),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(15),
        itemCount: myPatients.length,
        itemBuilder: (context, index) {
          final patient = myPatients[index];
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE3F2FD),
                child: Icon(Icons.person_outline, color: Color(0xFF1565C0)),
              ),
              title: Text(patient['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("Condition: ${patient['condition']}"),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("Last Visit", style: TextStyle(fontSize: 10, color: Colors.grey)),
                  Text(patient['lastVisit']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
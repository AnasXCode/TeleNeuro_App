import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'consult_doctor_screen.dart'; // Booking Page ka rasta

// Colors
const Color kPrimaryColor = Color(0xFF1565C0);
const Color kAccentColor = Color(0xFFE3F2FD);
const Color kTextDark = Color(0xFF37474F);
const Color kTextLight = Color(0xFF78909C);

class AllDoctorsScreen extends StatelessWidget {
  const AllDoctorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Select Specialist"),
        backgroundColor: kPrimaryColor,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      // ✅ REAL FIREBASE DATA (Sirf Doctors layega)
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'Doctor')
            .snapshots(),
        builder: (context, snapshot) {
          // 1. Loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Error Check
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading doctors."));
          }

          // 3. No Data
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No doctors available right now."));
          }

          var docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String docId = docs[index].id; // 🔑 ASLI UID (Zaroori hai)

              return GestureDetector(
                onTap: () {
                  // ✅ Click par Booking Page khulega
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ConsultDoctorPage(
                        doctorId: docId,       // UID pass ki
                        doctorName: data['name'] ?? 'Doctor', // Name pass kiya
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: kAccentColor,
                          backgroundImage: const AssetImage('assets/images/doctor1.png'),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['name'] ?? 'Unknown Doctor',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: kTextDark,
                                ),
                              ),
                              Text(
                                data['speciality'] ?? 'General Physician',
                                style: const TextStyle(
                                  color: kTextLight,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: const [
                                  Icon(Icons.star, color: Colors.amber, size: 14),
                                  Text(
                                    " 4.8",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: kTextDark,
                                    ),
                                  )
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: kPrimaryColor, size: 18),
                      ],
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
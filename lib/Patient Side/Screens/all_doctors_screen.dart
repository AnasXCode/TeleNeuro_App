import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../Widgets/profile_view_screens.dart';
import '../../Widgets/profile_avatar.dart';
import '../../services/auth_role_service.dart';

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
        title: const Text("Select Specialist", style: TextStyle(color: Colors.white)),
        backgroundColor: kPrimaryColor,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'Doctor')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return const Center(child: Text("Error loading doctors."));
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No doctors available right now."));
          }

          var docs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) return false;
            return AuthRoleService.isRegisteredDoctor(data);
          }).toList();

          // ✅ SORTING LOGIC: Rating ke hisab se (Highest First)
          List<DocumentSnapshot> sortedDocs = List.from(docs);
          sortedDocs.sort((a, b) {
            var dataA = a.data() as Map<String, dynamic>;
            var dataB = b.data() as Map<String, dynamic>;
            double ratingA = (dataA['rating'] ?? 0.0).toDouble();
            double ratingB = (dataB['rating'] ?? 0.0).toDouble();
            return ratingB.compareTo(ratingA); // Descending order
          });

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: sortedDocs.length,
            itemBuilder: (context, index) {
              var data = sortedDocs[index].data() as Map<String, dynamic>;
              String docId = sortedDocs[index].id;

              // ✅ RATING/NEW LOGIC
              int totalReviews = data['totalReviews'] ?? 0;
              String ratingDisplay = totalReviews == 0 ? "New" : (data['rating'] ?? 0.0).toString();

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DoctorProfileViewScreen(
                        doctorId: docId,
                        showPatientActions: true,
                        doctorDisplayName: data['name'] ?? 'Doctor',
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
                        color: Colors.grey.withValues(alpha: 0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        ProfileAvatar(
                          userId: docId,
                          radius: 30,
                          fallbackIcon: Icons.medical_services,
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['name'] ?? 'Unknown Doctor',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextDark),
                              ),
                              Text(
                                data['speciality'] ?? 'General Physician',
                                style: const TextStyle(color: kTextLight, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.star, color: Colors.amber, size: 14),
                                  Text(
                                    " $ratingDisplay",
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kTextDark),
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
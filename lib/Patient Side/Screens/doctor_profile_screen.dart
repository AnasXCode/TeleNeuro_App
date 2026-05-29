import 'package:flutter/material.dart';
// Ensure imports are correct

import 'chat_screen.dart'; // Apni chat screen ka path check karein
import 'consult_doctor_screen.dart'; // Booking page import

const Color kPrimaryColor = Color(0xFF1565C0);
const Color kAccentColor = Color(0xFFE3F2FD);
const Color kTextDark = Color(0xFF37474F);
const Color kTextLight = Color(0xFF78909C);

class DoctorProfilePage extends StatelessWidget {
  // ✅ New Field: doctorId add kiya hai
  final String doctorId;
  final String doctorName, specialty, about, exp, patients, education, timing;

  const DoctorProfilePage({
    super.key,
    required this.doctorId, // ✅ Required
    required this.doctorName,
    required this.specialty,
    required this.about,
    required this.exp,
    required this.patients,
    required this.education,
    required this.timing,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(doctorName, style: const TextStyle(color: Colors.white)),
        backgroundColor: kPrimaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Profile Header
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: kAccentColor,
                child: Icon(Icons.person, size: 50, color: kPrimaryColor),
              ),
            ),
            const SizedBox(height: 15),
            Text(doctorName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kTextDark)),
            Text(specialty, style: const TextStyle(fontSize: 16, color: kTextLight)),

            const SizedBox(height: 20),

            // Action Buttons (Chat & Book)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                    context,
                    Icons.chat,
                    "Chat",
                        () {
                      // ✅ ERROR FIXED HERE
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
                        receiverId: doctorId,
                        receiverName: doctorName,
                        // Hum yahan empty string bhej rahe hain taake error hat jaye.
                        // Chat screen isay "Completed" samjhegi aur typing band rakhegi.
                        appointmentId: "",
                      )));
                    }
                ),
                _buildActionButton(
                    context,
                    Icons.calendar_month,
                    "Book Now",
                        () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ConsultDoctorPage(
                        doctorId: doctorId,
                        doctorName: doctorName,
                      )));
                    }
                ),
              ],
            ),

            const SizedBox(height: 25),

            // Details Section
            _buildSectionTitle("About Doctor"),
            Text(about, style: const TextStyle(color: Colors.grey, height: 1.5)),
            const SizedBox(height: 20),

            _buildSectionTitle("Education"),
            Text(education, style: const TextStyle(color: kTextDark, fontWeight: FontWeight.w500)),
            const SizedBox(height: 20),

            _buildSectionTitle("Availability"),
            Text(timing, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),

            const SizedBox(height: 30),

            // Stats Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStat("Patients", patients),
                _buildStat("Experience", exp),
                _buildStat("Rating", "4.9 ⭐"),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: kPrimaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: kPrimaryColor),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextDark)),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kPrimaryColor)),
        Text(label, style: const TextStyle(fontSize: 12, color: kTextLight)),
      ],
    );
  }
}
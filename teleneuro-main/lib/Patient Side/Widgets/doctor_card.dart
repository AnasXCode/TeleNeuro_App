import 'package:flutter/material.dart';
import '../Screens/doctor_profile_screen.dart';
import 'custom_buttons.dart';

class DoctorCard extends StatelessWidget {
  final Map<String, String> doctor;

  // Local Colors
  static const Color kPrimaryColor = Color(0xFF1565C0);
  static const Color kTextDark = Color(0xFF37474F);
  static const Color kTextLight = Color(0xFF78909C);

  const DoctorCard({super.key, required this.doctor});

  @override
  Widget build(BuildContext context) {
    return ScaleButton(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DoctorProfilePage(
              // ✅ FIXED: doctorId pass kar rahe hain (Agar null ho to random string)
              doctorId: doctor['uid'] ?? 'unknown_doctor',
              doctorName: doctor['name'] ?? 'Unknown',
              specialty: doctor['spec'] ?? 'Specialist',
              about: doctor['about'] ?? 'No details available.',
              exp: doctor['exp'] ?? 'N/A',
              patients: doctor['patients'] ?? '0',
              education: doctor['education'] ?? 'MBBS',
              timing: doctor['timing'] ?? 'Available',
            ),
          ),
        );
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12, bottom: 5, top: 5),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 30,
              backgroundColor: Color(0xFFE3F2FD),
              child: Icon(Icons.person, color: kPrimaryColor, size: 30),
            ),
            const SizedBox(height: 8),
            Text(
              doctor['name'] ?? 'Doctor',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextDark),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            Text(
              doctor['spec'] ?? 'Specialist',
              style: const TextStyle(fontSize: 11, color: kTextLight),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
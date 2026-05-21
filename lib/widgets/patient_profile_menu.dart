import 'package:flutter/material.dart';
import '../Patient Side/Screens/patient_profile_screen.dart';

void showPatientProfileMenu(BuildContext context, {VoidCallback? onUpdated}) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Account',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE3F2FD),
                child: Icon(Icons.person, color: Color(0xFF1565C0)),
              ),
              title: const Text('My Profile'),
              subtitle: const Text('View your personal details'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ProfileDisplayPage()),
                ).then((_) => onUpdated?.call());
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE0F7FA),
                child: Icon(Icons.settings, color: Color(0xFF00838F)),
              ),
              title: const Text('Manage Account'),
              subtitle: const Text('Edit info, password & contacts'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PatientProfilePage()),
                ).then((_) => onUpdated?.call());
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Shows in-app snackbars when appointment status changes for the logged-in patient.
class AppointmentStatusListener extends StatefulWidget {
  final Widget child;
  const AppointmentStatusListener({super.key, required this.child});

  @override
  State<AppointmentStatusListener> createState() =>
      _AppointmentStatusListenerState();
}

class _AppointmentStatusListenerState extends State<AppointmentStatusListener> {
  final Map<String, String> _lastStatusByAppointment = {};

  void _onAppointments(QuerySnapshot snap) {
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final id = doc.id;
      final status = (data['status'] ?? '').toString();
      final doctorName = (data['doctorName'] ?? 'your doctor').toString();
      final previous = _lastStatusByAppointment[id];

      if (previous != null && previous != status) {
        if (status == 'Accepted') {
          _showSnack(
            'Appointment approved',
            'Dr. $doctorName accepted your appointment. You can now chat.',
            Colors.green,
            Icons.check_circle_outline,
          );
        } else if (status == 'Completed' && previous == 'Accepted') {
          _showSnack(
            'Consultation ended',
            'Dr. $doctorName has ended your active consultation session.',
            Colors.orange,
            Icons.event_busy,
          );
        } else if (status == 'Declined') {
          _showSnack(
            'Appointment declined',
            'Dr. $doctorName declined your appointment request.',
            Colors.red,
            Icons.cancel_outlined,
          );
        }
      }
      _lastStatusByAppointment[id] = status;
    }
  }

  void _showSnack(String title, String body, Color color, IconData icon) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: color,
        duration: const Duration(seconds: 5),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(body, style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return widget.child;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('patientId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasData) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _onAppointments(snap.data!);
          });
        }
        return widget.child;
      },
    );
  }
}

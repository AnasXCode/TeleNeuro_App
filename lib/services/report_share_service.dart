import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'notification_service.dart';
import 'doctor_availability_service.dart';

/// Handles medical report sharing with confirmation, delivery status, and chat preview.
class ReportShareService {
  static final _db = FirebaseFirestore.instance;

  static Future<Map<String, String>> getBookedDoctors() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return {};

    final snap = await _db
        .collection('appointments')
        .where('patientId', isEqualTo: uid)
        .where('status', whereIn: ['Accepted', 'Completed'])
        .get();

    final Map<String, String> doctors = {};
    for (final doc in snap.docs) {
      final data = doc.data();
      if (data['doctorAccountDeleted'] == true) continue;
      final id = (data['doctorId'] ?? '').toString();
      if (id.isEmpty) continue;
      final active = await DoctorAvailabilityService.isDoctorActive(id);
      if (!active) continue;
      doctors[id] = (data['doctorName'] ?? 'Doctor').toString();
    }
    return doctors;
  }

  static Future<String?> findActiveAppointmentId(
      String patientId, String doctorId) async {
    final snap = await _db
        .collection('appointments')
        .where('patientId', isEqualTo: patientId)
        .where('doctorId', isEqualTo: doctorId)
        .where('status', isEqualTo: 'Accepted')
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id;
  }

  static Future<bool> shareReport({
    required BuildContext context,
    required String reportDocId,
    required String doctorId,
    required String doctorName,
    required String reportTitle,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final reportRef = _db.collection('mri_reports').doc(reportDocId);
      final reportSnap = await reportRef.get();
      if (!reportSnap.exists) {
        _showError(context, 'Report not found.');
        return false;
      }

      final data = reportSnap.data()!;
      final alreadyShared =
          List<String>.from(data['sharedWith'] ?? []).contains(doctorId);
      if (alreadyShared) {
        _showInfo(context, 'This report is already shared with $doctorName.');
        return false;
      }

      final patientName =
          (data['patientName'] ?? user.displayName ?? 'Patient').toString();
      final stage = (data['stage'] ?? '').toString();

      await reportRef.update({
        'sharedWith': FieldValue.arrayUnion([doctorId]),
        'shareHistory': FieldValue.arrayUnion([
          {
            'doctorId': doctorId,
            'doctorName': doctorName,
            'sentAt': FieldValue.serverTimestamp(),
            'seen': false,
            'seenAt': null,
          }
        ]),
      });

      final appointmentId =
          await findActiveAppointmentId(user.uid, doctorId);
      if (appointmentId != null) {
        await _db
            .collection('chat_rooms')
            .doc(appointmentId)
            .collection('messages')
            .add({
          'senderId': user.uid,
          'receiverId': doctorId,
          'message':
              '📄 Medical report shared: $reportTitle${stage.isNotEmpty ? ' ($stage)' : ''}',
          'messageType': 'report',
          'reportDocId': reportDocId,
          'reportTitle': reportTitle,
          'time': FieldValue.serverTimestamp(),
          'isRead': false,
        });

        await _db.collection('appointments').doc(appointmentId).update({
          'lastMessage':
              '📄 Shared report: $reportTitle',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'doctorUnread': FieldValue.increment(1),
        });
      }

      await NotificationService.reportReceived(
        doctorId: doctorId,
        patientName: patientName,
        reportTitle: reportTitle,
        reportDocId: reportDocId,
        patientId: user.uid,
      );

      if (context.mounted) {
        await _showSuccessDialog(
          context,
          doctorName: doctorName,
          reportTitle: reportTitle,
          hasChat: appointmentId != null,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Report sent to $doctorName successfully.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'Failed to share report. Please try again.');
      }
      return false;
    }
  }

  static void _showError(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  static void _showInfo(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.orange),
    );
  }

  static Future<void> _showSuccessDialog(
    BuildContext context, {
    required String doctorName,
    required String reportTitle,
    required bool hasChat,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 32),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Report sent successfully',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your report "$reportTitle" was delivered to $doctorName.'),
            const SizedBox(height: 16),
            _statusRow(Icons.send, 'Delivery status', 'Sent', Colors.blue),
            const SizedBox(height: 8),
            _statusRow(Icons.visibility_outlined, 'Seen status', 'Pending', Colors.grey),
            if (hasChat) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline,
                        color: Color(0xFF1565C0), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'A preview was added to your chat with $doctorName.',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static Widget _statusRow(
      IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
      ],
    );
  }

  static Future<void> markReportSeen({
    required String reportDocId,
    required String doctorId,
  }) async {
    final ref = _db.collection('mri_reports').doc(reportDocId);
    final snap = await ref.get();
    if (!snap.exists) return;

    final history = List<Map<String, dynamic>>.from(
      (snap.data()?['shareHistory'] ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
    );
    bool updated = false;
    for (var i = 0; i < history.length; i++) {
      if (history[i]['doctorId'] == doctorId && history[i]['seen'] != true) {
        history[i]['seen'] = true;
        history[i]['seenAt'] = Timestamp.now();
        updated = true;
      }
    }
    if (updated) {
      await ref.update({'shareHistory': history});
    }
  }
}

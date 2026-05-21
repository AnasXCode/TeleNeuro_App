import 'package:cloud_firestore/cloud_firestore.dart';

/// Tracks which doctor accounts still exist and cleans up patient-facing data.
class DoctorAvailabilityService {
  static final _db = FirebaseFirestore.instance;

  static Stream<Set<String>> activeDoctorIdsStream() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'Doctor')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toSet());
  }

  static Future<bool> isDoctorActive(String doctorId) async {
    if (doctorId.isEmpty) return false;
    final doc = await _db.collection('users').doc(doctorId).get();
    return doc.exists;
  }

  /// Call before deleting a doctor's Firestore user document.
  static Future<void> onDoctorAccountDeleted(String doctorId) async {
    final appointments = await _db
        .collection('appointments')
        .where('doctorId', isEqualTo: doctorId)
        .get();

    if (appointments.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in appointments.docs) {
      batch.update(doc.reference, {
        'doctorAccountDeleted': true,
        'doctorDeleted': true,
      });
    }
    await batch.commit();
  }

  static bool appointmentHasActiveDoctor(
    Map<String, dynamic> apt,
    Set<String> activeDoctorIds,
  ) {
    if (apt['doctorAccountDeleted'] == true) return false;
    final doctorId = (apt['doctorId'] ?? '').toString();
    return doctorId.isNotEmpty && activeDoctorIds.contains(doctorId);
  }

  static String doctorDisplayName(
    Map<String, dynamic> apt,
    Set<String> activeDoctorIds,
  ) {
    if (!appointmentHasActiveDoctor(apt, activeDoctorIds)) {
      return 'Unavailable doctor';
    }
    return (apt['doctorName'] ?? 'Doctor').toString();
  }
}

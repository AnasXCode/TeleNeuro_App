/// Shared rules for hiding conversations when an account is deleted or removed.
class AppointmentChatVisibility {
  AppointmentChatVisibility._();

  static bool isPeerAccountDeletedForPatient(Map<String, dynamic> data) {
    return data['doctorAccountDeleted'] == true;
  }

  static bool isPeerAccountDeletedForDoctor(Map<String, dynamic> data) {
    return data['patientAccountDeleted'] == true;
  }

  static bool isVisibleForPatient(Map<String, dynamic> data) {
    return data['patientDeleted'] != true;
  }

  static bool isVisibleForDoctor(Map<String, dynamic> data) {
    return data['doctorDeleted'] != true;
  }

  /// Whether the current user's chat peer has been marked deleted on the appointment.
  static bool isPeerDeletedForUser(Map<String, dynamic> data, String currentUserId) {
    final patientId = (data['patientId'] ?? '').toString();
    final doctorId = (data['doctorId'] ?? '').toString();
    if (currentUserId == patientId) return isPeerAccountDeletedForPatient(data);
    if (currentUserId == doctorId) return isPeerAccountDeletedForDoctor(data);
    return false;
  }

  static String? peerUserId(Map<String, dynamic> data, String currentUserId) {
    final patientId = (data['patientId'] ?? '').toString();
    final doctorId = (data['doctorId'] ?? '').toString();
    if (currentUserId == patientId && doctorId.isNotEmpty) return doctorId;
    if (currentUserId == doctorId && patientId.isNotEmpty) return patientId;
    return null;
  }
}

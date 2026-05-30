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
    if (data['patientDeleted'] == true) return false;
    if (isPeerAccountDeletedForPatient(data)) return false;
    return true;
  }

  static bool isVisibleForDoctor(Map<String, dynamic> data) {
    if (data['doctorDeleted'] == true) return false;
    if (isPeerAccountDeletedForDoctor(data)) return false;
    return true;
  }
}

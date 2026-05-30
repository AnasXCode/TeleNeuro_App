/// Tracks which appointment chat room the user is actively viewing.
/// Used to avoid duplicate in-app notifications while the chat is open.
class ActiveChatTracker {
  static String? activeAppointmentId;
  static String? activeUserId;

  static void setActive(String? appointmentId, {String? userId}) {
    activeAppointmentId = appointmentId;
    activeUserId = userId;
  }

  static bool isViewingChat(String appointmentId) {
    return activeAppointmentId == appointmentId;
  }

  /// Suppress only when this device belongs to the recipient who is in that chat.
  static bool shouldSuppressChatNotification(String appointmentId, String recipientId) {
    final uid = activeUserId;
    if (uid == null || uid.isEmpty) return false;
    return uid == recipientId && activeAppointmentId == appointmentId;
  }
}

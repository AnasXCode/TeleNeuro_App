import 'package:cloud_firestore/cloud_firestore.dart';

/// Central service for in-app notifications stored in Firestore.
class NotificationService {
  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('notifications');

  static Future<void> send({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? relatedId,
    String? senderId,
    String? senderName,
  }) async {
    if (userId.isEmpty) return;
    await _collection.add({
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'relatedId': relatedId ?? '',
      'senderId': senderId ?? '',
      'senderName': senderName ?? '',
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> appointmentRequest({
    required String doctorId,
    required String patientName,
    required String appointmentId,
    required String patientId,
  }) =>
      send(
        userId: doctorId,
        title: 'New appointment request',
        body: '$patientName has requested an appointment.',
        type: 'appointment_request',
        relatedId: appointmentId,
        senderId: patientId,
        senderName: patientName,
      );

  static Future<void> appointmentStatus({
    required String patientId,
    required String doctorName,
    required String status,
    required String appointmentId,
    required String doctorId,
  }) {
    final normalized = status.toLowerCase();
    final approved =
        normalized == 'accepted' || normalized == 'approved';
    final declined = normalized == 'declined';
    return send(
      userId: patientId,
      title: approved
          ? 'Appointment approved'
          : declined
              ? 'Appointment declined'
              : 'Appointment update',
      body: approved
          ? 'Dr. $doctorName has approved your appointment. You can now chat.'
          : declined
              ? 'Dr. $doctorName declined your appointment request.'
              : 'Dr. $doctorName updated your appointment ($status).',
      type: 'appointment_status',
      relatedId: appointmentId,
      senderId: doctorId,
      senderName: doctorName,
    );
  }

  static Future<void> consultationEnded({
    required String patientId,
    required String doctorName,
    required String appointmentId,
    required String doctorId,
  }) =>
      send(
        userId: patientId,
        title: 'Consultation ended',
        body:
            'Dr. $doctorName has ended your active consultation session.',
        type: 'consultation_ended',
        relatedId: appointmentId,
        senderId: doctorId,
        senderName: doctorName,
      );

  static Future<void> newMessage({
    required String receiverId,
    required String senderName,
    required String preview,
    required String appointmentId,
    required String senderId,
  }) =>
      send(
        userId: receiverId,
        title: 'New message',
        body: '$senderName: $preview',
        type: 'message',
        relatedId: appointmentId,
        senderId: senderId,
        senderName: senderName,
      );

  static Future<void> reportReceived({
    required String doctorId,
    required String patientName,
    required String reportTitle,
    required String reportDocId,
    required String patientId,
  }) =>
      send(
        userId: doctorId,
        title: 'Medical report received',
        body: '$patientName shared "$reportTitle" with you.',
        type: 'report',
        relatedId: reportDocId,
        senderId: patientId,
        senderName: patientName,
      );

  static Stream<int> unreadCountStream(String userId) {
    return _collection
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> notificationsStream(
      String userId) {
    return _collection.where('userId', isEqualTo: userId).snapshots();
  }

  static Future<void> markAsRead(String notificationId) async {
    await _collection.doc(notificationId).update({'isRead': true});
  }

  static Future<void> markAllAsRead(String userId) async {
    final snap = await _collection
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }
}

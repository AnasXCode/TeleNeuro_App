import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'active_chat_tracker.dart';

/// Firestore-backed in-app notifications (one document per recipient + event).
class NotificationService {
  static const collection = 'notifications';

  static const typeAppointmentBooked = 'appointment_booked';
  static const typeSessionCompleted = 'session_completed';
  static const typeChatMessage = 'chat_message';
  static const typeMriShared = 'mri_shared';

  static String _docId(String recipientId, String eventId) {
    final safeEvent = eventId.replaceAll('/', '_').replaceAll(' ', '_');
    final id = '${recipientId}_$safeEvent';
    return id.length > 500 ? id.substring(0, 500) : id;
  }

  /// Creates or updates a notification exactly once per [eventId] per [recipientId].
  static Future<void> send({
    required String recipientId,
    required String type,
    required String title,
    required String body,
    required String eventId,
    String? senderId,
    String? appointmentId,
    Map<String, dynamic>? data,
  }) async {
    if (recipientId.trim().isEmpty) return;

    try {
      final docRef = FirebaseFirestore.instance
          .collection(collection)
          .doc(_docId(recipientId, eventId));

      final existing = await docRef.get();
      if (existing.exists) return;

      await docRef.set({
        'recipientId': recipientId,
        'senderId': senderId,
        'type': type,
        'title': title,
        'body': body,
        'eventId': eventId,
        if (appointmentId != null) 'appointmentId': appointmentId,
        if (data != null) ...data,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('NotificationService.send failed: $e');
    }
  }

  static Future<void> notifyAppointmentBooked({
    required String doctorId,
    required String patientId,
    required String patientName,
    required String appointmentId,
    required String date,
    required String time,
  }) async {
    await send(
      recipientId: doctorId,
      senderId: patientId,
      type: typeAppointmentBooked,
      title: 'New appointment request',
      body: '$patientName booked an appointment for $date at $time.',
      eventId: 'appt_booked_$appointmentId',
      appointmentId: appointmentId,
    );
  }

  static Future<void> notifySessionCompleted({
    required String patientId,
    required String doctorId,
    required String doctorName,
    required String appointmentId,
  }) async {
    await send(
      recipientId: patientId,
      senderId: doctorId,
      type: typeSessionCompleted,
      title: 'Consultation completed',
      body: 'Dr. $doctorName has marked your consultation session as completed.',
      eventId: 'session_completed_$appointmentId',
      appointmentId: appointmentId,
    );
  }

  static Future<void> notifyChatMessage({
    required String recipientId,
    required String senderId,
    required String senderName,
    required String appointmentId,
    required String messageId,
    required String messagePreview,
  }) async {
    if (recipientId.trim().isEmpty || recipientId == senderId) return;

    // Do not skip on sender's device when sender is viewing the chat (previous bug).
    if (shouldSuppressChatNotification(appointmentId, recipientId)) return;

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(recipientId).get();
      if (!userDoc.exists) return;
    } catch (e) {
      debugPrint('notifyChatMessage recipient check failed: $e');
      return;
    }

    final preview = messagePreview.length > 80
        ? '${messagePreview.substring(0, 80)}…'
        : messagePreview;

    await send(
      recipientId: recipientId,
      senderId: senderId,
      type: typeChatMessage,
      title: 'New message from $senderName',
      body: preview,
      eventId: 'chat_$messageId',
      appointmentId: appointmentId,
    );
  }

  static bool shouldSuppressChatNotification(String appointmentId, String recipientId) {
    return ActiveChatTracker.shouldSuppressChatNotification(appointmentId, recipientId);
  }

  static Future<void> notifyMriReportShared({
    required String doctorId,
    required String patientId,
    required String patientName,
    required String reportId,
    required String doctorName,
  }) async {
    await send(
      recipientId: doctorId,
      senderId: patientId,
      type: typeMriShared,
      title: 'MRI report shared',
      body: '$patientName shared an MRI report (ID: $reportId) with you.',
      eventId: 'mri_${patientId}_${reportId}_$doctorId',
      data: {'reportId': reportId},
    );
  }

  static Future<void> addChatSystemMessage({
    required String appointmentId,
    required String message,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(appointmentId)
          .collection('messages')
          .add({
        'type': 'system',
        'message': message,
        'time': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('addChatSystemMessage failed: $e');
    }
  }

  static Stream<int> unreadCountStream(String userId) {
    return notificationsStream(userId).map(
      (snap) => snap.docs.where((d) => d.data()['read'] != true).length,
    );
  }

  /// Unread chat-message notifications (badge on Chat tab).
  static Stream<int> unreadChatCountStream(String userId) {
    return notificationsStream(userId).map(
      (snap) => snap.docs.where((d) {
        final data = d.data();
        return data['read'] != true && data['type'] == typeChatMessage;
      }).length,
    );
  }

  /// Unread non-chat notifications (badge on Notifications tab).
  static Stream<int> unreadGeneralCountStream(String userId) {
    return notificationsStream(userId).map(
      (snap) => snap.docs.where((d) {
        final data = d.data();
        return data['read'] != true && data['type'] != typeChatMessage;
      }).length,
    );
  }

  static Future<void> markChatNotificationsAsRead(String userId) async {
    final snap = await FirebaseFirestore.instance
        .collection(collection)
        .where('recipientId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();
    final chatDocs = snap.docs.where((d) => d.data()['type'] == typeChatMessage);
    if (chatDocs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in chatDocs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  static Future<void> markGeneralNotificationsAsRead(String userId) async {
    final snap = await FirebaseFirestore.instance
        .collection(collection)
        .where('recipientId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();
    final toUpdate = snap.docs.where((d) => d.data()['type'] != typeChatMessage);
    if (toUpdate.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in toUpdate) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  static Future<void> markAppointmentNotificationsAsRead({
    required String userId,
    required String appointmentId,
  }) async {
    if (appointmentId.isEmpty) return;
    final snap = await FirebaseFirestore.instance
        .collection(collection)
        .where('recipientId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();
    final apptDocs = snap.docs.where((d) => d.data()['appointmentId'] == appointmentId);
    if (apptDocs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in apptDocs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> notificationsStream(String userId) {
    return FirebaseFirestore.instance
        .collection(collection)
        .where('recipientId', isEqualTo: userId)
        .snapshots();
  }

  static Future<void> markAsRead(String notificationDocId) async {
    await FirebaseFirestore.instance.collection(collection).doc(notificationDocId).update({
      'read': true,
    });
  }

  static Future<void> markAllAsRead(String userId) async {
    final snap = await FirebaseFirestore.instance
        .collection(collection)
        .where('recipientId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';

class ChatService {
  static final _db = FirebaseFirestore.instance;

  static Future<void> sendTextMessage({
    required String appointmentId,
    required String receiverId,
    required String message,
    required String receiverName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || appointmentId.isEmpty) return;

    final aptRef = _db.collection('appointments').doc(appointmentId);
    final aptSnap = await aptRef.get();
    if (!aptSnap.exists) return;

    final apt = aptSnap.data()!;
    final isDoctor = apt['doctorId'] == user.uid;
    final preview = message.length > 60 ? '${message.substring(0, 60)}...' : message;

    await _db
        .collection('chat_rooms')
        .doc(appointmentId)
        .collection('messages')
        .add({
      'senderId': user.uid,
      'receiverId': receiverId,
      'message': message,
      'messageType': 'text',
      'time': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    await aptRef.update({
      'lastMessage': preview,
      'lastMessageTime': FieldValue.serverTimestamp(),
      if (isDoctor) 'patientUnread': FieldValue.increment(1),
      if (!isDoctor) 'doctorUnread': FieldValue.increment(1),
    });

    final senderName = isDoctor
        ? 'Dr. ${apt['doctorName'] ?? 'Doctor'}'
        : (apt['patientName'] ?? 'Patient').toString();

    await NotificationService.newMessage(
      receiverId: receiverId,
      senderName: senderName,
      preview: preview,
      appointmentId: appointmentId,
      senderId: user.uid,
    );
  }

  static Future<void> clearUnread({
    required String appointmentId,
    required bool isDoctor,
    String? readerUserId,
    String? senderId,
  }) async {
    await _db.collection('appointments').doc(appointmentId).update({
      if (isDoctor) 'doctorUnread': 0,
      if (!isDoctor) 'patientUnread': 0,
    });

    final uid = readerUserId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await NotificationService.markMessageNotificationsRead(
        userId: uid,
        appointmentId: appointmentId,
        senderId: senderId,
      );
    }
  }

  static int unreadForUser(Map<String, dynamic> apt, String uid) {
    if (apt['doctorId'] == uid) {
      return (apt['doctorUnread'] ?? 0) as int;
    }
    return (apt['patientUnread'] ?? 0) as int;
  }
}

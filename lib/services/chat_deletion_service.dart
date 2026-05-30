import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Permanently removes chat messages and hides the conversation for the deleting user.
class ChatDeletionService {
  static Future<void> deleteConversation({
    required String appointmentId,
    required bool deletedByPatient,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final messagesRef = firestore
          .collection('chat_rooms')
          .doc(appointmentId)
          .collection('messages');

      const pageSize = 400;
      while (true) {
        final snap = await messagesRef.limit(pageSize).get();
        if (snap.docs.isEmpty) break;

        final batch = firestore.batch();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        if (snap.docs.length < pageSize) break;
      }

      final chatRoomRef = firestore.collection('chat_rooms').doc(appointmentId);
      final chatRoomSnap = await chatRoomRef.get();
      if (chatRoomSnap.exists) {
        await chatRoomRef.delete();
      }

      await firestore.collection('appointments').doc(appointmentId).update({
        if (deletedByPatient) 'patientDeleted': true else 'doctorDeleted': true,
        'chatClearedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('ChatDeletionService.deleteConversation failed: $e');
      rethrow;
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Deletes the authenticated user's account and Firestore profile.
class AccountDeletionService {
  static Future<String?> deleteCurrentAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Not signed in.';

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
    } catch (e) {
      debugPrint('Firestore user delete failed: $e');
    }

    try {
      await user.delete();
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return 'For security, please sign out, sign in again, then delete your account.';
      }
      return e.message ?? 'Could not delete account.';
    } catch (e) {
      return e.toString();
    }
  }
}

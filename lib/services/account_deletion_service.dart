import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Deletes the signed-in user's Firebase Auth account and Firestore profile.
class AccountDeletionService {
  static Future<String?> deleteCurrentAccount({required String password}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Not signed in.';

    final trimmedPassword = password.trim();
    if (trimmedPassword.isEmpty) return 'Password is required.';

    final reauthError = await _reauthenticate(user, trimmedPassword);
    if (reauthError != null) return reauthError;

    final uid = user.uid;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
    } catch (e) {
      debugPrint('AccountDeletionService profile delete failed: $e');
      return 'Could not remove profile. Please try again.';
    }

    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      debugPrint('AccountDeletionService auth delete failed: ${e.code}');
      return e.message ?? 'Could not delete account.';
    } catch (e) {
      return 'Could not delete account.';
    }

    try {
      await _clearLocalPreferences();
    } catch (e) {
      debugPrint('AccountDeletionService prefs clear failed: $e');
    }

    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}

    return null;
  }

  static Future<String?> _reauthenticate(User user, String password) async {
    final email = user.email?.trim();
    if (email == null || email.isEmpty) {
      return 'This account has no email; cannot verify password.';
    }

    try {
      final credential = EmailAuthProvider.credential(email: email, password: password);
      await user.reauthenticateWithCredential(credential);
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return 'Incorrect password.';
      }
      return e.message ?? 'Could not verify password.';
    } catch (_) {
      return 'Could not verify password.';
    }
  }

  static Future<void> _clearLocalPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('name');
    await prefs.remove('dob');
    await prefs.remove('phone');
    await prefs.remove('email');
    await prefs.remove('address');
    await prefs.remove('emergency');
    await prefs.remove('conditions');
    await prefs.remove('gender');
    await prefs.remove('bloodGroup');
    await prefs.remove('imagePath');
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Role checks for separating doctor and patient login flows.
class AuthRoleService {
  static bool isDoctorRole(String? role) => role?.trim().toLowerCase() == 'doctor';

  static bool isPatientRole(String? role) => role?.trim().toLowerCase() == 'patient';

  static Future<String?> fetchUserRole(String uid) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return doc.data()?['role']?.toString();
  }

  static Future<void> signOut() => FirebaseAuth.instance.signOut();

  static bool isRegisteredDoctor(Map<String, dynamic> data) {
    return data['registeredVia'] == 'doctor_signup';
  }
}

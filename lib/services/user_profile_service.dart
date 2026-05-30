import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Loads patient/doctor profile data from Firestore with SharedPreferences fallback.
class UserProfileService {
  static String _str(dynamic v, [String fallback = '—']) {
    if (v == null) return fallback;
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  static Future<Map<String, dynamic>> loadPatientProfile(String patientUid) async {
    final prefs = await SharedPreferences.getInstance();
    final isSelf = FirebaseAuth.instance.currentUser?.uid == patientUid;

    Map<String, dynamic> firestore = {};
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(patientUid).get();
      if (doc.exists) firestore = doc.data() ?? {};
    } catch (_) {}

    File? imageFile;
    if (isSelf) {
      final path = prefs.getString('imagePath');
      if (path != null && File(path).existsSync()) imageFile = File(path);
    }

    return {
      'uid': patientUid,
      'name': _str(firestore['name'], _str(prefs.getString('name'), 'Patient')),
      'email': _str(firestore['email'], _str(prefs.getString('email'), '—')),
      'phone': _str(firestore['phone'], _str(prefs.getString('phone'), '—')),
      'gender': _str(firestore['gender'], _str(prefs.getString('gender'), '—')),
      'dob': _str(firestore['dob'], _str(prefs.getString('dob'), '—')),
      'address': _str(firestore['address'], _str(prefs.getString('address'), '—')),
      'bloodGroup': _str(firestore['bloodGroup'], _str(prefs.getString('bloodGroup'), '—')),
      'emergency': _str(firestore['emergency'], _str(prefs.getString('emergency'), '—')),
      'medicalConditions': _str(
        firestore['medicalConditions'] ?? firestore['conditions'],
        _str(prefs.getString('conditions'), '—'),
      ),
      'profileImage': imageFile,
    };
  }

  static Future<Map<String, dynamic>> loadDoctorProfile(String doctorUid) async {
    Map<String, dynamic> data = {};
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(doctorUid).get();
      if (doc.exists) data = doc.data() ?? {};
    } catch (_) {}

    final totalReviews = (data['totalReviews'] ?? 0) as num;
    final rating = data['rating'];
    String ratingDisplay;
    if (totalReviews == 0) {
      ratingDisplay = 'New';
    } else {
      ratingDisplay = '${rating ?? '0.0'} / 5.0';
    }

    return {
      'uid': doctorUid,
      'name': _str(data['name'], 'Doctor'),
      'email': _str(data['email'], '—'),
      'phone': _str(data['phone'], '—'),
      'specialization': _str(data['speciality'] ?? data['specialization'], 'General Physician'),
      'qualifications': _str(data['qualifications'] ?? data['education'], '—'),
      'experience': _str(data['experience'], '—'),
      'hospital': _str(data['hospital'], '—'),
      'about': _str(data['about'], '—'),
      'availability': _str(data['timing'] ?? data['availability'], '—'),
      'ratingDisplay': ratingDisplay,
      'totalReviews': totalReviews.toInt(),
    };
  }

  static Future<void> syncPatientProfileToFirestore({
    required String uid,
    required Map<String, String> fields,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {
          ...fields,
          'role': 'patient',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {}
  }
}

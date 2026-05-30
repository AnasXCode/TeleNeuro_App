import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../supabase_config.dart';
import '../../services/notification_service.dart';

/// Shared MRI report persistence and doctor sharing for the patient side.
class MriReportService {
  static const _collection = 'mri_reports';

  /// Patient-owned Lab Reports entry (not visible to doctors until explicitly shared).
  static bool isPatientLibraryReport(Map<String, dynamic> data) {
    if (data['isPatientLibrary'] == true) return true;
    if (data['isPatientLibrary'] == false) return false;
    // Legacy documents (no isPatientLibrary field): keep previous patient list behavior.
    return true;
  }

  /// Doctor-facing share record (excludes patient-only library copies).
  static bool isDoctorVisibleReport(Map<String, dynamic> data, String doctorId, Set<String> linkedPatientIds) {
    if (data['isPatientLibrary'] == true) return false;

    final reportDoctorId = (data['doctorId'] as String?)?.trim();
    if (reportDoctorId != null && reportDoctorId.isNotEmpty) {
      return reportDoctorId == doctorId;
    }

    // Legacy reports (before doctor-scoped sharing): visible to all linked doctors.
    final patientUid = data['patientUid'] as String?;
    return linkedPatientIds.contains(patientUid);
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> patientLibraryReportsStream(String patientUid) {
    return FirebaseFirestore.instance
        .collection(_collection)
        .where('patientUid', isEqualTo: patientUid)
        .snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> appointmentDoctorsStream(String patientUid) {
    return FirebaseFirestore.instance
        .collection('appointments')
        .where('patientId', isEqualTo: patientUid)
        .where('status', whereIn: ['Accepted', 'Completed', 'Pending'])
        .snapshots();
  }

  static Map<String, String> doctorsFromAppointments(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> appointmentDocs,
  ) {
    final doctors = <String, String>{};
    for (final doc in appointmentDocs) {
      final data = doc.data();
      if (data['patientDeleted'] == true) continue;
      final doctorId = (data['doctorId'] as String?)?.trim();
      final doctorName = (data['doctorName'] as String?)?.trim();
      if (doctorId != null && doctorId.isNotEmpty) {
        doctors[doctorId] = doctorName?.isNotEmpty == true ? doctorName! : 'Doctor';
      }
    }
    return doctors;
  }

  static ({String ext, String mime}) mriStorageFormat(File mriFile) {
    final lower = mriFile.path.toLowerCase();
    if (lower.endsWith('.png')) return (ext: 'png', mime: 'image/png');
    if (lower.endsWith('.webp')) return (ext: 'webp', mime: 'image/webp');
    if (lower.endsWith('.gif')) return (ext: 'gif', mime: 'image/gif');
    if (lower.endsWith('.bmp')) return (ext: 'bmp', mime: 'image/bmp');
    if (lower.endsWith('.jpeg') || lower.endsWith('.jpg')) {
      return (ext: 'jpg', mime: 'image/jpeg');
    }
    return (ext: 'jpg', mime: 'image/jpeg');
  }

  static Future<({String? pdfUrl, String? imageUrl, String uploadStatus})> uploadReportFiles({
    required String patientUid,
    required String reportId,
    required Uint8List pdfBytes,
    required Uint8List imageBytes,
    required File mriSourceFile,
  }) async {
    String? pdfUrl;
    String? imageUrl;
    var uploadStatus = 'ok';

    try {
      final fmt = mriStorageFormat(mriSourceFile);
      final storage = Supabase.instance.client.storage.from(SupabaseConfig.supabaseBucket);
      final imagePath = '$patientUid/$reportId.${fmt.ext}';
      final pdfPath = '$patientUid/$reportId.pdf';

      await storage.uploadBinary(
        imagePath,
        imageBytes,
        fileOptions: FileOptions(contentType: fmt.mime, upsert: true),
      );
      imageUrl = storage.getPublicUrl(imagePath);

      await storage.uploadBinary(
        pdfPath,
        pdfBytes,
        fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true),
      );
      pdfUrl = storage.getPublicUrl(pdfPath);
    } on StorageException catch (e) {
      uploadStatus = '${e.statusCode ?? '?'} ${e.message}';
      debugPrint('Supabase StorageException: $e');
    } catch (e) {
      uploadStatus = e.toString();
      debugPrint('Supabase upload failed: $e');
    }

    return (pdfUrl: pdfUrl, imageUrl: imageUrl, uploadStatus: uploadStatus);
  }

  /// Saves or updates the patient's Lab Reports copy. Deduped by [reportId].
  static Future<({String? docId, String? pdfUrl, String? imageUrl, String uploadStatus})> saveToPatientLibrary({
    required String patientUid,
    required String patientName,
    required String patientEmail,
    required String reportId,
    required String stage,
    required String confidence,
    required String clinicalNotes,
    required Uint8List pdfBytes,
    required Uint8List imageBytes,
    required File mriSourceFile,
  }) async {
    final upload = await uploadReportFiles(
      patientUid: patientUid,
      reportId: reportId,
      pdfBytes: pdfBytes,
      imageBytes: imageBytes,
      mriSourceFile: mriSourceFile,
    );

    final payload = {
      'patientUid': patientUid,
      'patientName': patientName,
      'patientEmail': patientEmail,
      'reportId': reportId,
      'stage': stage,
      'confidence': confidence,
      'clinicalNotes': clinicalNotes,
      'pdfUrl': upload.pdfUrl,
      'imageUrl': upload.imageUrl,
      'storage': 'supabase',
      'isPatientLibrary': true,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final existing = await FirebaseFirestore.instance
        .collection(_collection)
        .where('patientUid', isEqualTo: patientUid)
        .where('reportId', isEqualTo: reportId)
        .where('isPatientLibrary', isEqualTo: true)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      final docRef = existing.docs.first.reference;
      await docRef.update(payload);
      return (docId: docRef.id, pdfUrl: upload.pdfUrl, imageUrl: upload.imageUrl, uploadStatus: upload.uploadStatus);
    }

    final docRef = await FirebaseFirestore.instance.collection(_collection).add({
      ...payload,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return (docId: docRef.id, pdfUrl: upload.pdfUrl, imageUrl: upload.imageUrl, uploadStatus: upload.uploadStatus);
  }

  /// Shares an existing library report with one doctor. Creates a separate doctor-facing record.
  static Future<ShareReportResult> shareReportWithDoctor({
    required String libraryDocId,
    required Map<String, dynamic> reportData,
    required String doctorId,
    required String doctorName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return ShareReportResult.failure('Please sign in to share reports.');
    }

    final patientUid = (reportData['patientUid'] as String?)?.trim();
    if (patientUid == null || patientUid.isEmpty) {
      return ShareReportResult.failure('Invalid report data.');
    }
    if (patientUid != user.uid) {
      return ShareReportResult.failure('You can only share your own reports.');
    }
    if (doctorId.trim().isEmpty) {
      return ShareReportResult.failure('Please select a doctor.');
    }

    final appointmentDoctors = await _fetchAppointmentDoctors(patientUid);
    if (!appointmentDoctors.containsKey(doctorId)) {
      return ShareReportResult.failure(
        'You can only share with doctors who have an appointment with you.',
      );
    }

    final reportId = (reportData['reportId'] as String?)?.trim();
    if (reportId == null || reportId.isEmpty) {
      return ShareReportResult.failure('Report is missing an identifier.');
    }

    final existingShare = await FirebaseFirestore.instance
        .collection(_collection)
        .where('patientUid', isEqualTo: patientUid)
        .where('reportId', isEqualTo: reportId)
        .where('doctorId', isEqualTo: doctorId)
        .where('isPatientLibrary', isEqualTo: false)
        .limit(1)
        .get();

    if (existingShare.docs.isNotEmpty) {
      return ShareReportResult.alreadyShared(doctorName);
    }

    await FirebaseFirestore.instance.collection(_collection).add({
      'patientUid': patientUid,
      'patientName': reportData['patientName'] ?? 'Patient',
      'patientEmail': reportData['patientEmail'] ?? '',
      'doctorId': doctorId,
      'doctorName': doctorName,
      'reportId': reportId,
      'stage': reportData['stage'] ?? '',
      'confidence': reportData['confidence'] ?? '',
      'clinicalNotes': reportData['clinicalNotes'] ?? '',
      'pdfUrl': reportData['pdfUrl'],
      'imageUrl': reportData['imageUrl'],
      'storage': reportData['storage'] ?? 'supabase',
      'isPatientLibrary': false,
      'libraryDocId': libraryDocId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final patientName = (reportData['patientName'] ?? 'Patient').toString();
    await NotificationService.notifyMriReportShared(
      doctorId: doctorId,
      patientId: patientUid,
      patientName: patientName,
      reportId: reportId,
      doctorName: doctorName,
    );

    return ShareReportResult.success(doctorName);
  }

  static Future<Map<String, String>> _fetchAppointmentDoctors(String patientUid) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('appointments')
        .where('patientId', isEqualTo: patientUid)
        .where('status', whereIn: ['Accepted', 'Completed', 'Pending'])
        .get();
    return doctorsFromAppointments(snapshot.docs);
  }
}

class ShareReportResult {
  final bool ok;
  final bool alreadyShared;
  final String message;

  const ShareReportResult._({
    required this.ok,
    required this.alreadyShared,
    required this.message,
  });

  factory ShareReportResult.success(String doctorName) => ShareReportResult._(
        ok: true,
        alreadyShared: false,
        message: 'Report shared with Dr. $doctorName.',
      );

  factory ShareReportResult.alreadyShared(String doctorName) => ShareReportResult._(
        ok: true,
        alreadyShared: true,
        message: 'Report was already shared with Dr. $doctorName.',
      );

  factory ShareReportResult.failure(String message) => ShareReportResult._(
        ok: false,
        alreadyShared: false,
        message: message,
      );
}

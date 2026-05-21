import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore-backed MRI / lab report record.
class LabReport {
  final String docId;
  final String reportId;
  final String patientUid;
  final String patientName;
  final String patientEmail;
  final String stage;
  final String confidence;
  final String clinicalNotes;
  final String? pdfUrl;
  final String? imageUrl;
  final String? localPdfPath;
  final bool pdfReady;
  final DateTime? createdAt;

  const LabReport({
    required this.docId,
    required this.reportId,
    required this.patientUid,
    required this.patientName,
    required this.patientEmail,
    required this.stage,
    required this.confidence,
    required this.clinicalNotes,
    this.pdfUrl,
    this.imageUrl,
    this.localPdfPath,
    this.pdfReady = false,
    this.createdAt,
  });

  factory LabReport.fromFirestore(
    String docId,
    Map<String, dynamic> data,
  ) {
    DateTime? created;
    final raw = data['createdAt'];
    if (raw is Timestamp) created = raw.toDate();

    final pdfUrl = (data['pdfUrl'] ?? '').toString();
    final localPath = (data['localPdfPath'] ?? '').toString();

    return LabReport(
      docId: docId,
      reportId: (data['reportId'] ?? 'MRI Report').toString(),
      patientUid: (data['patientUid'] ?? '').toString(),
      patientName: (data['patientName'] ?? 'Patient').toString(),
      patientEmail: (data['patientEmail'] ?? '').toString(),
      stage: (data['stage'] ?? '').toString(),
      confidence: (data['confidence'] ?? '').toString(),
      clinicalNotes: (data['clinicalNotes'] ?? '').toString(),
      pdfUrl: pdfUrl.isEmpty ? null : pdfUrl,
      imageUrl: ((data['imageUrl'] ?? '').toString().isEmpty)
          ? null
          : data['imageUrl'].toString(),
      localPdfPath: localPath.isEmpty ? null : localPath,
      pdfReady: data['pdfReady'] == true || pdfUrl.isNotEmpty,
      createdAt: created,
    );
  }

  Map<String, dynamic> pdfFirestoreFields({
    required String? pdfUrl,
    required String localPdfPath,
  }) {
    return {
      if (pdfUrl != null) 'pdfUrl': pdfUrl,
      'localPdfPath': localPdfPath,
      'pdfReady': true,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

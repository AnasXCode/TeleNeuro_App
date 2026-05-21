import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/lab_report.dart';
import '../../services/lab_report_pdf_service.dart';
import '../../widgets/share_report_dialog.dart';

const Color kPrimaryColor = Color(0xFF1565C0);
const Color _bg = Color(0xFFF0F4F8);

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final Set<String> _busyReportIds = {};

  String _formatDate(dynamic createdAt) {
    if (createdAt is Timestamp) {
      return DateFormat('MMM d, yyyy • h:mm a').format(createdAt.toDate());
    }
    return '';
  }

  Color _stageColor(String stage) {
    final s = stage.toLowerCase();
    if (s.contains('non')) return Colors.green;
    if (s.contains('very mild')) return Colors.lightGreen.shade700;
    if (s.contains('mild')) return Colors.orange;
    if (s.contains('moderate')) return Colors.red.shade700;
    return kPrimaryColor;
  }

  bool _isBusy(String docId) => _busyReportIds.contains(docId);

  void _setBusy(String docId, bool busy) {
    setState(() {
      if (busy) {
        _busyReportIds.add(docId);
      } else {
        _busyReportIds.remove(docId);
      }
    });
  }

  Future<void> _openReportPdf(LabReport report) async {
    if (_isBusy(report.docId)) return;
    _setBusy(report.docId, true);

    try {
      final localPath = await LabReportPdfService.resolveLocalPdfPath(
        reportId: report.reportId,
        existingLocalPath: report.localPdfPath,
        remotePdfUrl: report.pdfUrl,
        buildPdf: () async {
          Uint8List? imageBytes;
          if (report.imageUrl != null && report.imageUrl!.isNotEmpty) {
            imageBytes =
                await LabReportPdfService.downloadBytes(report.imageUrl!);
          }
          return LabReportPdfService.generateReportPdf(
            reportId: report.reportId,
            patientName: report.patientName,
            patientEmail: report.patientEmail,
            stage: report.stage,
            confidence: report.confidence,
            clinicalNotes: report.clinicalNotes.isNotEmpty
                ? report.clinicalNotes
                : LabReportPdfService.clinicalDescriptionForStage(
                    report.stage),
            mriImageBytes: imageBytes,
          );
        },
      );

      if (localPath == null) {
        throw Exception('Could not prepare the PDF file.');
      }

      if (report.localPdfPath != localPath) {
        await FirebaseFirestore.instance
            .collection('mri_reports')
            .doc(report.docId)
            .set(
          report.pdfFirestoreFields(
            pdfUrl: report.pdfUrl,
            localPdfPath: localPath,
          ),
          SetOptions(merge: true),
        );
      }

      await LabReportPdfService.openPdf(localPath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) _setBusy(report.docId, false);
    }
  }

  void _showReportDetail(
    BuildContext context,
    Map<String, dynamic> data,
    String reportDocId,
  ) {
    final report = LabReport.fromFirestore(reportDocId, data);
    final stage = report.stage.isEmpty ? '—' : report.stage;
    final conf = report.confidence.isEmpty ? '—' : report.confidence;
    final notes = report.clinicalNotes;
    final imageUrl = report.imageUrl ?? '';
    final title = report.reportId;
    final busy = _isBusy(report.docId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(title,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(_formatDate(data['createdAt']),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              const SizedBox(height: 16),
              if (imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(imageUrl, height: 200, fit: BoxFit.cover),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _metricChip('Stage', stage, _stageColor(stage)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _metricChip('Confidence', conf, kPrimaryColor),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Clinical notes',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Text(
                notes.isEmpty ? 'No clinical notes available.' : notes,
                style: TextStyle(
                    height: 1.5, color: Colors.grey.shade800, fontSize: 14),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: busy
                          ? null
                          : () {
                              Navigator.pop(ctx);
                              _openReportPdf(report);
                            },
                      icon: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.picture_as_pdf),
                      label: Text(busy ? 'Opening...' : 'View Report'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        showShareReportDialog(
                          context,
                          reportDocId: reportDocId,
                          reportTitle: title,
                        );
                      },
                      icon: const Icon(Icons.share, color: kPrimaryColor),
                      label: const Text('Share'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: kPrimaryColor),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              if (!report.pdfReady &&
                  (report.localPdfPath == null ||
                      !File(report.localPdfPath!).existsSync()))
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Tap View Report to generate and open the PDF on this device.',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14, color: color)),
        ],
      ),
    );
  }

  int _compareReports(
      QueryDocumentSnapshot<Map<String, dynamic>> a,
      QueryDocumentSnapshot<Map<String, dynamic>> b) {
    final ta = a.data()['createdAt'];
    final tb = b.data()['createdAt'];
    if (ta is! Timestamp) return 1;
    if (tb is! Timestamp) return -1;
    return tb.compareTo(ta);
  }

  bool _hasLocalPdf(LabReport report) {
    final path = report.localPdfPath;
    return path != null && path.isNotEmpty && File(path).existsSync();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('My Lab Reports'),
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: uid == null
          ? const Center(child: Text('Sign in to see your reports'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('mri_reports')
                  .where('patientUid', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs.toList() ?? [];
                docs.sort(_compareReports);

                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.biotech_outlined,
                              size: 72, color: Colors.grey.shade400),
                          const SizedBox(height: 20),
                          const Text(
                            'No lab reports yet',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Run an MRI scan in AI Diagnosis — your report and PDF are saved automatically.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.grey.shade600, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: docs.length,
                  itemBuilder: (c, i) {
                    final data = docs[i].data();
                    final reportDocId = docs[i].id;
                    final report =
                        LabReport.fromFirestore(reportDocId, data);
                    final title = report.reportId;
                    final stage = report.stage;
                    final conf = report.confidence;
                    final imageUrl = report.imageUrl ?? '';
                    final pdfReady =
                        report.pdfReady || _hasLocalPdf(report);
                    final sharedCount =
                        ((data['sharedWith'] ?? []) as List).length;
                    final busy = _isBusy(report.docId);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => _showReportDetail(
                              context, data, reportDocId),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: imageUrl.isEmpty
                                      ? Container(
                                          width: 72,
                                          height: 72,
                                          color: const Color(0xFFE3F2FD),
                                          child: const Icon(
                                            Icons.medical_information,
                                            color: kPrimaryColor,
                                            size: 32,
                                          ),
                                        )
                                      : Image.network(
                                          imageUrl,
                                          width: 72,
                                          height: 72,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          )),
                                      const SizedBox(height: 6),
                                      if (stage.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: _stageColor(stage)
                                                .withOpacity(0.12),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            stage,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: _stageColor(stage),
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 6),
                                      Text(
                                        [conf, _formatDate(data['createdAt'])]
                                            .where((s) => s.isNotEmpty)
                                            .join(' • '),
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(
                                            pdfReady
                                                ? Icons.picture_as_pdf
                                                : Icons.hourglass_empty,
                                            size: 14,
                                            color: pdfReady
                                                ? Colors.red.shade400
                                                : Colors.orange,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            pdfReady
                                                ? 'PDF ready'
                                                : 'Tap to generate PDF',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade700),
                                          ),
                                          if (sharedCount > 0) ...[
                                            const SizedBox(width: 12),
                                            Icon(Icons.people_outline,
                                                size: 14,
                                                color: Colors.grey.shade600),
                                            const SizedBox(width: 2),
                                            Text(
                                              'Shared with $sharedCount',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color:
                                                      Colors.grey.shade600),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    IconButton(
                                      tooltip: 'View PDF',
                                      icon: busy
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Icon(
                                              Icons.picture_as_pdf_outlined,
                                              color: pdfReady
                                                  ? Colors.red.shade400
                                                  : Colors.grey,
                                            ),
                                      onPressed: busy
                                          ? null
                                          : () => _openReportPdf(report),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.share_rounded,
                                          color: kPrimaryColor),
                                      onPressed: () => showShareReportDialog(
                                        context,
                                        reportDocId: reportDocId,
                                        reportTitle: title,
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right,
                                        color: Colors.grey),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

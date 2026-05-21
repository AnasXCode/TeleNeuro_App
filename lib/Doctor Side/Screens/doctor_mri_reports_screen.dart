import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/report_share_service.dart';
import 'patient_profile_view_screen.dart';

const Color kPrimaryColor = Color(0xFF1565C0);
const Color _bg = Color(0xFFF0F4F8);

class DoctorMriReportsScreen extends StatelessWidget {
  const DoctorMriReportsScreen({super.key});

  String _formatTime(dynamic createdAt) {
    if (createdAt is Timestamp) {
      return DateFormat('MMM d, yyyy • h:mm a').format(createdAt.toDate());
    }
    return '—';
  }

  Color _stageColor(String stage) {
    final s = stage.toLowerCase();
    if (s.contains('non')) return Colors.green;
    if (s.contains('very mild')) return Colors.lightGreen.shade700;
    if (s.contains('mild')) return Colors.orange;
    if (s.contains('moderate')) return Colors.red.shade700;
    return kPrimaryColor;
  }

  Future<void> _openLink(BuildContext context, String url) async {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No link attached to this report')),
      );
      return;
    }
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the link')),
      );
    }
  }

  void _showDetail(
    BuildContext context,
    Map<String, dynamic> data,
    String firestoreDocId,
    String patientId,
  ) {
    final doctorId = FirebaseAuth.instance.currentUser?.uid;
    if (doctorId != null) {
      ReportShareService.markReportSeen(
        reportDocId: firestoreDocId,
        doctorId: doctorId,
      );
    }

    final notes =
        (data['clinicalNotes'] ?? 'No clinical notes synced.').toString();
    final stage = (data['stage'] ?? '—').toString();
    final conf = (data['confidence'] ?? '—').toString();
    final pdfUrl = (data['pdfUrl'] ?? '').toString();
    final imageUrl = (data['imageUrl'] ?? '').toString();
    final reportLabel = (data['reportId'] ?? firestoreDocId).toString();
    final patientName = (data['patientName'] ?? 'Patient').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.78,
        minChildSize: 0.5,
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
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(patientName,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('Report $reportLabel',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 13)),
                      ],
                    ),
                  ),
                  if (patientId.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PatientProfileViewPage(
                              patientId: patientId,
                              fallbackName: patientName,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.person_outline, size: 18),
                      label: const Text('Profile'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(imageUrl, height: 220, fit: BoxFit.cover),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _detailMetric('Stage', stage, _stageColor(stage)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _detailMetric('Confidence', conf, kPrimaryColor),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Clinical assessment',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  notes,
                  style: const TextStyle(height: 1.55, fontSize: 14),
                ),
              ),
              const SizedBox(height: 20),
              if (imageUrl.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openLink(context, imageUrl),
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('View MRI scan'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              if (pdfUrl.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openLink(context, pdfUrl),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Open full PDF report'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailMetric(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14, color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doctorId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Patient Lab Reports',
            style: TextStyle(color: Colors.white)),
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: doctorId == null
          ? const Center(child: Text('Please sign in'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('mri_reports')
                  .where('sharedWith', arrayContains: doctorId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final reports = snapshot.data?.docs ?? [];
                reports.sort((a, b) {
                  final ta = a.data()['createdAt'];
                  final tb = b.data()['createdAt'];
                  if (ta is! Timestamp) return 1;
                  if (tb is! Timestamp) return -1;
                  return tb.compareTo(ta);
                });

                if (reports.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_shared_outlined,
                              size: 72, color: Colors.grey.shade400),
                          const SizedBox(height: 20),
                          const Text(
                            'No shared reports',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'When patients share MRI reports with you, they will appear here for review.',
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
                  itemCount: reports.length,
                  itemBuilder: (context, i) {
                    final data = reports[i].data();
                    final firestoreDocId = reports[i].id;
                    final name = (data['patientName'] ?? 'Patient').toString();
                    final stage = (data['stage'] ?? '—').toString();
                    final conf = (data['confidence'] ?? '—').toString();
                    final reportId = (data['reportId'] ?? firestoreDocId).toString();
                    final pdfUrl = (data['pdfUrl'] ?? '').toString();
                    final imageUrl = (data['imageUrl'] ?? '').toString();
                    final patientUid = (data['patientUid'] ?? '').toString();

                    final history = List.from(data['shareHistory'] ?? []);
                    bool seen = false;
                    for (final h in history) {
                      if (h is Map &&
                          h['doctorId'] == doctorId &&
                          h['seen'] == true) {
                        seen = true;
                        break;
                      }
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: seen
                            ? null
                            : Border.all(
                                color: kPrimaryColor.withOpacity(0.35),
                                width: 1.5),
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
                          onTap: () => _showDetail(
                            context,
                            data,
                            firestoreDocId,
                            patientUid,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Stack(
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
                                    if (!seen)
                                      Positioned(
                                        right: 0,
                                        top: 0,
                                        child: Container(
                                          width: 12,
                                          height: 12,
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          )),
                                      const SizedBox(height: 6),
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
                                      Text('Confidence: $conf',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade700)),
                                      Text('ID: $reportId',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade500)),
                                      const SizedBox(height: 4),
                                      Text(_formatTime(data['createdAt']),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: kPrimaryColor,
                                            fontWeight: FontWeight.w500,
                                          )),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    if (pdfUrl.isNotEmpty)
                                      IconButton(
                                        icon: Icon(Icons.picture_as_pdf,
                                            color: Colors.red.shade400),
                                        onPressed: () =>
                                            _openLink(context, pdfUrl),
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

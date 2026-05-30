import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../Patient Side/services/mri_report_service.dart';
import '../../Widgets/profile_avatar.dart';

/// Real-time MRI summaries for patients linked to this doctor via Accepted/Completed
/// appointments. PDF + MRI image are hosted on Supabase Storage; URLs live in Firestore.
class DoctorMriReportsScreen extends StatefulWidget {
  const DoctorMriReportsScreen({super.key});

  @override
  State<DoctorMriReportsScreen> createState() => _DoctorMriReportsScreenState();
}

class _DoctorMriReportsScreenState extends State<DoctorMriReportsScreen> {
  bool _isDeleting = false;

  String _formatTime(dynamic createdAt) {
    if (createdAt is Timestamp) {
      final d = createdAt.toDate();
      return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '—';
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

  Future<void> _confirmDeleteReport(
    BuildContext context,
    String documentId,
    String reportLabel,
    Set<String> linkedPatientIds,
    String doctorId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove report?'),
        content: Text(
          'Remove "$reportLabel" from your patient MRI reports list? '
          'The patient keeps their copy in Lab Reports.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      final removed = await MriReportService.deleteDoctorReport(
        doctorId: doctorId,
        documentId: documentId,
        linkedPatientIds: linkedPatientIds,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            removed
                ? 'Report removed from your list.'
                : 'Could not remove this report. Please try again.',
          ),
          backgroundColor: removed ? Colors.green : Colors.orange,
        ),
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  void _showDetail(BuildContext context, Map<String, dynamic> data, String reportId) {
    final notes = (data['clinicalNotes'] ?? 'No clinical notes synced.').toString();
    final stage = (data['stage'] ?? '—').toString();
    final conf = (data['confidence'] ?? '—').toString();
    final pdfUrl = (data['pdfUrl'] ?? '').toString();
    final imageUrl = (data['imageUrl'] ?? '').toString();
    final patientUid = (data['patientUid'] ?? '').toString();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Report $reportId'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (patientUid.isNotEmpty)
                Center(
                  child: ProfileAvatar(userId: patientUid, radius: 36),
                ),
              if (imageUrl.isNotEmpty) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(imageUrl, height: 180, fit: BoxFit.cover),
                ),
              ],
              const SizedBox(height: 12),
              Text('Stage: $stage', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Confidence: $conf', style: const TextStyle(fontWeight: FontWeight.bold)),
              const Divider(height: 24),
              const Text('Clinical notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              SelectableText(notes),
            ],
          ),
        ),
        actions: [
          if (imageUrl.isNotEmpty)
            TextButton.icon(
              onPressed: () => _openLink(context, imageUrl),
              icon: const Icon(Icons.image_outlined, size: 18),
              label: const Text('Open MRI'),
            ),
          if (pdfUrl.isNotEmpty)
            TextButton.icon(
              onPressed: () => _openLink(context, pdfUrl),
              icon: const Icon(Icons.picture_as_pdf, size: 18),
              label: const Text('Open PDF'),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doctorId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FC),
      appBar: AppBar(
        title: const Text('Patient MRI reports', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1565C0),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: doctorId == null
          ? const Center(child: Text('Please sign in'))
          : Stack(
              children: [
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('appointments')
                      .where('doctorId', isEqualTo: doctorId)
                      .where('status', whereIn: ['Accepted', 'Completed'])
                      .snapshots(),
                  builder: (context, apptSnap) {
                    if (apptSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final patientIds = <String>{};
                    for (final d in apptSnap.data?.docs ?? []) {
                      final pid = d.data()['patientId'] as String?;
                      if (pid != null && pid.isNotEmpty) patientIds.add(pid);
                    }

                    if (patientIds.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.folder_off_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                'No linked patients yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Accept or complete appointments first. Reports appear here when patients share them.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('mri_reports')
                          .orderBy('createdAt', descending: true)
                          .limit(100)
                          .snapshots(),
                      builder: (context, reportSnap) {
                        if (reportSnap.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (!reportSnap.hasData) {
                          return const Center(child: Text('No reports yet'));
                        }

                        final reports = reportSnap.data!.docs.where((doc) {
                          return MriReportService.isDoctorVisibleReport(
                            doc.data(),
                            doctorId,
                            patientIds,
                          );
                        }).toList();

                        if (reports.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'No MRI reports yet.\nThey appear when a linked patient shares a report with you.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: reports.length,
                          itemBuilder: (context, i) {
                            final doc = reports[i];
                            final data = doc.data();
                            final name = (data['patientName'] ?? 'Patient').toString();
                            final stage = (data['stage'] ?? '—').toString();
                            final conf = (data['confidence'] ?? '—').toString();
                            final reportId = (data['reportId'] ?? doc.id).toString();
                            final pdfUrl = (data['pdfUrl'] ?? '').toString();
                            final patientUid = (data['patientUid'] ?? '').toString();

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: ProfileAvatar(
                                  userId: patientUid.isNotEmpty ? patientUid : null,
                                  radius: 26,
                                  fallbackIcon: Icons.person,
                                ),
                                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Stage: $stage'),
                                      Text('Confidence: $conf'),
                                      Text('ID: $reportId', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      Text(_formatTime(data['createdAt']), style: const TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                ),
                                isThreeLine: true,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      tooltip: 'Remove from my list',
                                      onPressed: _isDeleting
                                          ? null
                                          : () => _confirmDeleteReport(
                                                context,
                                                doc.id,
                                                reportId,
                                                patientIds,
                                                doctorId,
                                              ),
                                    ),
                                    if (pdfUrl.isNotEmpty)
                                      IconButton(
                                        icon: const Icon(Icons.picture_as_pdf, color: Color(0xFFC62828)),
                                        tooltip: 'Open PDF',
                                        onPressed: () => _openLink(context, pdfUrl),
                                      ),
                                  ],
                                ),
                                onTap: () => _showDetail(context, data, reportId),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
                if (_isDeleting)
                  Container(
                    color: Colors.black26,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
    );
  }
}
